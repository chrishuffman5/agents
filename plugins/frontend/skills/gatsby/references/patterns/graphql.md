# Gatsby GraphQL Patterns

Patterns for maintaining existing Gatsby projects using the GraphQL data layer.

---

## Source Plugins

Pull external data into Gatsby's local GraphQL store as "nodes":

```js
// gatsby-config.js
module.exports = {
  plugins: [
    {
      resolve: "gatsby-source-filesystem",
      options: { name: "posts", path: `${__dirname}/content/posts` },
    },
    {
      resolve: "gatsby-source-contentful",
      options: {
        spaceId: process.env.CONTENTFUL_SPACE_ID,
        accessToken: process.env.CONTENTFUL_ACCESS_TOKEN,
      },
    },
  ],
};
```

---

## Page Queries

Run at build time per page. Only available in page components:

```jsx
export const query = graphql`
  query BlogPageQuery {
    allMarkdownRemark(sort: { frontmatter: { date: DESC } }) {
      nodes {
        id
        frontmatter { title date slug }
        excerpt
      }
    }
  }
`;

export default function BlogPage({ data }) {
  return data.allMarkdownRemark.nodes.map(post => (
    <article key={post.id}>
      <h2>{post.frontmatter.title}</h2>
      <p>{post.excerpt}</p>
    </article>
  ));
}
```

---

## useStaticQuery

For non-page components. Cannot accept variables:

```jsx
import { useStaticQuery, graphql } from "gatsby";

function SiteTitle() {
  const data = useStaticQuery(graphql`
    query { site { siteMetadata { title siteUrl } } }
  `);
  return <h1>{data.site.siteMetadata.title}</h1>;
}
```

---

## createPages API

```js
// gatsby-node.js
exports.createPages = async ({ graphql, actions }) => {
  const { createPage } = actions;
  const result = await graphql(`
    query {
      allMarkdownRemark {
        nodes { frontmatter { slug } }
      }
    }
  `);

  result.data.allMarkdownRemark.nodes.forEach(node => {
    createPage({
      path: `/blog/${node.frontmatter.slug}`,
      component: require.resolve("./src/templates/blog-post.jsx"),
      context: { slug: node.frontmatter.slug },
    });
  });
};
```

---

## Custom sourceNodes (Replacing Broken Plugins)

When a third-party source plugin is abandoned, replace it with manual sourcing:

```js
// gatsby-node.js
exports.sourceNodes = async ({ actions, createNodeId, createContentDigest }) => {
  const { createNode } = actions;
  const posts = await fetch("https://api.example.com/posts").then(r => r.json());

  posts.forEach(post => {
    createNode({
      ...post,
      id: createNodeId(`post-${post.id}`),
      parent: null,
      children: [],
      internal: {
        type: "ExternalPost",
        contentDigest: createContentDigest(post),
      },
    });
  });
};
```

---

## Debugging the Data Layer

```bash
gatsby develop                   # GraphiQL explorer at localhost:8000/___graphql
gatsby build --verbose           # verbose sourcing output
```

### Common Plugin Failure Causes

1. Plugin `peerDependencies` incompatible with Gatsby 5.
2. Deprecated Node.js APIs removed in Node 20.
3. CMS vendor API changes not reflected in abandoned plugin.

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
  `);
};
```
