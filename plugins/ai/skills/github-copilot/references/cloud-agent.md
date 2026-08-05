# Cloud agent (coding agent) reference

Read when planning, configuring, or debugging asynchronous Copilot work on GitHub: issue assignment, session behavior, `copilot-setup-steps.yml`, the integrated firewall, runner selection, automations, and the IDE/MCP entry points.

Terminology: GitHub's docs now say **cloud agent**; the product UI and blog posts still say **coding agent**. Same feature.

## What it is and what it runs on

> Source: https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent
> Source: https://docs.github.com/copilot/concepts/agents/coding-agent/about-coding-agent

An autonomous agent that works inside GitHub's infrastructure rather than in an IDE — "a coding resource that works on GitHub." It investigates repository structure, drafts implementation strategies before coding, resolves bugs, adds incremental features, improves test coverage and documentation, addresses technical debt, and resolves merge conflicts.

It executes in an **ephemeral development environment powered by GitHub Actions**, where it explores code, makes modifications, runs tests, and runs linters. It automates branch creation, commit message writing, and pushing; developers review the diff and iterate.

Best fit: **low-to-medium complexity tasks in well-tested codebases**. A repository without a working test/lint loop removes the agent's only self-correction signal — fix that before blaming the agent.

## Hard limits

> Source: https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent

- **59 minutes maximum execution time per session**, cannot be extended.
- Changes only in the repository specified when the task starts — **no cross-repository modifications** in one run.
- Single branch, **exactly one pull request per task**.
- Context access limited to the specified repository by default; broader access requires MCP configuration.
- Incompatible with certain rulesets/branch-protection rules unless bypass permissions are granted by an admin.
- **GitHub-hosted repositories only.**
- Cannot comply with rules restricting commit authorship to specific identities.
- "Deep research, planning, and iterating on code changes before creating a pull request" is available **only via the cloud agent on GitHub.com**. Third-party integrations (Jira, Slack, Teams, etc.) support direct PR creation only.

## Availability and billing

> Source: https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent

- All paid Copilot plans; **not** Copilot Free.
- Copilot Business and Enterprise require **administrator enablement**.
- Repository owners can opt individual repositories out.
- Usage consumes **GitHub Actions minutes and AI credits** within included allocations.
- Enhanced features (Copilot Memory, public preview) require Pro, Pro+, or Max/Enterprise-tier plans.

## Entry points

> Source: https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent
> Source: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-on-github
> Source: https://github.blog/ai-and-ml/github-copilot/assigning-and-completing-issues-with-coding-agent-in-github-copilot/

| Entry point | How |
|---|---|
| Issue assignment | Issue → **Assignees** → **Copilot** (github.com, GitHub Mobile, or GitHub CLI) |
| PR comment | Mention `@copilot` |
| Dashboard | GitHub homepage → **Task** button → repo → request → submit (lands on the agents tab) |
| Agents tab/panel | Repo Agents tab or `github.com/copilot/agents` → repo → prompt → optional base branch |
| Copilot Chat | `/task` with requirements; the session incorporates the current chat conversation's context |
| IDE | VS Code, JetBrains, Eclipse, Visual Studio |
| Programmatic | REST API, GitHub CLI, GitHub MCP Server |
| Automated | Schedules or event-triggered automations |
| Third-party | Azure Boards, Jira, Linear, Slack, Teams; also Raycast |

Assignment dialog options: optional guidance in the prompt field, target repository and branch dropdowns, choice of custom agent, AI model, and reasoning level. "Copilot will use any custom instructions that have been configured for the target repository."

**Copilot does not react to comments added to the issue after assignment.** Put follow-up detail in the resulting pull request instead.

## Session behavior and review

> Source: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-on-github

- An **eyes emoji reaction** signals the agent has started.
- Commits stream to a **draft pull request**; progress is visible step-by-step in session logs.
- Sessions accept image inputs: `image/png`, `image/jpeg`, `image/gif`, `image/webp`.
- Mention `@copilot` in a PR comment to request changes on any PR it created. Copilot remembers context from previous sessions on the same PR.
- GitHub Actions triggered by the agent's changes require clicking **Approve and run workflows** before they run automatically.
- Context flows between Copilot Chat and cloud agent sessions — start in Chat, hand off to the agent, keep directing an in-flight session from Chat.

## Environment customization: `copilot-setup-steps.yml`

> Source: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/customize-the-agent-environment

Path: `.github/workflows/copilot-setup-steps.yml`. It must contain a **single job named `copilot-setup-steps`** — "The job MUST be called `copilot-setup-steps` or it will not be picked up by Copilot." A typo in the job name fails silently, which is the single most common cause of "the agent isn't using my setup."

Customizable job-level settings: `steps`, `permissions`, `runs-on`, `services`, `snapshot`, `timeout-minutes` (max **59**).

```yaml
name: "Copilot Setup Steps"

on:
  workflow_dispatch:
  push:
    paths:
      - .github/workflows/copilot-setup-steps.yml
  pull_request:
    paths:
      - .github/workflows/copilot-setup-steps.yml

jobs:
  copilot-setup-steps:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@v6
      - name: Set up Node.js
        uses: actions/setup-node@v7
        with:
          node-version: "20"
          cache: "npm"
      - name: Install dependencies
        run: npm ci
```

The `on:` triggers above exist so the setup workflow is validated by CI whenever it changes — keep them.

## Integrated firewall and network egress

> Source: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/customize-the-agent-environment

Allowlisted for all setups:

- `uploads.github.com`
- `user-images.githubusercontent.com`

Plan-scoped Copilot API endpoint, allowlisted based on the calling account's subscription:

| Endpoint | Plan |
|---|---|
| `api.individual.githubcopilot.com` | Copilot Pro / Pro+ / Max |
| `api.business.githubcopilot.com` | Copilot Business |
| `api.enterprise.githubcopilot.com` | Copilot Enterprise |

When the OpenAI Codex third-party agent is enabled, these are also allowlisted: `npmjs.org`, `npmjs.com`, `registry.npmjs.com`, `registry.npmjs.org`, `skimdb.npmjs.com`. (Codex's own operation is the `codex` sibling skill's territory.)

**Incompatibilities — both are hard:**

- "The firewall is not compatible with self-hosted runners." Disable the integrated firewall in repository settings when using self-hosted runners.
- "Copilot cloud agent's integrated firewall is not compatible with Windows." Using Windows runner labels in `runs-on` requires self-hosted or larger GitHub-hosted runners with custom network controls instead.

Self-hosted runner proxy configuration goes in the job's `env`:

```yaml
jobs:
  copilot-setup-steps:
    runs-on: arc-scale-set-name
    env:
      https_proxy: http://proxy.local:8080
      http_proxy: http://proxy.local:8080
      no_proxy: example.com,myserver.local:443
      ssl_cert_file: /path/to/key.pem
      node_extra_ca_certs: /path/to/key.pem
```

For isolation and egress architecture beyond these knobs, defer to the `sandboxing` sibling skill.

## Per-repository agent settings

> Source: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/configuring-agent-settings

Repository **Settings → Copilot → Cloud agent** (requires repository administrator access):

| Setting | Default | Effect |
|---|---|---|
| Validation tools | **enabled** | Built-in security checks / code review: vulnerabilities, hardcoded secrets, insecure dependencies |
| Require approval for workflow runs | **enabled** | Workflows need manual approval; disabling lets them run without human intervention |

Disabling workflow approval removes a human gate on code an agent wrote — only do it in repositories where the workflows themselves are trusted and the branch is protected.

## Organization runner configuration

> Source: https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization/configure-runner-for-coding-agent

Org **Settings → Copilot → Cloud agent** lets org owners change the default runner from `ubuntu-latest` to another GitHub-hosted runner or a labeled runner from a specific runner group. Owners also control whether individual repositories may override the org default via their own `copilot-setup-steps.yml`; if overrides are disabled, "all repositories in your organization will use the organization-level runner type."

This is the setting to check when a repo's `runs-on` appears to be ignored.

## Automations

> Source: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/create-automations

Created through the repository's **Agents tab → Automations** pane: define a prompt describing the desired action, select which tools the agent may access (e.g. pushing changes, updating labels), and test before deploying. Automations can be **scheduled or event-triggered**.

Security note from the docs: "The Copilot cloud agent sessions started by an automation are visible to others with access to the repository. Don't include secrets or other sensitive information in your prompt."

Related how-to pages: `manage-rationale-confidence-approvals` (rationale, confidence, and approvals for issues handled by automation) and `changing-the-ai-model` (model and reasoning-level selection when starting tasks).

## MCP with the cloud agent

> Source: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-with-mcp
> Source: https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent

The **GitHub and Playwright MCP servers are enabled by default**. MCP is also the documented way to give the agent context beyond the single starting repository.

To drive the cloud agent from any MCP-capable IDE or agentic tool:

1. Install the GitHub MCP Server in that host.
2. Enable the `create_pull_request_with_copilot` tool in the MCP configuration.
3. Note it works only with **remote** GitHub MCP Servers, in hosts supporting remote MCP connectivity.

Workflow: describe the change in chat ("expand unit test coverage") → Copilot opens a preliminary PR, implements progressively, pushes to the branch, and adds you as reviewer. A base branch can be specified in the prompt; the host usually surfaces the PR URL.

**Unverified gap**: the configuration syntax for adding *arbitrary* MCP servers to the cloud agent (the equivalent of VS Code's `mcp.json`) was not retrievable on 2026-08-05. Do not invent a file path or schema — say it is unconfirmed and point the user at repository/org Copilot settings and the `manage-mcp-usage` admin page. Protocol-level MCP questions belong to the `mcp` sibling skill.

## Using the cloud agent from an IDE

> Source: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-in-your-ide

**VS Code**

- Requires the **GitHub Pull Requests** extension from the marketplace first.
- Open Copilot Chat → enter the task prompt (optionally select relevant code) → click **"Delegate this task to the GitHub Copilot cloud agent"** → choose whether to include local changes or start from the default branch. Copilot creates a PR and notifies you when done.
- Track sessions via the GitHub sidebar button: status, jump to PR, view session logs. "Open in VS Code" for a session is currently limited to **VS Code Insiders**.

**JetBrains IDEs** (public preview, subject to change)

- Enable at Settings → Tools → Copilot → Chat → **Enable Cloud Agent**. Business/Enterprise users need admin approval for Editor preview features.
- Open Copilot Chat → type the prompt → click **"Delegate to Cloud Agent"** next to Send. Copilot generates a PR and adds you as reviewer.
- A unified sessions view (**"GitHub Cloud Agent Jobs"** sidebar button) combines local, CLI, and cloud agent sessions: status, browser access to PRs, job cancellation, and IDE notifications on start/finish.
- Difference from VS Code: JetBrains integration is built in (no extra extension) and has a unified cross-agent dashboard; VS Code tracks sessions separately.

## Troubleshooting order

> Derived from the sourced sections above; ordering is judgement, every constraint cited is sourced earlier in this file.

1. **Plan and admin enablement** — paid plan; Business/Enterprise admin has enabled the cloud agent; the repository is not opted out.
2. **Setup not applied** — is the job in `.github/workflows/copilot-setup-steps.yml` named exactly `copilot-setup-steps`?
3. **Runner ignored** — did the org disable per-repository runner overrides?
4. **Network failures during a session** — firewall allowlist; self-hosted or Windows runners require the firewall to be off and proxy env vars set.
5. **Ran out of time** — 59 minutes is a hard cap; split the task.
6. **Push or branch failure** — branch-protection rulesets, or a rule restricting commit authorship (the agent cannot satisfy that one).
7. **Workflows never ran** — "Approve and run workflows" is pending, or workflow approval is required by the repo setting.
8. **Follow-up ignored** — comments added to the issue after assignment are not read; comment on the PR.

The docs also carry a dedicated `troubleshoot-cloud-agent` how-to page under `/en/copilot/how-tos/use-copilot-agents/cloud-agent/`.

## Sources

- https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent
- https://docs.github.com/copilot/concepts/agents/coding-agent/about-coding-agent
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-on-github
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-in-your-ide
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-with-mcp
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/customize-the-agent-environment
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/configuring-agent-settings
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/create-automations
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization/configure-runner-for-coding-agent
- https://docs.github.com/en/copilot/how-tos/copilot-on-github/copilot-for-github-tasks/use-copilot-to-create-or-update-issues
- https://github.blog/ai-and-ml/github-copilot/assigning-and-completing-issues-with-coding-agent-in-github-copilot/
- https://github.blog/news-insights/product-news/github-copilot-meet-the-new-coding-agent/

Fetched: 2026-08-05
