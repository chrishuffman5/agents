# Cursor models, plans, and cost mechanics

Read this when explaining Cursor's two usage pools, choosing an Auto mode, deciding whether Max Mode applies, estimating third-party model cost, or mapping a feature to a plan tier.

All figures are as fetched on 2026-08-05 and are the kind of thing that changes — restate them as "as of 2026-08-05" and point users at `cursor.com/pricing` for current numbers.

For cross-vendor model capability comparison and tier selection independent of Cursor, use the `model-selection` sibling skill.

## Available models and the two pools

> Source: https://cursor.com/docs/models

Cursor exposes models from two usage pools, both resetting monthly:

**Cursor Models pool**

- **Cursor Grok 4.5** — described as "jointly trained with SpaceXAI for long-running work"
- **Composer 2.5** — Cursor's own proprietary agentic coding model

This pool carries "significantly more included usage" than the third-party pool. Steering a cost-sensitive user toward Composer 2.5 or Grok 4.5 is the main lever for staying inside a plan's included usage.

**Other Models pool**

50+ third-party options from OpenAI (GPT-5 series variants), Anthropic (Claude models), Google (Gemini series), and others — "charged at the model's API price," with at least $20/month of included usage on Pro and above.

Per-model context-window sizes were **not** stated on the fetched pages; individual `docs/models/<model>.md` reference pages exist but were not fetched. Treat context-window claims as unverified.

## Plans

> Source: https://cursor.com/docs/models-and-pricing.md

**Individual:**

| Plan | Price | Included third-party model usage |
|---|---|---|
| Start (India only) | ₹649/month | None — Cursor Models pool only |
| Pro | $20/month | $20 |
| Pro Plus | $60/month | $70 |
| Ultra | $200/month | $400 |

**Business:**

| Plan | Price |
|---|---|
| Teams — Standard | $40/user/month |
| Teams — Premium | $120/user/month (5x Standard agent limits) |
| Enterprise | Custom pricing, priority support |

Example third-party rates, per million tokens (input/output):

| Model | Input | Output |
|---|---|---|
| Claude Sonnet 5 | $3 | $15 (launch promo $2 / $10 through August 2026) |
| GPT-5.4 | $2.50 | $15 |
| Gemini 3.1 Pro | $2 | $12 |
| Claude Opus 5 | $5 | $25 |

## Plan feature gates

> Source: https://cursor.com/pricing

| Tier | What it unlocks |
|---|---|
| **Hobby (Free)** | No credit card; limited Agent requests; access to Composer |
| **Pro ($20/mo)** | Extended Agent limits, generous Grok & Composer allowances, frontier model access, MCPs/skills/hooks, cloud agents, usage-based Bugbot billing |
| **Pro+** | 3x Pro Agent limits; same frontier model and Composer access; MCPs, skills, hooks, cloud agents; usage-based Bugbot |
| **Ultra** | 20x Pro Agent limits; frontier models and Composer; priority access to new features; usage-based Bugbot |
| **Teams (Standard & Premium)** | All Individual features plus centralized billing/administration, internal marketplace for rules/skills/plugins, agentic code review via Bugbot, shared team context for agents/automations, usage analytics dashboard, **team-wide privacy mode**, SAML/OIDC SSO. Premium adds 5x Standard agent limits |
| **Enterprise (custom)** | All Teams features plus pooled usage, invoice/PO billing, SCIM seat management, repository/model/MCP access controls, auto-run/browser/network controls, audit logs, service accounts, AI code tracking API, priority support |

Two gates worth surfacing early in a purchase conversation: **MCP servers, hooks, and cloud agents start at Pro** (not Free), and **SCIM plus model/MCP access controls are Enterprise-only**.

## Max Mode

> Source: https://cursor.com/docs/models

**Definition:** "Max Mode extends a model's context window beyond the default limit," and applies only to **legacy request-based plans**.

**Cost:** billed at the model's API rate **plus 20%**.

**Availability:** some models — Claude 4.5 Opus and GPT-5.5 are named — **require** Max Mode on legacy request-based plans; other models support it as an optional toggle.

If a user on a current (non-legacy) plan asks about Max Mode, the answer is that it does not apply to them — the equivalent modern surcharge is the Cursor Token Rate below.

## Auto modes

> Source: https://cursor.com/docs/models, https://cursor.com/docs/models-and-pricing.md

Three automatic model-selection strategies:

1. **Auto Cost** — "charged at per million tokens rate regardless of which model is used" (flat rate). Most predictable spend.
2. **Auto Balance** — "charged at Model API rates for the model used, based on actual usage."
3. **Auto Intelligence** — similar to Auto Balance, with model selection optimized for capability rather than cost.

On Teams/Enterprise, "Cursor Router picks the model for each Auto request based on your optimization mode."

Auto Cost is also the mode exempt from the Cursor Token Rate — see below — which makes it doubly the choice for a team optimizing predictability over peak capability.

## Additional cost factors

> Source: https://cursor.com/docs/models-and-pricing.md

- **Max Mode surcharge** — +20% on API pricing, legacy request-based plans only
- **Cursor Token Rate** (Teams/Enterprise) — **$0.25 per million tokens** applied to third-party model requests; **exempt** for first-party models and for Auto Cost mode
- **Regional data residency** — **10% uplift** on eligible models
- **Cloud Agents** — charged at API pricing for the selected model, scaling with the selected context window; a spend limit is set on first activation

## Unverified

- `cursor.com/docs/account/plans-and-usage` returned 404; plan facts above come from `models-and-pricing.md` and `/pricing`, which may differ in exact plan-limit wording from the canonical account-settings docs.
- Per-model context-window sizes for Grok 4.5, Composer 2.5, and third-party models — the per-model reference pages were not fetched.
- The docs did not describe a dedicated model-picker UI beyond noting that models can be selected individually or via automated routing.

## Sources

- https://cursor.com/docs/models
- https://cursor.com/docs/models-and-pricing.md
- https://cursor.com/pricing
- https://cursor.com/docs/get-started/installation

Fetched: 2026-08-05
