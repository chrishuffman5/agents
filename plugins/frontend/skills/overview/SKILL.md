---
name: overview
description: "Cross-framework frontend expertise: rendering models (CSR/SSR/SSG/ISR/islands/RSC), reactivity systems, framework selection, and performance fundamentals that span React, Vue, Angular, Next.js, Nuxt, Svelte, Astro, Remix, Blazor, Gatsby, and htmx. Use for \"frontend framework\", \"which frontend framework\", \"SSR vs SSG\", \"hydration\", \"islands architecture\", \"component design\", \"state management\", \"reactivity\", \"bundle size\", \"code splitting\", \"Core Web Vitals\", \"frontend performance\" questions that are framework-agnostic. Do NOT use for framework-specific implementation questions (React hooks, Vue composables, Angular signals, etc.) -- use that framework's own skill instead."
license: MIT
---

# Frontend Overview

This skill covers cross-framework frontend expertise: rendering models, reactivity systems, component architecture, and frontend performance. Route to a framework-specific skill for implementation details.

## When to Use This Skill vs. a Framework Skill

**Use this skill when the question is framework-agnostic:**
- "Which frontend framework should I use for X?"
- "SSR vs SSG vs islands for my site?"
- "What is hydration and why does it cost?"
- "Signals vs virtual DOM — what's the difference?"
- "How do I think about state management architecture?"
- "What drives Core Web Vitals and bundle size?"

**Use a framework-specific skill when the question is framework-specific:**

| Technology | Skill | Related skills |
|---|---|---|
| React | `react` | `react-server-components` |
| Next.js | `nextjs` | `nextjs-app-router` |
| Vue | `vue` | — |
| Nuxt | `nuxt` | — |
| Angular | `angular` | `angular-signals` |
| Svelte | `svelte` | — (Svelte 5 runes era) |
| Astro | `astro` | — |
| Remix | `remix` | — |
| Blazor | `blazor` | — |
| Gatsby | `gatsby` | — |
| htmx | `htmx` | — |

**Directory conventions within each framework skill:**
- `references/patterns/` — how to structure and implement (composition, data fetching, forms, routing patterns)
- `assets/` — build tooling, bundler, and project configuration
- `references/` — API facts, concepts, and comparisons
- `references/versions/` — version-specific features and breaking changes

Pick the directory type matching the question; read the narrowest file that answers.

## How to Approach Tasks

1. **Classify** the request:
   - **Framework selection** — use the selection criteria below, then load candidate framework SKILL.md files
   - **Rendering-model decision** — use the rendering model table below
   - **Framework-specific implementation** — use that framework's skill, its `references/patterns/`, at the user's version
   - **Build/tooling** — use that framework's skill, its `assets/`
   - **Performance** — demand measurements first (Lighthouse, bundle analysis, profiler), then route
2. **Pin the version** from `package.json` — idioms flip between majors (React 18→19, Angular NgModules→standalone, Vue Options→Composition, Svelte 4 stores→5 runes)
3. **Recommend** with trade-offs and the conditions under which the recommendation changes

## Cross-Framework Fundamentals

### Rendering Models

| Model | How it works | Best for | Framework support |
|---|---|---|---|
| CSR (SPA) | Ship JS, render in browser | Auth-gated apps, dashboards | All |
| SSR | Render per-request on server, hydrate | Dynamic + SEO-critical | Next.js, Nuxt, Angular SSR, SvelteKit, Remix |
| SSG | Render at build time | Content that changes on deploy | Next.js, Astro, Gatsby, Nuxt |
| ISR / on-demand | Static + revalidation | Large content sets, mostly static | Next.js, Nuxt |
| Islands | Static HTML, hydrate only interactive islands | Content-heavy, low interactivity | Astro |
| RSC | Components run on server, no client JS shipped for them | Data-heavy React apps | React 19 + Next.js App Router |
| Hypermedia | Server returns HTML fragments over the wire | Server-rendered apps, minimal JS teams | htmx |

The decision drivers: content-to-interactivity ratio, SEO requirement, data freshness, and infrastructure (static host vs. server runtime).

### Reactivity Systems

| System | Mechanism | Frameworks |
|---|---|---|
| Virtual DOM diffing | Re-run render, diff, patch | React, (Vue partially) |
| Signals | Fine-grained dependency tracking, targeted updates | Angular 17+, Svelte 5 runes, SolidJS-style |
| Proxy-based | Track property access on reactive objects | Vue 3 |
| Compiler-driven | Reactivity resolved at build time | Svelte |

Practical consequence: VDOM frameworks need memoization discipline to avoid over-rendering; signal frameworks need dependency-tracking discipline (reading signals in the right scope).

### Framework Selection Criteria

Gather before recommending: content model (static/dynamic ratio), interactivity depth, SEO needs, team background (React talent pool vs. .NET shop → Blazor vs. minimal-JS preference → htmx), existing stack, and deployment target. Compare 2–3 candidates; recommend one with flip conditions. Fight hype: the boring framework the team knows usually ships faster than the exciting one it doesn't.

## Guardrails

- Never mix idioms across framework majors unless documenting a migration.
- No `dangerouslySetInnerHTML`/`v-html`/`innerHTML` guidance without an XSS warning and sanitization path.
- Accessibility is part of correct: interactive elements must be keyboard-operable and labeled.
- If unsure an API exists at a given version, read the version tree — never invent framework APIs.
