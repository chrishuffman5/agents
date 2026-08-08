# Component Architecture Guide

The full decision guide behind Phase 2 (what should each capability be, what is a plugin) and Phase 3 (migration mechanics). Facts about Claude Code plugin behavior below are distilled from the official docs via the ai plugin's source-traced `plugins` corpus; conventions are this repository's.

## Component placement

> Source: https://code.claude.com/docs/en/plugins-reference  (official)

### Skill — knowledge loaded on demand

The default component. A skill is a directory `skills/<name>/SKILL.md` whose frontmatter description is the trigger surface and whose body is guidance the model loads when the task matches.

- Choose when: the capability is knowledge, judgment, or a procedure the model applies with its normal tools.
- Not when: the behavior must happen every time without the model deciding (hook), or the work should run in a separate context with restricted tools (agent).
- Traps: the folder name is the invocation name — kebab-case, self-explanatory. Version-specific content is `references/versions/<v>.md`, never its own skill or a nested SKILL.md. Depth beyond ~500 body lines moves to `references/` with when-to-read pointers.

### Command — legacy flat skill

`commands/*.md` are flat-file skills. Prefer `skills/<name>/SKILL.md` for anything new — a directory can grow `references/`, `scripts/`, and `assets/`; a flat file cannot. Migrate commands to skills during a remodel unless the user vetoes the rename.

### Agent — a delegatable worker

`agents/*.md`, Markdown with YAML frontmatter (`name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation: worktree`).

- Choose when: work benefits from its own context window, its own model/effort tier, or a restricted tool surface; or the persona is something the main thread delegates to.
- Not when: the "agent" is really a body of knowledge — that is a skill. The repo convention: a domain specialist agent holds a *knowledge map* of its plugin's `skills/` tree and delegates depth to those skills; it never re-teaches the technology inline.
- Traps: plugin-shipped agents cannot declare `hooks`, `mcpServers`, or `permissionMode` (security restriction). Project `.claude/agents/` definitions override same-named plugin agents — migrations must delete the originals or the plugin copy is dead code. Cross-domain agents must not hardcode other plugins' file paths — delegate to the other plugin's specialist or degrade gracefully.

### Hook — deterministic lifecycle behavior

`hooks/hooks.json` at the plugin root. Hook types: `command`, `http`, `mcp_tool`, `prompt`, `agent`.

- Choose when: the behavior must ALWAYS happen on an event (format after edit, gate a permission, audit on stop) — enforcement belongs to the harness, not the model's memory.
- Not when: the behavior needs judgment about *whether* to act at all — that is a skill directive.
- Traps: a malformed `hooks.json` blocks the **entire plugin** from loading. Event names are case-sensitive (`PostToolUse`). Matchers against a plugin's own MCP server must use the scoped name `mcp__plugin_<plugin>_<server>__<tool>`. Scripts must be executable and referenced via `${CLAUDE_PLUGIN_ROOT}`.

### MCP server — tools that reach an external system

`.mcp.json` at the plugin root; servers start when the plugin enables.

- Choose when: the capability is API access to an external system as callable tools.
- Not when: a shell script in `bin/` or `scripts/` does the job — an MCP server is a process to run, version, and debug; a script is a file.
- Traps: check the official marketplace first — github, gitlab, atlassian, linear, notion, figma, vercel, firebase, supabase, slack, sentry integrations already exist. Use `${CLAUDE_PLUGIN_ROOT}` in every path. Credentials via `userConfig` prompts or env vars — never committed.

### LSP, monitors, bin/, settings.json, themes

- **LSP** (`.lsp.json`): only for languages the official LSP plugins do not cover; the binary must be on PATH.
- **Monitors** (`monitors/monitors.json`): long-running watchers whose stdout notifies the session. Interactive sessions only; project-scope skills-dir plugins do not load them at all.
- **`bin/`**: executables added to the Bash PATH while the plugin is enabled — the right home for CLIs the model should run.
- **`settings.json`** (plugin root): only `agent` (forces a plugin agent as the main thread) and `subagentStatusLine` are honored.
- **Themes / output styles**: cosmetic; bundle them only when the plugin's identity includes them.

## Plugin taxonomy

Skill = technology. Plugin = domain. Marketplace = catalog of domains.

| Shape | Choose when | Cost |
|---|---|---|
| Single plugin | One domain, one audience, installed as a unit | Simplest; one version for everything |
| Marketplace of plugins | Multiple domains, selective install, independent versioning/ownership | Catalog maintenance, per-plugin release discipline |
| Bundle plugin (`name` + `dependencies` only) | Curated "standard set" for a team composed from existing plugins | Dependency ranges must be constrained or upstream releases break installs |

- Never split by component type. A domain plugin carries its own skills, agents, hooks together — "the agents plugin" is an anti-pattern that breaks the install-one-domain story.
- Overlapping technologies across domains are legitimate — split by *angle* (kafka broker ops vs kafka pipelines) and give every overlapping skill's description a mutual Do-NOT clause naming the other. The overlap audit's output is this list.
- A plugin below ~3 skills with no agent or hook is usually a category inside a neighboring plugin, not a plugin.

## Namespacing and invocation stability

Plugin skills are always namespaced: `/plugin-name:skill-name`. Migrating from `.claude/` renames every invocation, and old unnamespaced copies left in `.claude/skills/` keep working alongside — remove them or users get double triggers. The plugin `name` is the namespace and install identity; `displayName` relabels UI without breaking anything, and `renames` (append-only) is the only safe way to truly rename a published plugin.

## Versioning and release strategy

> Source: https://code.claude.com/docs/en/plugin-marketplaces  (official)

Version is the cache key — resolution order is `plugin.json` > marketplace entry > git SHA. Two viable strategies; pick one per repo in the interview:

- **Explicit semver** in each `plugin.json`, nowhere else. Updates ship only on bump — so bump on *every* release, or users silently never receive fixes. Fits published, multi-consumer repos (this marketplace's choice).
- **Commit-SHA flow**: omit `version` everywhere; every push is an update. Fits fast-moving internal plugins.

Never set version in both `plugin.json` and the marketplace entry — `plugin.json` wins silently and masks catalog bumps. Keep a `CHANGELOG.md` per plugin for humans.

## Distribution and rollout

- **Marketplace repo**: `.claude-plugin/marketplace.json` at the repo root; plugin entries with relative `./plugins/<name>` sources. Never rely on `metadata.pluginRoot` — hosts that honor it double-resolve the path (this repo removed it after exactly that failure).
- **Team rollout**: project settings declare `extraKnownMarketplaces` + `enabledPlugins`; teammates are prompted on folder trust.
- **Skills-dir plugin**: a folder under `~/.claude/skills/` or `<repo>/.claude/skills/` with its own `.claude-plugin/plugin.json` loads in place as `<name>@skills-dir` — no marketplace, no install, but project-scope copies skip monitors and gate MCP/LSP behind trust. Good for dogfooding a plugin inside the repo that develops it.
- **Enterprise**: `strictKnownMarketplaces` allowlists what can be added; pair it with `extraKnownMarketplaces` in the same managed settings or locked-down users end up with nothing.

## Migration traps

> Source: https://code.claude.com/docs/en/plugins  (official)

1. Only `plugin.json` goes in `.claude-plugin/`. Components placed there silently vanish — the most common remodel failure.
2. Hooks move from `.claude/settings.json` to `hooks/hooks.json` in identical format; scripts move into the plugin and switch to `${CLAUDE_PLUGIN_ROOT}` paths.
3. `.claude/agents/` originals override same-named plugin agents; `.claude/skills/` originals coexist as duplicates. Delete both sets of originals after migrating.
4. A plugin-root `CLAUDE.md` is not loaded as context — ship repo instructions as a skill if they must travel with the plugin.
5. Never reference paths outside the plugin directory (`../shared`): install copies only the plugin folder into cache.
6. `${CLAUDE_PLUGIN_ROOT}` changes on every update — never write state there; persistent state goes in `${CLAUDE_PLUGIN_DATA}`.
7. Validate at every step: `claude plugin validate <root>` catches manifest, path, and `renames`-chain errors that otherwise surface as silent load failures. Test the assembled plugin with `claude --plugin-dir ./<plugin>` before publishing.

## Sources

- https://code.claude.com/docs/en/plugins  (official)
- https://code.claude.com/docs/en/plugins-reference  (official)
- https://code.claude.com/docs/en/plugin-marketplaces  (official)
- https://code.claude.com/docs/en/discover-plugins  (official)
- Distilled via the ai plugin's `plugins` skill corpus (fetched 2026-08-05) and this repository's conventions (CLAUDE.md, marketplace restructuring of 2026-07/08).

Fetched: 2026-08-05
