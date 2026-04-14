# Gatsby to Astro Migration

Step-by-step guide for migrating a Gatsby site to Astro.

---

## Prerequisites

```bash
npm create astro@latest my-site
npx astro add react    # keep React components working
```

---

## Step 1: Migrate Content

Move Markdown from Gatsby's `content/` to Astro's `src/content/[collection]/`. Define a collection schema:

```typescript
// src/content.config.ts
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const blog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    slug: z.string(),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
  }),
});

export const collections = { blog };
```

### Frontmatter Changes

Gatsby uses GraphQL `@dateformat`; Astro uses `z.coerce.date()`. No frontmatter changes needed in most cases.

---

## Step 2: Replace createPages with getStaticPaths

**Gatsby (gatsby-node.js):**
```js
exports.createPages = async ({ graphql, actions }) => {
  const result = await graphql(`query { allMarkdownRemark { nodes { frontmatter { slug } } } }`);
  result.data.allMarkdownRemark.nodes.forEach(node => {
    actions.createPage({
      path: `/blog/${node.frontmatter.slug}`,
      component: require.resolve("./src/templates/blog-post.jsx"),
      context: { slug: node.frontmatter.slug },
    });
  });
};
```

**Astro (`src/pages/blog/[...slug].astro`):**
```astro
---
import { getCollection, render } from 'astro:content';

export async function getStaticPaths() {
  const posts = await getCollection('blog', ({ data }) => !data.draft);
  return posts.map(post => ({
    params: { slug: post.id },
    props: { post },
  }));
}

const { post } = Astro.props;
const { Content } = await render(post);
---
<article>
  <h1>{post.data.title}</h1>
  <Content />
</article>
```

---

## Step 3: Migrate React Components

Add `@astrojs/react` integration. Gatsby React components work directly in Astro.

**Key change:** Add `client:*` directives only for interactive components. Static display components need no directive (zero JS shipped).

```astro
---
import Header from '../components/Header.jsx';      // static: no JS
import SearchBar from '../components/SearchBar.jsx'; // interactive: needs JS
---
<Header />                           <!-- renders as static HTML -->
<SearchBar client:load />            <!-- hydrates with React -->
```

---

## Step 4: Replace gatsby-plugin-image

**Gatsby:**
```jsx
import { GatsbyImage, getImage } from "gatsby-plugin-image";
<GatsbyImage image={getImage(node.frontmatter.hero)} alt="Hero" />
```

**Astro:**
```astro
---
import { Image } from 'astro:assets';
import heroImg from '../assets/hero.jpg';
---
<Image src={heroImg} alt="Hero" width={1200} height={600} />
```

---

## Step 5: Replace Head API

**Gatsby:**
```jsx
export function Head() {
  return <><title>About Us</title><meta name="description" content="..." /></>;
}
```

**Astro (in layout):**
```astro
---
const { title, description } = Astro.props;
---
<html>
  <head>
    <title>{title}</title>
    <meta name="description" content={description} />
  </head>
  <body><slot /></body>
</html>
```

---

## Step 6: Replace useStaticQuery

**Gatsby:**
```jsx
const data = useStaticQuery(graphql`query { site { siteMetadata { title } } }`);
```

**Astro:** Access data directly in frontmatter:
```astro
---
const siteTitle = "My Site"; // or import from a config file
---
<h1>{siteTitle}</h1>
```

---

## Step 7: Migrate gatsby-browser.js / gatsby-ssr.js

**wrapRootElement** (providers, context):
Move to Astro's base layout file. If React context is needed, wrap the interactive portion in a React island.

**wrapPageElement** (layout wrapper):
Use Astro layouts:
```astro
---
// src/layouts/BaseLayout.astro
---
<html>
  <body>
    <nav>...</nav>
    <main><slot /></main>
    <footer>...</footer>
  </body>
</html>
```

---

## Key Differences to Watch

| Gatsby | Astro |
|---|---|
| Webpack | Vite (webpack customizations do not transfer) |
| GraphQL at build time | No GraphQL (direct file/API access) |
| Full React hydration every page | Zero JS by default; islands for interactivity |
| `gatsby-*` plugin ecosystem | Astro integrations + native features |
| `GATSBY_` env prefix | `PUBLIC_` env prefix or `astro:env` schema |
