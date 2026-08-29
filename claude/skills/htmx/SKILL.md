---
name: htmx
description: >
  Designing and building hypermedia-driven web applications with htmx 4:
  choosing whether hypermedia fits, shaping server endpoints around UI needs,
  picking targets and swap strategies, updating several regions at once with
  `<hx-partial>`, the HX-* request/response header protocol, status-based
  error and validation handling, scripting boundaries, and the security rules.
  MUST be invoked whenever htmx is used, added, reviewed, or debugged,
  whenever a page is built with `hx-get`/`hx-post`/`hx-swap`/`hx-target`/
  `hx-trigger`, and whenever deciding between htmx and a JavaScript SPA
  framework for a feature.
when_to_use: >
  Use for "build this with htmx", "add htmx to this page", "why isn't my swap
  happening", "how do I update the sidebar too", "should I use htmx or React
  here", "hx-partial", "hx-swap-oob", "out of band", "hx-status", ":inherited",
  "HX-Trigger", "hx-boost", "morph swap", "should the server return HTML or
  JSON", "server-rendered partial", "template fragment", "my 422 response isn't
  swapping", "htmx 2 to 4 migration", "which htmx extension", "SSE with htmx",
  or when reviewing templates that carry `hx-*` attributes. Also use when a
  hypermedia-driven design is on the table under another name: HDA, MPA,
  "server-rendered with partials", Hotwire/Turbo, Unpoly, Datastar, fixi.
---

# Building with htmx 4

htmx generalizes HTML's existing hypermedia controls: any element can issue any
HTTP method on any event and swap the response into any part of the page.
The server returns HTML, not JSON. That single constraint is what the rest of
this skill follows from.

This file covers the decisions: whether hypermedia fits, how to shape the
endpoints, where scripting belongs, and what the security rules are. It is
deliberately not a reference.

## Get the reference from htmx itself

htmx ships four agent skills in its npm package. They are the current,
first-party reference, and they are plain markdown. Fetch the one you need
rather than working from memory of any htmx version:

| Skill | Fetch when |
|---|---|
| [`htmx-guidance`](https://cdn.jsdelivr.net/npm/htmx.org@4/dist/skills/htmx-guidance.md) | writing markup: attributes, triggers, swaps, events, headers, patterns |
| [`htmx-debugging`](https://cdn.jsdelivr.net/npm/htmx.org@4/dist/skills/htmx-debugging.md) | a request doesn't fire or a swap misbehaves |
| [`htmx-upgrade-from-htmx2`](https://cdn.jsdelivr.net/npm/htmx.org@4/dist/skills/htmx-upgrade-from-htmx2.md) | migrating an existing htmx 2 codebase |
| [`htmx-extension-authoring`](https://cdn.jsdelivr.net/npm/htmx.org@4/dist/skills/htmx-extension-authoring.md) | writing or debugging an extension |

The full docs are one file at <https://four.htmx.org/docs.md>, and every
reference page has a `.md` twin (`/reference/attributes/hx-swap.md`). The
package also ships an upgrade checker: `npx htmx.org@next upgrade-check`.

**This skill targets htmx 4.** htmx 2 remains the npm `latest` tag until early
2027, so most existing code is still htmx 2 and reads very differently: no
`:inherited`, camelCase events, `hx-ext`, `hx-disable` meaning what `hx-ignore`
now means, and `4xx` responses not swapping. Check which version a project is
on before writing anything. If it is on 2, say so and reach for the upgrade
skill rather than mixing the two dialects.

## Decide whether hypermedia fits, and say what it costs

htmx trades fine-grained client interactivity for a much smaller system. Make
that trade explicitly, per feature, not per application: mixing approaches is
normal, and an isolated client-side island inside a hypermedia page is far
easier to build than the reverse.

Good fit: text-and-image-heavy UIs, CRUD forms, UIs whose updates land inside
well-defined blocks, anything needing deep links and fast first render.

Bad fit, and say so plainly rather than forcing it: many dynamic
interdependencies across the screen that can't be updated in one exchange (a
spreadsheet), state that updates faster than a network round trip (a map drag,
a game loop), full offline operation, or a team that has standardized on a
component library it wants to keep using.

The honest failure report from a team that dropped htmx (Gumroad's Helper) is
worth taking at face value: complex forms with conditional fields, drag-and-drop
builders, real-time collaboration, and per-cell state pushed them to React. If
the feature in front of you looks like that, say so.

## Shape endpoints around the UI, not around the data model

The endpoints htmx calls are a **hypermedia API**, and it is a different thing
from a JSON data API:

- It exists to serve one application's screens, so specialize it freely: an
  endpoint per region of the page is correct, not a smell.
- It carries no versioning obligation. Refactor it aggressively; add and delete
  endpoints as the UI changes. Clients are humans reading fresh HTML, so there
  is nothing to break.
- It is tightly coupled to the front end on purpose. The decoupling that matters
  happens at the network level, through the uniform interface, and that is what
  makes the churn safe.

When a JSON API is also needed (mobile, third parties), **build it separately**
at its own path (`/api/v1/contacts` next to `/contacts`), rather than using HTTP
content negotiation to return both from one endpoint. The two have opposite
requirements: the JSON API wants stability, versioning, rate limiting, and token
auth; the hypermedia API wants churn, specialization, and cookie sessions.
Keeping domain logic in a model layer, with thin controllers on both sides, is
what stops that from being duplication.

Reach for **template fragments** (rendering a named block of a template rather
than the whole file) instead of shattering templates into many partial files.
Most template engines support it: Jinja via `jinja2-fragments`, Django via
`django-template-partials`, Blade, Twig blocks, Go blocks, `templ`, Thymeleaf,
MiniJinja, Askama. Ask the project's engine before assuming it can't.

Aim for endpoints under ~100ms and roughly three or fewer data-store round trips
each. Server-side caching and hand-tuned SQL are available here in a way they
are not behind a generic JSON API; that is a large part of the payoff.

## Target and swap

Defaults worth holding in mind: the trigger is the element's natural event
(`change` for inputs, `submit` for forms, `click` for everything else), the
target is the element itself, and the swap is `innerHTML`.

Prefer relative targets (`hx-target="closest tr"`, `next`, `previous`, `find`,
`this`) over sprinkling `id` attributes across the DOM.

**Inheritance is explicit in htmx 4**, and this is the change most likely to
produce markup that silently does nothing. An attribute on a parent governs
only that parent unless it carries the `:inherited` modifier:

```html
<div role="tablist" hx-target:inherited="#tab-content">
  <button hx-get="/tab/1">Tab 1</button>
  <button hx-get="/tab/2">Tab 2</button>
</div>
```

Treat every `:inherited` as the deliberate act it now is. Hoisting trades
Locality of Behaviour for DRY, and the trade gets worse the further the
attribute sits from the element it governs: on the enclosing `tbody` it is
fine, three templates away it is not. `:inherited:append` adds to an inherited
value rather than replacing it. `htmx.config.implicitInheritance = true`
restores the htmx 2 behavior, and is for migrations, not new code.

Morphing is built into core now, no extension: `innerMorph` and `outerMorph`
merge into the existing DOM instead of replacing it, preserving focus, scroll,
input values, and playing media. That last one cuts both ways, so a form you
mean to reset needs `innerHTML`/`outerHTML`. `hx-morph-skip` and
`hx-morph-skip-children` fence off a third-party widget that owns its own
subtree.

Keep an element's `id` stable across a swap and CSS transitions work with no
JavaScript. `htmx-swapping`, `htmx-settling`, and `htmx-added` classes exist for
fade-out and fade-in; `hx-swap="... swap:1s"` lengthens the window for the
animation to run.

## Updating several regions at once

Four options, in the order to consider them:

1. **Expand the target.** Wrap the form and the table it feeds in one element
   and target that. Simple and reliable, and the right default when the pieces
   are near each other.
2. **`<hx-partial>` tags.** Each one in the response names its own target and
   swap, so the server states its intent explicitly and can use relative
   selectors (`hx-target="closest li"`) instead of demanding stable ids. Prefer
   this over out-of-band swaps in new code. A response made only of partials
   leaves the main target untouched, which is the point; `hx-swap="...
   swapEmpty:true"` overrides that when the main target should be cleared.
3. **Out-of-band swaps.** `hx-swap-oob` on an element in the response swaps it
   by `id` wherever it lives. Still fine for piggy-backing a flash message or a
   counter, and still what an htmx 2 codebase will be full of.
4. **Events.** Return `HX-Trigger: newContact` and have the dependent element
   listen with `hx-trigger="newContact from:body"` and re-fetch itself. The
   `from:body` is not optional: the event fires on the triggering element and
   reaches the listener by bubbling.

Better than any of them: **co-locate dependent elements** so one target covers
them. A count next to the collection it counts updates for free; the same count
in a tab strip across the page is the case that makes people give up on
hypermedia.

## Where scripting belongs

Scripting is part of the architecture, not a defeat. The rule is that anything
which changes *server* state goes over a hypermedia exchange; purely front-end
state can live in the client.

- Avoid `fetch()` returning JSON that you then render client-side. If a library
  needs that, wrap it as an **island** and connect it to the page with DOM
  events.
- A JS widget that emits events becomes a hypermedia control: the SortableJS
  example is just `hx-trigger="end"` on a form. Prefer libraries that fire
  events; a widget should expose its value through a hidden input rather than a
  JS API.
- Initialize third-party libraries on new content with `htmx.onLoad`, scoped to
  the loaded fragment, not the whole document. Content that *you* insert with
  raw JS needs `htmx.process(el)` before its `hx-*` attributes do anything.
- `hx-on:click="..."` and `hx-on:htmx:after:swap="..."` handle any event inline.
  htmx 4 event names are already lowercase (`htmx:before:request`), so the
  htmx 2 kebab-case trap is gone, but the two view-transition events keep a
  capital (`htmx:before:viewTransition`) and attribute names are
  case-insensitive, so those two cannot be handled with `hx-on:`.
- The `hx-live` extension is the sanctioned answer when a page genuinely wants
  reactive client-side scripting, in place of reaching for Alpine.
- Web components work well here, including Shadow DOM (call `htmx.process(root)`
  in `connectedCallback`).

## The server contract

- `HX-Request: true` on every htmx request. `HX-Source` identifies the
  triggering element as `tag#id`, `HX-Target` the target the same way, and
  `HX-Request-Type` is `partial` or `full`. `HX-Current-URL`,
  `HX-Boosted`, and `HX-History-Restore-Request` carry the rest.
- Responses can steer the client with `HX-Retarget`, `HX-Reswap`, `HX-Reselect`,
  `HX-Trigger`, `HX-Push-Url`, `HX-Replace-Url`, `HX-Location`, `HX-Redirect`,
  `HX-Refresh`.
- **None of those headers survive a 3xx.** The browser follows the redirect
  internally and htmx only sees the final response. Return 200 with the new
  fragment instead: htmx submissions do not need Post/Redirect/Get.
- **Every status code swaps except `204` and `304`.** This inverts htmx 2, where
  `4xx` and `5xx` were silently dropped. A `422` now renders form errors with no
  configuration, which is the good half. The bad half is that an unhandled `500`
  swaps the framework's HTML error page into whatever div was targeted, so
  decide what a server error should look like rather than discovering it in
  production. `hx-status:5xx="swap:none"` per element, or `htmx.config.noSwap`
  globally.
- `hx-status:<code>` steers one status code's `target`, `swap`, `select`,
  `push`, and `replace`, with wildcards (`hx-status:422`, `hx-status:5xx`). It
  replaces htmx 2's `responseHandling` array and the `response-targets`
  extension.
- `hx-push-url` obliges the server to serve that URL as a full page. htmx 4
  keeps no history snapshots, so back and forward re-request the URL and swap
  `body` every time. There is no cache to miss and nothing in `localStorage`,
  which removes a whole class of htmx 2 bug at the cost of a round trip. The
  `hx-history-cache` extension puts a `sessionStorage` cache back, and
  `htmx.config.history = "reload"` does a full reload instead, for pages whose
  client-side state cannot survive an `innerHTML` swap.
- Caching: if one URL returns a full page or a fragment depending on the
  request, branch on `HX-Request-Type` and send `Vary: HX-Request-Type`.
  `ETag`s must differ per variant too.

## Security

Four rules cover almost everything, and they are cheap to hold:

1. **Only call routes you control.** Relative URLs only. htmx inserts the
   response as live HTML and re-creates `<script>` tags so they execute; a
   third-party route can ship one. `htmx.config.mode` defaults to
   `same-origin` and `hx-config` cannot override it, so cross-origin requests
   fail at the browser. Leave it alone.
2. **Use an auto-escaping template engine**, and check that escaping is actually
   on (Jinja outside Flask is the usual trap).
3. **Put user content only inside HTML tags**, never inside `<script>` or
   `<style>`, and never as a tag name or a whole attribute. Wrap any unavoidable
   raw HTML in `hx-ignore` (htmx 2 spelled this `hx-disable`, which in htmx 4
   means something else entirely), which nothing in the injected content can
   turn back on.
4. **Set auth cookies `Secure; HttpOnly; SameSite=Lax`.** Cookies, not
   `Authorization` headers: HTML can set a cookie and JS cannot read it.

**Never put user data in a JS-evaluated attribute**: `hx-on:*`, `hx-vals` with
`js:`, `hx-confirm` with `js:`, and trigger filters. HTML escaping does not
protect you, because the browser decodes entities before the string reaches the
JS engine. Pass the value through `data-*` and read it back
(`hx-on:click="doThing(this.dataset.name)"`).

`hx-headers` on `<html>` or `<body>` is the usual CSRF-token vehicle, but
`hx-boost` never replaces those tags, so a boosted app needs the token
somewhere that does get replaced.

An app under a strict CSP wants the **`hx-csp` extension** rather than
configuration flags. It gates every htmx element on an `hx-nonce` matching the
page nonce (failing closed if either is missing), registers a Trusted Types
policy, and with `safeEval:true` runs the JS-expression features without
`unsafe-eval`. It supersedes `htmx.config.inlineScriptNonce`, which applies one
static nonce to everything and should not be used alongside it. Nonced
responses need `Vary: HX-Request-Type` so page loads and htmx requests cache
separately.

## Progressive enhancement and `hx-boost`

`hx-boost="true"` converts ordinary links and forms into AJAX that swaps the
`body`, and keeps working with JavaScript off. It is also the one genuinely
magical thing in htmx, and part of the core team avoids it: only the body is
swapped so new `head` styles and scripts are dropped (the `hx-head` extension
fixes that), and the global JS scope is not reset between "pages".

Take it or leave it deliberately. Plain unboosted links and forms are a
legitimate choice; so is boosting the whole app. Other patterns can be made
progressive by hand, usually by wrapping the htmx-enhanced control in a real
`<form>` and branching on `HX-Request` server-side.

## Installing

Do not recite a version or an integrity hash from memory. htmx 4 is published
under the npm `next` tag, not `latest`, until early 2027, so `npm i htmx.org`
still installs htmx 2. Install `htmx.org@next` or a pinned `htmx.org@4.x.y`,
and check the current release before writing a `<script>` tag.

Load htmx with a plain blocking `<script>` tag: `defer`, `type="module"`, and
injecting it via AJAX are all documented as unreliable, and the failure looks
like a page where no attribute does anything.

Extensions ship inside the core package under `dist/ext/` rather than as
separate `htmx-ext-*` packages, and there is no `hx-ext` attribute any more:
including the script activates the extension page-wide.
`htmx.config.extensions` is an optional allowlist of registration names, which
are not always the file names. `htmax.js` bundles core with the popular
extensions in one file.

Vendoring the files into the repo and checking them in is a well-supported
option here, since htmx has no runtime dependencies.

## Reading the docs critically

- **Parts of <https://four.htmx.org> are still htmx 2 text.** The quirks page
  documents `responseHandling` and `4xx` not swapping, and the web-security
  essay describes htmx 2 defaults; neither is true in htmx 4. The reference
  pages, the shipped skills, and `dist/htmx.js` itself are the reliable
  sources. When a doc page and the shipped skill disagree, check the source.
- `htmx.org/CVE-2026-3682-1` is an **April Fools joke**, not a security
  advisory. It says so at the bottom. Never cite it.
- `essays/htmx-sucks/` is Carson Gross writing satire against his own library,
  and `essays/prefer-if-statements/` is a joke thread. They are not the
  project's real positions. The genuine critical accounts are
  `essays/why-gumroad-didnt-choose-htmx/` and the "not a good fit" half of
  `essays/when-to-use-hypermedia/`.
- The htmx docs are opinionated advocacy as well as reference. The attribute,
  header, and config pages are factual; the essays argue a position and should
  be presented as such.
