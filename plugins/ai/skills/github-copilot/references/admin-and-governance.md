# Plans, administration, and governance

Read when answering "can my plan do X," when configuring org/enterprise policy, when auditing Copilot activity, or when setting up Copilot Spaces.

## Plans and pricing

> Source: https://docs.github.com/en/copilot/get-started/plans

| Plan | Price | Audience | Notable inclusions |
|---|---|---|---|
| Copilot Free | free | Individuals without org/enterprise access | Limited features and models, **auto model selection only** |
| Copilot Student | free (verified) | Verified students | Unlimited completions, an AI credit allowance, limited chat/agent usage, auto selection only |
| Copilot Pro | $10/mo | Individuals (free for eligible teachers and OSS maintainers) | Unlimited completions, **manual model selection**, cloud agent, monthly AI credits |
| Copilot Pro+ | $39/mo | Individuals | Pro plus higher AI credits and premium model access |
| Copilot Max | $100/mo | Individuals | Pro+ plus the highest credit allowance and priority access to new models/features |
| Copilot Business | $19/seat/mo | Orgs on GitHub Free/Team, and enterprises | Cloud agent, broad model catalog, monthly AI credit pool, centralized management, policy controls |
| Copilot Enterprise | $39/seat/mo | GitHub Enterprise Cloud | Business plus priority access, larger credit pool, enterprise capabilities |

Feature gating that matters most often:

- **Cloud (coding) agent**: Student tier and above — **not** in Free.
- **Code review**: Free is limited to "Review selection" in VS Code; full code review starts at Student.
- **Model selection**: Free and Student get auto selection only; Pro through Enterprise get manual selection.
- **Claude Opus models (4.5–5)** require Enterprise/Business tiers or higher-tier individual plans (Pro+/Max).
- **Newer premium models** (Opus 4.7+ and other "5"-class models) require Pro+/Max/Enterprise access.
- **Management**: Business and Enterprise provide centralized administration and policy controls. Enterprise can assign Copilot Enterprise or Business to specific organizations or teams.

Time-sensitive as of 2026-08-05: "Starting April 22, 2026, new self-serve sign-ups for Copilot Business for organizations on GitHub Free and GitHub Team plans are temporarily paused." Verify current status before advising a new signup.

**Unverified gap**: exact premium-request / AI-credit multipliers per model and per plan. The plans page references a separate models-and-pricing page that could not be fetched at a working URL. State this as unknown; do not estimate multipliers.

## Enterprise policy controls

> Source: https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-enterprise-policies

Location: enterprise settings → **AI controls**, with sidebar sections **Agents**, **Copilot**, and **MCP** — three policy categories: Agents policies, Copilot policies, MCP policies.

UI patterns: dropdown menus selecting an enforcement option, toggle switches, and click-through to per-policy detail pages.

Confirmed named policies and defaults:

- **"Suggestions matching public code"** — set to **Blocked** by default for Copilot Business users; adjustable in the Privacy section of the Copilot policy page.
- **"MCP servers in Copilot"** — controls only where MCP support is generally available **within Copilot itself**. It does **not** govern access permissions for GitHub's own MCP server used inside third-party applications such as Cursor or Claude; that is governed separately.
- Enterprise owners can opt into user feedback collection by enabling "Copilot in GitHub.com."

**Unverified gap**: a full enumeration of every enterprise/org policy name with its default enforcement value was not available on the fetched pages. Only the policies above are confirmed — do not present an invented policy list as authoritative.

## Organization policy controls

> Source: https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization/manage-policies

Two management areas:

- **Policies** — privacy and feature availability.
- **Models** — access to advanced/paid models beyond the default set.

Confirmed named policies:

- **"MCP servers in Copilot"** — use where MCP server support is GA.
- **Third-party coding agents** — enabling Anthropic Claude and OpenAI Codex as alternative coding agents. (Operating those tools themselves is the `codex` and `claude-code` siblings' territory; this policy is only the GitHub-side switch.)
- **"Copilot in GitHub.com"** — feedback collection and preview features.

Configuration: click a policy's dropdown and select an enforcement option; multiple enforcement levels exist per policy (not enumerated on the fetched page).

**Precedence**: "If your enterprise owner has selected a specific policy… you cannot override that setting at the organization level." Enterprise beats organization — check the enterprise setting before debugging an org-level one.

## Organization access management

> Source: https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization/manage-access

Organization owners grant and revoke Copilot access for members, with dedicated flows for granting to some or all members and for revoking. An **approval-request workflow** lets owners approve or deny member requests for Copilot access. The page also references network routing controls for subscription-based access management without further detail.

## Audit logs

> Source: https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/review-audit-logs

Two categories of logged events:

1. **Copilot plan changes** — "Changes to your Copilot plan, such as changes to settings and policies or a user losing or receiving a license."
2. **Agent activity** — records of Copilot agents operating on GitHub's website.

**Hard limitation**: the audit log does **not** capture client-session data such as local prompts. Organizations needing that must build custom solutions — for example webhooks forwarding CLI events to an internal logging service. Never tell a compliance owner that GitHub's audit log covers IDE or CLI prompt content.

Access: enterprise settings on GitHub.com → gear icon → **Audit log**.

Search and filter:

| Query | Returns |
|---|---|
| `action:copilot` | All Copilot-related events |
| `action:copilot.cfb_seat_assignment_created` | License assignment events |
| `actor:Copilot` | Agent activity records |

**Retention: 180 days.** For longer history and automated anomaly detection, GitHub recommends streaming to a SIEM platform — SIEM design and detection content belong to the security plugin.

## Administration page index

> Source: https://docs.github.com/en/copilot/how-tos/administer-copilot
> Source: https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization

Top level under `/en/copilot/how-tos/administer-copilot/`:

- `manage-for-organization` — subscribe, manage, and control Copilot policies at org level
- `manage-for-enterprise` — licensing, access control, policies/guardrails, usage monitoring
- `manage-mcp-usage` — control availability of MCP servers for developers company-wide
- `download-activity-report` — license-usage reporting for org/enterprise
- `view-usage-and-adoption` — Copilot usage metrics dashboard
- `view-code-generation` — code-generation dashboard
- `view-impact-dashboard` — Copilot impact dashboard

Organization subpages under `manage-for-organization/`:

- `manage-plan`, `manage-access`, `manage-policies`
- `add-copilot-cloud-agent` — cloud agent setup for the org
- `configure-runner-for-coding-agent` — runner type configuration (detail in `cloud-agent.md`)
- `prepare-for-custom-agents` — org readiness for custom agents
- `manage-default-models`, `enable-custom-models` — model availability and custom models
- `review-activity`

## Copilot Spaces

> Source: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/copilot-spaces/create-copilot-spaces

Containers that "centralize relevant content that grounds Copilot's responses" for a specific task.

Creation: `github.com/copilot/spaces` → **Create space** → descriptive name → personal or organization ownership → confirm → optional description. Name and description are editable later via the edit icon.

Context types:

- **Instructions** — free-form text defining Copilot's focus, expertise, task types, and boundaries.
- **Sources** — files, folders, repositories (smart-searched); URLs to GitHub PRs and issues; uploaded documents (images, text, spreadsheets); pasted text such as notes or transcripts.

Attaching a repository uses smart search across it (good for large-scale queries); attaching individual files loads them fully (best when specific documents must always be prioritized). A space attached to a repository automatically tracks the latest code on the **main branch**. Files can be added from GitHub's code view via the **Add to space** icon.

## Content exclusion

> No source: searched for on 2026-08-05 and not found. Nothing below is a documented claim.

**Unverified gap.** A canonical, fetchable page describing content exclusion — preventing Copilot from using specific repositories or paths across chat, completions, and the cloud agent — could not be located under the current docs.github.com structure on 2026-08-05; several plausible slugs returned 404 or did not mention it. Treat both the configuration format and the current feature name as unconfirmed and direct the user to their org/enterprise Copilot policy settings to check in-product. Do not reproduce a remembered YAML schema.

## Sources

- https://docs.github.com/en/copilot/get-started/plans
- https://docs.github.com/en/copilot/how-tos/administer-copilot
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization/manage-policies
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-organization/manage-access
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-enterprise-policies
- https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/review-audit-logs
- https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/copilot-spaces/create-copilot-spaces

Fetched: 2026-08-05
