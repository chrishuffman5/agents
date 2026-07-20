# HTMX Diagnostics Reference

Troubleshooting guide for common HTMX issues.

---

## Request Not Firing

1. **Trigger not matching** -- Check `hx-trigger` value. Default for `<div>` is `click`; is the element receiving click events? Add `hx-trigger="click"` explicitly to verify.

2. **Target missing** -- If `hx-target` references an element that does not exist, the swap silently fails. Check browser console for HTMX warnings. Use `htmx.logAll()` to see all events.

3. **CORS blocked** -- HTMX 2.0 `selfRequestsOnly=true` blocks cross-origin by default. Check browser console for CORS errors. Configure CORS on server and set `htmx.config.selfRequestsOnly = false`.

4. **Extension not loaded** -- `hx-ext="sse"` requires the SSE extension script to be loaded before the element is processed.

5. **Form inside form** -- Nested forms are invalid HTML; browsers ignore inner forms. Restructure markup.

6. **hx-on event name format** -- In 2.0, use kebab-case: `hx-on:htmx:after-swap`, not `hx-on="htmx:afterSwap: ..."`.

---

## Swap Not Working

1. **Wrong strategy** -- `innerHTML` vs `outerHTML` mismatch. If response returns `<div id="target">` wrapper and strategy is `innerHTML`, the ID appears twice.

2. **OOB ID mismatch** -- `hx-swap-oob` finds targets by ID. If `id="status"` in response but DOM has `id="status-bar"`, no swap occurs. No error thrown.

3. **204 response** -- HTTP 204 is intentional no-swap. Verify server is not returning 204 when content is expected.

4. **Response not HTML** -- If server returns JSON or a redirect, HTMX inserts raw text. Verify Content-Type is `text/html`.

5. **hx-select filtering everything** -- If `hx-select` selector matches nothing in the response, an empty swap occurs.

6. **View Transition blocking** -- `transition:true` requires browser View Transition API support. Fallback is no transition, not failure.

---

## Extension Issues

- Verify extension script URL and version are correct.
- `hx-ext` must be on the element or an ancestor.
- **SSE**: Verify endpoint returns `Content-Type: text/event-stream` and does not buffer responses.
- **WebSocket**: Verify server speaks WS protocol on the configured path.
- **Idiomorph**: Must be loaded before any `morph:innerHTML` swap is used.
- **response-targets**: Status code attributes use `hx-target-NNN` format (e.g., `hx-target-422`).

---

## Debugging Tools

```javascript
// Enable full logging
htmx.logAll();

// Custom logger
htmx.logger = function(elt, event, data) {
  if (console) console.log("HTMX Event:", event, elt, data);
};

// Inspect config
console.log(htmx.config);

// Manual HTMX request for testing
htmx.ajax("GET", "/test", {target: "#output", swap: "innerHTML"});

// Find all HTMX-processed elements
document.querySelectorAll("[hx-get],[hx-post]").forEach(el => {
  console.log(el, htmx.closest(el, "[hx-target]"));
});
```

**Browser DevTools:** All HTMX requests appear in Network tab. Look for `HX-Request: true` header in outgoing requests. Inspect response headers for `HX-Trigger`, `HX-Redirect`, etc.

---

## HTMX 2.0 Breaking Changes

| Change | Impact | Action |
|---|---|---|
| `selfRequestsOnly` default `true` | Cross-origin requests blocked | Set `htmx.config.selfRequestsOnly = false` |
| SSE/WS moved to extensions | `hx-sse`/`hx-ws` no longer built-in | Load extension scripts |
| `hx-on` syntax changed | Colon-separated attribute format | Use `hx-on:event-name="code"` |
| DELETE uses URL params | Body not sent with DELETE | Read from query string server-side |
| IE support dropped | Modern browsers only | No action needed |
| Extensions moved to separate repo | CDN paths changed | Update script URLs |
