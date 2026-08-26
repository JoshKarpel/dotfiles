# htmx 2.x Reference

Lookup tables for attributes, swaps, triggers, headers, events, config, and the
core extensions. Everything here is from <https://htmx.org>; when a detail
matters and this file is silent, fetch the page rather than guessing.

`hx-*` attributes also accept a `data-` prefix (`data-hx-get`) for validators
that reject unknown attributes.

## Request attributes

| Attribute | Purpose | Inherited |
|---|---|---|
| `hx-get` `hx-post` `hx-put` `hx-patch` `hx-delete` | issue that method to the URL | no |
| `hx-trigger` | which event fires the request | no |
| `hx-target` | element to swap into | yes |
| `hx-swap` | how to swap | yes |
| `hx-select` | CSS selector picking part of the response | yes |
| `hx-select-oob` | comma list of response ids to swap out of band | yes |
| `hx-swap-oob` | set *in the response*: swap this element by id, elsewhere | no |
| `hx-include` | extra elements whose values join the request | yes |
| `hx-params` | filter parameters: `*`, `none`, `not a,b`, `a,b` | yes |
| `hx-vals` | extra params as JSON, or `js:{...}` to evaluate | yes (merged) |
| `hx-headers` | extra headers as JSON, or `js:{...}` | yes (merged) |
| `hx-encoding` | set to `multipart/form-data` for file uploads | yes |
| `hx-request` | `{"timeout":…, "credentials":…, "noHeaders":…}` | yes (merged) |
| `hx-sync` | coordinate requests between elements | yes |
| `hx-indicator` | element to receive `htmx-request` during the request | yes |
| `hx-disabled-elt` | elements to `disabled` during the request | yes |
| `hx-confirm` | `window.confirm` text before the request | yes |
| `hx-prompt` | `window.prompt`; answer arrives as `HX-Prompt` header | yes |
| `hx-validate` | force HTML5 validation on a non-form element | no |
| `hx-boost` | AJAX-ify descendant links and forms | yes |
| `hx-push-url` / `hx-replace-url` | `true`, `false`, or a URL | yes |
| `hx-history` | `false` anywhere on the page keeps it out of the history cache | n/a |
| `hx-history-elt` | element to snapshot instead of `body` | no |
| `hx-preserve` | keep this element (by `id`) untouched across swaps | no |
| `hx-disable` | stop htmx processing here and below; cannot be re-enabled | yes |
| `hx-disinherit` / `hx-inherit` | turn inheritance off / on per attribute | n/a |
| `hx-ext` | enable extensions here and below (`ignore:name` to opt out) | yes (merged) |
| `hx-on:<event>` | inline handler for any event | no (but events bubble) |
| `hx-vars` | deprecated, use `hx-vals` | yes |

`hx-vals`/`hx-headers` values are plain JSON by default. The `js:`/`javascript:`
prefix evaluates them and is an XSS risk with user input; `hx-vars` is
deprecated precisely because it always evaluates.

## Extended CSS selectors

Accepted by `hx-target`, `hx-include`, `hx-indicator`, `hx-disabled-elt`,
`hx-trigger`'s `from:`/`target:`, and the `response-targets` attributes:

- `this` - the element itself
- `closest <sel>` - nearest ancestor-or-self matching
- `find <sel>` - first matching descendant
- `next` / `previous` - adjacent sibling
- `next <sel>` / `previous <sel>` - scan forward/backward in the document
- `document`, `window` (in `from:` only)
- a plain selector resolves via `querySelectorAll`, so it can match many
  elements; the extended forms return at most one
- `<sel/>` (angle-bracket query literal) is also accepted
- a selector containing whitespace must be parenthesized inside a modifier:
  `from:(form input)`, `from:closest (form input)`

`hx-include`, `hx-indicator`, and `hx-disabled-elt` also accept an `inherit`
keyword to add to, rather than replace, an inherited value:
`hx-include="inherit, [name='email']"`.

Extended selectors on inherited attributes resolve **from the triggering
element**, not from the element carrying the attribute. `hx-include="find input"`
on a parent looks for an input inside the *button* that was clicked.

## Swap strategies and modifiers

`innerHTML` (default), `outerHTML`, `textContent`, `beforebegin`, `afterbegin`,
`beforeend`, `afterend`, `delete`, `none`. Morphing strategies (`morph`,
`morph:outerHTML`, `morph:innerHTML`) come from the idiomorph extension.

Modifiers, colon-separated, after the strategy:

| Modifier | Effect |
|---|---|
| `transition:true` | wrap the swap in the View Transition API |
| `swap:<time>` | delay between response and swap (default 0ms) |
| `settle:<time>` | delay between swap and attribute settle (default 20ms) |
| `ignoreTitle:true` | don't adopt a `<title>` found in the response |
| `scroll:top`/`bottom` | scroll the target |
| `show:top`/`bottom` | scroll into view; also `show:<sel>:top`, `show:window:top`, `show:none` |
| `focus-scroll:true` | scroll to the focused input after the swap (default false) |

Boosted links and forms default to `show:top`.

## Trigger syntax

`hx-trigger="<event>[filter] modifier..., <event> ..."`, or `every <time>` to
poll.

Filters are JS expressions in square brackets, resolved against the event first
and then the global scope: `click[ctrlKey]`, `keyup[key=='Enter']`. They require
`allowEval`.

| Modifier | Effect |
|---|---|
| `once` | fire at most once |
| `changed` | only if the element's value changed |
| `delay:<time>` | debounce; a new event resets the timer |
| `throttle:<time>` | rate limit; events during the window are dropped |
| `from:<sel>` | listen on another element (`from:body` for global hotkeys) |
| `target:<sel>` | only fire when the event's target matches |
| `consume` | don't let the event trigger parent listeners |
| `queue:first\|last\|all\|none` | what to do with events arriving mid-request (default `last`) |

Non-DOM events htmx supplies: `load`, `revealed` (scrolled into the viewport),
`intersect` (with `root:<sel>` and `threshold:<float>`).

Polling stops when the server answers `286`.

## `hx-sync` strategies

`hx-sync="<selector>:<strategy>"`, default `drop`.

- `drop` - ignore this request if one is in flight on the sync element
- `abort` - drop it, and abort this element's in-flight request if a new one
  starts on the sync element
- `replace` - abort whatever is in flight and issue this one
- `queue first|last|all` - queue instead of dropping

`htmx.trigger(el, 'htmx:abort')` cancels an in-flight request imperatively.

## Out-of-band swaps

`hx-swap-oob` on an element **in the response** takes `true` (equivalent to
`outerHTML`), any swap strategy, or `strategy:<selector>`.

- With `true`/`outerHTML` the element replaces the element with the same `id`.
- With any other strategy the **wrapping tag is stripped** and only its children
  are inserted, so wrap the payload in a tag valid for the destination:
  `<tbody hx-swap-oob="beforeend:#table tbody"><tr>…</tr></tbody>`.
- Elements that can't stand alone in the DOM (`tr`, `td`, `th`, `thead`,
  `tbody`, `tfoot`, `colgroup`, `caption`, `col`, `li`) need a `<template>`
  wrapper, which is discarded.
- SVG children need `<template><svg>…</svg></template>` to get the right
  namespace.
- `htmx.config.allowNestedOobSwaps` defaults to `true`, so an OOB attribute
  nested inside the main response element is still processed. Set it `false`
  when reusing a fragment both standalone and inside a larger one.

`hx-select-oob` is the requesting side of the same idea: a comma list of ids,
each optionally `#id:strategy`.

## Request headers

`HX-Request` (always `true`), `HX-Boosted`, `HX-Current-URL`, `HX-Target`,
`HX-Trigger` (id), `HX-Trigger-Name` (name), `HX-Prompt`,
`HX-History-Restore-Request`.

## Response headers

`HX-Location` (client-side navigation without a reload; accepts JSON with
`path`, `target`, `swap`, `values`, `headers`, `select`, `push`, `replace`),
`HX-Redirect` (full browser redirect), `HX-Refresh`, `HX-Push-Url`,
`HX-Replace-Url`, `HX-Reswap`, `HX-Retarget`, `HX-Reselect`, `HX-Trigger`,
`HX-Trigger-After-Swap`, `HX-Trigger-After-Settle`.

`HX-Trigger` takes a bare event name, a comma list, or JSON:
`{"showMessage":{"level":"info","message":"…"}}` arrives as `event.detail`.
`{"evt":{"target":"#el"}}` fires it on another element.

**No response header is processed on a 3xx**; the browser follows the redirect
and htmx sees only the final response.

Cross-origin setups need `Access-Control-Expose-Headers` for htmx to read these.

## Request lifecycle and CSS classes

Trigger → gather values → add `htmx-request` → send → add `htmx-swapping` to the
target → swap delay → swap (`htmx-swapping` off, `htmx-added` on new content,
`htmx-settling` on target) → settle delay → settle attributes → classes removed.

`htmx-indicator` is styled invisible by default and revealed by an ancestor or
self carrying `htmx-request`. Disable the injected stylesheet with
`includeIndicatorStyles: false`, or supply `inlineStyleNonce` under a strict CSP.

## Events

Request: `htmx:confirm`, `htmx:configRequest`, `htmx:beforeRequest`,
`htmx:beforeSend`, `htmx:afterRequest`, `htmx:beforeOnLoad`, `htmx:afterOnLoad`,
`htmx:responseError`, `htmx:sendError`, `htmx:timeout`, `htmx:sendAbort`,
`htmx:abort`, `htmx:xhr:{loadstart,progress,loadend,abort}`.

Swap: `htmx:beforeSwap` (set `detail.shouldSwap`, `detail.isError`,
`detail.target`), `htmx:afterSwap`, `htmx:afterSettle`, `htmx:beforeTransition`,
`htmx:oobBeforeSwap`, `htmx:oobAfterSwap`, `htmx:oobErrorNoTarget`,
`htmx:swapError`, `htmx:targetError`.

Lifecycle: `htmx:load`, `htmx:beforeProcessNode`, `htmx:afterProcessNode`,
`htmx:beforeCleanupElement`.

History: `htmx:beforeHistorySave`, `htmx:historyCacheHit`,
`htmx:historyCacheMiss`, `htmx:historyCacheMissLoad`, `htmx:historyRestore`,
`htmx:pushedIntoHistory`, `htmx:replacedInHistory`.

Validation: `htmx:validation:validate`, `htmx:validation:failed`,
`htmx:validation:halted`. Security: `htmx:validateUrl` (has `detail.url` and
`detail.sameHost`; `preventDefault()` blocks the request).

Every event is dispatched under both camelCase and kebab-case names.

## JavaScript API

The API is deliberately small and not the point of the library; heavy use of
`htmx.ajax()` in particular usually means a more htmx-shaped approach exists.

`htmx.on/off`, `htmx.onLoad`, `htmx.trigger`, `htmx.process`, `htmx.find`,
`htmx.findAll`, `htmx.closest`, `htmx.remove`, `htmx.addClass`,
`htmx.removeClass`, `htmx.toggleClass`, `htmx.takeClass`, `htmx.swap`,
`htmx.values`, `htmx.ajax`, `htmx.defineExtension`, `htmx.removeExtension`,
`htmx.parseInterval`, `htmx.logAll`, `htmx.logNone`, `htmx.logger`,
`htmx.config`, `htmx.createEventSource`, `htmx.createWebSocket`.

`htmx.parseInterval` only understands `s` and `ms`; `"3m"` returns `3`.

## Configuration

Set with `<meta name="htmx-config" content='{"…":…}'>` (preferred) or by
assigning to `htmx.config`.

Defaults worth knowing, because they are the usual source of surprise:

| Key | Default | Note |
|---|---|---|
| `defaultSwapStyle` | `innerHTML` | many teams switch to `outerHTML` |
| `defaultSwapDelay` / `defaultSettleDelay` | `0` / `20` | ms |
| `selfRequestsOnly` | `true` | htmx 2 blocks cross-domain by default |
| `methodsThatUseUrlParams` | `["get","delete"]` | htmx 2 put `delete` here |
| `scrollBehavior` | `instant` | was `smooth` in htmx 1 |
| `responseHandling` | `[23]..` swaps; `204`, `[45]..` and the rest don't | see below |
| `reportValidityOfForms` | `false` | docs advise setting `true` to restore browser behaviour |
| `historyRestoreAsHxRequest` | `true` | set `false` when branching on `HX-Request` |
| `allowNestedOobSwaps` | `true` | |
| `disableInheritance` | `false` | |
| `allowEval` / `allowScriptTags` | `true` | disable for strict CSP |
| `historyCacheSize` | `10` | `0` disables the `localStorage` cache |
| `globalViewTransitions` | `false` | |
| `getCacheBusterParam` | `false` | alternative to `Vary: HX-Request` |
| `ignoreTitle` | `false` | |
| `withCredentials` / `timeout` | `false` / `0` | |
| `inlineScriptNonce` / `inlineStyleNonce` | `''` | |
| `attributesToSettle` | `["class","style","width","height"]` | |
| `scrollIntoViewOnBoost` | `true` | |
| `wsReconnectDelay` / `wsBinaryType` | `full-jitter` / `blob` | |

Response handling entries take `code` (a regex string), `swap`, `error`,
`ignoreTitle`, `select`, `target`, `swapOverride`, and are tested in order. To
let `422` render form errors:

```html
<meta name="htmx-config" content='{
  "responseHandling":[
    {"code":"204","swap":false},
    {"code":"[23]..","swap":true},
    {"code":"422","swap":true},
    {"code":"[45]..","swap":false,"error":true},
    {"code":"...","swap":false}
  ]}'>
```

## Core extensions

Enable with `hx-ext="name"`, usually on `<body>`. All ship separately from core
(`npm i htmx-ext-<name>`; idiomorph is just `idiomorph`).

- **idiomorph**: registers as `morph`; adds `morph`, `morph:outerHTML`,
  `morph:innerHTML` swaps that merge into the existing DOM instead of replacing
  it, preserving focus and media state at the cost of CPU.
- **head-support**: merges (boosted) or appends (unboosted) `<head>` content
  from responses. `hx-head="merge|append"` on the new `<head>`,
  `hx-head="re-eval"` to force re-adding an element, `hx-preserve` to pin one.
- **response-targets**: `hx-target-404`, `hx-target-5*`, `hx-target-4xx`,
  `hx-target-error`. Wildcard lookup walks `404` → `40*` → `4*` → `*`. Cannot
  handle `200`. Put `hx-ext` on a parent of both the `hx-target-…` and
  `hx-target` attributes.
- **preload**: `preload` attribute on links/`hx-get` elements, `mousedown`
  (default), `mouseover`, `always`, or a custom event; `preload-images="true"`.
  GET only. Adds `HX-Preloaded: true`.
- **sse**: `sse-connect="<url>"`, `sse-swap="<event>[,<event>]"`,
  `sse-close="<event>"`, and `hx-trigger="sse:<event>"` to fire a normal request
  on a message. Unnamed messages arrive as `message`. Uni-directional.
- **ws**: `ws-connect="<url>"`, `ws-send` on a form. Incoming HTML is swapped by
  `id` using OOB rules. Outgoing form values are serialized as **JSON** with a
  `HEADERS` field. Reconnects with full-jitter backoff and queues sends.
- **htmx-1-compat**: restores htmx 1 defaults (`scrollBehavior: smooth`,
  form-encoded `DELETE` bodies, cross-domain allowed) and the removed `hx-ws`,
  `hx-sse`, and bare `hx-on` attributes. Cannot restore IE11 support.

Notable community extensions: `class-tools`, `loading-states`, `path-deps`,
`path-params`, `multi-swap`, `json-enc`, `client-side-templates`, `remove-me`,
`restored`, `safe-nonce`, `alpine-morph`, `morphdom-swap`, `debug`. The full
list lives at <https://htmx.org/extensions/>.

Extensions implement any of `init`, `getSelectors`, `onEvent`,
`transformResponse`, `isInlineSwap`, `handleSwap`, `encodeParameters`, and are
registered with `htmx.defineExtension(name, {...})`.

## Debugging

- `htmx.logAll()` logs every htmx event; `htmx.logNone()` turns it off.
- `monitorEvents(htmx.find("#el"))` in the browser console shows what events the
  element actually fires, which is the fastest way to find a wrong
  `hx-trigger`. Console only.
- Breakpoints in `issueAjaxRequest()` and `handleAjaxResponse()` in the
  unminified `htmx.js` cover most of the request path.
- `<script src="https://demo.htmx.org"></script>` loads htmx, hyperscript, and a
  request mock driven by `<template url="/foo" delay="500">` tags, for building
  a reproduction in a fiddle.
