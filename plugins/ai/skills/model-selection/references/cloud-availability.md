# Cloud availability — Bedrock, Google Cloud Agent Platform, Claude Platform on AWS, Microsoft Foundry (as of 2026-08-05)

Read when the workload runs on a cloud rather than a first-party API, or when a feature might not exist off the first-party API. Re-verify against the source URLs.

## Amazon Bedrock (Claude)

> Source: https://platform.claude.com/docs/en/build-with-claude/claude-in-amazon-bedrock

Claude in Amazon Bedrock now serves Claude via the **Messages API** at `/anthropic/v1/messages` on AWS-managed infrastructure with zero Anthropic operator access. Endpoint pattern: `https://bedrock-mantle.{region}.api.aws/anthropic/v1/messages`. The legacy `InvokeModel`/`Converse` integration with ARN-versioned model IDs remains available separately.

**Access:** Claude Fable 5, Opus 4.8, Sonnet 5, Opus 4.7, and Haiku 4.5 are open to all Bedrock customers. Claude Mythos Preview requires a Project Glasswing invitation plus an allowlisted AWS account.

### Model IDs

| Model | Bedrock model ID | Access |
|---|---|---|
| Claude Fable 5 | `anthropic.claude-fable-5` | Open |
| Claude Opus 5 | `anthropic.claude-opus-5` | See access notes |
| Claude Opus 4.8 | `anthropic.claude-opus-4-8` | Open |
| Claude Opus 4.7 | `anthropic.claude-opus-4-7` | Open |
| Claude Sonnet 5 | `anthropic.claude-sonnet-5` | Open |
| Claude Haiku 4.5 | `anthropic.claude-haiku-4-5` | Open |
| Claude Mythos Preview | `anthropic.claude-mythos-preview` | Invitation only |

(Fully pinned Bedrock IDs for older snapshots — e.g. `anthropic.claude-haiku-4-5-20251001-v1:0`, `anthropic.claude-sonnet-4-5-20250929-v1:0`, `anthropic.claude-opus-4-5-20251101-v1:0` — are listed in `claude-catalog.md`.)

### Authentication

1. **Bedrock service role** (recommended) — AWS-managed keys, longest-lived.
2. **IAM assumed roles** — federated identity, 12-hour max session.
3. **Bearer tokens** — short-term, 12-hour max, least preferred; minted via the `aws-bedrock-token-generator` CLI and passed as the `x-api-key` header.

### Endpoint types

- **Global** — dynamic routing across all available regions, maximum availability, **no pricing premium**. Available for Fable 5, Opus 5, Opus 4.8, Opus 4.7, Sonnet 5, Haiku 4.5.
- **Regional** — resolves to a single specified AWS region, **10% pricing premium** over global, required for data residency. Use an inference profile (US/EU/JP/AU) to route across multiple regions within a geography; some regions support direct single-region routing ("In-region only").
- Claude Mythos Preview is **regional-only**, available in `us-east-1`.

### Regions

Global endpoint available in all; these regions also support In-region-only or inference-profile geographies: `us-east-1`, `us-east-2`, `us-west-1`, `us-west-2`; `eu-central-1`, `eu-central-2`, `eu-north-1`, `eu-south-1`, `eu-south-2`, `eu-west-1/2/3`; `ap-northeast-1/2/3`, `ap-south-1/2`, `ap-southeast-1/2/3/4`; `ca-central-1`, `ca-west-1`; `af-south-1`; `il-central-1`; `me-central-1`; `sa-east-1`.

### Quotas

Default **2M input tokens/minute (TPM)**; raisable to **4M input TPM** without additional Anthropic approval. RPM limits are enforced by AWS — contact AWS support to adjust.

### Feature gaps vs. first-party API

Not supported on Bedrock: URL sources for images/documents, Files API, server-side tools (code execution, web search, web fetch, advisor), Agent Skills, MCP connector, programmatic tool calling, Message Batches / Admin / Compliance / Usage-Cost API endpoints, Claude Managed Agents, and server-side fallback (the `fallbacks` parameter — implement client-side fallback instead).

## Google Cloud Agent Platform / Vertex AI (Claude)

> Source: https://platform.claude.com/docs/en/build-with-claude/claude-on-vertex-ai

Request shape differs from the first-party Messages API in two ways: **`model` is not in the request body** — it goes in the endpoint URL; and **`anthropic_version` is a body field** (not a header), fixed to `vertex-2023-10-16`.

Install: `pip install -U "anthropic[vertex]"` (Python), `npm install @anthropic-ai/vertex-sdk` (TypeScript), `dotnet add package Anthropic.Vertex` (C#), `go get github.com/anthropics/anthropic-sdk-go` (Go). Auth: `gcloud auth application-default login`, then default Google Cloud credentials.

### Model IDs

| Model | Google Cloud model ID |
|---|---|
| Claude Fable 5 | `claude-fable-5` |
| Claude Opus 5 | `claude-opus-5` |
| Claude Opus 4.8 | `claude-opus-4-8` |
| Claude Opus 4.7 | `claude-opus-4-7` |
| Claude Opus 4.6 | `claude-opus-4-6` |
| Claude Sonnet 5 | `claude-sonnet-5` |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` |
| Claude Sonnet 4.5 | `claude-sonnet-4-5@20250929` |
| Claude Sonnet 4 (deprecated) | `claude-sonnet-4@20250514` |
| Claude Sonnet 3.7 (retired) | `claude-3-7-sonnet@20250219` |
| Claude Opus 4.5 | `claude-opus-4-5@20251101` |
| Claude Opus 4.1 (deprecated) | `claude-opus-4-1@20250805` |
| Claude Opus 4 (deprecated) | `claude-opus-4@20250514` |
| Claude Haiku 4.5 | `claude-haiku-4-5@20251001` |
| Claude Haiku 3.5 (deprecated) | `claude-3-5-haiku@20241022` |

Lifecycle dates on Google Cloud are **set by Google** and can differ from the Claude API schedule — check Google's own "Claude models on Agent Platform" docs for exact retirement dates there.

### Example request

```bash
MODEL_ID=claude-opus-5
PROJECT_ID=MY_PROJECT_ID
curl https://aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/publishers/anthropic/models/${MODEL_ID}:rawPredict \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "anthropic_version": "vertex-2023-10-16",
    "messages": [{"role": "user", "content": "Hey Claude!"}],
    "max_tokens": 100
  }'
```

### Endpoint types

- **Global** (recommended) — dynamic routing, no premium, pay-as-you-go only (no provisioned throughput). `region="global"`.
- **Multi-region** — routes within the `us` or `eu` geography, **10% premium**, pay-as-you-go only. `region="us"` / `region="eu"`, resolving to `aiplatform.us.rep.googleapis.com` / `aiplatform.eu.rep.googleapis.com`.
- **Regional** — a single specific region (e.g. `us-east5`, `europe-west1`), **10% premium**, required for provisioned throughput. **Specific regional endpoints only support Claude Sonnet 4.6 and earlier** — newer models (Fable 5, Opus 5, Sonnet 5, …) are global or multi-region only.
- The 10% premium applies to Sonnet 4.5 and later models only; Sonnet 4 / Opus 4 and earlier keep the prior pricing structure.

### Context window and payload cap

Claude Fable 5, Opus 5, Opus 4.8, Opus 4.7, Opus 4.6, Sonnet 5, and Sonnet 4.6 have a **1M-token context window** on Agent Platform. Sonnet 4.5 and Sonnet 4 (deprecated) have 200k. Request payloads are capped at **30 MB** — large documents or many images can hit this before the token limit does.

### Feature gaps vs. first-party API

Not supported: URL sources, Files API, server-side tools (code execution, web fetch, advisor), Agent Skills, MCP connector, programmatic tool calling, Message Batches / Models / Admin / Compliance / Usage-Cost API endpoints, Claude Managed Agents, server-side fallback.

## Claude Platform on AWS and Microsoft Foundry

> Source: https://platform.claude.com/docs/en/about-claude/pricing

Both are **Anthropic-operated** and marketplace-billed, and both use **Claude Consumption Units (CCU)**: token usage is rated in USD at standard per-model rates, discounts are applied, then the total converts to CCUs at **$0.01/CCU** and is reported hourly to the AWS or Azure Marketplace. Postpaid/arrears only — no prepaid credits.

Inference geography: `inference_geo: "us"` (Claude 4.6+) applies **1.1x** on Claude Platform on AWS; the Microsoft Foundry equivalent is the "US Data Zone Standard" deployment type, same 1.1x.

Because these are Anthropic-operated, Anthropic's deprecation dates apply to them (unlike Bedrock and Google Cloud).

## Partner pricing caveat

Bedrock and Google Cloud are **partner-operated** with **independent regional pricing**. Anthropic's published $/MTok rates are the first-party reference; for official partner rates consult the AWS Bedrock pricing page and the Google Cloud Vertex AI pricing page directly.

**Gap:** the fetched `cloud.google.com/vertex-ai/generative-ai/pricing` page did not surface a distinct Claude pricing table in this pass. Confirm Claude-on-Vertex rates at `cloud.google.com/vertex-ai/generative-ai/pricing#claude-models` before quoting exact numbers.

## Choosing a platform

- Default to the **first-party API** — it is the only surface with the complete feature set.
- Choose **Bedrock** or **Google Cloud** when procurement, an existing cloud commit, or data-residency rules require it; then confirm every feature the design depends on survives the gap lists above.
- Prefer **global endpoints** on both clouds unless residency forces regional — regional costs 10% more on both.
- Choose **Claude Platform on AWS** or **Microsoft Foundry** when marketplace billing is the requirement and you want Anthropic-operated infrastructure with Anthropic's deprecation timeline.

## Sources

- https://platform.claude.com/docs/en/build-with-claude/claude-in-amazon-bedrock
- https://platform.claude.com/docs/en/build-with-claude/claude-on-vertex-ai
- https://platform.claude.com/docs/en/about-claude/pricing
- https://platform.claude.com/docs/en/about-claude/model-deprecations
- https://cloud.google.com/vertex-ai/generative-ai/pricing

Fetched: 2026-08-05
