# Copilot CLI reference

Read when working in the terminal with `copilot`: command surface, interactive slash commands, tool-approval flags, model providers, and keyboard shortcuts.

## What it is

> Source: https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli

A command-line interface giving direct terminal access to Copilot: "answer questions, write and debug code, and interact with GitHub.com" without leaving the terminal.

**Modes**

- **Interactive** — run bare `copilot` for a conversational session. Two sub-modes: standard ask/execute, and **plan mode** (toggle with `Shift+Tab`) where Copilot builds a structured implementation plan and asks clarifying questions before coding.
- **Programmatic** — `-p` / `--prompt` runs a task non-interactively and exits. This is the scripting/automation entry point.

**Task scope**: local development (code changes, file analysis, git operations, scaffolding new apps) and GitHub.com interactions (fetch work item details, create PRs, raise issues, review PR changes, manage workflows). Automatic context compression kicks in as a session approaches token limits.

**Operating systems**: Linux, macOS, Windows (PowerShell and WSL).

**Customization**: custom instructions, MCP servers, custom specialized agents, hooks, skills, and Copilot Memory (persistent repository understanding). Instruction and agent file formats are in `customization-files.md`.

## Security and tool approval

> Source: https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli

The docs are explicit: "Copilot can perform tasks on your behalf, such as executing or modifying files, or running shell commands."

Approval mechanisms:

| Mechanism | Scope |
|---|---|
| Single-use approval | One tool call |
| Session-wide approval | Rest of the session |
| `--allow-tool` | Named tool, no prompt |
| `--deny-tool` | Named tool, always refused |
| `--allow-all-tools` | Everything, no prompt |

Local and cloud-based sandboxing options are offered to mitigate the risk of automatic approvals. Treat `--allow-all-tools` as container-only; prefer an explicit `--allow-tool` list otherwise. For isolation mechanics, defer to the `sandboxing` sibling; for prompt-injection threat modeling, defer to `ai-security`.

## Models

> Source: https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli

Switch with the `/model` slash command or the `--model` flag. Latest models support **1M-token context windows** and configurable reasoning levels. **Custom model providers are supported via environment variables** — OpenAI-compatible endpoints, Azure OpenAI, Anthropic, and local instances such as Ollama.

## Top-level commands

> Source: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference

| Command | Purpose |
|---|---|
| `copilot login [--host HOST]` | Authenticate via OAuth device flow |
| `copilot init` | Initialize Copilot custom instructions for the current repository |
| `copilot logout` | End the current session |
| `copilot` | Launch the interactive interface |
| `copilot version` | Display version and check for updates |
| `copilot update` | Install the latest version |
| `copilot completion SHELL` | Enable tab completion for bash, zsh, or fish |
| `copilot plugins list [--kind KINDS] [--scope SCOPES] [--json]` | Inspect every plugin, MCP server, skill, instruction source, and language server |
| `copilot plugins enable\|disable\|remove [--plugin\|--mcp\|--skill]` | Manage individual plugins / MCP servers / skills |
| `copilot skill` | Manage agent skills |
| `copilot mcp` | Manage MCP server configurations |
| `copilot plugin` | Manage plugins and marketplaces |
| `copilot help [TOPIC]` | Access documentation topics |

`copilot plugins list --json` is the first diagnostic to run when a skill, MCP server, or instruction file appears not to load — it reports what the CLI actually resolved rather than what the filesystem suggests.

## Slash commands (inside interactive sessions)

> Source: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference

**Context and navigation**

- `/add-dir PATH` — expand file access permissions
- `/cwd [PATH]` — change or display the working directory
- `/env` — show loaded environment details

**Workflow**

- `/delegate [PROMPT]` — delegate changes to a remote repository with an AI-generated pull request (this is the CLI's handoff to the cloud agent)
- `/diff` — review local changes
- `/plan [PROMPT]` — create an implementation plan
- `/charter` — generate skill proposals from usage patterns

**Session management**

- `/clear`, `/new`, `/reset [PROMPT]` — start a fresh conversation
- `/exit`, `/quit` — close the session
- `/resume` — open the session picker

**AI control**

- `/model [MODEL]` — select a model or auto-selection
- `/limits` — configure response cost constraints
- `/ask QUESTION` — a quick side question that does not affect history

**Advanced**

- `/after [DELAY PROMPT]` — schedule a one-off task
- `/every [INTERVAL PROMPT]` — schedule a recurring task
- `/fleet [PROMPT]` — enable parallel subagent execution
- `/compact [FOCUS-INSTRUCTIONS]` — summarize the conversation to reduce token usage
- `/context` — show token-usage visualization

## Keyboard shortcuts

> Source: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference

**Editing**: `Ctrl+A` / `Ctrl+E` (line start/end), `Ctrl+U` / `Ctrl+K` (delete to start/end), `Ctrl+W` (delete previous word), `Ctrl+G` (edit in external editor).

**Navigation**: `Ctrl+R` (reverse history search), `Ctrl+L` (clear screen), `↑` / `↓` (command history).

**Submission**: `Ctrl+Enter` / `Ctrl+Q` (queue a message while busy), `Shift+Enter` / `Option+Enter` (insert newline), `Tab` / `Ctrl+Y` (accept inline completion).

**Mode switching**: `Shift+Tab` (cycle standard / plan / autopilot), `Ctrl+X` then `/` (run a slash command mid-prompt), `$` (hand over to the native shell — **enterprise-configurable**, so it may be disabled by policy).

**Signals**: `Esc` (cancel; press twice to interrupt), `Ctrl+C` (clear input or exit; press twice), `Ctrl+D` (shutdown).

**Diff mode**: `hjkl` / arrow keys to navigate, `c` (comment), `s` (summary), `b` (toggle branches), `w` (hide whitespace), `r` (refresh).

**Timeline**: `Ctrl+F` (search), `Ctrl+O` (expand recent), `Ctrl+E` (expand all), `Ctrl+T` (toggle reasoning).

## Scripting patterns

> Derived from the sourced sections above; no separate source page.

Use `-p` for anything non-interactive, and pair it with an explicit tool allowlist so an unattended run can never sit waiting on an approval prompt:

```bash
copilot -p "run the test suite and summarize failures" --allow-tool <tool> --deny-tool <tool>
```

Audit-log caveat that matters for CI: GitHub's audit log does **not** capture client-session data such as local prompts. If CLI activity must be auditable, forward events to an internal logging service yourself — see `admin-and-governance.md`.

## Sources

- https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli
- https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference

Fetched: 2026-08-05
