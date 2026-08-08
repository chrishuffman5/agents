---
name: cursor
description: "Cursor editor and its agents end-to-end: Agent/Plan/Ask modes and checkpoints, Run Modes and `.cursor/permissions.json`, sandboxing, the `.cursor/rules/*.mdc` rule format and AGENTS.md precedence, @-mention context and codebase indexing, Tab completions, `.cursor/mcp.json`, `.cursor/hooks.json` lifecycle hooks, Cloud/background agents and `.cursor/environment.json`, the `cursor-agent` CLI incl. headless CI, Agent Review/Bugbot, model pools and Max Mode, and enterprise SSO/SCIM/Privacy Mode. WHEN: \"Cursor\", \"Cursor IDE\", \"cursor-agent\", \".cursor/rules\", \".mdc rule\", \"alwaysApply\", \"globs frontmatter\", \"Cursor Plan Mode\", \"Shift+Tab modes\", \"Run Mode\", \"auto-review\", \"cursor permissions.json\", \"cursor hooks.json\", \"beforeShellExecution\", \"cursor mcp.json\", \"environment.json\", \"Cursor cloud agent\", \"background agent\", \"Bugbot\", \"BUGBOT.md\", \"Cursor Tab\", \"Composer 2.5\", \"Max Mode\", \"Auto Cost\", \"Cursor Privacy Mode\", \"CURSOR_API_KEY\", \"@cursor on a PR\". Do NOT use for: Claude Code harness config, settings.json, or its hooks (use `claude-code`); OpenAI Codex CLI/cloud/IDE extension (use `codex`); GitHub Copilot IDE features, coding agent, or enterprise policies (use `github-copilot`); pi/pi.dev (use `pi`); Gemini CLI or choosing between harnesses/SDKs/raw API (use `overview`); building agents with an SDK (use `claude-agent-sdk`, `openai-agents-sdk`, `google-adk`); the MCP spec itself or writing MCP servers (use `mcp`); authoring SKILL.md Agent Skills (use `agent-skills`); cross-vendor model catalog and tier choice (use `model-selection`); prompt-injection threat modeling (use `ai-security`); sandbox/egress architecture at fleet scale (use `sandboxing`). SIEM/EDR/WAF/SAST belong to the security plugin; Kubernetes and container runtime depth to the containers plugin."
license: MIT
---

# Cursor (the editor and its agents)

Configure, secure, and operate Cursor: the desktop IDE agent, its rule and context system, MCP and hook wiring, cloud agents, the CLI, and enterprise/privacy administration.

Corpus fetched 2026-08-05 from `cursor.com/docs`, `cursor.com/pricing`, `cursor.com/security`, and `cursor.com/privacy`. Several documented sub-pages were not retrieved — see **Documentation gaps** before asserting anything not stated here. `docs.cursor.com` now 308-redirects to `cursor.com/docs`; both are the same vendor source.

## Answering rules

Always confirm **which config scope** a change belongs in before editing. Cursor keeps parallel user-level (`~/.cursor/`) and project-level (`<repo>/.cursor/`) files for MCP servers, hooks, and permissions, plus enterprise-level hook paths. Wrong scope is the usual cause of "my Cursor config isn't applying".

Always spell rule files `*.mdc`, never `*.md`, inside `.cursor/rules/`. A plain `.md` file in that directory is silently ignored — this is the single most common Cursor rules bug.

Always prefer a **hook or a permissions rule** over an instruction written into a rule file when the user wants a guarantee. Rules are advisory model context; `.cursor/hooks.json` and `.cursor/permissions.json` are enforced by the harness.

Never present Run Mode "Run Everything" as acceptable outside an isolated VM or container — it disables every approval gate and sandboxing at once.

Never claim Cursor has a Memories feature separate from Rules. No such documentation page was findable on 2026-08-05 (see gaps); say so and route the user to Rules + `AGENTS.md` for persistent instructions.

Never state per-model context-window sizes for Cursor's model list. Per-model reference pages were not fetched; that detail is unverified.

## Install and platforms

macOS 12+ (Apple Silicon and Intel, `.dmg`), Windows 10+ (`.exe`), Linux via `apt` (Debian/Ubuntu), `dnf`/`yum` (RHEL/Fedora), or a portable AppImage.

Prefer the `apt`/`yum` packages over the AppImage on Linux — they install desktop icons, automatic updates, and the CLI tools; the AppImage gives none of that.

## Agent: modes and control

Open Agent with **Cmd+I** (sidepane). It edits files, searches by name/pattern, reads directory structure, reads images (`.png .jpg .gif .webp .svg`), runs shell commands and watches output, drives a browser to screenshot and verify visual changes, generates images into an `assets/` folder, performs web searches, retrieves rules by type/description, and asks clarifying questions mid-task. Tool calls per task are unlimited.

**Checkpoints** snapshot automatically before significant changes. Preview or restore any checkpoint from the chat timeline — this is rollback that does not touch Git history, so recommend it before suggesting `git reset`.

| Key | Effect |
|---|---|
| `Cmd+I` | Open Agent in sidepane |
| `Shift+Tab` | Cycle Agent modes (also works in the CLI) |
| `Enter` | Queue a follow-up, runs after the current task |
| `Cmd+Enter` | Send immediately, interrupting current work |

**Plan Mode** is for complex features, multi-file changes, unclear requirements, and architectural decisions. Agent asks clarifying questions, researches the codebase, writes an implementation plan, then the user edits it (in chat or directly as markdown) before any code is written. Skip it for routine changes.

Plans save to the **home directory by default**; "Save to workspace" moves a plan into the repo so teammates can see it. Tell users this explicitly — plans they expect to be committed are not, by default.

When Agent Mode output misses the intent, **revert and refine the plan** rather than patching with follow-up prompts. That is Cursor's own documented recovery strategy.

Ask mode exists in the CLI (`--mode=ask`, read-only exploration). A dedicated IDE Ask-mode docs page was not found; treat IDE Ask behavior as unverified.

Read `references/agent-and-permissions.md` for the full mode/tool detail, Agent Review triggers and depths, and Tab configuration.

## Run Modes, permissions, and sandboxing

Shell execution behavior is governed by the **Run Mode**:

| Run Mode | Behavior | Use for |
|---|---|---|
| **Auto-review** (recommended) | Allowlisted calls run immediately; other shell commands run sandboxed when possible; a classifier evaluates higher-risk operations | Default day-to-day |
| **Allowlist** | Only pre-approved actions run without prompting; optional sandboxing | Deterministic, repeated trusted workflows |
| **Run Everything** | Every tool call runs automatically — no approval gates, no sandboxing | Isolated VM/container only |

Permissions live in two merged files, **team settings override local config**:

```
~/.cursor/permissions.json          # user-level, all projects
<project>/.cursor/permissions.json  # project-specific
```

```json
{
  "autoRun": {
    "allow_instructions": [],
    "block_instructions": [
      "Every AWS CLI command should go through approval first."
    ]
  }
}
```

Instructions are **plain English**, not regex — the classifier interprets them. Agent can edit these files itself from a described preference.

Three actions always require approval regardless of Run Mode: **browser tool execution, file deletion, and modifying files outside the workspace.**

Sandbox defaults: workspace read/write (respecting `.cursorignore`), protected paths (`.git/config`, `.vscode`, sensitive configs), **network blocked by default**, writable temp dirs. Network policy has three modes — custom domains from `sandbox.json`, custom plus Cursor's defaults (package managers, language tools), or unrestricted. Implementation is Seatbelt (`sandbox-exec`) on macOS, Landlock on Linux (kernel 6.2+, seccomp fallback), AppArmor on some distros for Remote/CLI.

Sandboxed processes get `CURSOR_SANDBOX`, `CURSOR_ORIG_UID`, and `CURSOR_ORIG_GID`. The UID/GID pair matters for Docker workflows where the container needs the host user identity.

For isolation architecture and egress control beyond Cursor's own mechanics, defer to the `sandboxing` sibling.

## Rules: `.cursor/rules/*.mdc`

```
.cursor/rules/
  rule-name.mdc        # recognized
  plain-file.md        # IGNORED — wrong extension
  frontend/
    components.mdc     # folders are fine
```

```yaml
---
description: "Purpose of this rule"
alwaysApply: false
globs: src/**/*.tsx, src/**/*.ts
---
```

| Rule type | Trigger | Frontmatter |
|---|---|---|
| Always Apply | Every chat session | `alwaysApply: true` |
| Apply Intelligently | Agent judges relevance | `description` + `alwaysApply: false` |
| Apply to Specific Files | A file matches a glob | `globs` + `alwaysApply: false` |
| Apply Manually | Only when `@`-mentioned | Omit both `globs` and `description` |

`alwaysApply: true` wins outright — `globs` and `description` are ignored on that rule. Globs: `*` matches one filename segment, `**` recurses directories, and multiple patterns are comma-separated (`docs/**/*.md, docs/**/*.mdx`).

Keep each rule under 500 lines, split large ones across files, reference other files instead of pasting their content, and write concrete actionable guidance — not vague principles or duplicated codebase docs.

**`AGENTS.md`** is plain markdown with no frontmatter, placed at the project root or in subdirectories. Nested files are supported and **deeper instructions win** over parent directories. The CLI additionally loads root `AGENTS.md` and `CLAUDE.md` as rules.

Precedence when guidance conflicts: **Team Rules → Project Rules → User Rules** (earlier wins). Enterprise teams manage org-wide rules at `cursor.com/dashboard/team-content`.

Read `references/rules-and-context.md` for full rule mechanics, @-mention types, and indexing behavior.

## Context and indexing

`@`-mentions attach specific context: `@auth.ts` (file), `@src/components/` (folder), `@Terminals`, `@Past Chats`, `@Browser`, `@Commit (Diff of Working State)`, `@Branch (Diff with Main)`. Repeat `@` to attach several.

Guidance straight from the docs: use `@` when you know which files matter; **skip it when you do not** — Agent's own search finds relevant files.

Indexing builds embeddings **without storing raw source**: filenames obfuscated, chunks encrypted, file paths encrypted before transmission, code held in memory during indexing then discarded, decryption client-side at retrieval. **Instant Grep**, Cursor's search engine (documented as outperforming `ripgrep` on large codebases), runs automatically with regex and word-boundary matching.

Multi-root workspaces index all codebases automatically, but **worktrees are disabled** there and **Cloud Agents do not support multi-root workspaces** — flag this before recommending a multi-root setup to a cloud-agent user.

## Tab completions

Tab is the inline autocomplete: ghost text ahead of the cursor, driven by recent edits, surrounding code, and linter errors. It does multi-line edits (including inserting missing imports), **jump-in-file** (press Tab again after accepting to navigate to the predicted next edit), and **cross-file suggestions** surfaced in a portal window at the editor bottom.

Accept with `Tab`, reject with `Escape` or by continuing to type, accept word-by-word with `Cmd+→` / `Ctrl+→`. Remap via "Accept Cursor Tab Suggestions" in Keyboard Shortcuts.

Configure from the status indicator at the bottom-right: snooze for a duration, disable globally, or disable per file extension. Detailed settings under **Cursor Settings → Tab**.

## MCP configuration

Client side only — for the protocol, primitives, and writing servers use the `mcp` sibling.

```
.cursor/mcp.json     # project
~/.cursor/mcp.json   # global
```

```json
{
  "mcpServers": {
    "local-server": {
      "command": "python",
      "args": ["${workspaceFolder}/tools/mcp_server.py"],
      "env": { "API_KEY": "${env:API_KEY}" }
    },
    "remote-server": {
      "url": "https://api.example.com/mcp",
      "headers": { "API_KEY": "value" }
    }
  }
}
```

Transports: **stdio** (local, Cursor-managed, single user, manual auth), **SSE** and **Streamable HTTP** (local or remote, server-deployed, multi-user, OAuth).

Interpolation resolves in `command`, `args`, `env`, `url`, and `headers`: `${env:NAME}`, `${userHome}`, `${workspaceFolder}`, `${workspaceFolderBasename}`, `${pathSeparator}` / `${/}`. `envFile` is **stdio-only** — it does nothing on a remote server entry.

OAuth uses an `auth` block (`CLIENT_ID` required, `CLIENT_SECRET` optional for confidential clients, `scopes` optional). Server authors must register both static redirect URLs if users authenticate from both surfaces: `https://www.cursor.com/agents/mcp/oauth/callback` (web/cloud) and `http://localhost:8787/callback` (desktop).

Debug via Output panel (`Cmd+Shift+U`) → **MCP Logs**. Server failures are isolated — one crashing server does not affect others.

Read `references/mcp-config.md` for the full field tables, distribution paths (marketplace, extension API, enterprise dashboard), and troubleshooting.

## Hooks

Hooks are spawned processes speaking JSON over stdio that observe, block, or modify the agent loop. Config is `hooks.json`; Cursor **hot-reloads it on save**.

```json
{
  "version": 1,
  "hooks": {
    "afterFileEdit": [
      { "command": ".cursor/hooks/format.sh", "timeout": 30, "failClosed": false }
    ]
  }
}
```

Precedence, highest first: **Enterprise → Team → Project → User**. Project hooks are `<repo>/.cursor/hooks.json` with paths relative to the project root; user hooks are `~/.cursor/hooks.json` with paths relative to `~/.cursor/`. Getting that relative-path base wrong is a common "hook never fires" cause. `chmod +x` the scripts.

Exit codes: `0` = success (stdout JSON used), **`2` = block the action**, anything else **fails open**. Set `failClosed: true` when a hook failing must not silently allow the action.

Key events — lifecycle `sessionStart`/`sessionEnd`; tools `preToolUse`/`postToolUse`/`postToolUseFailure`; subagents `subagentStart`/`subagentStop`; shell and MCP `beforeShellExecution`/`afterShellExecution`/`beforeMCPExecution`/`afterMCPExecution`; files `beforeReadFile`/`afterFileEdit`; workflow `beforeSubmitPrompt`/`preCompact`/`stop`/`afterAgentResponse`/`afterAgentThought`; Tab `beforeTabFileRead`/`afterTabFileEdit`; app `workspaceOpen`.

Cloud agents run **command-based hooks only**, from project `.cursor/hooks.json` (team/enterprise hooks also load). Not available there: `sessionStart`, `sessionEnd`, MCP hooks, Tab hooks, `workspaceOpen`, and any user-level hook.

Read `references/hooks.md` before writing a hook — it carries every event, matcher values, prompt-type hooks, I/O schemas, the auto-continue `stop` loop, and the hook environment variables.

## Cloud (background) agents

Cloud Agents run in **isolated Ubuntu VMs** with full dev environments, working for minutes or hours in parallel with independent internet access. Launch from Cursor Desktop ("Cloud" in the agent dropdown), `cursor.com/agents`, the iOS app or Android PWA, a `@cursor` comment on a GitHub/Bitbucket PR or issue, `@cursor` in Slack or Linear, the API, or scheduled Automations.

Agents attach videos, screenshots, and logs to pull requests so results can be validated without checking out the branch; remote desktop access allows direct testing.

Prerequisites: an account admin connects source control (GitHub, GitLab, Bitbucket Cloud, Azure DevOps) with **read-write** repository privileges; dependent repos and submodules need their own permissions; each user connects a personal source-control account to view shared runs.

```json
{
  "build": { "dockerfile": "Dockerfile", "context": ".." },
  "install": "pnpm install && ./custom_script.sh",
  "start": "sudo service docker start"
}
```

`.cursor/environment.json` sections: `build`, `install` (once per Build — **must be idempotent**, no long-running processes/DBs/Docker/dev servers), `start` (every boot), `terminals` (processes kept alive in shared tmux sessions), `snapshot`. Resolution priority: repo `.cursor/environment.json` → personal saved environment → team saved environment.

Secrets live in the dashboard Secrets tab, never the repo — environment-scoped or standard/global, plus AWS IAM role assumption via `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` and TOTP via a stored shared secret.

**Pricing:** cloud agents are charged at API pricing for the selected model, scaling with the selected context window; users set a spend limit on first activation.

Read `references/cloud-agents-and-cli.md` for networking (Tailscale userspace mode, Cloudflare Tunnel, Docker-in-agent), secrets detail, and the full CLI surface.

## CLI and headless CI

```bash
curl https://cursor.com/install -fsS | bash            # macOS/Linux/WSL
irm 'https://cursor.com/install?win32=true' | iex      # Windows PowerShell

agent "refactor the auth module to use JWT tokens"     # interactive with an objective
agent ls | agent resume | agent --resume="chat-id"     # session history
agent --mode=plan --worktree feature-x                 # isolated worktree
agent -p "review this diff" --output-format json       # headless
```

Modes map to the IDE: **Agent** (default, full tools), **Plan** (`--plan` / `/plan`), **Ask** (`--mode=ask`, read-only). Cycle with `Shift+Tab`.

Prefixing a prompt with `&` hands the task off to a **Cloud Agent** for background processing.

In headless mode, `--force` (alias `--yolo`) lets the agent write files directly; **without it changes are only proposed**. `--output-format` is `text` (default, final answer only), `json` (structured), or `stream-json` (message-level progress). `--stream-partial-output` streams response deltas. CI requires `CURSOR_API_KEY`.

The CLI reads `.cursor/rules`, loads root `AGENTS.md` and `CLAUDE.md` as rules, and auto-detects `mcp.json`. Worktrees land in `~/.cursor/worktrees/<reponame>/<name>`.

Exhaustive flag/parameter reference, authentication, permissions, slash commands, shell mode, ACP, and the GitHub Actions integration are documented pages that were **not fetched** — treat specifics beyond the above as unverified.

## Agent Review and Bugbot

Agent Review analyzes local changes in the editor. Trigger it automatically after each committed change (when enabled), by typing `/agent-review` in the agent input, or from the Source Control tab (all local modifications vs. the main branch).

Depth is **Quick** (fast, low-cost, minor changes and formatting) or **Deep** (thorough, higher-cost, complex logic, security-critical code, large refactors).

Repo-specific review guidelines go in **`BUGBOT.md`** files. Settings live under Cursor Settings → Agents → Agent Review; on **Cursor 3.11+** that setting moved — see `references/versions/3.11.md`.

Bugbot is billed usage-based on Pro and above, and is the agentic code-review offering bundled into Teams.

## Models, pools, and cost

Two usage pools, both resetting monthly:

- **Cursor Models** — Cursor Grok 4.5 (jointly trained with SpaceXAI for long-running work) and Composer 2.5 (Cursor's proprietary agentic coding model). Significantly more included usage.
- **Other Models** — 50+ third-party models (OpenAI, Anthropic, Google, others) charged at the model's API price. The India-only Start plan excludes this pool entirely.

**Auto modes:** *Auto Cost* (flat per-million-token rate regardless of the model used), *Auto Balance* (real API rate for the model used), *Auto Intelligence* (selection optimized for capability). On Teams/Enterprise, Cursor Router picks the model per request based on the chosen optimization mode.

**Max Mode** extends a model's context window beyond the default and applies **only to legacy request-based plans**, billed at API rate **+20%**. Some models (Claude 4.5 Opus, GPT-5.5) *require* Max Mode on those legacy plans. On current Teams/Enterprise plans the relevant surcharge is instead the **Cursor Token Rate** of $0.25/M tokens on third-party requests — exempt for first-party models and Auto Cost. Regional data residency adds a 10% uplift.

For cross-vendor model capability comparison and tier choice, defer to `model-selection`. Plan tiers and per-model rates as of 2026-08-05 are in `references/models-and-pricing.md`.

## Enterprise and privacy

**SSO:** SAML 2.0 with Okta, Azure AD, Google Workspace, OneLogin. Orgs can require SSO and disable password login; multi-team orgs share org-level SSO via Organizations. (The pricing page says "SAML/OIDC SSO"; the IAM docs page names only SAML 2.0 — treat standalone OIDC as unconfirmed.)

**SCIM 2.0** is Enterprise-plan-only and requires SSO enabled. It provisions on IdP group join, revokes immediately on departure, and syncs group changes; Organization Groups reuse directory groups across teams.

**RBAC:** three roles — Members, Admins, Unpaid Admins.

Admin dashboard controls: role-based permissions, model and MCP server allow/block lists, repository access controls, global agent execution settings, and analytics (adoption, per-team/individual usage, AI-assisted code stats) with API export.

**Privacy Mode** is enabled per team from the dashboard and can be **enforced** so members cannot disable it. Pair it with the MDM "Allowed Team IDs" policy to stop users signing into personal accounts on corporate devices — without that, enforcement has a hole.

Under Privacy Mode most models run under Cursor's **Zero Data Retention** agreements, so providers neither store nor train on inputs/outputs. **Exception: Claude Fable 5 requires data retention** — Anthropic stores inputs and outputs to run automatic and human harm-prevention reviews — and needs explicit admin approval from the dashboard before use on Enterprise and Privacy-Mode teams. Surface this whenever a ZDR-committed org asks about that model.

Compliance posture: SOC 2 Type II (reports via trust.cursor.com), at-least-annual third-party penetration testing, no infrastructure or subprocessors in China, published subprocessor list, MFA-enforced least-privilege access, CMEK, audit logging. Vulnerability reports go to security-reports@cursor.com, acknowledged within 5 business days.

**Hard limitation:** Cursor runs on AWS only — **no on-premises or VPC deployment** is available (per cursor.com/enterprise, 2026-08-05). Data residency is US-only today; EU/APAC are "in development" with no stated timeline. Say this plainly to any org with a residency or self-hosting requirement.

Training: Cursor does not use inputs or suggestions to train models, or permit third parties to, except when flagged for security review, explicitly reported as feedback, or explicitly agreed to.

Read `references/enterprise-and-privacy.md` for the full IAM, governance, and security-practice detail.

## Documentation gaps (do not fill from memory)

State these as unknown rather than guessing:

- **Memories** — no official page for a Memories feature distinct from Rules was findable on 2026-08-05 (direct URL attempts 404'd, `llms.txt` has zero "memor" hits, no changelog entry). Do not describe its storage, scope, or UI.
- **`.cursorignore`** — referenced by the agent/sandbox docs but its file format and precedence were never documented on a fetched page.
- **Per-model context windows** for Grok 4.5, Composer 2.5, and third-party models — the per-model reference pages were not fetched.
- **Exhaustive CLI reference** — parameters, authentication, permissions, configuration, output-format, terminal-setup, slash commands, shell mode, ACP, and GitHub Actions pages exist but were not fetched.
- **Debug Mode and Design Mode**, and the browser/search/canvas tool pages — listed but not fetched.
- **Enterprise sub-pages** — admin-setup-guide, organizations, network-configuration, endpoint-security, llm-safety-and-controls, pooled-usage, compliance-and-monitoring, BAA, deployment-patterns, security-hardening. Admin API endpoints/schemas, service-account setup, and audit-log schema are unconfirmed.
- **Whether Privacy Mode changes indexing behavior** (e.g. skipping embeddings) is not stated on the indexing page.
- **IDE Ask mode** has no dedicated docs page; only the CLI `--mode=ask` is documented.

## Reference files

- `references/rules-and-context.md` — `.mdc` rule types and globs, AGENTS.md nesting, team/project/user precedence, @-mentions, codebase indexing and Instant Grep
- `references/agent-and-permissions.md` — Agent capabilities and checkpoints, Plan Mode workflow, Run Modes, `permissions.json`, sandboxing internals, Agent Review, Tab
- `references/hooks.md` — every hook event, matchers, command vs prompt hooks, I/O schemas, exit codes, env vars, cloud-agent limitations
- `references/mcp-config.md` — transports, field tables, interpolation, OAuth, distribution, troubleshooting
- `references/cloud-agents-and-cli.md` — cloud agent launch paths, `environment.json`, secrets, networking, CLI commands and headless/CI
- `references/enterprise-and-privacy.md` — SSO/SCIM/RBAC, admin controls, Privacy Mode and ZDR, security certifications, privacy policy
- `references/models-and-pricing.md` — plan tiers, usage pools, third-party rates, Max Mode, Auto modes, Cursor Token Rate
- `references/versions/3.11.md` — behavior gated on Cursor 3.11+

## Diagnostic script

- `scripts/01-cursor-config-inventory.sh` — read-only inventory of which Cursor config files exist at enterprise/project/user scope (`mcp.json`, `hooks.json`, `permissions.json`, `.cursor/rules/*.mdc`, `environment.json`, `AGENTS.md`, `BUGBOT.md`) plus CLI presence. Run it first when a Cursor config "isn't applying".

## Sources

- https://cursor.com/docs/get-started/installation
- https://cursor.com/docs/agent/overview
- https://cursor.com/docs/agent/modes
- https://cursor.com/docs/agent/plan-mode.md
- https://cursor.com/docs/agent/tools/terminal.md
- https://cursor.com/docs/agent/security/run-modes.md
- https://cursor.com/docs/agent/agent-review.md
- https://cursor.com/docs/agent/hooks
- https://cursor.com/docs/tab/overview
- https://cursor.com/docs/context/rules
- https://cursor.com/docs/context/@-symbols
- https://cursor.com/docs/context/codebase-indexing
- https://cursor.com/docs/context/mcp
- https://cursor.com/help/customization/context.md
- https://cursor.com/docs/mcp.md
- https://cursor.com/docs/hooks.md
- https://cursor.com/docs/background-agent
- https://cursor.com/docs/cloud-agent/setup.md
- https://cursor.com/help/ai-features/background-agents.md
- https://cursor.com/docs/cli/overview
- https://cursor.com/docs/cli/using.md
- https://cursor.com/docs/cli/headless.md
- https://cursor.com/docs/models
- https://cursor.com/docs/models-and-pricing.md
- https://cursor.com/pricing
- https://cursor.com/enterprise
- https://cursor.com/docs/enterprise/identity-and-access-management.md
- https://cursor.com/docs/enterprise/privacy-and-data-governance.md
- https://cursor.com/security
- https://cursor.com/privacy

Fetched: 2026-08-05
