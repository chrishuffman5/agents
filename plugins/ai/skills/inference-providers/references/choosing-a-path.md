# Choosing a path: direct API vs cloud vs aggregator

Read when the question is "where should we run this model," when you are estimating the cost delta between paths, or when you need the parity matrix before committing to a migration.

Snapshot of vendor docs on 2026-08-05. Every number here is volatile — re-verify at the URLs below.

## The four access paths

> Source: https://platform.claude.com/docs/en/about-claude/pricing
> Source: https://platform.claude.com/docs/en/api/claude-on-amazon-bedrock
> Source: https://platform.claude.com/docs/en/api/claude-on-vertex-ai

Using Claude as the worked example — the taxonomy generalizes even where the per-vendor detail does not.

| Path | Who invoices you | Rate set by | Feature timing |
|---|---|---|---|
| **First-party API** | The model vendor, in USD | The model vendor | New features first |
| **Partner-operated cloud** — Amazon Bedrock, Google Cloud Vertex AI / Agent Platform | **The cloud** (AWS/GCP bill) | **The cloud, independently** | Lags; parity gaps below |
| **Vendor-operated marketplace** — Claude Platform on AWS, Claude in Microsoft Foundry | The cloud marketplace, but metered by the vendor | The **model vendor**, converted to CCUs at $0.01/CCU | "Typically same-day feature access" per Anthropic's Bedrock docs |
| **Aggregator** — OpenRouter | The aggregator (credits) or your own provider account (BYOK) | Underlying host, plus aggregator margin / 5% BYOK fee | Follows whichever host it routes to |

The distinction people miss is path 2 vs path 3. Both put the charge on a cloud bill. Only path 2 hands rate-setting to the cloud; path 3 keeps the model vendor's own per-token economics — including negotiated private-offer discounts — and merely reports usage to the marketplace as an aggregated unit line item.

Anthropic's first-party API also offers `inference_geo: "us"` on Claude 4.6+ for US-only inference at a **1.1x multiplier** — the first-party equivalent of a cloud residency scope.

## Decision order

Ask these in sequence. The first "yes" that constrains you decides.

1. **Must the spend land on an existing cloud bill or draw down a committed contract?** → partner-operated cloud or vendor marketplace listing. This is the dominant real-world driver and it outranks technical preference.
2. **Do you need a feature the cloud path lacks?** → check the parity matrix below *before* committing. Discovering a missing Files API or batch endpoint mid-migration is the classic failure.
3. **Is there a hard data-residency obligation?** → you are buying a regional or data-zone endpoint and paying its premium; on Vertex this also forecloses global-endpoint Provisioned Throughput.
4. **Do you need cross-vendor failover or per-request model selection?** → aggregator. Clouds do not route across vendors.
5. **Do you need guaranteed throughput and low latency variance?** → reserved capacity, under three different names and units.
6. **Otherwise** → first-party API, for the fullest feature surface and earliest access.

## Feature parity: first-party vs partner clouds

> Source: https://platform.claude.com/docs/en/api/claude-on-amazon-bedrock
> Source: https://platform.claude.com/docs/en/api/claude-on-vertex-ai

Consistent gaps across **both** Bedrock and Vertex, as of 2026-08-05:

| Capability | First-party | Bedrock | Vertex / Agent Platform |
|---|---|---|---|
| Messages API, prompt caching, extended thinking | Yes | Yes | Yes |
| Tool use: Bash, Computer use, Memory, Text editor | Yes | Yes | Yes |
| Citations, structured outputs | Yes | Yes | Yes |
| **Web search server tool** | Yes | **No** | **Yes** |
| Server-side code execution, web fetch, advisor | Yes | No | No |
| URL input sources, Files API | Yes | No | No |
| Agent Skills, MCP connector, programmatic tool calling | Yes | No | No |
| Message Batches / Models / Admin / Compliance / Usage-and-Cost endpoints | Yes | No | No |
| Claude Managed Agents | Yes | No | No |
| Server-side fallback (`fallbacks` parameter) | Yes | No | No |
| Max request payload | — | **20 MB** | **30 MB** |
| 1M context on Fable 5 / Opus 5 / Opus 4.8-4.6 / Sonnet 5 / Sonnet 4.6 | Yes | Yes | Yes |
| 200k cap on Sonnet 4.5 / Sonnet 4 | — | Yes | Yes |

Two operational consequences:

- **Replace server-side fallback with a client-side fallback pattern** on every cloud path. This is not optional; the parameter does not exist.
- **The web search tool is the single parity split between the two clouds.** If a Claude workload needs it, Vertex works and Bedrock does not.

## The residency-vs-cost trade-off, per cloud

> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html
> Source: https://platform.claude.com/docs/en/api/claude-on-amazon-bedrock
> Source: https://platform.claude.com/docs/en/api/claude-on-vertex-ai
> Source: https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types

AWS frames the axis explicitly:

| Criterion | Geographic CRIS | Global CRIS |
|---|---|---|
| Data residency | Bounded to a geography (US/EU/APAC) | Any commercial AWS Region worldwide |
| Cost | Standard pricing | **~10% cheaper** |
| AWS's recommendation | Choose under data-residency regulation | Choose for cost optimization with no residency need |

Anthropic frames the same delta from the other side: on Bedrock and Vertex, **regional/multi-region endpoints carry a 10% premium over global** for Claude Sonnet 4.5+ / Haiku 4.5+ / Opus 4.5+. It is one 10%, not two — do not stack both framings.

All three clouds converged on the same shape by 2026-08-05: global routing is cheapest and most available with no residency guarantee; scoping to a region or data zone buys compliance at a cost. The differences:

- **Bedrock**: the cost is a ~10% delta, and geography scoping is expressed through inference-profile prefixes.
- **Vertex**: the cost is a 10% premium **and** regional scoping is a hard prerequisite for Provisioned Throughput — global and multi-region are pay-as-you-go only.
- **Foundry**: the cost is a separate Data Zone SKU with generally lower default quota rather than a published multiplier, except that Claude on US Data Zone Standard carries the same **1.1x** as first-party `inference_geo: "us"`.

## Choosing within the Azure catalog

> Source: https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/model-catalog-overview

Microsoft's own framework:

- **Requirements**: deep Azure integration + guaranteed SLA + Microsoft support → **models sold by Azure**. Specialized, niche, or innovation-led → **partner and community models** (where Claude sits).
- **Support**: Azure-sold = Microsoft support. Partner/community = provider-managed with varying SLA levels. Claude support routes to Microsoft Support per the Foundry Claude docs, but licensing and data terms are Anthropic's.
- **Innovation**: partner/community gets rapid access to frontier lab capabilities, at the cost of Azure-native SLA guarantees.

## The aggregator trade-off

> Source: https://openrouter.ai/docs/features/provider-routing
> Source: https://openrouter.ai/docs/use-cases/byok

OpenRouter's documented value proposition is **provider abstraction and routing flexibility, not necessarily lower cost**. Default routing load-balances toward lowest price across whichever hosts serve a model, with configurable sort by price/throughput/latency, quantization filters, and ZDR / data-collection-deny constraints for compliance-sensitive routing.

**BYOK is the lever** for "single-vendor pricing plus the routing, fallback, and observability layer": you pay the underlying provider's own rate plus **5%** (waived under 1M requests/month), instead of the marked-up shared-capacity rate.

What an aggregator gives that a cloud cannot: cross-vendor failover, per-request model selection, one usage and cost surface across vendors, and quantization/retention filters as request parameters.

What it costs you: a third party in the request path, non-determinism about which host served a request unless you pin, and — for non-BYOK usage — a margin this skill's corpus does not document.

## Cost stacking

> Source: https://platform.claude.com/docs/en/about-claude/pricing

Multipliers apply relative to base input price and **stack multiplicatively**: 5-minute cache write **1.25x**, 1-hour cache write **2x**, cache-hit read **0.1x**, Batch API **0.5x** on both input and output, regional/geo endpoint **1.1x** (the "10% premium"), first-party `inference_geo: "us"` **1.1x**.

These behave identically across first-party, partner-cloud, and marketplace paths — **except** that partner-operated Bedrock and Vertex per-token rates are set independently by AWS and Google and must be read from their own pricing pages, never assumed equal to the vendor's list price.

### Claude first-party reference rates (per MTok, USD)

Point-in-time snapshot for models current on 2026-08-05. Authoritative only at `claude.com/pricing`.

| Model | Input | 5m cache write | 1h cache write | Cache hit | Output |
|---|---|---|---|---|---|
| Claude Fable 5 | $10 | $12.50 | $20 | $1 | $50 |
| Claude Opus 5 | $5 | $6.25 | $10 | $0.50 | $25 |
| Claude Opus 4.8 / 4.7 / 4.6 / 4.5 | $5 | $6.25 | $10 | $0.50 | $25 |
| Claude Sonnet 5 (through 2026-08-31) | $2 | $2.50 | $4 | $0.20 | $10 |
| Claude Sonnet 5 (from 2026-09-01) | $3 | $3.75 | $6 | $0.30 | $15 |
| Claude Sonnet 4.6 / 4.5 | $3 | $3.75 | $6 | $0.30 | $15 |
| Claude Haiku 4.5 | $1 | $1.25 | $2 | $0.10 | $5 |

Sonnet 5's introductory rate expires **2026-08-31** — model anything past that date at $3/$15.

**Unverified — do not quote**: current per-token Claude pricing **on Bedrock and on Vertex**. Neither cloud's pricing page yielded current Claude figures at fetch time, and the Bedrock figures in this corpus are legacy-model examples. AWS's Bedrock pricing page (cited below) and Google's generative-AI pricing page for Claude models are the authoritative sources — read them before quoting.

**Unverified — do not quote**: per-token pricing for non-Claude models on any of these platforms. Not in this corpus.

## Sources

- https://platform.claude.com/docs/en/about-claude/pricing
- https://platform.claude.com/docs/en/api/claude-on-amazon-bedrock
- https://platform.claude.com/docs/en/api/claude-on-vertex-ai
- https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html
- https://aws.amazon.com/bedrock/pricing/
- https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/how-to/use-foundry-models-claude
- https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/model-catalog-overview
- https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types
- https://openrouter.ai/docs/features/provider-routing
- https://openrouter.ai/docs/use-cases/byok

Fetched: 2026-08-05
