# HTMX Swap Strategy Patterns

Choosing the right swap strategy and implementing common interaction patterns.

---

## Strategy Selection Guide

| Strategy | Use When |
|---|---|
| `innerHTML` | Replacing content inside a container (default, most common) |
| `outerHTML` | Replacing the element itself (inline edit to display) |
| `beforeend` | Appending to a list (infinite scroll, chat messages) |
| `afterbegin` | Prepending to a list (newest-first feeds) |
| `delete` | Deleting an element after server confirms removal |
| `none` | Server action with no DOM change (logging, analytics) |
| `morph:innerHTML` | Re-rendering complex UI preserving form state and focus |

---

## Morphing with Idiomorph

Standard `innerHTML` destroys and recreates DOM nodes, losing input values, focus, and CSS transitions. Idiomorph diffs old and new DOM, applying minimal changes:

```html
<script src="https://unpkg.com/idiomorph/dist/idiomorph-ext.min.js"></script>
<body hx-ext="morph">

<!-- Preserves scroll position and input state -->
<div hx-get="/dashboard" hx-trigger="every 10s" hx-swap="morph:innerHTML">
  <div class="scrollable-panel">...</div>
</div>
```

Use morph when: polling dashboards, live data displays, or any UI where focus/scroll/input state matters.

---

## Active Search Pattern

```html
<input
  name="q"
  type="search"
  placeholder="Search..."
  hx-get="/search"
  hx-trigger="keyup changed delay:300ms, search"
  hx-target="#search-results"
  hx-swap="innerHTML"
  hx-indicator="#spinner"
/>
<div id="spinner" class="htmx-indicator">Searching...</div>
<div id="search-results"></div>
```

`keyup changed delay:300ms` -- fires 300ms after typing stops, only if value changed. `search` -- also fires on the browser's native search event (clearing the field).

---

## Infinite Scroll Pattern

```html
<div id="item-list">
  {% for item in items %}
    <div class="item">{{ item.name }}</div>
  {% endfor %}

  {% if has_next %}
  <div
    hx-get="/items?page={{ next_page }}"
    hx-trigger="revealed"
    hx-target="#item-list"
    hx-swap="beforeend"
    hx-select=".item, [hx-trigger]"
  >
    <div class="loading-spinner">Loading more...</div>
  </div>
  {% endif %}
</div>
```

`revealed` fires when the element scrolls into the viewport. The trigger element replaces itself with new items plus a new trigger (or nothing if no more pages). `hx-select` extracts only matching elements from the response.

---

## Inline Edit Pattern

```html
<!-- Display mode -->
<div id="item-42">
  <span>Widget Name</span>
  <button hx-get="/items/42/edit" hx-target="#item-42" hx-swap="outerHTML">Edit</button>
</div>

<!-- Edit mode (returned by GET /items/42/edit) -->
<form id="item-42" hx-put="/items/42" hx-target="this" hx-swap="outerHTML">
  <input name="name" value="Widget Name" />
  <button type="submit">Save</button>
  <button hx-get="/items/42" hx-target="#item-42" hx-swap="outerHTML">Cancel</button>
</form>
```

`outerHTML` replaces the entire element -- toggling between display and edit modes.

---

## Delete with Confirmation

```html
<tr id="row-42">
  <td>Widget</td>
  <td>
    <button
      hx-delete="/items/42"
      hx-target="closest tr"
      hx-swap="delete swap:500ms"
      hx-confirm="Delete this item?"
    >Delete</button>
  </td>
</tr>
```

`hx-confirm` shows a native browser confirm dialog. `swap:500ms` delays removal for CSS fade-out animation. Server returns 204 No Content.

---

## OOB Multi-Update Pattern

Update a list, a counter, and a toast notification from a single POST:

```html
<!-- Response from POST /items -->
<li id="item-42">New Item</li>

<span id="item-count" hx-swap-oob="true">43 items</span>

<div id="toast" hx-swap-oob="innerHTML">
  <div class="toast success">Item created!</div>
</div>
```

Primary content (the `<li>`) goes into `hx-target` via `hx-swap="beforeend"`. OOB elements update their matching IDs anywhere in the DOM.
