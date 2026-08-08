# Cursor cloud (background) agents and the CLI

Read this when setting up cloud agents, writing `.cursor/environment.json`, managing cloud-agent secrets or networking, or scripting the `cursor-agent` CLI in a terminal or CI pipeline.

## Cloud / background agents overview

> Source: https://cursor.com/docs/background-agent, https://cursor.com/help/ai-features/background-agents.md

Cloud Agents "operate in isolated virtual machines with full development environments" rather than running locally: "Cloud agents use the same agent fundamentals but run in isolated VMs in the cloud with full development environments instead of on your local machine." They plan the task, edit code, run commands, and test their work over minutes or hours, with parallel execution and independent internet access.

**Launch methods:**

| Surface | How |
|---|---|
| Cursor Desktop | Select "Cloud" in the agent input dropdown |
| Web | `cursor.com/agents`, on any device |
| Mobile | Cursor iOS app, or a Progressive Web App on Android |
| Version control | Comment `@cursor` on a GitHub/Bitbucket PR or issue |
| Team tools | `@cursor` command in Slack or Linear |
| Programmatic | API |
| Scheduled | Automations |
| CLI | Prefix a prompt with `&` to hand off to a cloud agent |

**Output and validation:** agents attach videos, screenshots, and logs to pull requests so results can be validated without checking out the branch. Remote desktop access allows direct testing of the running software.

**Prerequisites:**

- An account admin must connect source control (GitHub, GitLab, Bitbucket Cloud, Azure DevOps) with **read-write** repository privileges.
- Dependent repos and submodules need their own accessible permissions — a monorepo-adjacent private dependency is the usual first failure.
- Individual users must connect personal source-control accounts to view shared agent runs.
- Slack: workspace admins install the Cursor Slack app; team members then trigger agents via `@cursor` and receive notifications.

**Security/isolation:** "secret redaction, network policies, and credential management," with user control over repo access, secret exposure, and network permissions. The VM is sandboxed and isolated from the local machine.

**Pricing:** "Cloud Agents are charged at API pricing for the selected model." Token costs scale with the selected context window; users set a spend limit on first activation.

Cloud agents do **not** support multi-root workspaces (see `rules-and-context.md`) and run command-based hooks only (see `hooks.md`).

## Environment setup: `.cursor/environment.json`

> Source: https://cursor.com/docs/cloud-agent/setup.md

Cloud agents run on isolated Ubuntu VMs. Two setup paths:

1. **Agent-driven setup (recommended)** — Cursor auto-configures the environment in under 10 minutes by inspecting the repo and its dependencies, saving the result to `.cursor/environment.json`.
2. **Manual Dockerfile** — for specific system dependencies, compiler versions, or custom OS images; reference the Dockerfile from `environment.json`.

Schema sections:

| Section | Purpose |
|---|---|
| `build` | `{ "dockerfile": "<relative path within .cursor>", "context": ".." }` |
| `install` | Script run **once per Build** to install dependencies |
| `start` | Command run **every time the agent boots** (e.g. `sudo service docker start`) |
| `terminals` | Processes kept alive during the agent run, in shared tmux sessions |
| `snapshot` | Reference a pre-built environment snapshot by ID |

```json
{
  "build": { "dockerfile": "Dockerfile", "context": ".." },
  "install": "pnpm install && ./custom_script.sh"
}
```

`install` **must be idempotent** — it may run against previously-prepared disk state. Do not put long-running processes, databases, Docker, or dev servers in `install`; those belong in `start` (one-shot boot commands) or `terminals` (persistent runtime services).

**Resolution priority:** `.cursor/environment.json` in the repo → personal saved environment → team saved environment. A committed file therefore always wins over dashboard-saved environments.

## Secrets

> Source: https://cursor.com/docs/cloud-agent/setup.md

Secrets are stored via the Cursor dashboard's **Secrets tab**, not in the repo.

- **Environment-scoped secrets** — available only to specific environments, for multi-repo setups
- **Standard secrets** — global across environments
- **AWS IAM role assumption** — via a `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` secret, with external-ID validation. Prefer this over storing long-lived AWS keys.
- **TOTP 2FA** — store the shared secret and generate codes with `oathtool --totp -b "$TOTP_SECRET"`

## Networking

> Source: https://cursor.com/docs/cloud-agent/setup.md

- **Tailscale** — supported via userspace networking mode (`--tun=userspace-networking`) with proxy environment variables.
- **Cloudflare Tunnel** — natively supported: install `cloudflared`, store service tokens as secrets, route authenticated hostnames to private origins.
- **Docker inside the agent** — requires the `fuse-overlayfs` storage driver and `iptables-legacy`.

These three are the documented paths to reach a private origin from a cloud agent. There is no documented VPC-peering or on-prem option (see `enterprise-and-privacy.md`).

## Cursor CLI

> Source: https://cursor.com/docs/cli/overview

Installation:

```bash
curl https://cursor.com/install -fsS | bash            # macOS / Linux / WSL
irm 'https://cursor.com/install?win32=true' | iex      # Windows PowerShell
```

Core commands:

```bash
agent                                    # interactive session
agent "refactor the auth module to use JWT tokens"   # session with an initial objective
agent ls                                 # view previous conversations
agent resume                             # continue the latest session
agent --continue                         # maintain previous context
agent --resume="chat-id"                 # open a specific conversation
```

Interactive sessions let you "describe your goals, review proposed changes, and approve commands."

Modes — switchable by slash command, keyboard shortcut, or flag:

| Mode | Purpose | Access |
|------|---------|--------|
| Agent | Full tool access for complex coding tasks | Default |
| Plan | Design the approach, asks clarifying questions | `--plan` or `/plan` |
| Ask | Read-only exploration | `--mode=ask` |

## CLI usage detail

> Source: https://cursor.com/docs/cli/using.md

| Flag / command | Effect |
|---|---|
| `--mode=[plan\|ask\|agent]` | Set operational mode |
| `--worktree [name]` / `-w` | Create an isolated Git worktree for edits |
| `--workspace <path>` | Specify the repo root explicitly |
| `-p` / `--print` | Non-interactive mode |
| `--output-format [json\|text]` | Control response formatting |
| `&` prefix on a prompt | Hand the task off to a Cloud Agent for background processing |
| `/resume` | Resume within an active session |
| `/summarize` or `/compress` | Reduce context window usage |
| `agent acp` | Agent Client Protocol, for custom integrations |

Input shortcuts: `Shift+Tab` (cycle modes), `Shift+Enter` (newline in iTerm2/Ghostty/Kitty/Warp/Zed), `Ctrl+J` (universal newline, tmux-compatible), `Ctrl+D` twice (exit), `ArrowUp` (message history), `Ctrl+R` (review changes, then `i` for follow-ups), `@` (select files/folders for context).

**Configuration the CLI reads:** rules from `.cursor/rules`; `AGENTS.md` and `CLAUDE.md` at the project root, loaded as rules; `mcp.json`, auto-detected for MCP servers.

**Worktrees** are stored at `~/.cursor/worktrees/<reponame>/<name>` and auto-cleaned per the editor retention policy. Worktrees are disabled in multi-root workspaces.

## Headless and CI

> Source: https://cursor.com/docs/cli/headless.md

| Flag | Effect |
|---|---|
| `-p` / `--print` | Non-interactive scripting mode |
| `--force` (alias `--yolo`) | Allow direct file changes without confirmation |
| `--stream-partial-output` | Incremental streaming of response deltas |
| `--output-format text` | Clean, final-answer-only response (default) |
| `--output-format json` | Structured output for programmatic parsing |
| `--output-format stream-json` | Message-level progress tracking with real-time updates |

**Without `--force`, changes are only proposed** — this is the reason a headless run "did nothing" in CI. Conversely, `--force` in an unsandboxed CI runner grants unreviewed write access; pair it with an ephemeral runner.

File paths referenced in a prompt are processed automatically — the agent uses tool calling to read images, video, and binary data without explicit file-reading commands. Batch processing loops over files with ordinary shell `find`/`for` constructs.

Documented CI/CD patterns: automated code review with structured output, real-time progress tracking by parsing `stream-json`, batch media processing, and exit-code handling for pipeline control. **Requires the `CURSOR_API_KEY` environment variable.**

## Unverified

The following CLI documentation pages were listed in the site index but not fetched; treat their specifics as unconfirmed:

`cli/installation.md`, `cli/changelog.md`, `cli/shell-mode.md`, `cli/acp.md`, `cli/reference/slash-commands.md`, `cli/reference/parameters.md`, `cli/reference/authentication.md`, `cli/reference/permissions.md`, `cli/reference/configuration.md`, `cli/reference/output-format.md`, `cli/reference/terminal-setup.md`, `cli/github-actions.md`.

Also unconfirmed: the exact GitHub PR-comment agent syntax beyond an `@cursor` mention, and Linear integration setup steps.

## Sources

- https://cursor.com/docs/background-agent
- https://cursor.com/help/ai-features/background-agents.md
- https://cursor.com/docs/cloud-agent/setup.md
- https://cursor.com/docs/cli/overview
- https://cursor.com/docs/cli/using.md
- https://cursor.com/docs/cli/headless.md

Fetched: 2026-08-05
