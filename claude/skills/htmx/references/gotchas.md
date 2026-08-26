# htmx Gotchas

Failures that are silent, look like something else, or contradict a reasonable
guess. Most come from the [quirks page](https://htmx.org/quirks/); the rest are
scattered through the attribute docs.

## Nothing swapped

- **`4xx` and `5xx` do not swap, and `204` does not swap.** A framework that
  answers `422 Unprocessable Entity` for an invalid form produces a page where
  the submit button appears to do nothing. Fix with
  `htmx.config.responseHandling`, the `response-targets` extension, or an
  `htmx:beforeSwap` handler that sets `detail.shouldSwap = true` and
  `detail.isError = false`.
- **Response headers are ignored on `3xx`.** The browser follows the redirect
  before htmx sees it, so `HX-Trigger`, `HX-Retarget`, and friends vanish.
  Answer `200` with the fragment instead.
- **Targeting `body` always swaps `innerHTML`**, whatever `hx-swap` says, so
  attributes on `<body>` can't be changed by a request. Same for `hx-boost`,
  which never replaces `<html>` or `<body>`: a CSRF token hoisted onto either
  tag survives, but so does anything stale you wanted refreshed.
- **`hx-swap="none"` discards `hx-preserve` elements** in the response. OOB
  swaps and response headers still process under `none`.

## Requests that don't fire, or fire wrong

- **A `GET` from a non-form element does not include the enclosing form's
  values.** Non-`GET` methods do. Add `hx-include="closest form"` when a button
  needs to `GET` with the form's inputs.
- **`from:` selectors are evaluated once, at initialization**, and never
  re-evaluated as the DOM changes. For dynamically added elements, listen high
  and filter: `hx-trigger="click[event.target.matches('button')] from:body"`,
  or use the `target:` modifier.
- **An event fired by the `HX-Trigger` response header needs `from:body`** on
  the listener. The header fires the event on the triggering element and it
  reaches other elements only by bubbling.
- **A `reset` trigger races the browser.** `hx-trigger="change, reset"` builds
  the request before the form has actually reset; add
  `reset delay:0.01s`.
- **`revealed` misbehaves inside `overflow-y: scroll` containers.** Use
  `intersect once`.
- **`changed` is a modifier, `change` is an event.** They read almost the same
  and do entirely different things.
- **HTML attribute names are case-insensitive**, so `hx-on:htmx:beforeRequest`
  silently does nothing. Write `hx-on:htmx:before-request` or the `hx-on::`
  shorthand. Non-htmx camelCase custom events cannot be handled by `hx-on` at
  all.
- **Content inserted by your own JavaScript is inert** until `htmx.process(el)`
  runs on it. This includes anything an Alpine `<template x-if>` reveals and
  anything inside a shadow root.
- **htmx must be loaded with a plain blocking `<script>` tag.** `defer`,
  `type="module"`, and AJAX-injected loading are all documented as unreliable,
  and the failure is a page where no attribute does anything.

## Out-of-band swaps

- **Any strategy other than `true`/`outerHTML` strips the wrapping tag** and
  inserts only the children, so the wrapper must be a tag that is valid in the
  destination: `<tbody hx-swap-oob="beforeend:#table tbody">`.
- **Elements that can't stand alone need a `<template>` wrapper**: `tr`, `td`,
  `th`, `thead`, `tbody`, `tfoot`, `colgroup`, `caption`, `col`, `li`. SVG
  children need `<template><svg>…</svg></template>` for the namespace. The
  wrappers are discarded.
- **OOB attributes nested inside the main response element are still
  processed** by default (`allowNestedOobSwaps`), which removes the fragment
  from the DOM when you reuse it inside a larger fragment. Set the config to
  `false` if a fragment serves both roles.
- A missing target id fires `htmx:oobErrorNoTarget` rather than failing loudly.

## Inheritance

- **Most attributes are inherited**, so adding one to a parent silently changes
  every htmx element below it. This is the mechanism behind hoisting `hx-target`
  onto a `tbody`, and it is also how a page acquires action at a distance.
- **Extended selectors on an inherited attribute resolve from the triggering
  element**, not from the element that carries the attribute.
  `hx-include="find input"` on a `div` looks inside the clicked *button* and
  errors when it finds nothing.
- `hx-disinherit` blocks inheritance from a parent; `hx-<attr>="unset"` opts one
  child out; `htmx.config.disableInheritance` flips the default and makes
  `hx-inherit` the opt-in.
- `hx-ext`, `hx-vals`, `hx-headers`, and `hx-request` are *merged* with parent
  values rather than replaced, and `hx-include`/`hx-indicator`/`hx-disabled-elt`
  accept an explicit `inherit` keyword to append rather than override.

## History and caching

- **`hx-push-url` obliges the server to serve that URL as a full page.** Users
  paste URLs and a history cache miss re-requests it.
- **A full page and a fragment served from one URL need `Vary: HX-Request`**, or
  the browser cache will serve one where the other is expected.
  `getCacheBusterParam` is the alternative. `ETag`s must differ per variant too.
- **`historyRestoreAsHxRequest` defaults to `true`**, which makes a history-miss
  full-page request look like an htmx request. Set it `false` in any app that
  branches on `HX-Request` to decide between a page and a partial.
- Third-party libraries that mutate the DOM poison the history snapshot; clean
  up in `htmx:beforeHistorySave`, or set `historyCacheSize: 0` and take the
  slower server round trip.
- `hx-history="false"` anywhere on a page keeps it out of `localStorage`
  entirely, for shared machines and sensitive data.

## Version drift

htmx 2 changed defaults that older answers and older code assume:

- IE11 support dropped (htmx 1.x still supports it and is still maintained).
- All extensions moved out of core into separate packages (`htmx-ext-<name>`;
  idiomorph is `idiomorph`). The SSE extension **must** be upgraded to 2.x.
- `hx-ws` and `hx-sse` removed in favour of the `ws` and `sse` extensions.
- Bare `hx-on="event: script"` removed in favour of `hx-on:<event>`.
- `selfRequestsOnly` now `true`: cross-domain requests are blocked by default.
- `methodsThatUseUrlParams` now `["get","delete"]`: `DELETE` sends URL params,
  not a form-encoded body.
- `scrollBehavior` now `instant` (was `smooth`).
- The `htmx-1-compat` extension reverts all of the above except IE11.
- The extension API's `selectAndSwap` became `swap`, so unmaintained
  third-party extensions may break.

## Reading the site itself

- `htmx.org/CVE-2026-3682-1` is an **April Fools joke**, not a security
  advisory. It says so at the bottom. Never cite it.
- `htmx.org/essays/htmx-sucks/` is Carson Gross writing satire against his own
  library, and `essays/prefer-if-statements/` is a joke thread. They are not
  the project's real positions. The genuine critical accounts are
  `essays/why-gumroad-didnt-choose-htmx/` and the "not a good fit" half of
  `essays/when-to-use-hypermedia/`.
- The htmx docs are opinionated advocacy as well as reference. The attribute,
  header, config, and quirks pages are factual; the essays argue a position and
  should be presented as such.
