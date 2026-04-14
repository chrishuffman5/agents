# Astro Islands Patterns

Patterns for client directives, server islands, and hydration strategies.

---

## Client Directive Decision Tree

```
Does the component need user interaction (clicks, input, state)?
  | NO --> No directive. Static Astro component. Zero JS.
  |
  YES
  v
Is interaction needed immediately on page load?
  | YES --> client:load
  |
  NO
  v
Is it below the fold or initially hidden?
  | YES --> client:visible (most common for performance)
  |
  NO
  v
Is it a background widget (analytics, chat, metrics)?
  | YES --> client:idle
  |
  NO
  v
Does it only apply on certain screen sizes (mobile drawer)?
  | YES --> client:media="(max-width: 768px)"
  |
  NO
  v
Does it use browser-only APIs and cannot SSR?
  | YES --> client:only="react"
  |
  NO --> client:visible (default recommendation)
```

---

## Client Island Examples

### Immediate Hydration

```astro
---
import SearchBar from '../components/react/SearchBar.jsx';
---
<!-- Above-the-fold interactive component -->
<SearchBar client:load placeholder="Search products..." />
```

### Deferred Hydration

```astro
---
import Comments from '../components/svelte/Comments.svelte';
---
<!-- Below-fold: hydrates only when scrolled into view -->
<Comments client:visible postId={post.id} />
```

### Conditional Hydration

```astro
---
import MobileMenu from '../components/MobileMenu.jsx';
---
<!-- Only hydrated on mobile screens -->
<MobileMenu client:media="(max-width: 768px)" />
```

### Client-Only Rendering

```astro
---
import MapWidget from '../components/react/MapWidget.jsx';
---
<!-- Skips SSR entirely: no server HTML, renders only in browser -->
<MapWidget client:only="react" center={[40.7, -74.0]} />
```

---

## Server Islands (v5)

### Basic Pattern

```astro
---
import UserGreeting from './UserGreeting.astro';
---
<header>
  <!-- Static shell: cached at CDN -->
  <nav>...</nav>

  <!-- Server island: rendered on-demand per request -->
  <UserGreeting server:defer>
    <div slot="fallback" class="skeleton">Loading...</div>
  </UserGreeting>
</header>
```

### Cache Control

Server island responses can have their own cache headers:

```astro
---
// UserGreeting.astro
Astro.response.headers.set('Cache-Control', 'private, max-age=60');
const user = await getUser(Astro.locals.userId);
---
<span>Welcome, {user.name}!</span>
```

- Parent page: `Cache-Control: public, s-maxage=86400` (CDN cache 24h).
- Server island: `Cache-Control: private, no-store` (never cached, personalized).

### When to Use Server Islands

- **Yes:** User name, cart count, personalized recommendations, pricing, auth-dependent content.
- **No:** Interactive components needing client-side state. Use a client island instead.
- **Combine:** Server island wrapping a client island for data + interactivity.

---

## Island Composition

### Static Wrapper with Interactive Core

```astro
---
import ProductCard from '../components/ProductCard.astro';
import AddToCartButton from '../components/react/AddToCartButton.jsx';
---
<!-- Static: product info, image, description -->
<ProductCard product={product}>
  <!-- Only the button needs interactivity -->
  <AddToCartButton client:visible productId={product.id} />
</ProductCard>
```

### Server Island with Client Island Inside

```astro
---
// RecommendationSection.astro (server:defer)
const recs = await getRecommendations(userId);
---
<section>
  <h2>Recommended for You</h2>
  {recs.map(rec => (
    <article>
      <h3>{rec.title}</h3>
      <!-- Client island inside a server island -->
      <SaveButton client:visible itemId={rec.id} />
    </article>
  ))}
</section>
```

---

## Performance Guidelines

1. **Default to no directive** -- Most content is static. Only add `client:*` when needed.
2. **Prefer `client:visible`** -- The best-performing directive for most interactive components.
3. **Avoid `client:load` on large components** -- Heavy frameworks (React, Vue) add significant JS.
4. **Use `client:only` sparingly** -- Skipping SSR means no HTML until JS loads (bad for CLS).
5. **Keep islands small** -- A `<LikeButton>` is better than a `<WholeArticleCard>`.
