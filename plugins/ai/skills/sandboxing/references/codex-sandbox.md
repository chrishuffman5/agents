# OpenAI Codex CLI — Sandbox Modes and Enterprise Lockdown

Cross-vendor reference for fleets running both Claude Code and Codex CLI. Read when the isolation question spans vendors. All facts as of 2026-08-05.

> `developers.openai.com/codex/*` documentation pages 308-redirect to the equivalent `learn.chatgpt.com/docs/*` paths (the same OpenAI-owned documentation site); URLs below reflect the resolved host actually fetched.

## Sandbox policy and mechanics

> Source: https://learn.chatgpt.com/docs/sandboxing
> Source: https://learn.chatgpt.com/docs/agent-approvals-security

Sandbox modes, set via `sandbox_mode` in `config.toml` or `--sandbox` on the CLI:

| Mode | Behavior |
|---|---|
| `read-only` | Agent can inspect files but cannot edit files or run commands without approval |
| `workspace-write` | Default for local dev — read files, edit within the workspace, run routine local commands inside that boundary |
| `danger-full-access` (alias `--yolo`) | Removes all filesystem and network restrictions; "no sandbox, no approvals" |

OS-specific enforcement:

- **macOS** — native Seatbelt framework (`sandbox-exec` with a profile matching the selected mode).
- **Linux / WSL2** — `bubblewrap` (`bwrap`, user-namespace isolation). Codex uses the first `bwrap` on `PATH`, falling back to a bundled helper requiring unprivileged user-namespace support; Landlock is available as a compatibility fallback path; seccomp is also used.
- **Windows** — native Windows sandbox implementation when running natively; WSL2 uses the Linux implementation.

Network access is enforced through the sandbox layer and also via `[sandbox_workspace_write].network_access = true|false`. In ChatGPT Work (cloud), separate "Work network access" controls let admins restrict commands to managed allowlists or enable public internet access. Cloud/isolated runs execute in an isolated environment where workspace policy determines available capabilities.

`codex sandbox` runs arbitrary commands inside the Codex-provided macOS/Linux/Windows sandboxes via permission profiles, with platform-specific aliases `codex sandbox seatbelt` and `codex sandbox landlock` (also surfaced as `codex debug`). Useful for testing a profile before wiring it into a job.

## Approval policy vs sandbox mode

> Source: https://learn.chatgpt.com/docs/agent-approvals-security

`approval_policy` values: `"on-request"` (approval needed to edit outside the workspace or access the network), `"never"` (no approval prompts; autonomy still governed by sandbox settings), `"untrusted"` (only known-safe read operations run automatically; state-mutating commands require approval). A granular form is also supported:

```toml
approval_policy = { granular = {
  sandbox_approval = true,
  rules = true,
  mcp_elicitations = true
} }
```

The interaction pattern: **sandbox mode determines what is technically possible; approval policy determines when the agent must ask first.** Actions staying within sandbox boundaries proceed automatically under permissive approval policies.

```toml
# Standard safe mode
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
writable_roots = ["/path/to/allow"]
network_access = false
```

`--dangerously-bypass-approvals-and-sandbox` / `--yolo` runs every command without approvals or sandboxing — only inside an externally hardened environment.

## Headless / CI

> Source: https://learn.chatgpt.com/docs/non-interactive-mode

```bash
codex exec --sandbox workspace-write "task prompt"
codex exec --json "task prompt"          # JSONL event stream to stdout
codex exec --ephemeral "task prompt"     # skip persisting session files to disk
```

Other relevant flags: `--ignore-user-config` (skip `$CODEX_HOME/config.toml`), `--ignore-rules` (skip user/project execpolicy `.rules` files), `--output-schema`, `--skip-git-repo-check`.

Authentication in automation: set `CODEX_API_KEY` inline for single invocations only — **never as a persistent environment variable in jobs running untrusted code**. The Codex GitHub Action (`openai/codex-action@v1`) is preferred for GitHub workflows to avoid exposing credentials to build scripts; it installs the CLI, starts the Responses API proxy when given an API key, and runs `codex exec` under specified permissions.

## Enterprise managed configuration

> Source: https://learn.chatgpt.com/docs/enterprise/managed-configuration

Two layers:

**Requirements** (`requirements.toml`) — non-overrideable constraints on security-sensitive settings. On conflict the local client falls back to a compatible value and notifies the user. Enforceable: approval policy, sandbox mode, permission profiles, web search, MCP servers, plugin marketplace sources, feature flags (browser use, computer use, plugins, hooks), network access allow/deny domain lists, filesystem deny-read patterns, appshots/device remote control toggles, and `allow_managed_hooks_only = true` (restricts user/project hook configs to managed hooks; supported only in `requirements.toml`).

**Managed defaults** (`managed_config.toml`) — starting values applied at client launch. Users can change them mid-session but defaults reapply on next startup; not enforced.

| Platform | Path |
|---|---|
| Linux/macOS | `/etc/codex/managed_config.toml` |
| Windows | `~/.codex/managed_config.toml` |
| macOS MDM | Preference domain `com.openai.codex`, keys `config_toml_base64` and `requirements_toml_base64` |

```toml
# requirements.toml
allowed_approval_policies = ["on-request"]
allowed_sandbox_modes = ["read-only", "workspace-write"]
allow_appshots = false

[rules]
prefix_rules = [
  { pattern = [{ any_of = ["bash", "sh"] }],
    decision = "prompt",
    justification = "Require approval for shell" }
]
```

```toml
# managed_config.toml
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = false
```

Inspect the resolved policy in-session with `/status` (active model, approval policy, writable roots) and `/debug-config` (layers in precedence order plus the source of managed policy requirements).

Environment scrubbing is available through `[shell_environment_policy]` in `config.toml` — `inherit`, `set`, and `filters` with per-variable `include`/`exclude` (e.g. `"AWS_*" = "exclude"`), which is the Codex analogue of stripping credentials from sandboxed subprocesses.

## Sources

- https://learn.chatgpt.com/docs/sandboxing
- https://learn.chatgpt.com/docs/agent-approvals-security
- https://learn.chatgpt.com/docs/non-interactive-mode
- https://learn.chatgpt.com/docs/enterprise/managed-configuration
- https://learn.chatgpt.com/docs/config-file/config-basic
- https://learn.chatgpt.com/docs/config-file/config-advanced
- https://learn.chatgpt.com/docs/developer-commands?surface=cli

Fetched: 2026-08-05
