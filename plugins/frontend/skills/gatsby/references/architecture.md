# Gatsby Architecture Reference

Overview of Gatsby's GraphQL data layer, build process, and key Gatsby 5 features.

---

## Architecture Overview

Gatsby is a React-based static site generator with a GraphQL data abstraction layer. At build time, Gatsby fetches all data into a local GraphQL store, then renders every page to HTML + a hydrated React bundle.

### Core Build Phases

1. **Bootstrap** -- Load config, initialize plugins, source nodes into the data layer.
2. **Schema inference** -- Infer GraphQL types from sourced nodes; merge with custom type definitions.
3. **createPages** -- `gatsby-node.js` queries data and calls `createPage()` to define pages dynamically.
4. **Build** -- Webpack compiles pages to HTML (SSG) + JS bundles for hydration.
5. **Post-build** -- Image processing (sharp), service worker generation.

### Key Differences from Modern Frameworks

- No server at runtime -- everything is prebuilt to static files. No ISR, SSR, or API routes.
- Data lives in GraphQL at build time, not at request time.
- Full React hydration on every page (no islands architecture).
- Webpack 5 only -- not configurable to Vite or Turbopack.

---

## Key Config Files

- `gatsby-config.js` -- plugins, site metadata, feature flags
- `gatsby-node.js` -- createPages, createSchemaCustomization, onCreateNode, sourceNodes
- `gatsby-browser.js` / `gatsby-ssr.js` -- client/SSR lifecycle hooks (wrapRootElement, wrapPageElement)

### Environment Variables

Prefix with `GATSBY_` to expose to the browser. All others are build-time only.

---

## Gatsby 5 Features

### Slice API

Isolates shared components (nav, footer) into separate build units. Only changed slices re-render.

```jsx
// gatsby-node.js
exports.createSlices = ({ actions }) => {
  actions.createSlice({
    id: "header",
    component: require.resolve("./src/components/header.jsx"),
  });
};

// In pages/layouts
import { Slice } from "gatsby";
<Slice alias="header" />
```

### Head API

Replaces `react-helmet`. Export a `Head` component from any page:

```jsx
export function Head() {
  return (
    <>
      <title>About Us</title>
      <meta name="description" content="About our company" />
    </>
  );
}
```

### Script Component

Controls third-party script loading strategy:

```jsx
import { Script } from "gatsby";
<Script src="https://analytics.example.com/script.js" strategy="post-hydrate" />
<Script src="https://widget.example.com/embed.js" strategy="idle" />
<Script src="https://gtm.example.com/gtm.js" strategy="off-main-thread" />
```

---

## Schema Customization

Prevents build failures when fields are missing from some nodes:

```js
exports.createSchemaCustomization = ({ actions }) => {
  actions.createTypes(`
    type MarkdownRemarkFrontmatter {
      title: String!
      date: Date @dateformat
      slug: String!
      draft: Boolean
      tags: [String]
    }
    type MarkdownRemark implements Node {
      frontmatter: MarkdownRemarkFrontmatter!
    }
  `);
};
```

---

## Extending Webpack

```js
exports.onCreateWebpackConfig = ({ actions }) => {
  actions.setWebpackConfig({
    resolve: {
      alias: { "@components": `${__dirname}/src/components` },
    },
  });
};
```
