# Google Cloud Vertex AI / Gemini Enterprise Agent Platform

Read when you are calling partner or publisher models on Google Cloud, choosing between global, multi-region, and regional endpoints, porting first-party API code to `rawPredict`, or planning Provisioned Throughput on Vertex.

Snapshot of Google and Anthropic docs on 2026-08-05. Re-verify model IDs, region support, and pricing at the URLs below.

## Naming and redirects

> Source: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/partner-models/use-claude
> Source: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/partner-models/claude

Google is renaming the Vertex AI generative-AI surface to **"Agent Platform" / "Gemini Enterprise Agent Platform"**. Claude documentation now lives at `docs.cloud.google.com/gemini-enterprise-agent-platform/models/partner-models/claude`, and `cloud.google.com/vertex-ai/...` URLs **301-redirect to `docs.cloud.google.com/vertex-ai/...`**.

Treat "Vertex AI" and "Agent Platform" as the same product. Anthropic's own docs still call the REST host `aiplatform.googleapis.com` and use both names interchangeably. The extent of the rename could not be fully confirmed — see gaps.

## Model Garden: three model categories

> Source: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/model-garden/explore-models

Model Garden is the centralized hub for discovering, testing, and deploying models, organized as:

- **Google first-party models** — Gemini (Pro/Flash/Flash-Lite), Veo (video), Lyria (music), Virtual Try-On, Gemini Robotics ER 2 — accessed via managed APIs.
- **Open models** — Llama, Gemma, DeepSeek, Qwen and others — self-deployable via custom containers, or reachable through managed Model-as-a-Service (MaaS).
- **Partner / third-party models** — **Claude (Anthropic)**, Grok (xAI), Mistral AI, OpenAI. These authenticate through the third-party provider's terms and bill accordingly.

Consumption patterns across all categories: direct API calls, **Provisioned Throughput** (guaranteed capacity), **batch inference**, and self-deployment for open models.

Per-model IDs, quotas, and parity for **Gemini and other non-Claude models are not in this skill's corpus** — read Google's per-model pages.

## Publisher-model endpoint shape

> Source: https://platform.claude.com/docs/en/api/claude-on-vertex-ai
> Source: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/partner-models/use-claude

Partner models are **publisher models** under a publisher namespace, called with `rawPredict`:

```
POST https://{host}/v1/projects/${PROJECT_ID}/locations/${LOCATION}/publishers/anthropic/models/${MODEL_ID}:rawPredict
```

`LOCATION` is `global`, a multi-region (`us`/`eu`), or a specific region (`us-east5`) — and **the host changes with it** (see the endpoint table below).

### Two differences from the first-party Messages API

The Agent Platform API is "nearly identical" to the Anthropic Messages API, with exactly two porting edits:

1. **`model` is not in the request body** — it is in the URL path (`.../models/${MODEL_ID}:rawPredict`).
2. **`anthropic_version` is in the request body**, not a header, and must equal `"vertex-2023-10-16"`.

Everything else — messages array, `max_tokens`, tools, thinking, caching — carries over unchanged.

### Authentication and examples

Local dev: `gcloud auth application-default login`. Production: the standard Google Cloud credential chain (service accounts). Claude on Agent Platform also supports API-key-based auth.

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

```python
from anthropic import AnthropicVertex   # pip install "anthropic[vertex]"
client = AnthropicVertex(project_id="MY_PROJECT_ID", region="global")
message = client.messages.create(
    model="claude-opus-5",
    max_tokens=100,
    messages=[{"role": "user", "content": "Hey Claude!"}],
)
```

## Endpoint types: global, multi-region, regional

> Source: https://platform.claude.com/docs/en/api/claude-on-vertex-ai

Applies to Claude Sonnet 4.5 and later; older models keep prior pricing and behavior.

| Endpoint type | `region` value | Host pattern | Premium | Provisioned Throughput |
|---|---|---|---|---|
| Global | `"global"` | `aiplatform.googleapis.com`, `locations/global` | **None** — recommended default | **No** (pay-as-you-go only) |
| Multi-region | `"us"` / `"eu"` | `aiplatform.${LOCATION}.rep.googleapis.com` (e.g. `aiplatform.us.rep.googleapis.com`) | **10%** | **No** (pay-as-you-go only) |
| Regional | `"us-east5"`, `"europe-west1"`, … | `${LOCATION}-aiplatform.googleapis.com` | **10%** | **Yes — the only type that supports it** |

Consequences:

- **Global first.** Max availability, dynamic routing, no premium. Narrow only for a compliance requirement.
- **Provisioned Throughput forces regional scoping**, which forces the 10% premium. A capacity plan that assumes a global endpoint is unbuildable.
- Specific regional endpoints support **Claude Sonnet 4.6 and earlier**; newer models are global/multi-region only. That means the newest Claude models cannot be run on Vertex PT at all as of this snapshot.
- Host/location mismatches produce 404s that look like a missing model. Check the host first.

## Claude model IDs on Agent Platform

> Source: https://platform.claude.com/docs/en/api/claude-on-vertex-ai

| Model | Agent Platform model ID |
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

IDs with `@date` are pinned dated snapshots. Bare IDs (Fable 5, Opus 5, Sonnet 5, Opus 4.8/4.7/4.6, Sonnet 4.6) are the newer naming convention. **Note Vertex uses `@` where Bedrock uses ARN versioning and the first-party API uses `-`** — the three ID schemes are not interchangeable.

## Feature parity vs the first-party API

> Source: https://platform.claude.com/docs/en/api/claude-on-vertex-ai

**Supported**: Messages API, prompt caching, extended thinking, tool use (Bash, Computer use, Memory, Text editor), **web search tool**, citations, structured outputs. Google's Claude page additionally lists batch predictions, token counting, and safety classifiers as available capabilities.

**Not supported**: URL input sources and Files API, server-side code execution / web fetch / advisor tools, Agent Skills / MCP connector / programmatic tool calling, Message Batches / Models / Admin / Compliance / Usage-and-Cost API endpoints, Claude Managed Agents, server-side `fallbacks` (use client-side fallback).

**The web search tool is the one place Vertex beats Bedrock** on Claude parity — Bedrock does not support it.

**Context window**: Fable 5, Opus 5, Opus 4.8/4.7/4.6, Sonnet 5, and Sonnet 4.6 get the full 1M-token window. Sonnet 4.5 and Sonnet 4 cap at 200k. **Request payload limit 30 MB**, versus Bedrock's 20 MB.

## Provisioned Throughput

> Source: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/provisioned-throughput
> Source: https://platform.claude.com/docs/en/api/claude-on-vertex-ai

Provisioned Throughput is Vertex's reserved-capacity consumption option, parallel to Bedrock PT and Azure PTU, documented as a purchasable reservation alongside pay-as-you-go and batch inference.

Verified constraint: **Claude Provisioned Throughput on Agent Platform requires a regional endpoint.** Global and multi-region endpoints serve pay-as-you-go traffic only.

**Unverified — do not quote**: GSU (Generative AI Scale Unit) sizing mechanics, PT pricing, and whether Claude appears on Google's PT supported-models table. The fetch of Google's provisioned-throughput page returned partial content missing the supported-models table and GSU pricing. Read Google's page directly before committing to a reservation.

## Data retention and logging

> Source: https://platform.claude.com/docs/en/api/claude-on-vertex-ai

Data handling for Claude on Agent Platform is governed by **Google Cloud's** data-governance terms, not Anthropic's. Agent Platform provides request-response logging you can enable to capture prompts and completions; Anthropic recommends a 30-day rolling log. Enabling it does not give Google or Anthropic access to your content.

## IAM and quotas

> Source: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/partner-models/use-claude

Claude on Agent Platform supports API-key auth and Application Default Credentials (service accounts), with IAM-based access control, and has a dedicated "Quotas for Anthropic Claude models" page. Supported consumption modes: Provisioned Throughput, standard pay-as-you-go, and batch inference.

**Unverified — do not quote**: the exact **IAM role names and permissions** required to call Claude publisher models, and the **numeric quota values**. Google's page did not surface them through fetch. Read the "Quotas for Anthropic Claude models" page and Google's IAM reference before writing a least-privilege policy.

**Unverified — do not quote**: **VPC Service Controls** support for Vertex/Agent Platform. Google's VPC-SC page returned no article body, so supported methods, perimeter setup, and partner-model limitations are unknown here. Verify directly; VPC-SC design generally is the `cloud-platforms` plugin's territory.

## Sources

- https://platform.claude.com/docs/en/api/claude-on-vertex-ai
- https://docs.cloud.google.com/vertex-ai/generative-ai/docs/partner-models/use-claude
- https://docs.cloud.google.com/vertex-ai/generative-ai/docs/model-garden/explore-models
- https://docs.cloud.google.com/vertex-ai/generative-ai/docs/provisioned-throughput
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/partner-models/claude

Fetched: 2026-08-05
