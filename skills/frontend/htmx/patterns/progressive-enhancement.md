# HTMX Progressive Enhancement Patterns

Patterns for building applications that work without JavaScript and progressively enhance with HTMX.

---

## hx-boost Foundation

`hx-boost="true"` on `<body>` upgrades all `<a>` and `<form>` elements to AJAX. Without JavaScript, everything works as normal HTML navigation.

```html
<body hx-boost="true">
  <!-- These work as plain HTML without JS -->
  <!-- With JS, they use HTMX AJAX for faster navigation -->
  <nav>
    <a href="/">Home</a>
    <a href="/about">About</a>
    <a href="/contact">Contact</a>
  </nav>

  <form method="post" action="/subscribe">
    <input name="email" type="email" required />
    <button type="submit">Subscribe</button>
  </form>
</body>
```

### Excluding Elements from Boost

```html
<!-- External link: full navigation -->
<a href="https://external.com" hx-boost="false">External</a>

<!-- File download: must not intercept -->
<a href="/files/report.pdf" hx-boost="false" download>Download PDF</a>

<!-- Anchor link: no request needed -->
<a href="#section" hx-boost="false">Jump to section</a>
```

---

## Form Progressive Enhancement

### Basic Pattern

```html
<!-- Without HTMX: standard form POST, full page reload -->
<!-- With HTMX: AJAX POST, response swapped into target -->
<form
  method="post"
  action="/contact"
  hx-post="/contact"
  hx-target="#form-container"
  hx-swap="outerHTML"
>
  <input name="name" required />
  <input name="email" type="email" required />
  <textarea name="message" required></textarea>
  <button type="submit">Send</button>
</form>
```

The `action="/contact"` attribute ensures the form works without JS. The `hx-post` attribute overrides with AJAX when HTMX is present.

### Server-Side Detection

```python
def contact(request):
    if request.method == "POST":
        # Process form...
        if request.headers.get("HX-Request"):
            return render(request, "partials/success_message.html")
        return redirect("/contact?success=true")  # standard PRG pattern
    return render(request, "contact.html")
```

---

## Graceful Degradation Patterns

### Search with Fallback

```html
<!-- Without JS: form submits, full page reloads with results -->
<!-- With JS: live search as you type -->
<form method="get" action="/search">
  <input
    name="q"
    type="search"
    hx-get="/search"
    hx-trigger="keyup changed delay:300ms"
    hx-target="#results"
    hx-push-url="true"
  />
  <button type="submit">Search</button>  <!-- fallback for no-JS -->
</form>
<div id="results">
  <!-- Results render here -->
</div>
```

### Pagination

```html
<!-- Without JS: standard link navigation -->
<!-- With JS: HTMX replaces only the list content -->
<div id="items">
  {% include "partials/item_list.html" %}
</div>

<nav>
  <a href="/items?page=2"
     hx-get="/items?page=2"
     hx-target="#items"
     hx-swap="innerHTML"
     hx-push-url="true">
    Next Page
  </a>
</nav>
```

---

## URL Management

### Push URL for Navigation

Keep browser history correct during AJAX navigation:

```html
<a href="/products/42"
   hx-get="/products/42"
   hx-target="#content"
   hx-push-url="true">
  Product Details
</a>
```

### Replace URL for Filters

Use `hx-replace-url` for filter/sort changes that should not create history entries:

```html
<select
  hx-get="/items"
  hx-target="#item-list"
  hx-replace-url="true"
  name="sort"
>
  <option value="newest">Newest</option>
  <option value="oldest">Oldest</option>
</select>
```

---

## Key Principles

1. **HTML first** -- Every interaction must work as standard HTML. HTMX is an enhancement.
2. **Same URLs** -- HTMX requests and regular requests use the same URLs. Server detects `HX-Request`.
3. **No JS dependencies** -- Core functionality never requires JavaScript. HTMX adds speed, not features.
4. **Semantic HTML** -- Use `<a>` for navigation, `<form>` for mutations, `<button>` for actions. HTMX respects semantics.
