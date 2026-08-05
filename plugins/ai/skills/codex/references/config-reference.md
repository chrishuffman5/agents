# Codex `config.toml` reference

Read when a setting isn't applying, when standardizing config across a team, when pointing Codex at a proxy or gateway, or when wiring telemetry. All facts as of 2026-08-05.

> `developers.openai.com/codex/*` pages 308-redirect to `learn.chatgpt.com/docs/*` — the same OpenAI-owned documentation site. URLs below are the resolved hosts actually fetched.

## File locations and precedence

> Source: https://learn.chatgpt.com/docs/config-file/config-basic

Layered files:

| Layer | Path | Note |
|---|---|---|
| User | `~/.codex/config.toml` | `CODEX_HOME` relocates the directory |
| Project | `.codex/config.toml` | In the repo; **loaded only when the project is trusted** |
| System | `/etc/codex/config.toml` | Unix only |
| Profile | `~/.codex/<profile-name>.config.toml` | Activated with `--profile <name>` |

Precedence, highest to lowest:

1. CLI flags and `--config` overrides
2. Project config (the one closest to cwd wins)
3. Profile file
4. User config
5. System config
6. Built-in defaults

Two consequences worth stating to users directly: a project file that is silently ignored usually means the project is not trusted; and a profile does **not** beat a project file, so per-repo config wins over a personal profile.

Admin-delivered `requirements.toml` and `managed_config.toml` sit outside this list — see `enterprise.md`.

## Basic keys

> Source: https://learn.chatgpt.com/docs/config-file/config-basic

```toml
model = "gpt-5.6"
approval_policy = "on-request"    # untrusted | on-request | never
sandbox_mode = "workspace-write"  # read-only | workspace-write | danger-full-access
web_search = "cached"             # cached | indexed | live | disabled
model_reasoning_effort = "high"
personality = "friendly"          # friendly | pragmatic | none
log_dir = "/absolute/path/to/codex-logs"

[windows]
sandbox = "elevated"

[shell_environment_policy]
ignore_default_excludes = false
inherit = "core"
set = { MY_FLAG = "1" }

[shell_environment_policy.filters]
"PATH" = "include"
"HOME" = "include"
"AWS_*" = "exclude"

[features]
memories = true
multi_agent = true
shell_tool = true
```

`[shell_environment_policy]` is the environment-scrubbing mechanism: `inherit` picks the base set, `set` injects values, and `filters` applies per-variable or glob `include` / `exclude`. Excluding `AWS_*`, `GITHUB_*`, and similar prefixes is the practical way to keep cloud credentials out of agent-spawned subprocesses — do this in addition to, not instead of, sandboxing.

`[features]` toggles optional subsystems: `memories` (the recall layer), `multi_agent` (parallel subagent delegation, which `model_reasoning_effort = "ultra"` relies on), `shell_tool`.

## Advanced keys

> Source: https://learn.chatgpt.com/docs/config-file/config-advanced

```toml
model_provider = "proxy"

[model_providers.proxy]
name = "OpenAI using LLM proxy"
base_url = "http://proxy.example.com"
env_key = "OPENAI_API_KEY"
http_headers = { "X-Example-Header" = "value" }
# command-backed auth: [model_providers.<id>.auth] with command / args / timeout_ms

approvals_reviewer = "auto_review"

[sandbox_workspace_write]
writable_roots = ["/path/to/allow"]
network_access = false

[otel]
exporter = { otlp-http = { endpoint = "https://otel.example.com/v1/logs" } }
log_user_prompt = false
```

`[model_providers.<id>]` is the corporate-gateway path: point `base_url` at an internal LLM proxy, name the credential env var in `env_key`, add required headers, and select it with `model_provider`. The nested `[model_providers.<id>.auth]` table takes `command`, `args`, and `timeout_ms` for rotating credentials produced by an external helper rather than a static env var.

`[otel]` ships telemetry to an OTLP/HTTP endpoint. Keep `log_user_prompt = false` unless the privacy decision to log prompt content has been made explicitly and recorded — it is off by default for a reason.

Other advanced keys:

| Key | Purpose |
|---|---|
| `project_root_markers` | Customize how Codex decides where the project root is |
| `project_doc_fallback_filenames` | Additional accepted names for the `AGENTS.md` instruction file |
| `project_doc_max_bytes` | Cap on instruction-file size; default 32 KiB |
| `file_opener` | Makes citations clickable — `vscode`, `cursor`, … |
| `notify` | External program invoked on agent events |
| `history.max_bytes` | Cap the history file size |
| `hide_agent_reasoning` | Suppress reasoning display |
| `review_model` | Use a different model for `/review` than for chat |

## Inspecting resolved config

> Source: https://learn.chatgpt.com/docs/config-file/config-basic
> Source: https://learn.chatgpt.com/docs/developer-settings

In a session:

- `/status` — active model, approval policy, writable roots, token usage.
- `/debug-config` — every config layer in precedence order, plus the source of any managed-policy requirement. This is the answer to "who set this?"

From the IDE: gear icon → "Codex Settings > Open config.toml."

`--strict-config` treats unrecognized keys as errors instead of ignoring them. Use it in CI and when validating a rollout — a misspelled key otherwise fails open to the default with no signal.

`--ignore-user-config` skips `$CODEX_HOME/config.toml` entirely while preserving auth settings; pair it with `--ignore-rules` (skips user/project execpolicy `.rules` files) for runs that must be identical on every machine.

## Sources

- https://learn.chatgpt.com/docs/config-file/config-basic
- https://learn.chatgpt.com/docs/config-file/config-advanced
- https://learn.chatgpt.com/docs/developer-commands?surface=cli
- https://learn.chatgpt.com/docs/developer-settings
- https://github.com/openai/codex/blob/main/docs/config.md

Fetched: 2026-08-05
