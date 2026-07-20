# Astro Content Layer Patterns

Patterns for collections, loaders, and schemas in Astro 5's Content Layer API.

---

## Collection Definition

Config file location: `src/content.config.ts` (v5 change from `src/content/config.ts`).

```typescript
import { defineCollection, z } from 'astro:content';
import { glob, file } from 'astro/loaders';

const blog = defineCollection({
  loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    publishDate: z.coerce.date(),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
    cover: z.string().url().optional(),
  }),
});

const authors = defineCollection({
  loader: file('./src/data/authors.json'),
  schema: z.object({
    name: z.string(),
    bio: z.string(),
    avatar: z.string(),
    social: z.object({
      twitter: z.string().optional(),
      github: z.string().optional(),
    }),
  }),
});

export const collections = { blog, authors };
```

---

## Querying Collections

```astro
---
import { getCollection, getEntry, render } from 'astro:content';

// All non-draft posts, sorted by date
const posts = (await getCollection('blog', ({ data }) => !data.draft))
  .sort((a, b) => b.data.publishDate.valueOf() - a.data.publishDate.valueOf());

// Single entry by ID
const post = await getEntry('blog', 'my-first-post');

// Render content
const { Content, headings } = await render(post);
---
<Content />
```

---

## Cross-Collection References

```typescript
import { defineCollection, reference, z } from 'astro:content';

const blog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    author: reference('authors'),     // links to authors collection by ID
    relatedPosts: z.array(reference('blog')).default([]),
  }),
});
```

Resolve references:

```astro
---
const post = await getEntry('blog', Astro.params.slug);
const author = await getEntry(post.data.author);
---
<p>By {author.data.name}</p>
```

---

## Dynamic Pages from Collections

```astro
---
// src/pages/blog/[...slug].astro
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
  <time>{post.data.publishDate.toLocaleDateString()}</time>
  <Content />
</article>
```

---

## Custom CMS Loader

```typescript
// src/loaders/contentful-loader.ts
import type { Loader, LoaderContext } from 'astro/loaders';

export function contentfulLoader(options: { spaceId: string; accessToken: string; contentType: string }): Loader {
  return {
    name: 'contentful-loader',

    async load({ store, meta, logger }: LoaderContext) {
      const lastFetched = meta.get('lastFetched');
      const params = new URLSearchParams({
        content_type: options.contentType,
        access_token: options.accessToken,
        ...(lastFetched ? { 'sys.updatedAt[gte]': lastFetched } : {}),
      });

      const res = await fetch(`https://cdn.contentful.com/spaces/${options.spaceId}/entries?${params}`);
      if (!res.ok) { logger.error(`Fetch failed: ${res.statusText}`); return; }

      const data = await res.json();
      logger.info(`Fetched ${data.items.length} entries`);

      if (!lastFetched) store.clear();

      for (const item of data.items) {
        store.set({
          id: item.sys.id,
          data: {
            title: item.fields.title,
            slug: item.fields.slug,
            body: item.fields.body,
            publishedAt: item.sys.createdAt,
          },
        });
      }

      meta.set('lastFetched', new Date().toISOString());
    },
  };
}
```

---

## Schema Design Tips

1. **Use `z.coerce.date()`** for dates -- handles both string and Date inputs.
2. **Use `.default()`** for optional fields with sensible fallbacks.
3. **Use `reference()`** for relationships instead of raw string IDs.
4. **Use `z.discriminatedUnion`** for entries with different shapes.
5. **Validate at build time** -- schema errors surface during `astro build`, not at runtime.

---

## Loader Selection Guide

| Source | Loader | Notes |
|---|---|---|
| Markdown/MDX files | `glob()` | Default for content-heavy sites |
| JSON/YAML files | `file()` | Best for structured data |
| CMS (Contentful, Sanity) | Custom loader | Fetch at build; `store.clear()` for full refresh |
| REST/GraphQL API | Custom loader | `store.set()` per entry; incremental sync via `meta` |
