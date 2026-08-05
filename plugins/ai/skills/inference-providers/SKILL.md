---
name: inference-providers
description: "Operating LLM inference through clouds and aggregators rather than a vendor's own API: Amazon Bedrock (Converse/ConverseStream vs InvokeModel vs the bedrock-mantle endpoint, Marketplace entitlement and the Anthropic first-time-use form, cross-region inference profiles, Provisioned Throughput, Guardrails, PrivateLink), Google Cloud Vertex AI / Gemini Enterprise Agent Platform (publisher-model rawPredict endpoints, global vs multi-region vs regional hosts, Provisioned Throughput), Microsoft Foundry / Azure AI Foundry (model catalog, Global/DataZone/Regional Standard and Provisioned deployment SKUs, PTU, Entra ID vs key auth), and OpenRouter (OpenAI-compatible unified endpoint, provider and model routing, fallbacks, BYOK). Covers the direct-vs-cloud-vs-aggregator decision, per-platform model-ID translation, data-residency premiums, reserved-capacity modes, and feature-parity gaps. WHEN: \"Bedrock\", \"bedrock-runtime\", \"bedrock-mantle\", \"Converse API\", \"InvokeModel\", \"inference profile\", \"cross-region inference\", \"CRIS\", \"us.anthropic.\", \"global.anthropic.\", \"Provisioned Throughput\", \"Model Units\", \"Bedrock Guardrails\", \"ApplyGuardrail\", \"model access\", \"AccessDeniedException Bedrock\", \"Vertex AI\", \"Model Garden\", \"publisher model\", \"rawPredict\", \"aiplatform.googleapis.com\", \"vertex-2023-10-16\", \"AnthropicVertex\", \"Agent Platform\", \"Azure AI Foundry\", \"Microsoft Foundry\", \"GlobalStandard\", \"DataZoneStandard\", \"ProvisionedManaged\", \"PTU\", \"AnthropicFoundry\", \"services.ai.azure.com/anthropic\", \"Claude Consumption Unit\", \"CCU\", \"OpenRouter\", \"openrouter.ai/api/v1\", \"provider routing\", \"allow_fallbacks\", \"BYOK\", \"auto router\", \":nitro\", \":floor\", \"which cloud should we run this model on\", \"data residency for LLM calls\". Do NOT use for: choosing which model or vendor to run in the first place — that's `model-selection`; first-party Anthropic Messages API mechanics (tools, caching, batches, thinking) — that's `claude-api`; first-party OpenAI platform mechanics (Responses API, Assistants, OpenAI-hosted tools) — that's `openai-api`; pointing the Claude Code harness at Bedrock/Vertex via env vars — that's `claude-code`; the MCP protocol — that's `mcp`; prompt-injection and agent threat modeling — that's `ai-security`; egress control and VM/container isolation for agent execution — that's `sandboxing`; training or tuning a model — that's `fine-tuning`; scoring model output — that's `evals`. Cloud IAM, VPC, and networking beyond model access belong to the `cloud-platforms` plugin; SIEM/EDR ingestion of inference logs belongs to the `security` plugin."
license: MIT
---

# Inference providers: clouds and aggregators

Same weights, different control plane. A cloud or aggregator changes your auth, your model IDs, your billing entity, your residency guarantees, and — critically — **which API features exist at all**. It does not change the model.

## Volatility rule — verify before you quote

Model IDs, region availability, per-token rates, premium multipliers, deployment SKU names, and feature-parity lists all move. Every fact here is a snapshot of vendor docs on **2026-08-05**, with exact source URLs at the bottom of each file.

Re-check the cited URL before putting a model ID into production config, a price into a budget, or a "not supported on X" claim into a design doc. Never quote a figure for a platform or model this skill does not list — say it is unverified and point at the vendor's page.

## Routing

| Question | Load |
|---|---|
| Bedrock APIs, IAM, entitlement, inference profiles, PT, Guardrails, PrivateLink | `references/bedrock.md` |
| Vertex AI / Agent Platform publisher endpoints, hosts, model IDs, PT | `references/vertex-ai.md` |
| Microsoft Foundry catalog, deployment SKUs, PTU, Claude-on-Foundry auth and CCU billing | `references/azure-foundry.md` |
| OpenRouter unified API, provider/model routing, BYOK, rate limits | `references/openrouter.md` |
| "Which path do we pick?", parity matrix, residency premiums, cost stacking | `references/choosing-a-path.md` |

## Scope honesty

The corpus behind this skill is deep on **platform mechanics** (which are model-agnostic) and on **Claude as the worked example** of a partner model on each cloud, because Anthropic publishes per-platform integration docs and the clouds mostly do not.

- Model-agnostic and safe to generalize: Bedrock's Converse/InvokeModel split and IAM model, Bedrock inference profiles and Provisioned Throughput, Bedrock Guardrails, Vertex Model Garden's three model categories, Foundry's deployment-type matrix and PTU model, all of OpenRouter.
- Claude-specific and **not** transferable to Gemini/GPT/Llama on the same platform: the model-ID tables, the endpoint-premium rules, the feature-parity lists, and CCU billing.
- Not in the corpus at all: per-model IDs, quotas, and parity for Gemini on Vertex, GPT models on Foundry, or Nova/Llama/Mistral on Bedrock. Treat those as unverified and read the vendor page.

## Pick a path first

Three genuinely different paths exist, and they differ in **who invoices you**, not just in URL.

1. **First-party vendor API** — the model vendor bills you in USD. Full feature surface, newest features first. No cloud-native IAM, no committed-spend drawdown.
2. **Partner-operated cloud** (Bedrock, Vertex AI) — **the cloud invoices you** on its own pricing tables, under cloud IAM, inside your VPC/VPC-SC boundary, drawing down cloud commitments. Feature surface lags the first-party API.
3. **Vendor-operated marketplace listing** (Claude Platform on AWS, Claude in Microsoft Foundry) — the model vendor still sets the rate and applies your negotiated discount, then meters it to the cloud marketplace so the charge lands on your cloud bill. Anthropic's docs say these typically get **same-day feature access**, unlike the partner-operated integrations.
4. **Aggregator** (OpenRouter) — one OpenAI-compatible endpoint across many vendors, with routing, fallback, and BYOK.

Decide with these, in order:

- **Does procurement require the spend on an existing cloud bill or committed contract?** If yes, path 2 or 3. This is the dominant real-world reason, and it outranks technical preference.
- **Do you need a feature the cloud path does not have?** Files API, server-side code execution, MCP connector, Message Batches, Agent Skills — check the parity list in `references/choosing-a-path.md` **before** committing. Discovering a missing feature after the migration is the classic failure.
- **Is there a hard data-residency rule?** Then you are buying a regional or data-zone endpoint, and you will pay a premium for it (see below).
- **Do you need multi-vendor failover or per-request model choice?** That is an aggregator's actual product; clouds do not do it across vendors.
- **Do you need guaranteed throughput and low latency variance?** Reserved capacity exists on all three clouds under three different names and three different sizing units.

Never assume price parity between paths. Partner-operated Bedrock/Vertex rates are **set by AWS/Google independently** of the model vendor's own list price — read the cloud's pricing page, not the vendor's.

## The residency-vs-cost pattern (all three clouds)

Every major cloud converged on the same trade-off shape by 2026-08-05:

| Scope | Bedrock | Vertex AI | Microsoft Foundry |
|---|---|---|---|
| Global / anywhere | `global.` profile prefix — cheapest, most available | `region="global"`, host `aiplatform.googleapis.com` — no premium | `GlobalStandard` / `GlobalProvisionedManaged` — highest quota, newest models first |
| Geography / zone | `us.` `eu.` `jp.` `apac.` profile prefixes | `region="us"` / `"eu"`, host `aiplatform.<loc>.rep.googleapis.com` | `DataZoneStandard` / `DataZoneProvisionedManaged` (US/EU/APAC) |
| Single region | (regional model IDs) | `region="us-east5"`, host `<loc>-aiplatform.googleapis.com` | `Standard` / `ProvisionedManaged` |

Rules that follow:

- **Global is the default.** Choose narrower scope only when a regulation forces it, and price the premium in first.
- On Bedrock and Vertex, for Claude Sonnet 4.5 and later, geography-scoped and regional endpoints carry a **10% premium** over global. Bedrock frames the same axis in reverse — global cross-region inference is described as ~10% cheaper than geographic. Same number, opposite framing; do not double-count it.
- On Vertex, **Provisioned Throughput requires a regional endpoint**. Global and multi-region are pay-as-you-go only. If your capacity plan and your residency plan disagree, the residency plan wins by construction.
- On Foundry, narrowing scope costs you **default quota and model availability**, not a published multiplier — except that Claude on `DataZoneStandard` (US) is equivalent to the first-party `inference_geo: "us"` and does carry the **1.1x** multiplier.
- Bedrock cross-region routing stays on the AWS network, never the public internet, and may route into Regions you never opted into. Your SCP must allow **every** destination Region in the profile or the whole request fails; global profiles additionally need `"aws:RequestedRegion": "unspecified"` allowed.

## Reserved capacity: three names, three units

| Platform | Name | Unit | Commitment | Gotcha |
|---|---|---|---|---|
| Bedrock | Provisioned Throughput | Model Units (MUs) | none / 1 month / 6 months | **Mutually exclusive with inference profiles** — you cannot have cross-region routing and PT together. Required for any custom/fine-tuned model. Billed hourly until deleted, idle or not. |
| Vertex AI | Provisioned Throughput | GSU (unverified — see gaps) | see Google's page | Regional endpoints only. |
| Microsoft Foundry | Provisioned throughput | PTU | reservations | Min PTU and throughput-per-PTU differ per model **and per model version**. Some Azure-sold models offer *fungible* PTU usable across a model group. |

Always model reserved capacity as a floor cost, not a discount. Bedrock PT bills hourly regardless of usage, and per-MU throughput and price are not published — AWS routes you to an account manager.

## Amazon Bedrock in one page

Endpoints: `bedrock-runtime` carries **Converse/ConverseStream** (model-agnostic, recommended for new work) and **InvokeModel/InvokeModelWithResponseStream** (provider-specific JSON bodies). A newer **`bedrock-mantle`** endpoint exposes an OpenAI-style Responses API, Chat Completions, and an Anthropic Messages API directly.

Directives:

- **Default to Converse** for anything conversational — one request shape across model families, and it is how tool use and Guardrails are wired. Drop to InvokeModel only for control Converse does not expose (notably PDF analysis without forced citations).
- Converse **rewrites your input into a model-specific prompt template for Mistral and Meta models**. InvokeModel does not. Behavioral differences between the two APIs on those families are expected, not a bug.
- IAM actions differ per endpoint: `bedrock:InvokeModel*` etc. for `bedrock-runtime`, `bedrock-mantle:CreateInference` etc. for `bedrock-mantle`. `AmazonBedrockFullAccess` does **not** cover mantle — that is `AmazonBedrockMantleInferenceAccess`.
- Model access is enabled by default now; Bedrock **auto-subscribes** you in AWS Marketplace on first invoke, which can take up to 15 minutes and throws transient `AccessDeniedException` in that window. Do not debug a fresh account's first 401/403 as a policy bug before waiting it out.
- **Anthropic models require a one-time first-time-use form** per account or Org management account before first invocation. It does not apply on `bedrock-mantle`.
- To actually block a model, **Deny `bedrock:InvokeModel*` on the foundation-model ARN**. Denying `aws-marketplace:Subscribe` does not work, and `DeleteFoundationModelAgreement` is silently undone by the next invoke.
- Newer Claude models cannot be called by bare base model ID at all — they require an inference-profile ID (`us.anthropic....`) or ARN, and return an explicit "on-demand throughput isn't supported" error otherwise.
- Bedrock caps request payloads at **20 MB**, which large PDFs and image batches hit before any token limit.

Guardrails, PrivateLink, full IAM policy bodies, entitlement API sequence, and the Claude model-ID table are in `references/bedrock.md`.

## Google Vertex AI / Agent Platform in one page

Claude and other partner models are **publisher models**, called at:

```
POST https://{host}/v1/projects/${PROJECT_ID}/locations/${LOCATION}/publishers/anthropic/models/${MODEL_ID}:rawPredict
```

Directives:

- The model goes **in the URL path, not the request body**, and `anthropic_version` moves **into the body** with the fixed value `"vertex-2023-10-16"`. Those two edits are the entire porting diff from the first-party Messages API for Claude.
- **The host changes with the location type** — `aiplatform.googleapis.com` for `global`, `aiplatform.us.rep.googleapis.com` for multi-region, `us-east5-aiplatform.googleapis.com` for regional. Pointing the wrong host at the right location is the most common 404.
- Vertex model IDs use `@date` snapshot suffixes for older Claude models (`claude-sonnet-4-5@20250929`) and bare names for newer ones (`claude-opus-5`). They match neither Bedrock's ARN-versioned IDs nor always the first-party IDs.
- Payload cap is **30 MB** — larger than Bedrock's 20 MB, so a document pipeline that works on Vertex can fail on Bedrock.
- Vertex supports the **web search server tool** for Claude; Bedrock does not. This is the one significant parity split between the two clouds.
- Google is renaming this surface to **Gemini Enterprise Agent Platform**; docs live under both `vertex-ai/` and `gemini-enterprise-agent-platform/` paths and `cloud.google.com` 301s to `docs.cloud.google.com`. Treat the names as the same product.

Endpoint/host table, model IDs, auth, and parity detail in `references/vertex-ai.md`.

## Microsoft Foundry in one page

Foundry (formerly Azure AI Foundry) splits its 10,000+ model catalog into **Foundry Models sold by Azure** (Microsoft-hosted, Microsoft-supported, Azure meters, enterprise SLA) and **Foundry Models from partners and community** (provider-supported, **billed through Azure Marketplace**). Claude, and most third-party frontier models, are in the second group.

Directives:

- Deployment type is a **SKU string** you commit to: `GlobalStandard`, `DataZoneStandard`, `Standard`, `GlobalProvisionedManaged`, `DataZoneProvisionedManaged`, `ProvisionedManaged`, `GlobalBatch`, `DataZoneBatch`, `DeveloperTier`. Governance is real — Azure Policy can deny a SKU org-wide, so confirm the SKU is permitted before designing around it.
- **The `model` parameter is your deployment name**, not the catalog model ID. This breaks copy-pasted vendor examples every time.
- Partner models need **Azure Marketplace subscribe permission** plus **Contributor or Owner** on the resource group to deploy, and **Cognitive Services User** for Entra-authenticated inference. A 403 at inference time is usually the last one.
- Claude on Foundry uses the **native Anthropic Messages API shape** at `https://<resource>.services.ai.azure.com/anthropic/v1/messages` with `x-api-key` and `anthropic-version` headers — not the Azure AI Model Inference API, and not `Authorization: Bearer` for key auth.
- Subscription eligibility is a hard gate for Claude: paid pay-as-you-go only. **CSP subscriptions, South Korea Enterprise Accounts, free/trial/startup-credit accounts, and credit-only sponsored subscriptions are unsupported.** Check this during procurement, not during the deploy.
- `DeveloperTier` deployments **auto-delete after 24 hours**. Never build a pipeline on one.
- Batch SKUs are **50% off with a 24-hour target turnaround** — the cheapest per-token path on Azure for anything latency-tolerant.

Deployment matrix, data-zone geography lists, Claude hosting versions, and CCU billing mechanics in `references/azure-foundry.md`.

## OpenRouter in one page

One OpenAI-compatible endpoint — `https://openrouter.ai/api/v1/chat/completions`, `Authorization: Bearer`, drop-in for the OpenAI SDK — in front of many vendors and many hosts per model.

Directives:

- Distinguish **provider routing** (which host serves a given model) from **model routing** (`openrouter/auto-beta` picking *which model* to use). They are separate features with separate config.
- Default behavior with no `provider` object is **price-weighted load balancing** across hosts, skipping endpoints unstable in the last 30 seconds. Setting `sort` or `order` **turns that off** — you own routing from then on.
- Compliance routing is a first-class filter, not an afterthought: `zdr: true` for Zero-Data-Retention endpoints, `data_collection: "deny"` to exclude hosts with non-transient logging, `quantizations` to refuse degraded weights. Set `quantizations` on any eval or production workload where output quality must be stable — silently landing on an int4 host is a real failure mode.
- Use `require_parameters: true` whenever your request uses non-universal parameters, or a host that ignores them will serve you silently different behavior.
- Read `model` and `native_finish_reason` off every response. `model` tells you who actually served it; without logging it, you cannot reproduce or attribute a bad output.
- **BYOK** is the lever for "keep the routing layer, pay vendor rates": your own provider credentials, **5% of the equivalent OpenRouter cost**, waived under 1,000,000 BYOK requests/month. Budget guardrails **exclude BYOK spend by default** — turn inclusion on or your caps do not cap.
- Rate limits are **account-global**. Minting more API keys or accounts does not raise them. Insufficient balance is **HTTP 402**, not 429.

Full routing-field table, auto-router mechanics, session stickiness, and free-tier limits in `references/openrouter.md`.

## Porting checklist

When moving an existing integration onto a cloud or aggregator, change all six of these deliberately:

1. **Auth** — API key → SigV4/IAM role (Bedrock), ADC/service account (Vertex), Entra ID or per-deployment key (Foundry), bearer key (OpenRouter). Bedrock also accepts `AWS_BEARER_TOKEN_BEDROCK` if teams must avoid IAM credentials.
2. **Host** — and on Vertex the host varies by location type.
3. **Model ID** — never reuse a first-party ID; translate it per platform, and on Foundry substitute your deployment name.
4. **Request shape deltas** — Vertex moves `model` out of the body and `anthropic_version` into it.
5. **Feature set** — remove calls to anything the target does not support, and replace server-side fallback with a **client-side fallback pattern** (no cloud path offers the `fallbacks` parameter).
6. **Payload ceiling** — 20 MB Bedrock, 30 MB Vertex.

## Cost accounting checklist

Never quote a per-request cost from a per-token rate alone. Sum:

1. The **platform's own** per-token rate — AWS/Google set theirs independently of the model vendor's list price.
2. Scope premium: ~10% for geography/regional endpoints on Bedrock and Vertex (Claude Sonnet 4.5+); 1.1x for Claude on Foundry US Data Zone.
3. Prompt-cache multipliers where supported (5m write 1.25x, 1h write 2x, cache hit 0.1x of base input).
4. Batch discount where it applies — 50% on Bedrock batch inference and Foundry `GlobalBatch`/`DataZoneBatch`.
5. Reserved capacity as a **fixed hourly floor**, not a discount — Bedrock PT bills until deleted.
6. Platform add-ons metered separately: Bedrock Guardrails (~$0.15/1,000 text units), Bedrock-integrated web search (~$12/1,000 queries), Knowledge Bases storage and retrieval, Foundry Content Safety.
7. Aggregator margin: OpenRouter BYOK adds 5% above the underlying provider's rate (waived under 1M req/month). Its non-BYOK credit margin is **not documented in the corpus** — treat it as unverified.

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `AccessDeniedException` on a brand-new AWS account's first call | Marketplace auto-subscription still propagating (up to 15 min) | Wait and retry before touching IAM |
| Anthropic model 403s on Bedrock, IAM looks correct | One-time first-time-use form not submitted for the account/Org | Submit the FTU form, or call via `bedrock-mantle` |
| "Invocation of model ID … with on-demand throughput isn't supported" | Called a base model ID for a model that is inference-profile-only | Use the `us.`/`global.` profile ID or ARN |
| Cross-region request fails despite an allowed source Region | SCP blocks one destination Region in the profile | Allow all destinations; global profiles also need `aws:RequestedRegion: "unspecified"` |
| Deny on `aws-marketplace:Subscribe` did not block a model | Bedrock auto-subscribes in the background | Deny `bedrock:InvokeModel*` on the model ARN via SCP/IAM |
| Provisioned Throughput rejected with a cross-region profile | PT and inference profiles are mutually exclusive | Pick one purchase path |
| 404 on Vertex `rawPredict` | Host does not match the location type | Match host to `global` / multi-region / regional |
| Vertex 400 on a request that works first-party | `model` still in the body, or `anthropic_version` wrong/missing | Model in the URL; `anthropic_version: "vertex-2023-10-16"` in the body |
| Vertex Provisioned Throughput unavailable | Using a global or multi-region endpoint | PT requires a regional endpoint |
| Foundry 404 with a valid model | Passed the catalog model ID instead of the deployment name | Use the deployment name in `model` |
| Foundry 403 with a valid key | Missing **Cognitive Services User** (Entra) or RG Contributor/Owner | Grant the role |
| Foundry deploy blocked at subscription check | CSP/free/credit-only/unsupported-region subscription, or quota 0 | Move to a paid pay-as-you-go subscription in a supported billing region |
| Foundry deployment vanished overnight | `DeveloperTier` 24-hour auto-delete | Redeploy on a Standard SKU |
| OpenRouter output quality varies run to run | Routed to a different host or quantization | Pin with `only`/`order`, set `quantizations`, log the response `model` |
| OpenRouter HTTP 402 | Credit balance exhausted | Top up; check `GET /api/v1/key` |
| OpenRouter budget cap overshot | Guardrail caps exclude BYOK spend by default | Enable BYOK inclusion on the cap |
| Large-PDF request works on Vertex, fails on Bedrock | 30 MB vs 20 MB payload ceiling | Split or downsample before the Bedrock call |
| Code-execution / Files API / batches calls fail on a cloud path | Feature not offered on partner clouds | Check the parity list before porting |

## Diagnostic scripts

Read-only. They enumerate and describe; they never deploy, purchase, or invoke a model for inference.

- `scripts/bedrock-check-access.sh [region]` — lists Anthropic foundation models, inference profiles, and (per model) `GetFoundationModelAvailability` entitlement/authorization status. Answers "is this account actually entitled?" without spending a token.
- `scripts/openrouter-status.sh [model-slug]` — `GET /api/v1/key` for credit and rate-limit state, plus `GET /api/v1/models` filtered to a slug. Answers "what does my key see and what does it cost?"

## Known gaps in this skill's corpus

Stated plainly rather than guessed:

- Vertex AI **GSU sizing and Provisioned Throughput pricing**, and whether Claude is on Google's PT supported-model list, were not retrievable — only Anthropic's statement that PT requires a regional endpoint is verified.
- **Vertex IAM role names** required to call Claude publisher models, and Claude-specific Vertex quota numbers, were not surfaced.
- **VPC Service Controls** coverage for Vertex/Agent Platform — supported methods, perimeter setup, partner-model limitations — could not be extracted.
- Foundry **minimum PTU counts and $/PTU**, and the exact **regions where Claude is deployable**, were referenced by fetched pages but not themselves fetched.
- **Current per-token Claude pricing on Bedrock and Vertex** was not confirmed from AWS's or Google's own pricing pages; the Bedrock figures in the corpus are legacy-model examples.
- **OpenRouter's margin on standard (non-BYOK) credit usage** is not stated in any fetched page. Only the 5% BYOK fee is documented.
- Non-Claude per-model detail on every platform (Gemini, GPT, Nova, Llama, Mistral IDs/quotas/parity) is absent.

## Sources

- https://docs.aws.amazon.com/bedrock/latest/userguide/conversation-inference.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/inference.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/security-iam.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/security_iam_id-based-policy-examples.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-support.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/prov-throughput.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/usingVPC.html
- https://aws.amazon.com/bedrock/pricing/
- https://platform.claude.com/docs/en/api/claude-on-amazon-bedrock
- https://platform.claude.com/docs/en/api/claude-on-vertex-ai
- https://platform.claude.com/docs/en/about-claude/pricing
- https://docs.cloud.google.com/vertex-ai/generative-ai/docs/partner-models/use-claude
- https://docs.cloud.google.com/vertex-ai/generative-ai/docs/model-garden/explore-models
- https://docs.cloud.google.com/vertex-ai/generative-ai/docs/provisioned-throughput
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/partner-models/claude
- https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/model-catalog-overview
- https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types
- https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/how-to/use-foundry-models-claude
- https://openrouter.ai/docs/quickstart
- https://openrouter.ai/docs/api-reference/overview
- https://openrouter.ai/docs/features/provider-routing
- https://openrouter.ai/docs/features/model-routing
- https://openrouter.ai/docs/use-cases/byok
- https://openrouter.ai/docs/api-reference/limits

Fetched: 2026-08-05
