# `claude plugin` CLI, the `/plugin` UI, and debugging

Read this for exact subcommand flags, local development workflow, auto-update behavior, and the full validation error/warning catalog.

## Local testing with `--plugin-dir` / `--plugin-url`
> Source: https://code.claude.com/docs/en/plugins

```bash
claude --plugin-dir ./my-plugin
claude --plugin-dir ./my-plugin.zip                 # .zip requires v2.1.128+
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two
claude --plugin-url https://example.com/my-plugin.zip --plugin-url https://example.com/other.zip
claude --plugin-url "https://example.com/my-plugin.zip https://example.com/other.zip"
```

`--plugin-dir` loads a plugin for the session with no install. When it shares a name with an installed marketplace plugin, the **local copy wins for that session** — test changes without uninstalling. Exception: plugins that managed settings force-enable or force-disable cannot be overridden this way.

`--plugin-url` fetches a hosted `.zip` (e.g. a CI build artifact) at startup for that session only. If the archive cannot be fetched or is invalid, Claude Code starts without it and records a load error in the `/plugin` **Errors** tab. The same trust considerations as any plugin source apply.

After editing, `/reload-plugins` picks up changes without a restart: plugins, skills, agents, hooks, plugin MCP servers, plugin LSP servers. Verify:

- Skills: `/plugin-name:skill-name`
- Agents: `/context` under Custom Agents, or @-mention by scoped name
- Hooks: trigger the matching event; matched hooks, exit codes, and output are recorded in the debug log

## `claude plugin init`
> Source: https://code.claude.com/docs/en/plugins-reference

Scaffolds a plugin at `~/.claude/skills/<name>/`, loading automatically next session as `<name>@skills-dir` — no marketplace, no install step. Alias: `new`.

```bash
claude plugin init my-helper
claude plugin init my-helper --with skills hooks
claude plugin init my-helper --force
```

| Option | Description | Default |
|---|---|---|
| `--description <text>` | Manifest description | |
| `--author <name>` | Author name | `git config user.name` |
| `--author-email <email>` | Author email | `git config user.email` |
| `--with <components...>` | Also scaffold `skills`, `agents`, `hooks`, `mcp`, `lsp`, `output-style`, `channel` | |
| `-f, --force` | Overwrite an existing `.claude-plugin/` at the target | |

`--with` contents: `skills` adds a namespaced `<name>:example` skill; `agents` an `agents/` definition; `hooks` a `hooks/hooks.json` sample; `mcp` a `.mcp.json` with HTTP and stdio examples; `lsp` a `.lsp.json` example; `output-style` an `output-styles/<name>.md` that applies while enabled; `channel` an MCP-based channel (`server.ts` stdio server, `.mcp.json`, `package.json`).

Admins can block the `@skills-dir` source via `strictKnownMarketplaces`, or by adding `{"source": "skills-dir"}` to `blockedMarketplaces` — `plugin init` then fails before writing.

## Install, uninstall, prune, enable, disable, update
> Source: https://code.claude.com/docs/en/plugins-reference

```bash
claude plugin install <plugin> [-s user|project|local] [--config key=value]
claude plugin uninstall <plugin> [-s <scope>] [--keep-data] [--prune] [-y]   # aliases: remove, rm
claude plugin prune [-s <scope>] [--dry-run] [-y]                            # alias: autoremove
claude plugin enable <plugin> [-s <scope>]
claude plugin disable [plugin] [-a] [-s <scope>]
claude plugin update <plugin> [-s user|project|local|managed]
```

`<plugin>` is a plugin name or `plugin-name@marketplace-name`. Install default scope is `user`; `--scope project` writes `enabledPlugins` in `.claude/settings.json`, shared with everyone who clones the repo.

Uninstalling from the last remaining scope also deletes `${CLAUDE_PLUGIN_DATA}` — `--keep-data` preserves it (useful before reinstalling a new version to test). When same-named plugins exist in different marketplaces, the qualified `plugin-name@marketplace-name` form uninstalls only that marketplace's copy; before v2.1.212 it could match a same-named plugin from a different marketplace.

`enable` enables declared dependencies transitively at the same scope and fails if a dependency is not installed. `disable -a` disables all enabled plugins (not combinable with `--scope`) and fails while another enabled plugin depends on the target, printing a chained command to disable dependents first.

## `claude plugin list`
> Source: https://code.claude.com/docs/en/plugins-reference

```bash
claude plugin list [--json] [--available]
```

`--available` includes not-yet-installed marketplace plugins and requires `--json`. Plugins with dependency problems include an `errors` field in JSON output; clean plugins omit it.

Interactive `/plugin list` covers **marketplace-installed plugins only**:

- `@skills-dir` plugins appear in `/plugin` and `claude plugin list`, but not in inline `/plugin list`.
- `--plugin-dir` / `--plugin-url` session plugins appear in `/plugin`, and in `claude plugin list` only when the same flag precedes the subcommand: `claude --plugin-dir <dir> plugin list`. A bare `claude plugin list` will not show them.

The interactive form accepts `--enabled` / `--disabled` filters and `ls` as shorthand.

## `claude plugin details`
> Source: https://code.claude.com/docs/en/plugins-reference

```bash
claude plugin details <name>
```

Shows the full component inventory (Skills — including both `skills/` and `commands/` — Agents, Hooks, MCP servers, LSP servers) and two token-cost figures per component: **always-on** (added to every session by listing text, regardless of invocation) and **on-invoke** (paid each time the component fires; shown per component, not summed).

```text
dependency-guard 1.2.0
  Dependency analysis for Claude Code sessions
  Source: dependency-guard@example-marketplace

Component inventory
  Skills (2)  scan-dependencies, review-changes
  Agents (0)
  Hooks (1)  SessionStart  (harness-only — no model context cost)
  MCP servers (0)
  LSP servers (0)

Projected token cost
  Always-on:   ~180 tok   added to every session

Per-component (rounded)
  component            always-on  on-invoke
  scan-dependencies        ~100      ~2400
  review-changes            ~80      ~1800
```

The always-on total is computed via the `count_tokens` API for the active model, with per-component numbers proportionally scaled; it falls back to a character-based estimate when the API is unreachable.

## `claude plugin tag`
> Source: https://code.claude.com/docs/en/plugins-reference

```bash
claude plugin tag [path] [--push] [--dry-run] [-f] [-m <msg>] [--remote <name>]
```

Creates a release git tag named `{plugin-name}--v{version}`, the convention used for dependency version resolution. `[path]` defaults to the current directory; `-m` accepts a `%s` placeholder for the version; `--remote` defaults to `origin`. It validates plugin contents, checks `plugin.json`/marketplace-entry version agreement, requires a clean working tree under the plugin directory, and refuses if the tag exists. Manual equivalent: `git tag secrets-vault--v2.1.0`.

## Marketplace subcommands
> Source: https://code.claude.com/docs/en/plugin-marketplaces

```bash
claude plugin marketplace add <source> [--scope user|project|local] [--sparse <paths...>]
claude plugin marketplace list [--json]
claude plugin marketplace remove <name> [--scope <scope>]     # alias: rm
claude plugin marketplace update [name]
```

`<source>` is a GitHub `owner/repo` shorthand, a git URL, a remote URL to `marketplace.json`, or a local directory. Pin a ref with `@ref` (GitHub shorthand) or `#ref` (git URL). `--sparse` limits the checkout to specific directories via git sparse-checkout, for monorepos.

A URL must include its scheme: as of v2.1.196 a schemeless host (e.g. `gitlab.example.com/team/plugins`) is rejected as an invalid `owner/repo` shorthand with an error telling you to add `https://` or `./`. Earlier versions misread it as a GitHub path and fail at clone time.

```bash
claude plugin marketplace add acme-corp/claude-plugins
claude plugin marketplace add acme-corp/claude-plugins@v2.0
claude plugin marketplace add https://gitlab.example.com/team/plugins.git
claude plugin marketplace add ./my-marketplace
claude plugin marketplace add acme-corp/claude-plugins --scope project
claude plugin marketplace add acme-corp/monorepo --sparse .claude-plugin plugins
```

`list --json` entries include `name`, `source`, `installLocation` (local cache path), and source-specific fields — `repo`, `url`, or `path`, plus `ref` when pinned.

`remove <name>` takes the marketplace's `marketplace.json` `name`, not the add-time source. Without `--scope` it is removed from every editable scope; with `--scope`, shared state/cache/data are preserved if declared in another scope. **Warning**: removing from the last remaining scope also uninstalls plugins installed from it — use `marketplace update` to refresh without losing plugins.

`update [name]` with no name updates all. A marketplace added with a branch/tag `ref` updates to the latest commit of that ref, not the default branch. Both `remove` and `update` fail against a seed-managed marketplace; when updating all, seed entries are skipped and others still update.

## Interactive marketplace and plugin commands
> Source: https://code.claude.com/docs/en/discover-plugins

Shortcuts: `/plugin market` for `/plugin marketplace`, `rm` for `remove`.

```shell
/plugin marketplace add anthropics/claude-code
/plugin marketplace add https://gitlab.com/company/plugins.git
/plugin marketplace add git@gitlab.com:company/plugins.git
/plugin marketplace add https://gitlab.com/company/plugins.git#v1.0.0
/plugin marketplace add ./my-marketplace
/plugin marketplace add ./path/to/marketplace.json
/plugin marketplace add https://example.com/marketplace.json
/plugin list                 # --enabled / --disabled
/plugin enable  plugin-name@marketplace-name
/plugin disable plugin-name@marketplace-name
/plugin uninstall plugin-name@marketplace-name
```

For non-GitHub git URLs include the `.git` suffix so Claude Code clones the repo instead of treating the URL as a direct `marketplace.json` link, and include `https://`.

`plugin-name` in these commands is the **marketplace-entry** name, which can differ from `plugin.json`'s own `name`. As of v2.1.195 enable/disable work regardless of which of the two names differ and accept either; earlier versions report `already disabled` and leave it enabled.

## `/plugin` interactive UI
> Source: https://code.claude.com/docs/en/discover-plugins

Tabs (Tab / Shift+Tab to cycle): **Discover**, **Installed**, **Marketplaces**, **Errors**.

Discover detail pane, version-gated: **Context cost** estimate in tokens (v2.1.143+), **Last updated** date (v2.1.144+), **Will install** listing commands/agents/skills/hooks/MCP/LSP servers before install (v2.1.145+; local or custom marketplaces may show "Components will be discovered at installation").

Install scopes offered: **User** (all your projects), **Project** (all collaborators, written to `.claude/settings.json`), **Local** (you, this repo only). Managed-scope plugins are shown read-only.

If an install target is not found locally: with marketplace auto-update **on**, Claude Code refreshes the catalog once and retries before reporting not-found; with it **off**, refresh manually with `/plugin marketplace update <name>`. Before v2.1.221 it reported not-found without refreshing.

Install summary states: `Plugin is now active.`; `Run /reload-plugins to activate.` (activation would invalidate the prompt cache, or failed); or a failure with detail in the **Errors** tab. Before v2.1.221 no install took effect in-session until `/reload-plugins` or restart. The shell command `claude plugin install` never activates in a running session — plugins load next launch or on `/reload-plugins`.

**Installed tab**: grouped by scope, sorted with load-error/unresolved-dependency plugins first, then favorites, then a collapsed disabled section. `f` favorites, typing filters, Enter opens detail. Uninstalling a plugin that a project's `.claude/settings.json` enables asks which scope — disable for yourself (writes an override to `.claude/settings.local.json`) or uninstall for everyone (removes it from the shared file). Requires v2.1.203+.

**"Not used recently"**: marketplace plugins installed but unused for ≥2 weeks over ≥10 sessions, under a collapsed header with a "Last used" line (v2.1.187+). Never listed: org-managed plugins, `--plugin-dir` plugins, or plugins contributing only a theme/output-style/monitor/workflow. An LSP plugin's server counts as used when it delivers diagnostics or answers a navigation request (v2.1.203+). The group is hidden entirely when `strictKnownMarketplaces` is set.

**Reload cost**: `/reload-plugins` costs tokens on the next request, because newly loaded components announce themselves in appended content while existing history still reads from cache. A plugin providing MCP servers whose tools are not deferred by tool search costs more — cache invalidation forces re-reading the whole conversation — and in that case the command warns and does **not** apply unless you pass `--force`.

## Auto-updates
> Source: https://code.claude.com/docs/en/discover-plugins

Background refresh runs after session start with a random delay up to **10 minutes**; the running session keeps using launch-time versions. If plugins updated you are notified to `/reload-plugins`, or new versions load next launch.

Toggle per marketplace in `/plugin` → **Marketplaces** → **Enable/Disable auto-update**. Official Anthropic marketplaces default **on**; third-party and local dev marketplaces default **off**. Admins can force it org-wide with `"autoUpdate": true` on an `extraKnownMarketplaces` entry in managed settings.

`DISABLE_AUTOUPDATER` disables *all* automatic updates including Claude Code's own. To keep plugin auto-updates while disabling the CLI's:

```bash
export DISABLE_AUTOUPDATER=1
export FORCE_AUTOUPDATE_PLUGINS=1
```

## Debugging
> Source: https://code.claude.com/docs/en/plugins-reference

`claude --debug` shows which plugins are loading, manifest errors, skill/agent/hook registration, and MCP server initialization.

| Issue | Cause | Solution |
|---|---|---|
| Plugin not loading | Invalid `plugin.json` | `claude plugin validate ./my-plugin` or `/plugin validate ./my-plugin` |
| Skills not appearing | Wrong directory structure | `skills/`/`commands/` must be at the plugin root, not inside `.claude-plugin/` |
| Hooks not firing | Script not executable | `chmod +x script.sh` |
| MCP server fails | Missing `${CLAUDE_PLUGIN_ROOT}` | Use the variable for all plugin paths |
| Path errors | Absolute paths used | Make them relative, starting with `./` |
| LSP `Executable not found in $PATH` | Language server not installed | Install the binary |

Example error messages:

- `Invalid JSON syntax: Unexpected token } in JSON at position 142` — missing/extra comma or unquoted string
- `Plugin <name> has an invalid manifest file at .claude-plugin/plugin.json. Validation errors: name: Invalid input: expected string, received undefined` — required field missing
- `Plugin <name> has a corrupt manifest file at .claude-plugin/plugin.json. JSON parse error: ...`
- `Warning: No commands found in plugin my-plugin custom directory: ./cmds. Expected .md files or SKILL.md in subdirectories.`
- `Plugin directory not found at path: ./plugins/my-plugin. Check that the marketplace entry has the correct path.`
- `Plugin my-plugin has conflicting manifests: both plugin.json and marketplace entry specify components.`

Hook troubleshooting order: `chmod +x` the script; correct shebang (`#!/bin/bash` or `#!/usr/bin/env bash`); path uses `"\"${CLAUDE_PLUGIN_ROOT}\"/scripts/your-script.sh"`; test the script manually; event name is case-sensitive (`PostToolUse`, not `postToolUse`); matcher pattern shape `"matcher": "Write|Edit"`; hook type is one of `command`, `http`, `mcp_tool`, `prompt`, `agent`.

MCP troubleshooting order: the command exists and is executable; all paths use `${CLAUDE_PLUGIN_ROOT}`; `claude --debug` shows init errors; test the server manually outside Claude Code; confirm it is configured in `.mcp.json` or `plugin.json`; check for connection timeouts in debug output.

## Validation error and warning catalog
> Source: https://code.claude.com/docs/en/plugin-marketplaces

Errors from `claude plugin validate .` against a marketplace directory:

| Error | Cause | Solution |
|---|---|---|
| `File not found: .claude-plugin/marketplace.json` | Missing manifest | Create it with required fields |
| `Invalid JSON syntax: Unexpected token...` | Syntax error | Fix commas/quoting |
| `Duplicate plugin name "x" found in marketplace` | Two plugins share a name | Rename one |
| `plugins[0].source: Path contains ".."` | Source path escapes the marketplace root | Remove `..` |
| `YAML frontmatter failed to parse: ...` | Bad YAML in a skill/agent/command | Fix syntax (the file loads with no metadata at runtime); reported only when validating a plugin directory |
| `Invalid JSON syntax: ...` (hooks.json) | Malformed `hooks/hooks.json` | Fix JSON — a malformed hooks.json blocks the **entire plugin** |

Non-blocking warnings: `Marketplace has no plugins defined`; `No marketplace description provided`; `Plugin name "x" is not kebab-case` (claude.ai marketplace sync rejects non-kebab-case even though Claude Code loads it); `Marketplace name "x" is reserved in Claude Desktop` (`org`, `org-provisioned`, `unknown` in any casing — Desktop's managed sync rejects the whole marketplace; check added v2.1.221); `Marketplace/Plugin name "x" is not accepted by Claude Desktop` (Desktop accepts ≤128 chars of letters, digits, `.`, `_`, `-`, starting with a letter or digit; check added v2.1.221).

When pointed at a marketplace directory the validator also checks each local-path entry's own `plugin.json` and warns on a version mismatch between entry and manifest; problems are prefixed `plugins[2] plugin.json →`. As of v2.1.196 the per-entry pass also includes plugins whose `source` is `.`, runs even when `marketplace.json` sits outside a `.claude-plugin/` directory (resolving against the file's own directory), and reports each entry's problems independently even when another part of the file has schema errors.

## Community and official marketplaces
> Source: https://code.claude.com/docs/en/plugins
> Source: https://code.claude.com/docs/en/discover-plugins

- **`claude-plugins-official`** — curated by Anthropic, registered automatically on first interactive launch. If blocked: `claude plugin marketplace add anthropics/claude-plugins-official`. Install with `/plugin install <name>@claude-plugins-official`.
- **`claude-community`** (catalog repo `anthropics/claude-plugins-community`) — third-party submissions after automated validation and safety screening. Add manually: `/plugin marketplace add anthropics/claude-plugins-community`.

Submission forms feed the **community** marketplace only; the official marketplace has no application process. claude.ai: `claude.ai/admin-settings/directory/submissions/plugins/new` (Team/Enterprise org with directory management access). Console: `platform.claude.com/plugins/submit` (individual authors).

Run `claude plugin validate ./your-plugin` before submitting — the review pipeline runs the same check plus safety screening (`✔ Validation passed` or `✔ Validation passed with warnings`; warnings do not fail unless `--strict`). Approved plugins are pinned to a specific commit SHA in the community catalog and CI auto-bumps the pin on new commits. The public catalog syncs **nightly**, so there is a delay between approval and installability — check by searching the plugin name in `github.com/anthropics/claude-plugins-community/blob/main/.claude-plugin/marketplace.json`.

Demo marketplace (not auto-added): the `anthropics/claude-code` repo, marketplace name `claude-code-plugins`.

## Security
> Source: https://code.claude.com/docs/en/discover-plugins

Plugins and marketplaces are **highly trusted components** that execute arbitrary code on your machine with your user privileges. Anthropic does not control what MCP servers, files, or software third-party plugins include and cannot verify they work as intended — install only from sources you trust and check each plugin's homepage. Organizations restrict allowed marketplace sources via `strictKnownMarketplaces`.

## Sources

- https://code.claude.com/docs/en/plugins
- https://code.claude.com/docs/en/plugins-reference
- https://code.claude.com/docs/en/plugin-marketplaces
- https://code.claude.com/docs/en/discover-plugins

Fetched: 2026-08-05
