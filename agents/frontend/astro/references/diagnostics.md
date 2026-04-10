# Astro Diagnostics Reference

Troubleshooting guide for build errors, hydration issues, content layer debugging, and multi-framework conflicts.

---

## Build Errors

| Error | Cause | Fix |
|---|---|---|
| `Cannot find module 'astro:content'` | Wrong import or missing config | Ensure `src/content.config.ts` exists and exports `collections` |
| Schema validation error on frontmatter | Frontmatter does not match Zod schema | Check field types; use `z.coerce.date()` for dates |
| `getStaticPaths` required | Dynamic route in static mode with no paths | Export `getStaticPaths()` or set `prerender = false` |
| Adapter not found | SSR output with no adapter | Run `npx astro add <adapter>` |
| `process is not defined` | Node.js API used in client bundle | Move to server-only context or use `import.meta.env` |

### First-Pass Fix for Any Build Failure

```bash
rm -rf node_modules .astro dist
npm install
npm run build
```

---

## Hydration Issues

### "Server HTML does not match client"

Component renders differently on server vs client. Common causes: `Math.random()`, `Date.now()`, or `typeof window` checks that alter output. Fix: use `client:only` if the component must differ, or ensure deterministic SSR output.

### Component Not Interactive

Missing `client:*` directive. Astro silently renders static HTML. Add the appropriate directive.

### Island Hydrates but Crashes

Check browser console for JS errors. Use `client:only="react"` to confirm it is not an SSR incompatibility. Check that props are serializable (no functions, no class instances).

---

## Content Layer Debugging

- Run `astro build --verbose` to see loader execution and entry counts.
- Check `.astro/` directory for generated type definitions -- confirms collections are recognized.
- If entries are missing, verify the `glob()` pattern matches actual file paths.
- `store.clear()` in custom loaders ensures stale entries are removed on rebuild.

---

## Multi-Framework Conflicts

### Import Resolution Errors

Ensure each framework's integration is installed and listed in `integrations` in `astro.config.mjs`. Order matters: Astro processes integrations sequentially.

### JSX Pragma Conflicts

If React and Preact are both installed, scope them:

```javascript
integrations: [
  react({ include: ['**/react/**'] }),
  preact({ include: ['**/preact/**'] }),
]
```

### Svelte + React Hydration Interference

Islands are isolated, so state should not bleed. If it does, check that you are using nanostores (neutral store), not a framework-specific context provider.

### Alpine.js

Does not use `client:*` directives. Include via `<script>` tag or `@astrojs/alpinejs` integration. Keep Alpine out of Astro component hydration.

---

## Common Error Patterns

### Missing Collection Export

```
[ERROR] Cannot find collection "blog"
```

Ensure `src/content.config.ts` exports the collection in the `collections` object.

### Server Island Without Adapter

```
[ERROR] server:defer requires an SSR adapter
```

Server Islands need server-side rendering capability. Install an adapter even if the rest of the site is static.

### Environment Variable Not Available

```
[ERROR] Missing required environment variable: DATABASE_URL
```

Variables declared in `astro:env` schema are validated at build time. Set the variable in your environment or `.env` file.
