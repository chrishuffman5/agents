# HTMX Architecture Reference

Deep reference for HTMX 2.x attributes, swap strategies, out-of-band swaps, request/response model, and extensions.

---

## Core Attributes

### HTTP Method Attributes

```html
hx-get="/endpoint"        hx-post="/endpoint"
hx-put="/endpoint"        hx-patch="/endpoint"
hx-delete="/endpoint"
```

When activated, HTMX sends the HTTP request and swaps the response HTML into the target.

### hx-trigger

Controls what event initiates the request. Default: `click` for most elements, `change` for inputs, `submit` for forms.

**Event-based:**
```html
hx-trigger="click"          hx-trigger="mouseenter"
hx-trigger="keyup"          hx-trigger="change"
hx-trigger="submit"
```

**Modifiers (space-separated):**
```html
hx-trigger="click once"                   <!-- fires only first time -->
hx-trigger="click changed"                <!-- only if value changed -->
hx-trigger="keyup delay:300ms"            <!-- debounce 300ms -->
hx-trigger="keyup changed delay:300ms"    <!-- debounce + only if changed -->
hx-trigger="click throttle:2s"            <!-- at most once per 2s -->
hx-trigger="click queue:last"             <!-- queue only the last request -->
hx-trigger="click from:document"          <!-- listen on different element -->
hx-trigger="click consume"                <!-- stop event propagation -->
hx-trigger="click target:.btn"            <!-- filter by target selector -->
```

**Special triggers:**
```html
hx-trigger="load"                          <!-- fires on page load -->
hx-trigger="load delay:1s"               <!-- fires 1s after load -->
hx-trigger="revealed"                     <!-- element scrolls into viewport -->
hx-trigger="intersect"                    <!-- Intersection Observer API -->
hx-trigger="intersect threshold:0.5"     <!-- 50% visible -->
hx-trigger="every 5s"                     <!-- polling every 5 seconds -->
```

**Multiple triggers:**
```html
hx-trigger="keyup, change"               <!-- keyup OR change -->
```

### hx-target

Specifies which element receives swapped content. Default: the element itself.

```html
hx-target="#result"                <!-- CSS ID selector -->
hx-target=".panel"                 <!-- CSS class (first match) -->
hx-target="this"                   <!-- the element itself -->
hx-target="closest div"            <!-- nearest ancestor -->
hx-target="find .child"            <!-- descendant -->
hx-target="next .sibling"         <!-- next sibling -->
hx-target="previous .sibling"     <!-- previous sibling -->
hx-target="body"                   <!-- full body replacement -->
```

### hx-swap

Controls how response HTML is inserted relative to the target. Default: `innerHTML`.

```html
hx-swap="innerHTML"       <!-- replace inner content (default) -->
hx-swap="outerHTML"        <!-- replace entire target element -->
hx-swap="beforebegin"     <!-- insert before target -->
hx-swap="afterbegin"      <!-- insert as first child -->
hx-swap="beforeend"       <!-- insert as last child (append) -->
hx-swap="afterend"        <!-- insert after target -->
hx-swap="delete"          <!-- delete target, ignore response -->
hx-swap="none"            <!-- no DOM change -->
```

**Modifiers:**
```html
hx-swap="innerHTML swap:500ms"                <!-- wait before swapping -->
hx-swap="innerHTML settle:300ms"              <!-- wait before removing settling class -->
hx-swap="innerHTML scroll:top"                <!-- scroll target to top -->
hx-swap="outerHTML transition:true"           <!-- use View Transitions API -->
hx-swap="beforeend scroll:#container:bottom"  <!-- combined modifiers -->
```

### CSS Lifecycle Classes

- `htmx-request` -- added to element while request is in-flight
- `htmx-settling` -- added to new content during settle phase
- `htmx-swapping` -- added to old content before swap

---

## Out-of-Band Swaps

A single HTTP response can update multiple DOM elements. The primary response body swaps into `hx-target`. Additional elements marked with `hx-swap-oob` swap into matching IDs.

```html
<!-- Primary content -->
<div id="search-results">
  <p>Result 1</p>
  <p>Result 2</p>
</div>

<!-- OOB updates -->
<span id="result-count" hx-swap-oob="true">2 results</span>
<div id="status-bar" hx-swap-oob="innerHTML">Search complete</div>
```

**hx-swap-oob values:**
```html
hx-swap-oob="true"          <!-- outerHTML (replaces element by ID) -->
hx-swap-oob="innerHTML"     <!-- replaces inner content -->
hx-swap-oob="beforeend"     <!-- appends to element -->
hx-swap-oob="afterbegin"    <!-- prepends to element -->
```

---

## Request/Response Model

### Request Headers (sent by HTMX)

| Header | Value | Description |
|---|---|---|
| `HX-Request` | `true` | Always sent; detect HTMX requests server-side |
| `HX-Trigger` | element ID | ID of triggering element |
| `HX-Trigger-Name` | name attr | Name attribute of triggering element |
| `HX-Target` | element ID | ID of target element |
| `HX-Current-URL` | URL | Current browser URL |
| `HX-Boosted` | `true` | Request via hx-boost |

### Response Headers (sent by server)

| Header | Value | Effect |
|---|---|---|
| `HX-Trigger` | event name or JSON | Fire client-side event after swap |
| `HX-Trigger-After-Settle` | event name or JSON | Fire event after settle phase |
| `HX-Trigger-After-Swap` | event name or JSON | Fire event after swap phase |
| `HX-Redirect` | URL | Client-side redirect (no swap) |
| `HX-Reswap` | swap strategy | Override hx-swap for this response |
| `HX-Retarget` | CSS selector | Override hx-target for this response |
| `HX-Push-Url` | URL or `false` | Push URL to browser history |
| `HX-Replace-Url` | URL or `false` | Replace URL in browser history |
| `HX-Refresh` | `true` | Force full page refresh |

HTTP 204 No Content: HTMX performs no swap.

**HX-Trigger with JSON (multiple events with data):**
```
HX-Trigger: {"itemAdded": {"id": 42, "name": "Widget"}, "cartUpdated": true}
```

---

## Extensions

Extensions are separate scripts. Include after htmx, activate with `hx-ext`.

**SSE (Server-Sent Events):**
```html
<script src="https://unpkg.com/htmx-ext-sse@2.2.1/sse.js"></script>
<div hx-ext="sse" sse-connect="/stream" sse-swap="update">
  <div id="live-data">Waiting...</div>
</div>
```

**WebSocket:**
```html
<div hx-ext="ws" ws-connect="/ws/chat">
  <div id="chat-messages"></div>
  <form ws-send>
    <input name="message" />
    <button type="submit">Send</button>
  </form>
</div>
```

**Idiomorph (morphing):** Intelligent DOM merging preserving focus, scroll, input values, animations:
```html
<script src="https://unpkg.com/idiomorph/dist/idiomorph-ext.min.js"></script>
<div hx-get="/component" hx-swap="morph:innerHTML">
```

**response-targets:** Map HTTP status codes to different targets:
```html
<div hx-ext="response-targets"
     hx-get="/data"
     hx-target="#success"
     hx-target-422="#error-msg"
     hx-target-500="#server-error">
```

**preload:** Preload links on mouseenter:
```html
<body hx-ext="preload">
<a href="/page" preload>Fast link</a>
```

**loading-states:** Manage loading UI:
```html
<button hx-ext="loading-states" hx-post="/submit"
        data-loading-disable>Submit</button>
```

**head-support:** Merge `<head>` content from responses:
```html
<body hx-ext="head-support">
```
