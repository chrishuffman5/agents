# OpenRouter

Read when you are putting an aggregator in front of multiple model vendors, configuring provider or model routing and fallbacks, enforcing compliance constraints on which host serves a request, or wiring BYOK.

Snapshot of OpenRouter docs on 2026-08-05. Routing fields, slugs, and limits change — re-verify at the URLs below.

## Base API and authentication

> Source: https://openrouter.ai/docs/quickstart
> Source: https://openrouter.ai/docs/api-reference/overview

- **Endpoint**: `https://openrouter.ai/api/v1/chat/completions` — an OpenAI-compatible Chat Completions interface, drop-in for the OpenAI SDK.
- **Auth**: `Authorization: Bearer <OPENROUTER_API_KEY>`.
- **Optional attribution headers**: `HTTP-Referer` (identifies your app on openrouter.ai), `X-OpenRouter-Title` / `X-Title` (display name), `X-OpenRouter-Categories` (marketplace category attribution).
- **Model listing**: browse `openrouter.ai/models`, or `GET /api/v1/models`.
- **Streaming**: SSE via `stream: true`. The stream may include comment payloads — ignore them rather than failing to parse.
- **Tool calling**: standard OpenAI-style `tools` array. OpenRouter transforms it per-provider, and for providers without native tool calling it converts to YAML templates. **Check per-model tool-calling support on the model page** — "supported" is not uniform across hosts.
- **Anthropic beta headers** pass through via `x-anthropic-beta` when routed to an Anthropic-backed provider, e.g. `interleaved-thinking-2025-05-14`, `structured-outputs-2025-11-13`.

### Response shape

Normalized to OpenAI Chat conventions, plus fields that only an aggregator can give you:

| Field | Why it matters |
|---|---|
| `choices[]` | `message` (non-streaming) or `delta` (streaming) |
| `usage` | Native-tokenizer counts including cached tokens, plus a cost breakdown |
| `model` | **Which model actually served the request** |
| `finish_reason` | Normalized: `tool_calls`, `stop`, `length`, `content_filter`, `error` |
| `native_finish_reason` | The raw provider reason behind the normalization |

**Always log `model` and `native_finish_reason`.** Without them you cannot reproduce an output, attribute a regression to a host, or tell a content filter from a length cutoff.

### Model naming

Models are addressed by slug. A **tilde prefix** (`~`) marks a "latest alias" that auto-resolves to the newest version of a model family, e.g. `~openai/gpt-latest`. Aliases are convenient and non-reproducible — pin exact slugs for anything you need to reproduce, including evals.

## Provider routing

> Source: https://openrouter.ai/docs/features/provider-routing

Configured with a `provider` object in the request body. This selects **which host serves a given model**.

| Field | Type | Purpose |
|---|---|---|
| `order` | string[] | Providers to attempt in sequence |
| `allow_fallbacks` | boolean | Allow backup providers when the primary is unavailable |
| `require_parameters` | boolean | Route only to providers supporting **all** requested parameters |
| `data_collection` | `"allow"` \| `"deny"` | `"deny"` restricts to providers without non-transient logging |
| `zdr` | boolean | Route only to Zero Data Retention endpoints |
| `enforce_distillable_text` | boolean | Restrict to models that allow text distillation |
| `only` | string[] | Whitelist provider slugs |
| `ignore` | string[] | Blacklist provider slugs |
| `quantizations` | string[] | Filter by quantization: `int4, int8, fp4, mxfp4, nvfp4, fp6, fp8, mxfp8, bf16, fp16, fp32, unknown` |
| `sort` | string \| object | `"price"`, `"throughput"`, `"latency"` — or `{by, partition}` |
| `preferred_min_throughput` | number \| object | Minimum tokens/sec, percentile-based |
| `preferred_max_latency` | number \| object | Maximum latency, percentile-based |
| `max_price` | object | Per-token-type ceiling, e.g. `{"prompt": 1, "completion": 2, "request": 0.5, "image": 0.1}` (per-million-token) |

Behaviors to design around:

- **Default with no `provider` object**: load-balance across hosts weighted toward lowest price (inverse-square weighting), automatically excluding endpoints that were unstable in the last 30 seconds.
- **Setting `sort` or `order` disables that default load balancing.** You own routing from that point; the price weighting no longer protects you.
- **Slug shortcuts**: append `:nitro` to a model slug to prioritize throughput, `:floor` to prioritize price.
- **Sort partitioning**: `sort.by` + `sort.partition`. `partition: "model"` (default) sorts hosts within each requested model; `partition: "none"` sorts globally across all candidate models and hosts — use it to pick the single best-performing option regardless of which model that turns out to be.
- **Performance thresholds**: `preferred_min_throughput` / `preferred_max_latency` use rolling 5-minute metrics at p50/p75/p90/p99 (higher percentile = more conservative). Endpoints failing a threshold are **demoted to fallback position, not hard-excluded** — a bad-latency host can still serve you if everything else fails.
- **Provider slug targeting**: base slugs like `"google-vertex"` match all regional and variant endpoints; fully-qualified slugs like `"google-vertex/us-east5"` target one specific endpoint. Service-tier endpoints require explicit opt-in.

### Compliance routing

`zdr: true`, `data_collection: "deny"`, and `quantizations` are the three levers that make an aggregator usable under a data policy:

- `zdr: true` — Zero Data Retention endpoints only.
- `data_collection: "deny"` — excludes providers with non-transient logging.
- `quantizations` — pin acceptable weight precision. **Set this on evals and production quality-sensitive paths**; silently landing on an int4 host is a real and hard-to-diagnose quality regression.

Set `require_parameters: true` whenever the request uses non-universal parameters, or a host that ignores them serves silently different behavior with no error.

## Model routing (Auto Router)

> Source: https://openrouter.ai/docs/features/model-routing

Distinct from provider routing: the **Auto Router** (`openrouter/auto-beta`) picks **which model** answers each prompt.

1. **Task classification** — ~30 fine-grained categories (e.g. `code:debugging`, `math`).
2. **Spend-share ranking** — references live community spend patterns from the trailing 7 days.
3. **Cost/quality filtering** — applies your `cost_quality_tradeoff`, or a named `cost_tier`: `low`, `medium`, `high`, `xhigh`, `max`.
4. **Fallback chain** — routes through top-ranked models in order, degrading to a default model set if classification fails.

Restrict candidates with `allowed_models`, using wildcards (`anthropic/*`, `openai/gpt-5*`) or exact slugs (`openai/gpt-5.1`).

**Session stickiness**: subsequent requests in the same conversation route to the same underlying model — implicitly by message-content hashing, or explicitly via `session_id`. This keeps multi-turn behavior consistent **and preserves prompt-cache efficiency**; without it a long conversation can bounce between models and lose every cache hit.

The Auto Router's ranking depends on community spend patterns, so its choices shift over time. Never use it for reproducible evaluation — pin a model there.

## BYOK (Bring Your Own Key)

> Source: https://openrouter.ai/docs/use-cases/byok

Supply your **own** provider credentials instead of paying OpenRouter's shared-capacity rate; keys are encrypted and used for requests routed to that provider.

- **Prioritized keys** are attempted before shared OpenRouter capacity. **Fallback keys** are used only after shared endpoints fail.
- **"Always use for this provider"** forces all matching requests onto your key with no fallback to shared capacity.
- **Explicitly supported providers**: OpenAI, Azure (both AI Foundry and OpenAI variants), Amazon Bedrock, Google Vertex AI, plus others not detailed.
- **Fee**: **5% of what the same model/provider would normally cost on OpenRouter**, deducted from your OpenRouter credit balance — **waived for the first 1,000,000 BYOK requests per month**.
- **Key setup by provider**: Azure needs either simplified Foundry config or per-deployment setup; AWS Bedrock accepts a simple API key or full AWS IAM credentials; Google Vertex needs a service-account JSON key with appropriate permissions.
- **Guardrail and budget spend caps exclude BYOK spend by default** unless explicitly enabled to include it. A cap you believe is enforcing is not enforcing until you turn this on.

BYOK is the answer to "we want vendor pricing and our own commitments, but we still want routing, fallback, and one observability surface."

## Rate limits and credits

> Source: https://openrouter.ai/docs/api-reference/limits

- Two independent mechanisms: **credit limits** (spend caps tied to balance and per-key caps) and **rate limits** (request-frequency caps plus DDoS protection).
- Limits are governed **globally per account** — "making additional accounts or API keys will not affect your rate limits." Key sharding does not buy throughput.
- **Free model variants** (slugs ending `:free`):

| Lifetime credits purchased | Requests/minute | Requests/day |
|---|---|---|
| < $10 | 20 | 50 |
| ≥ $10 | 20 | 1,000 |

- Check remaining credits and usage: `GET /api/v1/key`.
- **Insufficient balance is HTTP 402**, not 429. Handle them separately — retrying a 402 never succeeds.
- Usage is tracked all-time and in daily/weekly/monthly windows, with **separate tracking for BYOK usage vs OpenRouter-credit usage**.

## Known gap

**OpenRouter's own margin on standard (non-BYOK) credit-based usage is not documented in any fetched page.** Only the 5% BYOK fee is stated. Standard credit pricing appears to pass through provider list prices per the model listing, but no fetched statement confirms this. Treat any non-BYOK margin figure as unverified and check current model pages and pricing docs.

## Sources

- https://openrouter.ai/docs/quickstart
- https://openrouter.ai/docs/api-reference/overview
- https://openrouter.ai/docs/features/provider-routing
- https://openrouter.ai/docs/features/model-routing
- https://openrouter.ai/docs/use-cases/byok
- https://openrouter.ai/docs/api-reference/limits

Fetched: 2026-08-05
