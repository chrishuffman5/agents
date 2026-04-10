# Web UI / Frontend Agent Library — Comprehensive Plan

Complete plan for the frontend domain agent hierarchy covering 11 technologies across 4 paradigms. Each technology includes version-specific features, configuration references, common patterns, and diagnostic guides.

---

## Domain Structure Overview

```
agents/frontend/
├── SKILL.md                              # Frontend domain router
├── references/
│   ├── concepts.md                       # Component models, rendering strategies, hydration, state management theory
│   ├── paradigm-component.md             # Component library paradigm (React, Vue, Svelte, Angular)
│   ├── paradigm-metaframework.md         # Meta-framework paradigm (Next.js, Nuxt, SvelteKit, Remix, Astro)
│   ├── paradigm-server-driven.md         # Server-driven paradigm (Blazor, HTMX)
│   └── build-tooling.md                  # Vite, Turbopack, Webpack, esbuild — cross-technology reference
│
├── react/                                # Component Library: React
├── angular/                              # Component Library: Angular
├── vue/                                  # Component Library: Vue.js
├── svelte/                               # Component Library + Framework: Svelte / SvelteKit
├── nextjs/                               # Meta-Framework: Next.js (React)
├── nuxt/                                 # Meta-Framework: Nuxt (Vue)
├── astro/                                # Meta-Framework: Astro (multi-framework)
├── remix/                                # Meta-Framework: Remix / React Router v7
├── blazor/                               # Server-Driven: Blazor (.NET)
├── htmx/                                 # Server-Driven: HTMX
└── gatsby/                               # Legacy: Gatsby (maintenance mode)
```

### Paradigm Classification

| Paradigm | Technologies | Philosophy |
|---|---|---|
| **Component Libraries** | React, Angular, Vue.js, Svelte | UI rendering primitives — need a meta-framework or custom setup for full-stack |
| **Meta-Frameworks** | Next.js, Nuxt, SvelteKit, Astro, Remix | Full-stack: routing, SSR, data fetching, deployment — built on component libraries |
| **Server-Driven** | Blazor, HTMX | UI rendered/managed primarily server-side (C#/.NET or HTML-over-the-wire) |
| **Legacy/Maintenance** | Gatsby | Static site generation, maintenance mode — migration guidance focus |

### Resource Strategy (instead of shell scripts)

Frontend agents use **configuration references, code patterns, and diagnostic guides** instead of shell scripts:

| Resource Type | Directory | Contents |
|---|---|---|
| **Configuration References** | `configs/` | Annotated config files (tsconfig.json, vite.config.ts, next.config.ts, etc.) with recommended settings |
| **Code Patterns** | `patterns/` | Common implementation patterns (data fetching, auth, forms, state management) as documented recipes |
| **Diagnostic Guides** | `diagnostics/` | Troubleshooting checklists for build errors, hydration mismatches, performance issues |

---

## 1. React

### Versions (as of April 2026)

| Version | Released | Status | Notes |
|---|---|---|---|
| React 18 | Mar 2022 | **No formal LTS — support ended Dec 2024** | Still widely deployed; agent covers migration path to 19 |
| React 19 | Dec 2024 | **Current** (19.2.x) | Only actively supported version |

*Note: React has no formal LTS program. React 18 security backports are case-by-case, not guaranteed.*

### React 19 — Key Features (vs 18)

- **Actions** — async functions in transitions, `<form action={asyncFn}>` native support
- **New Hooks**: `useActionState`, `useOptimistic`, `useFormStatus`, `use(promise|context)`
- **React Compiler 1.0** — automatic memoization (eliminates manual useMemo/useCallback/React.memo)
- **Server Components (stable)** — `"use server"` / `"use client"` directives
- **Document/Resource APIs** — native `<title>`, `<meta>`, `<link>` in components, auto-hoisted to `<head>`
- **ref as prop** — no more `forwardRef` wrapper
- **Removed**: `defaultProps` on function components, `propTypes`, string refs, legacy context API

### React — Key Feature Deep-Dives

| Feature | Warrants Sub-Agent? | Rationale |
|---|:---:|---|
| **Server Components** | Yes | Complex rendering model, client/server boundary, serialization constraints, data fetching patterns |
| **React Compiler** | No | Covered in version agent — it's a build tool config, not a runtime architecture |
| **State Management** | No | Covered in domain-level reference (spans multiple frameworks) |
| **Testing (RTL/Vitest)** | No | Covered in best-practices reference |

### React — Directory Structure

```
agents/frontend/react/
├── SKILL.md                              # Technology agent — React 18 + 19
├── references/
│   ├── architecture.md                   # Component model, virtual DOM, reconciliation, fiber, hooks
│   ├── best-practices.md                 # Component patterns, performance, accessibility, testing
│   └── diagnostics.md                    # Hydration errors, render debugging, profiler, DevTools
├── configs/
│   ├── tsconfig.json                     # Recommended TypeScript config for React projects
│   └── vite.config.ts                    # Vite config with React plugin, HMR, proxy
├── patterns/
│   ├── data-fetching.md                  # Suspense, use(), TanStack Query, SWR patterns
│   ├── forms.md                          # Actions, useActionState, controlled vs uncontrolled
│   └── state-management.md              # Context+useReducer, Zustand, Jotai, Redux Toolkit
│
├── 18/
│   └── SKILL.md                          # React 18: concurrent features, migration to 19
├── 19/
│   └── SKILL.md                          # React 19: Actions, Compiler, Server Components, new hooks
│
└── server-components/                    # Feature sub-agent
    ├── SKILL.md                          # RSC rendering model, boundaries, serialization
    └── references/
        ├── architecture.md               # Server/client component tree, streaming, Suspense integration
        └── patterns.md                   # Data fetching in RSC, composition patterns, "use client" placement
```

### React — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | React-Architecture | Component model, virtual DOM, fiber, hooks, reconciliation, concurrent features |
| R2 | React-18 | Concurrent rendering, Suspense, transitions, migration to 19, deprecations |
| R3 | React-19 | Actions, Compiler 1.0, new hooks, ref-as-prop, document APIs, removed features |
| R4 | React-ServerComponents | RSC rendering model, client/server boundary, streaming, serialization, "use client"/"use server" |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | React-Writer | All SKILL.md files, references, configs, patterns, RSC sub-agent |

---

## 2. Angular

### Versions (as of April 2026)

| Version | Released | LTS Ends | Status |
|---|---|---|---|
| Angular 19 | Nov 2024 | May 2026 | **LTS (near EOL)** |
| Angular 20 | May 2025 | Nov 2026 | **LTS** |
| Angular 21 | Nov 2025 | May 2027 | **Active (current)** |

*Release cadence: 2 major versions per year. Each gets 6mo active + 12mo LTS = 18mo total.*

### Version Feature Progression

- **Angular 19**: Signals (linkedSignal, resource() experimental), incremental hydration (dev preview), route-level render mode (dev preview), event replay (stable), standalone components default
- **Angular 20**: All signal APIs stable, zoneless (dev preview → stable in 20.2), incremental hydration stable (40-50% LCP improvement), template HMR stable, route-level render mode stable
- **Angular 21**: Zoneless by default for new projects, Signal Forms (experimental), Vitest default test runner (Karma removed), `@angular/aria` (headless accessible components), Tailwind default, HammerJS removed

### Angular — Key Feature Deep-Dives

| Feature | Warrants Sub-Agent? | Rationale |
|---|:---:|---|
| **Signals** | Yes | Core reactive primitive replacing Zone.js — fundamental architecture shift across 3 versions |
| **SSR/Hydration** | No | Covered in version agents (incremental hydration, event replay, route-level render mode) |
| **Testing Migration** | No | Covered in best-practices (Karma → Vitest) |

### Angular — Directory Structure

```
agents/frontend/angular/
├── SKILL.md                              # Technology agent — Angular 19/20/21
├── references/
│   ├── architecture.md                   # Modules→Standalone, DI, change detection, zones, compiler
│   ├── best-practices.md                 # Component patterns, RxJS, testing (Vitest), performance
│   └── diagnostics.md                    # Build errors, change detection debugging, SSR hydration issues
├── configs/
│   ├── tsconfig.json                     # Angular TypeScript config
│   ├── angular.json                      # Workspace/project config reference
│   └── eslint.config.js                  # ESLint flat config for Angular
├── patterns/
│   ├── signals.md                        # signal(), computed(), effect(), linkedSignal(), resource()
│   ├── standalone-migration.md           # NgModules → Standalone migration guide
│   └── ssr-hydration.md                  # Route-level render mode, incremental hydration, event replay
│
├── 19/
│   └── SKILL.md                          # Angular 19: signals experimental, incremental hydration preview
├── 20/
│   └── SKILL.md                          # Angular 20: signals stable, zoneless dev preview→stable
├── 21/
│   └── SKILL.md                          # Angular 21: zoneless default, Signal Forms, Vitest, @angular/aria
│
└── signals/                              # Feature sub-agent
    ├── SKILL.md                          # Signals reactive system deep-dive
    └── references/
        ├── architecture.md               # Signal graph, computed, effect, zoneless change detection
        └── migration.md                  # Zone.js → Zoneless migration, RxJS interop (toSignal/toObservable)
```

### Angular — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | Angular-Architecture | DI, change detection, zones, compiler (esbuild/Vite), standalone |
| R2 | Angular-19 | Signals experimental, incremental hydration preview, route-level render |
| R3 | Angular-20 | Signals stable, zoneless, template HMR, async redirects |
| R4 | Angular-21 | Zoneless default, Signal Forms, Vitest, @angular/aria, CLI MCP |
| R5 | Angular-Signals | Signal graph, computed, effect, linkedSignal, resource, zoneless migration |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | Angular-Writer | All SKILL.md files, references, configs, patterns, Signals sub-agent |

---

## 3. Vue.js

### Versions

| Version | Released | Status |
|---|---|---|
| Vue 3.5 "Tengen Toppa Gurren Lagann" | Sep 2024 | **Current stable** |
| Vue 3.6 (Vapor Mode) | Beta ~Dec 2025 | **Beta** — stable expected 2026 |

*Vue has no formal LTS. Core team maintains latest minor. Vue 2 EOL was Dec 31, 2023.*

### Vue 3.5 Key Features
- **Reactive Props Destructure** — stable, replaces `withDefaults()`
- **Reactivity refactor** — 56% memory reduction, 10x faster large arrays
- **useTemplateRef()** — dynamic template refs via runtime string ID
- **useId()** — stable unique IDs across SSR/client
- **Lazy Hydration** — `defineAsyncComponent()` with hydration strategies (idle, visible, interaction, media query)
- **defineModel** — stable two-way binding macro
- **Deferred Teleport** — `<Teleport defer>` resolves ordering issues
- **Custom Elements** — enhanced `defineCustomElement()` with app config, useHost(), useShadowRoot()

### Vue 3.6 (Beta) — Vapor Mode
- **Vapor Mode** — opt-in per-component compilation to direct DOM manipulation (no virtual DOM)
- Requires Composition API + `<script setup>` (Options API not supported in Vapor)
- Performance comparable to Solid.js and Svelte 5
- VDOM and Vapor components coexist via `vaporInteropPlugin`
- **Alien Signals** — core reactivity rebuilt for performance

### Vue — Directory Structure

```
agents/frontend/vue/
├── SKILL.md                              # Technology agent — Vue 3.5+
├── references/
│   ├── architecture.md                   # Reactivity system, virtual DOM, compiler, SFC, Vapor mode
│   ├── best-practices.md                 # Composition API patterns, Pinia, TypeScript, testing
│   └── diagnostics.md                    # Reactivity debugging, hydration mismatches, DevTools
├── configs/
│   ├── tsconfig.json                     # Vue TypeScript config (vue-tsc)
│   ├── vite.config.ts                    # Vite + @vitejs/plugin-vue config
│   └── eslint.config.js                  # ESLint flat config with vue plugin
├── patterns/
│   ├── composition-api.md                # ref, reactive, computed, watch, composables, provide/inject
│   ├── pinia.md                          # Store patterns (options vs setup), SSR, DevTools
│   └── typescript.md                     # defineProps<T>, defineEmits<T>, defineModel<T>, generics
│
└── 3.5/
    └── SKILL.md                          # Vue 3.5: reactive props destructure, useTemplateRef, lazy hydration
```

*No feature sub-agents — Vue's Vapor Mode is covered in version/architecture references. Nuxt handles SSR deep-dive.*

### Vue — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | Vue-Architecture | Reactivity system, virtual DOM, SFC compiler, Vapor mode, ecosystem |
| R2 | Vue-3.5 | New features, defineModel, useTemplateRef, lazy hydration, custom elements |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | Vue-Writer | SKILL.md, references, configs, patterns, version agent |

---

## 4. Svelte / SvelteKit

### Versions

| Component | Version | Status |
|---|---|---|
| Svelte | 5.x (runes) | **Current** |
| SvelteKit | 2.x | **Current** |

*Single actively supported version. Svelte 4 → 5 migration is the key upgrade path.*

### Key Features
- **Runes**: `$state`, `$derived`, `$effect`, `$props`, `$bindable`, `$inspect` — compiler-level reactivity replacing Svelte 4's implicit model
- **SvelteKit**: File-based routing (+page.svelte, +layout.svelte, +server.js), load functions, form actions, SSR/SSG/CSR per-route, adapters (node, static, vercel, cloudflare, netlify)
- **No Virtual DOM** — compiler generates optimized vanilla JS
- **Transitions/Animations** — built-in transition directives

### Svelte — Directory Structure

```
agents/frontend/svelte/
├── SKILL.md                              # Technology agent — Svelte 5 + SvelteKit 2
├── references/
│   ├── architecture.md                   # Compiler model, runes, no-VDOM, SvelteKit routing
│   ├── best-practices.md                 # Runes patterns, load functions, form actions, adapters
│   └── diagnostics.md                    # Compiler errors, SSR issues, migration from Svelte 4
├── configs/
│   ├── svelte.config.js                  # SvelteKit config (adapter, preprocess, alias)
│   ├── vite.config.ts                    # Vite + SvelteKit plugin
│   └── tsconfig.json                     # TypeScript config for SvelteKit
├── patterns/
│   ├── runes.md                          # $state, $derived, $effect patterns and migration from Svelte 4
│   ├── routing.md                        # +page, +layout, +server, +error, load functions, form actions
│   └── deployment.md                     # Adapter selection, SSR vs SSG vs CSR, environment variables
```

*No version agents (single supported version). No feature sub-agents.*

### Svelte — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | Svelte-Full | Runes, SvelteKit routing, load functions, form actions, adapters, Svelte 4→5 migration |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | Svelte-Writer | SKILL.md, references, configs, patterns |

---

## 5. Next.js

### Versions

| Version | Released | Status | EOL |
|---|---|---|---|
| Next.js 15 | Oct 2024 | **Maintenance LTS** | Oct 2026 |
| Next.js 16 | Oct 2025 | **Active LTS (current)** | Until Next.js 17 |

### Version Feature Progression

- **Next.js 15**: Turbopack Dev stable, React 19 support, async request APIs (breaking), caching defaults reversed, `<Form>` component, `instrumentation.js` stable, `next.config.ts`, self-hosting improvements
- **Next.js 16**: Turbopack stable (dev + prod, default bundler), React Compiler stable integration, Cache Components (`"use cache"` replacing PPR/dynamicIO), `proxy.ts` replacing `middleware.ts`, simplified `create-next-app`, Node.js 20+ required, AMP removed

### Next.js — Key Feature Deep-Dives

| Feature | Warrants Sub-Agent? | Rationale |
|---|:---:|---|
| **App Router** | Yes | Complex routing model with RSC, layouts, loading states, parallel routes, intercepting routes |
| **Turbopack** | No | Covered in version agents — it's a build tool, not an architecture |
| **Cache Components** | No | Covered in Next.js 16 version agent |

### Next.js — Directory Structure

```
agents/frontend/nextjs/
├── SKILL.md                              # Technology agent — Next.js 15 + 16
├── references/
│   ├── architecture.md                   # App Router, rendering pipeline, RSC integration, caching model
│   ├── best-practices.md                 # Data fetching, ISR, image/font optimization, self-hosting
│   └── diagnostics.md                    # Build errors, hydration issues, caching gotchas, Turbopack migration
├── configs/
│   ├── next.config.ts                    # Annotated Next.js config (v16 format)
│   ├── tsconfig.json                     # TypeScript paths, module resolution
│   └── middleware.ts                     # Middleware → proxy.ts migration reference
├── patterns/
│   ├── data-fetching.md                  # Server Components fetch, Server Actions, Cache Components
│   ├── authentication.md                 # NextAuth/Auth.js, middleware auth, session patterns
│   └── deployment.md                     # Vercel vs self-hosting, standalone output, ISR on self-hosted
│
├── 15/
│   └── SKILL.md                          # Next.js 15: Turbopack dev, async APIs, caching reversed
├── 16/
│   └── SKILL.md                          # Next.js 16: Turbopack prod, Cache Components, proxy.ts
│
└── app-router/                           # Feature sub-agent
    ├── SKILL.md                          # App Router deep-dive
    └── references/
        ├── routing.md                    # Layouts, loading, error, parallel routes, intercepting routes
        ├── rendering.md                  # RSC, streaming, static/dynamic, Cache Components
        └── migration.md                  # Pages Router → App Router migration guide
```

### Next.js — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | NextJS-Architecture | App Router, rendering pipeline, caching model, RSC integration |
| R2 | NextJS-15 | Async APIs, caching changes, Turbopack dev, Form component |
| R3 | NextJS-16 | Turbopack prod, Cache Components, proxy.ts, React Compiler, removals |
| R4 | NextJS-AppRouter | Routing model, layouts, parallel/intercepting routes, Pages→App migration |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | NextJS-Writer | All SKILL.md files, references, configs, patterns, App Router sub-agent |

---

## 6. Nuxt

### Versions

| Version | Released | Status | EOL |
|---|---|---|---|
| Nuxt 3.x | Nov 2022 | **Maintenance** | Jul 2026 |
| Nuxt 4.0 | Jul 2025 | **Current** | — |

### Key Differences (3 → 4)
- `app/` directory structure (source separated from project root)
- Separate TypeScript configs per context (app, server, shared, build)
- `shared/` folder for cross-context types/utils
- `shallowRef` for component reactivity (performance)
- `useAsyncData` shared keys share state refs
- Nuxt 2 compatibility removed from `@nuxt/kit`

### Nuxt — Directory Structure

```
agents/frontend/nuxt/
├── SKILL.md                              # Technology agent — Nuxt 3 + 4
├── references/
│   ├── architecture.md                   # Nitro server engine, auto-imports, file-based routing, modules
│   ├── best-practices.md                 # Data fetching (useFetch/useAsyncData), composables, deployment
│   └── diagnostics.md                    # Build errors, hydration, data fetching gotchas, module conflicts
├── configs/
│   ├── nuxt.config.ts                    # Annotated Nuxt config (v4 format)
│   └── tsconfig.json                     # Nuxt TypeScript config
├── patterns/
│   ├── data-fetching.md                  # useFetch vs useAsyncData vs $fetch, lazy, server-only
│   ├── server-routes.md                  # Nitro API routes, middleware, event handlers
│   └── module-development.md             # @nuxt/kit, defineNuxtModule, module hooks
│
├── 3/
│   └── SKILL.md                          # Nuxt 3: original structure, migration to 4
└── 4/
    └── SKILL.md                          # Nuxt 4: app/ directory, shared/, TypeScript separation
```

*No feature sub-agents — Nitro is covered in architecture reference.*

### Nuxt — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | Nuxt-Architecture | Nitro, auto-imports, routing, modules, DevTools |
| R2 | Nuxt-Versions | 3→4 migration, directory changes, TypeScript improvements |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | Nuxt-Writer | SKILL.md, references, configs, patterns, version agents |

---

## 7. Astro

### Versions

| Version | Released | Status |
|---|---|---|
| Astro 5.x | Dec 2024 | **Current** |

*Astro 6 may be released by the time agents are built — plan accommodates.*

### Key Features
- **Islands Architecture** — static HTML by default, selective hydration via `client:*` directives
- **Server Islands (v5)** — `server:defer` for on-demand server rendering of individual components
- **Content Layer API (v5)** — unified type-safe data from any source (files, CMS, APIs)
- **Multi-Framework** — React, Vue, Svelte, Solid, Preact, Alpine in same project
- **View Transitions** — built-in page transitions
- **Actions** — type-safe server-side mutation handlers
- **`astro:env`** — type-safe environment variables

### Astro — Directory Structure

```
agents/frontend/astro/
├── SKILL.md                              # Technology agent — Astro 5+
├── references/
│   ├── architecture.md                   # Islands, content layer, rendering modes, multi-framework
│   ├── best-practices.md                 # Content collections, image optimization, SSR adapters
│   └── diagnostics.md                    # Build errors, hydration issues, content layer debugging
├── configs/
│   ├── astro.config.mjs                  # Annotated Astro config (integrations, output, adapter)
│   └── tsconfig.json                     # Astro TypeScript config
├── patterns/
│   ├── islands.md                        # Client directives, server islands, hydration strategies
│   ├── content-layer.md                  # Collections, loaders (glob, file, custom), schemas, rendering
│   └── multi-framework.md               # Mixing React+Vue+Svelte, when and how, shared state
│
└── 5/
    └── SKILL.md                          # Astro 5: Server Islands, Content Layer API, astro:env
```

### Astro — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | Astro-Full | Islands architecture, Content Layer, Server Islands, multi-framework, Actions |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | Astro-Writer | SKILL.md, references, configs, patterns, version agent |

---

## 8. Remix / React Router v7

### Status

Remix as a standalone framework is **effectively superseded by React Router v7** (released Dec 2024). "The latest version of Remix is now React Router v7." New projects should use React Router v7 directly.

| Version | Status |
|---|---|
| Remix 2.x | **Superseded** — upgrade to React Router v7 |
| React Router v7 | **Current** — contains all Remix features |

### Key Concepts (applicable to both)
- **Nested Routes** — route tree with `<Outlet/>`, each route owns data/error/loading
- **Loaders/Actions** — server-side data fetching and mutations
- **Progressive Enhancement** — `<Form>` works without JS
- **File-Based Routing** — convention-based or `routes.ts` config
- **Vite** — primary bundler

### Remix — Directory Structure

```
agents/frontend/remix/
├── SKILL.md                              # Technology agent — Remix 2 / React Router v7
├── references/
│   ├── architecture.md                   # Nested routes, loaders/actions, progressive enhancement
│   ├── best-practices.md                 # Data flow, form handling, error boundaries, deployment
│   └── diagnostics.md                    # Route errors, loader failures, hydration, migration issues
├── configs/
│   ├── react-router.config.ts            # React Router v7 config
│   ├── routes.ts                         # Route configuration (replacing file-system convention)
│   └── vite.config.ts                    # Vite config with React Router plugin
├── patterns/
│   ├── data-loading.md                   # Loaders, clientLoader, defer, streaming
│   ├── forms.md                          # Actions, clientAction, progressive enhancement
│   └── migration.md                      # Remix v2 → React Router v7 migration guide
```

*No version agents — single current version. No feature sub-agents.*

### Remix — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | Remix-Full | Nested routes, loaders/actions, Remix→RR v7 migration, deployment |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | Remix-Writer | SKILL.md, references, configs, patterns |

---

## 9. Blazor

### Versions (tied to .NET)

| .NET Version | Released | Status | Blazor Key Features |
|---|---|---|---|
| .NET 8 | Nov 2023 | **LTS** (until Nov 2026) | Render modes (Static SSR, Server, WASM, Auto), streaming, QuickGrid |
| .NET 9 | Nov 2024 | **STS** (until May 2026) | Constructor injection, RendererInfo, WebSocket compression, MapStaticAssets |
| .NET 10 | Nov 2025 | **LTS (current)** | `[PersistentState]`, circuit persistence, reconnect modal, passkeys, 76% smaller blazor.web.js |

### Blazor Render Modes

| Mode | Where | Connection | Use Case |
|---|---|---|---|
| Static SSR | Server | None | Content pages, SEO, forms |
| Interactive Server | Server | SignalR WebSocket | Low-latency, thin client, internal apps |
| Interactive WebAssembly | Browser | None (after download) | Offline-capable, client-heavy, PWA |
| Interactive Auto | Server → Browser | SignalR → WASM transition | Best of both (fast start + offline eventual) |

### Blazor — Directory Structure

```
agents/frontend/blazor/
├── SKILL.md                              # Technology agent — Blazor across .NET 8/9/10
├── references/
│   ├── architecture.md                   # Render modes, Razor components, DI, SignalR, WASM runtime
│   ├── best-practices.md                 # Mode selection, state management, JS interop, performance
│   └── diagnostics.md                    # Connection issues, WASM download, render mode debugging
├── configs/
│   ├── Program.cs                        # Annotated Blazor Web App startup config
│   └── csproj-reference.xml              # Project file settings (WASM AOT, trimming, compression)
├── patterns/
│   ├── render-modes.md                   # Mode selection decision tree, per-component configuration
│   ├── state-management.md               # Scoped services, PersistentComponentState, cascading params
│   └── js-interop.md                     # IJSRuntime, module isolation, bidirectional calls
│
├── dotnet-8/
│   └── SKILL.md                          # .NET 8: render mode system, streaming, QuickGrid
├── dotnet-9/
│   └── SKILL.md                          # .NET 9: constructor injection, RendererInfo, WebSocket compression
└── dotnet-10/
    └── SKILL.md                          # .NET 10: PersistentState, circuit persistence, passkeys, size reduction
```

### Blazor — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | Blazor-Architecture | Render modes, Razor components, DI, SignalR, WASM |
| R2 | Blazor-DotNet8 | Render mode system, streaming, enhanced navigation |
| R3 | Blazor-DotNet9-10 | .NET 9 improvements + .NET 10 PersistentState, circuit persistence |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | Blazor-Writer | All SKILL.md files, references, configs, patterns |

---

## 10. HTMX

### Version

| Version | Released | Status |
|---|---|---|
| HTMX 2.0 | Jun 2024 | **Current** |

### Philosophy
HTML-over-the-wire. Any element can issue HTTP requests, triggered by any event. Server returns HTML fragments, not JSON. No build step. HATEOAS-aligned.

### Key Features
- Core attributes: `hx-get/post/put/patch/delete`, `hx-trigger`, `hx-target`, `hx-swap`, `hx-boost`
- Swap strategies: innerHTML, outerHTML, beforebegin, afterbegin, beforeend, afterend, delete, none
- Out-of-band swaps (`hx-swap-oob`) — update multiple DOM elements from single response
- Extensions (separate repo): SSE, WebSocket, head-support, response-targets, preload, loading-states, Idiomorph morphing
- Works with ANY backend (Django, Flask, Rails, ASP.NET, Go, Express, FastAPI)

### HTMX — Directory Structure

```
agents/frontend/htmx/
├── SKILL.md                              # Technology agent — HTMX 2.0
├── references/
│   ├── architecture.md                   # HTML-over-the-wire model, HATEOAS, attribute reference
│   ├── best-practices.md                 # Progressive enhancement, swap strategies, OOB patterns
│   └── diagnostics.md                    # Request debugging, swap issues, extension conflicts, CORS
├── patterns/
│   ├── swap-strategies.md                # innerHTML vs outerHTML vs morph, OOB updates, infinite scroll
│   ├── backend-integration.md            # Django+HTMX, Flask+HTMX, Rails+HTMX, ASP.NET+HTMX patterns
│   └── progressive-enhancement.md        # hx-boost, graceful degradation, HX-Request detection
```

*No version agents (single version). No feature sub-agents. No configs directory (no build step).*

### HTMX — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | HTMX-Full | Attributes, swap strategies, OOB, extensions, backend pairings, progressive enhancement |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | HTMX-Writer | SKILL.md, references, patterns |

---

## 11. Gatsby

### Version

| Version | Status |
|---|---|
| Gatsby 5.x | **Maintenance mode** — effectively abandoned |

*Netlify acquired Gatsby Inc. (Feb 2023), team laid off (Aug 2023). Security fixes only. No roadmap. Plugin ecosystem degrading. Migration to Astro or Next.js recommended.*

### Gatsby — Directory Structure

```
agents/frontend/gatsby/
├── SKILL.md                              # Technology agent — Gatsby 5.x (maintenance/migration focus)
├── references/
│   ├── architecture.md                   # GraphQL data layer, build process, Slice API, plugin model
│   └── migration.md                      # Migration paths to Astro and Next.js
├── patterns/
│   ├── graphql.md                        # Source plugins, static queries, page queries, schema customization
│   └── migration-astro.md                # Step-by-step Gatsby → Astro migration
```

*Minimal agent — focuses on maintaining existing projects and migration planning. No version agents, no sub-agents, no configs.*

### Gatsby — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | Gatsby-Full | GraphQL data layer, plugin ecosystem health, migration paths |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | Gatsby-Writer | SKILL.md, references, patterns |

---

## Execution Strategy

### Approach: Batch by Complexity

Frontend technologies vary significantly in scope. Group by effort:

**Tier 1 — Heavy (4-5 research + dedicated writer):**
- React (4 research agents — includes RSC sub-agent)
- Angular (5 research agents — 3 versions + Signals sub-agent)
- Next.js (4 research agents — includes App Router sub-agent)

**Tier 2 — Medium (2-3 research, combined writer):**
- Vue.js (2 research)
- Nuxt (2 research)
- Blazor (3 research — 3 .NET versions)
- Svelte (1 research)

**Tier 3 — Light (1 research, combined writer):**
- Astro (1 research)
- Remix (1 research)
- HTMX (1 research)
- Gatsby (1 research)

### Recommended Execution Waves

| Wave | Technologies | Research Agents | Writer Agents | Rationale |
|---|---|:---:|:---:|---|
| 1 | React + Next.js | 8 | 2 | Tightly coupled (Next.js is React's primary meta-framework); RSC shared |
| 2 | Angular | 5 | 1 | Standalone ecosystem, 3 concurrent versions |
| 3 | Vue + Nuxt + Svelte | 5 | 2 | Vue+Nuxt tightly coupled; Svelte is standalone but light |
| 4 | Blazor + HTMX + Astro + Remix + Gatsby | 7 | 2 | Remaining technologies, batch for efficiency |

**After all waves:** Create the frontend domain-level agent (`agents/frontend/SKILL.md` + `references/`)

### Total Inventory

| Component | Count |
|---|---|
| **Technologies** | 11 |
| **Version agents** | 14 (2 React + 3 Angular + 1 Vue + 2 Next.js + 2 Nuxt + 1 Astro + 3 Blazor) |
| **Feature sub-agents** | 3 (React Server Components, Angular Signals, Next.js App Router) |
| **Reference files** | ~40 |
| **Config references** | ~20 |
| **Pattern guides** | ~30 |
| **Research agents needed** | ~25 (Sonnet 4.6) |
| **Writer agents needed** | ~7 (Opus 4.6) |

### Cross-References (avoid duplication)

| Topic | Primary Agent | Cross-Referenced From |
|---|---|---|
| React core | `frontend/react/` | Next.js, Remix, Astro (React islands), Gatsby |
| Vue core | `frontend/vue/` | Nuxt |
| Svelte core | `frontend/svelte/` | (SvelteKit is part of svelte agent) |
| SSR/Hydration theory | `frontend/references/concepts.md` | All meta-frameworks |
| Build tooling (Vite/Turbopack) | `frontend/references/build-tooling.md` | React, Vue, Svelte, Next.js, Nuxt, Astro, Remix |
| State management theory | `frontend/references/concepts.md` | React (Redux/Zustand), Vue (Pinia), Angular (Signals) |
| TypeScript config | Per-technology `configs/tsconfig.json` | — |

---

## Notes

- **No shell diagnostic scripts** — frontend agents use config references, code patterns, and diagnostic guides instead
- **Version churn is faster** than OS domain (6-12 month cycles) — agents should note "verify current version" more prominently
- **React 18 has no formal LTS** — included because it's widely deployed, but agent emphasizes migration to 19
- **Remix is now React Router v7** — agent covers both names for discoverability
- **Gatsby is maintenance mode** — agent is intentionally minimal, focused on migration
- **Vue 3.6 Vapor Mode is beta** — covered in architecture reference, not a version agent until stable
- **Angular has fastest version cadence** (2/year) — 3 concurrent versions, oldest nearing EOL
- Feature sub-agents reserved for architectural shifts that span multiple versions or require deep understanding:
  - React Server Components (new rendering paradigm)
  - Angular Signals (replacing Zone.js — multi-version migration)
  - Next.js App Router (complex routing model with RSC integration)
