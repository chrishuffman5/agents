# Plugin components and directory layout

Read this when adding a component type to a plugin, when a component silently fails to appear, or when deciding between a marketplace plugin and a `@skills-dir` plugin.

## Directory layout and the `.claude-plugin/` trap
> Source: https://code.claude.com/docs/en/plugins
> Source: https://code.claude.com/docs/en/plugins-reference

**Common mistake**: do not put `commands/`, `agents/`, `skills/`, or `hooks/` inside `.claude-plugin/`. Only `plugin.json` goes there. Every other directory sits at the plugin root.

The plugin root is the individual plugin's own directory — the one passed to `--plugin-dir`, or the one containing `.claude-plugin/plugin.json`. It is **never** `~/.claude/`; Claude Code does not read `~/.claude/.mcp.json`.

| Directory | Purpose |
|---|---|
| `.claude-plugin/` | Contains `plugin.json` (optional if components use default locations) |
| `skills/` | Skills as `<name>/SKILL.md` directories |
| `commands/` | Skills as flat Markdown files — use `skills/` for new plugins |
| `agents/` | Subagent definitions |
| `hooks/` | Event handlers in `hooks.json` |
| `.mcp.json` | MCP server configurations |
| `.lsp.json` | LSP server configurations |
| `monitors/` | Background monitor configs in `monitors.json` |
| `bin/` | Executables added to the Bash tool's `PATH` while the plugin is enabled |
| `settings.json` | Default settings applied when the plugin is enabled |

Full reference layout:

```text
enterprise-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── code-reviewer/SKILL.md
│   └── pdf-processor/{SKILL.md,scripts/}
├── commands/{status.md,logs.md}
├── agents/{security-reviewer.md,performance-tester.md,compliance-checker.md}
├── workflows/release-audit.js
├── output-styles/terse.md
├── themes/dracula.json
├── monitors/monitors.json
├── hooks/{hooks.json,security-hooks.json}
├── bin/my-tool
├── settings.json
├── .mcp.json
├── .lsp.json
├── scripts/{security-scan.sh,format-code.py,deploy.js}
├── LICENSE
└── CHANGELOG.md
```

A `CLAUDE.md` at the plugin root is **not** loaded as project context. Plugins contribute context through skills, agents, and hooks — ship instructions as a skill.

| Component | Default location |
|---|---|
| Manifest | `.claude-plugin/plugin.json` |
| Skills | `skills/<name>/SKILL.md` |
| Commands | `commands/*.md` |
| Agents | `agents/*.md` |
| Workflows | `workflows/` |
| Output styles | `output-styles/` |
| Themes | `themes/` |
| Hooks | `hooks/hooks.json` |
| MCP servers | `.mcp.json` |
| LSP servers | `.lsp.json` |
| Monitors | `monitors/monitors.json` |
| Executables | `bin/` |
| Settings | `settings.json` (only `agent` and `subagentStatusLine` supported) |

## Skills
> Source: https://code.claude.com/docs/en/plugins-reference

Location: `skills/` or `commands/` at the plugin root, or a single `SKILL.md` at the plugin root. Skills are directories containing `SKILL.md`; commands are plain Markdown files.

```text
skills/
├── pdf-processor/
│   ├── SKILL.md
│   ├── reference.md      (optional)
│   └── scripts/          (optional)
└── code-reviewer/
    └── SKILL.md
```

If a plugin has no `skills/` directory and no `skills` manifest field, a root `SKILL.md` loads as a single skill. Set frontmatter `name` explicitly to control the invocation name — the fallback is the install directory name, which for marketplace installs is a version string that changes on every update. Plugins that may grow past one skill should use `skills/`.

Boolean frontmatter fields (e.g. `disable-model-invocation`) accept `yes/no/on/off/1/0` in any case in addition to `true/false` since v2.1.218.

For writing the *content* of a SKILL.md, use the `agent-skills` sibling skill.

## Agents
> Source: https://code.claude.com/docs/en/plugins-reference

Location: `agents/` at the plugin root, Markdown with YAML frontmatter.

```markdown
---
name: agent-name
description: What this agent specializes in and when Claude should invoke it
model: sonnet
effort: medium
maxTurns: 20
disallowedTools: Write, Edit
---

Detailed system prompt describing the agent's role, expertise, and behavior.
```

Supported frontmatter: `name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation` (only valid value `"worktree"`).

**Not supported for plugin-shipped agents, for security**: `hooks`, `mcpServers`, `permissionMode`.

Agents appear in @-mention typeahead under their scoped name (`my-plugin:code-reviewer`) once enabled, and Claude can invoke them automatically.

## Hooks
> Source: https://code.claude.com/docs/en/plugins-reference

Location: `hooks/hooks.json` at the plugin root, or inline in `plugin.json`.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/format-code.sh" } ]
      }
    ]
  }
}
```

Plugin hooks respond to the same lifecycle events as user-defined hooks. Full event list as of 2026-08-05:

`SessionStart`, `Setup` (fires with `--init-only`, or `--init`/`--maintenance` in `-p` mode), `UserPromptSubmit`, `UserPromptExpansion`, `PreToolUse`, `PermissionRequest`, `PermissionDenied` (return `{retry: true}` to let the model retry), `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `Notification`, `MessageDisplay`, `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `Stop`, `StopFailure` (output/exit code ignored), `TeammateIdle`, `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `FileChanged` (matcher = filenames to watch), `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `PostCompact`, `Elicitation`, `ElicitationResult`, `SessionEnd`.

Hook types: `command` (shell), `http` (POST event JSON to a URL), `mcp_tool` (call a tool on a configured MCP server), `prompt` (LLM eval, `$ARGUMENTS` placeholder), `agent` (agentic verifier with tools).

**Scoped names for a plugin's own MCP server**: tool matchers and `if` fields use `mcp__plugin_<plugin-name>_<server-name>__<tool>`; an `mcp_tool` hook's `server` field uses `plugin:<plugin-name>:<server-name>`. A matcher against the bare server key never fires.

A malformed `hooks/hooks.json` blocks the **entire plugin** from loading, not just the hooks.

For hook event semantics, input/output schemas, and exit codes, use the `claude-code` sibling skill.

## MCP servers
> Source: https://code.claude.com/docs/en/plugins-reference

Location: `.mcp.json` at the plugin root, or inline in `plugin.json`.

```json
{
  "mcpServers": {
    "plugin-database": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/db-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": { "DB_PATH": "${CLAUDE_PLUGIN_ROOT}/data" }
    },
    "plugin-api-client": { "command": "npx", "args": ["@company/mcp-server", "--plugin-mode"] }
  }
}
```

Plugin MCP servers start automatically when the plugin is enabled and their tools integrate as standard MCP tools. `/reload-plugins` keeps live connections for servers whose config is unchanged.

## LSP servers
> Source: https://code.claude.com/docs/en/plugins-reference

Location: `.lsp.json` at the plugin root, or the `lspServers` key in `plugin.json`.

```json
{
  "go": { "command": "gopls", "args": ["serve"], "extensionToLanguage": { ".go": "go" } }
}
```

**Required**: `command` (binary must be in PATH), `extensionToLanguage`.

**Optional**: `args`, `transport` (`stdio` default or `socket`), `env`, `initializationOptions`, `settings` (delivered via `workspace/didChangeConfiguration`), `workspaceFolder`, `startupTimeout` (ms), `shutdownTimeout` (ms; unset = no timeout), `restartOnCrash` (default `true`), `maxRestarts`, `diagnostics` (default `true`).

`restartOnCrash` and `shutdownTimeout` require v2.1.205+; earlier versions accepted the schema but setting either caused the server to be skipped at startup, visible only via `claude --debug`.

When multiple servers claim the same extension, the first registered wins, the others never start, and `/plugin` warns naming the active plugin. A server that fails to initialize is skipped without stopping the others, and (v2.1.205+) does not claim its extensions.

Official LSP plugins — install the language server binary separately:

| Language | Plugin | Binary |
|---|---|---|
| C/C++ | `clangd-lsp` | `clangd` |
| C# | `csharp-lsp` | `csharp-ls` |
| Go | `gopls-lsp` | `gopls` |
| Java | `jdtls-lsp` | `jdtls` |
| Kotlin | `kotlin-lsp` | `kotlin-language-server` |
| Lua | `lua-lsp` | `lua-language-server` |
| PHP | `php-lsp` | `intelephense` |
| Python | `pyright-lsp` | `pyright-langserver` |
| Rust | `rust-analyzer-lsp` | `rust-analyzer` |
| Swift | `swift-lsp` | `sourcekit-lsp` |
| TypeScript | `typescript-lsp` | `typescript-language-server` |

Code intelligence plugins give Claude automatic diagnostics after every edit and code navigation (definition, references, hover, symbols, implementations, call hierarchies). Press **Ctrl+O** to read diagnostics after a "Found N new diagnostic issues" indicator.

## Monitors
> Source: https://code.claude.com/docs/en/plugins-reference

Background monitors start automatically when the plugin is active; each runs a shell command for the session lifetime and delivers every stdout line to Claude as a notification. Same constraints as the Monitor tool: interactive CLI sessions only, unsandboxed at hook trust level, skipped where the Monitor tool is unavailable.

Location: `monitors/monitors.json` at the plugin root, or inline `experimental.monitors` in `plugin.json` (array, or a relative path string).

```json
[
  {
    "name": "deploy-status",
    "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/poll-deploy.sh",
    "description": "Deployment status changes"
  },
  {
    "name": "error-log",
    "command": "tail -F ./logs/error.log",
    "description": "Application error log",
    "when": "on-skill-invoke:debug"
  }
]
```

**Required**: `name` (unique within the plugin — prevents duplicate processes on reload), `command`, `description`.
**Optional**: `when` — `"always"` (default) or `"on-skill-invoke:<skill-name>"`.

`command` supports `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`, `${CLAUDE_PROJECT_DIR}`, and any `${ENV_VAR}`. Prefix with `cd "${CLAUDE_PLUGIN_ROOT}" && ` when the script must run from the plugin directory.

A monitor `command` **cannot** reference `${user_config.*}` (rejected with an error), and monitor processes do not receive `CLAUDE_PLUGIN_OPTION_<KEY>` — have the script read a config file. Before v2.1.207 monitor commands did substitute.

Disabling a plugin mid-session does not stop already-running monitors; they stop when the session ends.

## Themes
> Source: https://code.claude.com/docs/en/plugins-reference

A theme is a JSON file in `themes/` with a `base` preset and a sparse `overrides` map; it appears in `/theme` alongside built-ins.

```json
{
  "name": "Dracula",
  "base": "dark",
  "overrides": { "claude": "#bd93f9", "error": "#ff5555", "success": "#50fa7b" }
}
```

Selecting one saves `custom:<plugin-name>:<slug>` in config. Plugin themes are read-only — `Ctrl+E` in `/theme` copies it to `~/.claude/themes/` for editing.

## Plugin default settings
> Source: https://code.claude.com/docs/en/plugins

A `settings.json` at the plugin root applies default config when the plugin is enabled. Only `agent` and `subagentStatusLine` are supported.

```json
{ "agent": "security-reviewer" }
```

Setting `agent` activates one of the plugin's custom agents as the main thread — its system prompt, tool restrictions, and model. `settings.json` values take priority over `settings` declared in `plugin.json`; unknown keys are silently ignored.

## Skills-directory plugins (`@skills-dir`)
> Source: https://code.claude.com/docs/en/plugins-reference

Any folder under a skills directory that contains `.claude-plugin/plugin.json` loads as a plugin named `<name>@skills-dir` on the next session — discovered in place, never copied to cache, no marketplace and no install step. Scaffold with `claude plugin init`.

| What you have | What it is |
|---|---|
| `<skills-dir>/foo/SKILL.md` (no manifest) | A plain skill named `foo` |
| `<skills-dir>/foo/.claude-plugin/plugin.json` | A plugin `foo@skills-dir` that can bundle its own skills, agents, hooks |
| `<plugin>/skills/bar/SKILL.md` | A skill `bar` packaged inside a plugin |

| Skills directory | Scope | Loads |
|---|---|---|
| `~/.claude/skills/` | personal | Every project |
| `<cwd>/.claude/skills/` | project | Only after the workspace trust dialog is accepted |

Project-scope `@skills-dir` plugins reach every collaborator who clones the repo, so components that run code are restricted: MCP servers go through the same per-server approval as project `.mcp.json`, LSP servers start only after trust, and **background monitors do not load**. Personal-scope plugins have none of these restrictions.

**Warning**: project-scope `@skills-dir` plugins load only from the `.claude/skills/` of the directory Claude Code was *started in* — they do not walk up to the repo root the way plain skills and commands do. Launch from the repo root, or run `/reload-plugins` after changing directories.

Changes to a skill's `SKILL.md` take effect immediately; changes to other components (`hooks/`, `.mcp.json`, `agents/`, `output-styles/`) require `/reload-plugins` or a restart. To stop loading, delete the folder or run `claude plugin disable my-tool@skills-dir` — there is no uninstall step because nothing was installed.

## Sources

- https://code.claude.com/docs/en/plugins
- https://code.claude.com/docs/en/plugins-reference

Fetched: 2026-08-05
