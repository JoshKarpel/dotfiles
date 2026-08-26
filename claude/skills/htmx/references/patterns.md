# htmx UX Patterns

Working markup for the patterns htmx exists to make easy, from
<https://htmx.org/examples/>. Each one names the endpoints it implies, since the
endpoint shape is the part that has to be designed rather than copied.

## Click to edit

A read-only view that swaps itself for a form and back. The container owns the
target so both states inherit it.

```html
<div hx-target="this" hx-swap="outerHTML">
  <div><label>First Name</label>: Joe</div>
  <div><label>Email</label>: joe@blow.com</div>
  <button hx-get="/contact/1/edit">Click To Edit</button>
</div>
```

`GET /contact/1/edit` returns the form; the form's `PUT /contact/1` returns the
read-only view again, and its Cancel button is a `hx-get="/contact/1"`.

Endpoints: `GET /contact/:id`, `GET /contact/:id/edit`, `PUT /contact/:id`.

## Edit row

Same idea inside a table. Put the target on `tbody` so every row inherits it.
A `<form>` cannot live inside a `<tr>`, so the Save button gathers the row's
inputs with `hx-include`.

```html
<tbody hx-target="closest tr" hx-swap="outerHTML">
  <tr>
    <td><input name="name" value="Joe"></td>
    <td>
      <button hx-get="/contact/1">Cancel</button>
      <button hx-put="/contact/1" hx-include="closest tr">Save</button>
    </td>
  </tr>
</tbody>
```

## Delete row

`hx-confirm` and `hx-target` hoisted onto `tbody`; the swap delay gives the CSS
fade time to run. The server answers `200` with an **empty body** (a `204` would
skip the swap and leave the row).

```html
<tbody hx-confirm="Are you sure?" hx-target="closest tr" hx-swap="outerHTML swap:1s">
  <tr><td>Angie</td><td><button hx-delete="/contact/1">Delete</button></td></tr>
</tbody>
```

```css
tr.htmx-swapping td { opacity: 0; transition: opacity 1s ease-out; }
```

## Active search

Debounce with `delay`, skip no-op keystrokes with `changed`, and add explicit
triggers for Enter and initial load. `hx-sync="this:replace"` keeps a slow
earlier response from landing after a newer one.

```html
<input type="search" name="search"
       hx-post="/search"
       hx-trigger="input changed delay:500ms, keyup[key=='Enter'], load"
       hx-target="#search-results"
       hx-sync="this:replace"
       hx-indicator=".htmx-indicator">
<tbody id="search-results"></tbody>
```

Wrap the input in a real `<form method="post" action="/search">` if the feature
has to survive JavaScript being off.

## Click to load / infinite scroll

The last row carries the request for the next page and replaces or extends
itself, so the response contains the next such row.

```html
<!-- click to load: button row replaces itself with the next page -->
<tr id="replaceMe">
  <td colspan="3">
    <button hx-get="/contacts/?page=2" hx-target="#replaceMe" hx-swap="outerHTML">
      Load More
    </button>
  </td>
</tr>

<!-- infinite scroll: last row fetches when scrolled into view -->
<tr hx-get="/contacts/?page=2" hx-trigger="revealed" hx-swap="afterend">
  <td>Agent Smith</td>
</tr>
```

Inside a scrolling container (`overflow-y: scroll`), `revealed` misfires; use
`hx-trigger="intersect once"` instead.

## Lazy load

Defer an expensive region so the page renders first. This is what lets an
expensive computation live at its own endpoint, and it is also why that endpoint
can be deleted later once the computation gets cheap.

```html
<div hx-get="/graph" hx-trigger="load">
  <img class="htmx-indicator" src="/img/bars.svg" alt="Loading…">
</div>
```

## Inline validation

The wrapper targets itself, so the server can return the same wrapper decorated
with an error class and message.

```html
<form hx-post="/contact">
  <div hx-target="this" hx-swap="outerHTML">
    <label>Email Address</label>
    <input name="email" hx-post="/contact/email" hx-indicator="#ind">
    <img id="ind" class="htmx-indicator" src="/img/bars.svg" alt="Checking…">
  </div>
  <button>Submit</button>
</form>
```

Add `hx-sync="closest form:abort"` on the input so submitting mid-validation
doesn't race. Client-side validation is a UX affordance; re-validate on the
server regardless.

## Progress bar

An outer element polls a status endpoint, and the job's completion is signalled
with an `HX-Trigger: done` response header rather than by polling for a flag.
A stable `id` on the bar plus a CSS transition on `width` makes it move
smoothly instead of jumping.

```html
<div hx-trigger="done" hx-get="/job" hx-swap="outerHTML" hx-target="this">
  <h3 role="status" id="pblabel" tabindex="-1" autofocus>Running</h3>
  <div hx-get="/job/progress" hx-trigger="every 600ms" hx-target="this" hx-swap="innerHTML">
    <div class="progress" role="progressbar" aria-valuemin="0" aria-valuemax="100"
         aria-valuenow="0" aria-labelledby="pblabel">
      <div id="pb" class="progress-bar" style="width:0%"></div>
    </div>
  </div>
</div>
```

Endpoints: `POST /start`, `GET /job` (whole widget), `GET /job/progress` (bar
only, answering `HX-Trigger: done` on the last poll).

## Bulk update

Wrap the table in a form; checkbox state is the browser's job, so a successful
response only needs to say what happened.

```html
<form hx-post="/users" hx-target="#toast" hx-swap="innerHTML settle:3s">
  <table>…<input type="checkbox" name="active:joe@smith.org">…</table>
  <input type="submit" value="Bulk Update">
  <output id="toast"></output>
</form>
```

`<output>` announces politely inside a form; use `<p aria-live="polite">` for
messages not tied to one.

## Cascading selects

The first select targets the second and returns only `<option>` elements.

```html
<select name="make" hx-get="/models" hx-target="#models">
  <option value="audi">Audi</option>
</select>
<select id="models" name="model"><option value="a1">A1</option></select>
```

## Reset a form after submit

```html
<form hx-post="/note" hx-target="#notes" hx-swap="afterbegin"
      hx-on::after-request="if(event.detail.successful) this.reset()">
  <input type="text" name="note-text">
  <button>Add</button>
</form>
<ul id="notes"></ul>
```

`reset()` exists only on `<form>`; elsewhere clear the input by id.

## Tabs

The HATEOAS version returns the whole tab strip with the selected tab marked, so
selection lives in the server's response and needs no client state:

```html
<div id="tabs" hx-get="/tab1" hx-trigger="load delay:100ms"
     hx-target="#tabs" hx-swap="innerHTML"></div>
```

Each tab response re-renders the `role="tablist"` buttons with
`aria-selected` set plus the `role="tabpanel"` content. The JavaScript variant
(moving the `selected` class client-side on `htmx:after-on-load`) saves a bit of
markup and gives up that property; prefer the HATEOAS one unless the duplication
actually hurts.

## Modals

htmx has no modal concept; it fetches the dialog markup and appends it. With
Bootstrap or UIKit, let their JS handle showing, and target a container div.
Hand-rolled:

```html
<button hx-get="/modal" hx-target="body" hx-swap="beforeend">Open a Modal</button>
```

The returned `#modal` element owns its own dismissal (a click handler, an
`animationend` listener, then remove). Prefer inline editing where the design
allows: modals introduce client-side state that fits the hypermedia model
poorly.

## File upload with progress

```html
<form id="form" hx-encoding="multipart/form-data" hx-post="/upload">
  <input type="file" name="file">
  <button>Upload</button>
  <progress id="progress" value="0" max="100"></progress>
</form>
<script>
  htmx.on('#form', 'htmx:xhr:progress', function(evt) {
    htmx.find('#progress').setAttribute('value', evt.detail.loaded / evt.detail.total * 100)
  })
</script>
```

To keep a chosen file across a validation re-render, put `hx-preserve` on the
file input (with a stable `id`), or move the input outside the swapped region
and associate it with `form="binaryForm"`.

## Keyboard shortcuts

```html
<button hx-post="/doit"
        hx-trigger="click, keyup[altKey&&shiftKey&&key=='D'] from:body">
  Do It (alt-shift-D)
</button>
```

## Drag and drop via a JS library

The library supplies the interaction; htmx turns its completion event into a
hypermedia exchange. This is the island pattern in miniature.

```html
<form class="sortable" hx-post="/items" hx-trigger="end">
  <div><input type="hidden" name="item" value="1">Item 1</div>
</form>
```

```js
htmx.onLoad(function (content) {
  content.querySelectorAll(".sortable").forEach(function (el) {
    const s = new Sortable(el, { animation: 150, filter: ".htmx-indicator" })
    el.addEventListener("htmx:afterSwap", () => s.option("disabled", false))
  })
})
```

## Custom confirmation dialog

`htmx:confirm` fires for every request, so check `detail.question` and return
early when the element carries no `hx-confirm`. `issueRequest(true)` skips the
built-in `window.confirm`.

```js
document.addEventListener("htmx:confirm", function (e) {
  if (!e.detail.question) return
  e.preventDefault()
  Swal.fire({ title: "Proceed?", text: e.detail.question }).then(function (r) {
    if (r.isConfirmed) e.detail.issueRequest(true)
  })
})
```

The same event gates requests on an async precondition, such as waiting for an
auth token:

```js
htmx.on("htmx:confirm", (e) => {
  if (authToken == null) { e.preventDefault(); auth.then(() => e.detail.issueRequest()) }
})
htmx.on("htmx:configRequest", (e) => { e.detail.headers["AUTH"] = authToken })
```

## Animations

Three mechanisms, in increasing order of reach:

```css
/* 1. stable id + a transition: htmx settles the new attributes 20ms after swap */
.smooth { transition: all 1s ease-in; }

/* 2. swap/settle phase classes */
.fade-me-out.htmx-swapping { opacity: 0; transition: opacity 1s ease-out; }
#fade-me-in.htmx-added { opacity: 0; }
#fade-me-in { opacity: 1; transition: opacity 1s ease-out; }

/* 3. View Transitions, tied to hx-swap="… transition:true" */
.slide-it { view-transition-name: slide-it; }
::view-transition-old(slide-it) { animation: 180ms both fade-out, 600ms both slide-to-left; }
::view-transition-new(slide-it) { animation: 420ms 90ms both fade-in, 600ms both slide-from-right; }
```

Pair 2 with a matching `hx-swap="outerHTML swap:1s"` or `settle:1s` so the swap
waits for the animation. Set `htmx.config.globalViewTransitions` to apply 3
everywhere.

## Web components

htmx does not see inside a shadow root until told:

```js
customElements.define('my-component', class extends HTMLElement {
  connectedCallback() {
    const root = this.attachShadow({ mode: 'closed' })
    root.innerHTML = `<button hx-get="/clicked" hx-target="next div">Click</button><div></div>`
    htmx.process(root)
  }
})
```

Selectors resolve inside the shadow root; `host` reaches the hosting element and
a `global` prefix reaches the main document. A custom element that reads its
state from attributes and writes it to a hidden input composes with htmx exactly
like a built-in element does, which is the cleanest way to get reusable
components without a framework.
