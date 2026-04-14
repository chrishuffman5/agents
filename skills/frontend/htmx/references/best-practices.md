# HTMX Best Practices Reference

Guidelines for progressive enhancement, backend integration, scripting companions, and security.

---

## Progressive Enhancement

### hx-boost as Foundation

Apply `hx-boost="true"` to `<body>` or a container. All `<a>` and `<form>` elements within scope use HTMX AJAX, swapping only the `<body>` and updating the URL via pushState. The page works without JavaScript.

```html
<body hx-boost="true">
  <a href="/about">About</a>          <!-- AJAX navigation -->
  <form method="post" action="/save">  <!-- AJAX submit -->
    <input name="title" />
    <button>Save</button>
  </form>
</body>
```

Disable boost on specific elements:

```html
<a href="/external" hx-boost="false">External link</a>
```

### Server-Side HX-Request Detection

Return fragments for HTMX requests, full pages for regular requests. The same URL serves both:

```python
# Django
def my_view(request):
    context = {"items": Item.objects.all()}
    if request.headers.get("HX-Request"):
        return render(request, "partials/item_list.html", context)
    return render(request, "full_page.html", context)
```

### Graceful Degradation Principle

- All links and forms should work as standard HTML first.
- HTMX attributes layer on AJAX behavior.
- Users without JavaScript get a fully functional (but slower) experience.
- Use `hx-push-url="true"` to keep browser history correct during AJAX navigation.

---

## Backend Integration

### Template Partials Pattern

Structure templates so a partial can be rendered standalone or embedded in a full layout:

```html
<!-- base.html (full page) -->
<!DOCTYPE html>
<html><body>{% block content %}{% endblock %}</body></html>

<!-- items.html (full page with partial) -->
{% extends "base.html" %}
{% block content %}{% include "partials/item_list.html" %}{% endblock %}

<!-- partials/item_list.html (standalone fragment) -->
<ul id="item-list">
  {% for item in items %}
    <li>{{ item.name }}</li>
  {% endfor %}
</ul>
```

The view checks `HX-Request` and returns the partial or the full page.

### Response Headers for Server-Driven Control

Use `HX-Trigger` to fire client-side events from server responses:

```python
response = render(request, "partials/item_row.html", {"item": item})
response["HX-Trigger"] = "itemCreated"  # fire event after swap
return response
```

Use `HX-Redirect` for server-initiated redirects. Use `HX-Reswap` to change swap strategy dynamically.

### HTTP 204 for No-Swap Operations

Return 204 No Content when the server processes a request but no DOM change is needed:

```python
def delete_item(request, pk):
    item = get_object_or_404(Item, pk=pk)
    item.delete()
    return HttpResponse(status=204)  # hx-swap="delete" handles removal
```

---

## Scripting Companions

### Alpine.js (Recommended)

Alpine handles client-only state (dropdowns, toggles, form validation) without server round-trips. Complementary to HTMX:

```html
<div x-data="{ open: false }">
  <button @click="open = !open">Toggle Menu</button>
  <nav x-show="open" x-transition>
    <a hx-get="/profile" hx-target="#content">Profile</a>
  </nav>
</div>
```

### Hyperscript

Authored by the HTMX team. Readable event/behavior DSL in HTML attributes:

```html
<button _="on click toggle .hidden on #menu">Toggle</button>
<input _="on keyup if my value's length > 2 remove .error from #field-error">
```

### Vanilla JS + HTMX Events

```javascript
// Re-initialize third-party libraries after swap
document.addEventListener("htmx:afterSwap", function(evt) {
  initDatePickers(evt.detail.target);
  initTooltips(evt.detail.target);
});

// Add custom headers to all requests
document.addEventListener("htmx:configRequest", function(evt) {
  evt.detail.headers["X-Custom-Header"] = "value";
});
```

---

## Security

### CSRF Tokens

HTMX sends cookies automatically but CSRF tokens from meta tags must be forwarded:

**Django (global via hx-headers on body):**
```html
<body hx-headers='{"X-CSRFToken": "{{ csrf_token }}"}'>
```

**Rails:**
```html
<body hx-headers='{"X-CSRF-Token": "<%= form_authenticity_token %>"}'>
```

**ASP.NET (per-form, token in form field):**
```html
<form hx-post="/save">@Html.AntiForgeryToken()<button>Save</button></form>
```

**Meta-tag approach (any backend):**
```html
<meta name="csrf-token" content="{{ csrf_token }}">
<script>
  document.body.setAttribute("hx-headers",
    JSON.stringify({"X-CSRFToken": document.querySelector('meta[name="csrf-token"]').content}));
</script>
```

### selfRequestsOnly (HTMX 2.0 Default)

HTMX 2.0 blocks cross-origin AJAX requests by default. Enable for APIs on other origins:

```javascript
htmx.config.selfRequestsOnly = false;
htmx.config.allowedHosts = ["api.example.com"];
```

### Content Security Policy

HTMX executes no `eval`. A strict CSP is compatible as long as the HTMX script is allowed (via hash or nonce). `hx-on` handlers execute within the page's existing JS context.

### Auth Token Forwarding

```html
<div hx-headers='{"Authorization": "Bearer token-here"}' hx-get="/api/data">
```

Or globally via event listener:
```javascript
document.addEventListener("htmx:configRequest", function(evt) {
  const token = localStorage.getItem("authToken");
  if (token) evt.detail.headers["Authorization"] = `Bearer ${token}`;
});
```

---

## Design Principles

### Prefer Server-Side Logic

Do not replicate business logic on the client. Let the server decide what HTML to return. The server controls available actions by including or excluding hypermedia controls.

### Small, Focused Responses

Return only the HTML fragment that changed, not the entire page. Use OOB swaps when multiple regions need updating.

### Use hx-indicator for Loading States

```html
<button hx-post="/save" hx-indicator="#spinner">Save</button>
<span id="spinner" class="htmx-indicator">Saving...</span>
```

The `htmx-indicator` class hides the element by default and shows it during requests.

### Avoid Deep Nesting of hx- Attributes

Keep HTMX attributes close to the triggering element. Inheritance via `hx-target` on ancestors is convenient but can be confusing. Be explicit when clarity matters.
