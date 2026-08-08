# `marketplace.json` — complete catalog reference

Read this when authoring or debugging a marketplace catalog: required and optional fields, plugin entries, source types, strict mode, reserved names, and organization-sync restrictions.

## What a marketplace is
> Source: https://code.claude.com/docs/en/plugin-marketplaces

A plugin marketplace is a catalog that distributes plugins to others: centralized discovery, version tracking, automatic updates, and multiple source types (git repos, local paths, npm). Create `.claude-plugin/marketplace.json` in the repository root.

```json
{
  "name": "company-tools",
  "owner": { "name": "DevTools Team", "email": "devtools@example.com" },
  "plugins": [
    {
      "name": "code-formatter",
      "source": "./plugins/formatter",
      "description": "Automatic code formatting on save",
      "version": "2.1.0",
      "author": { "name": "DevTools Team" }
    },
    {
      "name": "deployment-tools",
      "source": { "source": "github", "repo": "company/deploy-plugin" },
      "description": "Deployment automation tools"
    }
  ]
}
```

Local walkthrough layout:

```bash
mkdir -p my-marketplace/.claude-plugin
mkdir -p my-marketplace/plugins/quality-review-plugin/.claude-plugin
mkdir -p my-marketplace/plugins/quality-review-plugin/skills/quality-review
```

```json
{
  "name": "my-plugins",
  "owner": { "name": "Your Name" },
  "plugins": [
    {
      "name": "quality-review-plugin",
      "source": "./plugins/quality-review-plugin",
      "description": "Adds a quality-review skill for quick code reviews"
    }
  ]
}
```

```shell
/plugin marketplace add ./my-marketplace
/plugin install quality-review-plugin@my-plugins
```

Installation copies the plugin directory to a cache location, so plugins cannot reference files outside their own directory (`../shared-utils`). Use symlinks to share files across plugins in the same marketplace.

## Required fields
> Source: https://code.claude.com/docs/en/plugin-marketplaces

| Field | Type | Description |
|---|---|---|
| `name` | string | Marketplace identifier, kebab-case, no spaces. Public-facing (`/plugin install my-tool@your-marketplace`). Each user can register only **one** marketplace per name — adding a second with the same name replaces the first, so publish multiple plugins under one name by listing them all in a single `marketplace.json`. |
| `owner` | object | Maintainer info |
| `plugins` | array | Available plugins |

Owner fields: `name` (required), `email` (optional), `url` (optional).

### Optional marketplace fields

| Field | Type | Description |
|---|---|---|
| `$schema` | string | JSON Schema URL for editor autocomplete; ignored at load time |
| `description` | string | Brief marketplace description |
| `version` | string | Marketplace manifest version |
| `metadata.pluginRoot` | string | Base directory prepended to relative plugin source paths — `"./plugins"` lets you write `"source": "formatter"` |
| `allowCrossMarketplaceDependenciesOn` | array | Other marketplaces whose plugins this marketplace's plugins may depend on; deps from an unlisted marketplace are blocked at install |
| `renames` | object | Map from a former plugin `name` to its current name, or `null` if removed. Requires v2.1.193+ |

`description` and `version` are also accepted under `metadata` for backward compatibility.

## Reserved marketplace names
> Source: https://code.claude.com/docs/en/plugin-marketplaces

Reserved for Anthropic and unusable by third parties: `claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `claude-plugins-community`, `claude-community`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `anthropic-agent-skills`, `knowledge-work-plugins`, `life-sciences`, `claude-for-legal`, `claude-for-financial-services`, `financial-services-plugins`, `first-party-plugins`, `healthcare`. Names impersonating official marketplaces (`official-claude-plugins`, `anthropic-plugins-v2`) are also blocked.

Reserved names are re-checked on **every load**, not only on add. A marketplace registered under a name that later became reserved stops loading and reports "registered from an untrusted source" — remove and re-add from the official source, or re-add third-party marketplaces under a different name. Before v2.1.205, `first-party-plugins` and `healthcare` were not reserved.

## Plugin entries
> Source: https://code.claude.com/docs/en/plugin-marketplaces

Each entry accepts **any field from the plugin manifest schema** plus marketplace-specific fields: `source`, `category`, `tags`, `strict`, `relevance`.

| Field | Type | Description |
|---|---|---|
| `name` | string | Plugin identifier, kebab-case. Public-facing (`/plugin install my-plugin@marketplace`) |
| `source` | string\|object | Where to fetch the plugin from |

Standard optional metadata: `displayName` (v2.1.143+), `description`, `version`, `author`, `homepage`, `repository`, `license`, `keywords`, `metadata` (before v2.1.222 the validator flagged it as unrecognized), `category`, `tags`, `strict`, `relevance` (only honored for marketplaces allowlisted via `pluginSuggestionMarketplaces`; requires v2.1.152+), `defaultEnabled` (takes precedence over the `plugin.json` value; v2.1.154+).

Component configuration fields in an entry: `skills`, `commands`, `agents`, `hooks`, `mcpServers`, `lspServers` — same shapes as in `plugin.json`.

Advanced entry:

```json
{
  "name": "enterprise-tools",
  "source": { "source": "github", "repo": "company/enterprise-plugin" },
  "description": "Enterprise workflow automation tools",
  "version": "2.1.0",
  "author": { "name": "Enterprise Team", "email": "enterprise@example.com" },
  "homepage": "https://docs.example.com/plugins/enterprise-tools",
  "repository": "https://github.com/company/enterprise-plugin",
  "license": "MIT",
  "keywords": ["enterprise", "workflow", "automation"],
  "category": "productivity",
  "commands": ["./commands/core/", "./commands/enterprise/", "./commands/experimental/preview.md"],
  "agents": ["./agents/security-reviewer.md", "./agents/compliance-checker.md"],
  "hooks": {
    "PostToolUse": [
      { "matcher": "Write|Edit",
        "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh" } ] }
    ]
  },
  "mcpServers": {
    "enterprise-db": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/db-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"]
    }
  },
  "strict": false
}
```

By default a plugin's skills load from `skills/` under its `source`, and paths in the entry's `skills` field **add** to that scan. When several entries share one `skills/` folder at the marketplace root (`source: "./"`), list specific subdirectories so each entry loads only its own:

```json
{ "source": "./", "skills": ["./skills/code-review", "./skills/docs"] }
```

With a marketplace-root `source`, the listed paths become the *complete* set for that entry — other skills in the shared folder do not load. Listing `./skills/` itself or the plugin root keeps the full scan. If none of the listed paths exist, the default scan runs.

## Strict mode
> Source: https://code.claude.com/docs/en/plugin-marketplaces

| `strict` | Behavior |
|---|---|
| `true` (default) | `plugin.json` is authority; the marketplace entry can supplement with additional components and both are merged |
| `false` | The marketplace entry is the entire definition. If the plugin *also* has a `plugin.json` declaring components, that is a conflict and the plugin fails to load |

Use `strict: true` when the plugin manages its own components (works for most). Use `strict: false` when the marketplace operator wants full control — the plugin repo provides raw files and the entry decides what is exposed.

## Plugin sources
> Source: https://code.claude.com/docs/en/plugin-marketplaces

Set in each entry's `source`. After clone or download, Claude Code copies the plugin into the versioned cache at `~/.claude/plugins/cache`.

| Source | Type | Fields | Notes |
|---|---|---|---|
| Relative path | string (`"./my-plugin"`) | — | Local directory within the marketplace repo. Must start with `./`, resolved relative to the marketplace root (the directory containing `.claude-plugin/`), no `../` |
| `github` | object | `repo`, `ref?`, `sha?` | `repo` is `owner/repo` |
| `url` | object | `url`, `ref?`, `sha?` | Full git URL, `https://` or `git@`; `.git` suffix optional |
| `git-subdir` | object | `url`, `path`, `ref?`, `sha?` | Subdirectory in a repo; sparse clone minimizes bandwidth for monorepos. `url` also accepts `owner/repo` shorthand or SSH URLs |
| `npm` | object | `package`, `version?`, `registry?` | Installed via `npm install` |

**Marketplace source vs plugin source**: the marketplace source is where the catalog itself is fetched from (set via `/plugin marketplace add` or `extraKnownMarketplaces`; supports `ref` but not `sha`). A plugin source is where an individual listed plugin is fetched from (supports both `ref` and `sha`). They can point at entirely different repos and are pinned independently.

For `github`/`url`/`git-subdir`, when both `ref` and `sha` are set, **`sha` is the effective pin**. On most hosts (GitHub, GitLab, Bitbucket) install succeeds even if the `ref`-named branch or tag was later deleted, as long as the commit is reachable. Some servers (e.g. AWS CodeCommit) do not support fetching by SHA — there the `ref` must still exist and the pinned commit must be reachable from it.

Relative paths do **not** resolve when the marketplace was added via a direct URL to `marketplace.json`, because only that one file is downloaded. Use GitHub/npm/git URL sources for URL-based distribution.

```json
{ "name": "github-plugin",
  "source": { "source": "github", "repo": "owner/plugin-repo", "ref": "v2.0.0", "sha": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0" } }
```

```json
{ "name": "my-plugin",
  "source": { "source": "git-subdir", "url": "https://github.com/acme-corp/monorepo.git", "path": "tools/claude-plugin", "ref": "v2.0.0" } }
```

```json
{ "name": "my-npm-plugin",
  "source": { "source": "npm", "package": "@acme/claude-plugin", "version": "^2.0.0", "registry": "https://npm.example.com" } }
```

## Organization-sync source rules (Team/Enterprise)
> Source: https://code.claude.com/docs/en/plugin-marketplaces

When distributing via **Organization settings > Plugins** (`claude.ai/admin-settings/plugins`):

- The marketplace repo must be private or internal; org sync reads it via the Claude GitHub App or the org's GitHub Enterprise App.
- Plugin source types `github`, `url`, and `git-subdir` are supported; `npm` is **not**.
- A plugin source can be private only in two cases: a `github.com` source sharing the marketplace repo's owner, or a source on the org's GHE host with the GHE App installed. Every other source is fetched with no credentials — non-owner GitHub repos and non-GitHub hosts (GitLab, Bitbucket) must be public.
- To include private plugins, place plugin folders inside the marketplace repo and reference them with a relative path; org sync packages each plugin during distribution.

## Sources

- https://code.claude.com/docs/en/plugin-marketplaces

Fetched: 2026-08-05
