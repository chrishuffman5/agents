---
name: github-copilot
description: "GitHub Copilot end-to-end across every surface: IDE chat and agent mode (VS Code chat surfaces, `settings.json` keys, custom agents and handoffs, JetBrains cloud-agent integration), the asynchronous cloud/coding agent (issue assignment, `@copilot`, session limits, `copilot-setup-steps.yml`, the integrated firewall, runner selection, automations, MCP entry points), Copilot CLI (commands, slash commands, tool-approval flags), repository customization file formats with exact syntax (`.github/copilot-instructions.md`, `*.instructions.md` `applyTo` frontmatter, `*.prompt.md`, `*.agent.md`, `AGENTS.md`/`CLAUDE.md` precedence), Copilot Spaces, model catalog and auto model selection, plans/seats, and enterprise/org policy plus audit-log administration. WHEN: \"GitHub Copilot\", \"Copilot coding agent\", \"Copilot cloud agent\", \"assign an issue to Copilot\", \"@copilot\", \"copilot-setup-steps.yml\", \"copilot-instructions.md\", \"applyTo\", \".instructions.md\", \".prompt.md\", \".agent.md\", \"Copilot CLI\", \"copilot -p\", \"/delegate\", \"Copilot Spaces\", \"Copilot Business\", \"Copilot Enterprise\", \"AI credits\", \"Copilot policies\", \"action:copilot audit log\", \"Copilot firewall allowlist\", \"auto model selection\", \"chat.agent.enabled\". Do NOT use for: the Claude Code CLI harness (use `claude-code`); OpenAI Codex CLI/cloud/IDE operations, even when Codex is enabled as a third-party coding agent inside GitHub (use `codex`); the Cursor editor (use `cursor`); the pi harness (use `pi`); building agents with an SDK (use `claude-agent-sdk`, `openai-agents-sdk`, or `google-adk`); the Model Context Protocol spec, transports, or writing MCP servers (use `mcp`); authoring SKILL.md Agent Skills content (use `agent-skills`); cross-vendor model tier choice (use `model-selection`); prompt-injection and agent threat modeling (use `ai-security`); sandbox/egress isolation architecture (use `sandboxing`); harness-vs-SDK-vs-API architecture selection (use `overview`); testing agents or skills (use `evals`). GitHub Advanced Security / SAST / secret-scanning depth is the security plugin; Actions runner and container runtime depth is the containers plugin."
license: MIT
---

# GitHub Copilot

Configure, operate, and govern GitHub Copilot across its five surfaces: IDE (chat + agent mode), the asynchronous **cloud agent** (formerly "coding agent") on GitHub's infrastructure, **Copilot CLI** in the terminal, github.com features (Chat, Spaces, code review), and the **admin/policy plane** for orgs and enterprises.

Corpus fetched 2026-08-05 against `docs.github.com` and `code.visualstudio.com`. Copilot's docs and product surfaces move fast — see "Known gaps" at the bottom and `references/versions/2026-08.md` before asserting that a named feature exists or is GA.

## Naming: "coding agent" vs "cloud agent"

GitHub's docs renamed **coding agent** → **cloud agent** (`/copilot/concepts/agents/cloud-agent/…`); the old `about-coding-agent` slug still resolves to the renamed content, and product UI and blog posts still say "coding agent." Treat the two names as the same thing and mirror the user's wording. Never treat a user saying "coding agent" as evidence they are on an older product.

## Answering rules

Always establish **which surface** before answering. "Copilot won't do X" has completely different causes in agent mode (a tool approval or `#`-mention issue), the cloud agent (firewall, 59-minute cap, ruleset conflict), and the CLI (a `--deny-tool` rule or a missing plugin). Surfaces do not share configuration except the repository instruction files.

Always establish **the plan** before promising a feature. Free has no cloud agent and no manual model selection; Claude Opus-class and other newer premium models require Business/Enterprise or Pro+/Max. Business/Enterprise additionally require an **administrator to enable** the cloud agent — a correct repo config still does nothing without it.

Always put durable project guidance in a **repository instruction file**, not in chat. `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md` are automatically included in requests on save; chat context is not.

Never claim the audit log captures what a developer did in their IDE or CLI. It records Copilot plan/policy changes and agent activity on GitHub's website only — **not client-session data such as local prompts**. Local-session telemetry requires a custom pipeline (e.g. webhooks forwarding CLI events).

Never recommend the cloud agent's integrated firewall together with self-hosted runners or Windows runners — the firewall is **not compatible** with either. Say so and move the control to the network layer.

Never assume the agent can touch more than one repo. One repository, one branch, one pull request, per task.

## Surface selection

| Need | Surface | Why |
|---|---|---|
| Synchronous edits with the developer watching | IDE agent mode | Local files, immediate iteration |
| Background work on a well-scoped issue | Cloud agent | Ephemeral Actions environment, draft PR, logs |
| Terminal-native work, scripting, CI glue | Copilot CLI | `-p` programmatic mode, tool-approval flags |
| Curated grounding context reused by a team | Copilot Spaces | Pinned files/repos/URLs/pasted text |
| Deep research + planning before a PR | Cloud agent **on github.com** | Third-party integrations (Jira/Slack/Teams/Linear/Azure Boards) support direct PR creation only, not the fuller iterative workflow |

## Repository customization files (exact syntax)

These are the highest-leverage configuration in Copilot, and the only configuration shared across surfaces.

**Repository-wide instructions** — `.github/copilot-instructions.md`, plain Markdown, no frontmatter required. Applies to all Copilot requests made in the repository's context. Keep it **under ~2 pages** and task-agnostic; cover repo summary, bootstrap/build/test/lint command sequences, environment setup (including steps that "appear optional"), project layout, CI/validation pipelines, and key config file locations.

**Path-specific instructions** — `.github/instructions/NAME.instructions.md` (subdirectories allowed). Frontmatter `applyTo` glob is **required**:

```markdown
---
applyTo: "app/models/**/*.rb"
---

Use ActiveRecord scopes rather than raw SQL in model classes.
```

Multiple patterns are comma-separated inside one string: `applyTo: "**/*.ts,**/*.tsx"`. Optional `excludeAgent` opts a tool out, e.g. `excludeAgent: "code-review"`. Path-specific and repository-wide instructions **combine** — they are not mutually exclusive.

Glob semantics: `*.py` = current directory only; `**/*.py` = recursive everywhere; `src/*.py` = directly in `src`; `src/**/*.py` = recursive under `src`.

**Agent instructions** — `AGENTS.md` may sit anywhere in the tree; the **nearest file to the working context wins**. A single `CLAUDE.md` or `GEMINI.md` at the repository root is also recognized.

**Precedence, highest first: personal → repository → organization instructions.**

**Prompt files** — `.github/prompts/NAME.prompt.md`, invoked as `/NAME` in chat:

```markdown
---
agent: 'agent'
description: 'Generate a clear code explanation with examples'
---

Explain this code for ${input:audience:Who is this explanation for?}:
${input:code:Paste your code here}
```

`${input:name:prompt text}` collects a value at run time. Prompt files are **public preview**, and only in VS Code, Visual Studio, and JetBrains.

**Custom agents** — `.agent.md` files in `.github/agents` (workspace) or `~/.copilot/agents` (user profile). Only `description` is required:

```yaml
---
name: testing-specialist
description: Focuses on test coverage and quality
target: github-copilot          # vscode | github-copilot; both if omitted
tools: ["read", "edit", "search"]
model: <model-id>
---
```

`tools` accepts a comma-separated string or a YAML array; omit it or use `["*"]` for all tools, `[]` to disable all, and namespaced entries for MCP tools (`custom-mcp/tool-1`, `github/*`). Aliases: `read`→view, `edit`→str_replace, `search`, `execute`→bash/powershell, `agent`, `web` (web is N/A for the cloud agent). Body max **30,000 characters**. The filename (minus `.agent.md`) is the identity, and **repository-level overrides organization-level overrides enterprise-level**.

Read `references/customization-files.md` for the full field tables, the `excludeAgent` and precedence edge cases, and Copilot Spaces as a non-file alternative.

## Cloud agent (the async coding agent)

Assign by adding **Copilot** as an assignee on an issue (github.com, GitHub Mobile, or `gh`), by `@copilot` in a PR comment, from the github.com Agents tab / `github.com/copilot/agents`, from the dashboard **Task** button, via `/task` in Copilot Chat, from VS Code / JetBrains / the REST API / GitHub CLI, or on a schedule via Automations.

The agent reacts 👀, starts a session on GitHub Actions, pushes commits to a **draft pull request**, and streams step-by-step session logs. It does **not** react to comments added to the issue after assignment — put follow-ups in the PR.

Hard constraints to quote before anyone plans around it:

- **59 minutes** maximum per session; cannot be extended.
- One repository, one branch, one PR per task. Cross-repo context requires MCP.
- GitHub-hosted repositories only.
- Some branch-protection rulesets block it unless an admin grants bypass.
- It **cannot** satisfy rules restricting commit authorship to specific identities.
- Actions workflows triggered by its changes need **Approve and run workflows** by default.

Environment customization lives in `.github/workflows/copilot-setup-steps.yml`, which must contain a **single job named `copilot-setup-steps`** — a different job name is silently ignored:

```yaml
name: "Copilot Setup Steps"
on:
  workflow_dispatch:
  push:
    paths: [.github/workflows/copilot-setup-steps.yml]
  pull_request:
    paths: [.github/workflows/copilot-setup-steps.yml]

jobs:
  copilot-setup-steps:
    runs-on: ubuntu-latest
    timeout-minutes: 59          # max
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v7
        with: { node-version: "20", cache: "npm" }
      - run: npm ci
```

Only `steps`, `permissions`, `runs-on`, `services`, `snapshot`, and `timeout-minutes` are customizable at job level.

**Firewall.** The integrated firewall allowlists `uploads.github.com` and `user-images.githubusercontent.com` for everyone, plus one plan-scoped API host: `api.individual.githubcopilot.com` (Pro/Pro+/Max), `api.business.githubcopilot.com`, or `api.enterprise.githubcopilot.com`. It is **incompatible with self-hosted runners and with Windows runners** — disable it in repository settings and use `https_proxy`/`no_proxy`/`ssl_cert_file`/`node_extra_ca_certs` env vars in the job instead.

**Per-repo settings** (Settings → Copilot → Cloud agent, admin only): *Validation tools* (built-in security/code-review checks — default **enabled**) and *Require approval for workflow runs* (default **enabled**).

**Org runner control** (Settings → Copilot → Cloud agent): change the default from `ubuntu-latest` to another GitHub-hosted or labeled runner, and choose whether repos may override it via their own `copilot-setup-steps.yml`.

**MCP**: the GitHub and Playwright MCP servers are enabled by default. To drive the cloud agent from any MCP-capable host, install the **remote** GitHub MCP Server and enable the `create_pull_request_with_copilot` tool — remote servers only.

Read `references/cloud-agent.md` for the full entry-point matrix, session/review workflow, automations, IDE differences (VS Code needs the GitHub Pull Requests extension; JetBrains is built-in and public preview), and troubleshooting order.

## Copilot CLI

```bash
copilot                       # interactive; Shift+Tab cycles standard / plan / autopilot
copilot -p "run the tests and fix failures"   # programmatic, exits when done
copilot login [--host HOST]   # OAuth device flow
copilot init                  # scaffold custom instructions for this repo
copilot plugins list --json   # every plugin, MCP server, skill, instruction source, language server
```

Runs on Linux, macOS, and Windows (PowerShell and WSL). Model via `/model` or `--model`; custom providers (OpenAI-compatible, Azure OpenAI, Anthropic, local Ollama) via environment variables.

Tool approval is the safety boundary: single-use, session-wide, or automatic via `--allow-all-tools` / `--allow-tool` / `--deny-tool`. Prefer a narrow `--allow-tool` list over `--allow-all-tools` in any non-sandboxed context; the CLI executes and modifies files and runs shell commands.

High-value slash commands: `/delegate` (hand off to the cloud agent as a PR), `/plan`, `/diff`, `/fleet` (parallel subagents), `/compact`, `/context`, `/limits` (cost constraints), `/after` and `/every` (one-off and recurring scheduled tasks), `/add-dir` (widen file access).

Read `references/cli.md` for the complete command and slash-command tables and the keyboard-shortcut reference.

## IDE (VS Code focus)

Four chat surfaces: **Agents Window** (`code --agents`), **Chat View** (`Ctrl+Alt+I`), **Inline Chat** (`Ctrl+I`), **Quick Chat** (`Ctrl+Shift+Alt+L`).

Context comes from implicit context (active file, selection), `#`-mentions (`#file`, `#codebase`, `#terminalSelection`, `#fetch`), image/vision attachments, and MCP servers or extensions for external systems. `/` runs slash commands and agent skills; `!` runs shell commands directly in chat (Agent Host sessions only).

Settings keys worth knowing when behavior is missing:

| Key | Default | Effect |
|---|---|---|
| `chat.agent.enabled` | `true` | Agents on/off (VS Code 1.99+) |
| `chat.disableAIFeatures` | — | Hides built-in AI features entirely |
| `chat.instructionsFilesLocations` | incl. `.github/instructions` | Where instruction files are found |
| `chat.promptFilesLocations` | `{".github/prompts": true}` | Where prompt files are found |
| `chat.agentFilesLocations` | `{".github/agents": true}` | Where `.agent.md` agents are found |
| `chat.useAgentsMdFile` | `true` | `AGENTS.md` as chat context |
| `chat.useClaudeMdFile` | `true` | `CLAUDE.md` as custom instructions |
| `chat.mcp.discovery.enabled` | `false` | Auto-discover MCP configs |
| `chat.mcp.autoStart` | `"newAndOutdated"` | Auto-start MCP servers on config change |
| `chat.mcp.access` | — | Which MCP servers may be used |

Custom agents (formerly "chat modes") add **handoffs** — a planning agent can hand context to an implementation agent, or to a code-review agent. Give a planning agent read-only `tools` so it cannot edit by accident.

Read `references/ide-and-models.md` for the rest of the settings catalog, agent-mode behavior, and the cross-IDE feature-matrix caveat.

## Models and plans

| Plan | Price | Cloud agent | Model selection |
|---|---|---|---|
| Free | — | No | Auto only |
| Student | free (verified) | Yes | Auto only |
| Pro | $10/mo | Yes | Manual |
| Pro+ | $39/mo | Yes | Manual + premium models |
| Max | $100/mo | Yes | Manual + priority access |
| Business | $19/seat/mo | Yes (admin must enable) | Manual + central policy |
| Enterprise | $39/seat/mo | Yes (admin must enable) | Manual + larger credit pool |

Catalog spans OpenAI (GPT-5 family), Anthropic (Claude Fable/Haiku/Opus/Sonnet), Google (Gemini 3.x), Microsoft (MAI-Code-1-Flash), and others (Raptor mini, Kimi K2.7 Code, Grok 4.5). The **1M-token context window is VS Code and Copilot CLI only**; configurable reasoning levels also work in the cloud agent.

**Auto model selection** routes on task complexity plus live system health, respects plan and admin policy, is language-independent, and carries a **10% model-cost discount** on paid plans. It never picks models that are unavailable on the plan, admin-blocked, FedRAMP-restricted, or excluded evaluation models. Recommend it as the default for mixed workloads; recommend manual selection when a specific model's behavior is being evaluated.

For picking models across vendors on capability/price grounds rather than within Copilot's catalog, defer to the `model-selection` sibling.

## Administration and governance

Enterprise: settings → **AI controls** → **Agents** / **Copilot** / **MCP** policy sections. **Enterprise policies override organization policies** — an org owner cannot loosen what the enterprise set. "Suggestions matching public code" defaults to **Blocked** for Copilot Business.

Organization: **Policies** (privacy and feature availability) and **Models** (access beyond the default set). Named policies include *MCP servers in Copilot*, *third-party coding agents* (enabling Anthropic Claude and OpenAI Codex as alternative coding agents), and *Copilot in GitHub.com*. Note the **MCP servers in Copilot** policy governs MCP inside Copilot only — it does not control access to GitHub's own MCP server used from third-party apps like Cursor or Claude.

Audit log: enterprise settings → Audit log; filter `action:copilot` (all Copilot events), `actor:Copilot` (agent activity), or a specific action such as `action:copilot.cfb_seat_assignment_created`. **180-day retention** — stream to a SIEM for longer history and anomaly detection.

Usage visibility: `view-usage-and-adoption`, `view-code-generation`, `view-impact-dashboard`, and `download-activity-report` under the administer-Copilot docs.

Read `references/admin-and-governance.md` for the policy/subpage index, access-request workflow, org runner and MCP-management pages, and Copilot Spaces setup.

## Diagnostic script

- `scripts/01-copilot-inventory.sh` — read-only inventory of a repository's Copilot configuration: instruction files, `applyTo` frontmatter presence, prompt files, `.agent.md` agents, `AGENTS.md` locations, and a `copilot-setup-steps.yml` job-name check. Run it first when "Copilot is ignoring my instructions."

## Reference files

- `references/customization-files.md` — instruction/prompt/agent file formats, frontmatter fields, precedence, Spaces
- `references/cloud-agent.md` — entry points, sessions, limits, `copilot-setup-steps.yml`, firewall, runners, automations, MCP
- `references/cli.md` — Copilot CLI commands, slash commands, shortcuts, tool approval, custom providers
- `references/ide-and-models.md` — VS Code surfaces and settings keys, agent mode, custom agents/handoffs, model catalog, auto selection
- `references/admin-and-governance.md` — plans, enterprise/org policies, audit logs, usage dashboards, Spaces
- `references/versions/2026-08.md` — what was preview vs GA, renamed, or time-limited as of 2026-08-05

## Known gaps (unverified — do not fill from memory)

State these as unknown rather than guessing; every one was searched for and not found in the fetched corpus on 2026-08-05.

- **Premium-request / AI-credit multipliers** per model and per plan. The plans page references a separate models-and-pricing page that was not retrievable.
- **MCP server configuration syntax for the cloud agent** (the equivalent of VS Code's `mcp.json`). Only the default-enabled GitHub and Playwright servers and the remote GitHub MCP Server's `create_pull_request_with_copilot` tool are confirmed.
- **Content exclusion** (excluding specific repos/paths from all Copilot surfaces) — no working canonical URL or config format found under the current docs structure.
- **A complete enumerated list of enterprise/org Copilot policies** with default enforcement values; only the named examples above are confirmed.
- **JetBrains IDE chat/edit/completion feature detail** beyond cloud-agent integration.
- **The legacy Ask/Edit/Agent chat-mode trio and its keybindings** — current VS Code docs document the four surfaces above and custom agents/handoffs instead.

## Sources

- https://docs.github.com/copilot/concepts/agents/coding-agent/about-coding-agent
- https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent
- https://docs.github.com/en/copilot/how-tos/copilot-on-github/copilot-for-github-tasks/use-copilot-to-create-or-update-issues
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-on-github
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-in-your-ide
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-with-mcp
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/customize-the-agent-environment
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/configuring-agent-settings
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/create-automations
- https://docs.github.com/en/copilot/how-tos/administer-copilot
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization/manage-policies
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization/manage-access
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization/configure-runner-for-coding-agent
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-enterprise-policies
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/review-audit-logs
- https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions
- https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/copilot-spaces/create-copilot-spaces
- https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file
- https://docs.github.com/en/copilot/reference/custom-agents-configuration
- https://docs.github.com/en/copilot/reference/copilot-feature-matrix
- https://docs.github.com/en/copilot/reference/ai-models/supported-models
- https://docs.github.com/en/copilot/concepts/models/auto-model-selection
- https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli
- https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference
- https://docs.github.com/en/copilot/get-started/plans
- https://code.visualstudio.com/docs/copilot/chat/copilot-chat
- https://code.visualstudio.com/docs/copilot/chat/chat-agent-mode
- https://code.visualstudio.com/docs/copilot/chat/chat-modes
- https://code.visualstudio.com/docs/copilot/reference/copilot-settings
- https://github.blog/ai-and-ml/github-copilot/assigning-and-completing-issues-with-coding-agent-in-github-copilot/
- https://github.blog/news-insights/product-news/github-copilot-meet-the-new-coding-agent/

Fetched: 2026-08-05
