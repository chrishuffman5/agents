# Team and enterprise plugin configuration

Read this when rolling plugins out to a team, deciding which settings scope a plugin belongs in, or locking down which marketplaces an organization allows.

## Installation scopes
> Source: https://code.claude.com/docs/en/plugins-reference

| Scope | Settings file | Use case |
|---|---|---|
| `user` | `~/.claude/settings.json` | Personal plugins across all projects (default) |
| `project` | `.claude/settings.json` | Team plugins shared via version control |
| `local` | `.claude/settings.local.json` | Project-specific, gitignored when Claude Code saves a setting to it |
| `managed` | Managed settings | Managed plugins (read-only; update only) |

## Settings precedence and delivery
> Source: https://code.claude.com/docs/en/settings

| Scope | Location | Who it affects | Shared? |
|---|---|---|---|
| Managed | Server-managed / plist / registry / `managed-settings.json` | Org (server-managed); all machine users (plist/HKLM/file); current user (HKCU) | Yes, deployed by IT |
| User | `~/.claude/` | You, all projects | No |
| Project | `.claude/` in repo | All collaborators | Yes, committed |
| Local | `.claude/settings.local.json` | You, this repo only | No, gitignored |

Precedence, highest to lowest: **Managed** > command-line args > **Local** > **Project** > **User**. Managed cannot be overridden by any other scope, with narrow security-field exceptions.

Managed delivery mechanisms: server-managed (claude.ai admin console or a self-hosted Claude apps gateway); MDM/OS-level (macOS `com.anthropic.claudecode` managed-preferences plist; Windows `HKLM\SOFTWARE\Policies\ClaudeCode\Settings`, or `HKCU\...` as a lowest-priority fallback); or file-based `managed-settings.json` at `/Library/Application Support/ClaudeCode/` (macOS), `/etc/claude-code/` (Linux/WSL), `C:\Program Files\ClaudeCode\` (Windows — the legacy `C:\ProgramData\ClaudeCode\managed-settings.json` is unsupported since v2.1.75).

File-based managed settings support a `managed-settings.d/` drop-in directory for independent policy fragments: `managed-settings.json` merges first as base, then `*.json` files merge alphabetically on top (scalars: later wins; arrays: concatenated and de-duplicated; objects: deep-merged). Use numeric prefixes (`10-telemetry.json`, `20-security.json`) to control order.

**Invalid managed-settings entries parse tolerantly** — a failing entry is stripped, a warning is recorded, and every other valid policy is still enforced (v2.1.169+). `claude doctor` lists stripped entries with source file and field. This tolerance is specific to managed settings; user/project/local settings files are strict and a file failing validation is rejected as a whole.

## `extraKnownMarketplaces`
> Source: https://code.claude.com/docs/en/plugin-marketplaces

Object map keyed by marketplace name:

```json
{
  "extraKnownMarketplaces": {
    "company-tools": { "source": { "source": "github", "repo": "your-org/claude-plugins" } }
  }
}
```

Set at project scope (`.claude/settings.json`) to prompt team members to install when they trust the folder. As of v2.1.195 this install step applies on every path that loads plugins — a plugin that only project settings enable, sourced externally (GitHub/npm), does not load until the team member runs the `claude plugin install` command Claude Code shows.

An entry can carry `"autoUpdate": true` to force auto-update for that marketplace org-wide without per-user toggling.

## `enabledPlugins`
> Source: https://code.claude.com/docs/en/plugin-marketplaces

Object map keyed `"plugin-name@marketplace-name": true`:

```json
{
  "enabledPlugins": {
    "code-formatter@company-tools": true,
    "deployment-tools@company-tools": true
  }
}
```

This is the form documented for project/team settings. `enabledPlugins` honors project and local scopes, unlike `pluginConfigs`.

## `pluginConfigs`
> Source: https://code.claude.com/docs/en/plugins-reference

Non-sensitive `userConfig` values are stored under `pluginConfigs[<plugin-id>].options` in user `settings.json`; sensitive values go to the macOS Keychain or `~/.claude/.credentials.json`.

`pluginConfigs` is read from only **three** sources, precedence managed > `--settings` > user: `~/.claude/settings.json` (where the enable-time prompt writes), the `--settings` CLI flag / SDK inline settings, and managed settings. `--setting-sources` narrows this further. **Project and local entries are ignored** — both files live in the workspace, and a cloned repo could otherwise inject values that flow into plugin hook commands, MCP configs, LSP commands, and monitor commands (restriction added v2.1.207). It is specific to `pluginConfigs`; `enabledPlugins` is unaffected.

## `strictKnownMarketplaces`
> Source: https://code.claude.com/docs/en/plugin-marketplaces

Managed-settings-only. Restricts which marketplace sources users may **add**.

| Value | Behavior |
|---|---|
| Undefined (default) | No restrictions |
| Empty array `[]` | Complete lockdown — blocks every source, including the official Anthropic marketplace |
| List of sources | Only marketplaces matching the allowlist exactly |

```json
{ "strictKnownMarketplaces": [] }
```

Allow only the official marketplace (matching is exact and does not cover `ref`/`path` variants):

```json
{ "strictKnownMarketplaces": [ { "source": "github", "repo": "anthropics/claude-plugins-official" } ] }
```

With that entry, an already-registered official marketplace stays available and on a fresh machine it auto-registers on first interactive launch. Automatic registration misses two cases: non-interactive environments running before first interactive launch, and machines where Claude Code already ran under a blocking policy (a blocked attempt is recorded and not retried after the policy changes). For those, also add the official marketplace to `extraKnownMarketplaces` in the same `managed-settings.json`, or run `claude plugin marketplace add anthropics/claude-plugins-official`.

Allow specific marketplaces, an internal git host by regex, or a filesystem path by regex:

```json
{
  "strictKnownMarketplaces": [
    { "source": "github", "repo": "acme-corp/approved-plugins" },
    { "source": "github", "repo": "acme-corp/security-tools", "ref": "v2.0" },
    { "source": "url", "url": "https://plugins.example.com/marketplace.json" },
    { "source": "hostPattern", "hostPattern": "^github\\.example\\.com$" },
    { "source": "pathPattern", "pathPattern": "^/opt/approved/" }
  ]
}
```

`pathPattern: ".*"` allows any filesystem path while still restricting network sources with `hostPattern`.

**It restricts what can be added; it does not register anything.** Pair it with `extraKnownMarketplaces` in the same `managed-settings.json`, or locked-down machines end up with no marketplace.

**Enforcement**: checked before any network or filesystem operation, on marketplace add and on plugin install/update/refresh/auto-update. A marketplace added before the policy existed whose source no longer matches can no longer install or update. The same applies to `blockedMarketplaces`. Matching is exact with no URL normalization — trailing slash, `.git` suffix, and `ssh://` vs `https://` are all different values, so prefer `hostPattern` when your marketplace has multiple clone-URL forms. For GitHub sources `repo` is required and `ref`/`path` must each match exactly or be absent from both sides; for URL sources the full URL must match exactly. Because this lives in managed settings, users and projects cannot override it.

## `blockedMarketplaces`
> Source: https://code.claude.com/docs/en/plugin-marketplaces
> Source: https://code.claude.com/docs/en/settings

Managed-settings-only denylist, enforced on marketplace add and on plugin install/update/refresh/auto-update. A marketplace added before the policy was set can no longer fetch plugins. Blocked sources are checked before downloading, so they never touch the filesystem.

```json
{ "blockedMarketplaces": [ { "source": "github", "repo": "untrusted/plugins" } ] }
```

## `disableSideloadFlags`
> Source: https://code.claude.com/docs/en/plugin-marketplaces
> Source: https://code.claude.com/docs/en/settings

Managed-settings-only. Rejects `--plugin-dir`, `--plugin-url`, `--agents`, and `--mcp-config` at startup — the flags a user could otherwise pass to bypass `strictKnownMarketplaces` for a single run. Requires v2.1.193+.

```json
{ "disableSideloadFlags": true }
```

A `--mcp-config` whose servers are all in-process `type: "sdk"` entries is still accepted, keeping the Agent SDK and VS Code extension working. It does **not** block `claude mcp add`, `.mcp.json`, or SDK `setMcpServers()` — pair with `allowedMcpServers` for per-server MCP control.

## `pluginSuggestionMarketplaces`
> Source: https://code.claude.com/docs/en/discover-plugins
> Source: https://code.claude.com/docs/en/settings

Allowlists which marketplaces' plugins may appear as contextual install suggestions ("suggested for this directory") in `/plugin` Discover, using each plugin entry's `relevance` field (which itself requires v2.1.152+).

## Lockdown summary
> Source: https://code.claude.com/docs/en/plugin-marketplaces

For organizations requiring strict control: `strictKnownMarketplaces` restricts addable sources; pair it with `disableSideloadFlags` to reject the CLI flags that sideload plugins, agents, and MCP servers for a single run; use `pluginSuggestionMarketplaces` to allowlist which marketplaces may surface contextual suggestions; and register the marketplaces you do allow via `extraKnownMarketplaces` in the same managed settings.

## Unverified in this corpus

The exact JSON **shape** of `enabledPlugins` and `pluginConfigs` when an administrator writes them **directly into managed settings** — as opposed to Claude Code writing them via `/plugin install` or the `userConfig` prompt — could not be confirmed against a verbatim source page during this fetch. Reported variants (an `enabledPlugins` array of `{marketplace, plugin}` objects for managed force-enable; an alternative `pluginConfigs` array shape; an `extraKnownMarketplaces` array-of-source-object shape) came only from a summarizing fetch of the very large settings page and are **not** treated as verified here. The object-map forms documented above are confirmed for user/project settings and for values Claude Code writes itself. Verify managed-settings shapes against the live settings reference before deploying policy.

## Sources

- https://code.claude.com/docs/en/plugins-reference
- https://code.claude.com/docs/en/plugin-marketplaces
- https://code.claude.com/docs/en/settings
- https://code.claude.com/docs/en/discover-plugins

Fetched: 2026-08-05
