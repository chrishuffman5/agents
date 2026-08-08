---
name: codex
description: "OpenAI Codex harness operations end-to-end: CLI install and sign-in, layered `config.toml` (user/project/profile/system) and its key catalog, approval policies vs sandbox modes, `AGENTS.md` discovery and merge order, Codex Skills (`.agents/skills`, `$skill`), MCP server wiring, `codex exec` headless/CI and the Codex GitHub Action, Codex cloud tasks and environments, git worktrees, `/review` and `@codex` PR reviews, the IDE extension, model IDs and reasoning effort, and enterprise `requirements.toml` / `managed_config.toml` policy. WHEN: \"Codex\", \"Codex CLI\", \"codex exec\", \"config.toml\", \"approval_policy\", \"sandbox_mode\", \"workspace-write\", \"danger-full-access\", \"--yolo\", \"AGENTS.md\", \"AGENTS.override.md\", \"codex mcp add\", \"codex review\", \"@codex review\", \"codex cloud-tasks\", \"Codex cloud environment\", \"codex-action\", \"CODEX_API_KEY\", \"CODEX_HOME\", \"requirements.toml\", \"managed_config.toml\", \"/debug-config\", \"gpt-5.6-sol\", \"model_reasoning_effort\". Do NOT use for: Claude Code settings/hooks/permissions (use `claude-code`); GitHub Copilot's coding agent, IDE features, or CLI (use `github-copilot`); Cursor's editor and agents (use `cursor`); the pi harness (use `pi`); building agents with the OpenAI Agents SDK (use `openai-agents-sdk`), the Claude Agent SDK (`claude-agent-sdk`), or Google ADK (`google-adk`); harness-vs-SDK-vs-API selection and Gemini CLI comparison (use `overview`); the MCP spec itself or writing servers (use `mcp`); authoring SKILL.md content (use `agent-skills`); deep sandbox/egress isolation architecture (use `sandboxing`); prompt-injection threat modeling (use `ai-security`); cross-vendor model catalog comparison (use `model-selection`). Platform security tooling (SIEM/EDR/WAF/SAST) is the security plugin; container and Kubernetes runtime depth is the containers plugin."
license: MIT
---

# OpenAI Codex (the harness)

Configure, secure, and operate OpenAI Codex across all four of its surfaces: the CLI, the IDE extension, the desktop/web app, and Codex cloud. This skill owns the harness — config layering, approvals and sandboxing, `AGENTS.md`, Skills, MCP wiring, headless/CI, cloud environments, code review, and enterprise policy.

Corpus fetched 2026-08-05 against `learn.chatgpt.com/docs` and the `openai/codex` GitHub repo. Note that `developers.openai.com/codex/*` pages 308-redirect to the equivalent `learn.chatgpt.com/docs/*` paths — same OpenAI-owned site; cite the resolved host.

## Answering rules

Always separate the two independent controls before answering any "why did Codex do that?" question: **`sandbox_mode` determines what is technically possible; `approval_policy` determines when Codex must ask first.** Most reported surprises are a permissive approval policy sitting on top of a restrictive sandbox, or the reverse.

Always establish which **config layer** a setting should live in before editing — system (`/etc/codex/config.toml`), user (`~/.codex/config.toml`), profile (`~/.codex/<name>.config.toml`), project (`.codex/config.toml`), or an admin's `requirements.toml`. Wrong layer is the most common cause of "my setting isn't applying", and project config loads **only when the project is trusted**.

Always reach for `/status` and `/debug-config` in-session before reasoning about files. `/status` shows the active model, approval policy, writable roots, and token usage; `/debug-config` prints the config layers in precedence order plus the source of any managed-policy requirement. Both exist in the CLI and the IDE extension.

Never recommend `--dangerously-bypass-approvals-and-sandbox` / `--yolo` / `sandbox_mode = "danger-full-access"` outside an environment that is already hardened externally (a container or VM you control). It removes all filesystem and network restrictions and all approval prompts simultaneously.

Never set `CODEX_API_KEY` as a persistent environment variable in a job that runs untrusted code. Set it inline for a single invocation, or use the Codex GitHub Action, which keeps credentials out of build scripts.

Never treat `AGENTS.md` or memories as enforcement. They shape behavior; `requirements.toml`, sandbox mode, and execpolicy `.rules` are the parts an admin can actually rely on.

## Install and sign-in

```bash
npm install -g @openai/codex
brew install --cask codex

curl -fsSL https://chatgpt.com/codex/install.sh | sh                                  # macOS/Linux
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1|iex" # Windows
```

Binary archives are published on the latest GitHub Release (`codex-aarch64-apple-darwin.tar.gz`, `codex-x86_64-apple-darwin.tar.gz`, `codex-{x86_64,aarch64}-unknown-linux-musl.tar.gz`) — extract and rename the binary to `codex`.

Two auth paths, chosen on first run:

| Path | Use for | Caveat |
|---|---|---|
| **ChatGPT account login** (recommended) | Everything; consistent across desktop, web, CLI, IDE | Usage draws on the ChatGPT plan's shared limits |
| **API key** | Developers billing per token | Cloud features (GitHub reviews, Slack integration) are **not** included; docs say "some features might not be available" |

The desktop app and web require no CLI. First run asks which surface you want (ChatGPT / Codex / Quick chat) and then for a working directory or project.

The exact `codex login` command syntax and flags are **not documented in the fetched corpus** — treat sign-in as the interactive first-run prompt unless the user's own `codex --help` says otherwise.

## config.toml layering

Locations: `~/.codex/config.toml` (user), `.codex/config.toml` (project — loaded only when the project is trusted), `/etc/codex/config.toml` (system, Unix only). `CODEX_HOME` relocates the user directory.

**Precedence, highest first:** CLI flags and `--config` overrides → project config (closest to cwd wins) → profile file (`~/.codex/<name>.config.toml`, activated with `--profile <name>`) → user config → system config → built-in defaults.

```toml
model = "gpt-5.6"
approval_policy = "on-request"    # untrusted | on-request | never
sandbox_mode = "workspace-write"  # read-only | workspace-write | danger-full-access
web_search = "cached"             # cached | indexed | live | disabled
model_reasoning_effort = "high"
review_model = "gpt-5.6-sol"      # separate model for /review
personality = "friendly"          # friendly | pragmatic | none

[sandbox_workspace_write]
writable_roots = ["/path/to/allow"]
network_access = false

[shell_environment_policy]
inherit = "core"
set = { MY_FLAG = "1" }
[shell_environment_policy.filters]
"AWS_*" = "exclude"

[features]
memories = true
multi_agent = true
shell_tool = true
```

`[shell_environment_policy.filters]` is the credential-scrubbing lever — use it to keep `AWS_*`, `GITHUB_*`, and similar out of sandboxed subprocesses instead of hoping the sandbox catches an exfiltration attempt.

`--strict-config` turns unrecognized config keys into errors; use it in CI so a typo fails the build rather than silently reverting to a default.

Read `references/config-reference.md` for the full key catalog, profiles, `[model_providers.*]` proxy/gateway wiring, OTel export, and the layering rules in detail.

## Approvals and sandboxing

```
sandbox_mode  →  what CAN happen
approval_policy → when Codex STOPS to ask
```

| `sandbox_mode` | Behavior |
|---|---|
| `read-only` | Inspect files only; no edits and no commands without approval |
| `workspace-write` | Default for local dev — read anywhere allowed, edit inside the workspace, run routine commands in that boundary |
| `danger-full-access` | No filesystem or network restrictions; "no sandbox, no approvals" |

| `approval_policy` | Behavior |
|---|---|
| `untrusted` | Only known-safe read operations run automatically; anything state-mutating asks |
| `on-request` | Asks to edit outside the workspace or reach the network |
| `never` | No approval prompts at all; autonomy still bounded by the sandbox |

A granular form exists for per-channel control:

```toml
approval_policy = { granular = { sandbox_approval = true, rules = true, mcp_elicitations = true } }
```

Enforcement is OS-native: **macOS** Seatbelt (`sandbox-exec`), **Linux/WSL2** bubblewrap (first `bwrap` on `PATH`, else a bundled helper needing unprivileged user namespaces; Landlock as a compatibility fallback; seccomp also used), **Windows** a native sandbox implementation. `codex sandbox` (aliases `codex sandbox seatbelt`, `codex sandbox landlock`, also surfaced as `codex debug`) runs an arbitrary command inside a profile — use it to test a policy before wiring it into a job.

Read `references/approvals-and-sandbox.md` for mode-combination recipes and the network-access interaction. For isolation architecture at fleet scale — egress proxies, credential injection, gVisor/Firecracker, cross-vendor comparison — use the `sandboxing` sibling skill; it carries `references/codex-sandbox.md` specifically.

## CLI surface

Global flags worth knowing: `--json` / `--experimental-json` (newline-delimited event stream), `--ignore-user-config` (skip `$CODEX_HOME/config.toml`; auth is preserved), `--ignore-rules` (skip user/project execpolicy `.rules`), `--sandbox <mode>`, `-a` / `--ask-for-approval <policy>`, `--profile <name>`, `--strict-config`, `--dangerously-bypass-approvals-and-sandbox` (`--yolo`).

| Command | Purpose |
|---|---|
| `codex exec` (alias `codex e`) | Non-interactive task execution — the CI entry point |
| `codex review` | Non-interactive review of uncommitted changes, a base-branch diff, a commit, or custom instructions |
| `codex sandbox` / `codex debug` | Run a command inside a Codex sandbox profile |
| `codex debug prompt-input` | Dump the exact model-visible prompt input list as JSON — the tool for "why didn't it read my AGENTS.md?" |
| `codex mcp add/list/login` | MCP server management |
| `codex mcp-server` | Run Codex itself as an MCP server over stdio, for another agent to drive |
| `codex cloud-tasks` | Drive Codex cloud tasks from the terminal |

In-session: `/status`, `/debug-config`, `/model`, `/review`, `/mention`.

## AGENTS.md

Codex builds an instruction chain once per run (once per launched TUI session), then merges files **root-down, joined by blank lines** — files closer to the cwd land later in the prompt and therefore override earlier guidance.

Discovery order:

1. **Global** (Codex home, default `~/.codex`): `AGENTS.override.md` first, else `AGENTS.md`. Only the first non-empty file at this level is used.
2. **Project**: walk from the Git root down to the cwd; in each directory check `AGENTS.override.md`, then `AGENTS.md`, then any `project_doc_fallback_filenames`. At most one file per directory.

`AGENTS.override.md` is the temporary-replacement form and takes precedence over `AGENTS.md` in the same directory. `project_doc_max_bytes` defaults to 32 KiB — split large instructions across nested directories rather than growing one file past the cap, or the tail is silently lost.

Codex reads `AGENTS.md`, not `CLAUDE.md`. A repo shared with Claude Code needs both files (Claude Code can bridge with an `@AGENTS.md` import — see the `claude-code` sibling).

Division of labor to quote when a user asks "where does this instruction go?": **AGENTS.md** shapes behavior and is the source of truth for rules that must always apply; **memories** carry local context forward and are a recall layer, not policy; **Skills** package repeatable processes; **MCP** connects Codex to systems outside the workspace.

Read `references/agents-md-and-skills.md` for the full discovery/merge semantics and the Skills system below.

## Skills

Codex Skills are the open agent-skills standard: a folder with a required `SKILL.md` (frontmatter `name` + `description`, then instructions) plus optional `scripts/`, `references/`, `assets/`, and `agents/openai.yaml`.

Discovery scans upward through `.agents/skills` directories — repository scope (cwd, parents, repo root), user scope `$HOME/.agents/skills`, admin scope `/etc/codex/skills`, then skills built into Codex.

Activation is explicit (`$skill` in Codex, `@skill` in ChatGPT) or implicit (selected from the description). Progressive disclosure caps the always-loaded name+description budget at **8,000 characters total** across listed skills — if a skill stops being selected after a team adds more skills, that budget is the first thing to check. `$skill-creator` scaffolds a new one.

`agents/openai.yaml` declares MCP servers as optional dependencies of a skill. For *authoring* good skill content, defer to the `agent-skills` sibling skill.

## MCP configuration

Client side only — for the protocol, transports, and writing servers use the `mcp` sibling.

```toml
[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp"]
env_vars = ["LOCAL_TOKEN"]
required = true            # codex exec exits with an error if this server fails to init
startup_timeout_sec = 10   # default
tool_timeout_sec = 60      # default

[mcp_servers.context7.env]
MY_ENV_VAR = "MY_ENV_VALUE"
```

Other keys: `cwd`, `enabled` (disable without deleting config). Set `required = true` for any server whose absence would make a CI run produce a wrong-but-successful result — otherwise `codex exec` continues without it.

CLI: `codex mcp add <name> -- <stdio-command>`, `codex mcp list`, `codex mcp login <name>` (OAuth). Local Codex clients (desktop app, CLI, IDE extension) connect to MCP servers directly and can share configuration for the same Codex host.

Read `references/mcp-integration.md` for the full key table and `codex mcp-server` reverse-direction usage.

## Headless and CI

```bash
codex exec "task prompt"
codex exec --json "task prompt"                                  # JSONL events on stdout
codex exec --ephemeral "task prompt"                             # don't persist session files
codex exec --sandbox workspace-write --ignore-user-config "task" # reproducible across machines
codex exec --output-schema ./schema.json -o ./out.json "task"    # structured result
npm test 2>&1 | codex exec "summarize failures and propose a fix"
cat prompt.txt | codex exec -                                    # stdin is the whole prompt
```

Pair `--ignore-user-config` with `--ignore-rules` when you need a run to behave identically on every machine — otherwise a developer's `~/.codex/config.toml` changes CI behavior invisibly.

`--json` emits one event object per line; observed types include `thread.started` (carries `thread_id`), `turn.started` / `turn.completed` (carries `input_tokens`, `cached_input_tokens`, `output_tokens`), and `item.*` for commands, file changes, MCP calls, and messages. Parse `turn.completed` for cost telemetry.

**Exit-code semantics are not documented in the fetched corpus.** Do not promise a specific non-zero code for a specific failure; if a pipeline must branch on outcome, parse the `--json` stream or the `--output-last-message` file rather than relying on an undocumented code.

GitHub Actions: prefer `openai/codex-action@v1` over hand-rolling. It installs the CLI, starts the Responses API proxy when given an API key, and runs `codex exec` under specified permissions — keeping the credential out of build scripts.

Read `references/exec-and-ci.md` for the complete flag list, event stream detail, and automation auth patterns.

## Codex cloud

Cloud runs tasks in parallel, isolated environments so work continues unattended. Delegate from the ChatGPT web/desktop app, the CLI (`codex cloud-tasks`), a **GitHub pull request**, a **Linear issue**, or a **Slack channel**. (The Linear and Slack integration pages were not fetched into this corpus — their setup specifics are unverified here.)

An **environment** defines what gets installed and run:

- **Setup script** — runs at container creation, **with internet access**, so dependency installs work.
- **Maintenance script** — runs when a cached container resumes.
- **Environment variables** — visible for the whole chat (setup *and* agent phase).
- **Secrets** — encrypted, available **only during setup**, stripped before the agent phase. Put anything the agent must not see here, not in environment variables.
- **Container image** — defaults to `universal`; reference Dockerfile at `github.com/openai/codex-universal`.

Agent-phase internet is **off by default**. When enabled, it is three-layered: toggle → domain allowlist (`None` / `Common dependencies`, a preset of 89 domains / `All (unrestricted)`) → HTTP method restriction (optionally `GET`/`HEAD`/`OPTIONS` only). The docs' own recommendation: start from `Common dependencies`, then restrict. The 89-domain list is not enumerated in the fetched corpus.

The docs name the risks explicitly — prompt injection from untrusted web content, exfiltration of code or secrets, malware/vulnerable dependency downloads, license violations — with the worked example of an agent following hidden instructions in a web page or GitHub issue and leaking commit messages. Method restriction is the cheap mitigation: read-only verbs make exfiltration much harder.

Caches persist **up to 12 hours** and invalidate when the setup script, maintenance script, environment variables, or secrets change. Business/Enterprise workspaces **share caches workspace-wide** — a relevant fact when a cached container could carry one team's state into another's run.

**Git worktrees** (ChatGPT desktop app only, Git repos only) run multiple chats in parallel on the same repo, each with its own working directory over shared `.git`. Root defaults to `$CODEX_HOME/worktrees`; `.worktreeinclude` copies git-ignored files like `.env` into new worktrees; **Handoff** moves a chat and its changes between Local and Worktree, doing the Git safety work Git otherwise refuses (same branch checked out twice). ~15 Codex-managed worktrees are retained by default, oldest auto-removed; pinned/active/permanent ones are protected.

Read `references/cloud-and-environments.md` for the full environment, internet-access, and worktree detail.

## Code review and GitHub

`/review` works in ChatGPT Work, the CLI, and the IDE extension (IDE requires a Git repo), with four scopes: base-branch diff, uncommitted changes (staged + unstaged + untracked), a single commit, or custom instructions. Findings land as inline comments in the review pane; hover a line and use **+** to reply with guidance for the follow-up.

Set `review_model` in `config.toml` to review with a stronger model than you chat with. Set `chatgpt.reviewDelivery = "detached"` (IDE) to keep reviews out of the working chat.

GitHub PR reviews: set up Codex cloud for the repo, then toggle **Code review** on at `chatgpt.com/codex/settings/code-review`, optionally with **Automatic reviews** for all new PRs. Comment `@codex review` on a PR — Codex reacts 👀 and posts a review covering **only P0 and P1 severity issues**. Add focus inline (`@codex review for security regressions`). Any `@codex` mention that isn't "review" starts a cloud task with the PR as context.

Codex can read PR diffs, post reviews, follow `AGENTS.md`, and **push fixes** when permitted. Scope its review checks with a **"Code Review Rules"** section in `AGENTS.md`, root-level or per-service. The GitHub App's exact OAuth permission scopes are not stated in the fetched corpus — have the user read the consent screen before approving.

For the in-editor PR sidebar (PR context and reviewer comments alongside diffs), install the GitHub CLI and run `gh auth login`.

## IDE extension

VS Code and VS Code-compatible editors (Cursor, Windsurf), plus native Xcode and JetBrains integrations. Install from the marketplace, open the sidebar (or run "Codex: Open Codex Sidebar"), sign in.

The IDE **automatically includes open files as context** — the CLI does not, which is why the same prompt behaves differently across surfaces. In both, `@` + path triggers autocomplete; in the CLI, `/mention` attaches. Highlight lines and use "Add to Codex Thread" to narrow context to a selection.

IDE-only `chatgpt.*` settings: `reviewDelivery` (`inline` | `detached`), `composerEnterBehavior`, `followUpQueueMode` (queue follow-ups vs steer the running turn), `runCodexInWindowsSubsystemForLinux`, font sizes. Agent-level settings still come from `config.toml`, so a team standard in `.codex/config.toml` applies to the IDE too.

Read `references/ide-and-review.md` for the settings layering and review-pane Git actions.

## Models and reasoning effort

| Model | ID | Use for |
|---|---|---|
| 5.6 Sol | `gpt-5.6-sol` | Complex coding, computer use, research, cybersecurity |
| 5.6 Terra | `gpt-5.6-terra` | Everyday work; competitive with GPT-5.5 at lower cost |
| 5.6 Luna | `gpt-5.6-luna` | Repetitive structured work; lowest cost in the family |
| 5.3 Codex Spark | `gpt-5.3-codex-spark` | Text-only research preview for near-instant iteration (ChatGPT Pro) |

GPT-5.5/5.4/5.4 Mini remain available; **GPT-5.4 variants are scheduled to retire 2026-08-31** — flag this whenever a user pins one.

`model_reasoning_effort`: low, medium (default), high, extra high, max, plus **ultra**, which delegates to parallel subagents. Raise effort only when the task actually needs it; it is the main cost/latency lever after model choice.

Switch with `/model` in session, `codex --model gpt-5.6` / `codex exec -m gpt-5.6-sol`, `model = "..."` in config, or the GUI selector.

Read `references/models-and-pricing.md` for plan tiers, the rolling 5-hour usage windows, and the credit rates for overage. These figures are time-sensitive — re-verify before quoting. For choosing models *across* vendors, use the `model-selection` sibling.

## Enterprise controls

Two independent layers, and users hit both:

**Workspace RBAC** governs who can reach which surface at all. The docs model administration as **six control boundaries** — ChatGPT workspace, local clients, Codex cloud, Platform API, plugins, connected systems — with the operative rule: *"A request must pass every boundary that applies to it."* Access at one boundary never implies access at another. Concrete role names and seat types are deferred to Help Center articles and are **not in the fetched corpus** — do not assert that a role named "Codex Admin" exists.

**Config-file policy** governs what settings are allowed once someone is on a surface:

| File | Force | Behavior |
|---|---|---|
| `requirements.toml` | Non-overrideable | On conflict the client falls back to a compatible value and notifies the user |
| `managed_config.toml` | Defaults only | Applied at launch; users may change mid-session, defaults reapply next startup |

Paths: `/etc/codex/managed_config.toml` (Linux/macOS), `~/.codex/managed_config.toml` (Windows), or macOS MDM preference domain `com.openai.codex` with keys `config_toml_base64` / `requirements_toml_base64`.

`requirements.toml` can constrain approval policy, sandbox mode, permission profiles, web search, MCP servers, plugin marketplace sources, feature flags (browser use, computer use, plugins, hooks), network allow/deny domain lists, filesystem deny-read patterns, appshot and device-remote-control toggles, and `allow_managed_hooks_only = true` (restricts user/project hooks to managed hooks — **supported only in `requirements.toml`**).

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

Read `references/enterprise.md` for the full policy schema, the RBAC boundary model, and how the two layers compose.

## Reference files

- `references/config-reference.md` — full `config.toml` key catalog, layering and profiles, model providers/proxies, OTel, diagnostics
- `references/approvals-and-sandbox.md` — approval policies, sandbox modes, OS enforcement, mode-combination recipes
- `references/agents-md-and-skills.md` — `AGENTS.md` discovery/merge/limits, Codex Skills layout, discovery, activation, progressive disclosure
- `references/mcp-integration.md` — `[mcp_servers.*]` key table, CLI commands, Codex as an MCP server
- `references/exec-and-ci.md` — `codex exec` flags, JSONL event stream, stdin patterns, GitHub Action, automation auth
- `references/cloud-and-environments.md` — cloud task delegation, environment setup/secrets/caching, agent internet access, git worktrees
- `references/ide-and-review.md` — IDE install and features, `chatgpt.*` settings, `/review` scopes, GitHub PR integration
- `references/models-and-pricing.md` — model IDs, reasoning effort, plans, usage windows, credits (time-sensitive)
- `references/enterprise.md` — `requirements.toml` / `managed_config.toml`, RBAC control boundaries, rollout areas

## Diagnostic script

- `scripts/01-codex-inventory.sh` — read-only inventory: CLI version, which config layers exist, managed policy presence, the `AGENTS.md` chain that would be discovered from the cwd, `.agents/skills` directories, and configured MCP servers. Run it first when a setting "isn't applying".

## Known documentation gaps

Treat these as unverified rather than guessing: `codex exec` exit-code enumeration; named enterprise RBAC roles and their capability matrices; the Linear and Slack cloud integrations; the GitHub App's OAuth scope list; the verbatim 89-domain "Common dependencies" allowlist; USD-to-credit conversion and Enterprise/Edu pricing; SSO/SCIM provisioning, workspace analytics, and the compliance API; the `codex-sdk` / `app-server` programmatic surfaces; the `agents/openai.yaml` schema beyond MCP dependency declaration; explicit `codex login` flags.

## Sources

- https://github.com/openai/codex/blob/main/README.md
- https://github.com/openai/codex/blob/main/docs/config.md
- https://github.com/openai/codex/releases/latest
- https://learn.chatgpt.com/docs/quickstart
- https://learn.chatgpt.com/docs/config-file/config-basic
- https://learn.chatgpt.com/docs/config-file/config-advanced
- https://learn.chatgpt.com/docs/developer-commands?surface=cli
- https://learn.chatgpt.com/docs/sandboxing
- https://learn.chatgpt.com/docs/agent-approvals-security
- https://learn.chatgpt.com/docs/agent-configuration/agents-md
- https://learn.chatgpt.com/docs/build-skills
- https://learn.chatgpt.com/docs/extend/mcp?surface=cli
- https://learn.chatgpt.com/docs/non-interactive-mode
- https://learn.chatgpt.com/docs/cloud
- https://learn.chatgpt.com/docs/cloud/internet-access
- https://learn.chatgpt.com/docs/environments/cloud-environment
- https://learn.chatgpt.com/docs/environments/git-worktrees
- https://learn.chatgpt.com/docs/code-review
- https://learn.chatgpt.com/docs/third-party/github
- https://learn.chatgpt.com/docs/ide
- https://learn.chatgpt.com/docs/prompting
- https://learn.chatgpt.com/docs/developer-settings
- https://learn.chatgpt.com/docs/models
- https://learn.chatgpt.com/docs/pricing
- https://learn.chatgpt.com/docs/enterprise/managed-configuration
- https://learn.chatgpt.com/docs/enterprise/admin-setup
- https://learn.chatgpt.com/docs/enterprise/roles-and-workspace-permissions

Fetched: 2026-08-05
