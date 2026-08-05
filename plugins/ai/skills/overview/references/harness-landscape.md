# The agent-harness landscape (2026-08-05)

Read this when selecting, comparing, or migrating between coding-agent harnesses, or when you need Codex CLI / Gemini CLI specifics. Claude Code depth beyond the comparison grid lives in the `claude-code` sibling skill.

## What "agent harness" means here

> Source: https://code.claude.com/docs/en/overview

An **agent harness** is a complete, opinionated runtime that drives an LLM through an agentic loop for you: it owns the system prompt, the tool-calling loop, context/compaction, permissions, and a filesystem-based configuration surface (project memory, custom subagents, hooks, connectors). You install it and point it at a task; you don't write the loop yourself. This is distinct from an **agent SDK** (a library you embed to build a custom loop) and the **raw model API** (you implement everything, including tool execution) — see `layer-selection.md`.

The three major harnesses referenced across the industry as of 2026-08-05 are Anthropic's **Claude Code**, OpenAI's **Codex CLI**, and Google's **Gemini CLI**.

## Claude Code

> Source: https://code.claude.com/docs/en/overview

Described as "an agentic coding tool that reads your codebase, edits files, runs commands, and integrates with your development tools." It ships as multiple **surfaces** over the same engine, so `CLAUDE.md` files, settings, and MCP servers work identically across them: Terminal CLI, VS Code extension, JetBrains plugin, Desktop app (macOS/Windows), and Web (claude.ai/code, plus iOS/Android). All surfaces except the Terminal CLI and VS Code (which also support third-party model providers) require a Claude subscription or Anthropic Console account.

Install (native, auto-updating):

```bash
# macOS, Linux, WSL
curl -fsSL https://claude.ai/install.sh | bash
# Windows PowerShell
irm https://claude.ai/install.ps1 | iex
# Windows CMD
curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
```

Also available via Homebrew (`brew install --cask claude-code`, or `claude-code@latest` for the bleeding-edge channel) and WinGet (`winget install Anthropic.ClaudeCode`). Homebrew and WinGet installs do **not** auto-update; native installs auto-update in the background.

Start in any project with `claude`. First run prompts login unless `ANTHROPIC_API_KEY` is set, in which case it asks you to approve the key instead.

Composability — it follows the Unix philosophy and is explicitly designed to be piped and scripted:

```bash
tail -200 app.log | claude -p "Slack me if you see any anomalies"
claude -p "translate new strings into French and raise a PR for review"
git diff main --name-only | claude -p "review these changed files for security issues"
```

Capability clusters: automating tedious work (tests, lint fixes, merge conflicts, dependency updates, release notes); building features and fixing bugs; git/PR workflows; connecting external tools via **MCP**; customizing via **CLAUDE.md** instructions, **auto memory**, **skills**, and **hooks**; running **agent teams** (multiple agents coordinated by a lead) and **background agents** (many parallel sessions monitored from one screen); scheduling recurring work via **Routines** (Anthropic-managed infra, keeps running when your machine is off), Desktop scheduled tasks (local), or `/loop`; and moving sessions across devices (Remote Control, Dispatch, `claude --teleport`, `/desktop`).

> Source: https://code.claude.com/docs/en/claude_code_docs_map.md

Documentation concept clusters, each with dedicated reference pages: Subagents, Hooks, Skills, MCP (including managed MCP), Context management (context window, prompt caching, best practices), Memory, Permission modes, Sessions, Common workflows, Checkpointing, Worktrees, dynamic Workflows, Channels, Plugins and plugin marketplaces, and deployment via Amazon Bedrock, Google Vertex AI, and Microsoft Foundry.

## OpenAI Codex CLI

> Source: https://github.com/openai/codex/blob/main/README.md

`developers.openai.com/codex/*` pages 308-redirect to the equivalent `learn.chatgpt.com/docs/*` paths (the same OpenAI-owned documentation site); URLs below reflect the resolved host.

Install:

```bash
npm install -g @openai/codex
brew install --cask codex

# Mac/Linux installer
curl -fsSL https://chatgpt.com/codex/install.sh | sh
# Windows installer
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

Platform archives are on the latest GitHub Release (e.g. `codex-aarch64-apple-darwin.tar.gz`, `codex-x86_64-unknown-linux-musl.tar.gz`); extract and rename the binary to `codex`. First run prompts for a ChatGPT account or an API key.

### config.toml

> Source: https://learn.chatgpt.com/docs/config-file/config-basic
> Source: https://learn.chatgpt.com/docs/config-file/config-advanced

Layered file locations: user `~/.codex/config.toml`; project `.codex/config.toml` (loaded only when the project is trusted); system `/etc/codex/config.toml` (Unix only). Precedence, highest first: CLI flags / `--config` overrides → project config (closest to cwd wins) → profile files (`~/.codex/<profile>.config.toml`, via `--profile`) → user config → system config → built-in defaults.

```toml
model = "gpt-5.6"
approval_policy = "on-request"   # untrusted | on-request | never
sandbox_mode = "workspace-write" # read-only | workspace-write | danger-full-access
web_search = "cached"            # cached | indexed | live | disabled
model_reasoning_effort = "high"
personality = "friendly"         # friendly | pragmatic | none

[shell_environment_policy]
inherit = "core"
[shell_environment_policy.filters]
"AWS_*" = "exclude"

[sandbox_workspace_write]
writable_roots = ["/path/to/allow"]
network_access = false

[otel]
exporter = { otlp-http = { endpoint = "https://otel.example.com/v1/logs" } }
log_user_prompt = false
```

Other keys: `model_provider` + `[model_providers.<id>]` (proxy base URL, env key, headers, command-backed auth), `approvals_reviewer`, `project_root_markers`, `file_opener`, `notify`, `history.max_bytes`, `hide_agent_reasoning`, `[features]` toggles (`memories`, `multi_agent`, `shell_tool`), `[windows] sandbox`. Inspect the resolved config in-session with `/status` and `/debug-config` (shows layers in precedence order).

### CLI and headless

> Source: https://learn.chatgpt.com/docs/developer-commands?surface=cli
> Source: https://learn.chatgpt.com/docs/non-interactive-mode

Global flags: `--json` (newline-delimited JSON events), `--ignore-user-config`, `--ignore-rules`, `--sandbox <mode>`, `--ask-for-approval`/`-a <mode>`, and `--dangerously-bypass-approvals-and-sandbox` / `--yolo` (only inside an externally hardened environment).

Core commands: `codex exec` (non-interactive execution), `codex sandbox` (run arbitrary commands inside the provided macOS/Linux/Windows sandboxes; aliases `codex sandbox seatbelt`, `codex sandbox landlock`), `codex debug prompt-input` (render the exact model-visible prompt input as JSON), `codex review` (non-interactive review of uncommitted changes, a base-branch diff, or a commit), `codex mcp-server` (run Codex itself as an MCP server over stdio).

```bash
codex exec "task prompt"
codex exec --json "task prompt"
codex exec --ephemeral "task prompt"                       # don't persist session files
codex exec --output-schema ./schema.json -o ./output.json "task prompt"
npm test 2>&1 | codex exec "summarize failures and propose fix"
cat prompt.txt | codex exec -
```

`--json` emits one event object per line; observed types include `thread.started` (with `thread_id`), `turn.started`/`turn.completed` (with `input_tokens`, `cached_input_tokens`, `output_tokens`), and `item.*` events for commands, file changes, MCP calls, and messages.

Automation auth: set `CODEX_API_KEY` inline for single invocations only — never as a persistent environment variable in jobs running untrusted code. The Codex GitHub Action (`openai/codex-action@v1`) is preferred for GitHub workflows: it installs the CLI, starts the Responses API proxy when given an API key, and runs `codex exec` under specified permissions. Exit-code semantics for `codex exec` are not enumerated in the fetched docs — treat only standard 0/non-zero as verified.

### Sandbox and approvals

> Source: https://learn.chatgpt.com/docs/sandboxing
> Source: https://learn.chatgpt.com/docs/agent-approvals-security

Sandbox modes: `read-only` (inspect files; no edits or commands without approval), `workspace-write` (default for local dev — read, edit within the workspace, run routine local commands inside that boundary), `danger-full-access` (no filesystem or network restrictions; "no sandbox, no approvals").

Enforcement: **macOS** uses native Seatbelt (`sandbox-exec` with a profile matching the mode); **Linux/WSL2** uses `bubblewrap` (first `bwrap` on `PATH`, falling back to a bundled helper requiring unprivileged user namespaces), with Landlock as a compatibility fallback and seccomp also applied; **Windows** uses a native sandbox implementation, while WSL2 uses the Linux one. Network access is enforced through the sandbox layer plus `[sandbox_workspace_write].network_access`.

Approval policies: `on-request` (approval required to edit outside the workspace or access network), `never` (no prompts; autonomy still bounded by the sandbox), `untrusted` (only known-safe read operations run automatically). A granular form exists:

```toml
approval_policy = { granular = { sandbox_approval = true, rules = true, mcp_elicitations = true } }
```

The interaction to remember: **sandbox mode determines what is technically possible; approval policy determines when the agent must ask first.** Actions inside sandbox boundaries proceed automatically under permissive approval policies.

### AGENTS.md

> Source: https://learn.chatgpt.com/docs/agent-configuration/agents-md

Codex reads AGENTS.md before doing any work, building an instruction chain once per run (once per launched session in the TUI). Discovery: **global scope** (Codex home, default `~/.codex`) checks `AGENTS.override.md` then `AGENTS.md`, using only the first non-empty file; **project scope** walks from the Git root down to the cwd, checking `AGENTS.override.md`, then `AGENTS.md`, then configured fallback names — at most one file per directory.

Files are concatenated root-first, joined by blank lines, so files closer to the cwd override earlier guidance by appearing later in the prompt. Default size limit `project_doc_max_bytes` is 32 KiB — split large instructions across nested directories rather than one huge file. Keep required team guidance in AGENTS.md or checked-in docs; treat memories as a recall layer, not the source of truth for rules that must always apply.

### MCP

> Source: https://learn.chatgpt.com/docs/extend/mcp?surface=cli

```toml
[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp"]
env_vars = ["LOCAL_TOKEN"]

[mcp_servers.context7.env]
MY_ENV_VAR = "MY_ENV_VALUE"
```

Keys: `command` (required), `args`, `env`, `env_vars`, `cwd`, `required` (if true, `codex exec` exits with an error when the server fails to initialize), `enabled`, `startup_timeout_sec` (default 10), `tool_timeout_sec` (default 60). CLI: `codex mcp add <name> -- <stdio-command>`, `codex mcp list`, `codex mcp login <name>`.

### Enterprise controls

> Source: https://learn.chatgpt.com/docs/enterprise/managed-configuration

Two admin layers. **Requirements** (`requirements.toml`) are non-overrideable constraints; on conflict the client falls back to a compatible value and notifies the user. Enforceable: approval policy, sandbox mode, permission profiles, web search, MCP servers, plugin marketplace sources, feature flags (browser use, computer use, plugins, hooks), network allow/deny domain lists, filesystem deny-read patterns, appshots/device-remote-control toggles, and `allow_managed_hooks_only = true` (supported only in `requirements.toml`). **Managed defaults** (`managed_config.toml`) are starting values applied at launch; users may change them mid-session and they reapply at next startup.

| Platform | Path |
|---|---|
| Linux/macOS | `/etc/codex/managed_config.toml` |
| Windows | `~/.codex/managed_config.toml` |
| macOS MDM | Preference domain `com.openai.codex`, keys `config_toml_base64` / `requirements_toml_base64` |

```toml
# requirements.toml
allowed_approval_policies = ["on-request"]
allowed_sandbox_modes = ["read-only", "workspace-write"]
allow_appshots = false

[rules]
prefix_rules = [
  { pattern = [{ any_of = ["bash", "sh"] }], decision = "prompt", justification = "Require approval for shell" }
]
```

## Google Gemini CLI

> Source: https://github.com/google-gemini/gemini-cli

```bash
npx @google/gemini-cli            # run without installing
npm install -g @google/gemini-cli
brew install gemini-cli
```

Release channels: `@preview` (weekly), `@latest` (stable, weekly), `@nightly` (daily). Basic usage: `gemini`, `gemini --include-directories ../lib,../docs`, `gemini -m gemini-2.5-flash`, `gemini -p "prompt"` (non-interactive single prompt, then exit).

### Authentication

> Source: https://github.com/google-gemini/gemini-cli/blob/main/docs/get-started/authentication.mdx

1. **Sign in with Google (OAuth)** — credentials cache locally; for individual Google accounts and AI Pro/Ultra subscribers. No GCP project needed except for Workspace/school accounts or Gemini Code Assist licenses.
2. **Gemini API key** — `export GEMINI_API_KEY=...` from Google AI Studio; no GCP requirement.
3. **Vertex AI** — requires `GOOGLE_CLOUD_PROJECT` and `GOOGLE_CLOUD_LOCATION`, then Application Default Credentials (`gcloud auth application-default login`), a service-account JSON key with the "Vertex AI User" role via `GOOGLE_APPLICATION_CREDENTIALS`, or a Google Cloud API key via `GOOGLE_API_KEY`.

### settings.json

> Source: https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/settings.md

Locations: user `~/.gemini/settings.json`; workspace `<project>/.gemini/settings.json` (workspace overrides user); an enterprise system layer sits above both. Categories: General, Output, UI, IDE, Billing, Model, Agents, Context, Tools, Security, Advanced, Experimental, Skills, HooksConfig.

```json
{
  "general": { "vimMode": false, "defaultApprovalMode": "default", "enableAutoUpdate": true },
  "model": { "maxSessionTurns": -1, "compressionThreshold": 0.5 },
  "security": { "toolSandboxing": false, "disableYoloMode": false }
}
```

`defaultApprovalMode`: `default` (prompt for approval), `auto_edit` (auto-approve edit tools), `plan` (read-only). Edit the files directly or use `/settings`.

### GEMINI.md and built-in tools

> Source: https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/gemini-md.md

Discovery order: global `~/.gemini/GEMINI.md`; workspace `GEMINI.md` files in configured directories and their parents; just-in-time `GEMINI.md` files found when tools access files/directories, up to a trusted root. All discovered files are concatenated (broadest first, most specific last) and sent with every prompt. Customize filenames via `{"context": {"fileName": ["AGENTS.md", "CONTEXT.md", "GEMINI.md"]}}`. Modular imports use `@./path/to/file.md`. Commands: `/memory show`, `/memory reload`.

> Source: https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md

Core built-in tools: `run_shell_command`, `read_file`, `write_file`, `glob`, `grep_search`, `list_directory`, `replace`, plus a Google Search grounding tool (`WebSearchTool`), `web_fetch`, and a `MemoryTool`. List active tools in-session with `/tools`.

### MCP

> Source: https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md

Configured under `mcpServers` in settings.json, one transport per server — `command` (stdio), `url` (SSE), or `httpUrl` (HTTP streaming):

```json
{
  "mcpServers": {
    "pythonTools": {
      "command": "python", "args": ["-m", "my_mcp_server"], "cwd": "./mcp-servers/python",
      "env": { "API_KEY": "$EXTERNAL_API_KEY" }, "timeout": 15000, "trust": false,
      "includeTools": ["safe_tool1", "safe_tool2"]
    },
    "remoteServer": { "httpUrl": "https://api.example.com/mcp", "headers": { "Authorization": "Bearer token-here" } }
  }
}
```

Other keys: `timeout` (ms, default 600000), `trust` (default false — bypasses confirmation dialogs), `includeTools`/`excludeTools` (`excludeTools` wins). OAuth for remote servers uses `authProviderType`: `dynamic_discovery` (default), `google_credentials`, or `service_account_impersonation` (with `targetAudience` and `targetServiceAccount` for IAP-protected services). Global gating: `{"mcp": {"allowed": [...], "excluded": [...]}}`.

### Sandboxing

> Source: https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/sandbox.md

`GEMINI_SANDBOX` selects the mechanism: `docker`, `podman`, `sandbox-exec` (macOS Seatbelt, lightweight/built-in), `runsc` (gVisor, Linux only, strongest isolation), `lxc` (Linux only, experimental). macOS Seatbelt profiles via `SEATBELT_PROFILE`: `permissive-open` (default), `permissive-proxied`, `restrictive-open`, `restrictive-proxied`, `strict-open`, `strict-proxied` — the `-proxied` variants route network through a proxy. Docker sandboxing defaults to `ghcr.io/google/gemini-cli:latest`; a project image comes from `.gemini/sandbox.Dockerfile` built with `BUILD_SANDBOX=1 GEMINI_SANDBOX=docker gemini -p "…"`. Enablement precedence: `-s`/`--sandbox` flag → `GEMINI_SANDBOX` env var → `{"tools": {"sandbox": true}}`.

Known limitation (from issue tracking, not the sandbox doc — treat as unverified): when sandboxing, MCP servers must be reachable from inside the sandboxed environment or they fail to start. Likewise, MCP availability and read-only tool restriction under `gemini -p` were only visible in GitHub issue discussion (#4372, #10177, #15338), not canonical docs — treat as evolving.

### Enterprise controls

> Source: https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/enterprise.md

System settings paths: Linux `/etc/gemini-cli/settings.json`, Windows `C:\ProgramData\gemini-cli\settings.json`, macOS `/Library/Application Support/GeminiCli/settings.json`; overridable with `GEMINI_CLI_SYSTEM_SETTINGS_PATH`. Precedence, highest first: System Overrides → Workspace Settings → User Settings → System Defaults (`system-defaults.json`); array and object settings merge across levels rather than being replaced.

```json
{ "tools": { "core": ["ReadFileTool", "GlobTool", "ShellTool(ls)"] } }   // allowlist beats denylist
{ "security": { "disableYoloMode": true } }
{ "tools": { "sandbox": "docker" } }
{ "mcp": { "allowed": ["corp-data-api", "source-code-analyzer"] } }
{ "security": { "auth": { "enforcedType": "oauth-personal" } } }
{ "telemetry": { "enabled": true, "target": "gcp", "logPrompts": false } }
```

Admins can also deploy a wrapper script at `/usr/local/bin/gemini` that sets `GEMINI_CLI_SYSTEM_SETTINGS_PATH` before invoking the real binary, preventing users from bypassing centralized configuration. A separate Policy Engine (`docs/reference/policy-engine.md`) offers stronger tool-restriction rules whose admin policies always override user, workspace, and default policies; its rule syntax was not fetched — do not state it as fact.

## Comparison grid

| Axis | Claude Code | Codex CLI | Gemini CLI |
|---|---|---|---|
| Instruction file | `CLAUDE.md` + auto memory | `AGENTS.md` / `AGENTS.override.md` | `GEMINI.md` (filenames configurable) |
| Config format | `settings.json` | `config.toml` | `settings.json` |
| Config layers | user / project / project-local / managed | CLI → project → profile → user → system → defaults | system → workspace → user → system-defaults |
| MCP config | `claude mcp add`, `.mcp.json` | `[mcp_servers.<name>]` in `config.toml` | `mcpServers` in `settings.json` |
| Isolation | permission modes + hooks | `sandbox_mode` × `approval_policy`, OS-native enforcement | `GEMINI_SANDBOX` (docker/podman/seatbelt/gVisor/LXC) |
| Headless | `claude -p --output-format json` | `codex exec --json` | `gemini -p` |
| Self-as-MCP-server | — | `codex mcp-server` | — |
| Enforced enterprise policy | managed settings | `requirements.toml` | system `settings.json` + policy engine |

## Sources

- https://code.claude.com/docs/en/overview
- https://code.claude.com/docs/en/claude_code_docs_map.md
- https://github.com/openai/codex/blob/main/README.md
- https://github.com/openai/codex/blob/main/docs/config.md
- https://learn.chatgpt.com/docs/config-file/config-basic
- https://learn.chatgpt.com/docs/config-file/config-advanced
- https://learn.chatgpt.com/docs/developer-commands?surface=cli
- https://learn.chatgpt.com/docs/sandboxing
- https://learn.chatgpt.com/docs/agent-approvals-security
- https://learn.chatgpt.com/docs/extend/mcp?surface=cli
- https://learn.chatgpt.com/docs/non-interactive-mode
- https://learn.chatgpt.com/docs/enterprise/managed-configuration
- https://learn.chatgpt.com/docs/agent-configuration/agents-md
- https://github.com/google-gemini/gemini-cli
- https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/settings.md
- https://github.com/google-gemini/gemini-cli/blob/main/docs/get-started/authentication.mdx
- https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/gemini-md.md
- https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md
- https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/sandbox.md
- https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/enterprise.md

Fetched: 2026-08-05
