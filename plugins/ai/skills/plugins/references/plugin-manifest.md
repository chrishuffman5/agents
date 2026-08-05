# `plugin.json` — complete manifest reference

Read this when writing or debugging a plugin manifest: field types, path-field semantics, `userConfig`, `channels`, path variables, and how installs are cached.

## The manifest is optional
> Source: https://code.claude.com/docs/en/plugins-reference

`.claude-plugin/plugin.json` defines a plugin's metadata and configuration. Omit it entirely and Claude Code auto-discovers components in default locations (`skills/`, `commands/`, `agents/`, `hooks/hooks.json`, `.mcp.json`, `.lsp.json`, `themes/`, `monitors/monitors.json`) and derives the plugin name from the directory name. Add a manifest when you need metadata or custom component paths.

If a manifest is present, `name` is the **only** required field.

Complete schema example:

```json
{
  "name": "plugin-name",
  "displayName": "Plugin Name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": { "name": "Author Name", "email": "author@example.com", "url": "https://github.com/author" },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "metadata": { "catalogId": "cat-123", "tier": "pro" },
  "skills": "./custom/skills/",
  "commands": ["./custom/commands/special.md"],
  "agents": ["./custom/agents/reviewer.md"],
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json",
  "outputStyles": "./styles/",
  "lspServers": "./.lsp.json",
  "experimental": { "themes": "./themes/", "monitors": "./monitors.json" },
  "dependencies": ["helper-lib", { "name": "secrets-vault", "version": "~2.1.0" }]
}
```

Minimal form from the Create Plugins tutorial:

```json
{
  "name": "my-first-plugin",
  "description": "A greeting plugin to learn the basics",
  "version": "1.0.0",
  "author": { "name": "Your Name" }
}
```

## Required field and namespacing
> Source: https://code.claude.com/docs/en/plugins-reference

| Field | Type | Description |
|---|---|---|
| `name` | string | Unique identifier, kebab-case, no spaces. When a marketplace entry lists the plugin under a different name, the **marketplace entry name** is what `enabledPlugins` keys and `/plugin` use. |

`name` namespaces every component: agent `agent-creator` in plugin `plugin-dev` appears as `plugin-dev:agent-creator`; skill directory `hello/` in `my-first-plugin` becomes `/my-first-plugin:hello`.

## Metadata fields
> Source: https://code.claude.com/docs/en/plugins-reference

| Field | Type | Description |
|---|---|---|
| `$schema` | string | JSON Schema URL for editor autocomplete. Ignored at load time. |
| `displayName` | string | Human-readable name in `/plugin` and UI; falls back to `name`. May contain spaces/casing. Not used for namespacing or lookup. Requires v2.1.143+. |
| `version` | string | Semver. Setting it **pins** the plugin — users only get updates when you bump it. Omit to fall back to the git commit SHA. If also set in the marketplace entry, `plugin.json` wins. |
| `description` | string | Brief purpose statement. |
| `author` | object | `{name, email?, url?}`. |
| `homepage` | string | Documentation URL. |
| `repository` | string | Source code URL. |
| `license` | string | License identifier (`MIT`, `Apache-2.0`). |
| `keywords` | array | Discovery tags. |
| `metadata` | object | Free-form; Claude Code never reads it. Non-object value → warning. Before v2.1.222 it was treated as an unrecognized field. |
| `defaultEnabled` | boolean | Whether the plugin starts enabled with no explicit user setting. Default `true`. Requires v2.1.154+. |

### Default enablement

`defaultEnabled: false` ships a plugin that installs disabled — the user turns it on with `claude plugin enable <plugin>` or `/plugin`. Intended for plugins with cost or scope implications (connecting to an external service). Earlier versions than v2.1.154 ignore the field and enable on install.

Two things override it:

1. **The user's setting** — an `enabledPlugins` entry at any scope persists across updates and reinstalls regardless of later `defaultEnabled` changes.
2. **A dependency requirement** — when another active plugin requires it, Claude Code writes `true` at install/enable time.

The same field in a *marketplace entry* takes precedence over the `plugin.json` value.

## Unrecognized fields and type mismatches
> Source: https://code.claude.com/docs/en/plugins-reference

Claude Code ignores unrecognized top-level fields — you can keep VS Code/Cursor extension metadata, npm `package.json` keys, or MCPB/DXT bundle fields in the same file and the plugin still loads.

`claude plugin validate` reports unrecognized fields as **warnings**, not errors, and suggests a likely intended name when a field is one or two characters off. A plugin with only such warnings passes validation and loads.

Type mismatches differ by field:

- **Most fields**: wrong type → the plugin fails to load, reported as an error (e.g. `keywords` as a string).
- **`experimental` and `metadata`**: a non-object value is ignored and reported only as a warning.

`--strict` promotes warnings to errors:

```bash
claude plugin validate ./my-plugin --strict
```

## Component path fields
> Source: https://code.claude.com/docs/en/plugins-reference

| Field | Type | Description |
|---|---|---|
| `skills` | string\|array | Skill directories containing `<name>/SKILL.md`. **Adds to** the default `skills/` scan. |
| `commands` | string\|array | Flat `.md` skill files or directories. **Replaces** default `commands/`. |
| `agents` | string\|array | Agent files. **Replaces** default `agents/`. |
| `workflows` | string\|array | Workflow script files/dirs. **Replaces** default `workflows/`. |
| `hooks` | string\|array\|object | Hook config paths or inline config. |
| `mcpServers` | string\|array\|object | MCP config paths or inline config. |
| `outputStyles` | string\|array | Output style files/dirs. Replaces default `output-styles/`. |
| `lspServers` | string\|array\|object | LSP configs. |
| `experimental.themes` | string\|array | Theme files/dirs. Replaces default `themes/`. |
| `experimental.monitors` | string\|array | Background monitor configs; start automatically when the plugin is active. |
| `userConfig` | object | Values prompted at enable time. |
| `channels` | array | Channel declarations for message injection. |
| `dependencies` | array | Other required plugins, optionally with semver constraints. |

Components under `experimental` (`themes`, `monitors`) have a schema that may change between releases. Declaring them at the top level still works today, `claude plugin validate` warns, and a future release will require `experimental.*`.

### Path behavior rules

- **Replaces the default**: `commands`, `agents`, `workflows`, `outputStyles`, `experimental.themes`, `experimental.monitors`. To keep the default and add more, list it explicitly: `"commands": ["./commands/", "./extras/"]`.
- **Adds to the default**: `skills` — `skills/` is always scanned, plus listed dirs. **Exception**: for a marketplace entry whose `source` resolves to the marketplace root, declaring specific subdirectories *replaces* the default `skills/` scan.
- **Own merge rules**: hooks, MCP servers, LSP servers.

Rules for all path fields:

- Paths are relative to the plugin root and start with `./`, except `skills` also accepts `"."`. Both `"."` and `"./"` denote the plugin root; before v2.1.221 `"."` failed validation, so use `"./"` for earlier-version support.
- Multiple paths may be arrays.
- A skill path can point directly at a directory containing `SKILL.md` (e.g. `"skills": ["."]`). The invocation name comes from `SKILL.md` frontmatter `name`, falling back to the directory basename.
- A plugin with a root-level `SKILL.md`, no `skills/` subdirectory, and no `skills` manifest field auto-loads as a single-skill plugin (v2.1.142+).

When a plugin has both a default folder and the matching manifest key, v2.1.140+ warns about the ignored folder in `claude plugin list` and the `/plugin` detail view (the plugin still loads using manifest paths). No warning when the manifest key points *into* the default folder, e.g. `"commands": ["./commands/deploy.md"]`.

## `userConfig`
> Source: https://code.claude.com/docs/en/plugins-reference

Declares values Claude Code prompts for when the plugin is enabled, instead of requiring hand-edited `settings.json`.

```json
{
  "userConfig": {
    "api_endpoint": { "type": "string", "title": "API endpoint", "description": "Your team's API endpoint" },
    "api_token": { "type": "string", "title": "API token", "description": "API authentication token", "sensitive": true }
  }
}
```

Keys must be valid identifiers.

| Field | Required | Description |
|---|---|---|
| `type` | Yes | `string`, `number`, `boolean`, `directory`, or `file` |
| `title` | Yes | Label in the config dialog |
| `description` | Yes | Help text |
| `sensitive` | No | Masks input and stores in secure storage instead of `settings.json` |
| `required` | No | Validation fails when empty |
| `default` | No | Value used when the user provides nothing |
| `multiple` | No | For `string`, allow an array of strings |
| `min` / `max` | No | Bounds for `number` |

Substitution: `${user_config.KEY}` works in MCP/LSP server configs and hook commands. Non-sensitive values also substitute into skill and agent content. All values export to hook processes as `CLAUDE_PLUGIN_OPTION_<KEY>` (KEY uppercased).

**Shell-injection guard** — fields that run in a shell reject `${user_config.*}` with an error:

| Rejected field | Alternative |
|---|---|
| Shell-form hook commands | Use exec form with `args`, or read `CLAUDE_PLUGIN_OPTION_<KEY>` from the environment |
| Monitor commands | Read the value from a config file in the script |
| MCP `headersHelper` | Read the value from a config file in the script |

Before v2.1.207 these fields *did* substitute — update plugins relying on the old behavior.

**Storage**: non-sensitive values go to `pluginConfigs[<plugin-id>].options` in user `settings.json`. Sensitive values go to the macOS Keychain, or `~/.claude/.credentials.json` where no keychain exists (shared with OAuth tokens, ~2 KB total — keep sensitive values small).

`pluginConfigs` is read from only three sources, precedence managed > `--settings` > user settings. **Project (`.claude/settings.json`) and local (`.claude/settings.local.json`) entries are ignored** — a cloned repo could otherwise inject values into hook commands and MCP configs (restriction added v2.1.207). This restriction is specific to `pluginConfigs`; `enabledPlugins` still honors project and local scopes.

## Channels
> Source: https://code.claude.com/docs/en/plugins-reference

```json
{
  "channels": [
    {
      "server": "telegram",
      "userConfig": {
        "bot_token": { "type": "string", "title": "Bot token", "description": "Telegram bot token", "sensitive": true },
        "owner_id": { "type": "string", "title": "Owner ID", "description": "Your Telegram user ID" }
      }
    }
  ]
}
```

`server` is required and must match a key in the plugin's `mcpServers`. Per-channel `userConfig` uses the same schema as the top-level field.

## Path variables
> Source: https://code.claude.com/docs/en/plugins-reference

| Variable | Resolves to | Use for |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the plugin's installation directory | Bundled scripts, binaries, config files |
| `${CLAUDE_PLUGIN_DATA}` | Persistent directory surviving plugin updates, created on first reference | Installed dependencies (`node_modules`, venvs), generated code, caches |
| `${CLAUDE_PROJECT_DIR}` | The project root | Project-local scripts and config |

All three export as environment variables to hook processes and MCP/LSP subprocesses. Where they resolve *inline*:

| Component | Fields |
|---|---|
| Skill and agent content | Anywhere the placeholder appears |
| Hook and monitor commands | Anywhere the placeholder appears |
| MCP `stdio` servers | `command`, `args`, `env` |
| MCP `http`/`sse`/`ws` servers | `url`, `headers`, `headersHelper` |
| LSP servers | `command`, `args`, `env`, `workspaceFolder` |

In hook commands prefer exec form with `args` so each path is one unquoted argument. In shell-form hooks and monitor commands, wrap in double quotes:

```json
{
  "hooks": {
    "PostToolUse": [
      { "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/process.sh" } ] }
    ]
  }
}
```

`${CLAUDE_PLUGIN_ROOT}` changes on every plugin update. The previous version's directory stays on disk ~2 weeks before cleanup — treat it as ephemeral and never write state there. When a plugin updates mid-session, hook commands, monitors, and MCP/LSP servers keep using the *previous* version's path until `/reload-plugins` (monitors need a session restart).

MCP servers can also call `roots/list` to read the session's working directories at runtime.

### Persistent data directory

`${CLAUDE_PLUGIN_DATA}` resolves to `~/.claude/plugins/data/{id}/`, where `{id}` is the plugin identifier with any character outside `a-z A-Z 0-9 _ -` replaced by `-`. A plugin installed as `formatter@my-marketplace` gets `~/.claude/plugins/data/formatter-my-marketplace/`.

Because the data directory outlives any single version, directory existence alone can't detect a dependency-manifest change. Compare the bundled manifest against a copy in the data directory and reinstall when they differ:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "diff -q \"${CLAUDE_PLUGIN_ROOT}/package.json\" \"${CLAUDE_PLUGIN_DATA}/package.json\" >/dev/null 2>&1 || (cd \"${CLAUDE_PLUGIN_DATA}\" && cp \"${CLAUDE_PLUGIN_ROOT}/package.json\" . && npm install) || rm -f \"${CLAUDE_PLUGIN_DATA}/package.json\""
          }
        ]
      }
    ]
  }
}
```

Then point the runtime at the persisted dependencies:

```json
{
  "mcpServers": {
    "routines": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/server.js"],
      "env": { "NODE_PATH": "${CLAUDE_PLUGIN_DATA}/node_modules" }
    }
  }
}
```

The data directory is deleted automatically on uninstall from the *last* scope where the plugin is installed. `/plugin` shows its size and prompts before deleting; the CLI deletes by default — pass `--keep-data` to `claude plugin uninstall` to preserve it.

## Caching, file resolution, and symlinks
> Source: https://code.claude.com/docs/en/plugin-marketplaces
> Source: https://code.claude.com/docs/en/plugins-reference

Plugins are specified either via `claude --plugin-dir` / `--plugin-url` (session-only) or through a marketplace (installed for future sessions). On install, Claude Code **copies the plugin directory to `~/.claude/plugins/cache`** rather than using it in place — so a plugin **cannot** reference files outside its own directory (`../shared-utils` is not copied).

Each installed version is a separate cache directory. On update or uninstall the previous version directory is orphaned and auto-removed after **14 days** (a grace period so concurrent sessions on the old version keep running). Glob and Grep skip orphaned version directories.

Symlink handling when copying into the cache depends on the target:

- **Within the plugin's own directory** — preserved as a relative symlink.
- **Elsewhere in the same marketplace** — dereferenced; target content is copied in its place (this is how a meta-plugin's `skills/` can link to sibling plugins' skills).
- **Outside the marketplace** — skipped entirely for security.

For `--plugin-dir` or local-path installs, only symlinks resolving within the plugin's own directory are preserved; all others are skipped.

```bash
# from inside a marketplace plugin, link to a shared skill in a sibling plugin
ln -s ../../shared-plugin/skills/foo ./skills/foo
```

On Windows use `mklink /D` from an elevated Command Prompt, or enable Developer Mode.

## Sources

- https://code.claude.com/docs/en/plugins
- https://code.claude.com/docs/en/plugins-reference
- https://code.claude.com/docs/en/plugin-marketplaces

Fetched: 2026-08-05
