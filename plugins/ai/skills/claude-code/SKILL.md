---
name: claude-code
description: "Claude Code harness operations end-to-end: install/auth precedence, settings.json scopes incl. server-managed settings, permission rules and all permission modes, hooks, subagents, skills, plugins/marketplaces, MCP client config, headless `claude -p` and GitHub Actions, enterprise deployment (Bedrock/Vertex/devcontainers), CLAUDE.md memory, slash commands, and OpenTelemetry monitoring. WHEN: \"Claude Code\", \"claude -p\", \"--bare\", \"settings.json\", \"managed-settings.json\", \"server-managed settings\", \"permissions.deny\", \"permission mode\", \"bypassPermissions\", \"acceptEdits\", \"auto mode\", \"PreToolUse hook\", \"subagent\", \".claude/agents\", \"claude mcp add\", \"plugin marketplace\", \"claude-code-action\", \"CLAUDE_CODE_USE_BEDROCK\", \"CLAUDE_CODE_USE_VERTEX\", \"CLAUDE.md\", \"/doctor\", \"CLAUDE_CODE_ENABLE_TELEMETRY\". Do NOT use for: building custom agents with the Claude Agent SDK (use `agent-sdk`); the raw Claude Messages API, model IDs, or pricing (use `claude-api`); the Model Context Protocol spec, transports, or writing MCP servers (use `mcp`); authoring SKILL.md content and progressive disclosure (use `agent-skills`); sandbox/egress isolation architecture at enterprise scale (use `sandboxing`); prompt-injection and agent threat modeling (use `ai-security`); choosing harness vs SDK vs raw API (use `overview`). Platform security tooling (SIEM/EDR/WAF) is the security plugin; container/Kubernetes runtime depth is the containers plugin."
license: MIT
---

# Claude Code (the harness)

Configure, secure, and operate the Claude Code CLI. This skill covers the harness surface — settings, permissions, hooks, subagents, skills, plugins, MCP wiring, headless/CI, enterprise deployment, memory, and telemetry.

Corpus fetched 2026-08-05 against `code.claude.com/docs`. Many behaviors below are gated on a CLI version (`v2.1.x+`); when a user reports a feature "not working", check their `claude --version` against `references/versions/2.1.md` before debugging further.

## Answering rules

Always ask which **scope** a change belongs in before editing config — user (`~/.claude/settings.json`), project (`.claude/settings.json`, committed), local (`.claude/settings.local.json`, gitignored), or managed. Wrong scope is the single most common cause of "my setting isn't applying".

Always prefer a **deny rule or hook** over a conversational instruction when the user wants a guarantee. Instructions stated in chat are advisory context and are lost on compaction; `permissions.deny` and `PreToolUse` hooks are enforced by the harness.

Never claim a managed/server-managed setting is a security boundary on an unmanaged device. It is a client-side control; a user without admin rights can bypass it (modified binary, older CLI, different org). Say so and point at MDM-delivered endpoint-managed settings for a hard boundary.

Never recommend `--dangerously-skip-permissions` / `bypassPermissions` outside an isolated container or VM, and never as root — the CLI refuses to start as root/sudo outside a recognized sandbox.

Always reach for `/status`, `/doctor`, `/context`, `/hooks`, `/permissions`, and `/mcp` first when diagnosing — they report which sources are actually active, which beats reasoning about files.

## Install and first run

```bash
curl -fsSL https://claude.ai/install.sh | bash        # macOS/Linux/WSL, auto-updates
irm https://claude.ai/install.ps1 | iex               # Windows PowerShell
```

Homebrew (`brew install --cask claude-code`) and WinGet (`winget install Anthropic.ClaudeCode`) do **not** auto-update — the user must run the package manager's upgrade. apt/dnf/apk packages exist for Debian/Fedora/RHEL/Alpine. Verify with `claude --version`.

On native Windows, install Git for Windows so the Bash tool works; without it Claude Code falls back to PowerShell as the shell tool. WSL setups need nothing extra.

Entry points: `claude` (interactive), `claude "task"` (one task then interactive), `claude -p "query"` (headless), `claude -c` (continue latest), `claude -r` (resume a chosen session).

## Authentication

Login paths: Claude Pro/Max subscription, Claude for Teams/Enterprise, Claude Console API billing (admin grants the **Claude Code** role for Claude-Code-only keys or **Developer** for any key), cloud providers (Bedrock / Google Cloud's Agent Platform / Microsoft Foundry), or a self-hosted Claude apps gateway via corporate SSO.

**Precedence, highest first** — quote this when a user's credentials "aren't being used":

1. Cloud provider (`CLAUDE_CODE_USE_BEDROCK` / `_USE_VERTEX` / `_USE_FOUNDRY` set)
2. `ANTHROPIC_AUTH_TOKEN` (`Authorization: Bearer`, gateway/proxy use)
3. `ANTHROPIC_API_KEY` (`X-Api-Key`; always used in `-p` mode)
4. `apiKeyHelper` script output (rotating credentials)
5. `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`)
6. Subscription OAuth from `/login`

A signed-in Claude apps gateway session sits outside this list and outranks Bedrock/Vertex/Foundry selection.

Credentials live in the macOS Keychain, or `~/.claude/.credentials.json` (mode 0600) on Linux, or `%USERPROFILE%\.claude\.credentials.json` on Windows; `CLAUDE_CONFIG_DIR` relocates them on Linux/Windows.

For CI, mint a one-year token with `claude setup-token` and export `CLAUDE_CODE_OAUTH_TOKEN`. It requires a Pro/Max/Team/Enterprise plan, can only make model requests, and is **not** read by `--bare` mode — use `ANTHROPIC_API_KEY` or `apiKeyHelper` there.

Lock login to one org from managed settings with `forceLoginMethod` + `forceLoginOrgUUID`; note it cannot verify env-credential sessions (so it blocks them) and does not block cloud-provider sessions — restrict those with cloud IAM. Full nuances in `references/settings-and-auth.md`.

## Settings hierarchy

Priority, highest first: **managed** → **CLI arguments** → **local** (`.claude/settings.local.json`) → **project** (`.claude/settings.json`) → **user** (`~/.claude/settings.json`).

Scalar keys are last-scope-wins, but **permission rules merge across scopes** and arrays generally concatenate and de-duplicate. Managed settings cannot be overridden by lower scopes.

Endpoint-managed file locations: `/etc/claude-code/managed-settings.json` (Linux/WSL), `/Library/Application Support/ClaudeCode/managed-settings.json` (macOS), `C:\Program Files\ClaudeCode\managed-settings.json` (Windows); a `managed-settings.d/*.json` drop-in directory supports modular policy.

Most keys live-reload (`permissions`, `hooks`, `env`, `apiKeyHelper`); `model` and `outputStyle` need a restart — use `/model` mid-session instead.

Read `references/settings-and-auth.md` for the full settings key catalog by area, managed-only keys, environment-variable overrides, and the complete server-managed settings behavior (fetch/caching, withheld `env` categories, `forceRemoteSettingsRefresh`, platform availability).

**Server-managed settings** (Teams/Enterprise) are configured at `claude.ai/admin-settings/claude-code` by an Owner and delivered from Anthropic's servers at auth time — no MDM required. Within the managed tier they are checked **first** and do not merge with endpoint-managed settings: if the server delivers any keys at all, endpoint-managed is ignored entirely. They are unavailable on Bedrock/Vertex/Foundry/custom `ANTHROPIC_BASE_URL`.

## Permissions

Rules are `ToolName(pattern)` under `permissions.allow` / `.deny` / `.ask`:

```json
{
  "permissions": {
    "allow": ["Bash(npm run lint)", "Bash(npm run test *)", "Read(~/.zshrc)"],
    "deny": ["Bash(curl *)", "Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)"],
    "defaultMode": "acceptEdits"
  }
}
```

The space before `*` matters: `Bash(git diff *)` is a prefix match on `git diff `, while `Bash(git diff*)` also matches `git diff-index`. Other rule shapes: `Edit(*.ts)`, `Agent(subagent-name)`, `Skill(name)` / `Skill(name *)`, and MCP patterns `mcp__<server>__<tool>` / `mcp__<server>` / `mcp__*`.

| Mode | Runs without asking | Use for |
|---|---|---|
| `default` (label **Manual**) | Reads only | Sensitive work |
| `acceptEdits` | Reads, edits, common fs commands in scope | Iterating on reviewed code |
| `plan` | Reads; classifier-approved commands when auto mode is available | Exploring before changing |
| `auto` | Everything, behind a classifier | Long tasks |
| `dontAsk` | Only pre-approved tools; auto-denies the rest | CI/locked-down scripts |
| `bypassPermissions` | Everything (explicit `ask` rules and the root/home `rm -rf` circuit breaker still prompt) | Isolated containers only |

Set with `--permission-mode <mode>` or `permissions.defaultMode`; `Shift+Tab` cycles `default → acceptEdits → plan` in-session (`dontAsk` never appears in the cycle).

Writes to **protected paths** (`.git`, `.claude`, `.vscode`, `.devcontainer`, `.mcp.json`, `.claude.json`, shell rc files, `.npmrc`, …) are never auto-approved except in `bypassPermissions` — the safety check runs *before* rule evaluation, so a matching `allow` rule does not help.

`defaultMode: "auto"` is ignored in project/local settings so a repo cannot grant itself auto mode; it must be set in user scope.

Read `references/permissions.md` for the full mode semantics, the auto-mode classifier's default blocked/allowed action lists, its fallback thresholds, subagent interaction, and the complete protected-path table.

## Hooks

Hooks are the only way to make something happen deterministically every time. Configure under `hooks` in any settings scope, in a plugin's `hooks/hooks.json`, or in skill/agent frontmatter.

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash",
        "hooks": [{ "type": "command", "if": "Bash(rm *)", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh" }] }
    ]
  }
}
```

Handler types: `command`, `http`, `mcp_tool`, `prompt`, `agent`. Exit code 0 = success (stdout parsed as JSON output), **2 = blocking error** (stderr shown to Claude), anything else = non-blocking.

Only some events are blockable — `PreToolUse`, `PermissionRequest`, `UserPromptSubmit`, `UserPromptExpansion`, `Stop`/`SubagentStop`, `PreCompact`, `ConfigChange` (except `policy_settings`), `TaskCreated`/`TaskCompleted`, `TeammateIdle`, `PostToolBatch`, `Elicitation*`, `WorktreeCreate`. `PostToolUse` and friends are informational: the tool already ran.

Debug with `/hooks` (read-only browser showing matcher, handler, and source) and `CLAUDE_CODE_DEBUG=1`.

Read `references/hooks.md` before writing any hook — it carries every event, its matcher values, per-event input fields, the JSON output schema, path placeholders, and the common failure modes.

## Subagents

Markdown files with YAML frontmatter in `.claude/agents/` (project), `~/.claude/agents/` (user), a plugin's `agents/`, or session-only via `--agents '<json>'`.

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Glob, Grep
model: sonnet
---
You are a code reviewer. Give specific, actionable feedback.
```

Only `name` and `description` are required. Built-ins: `Explore` and `Plan` (read-only, skip CLAUDE.md and git status), `general-purpose`, `claude`, `statusline-setup`, `claude-code-guide`.

Subagents run in **background by default** (v2.1.198+), which also narrows their tool pool — if a custom subagent is missing a tool it should have, that filter is usually why. Plugin subagents silently ignore `hooks`, `mcpServers`, and `permissionMode` for security.

Invoke by name in prose, by `@agent-<name>`, or run one as the whole session with `claude --agent <name>`.

Read `references/subagents.md` for the full frontmatter table, scope precedence, model resolution order, the two tool filters, worktree isolation, memory scopes, and output scanning.

## Skills

A skill is `SKILL.md` + supporting files under `.claude/skills/<name>/` (project), `~/.claude/skills/<name>/` (personal), or a plugin's `skills/`. Name-clash precedence: enterprise > personal > project > bundled; plugin skills are namespaced `plugin-name:skill-name` and never conflict. `.claude/commands/*.md` still work and are merged into the same `/name` namespace, with skills winning.

Key harness-side frontmatter (Claude Code extensions beyond the Agent Skills spec): `disable-model-invocation`, `user-invocable`, `allowed-tools`/`disallowed-tools` (granted for the invoking turn only), `context: fork` + `agent`, `paths`, `hooks`, `argument-hint`/`arguments`. Only `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools` are valid outside Claude Code — any other key hard-fails an uploaded/packaged skill.

Control access with `Skill(name)` permission rules and the `skillOverrides` setting (`on` / `name-only` / `user-invocable-only` / `off`). `user-invocable: false` hides a skill from the `/` menu but does **not** block the Skill tool — use `disable-model-invocation: true` for that.

Read `references/skills-and-plugins.md` for the full frontmatter table, invocation-control matrix, string substitutions, `` !`command` `` dynamic context injection, and the skill content lifecycle. For *authoring* good skill content, defer to the `agent-skills` sibling skill.

## Plugins and marketplaces

A plugin is a directory with `.claude-plugin/plugin.json` plus component dirs at the plugin root (`skills/`, `agents/`, `hooks/hooks.json`, `.mcp.json`, `.lsp.json`, `monitors/monitors.json`, `bin/`, `commands/`).

```bash
claude plugin validate ./my-plugin --strict
claude --plugin-dir ./my-plugin          # local dev; beats an installed plugin of the same name
/plugin marketplace add owner/repo
/reload-plugins                          # pick up changes without restart
```

`marketplace.json` needs `name`, `owner`, `plugins`; plugin sources may be a relative path, `github`, `url`, `git-subdir`, or `npm`. **Setting `version` pins the plugin — bump it every release or users never receive updates.** Omit `version` on git sources to treat each commit as a new version. Never set `version` in both `plugin.json` and the marketplace entry: `plugin.json` wins silently.

Teams distribute via `extraKnownMarketplaces` + `enabledPlugins` in project settings; admins lock down with `strictKnownMarketplaces` and `blockedMarketplaces` in managed settings.

Read `references/skills-and-plugins.md` for the full marketplace schema, reserved marketplace names, strict mode, `renames`, container/CI seeding, and private-repo credential handling.

## MCP configuration

This section is the *client* side only. For the protocol itself — spec, primitives, OAuth server implementation, writing servers — use the `mcp` sibling skill.

```bash
claude mcp add --transport http notion https://mcp.notion.com/mcp
claude mcp add --env KEY=VAL --transport stdio airtable -- npx -y airtable-mcp-server
claude mcp list && claude mcp get notion
claude mcp login sentry [--no-browser]
```

Scopes: `local` (default, private to you in this project, stored in `~/.claude.json`), `project` (`.mcp.json`, committed, requires per-developer approval — reset with `claude mcp reset-project-choices`), `user` (all your projects). Duplicate resolution order: local > project > user > plugin-provided > claude.ai connectors; the first three match by name, the last two by endpoint.

`.mcp.json` expands `${VAR}` and `${VAR:-default}` in `command`, `args`, `env`, `url`, `headers`. A `url` entry with no `type` is a hard error — add `"type": "http"`.

Operational limits worth knowing: output warns at 10,000 tokens and truncates at 25,000 (`MAX_MCP_OUTPUT_TOKENS`); idle timeout 5 min HTTP / 30 min stdio; HTTP/SSE auto-reconnect up to 5 attempts, stdio never reconnects; a main-conversation call still running after 2 minutes auto-backgrounds (v2.1.212+).

Read `references/mcp-config.md` for OAuth pre-registration, `headersHelper` dynamic auth, plugin-provided servers and their tool-name form, org connector controls, and tool search.

## Headless and CI

```bash
claude -p "Find and fix the bug in auth.py" --allowedTools "Read,Edit,Bash"
claude --bare -p "Summarize README.md" --allowedTools "Read"
claude -p "Extract function names" --output-format json --json-schema '{"type":"object","properties":{"functions":{"type":"array","items":{"type":"string"}}},"required":["functions"]}'
```

Prefer `--bare` for anything scripted. It skips auto-discovery of hooks, skills, plugins, MCP servers, auto memory, and CLAUDE.md so every machine behaves identically — then pass context explicitly via `--append-system-prompt(-file)`, `--settings`, `--mcp-config`, `--agents`, `--plugin-dir`/`--plugin-url`. `--bare` never reads OAuth credentials or the keychain.

Use `--permission-mode dontAsk` (or a tight `--allowedTools`) in CI so a run can never block waiting for input. Exit code 0 means success; branch on it.

Fail CI on harness misconfiguration by inspecting the `system/init` stream event: `plugin_errors` and (v2.1.219+) `mcp_server_errors` are non-empty when a plugin or `--mcp-config` entry failed to load.

GitHub Actions: `/install-github-app` for setup, then `anthropics/claude-code-action@v1`. In v1 the beta inputs collapsed into `claude_args` raw CLI passthrough (`mode` removed, `direct_prompt`→`prompt`, `allowed_tools`→`claude_args: --allowedTools`, and so on). `prompt` accepts a skill invocation like `/plugin-name:skill-name`.

Read `references/headless-ci-enterprise.md` for the full flag/pattern set, stream events, the Actions parameter list, and Bedrock/Vertex-via-Actions OIDC wiring.

## Enterprise deployment

**Bedrock**: `export CLAUDE_CODE_USE_BEDROCK=1` plus standard AWS credentials (`/setup-bedrock` runs a wizard). Always pin `ANTHROPIC_DEFAULT_OPUS_MODEL` / `_SONNET_MODEL` / `_HAIKU_MODEL` to cross-region inference profile IDs for multi-user deployments — unpinned aliases resolve to Claude Code's built-in default, which may not be enabled in the account. `/logout` and WebSearch are unavailable on Bedrock.

**Google Cloud's Agent Platform (Vertex AI)**: `CLAUDE_CODE_USE_VERTEX=1`, `CLOUD_ML_REGION`, `ANTHROPIC_VERTEX_PROJECT_ID`, ADC or Workload Identity Federation, `roles/aiplatform.user`. Per-model region overrides via `VERTEX_REGION_CLAUDE_*`. `/logout` unavailable.

**Dev containers**: add the `ghcr.io/anthropics/devcontainer-features/claude-code:1.0` feature. To survive rebuilds, mount a volume at `/home/node/.claude` **and** set `CLAUDE_CONFIG_DIR` to it — otherwise `~/.claude.json` (OAuth account, MCP servers, trust decisions) is lost. Baking `managed-settings.json` into the image gives highest precedence but is bypassable by anyone with repo write access; use server-managed settings or MDM for real policy.

**Restricted networks**: `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` and `DISABLE_AUTOUPDATER=1`; proxy/CA config travels in settings `env` (`HTTPS_PROXY`, `NODE_EXTRA_CA_CERTS`, `CLAUDE_CODE_CLIENT_CERT`/`_KEY`) — note these are among the cached `env` values server-managed settings deliberately withhold until confirmed.

**Sandboxing** (summary only — architecture and enterprise egress control belong to the `sandboxing` sibling skill): `{"sandbox": {"enabled": true}}` uses macOS Seatbelt natively, needs `bubblewrap` + `socat` on Linux/WSL2, and is unsupported on native Windows. Default writes are cwd + session temp; network is proxy-enforced with no domains pre-allowed. Add `sandbox.failIfUnavailable: true` in managed settings so a missing dependency fails loudly instead of silently running unsandboxed. `/sandbox` shows the resolved config.

## CLAUDE.md and memory

Two systems load at the start of every conversation: **CLAUDE.md** (you write it — instructions) and **auto memory** (Claude writes it — learnings, stored per git repo under `~/.claude/projects/<project>/memory/`, first 200 lines / 25KB of `MEMORY.md` loaded).

CLAUDE.md load order, broadest to most specific: managed policy → `~/.claude/CLAUDE.md` → `./CLAUDE.md` or `./.claude/CLAUDE.md` → `./CLAUDE.local.md`. All discovered files are **concatenated**, not overridden. Nested subdirectory CLAUDE.md and `.claude/rules/*.md` load lazily when Claude touches a matching file — and unlike root CLAUDE.md they are **not** re-injected after `/compact`.

`@path` imports resolve relative to the containing file, recurse up to 4 hops, and are escaped by backticks. Claude Code reads `CLAUDE.md`, not `AGENTS.md` — bridge with `@AGENTS.md` (prefer the import over a symlink on Windows).

Path-scoped instructions go in `.claude/rules/*.md` with a `paths:` frontmatter glob. Org-wide guidance goes in managed `claudeMd`; monorepos prune with `claudeMdExcludes`.

CLAUDE.md is advisory context, never enforcement. "Before every commit, run X" belongs in a hook. Confirm what actually loaded with `/context` → Memory files, or the `InstructionsLoaded` hook.

## Slash commands and monitoring

Commands are recognized only at the start of a message; up to 6 skills chain per message. The ones that matter for harness debugging: `/status` (active settings sources), `/doctor`, `/context`, `/hooks`, `/permissions`, `/mcp`, `/config key=value`, `/usage`, `/rewind`, `/export`. The full grouped list is in `references/headless-ci-enterprise.md`.

OpenTelemetry, for fleet monitoring:

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

Content logging (`OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_TOOL_CONTENT`, …) is off by default — never enable it without confirming the privacy decision with the user. Metrics include `claude_code.session.count`, `.token.usage`, `.cost.usage`, `.commit.count`, `.active_time.total`. Delivering OTel config via managed settings makes Claude Code strip conflicting user-set OTel env vars, preventing signal redirection; OTel config is also the one server-managed change that needs a full restart.

Read `references/monitoring.md` for exporters, events, correlation IDs, mTLS, cardinality control, multi-team attribution, and `otelHeadersHelper`.

## Reference files

- `references/settings-and-auth.md` — settings key catalog, env-var overrides, managed-only keys, server-managed settings lifecycle, auth precedence and org lockdown
- `references/permissions.md` — every permission mode in detail, auto-mode classifier rules, protected paths, rule syntax
- `references/hooks.md` — complete hook event reference, matchers, I/O schemas, exit codes, examples
- `references/subagents.md` — subagent frontmatter, scopes, tool filters, isolation, memory
- `references/skills-and-plugins.md` — skill frontmatter and lifecycle, plugin manifest, marketplace schema and distribution
- `references/mcp-config.md` — MCP client transports, scopes, auth, plugin servers, limits
- `references/headless-ci-enterprise.md` — `claude -p`/`--bare`, GitHub Actions, Bedrock, Vertex, devcontainers, slash-command index
- `references/monitoring.md` — OpenTelemetry metrics, events, tracing, enterprise config
- `references/versions/2.1.md` — behavior gated on specific v2.1.x releases; check here first when a documented feature is missing

## Diagnostic script

- `scripts/01-harness-inventory.sh` — read-only inventory: CLI version, settings file presence per scope, configured MCP servers, and installed marketplaces. Run it before diagnosing "my config isn't applying".

## Sources

- https://code.claude.com/docs/en/quickstart.md
- https://code.claude.com/docs/en/authentication.md
- https://code.claude.com/docs/en/settings.md
- https://code.claude.com/docs/en/server-managed-settings.md
- https://code.claude.com/docs/en/permissions.md
- https://code.claude.com/docs/en/permission-modes.md
- https://code.claude.com/docs/en/hooks.md
- https://code.claude.com/docs/en/sub-agents.md
- https://code.claude.com/docs/en/skills.md
- https://code.claude.com/docs/en/plugins.md
- https://code.claude.com/docs/en/plugin-marketplaces.md
- https://code.claude.com/docs/en/mcp.md
- https://code.claude.com/docs/en/headless.md
- https://code.claude.com/docs/en/github-actions.md
- https://code.claude.com/docs/en/amazon-bedrock.md
- https://code.claude.com/docs/en/google-vertex-ai.md
- https://code.claude.com/docs/en/devcontainer.md
- https://code.claude.com/docs/en/sandboxing.md
- https://code.claude.com/docs/en/memory.md
- https://code.claude.com/docs/en/commands.md
- https://code.claude.com/docs/en/monitoring-usage.md

Fetched: 2026-08-05
