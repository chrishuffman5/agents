# Google Gemini — model catalog, limits, and pricing (as of 2026-08-05)

Read when the question names Gemini, Google AI Studio, Vertex AI / Agent Platform, Nano Banana, Veo, or Antigravity, or asks for a Gemini model ID / price / limit. Re-verify against the source URLs before quoting.

## Gemini 3 series (latest generation)

> Source: https://ai.google.dev/gemini-api/docs/models

**Stable / GA:**

- `gemini-3.6-flash` — balances speed with intelligence for agentic tasks; **new default model for the Antigravity agent** in this generation.
- `gemini-3.5-flash` — intelligent model for coding and agentic work.
- `gemini-3.5-flash-lite` — fastest, most cost-effective option.
- `gemini-3.1-flash-lite` — frontier performance at reduced cost.
- `gemini-3.1-flash-image` ("Nano Banana 2") — image generation optimized for speed.
- `gemini-3.1-flash-lite-image` ("Nano Banana 2 Lite") — ultra-low-latency image generation.
- `gemini-3-pro-image` ("Nano Banana Pro") — state-of-the-art 4K image generation.

**Preview:**

- `gemini-3.1-pro-preview` — advanced reasoning and problem-solving; the current Pro-tier preview, superseding `gemini-3-pro-preview`.
- `gemini-3-flash-preview` — frontier-performance alternative.
- `gemini-3.1-flash-live-preview` — real-time dialogue.
- `gemini-3.1-flash-tts-preview` — low-latency speech generation.
- `gemini-3.5-live-translate-preview` — translation, 70+ languages.
- `gemini-omni-flash` — video generation/editing.

There is **no GA Pro-tier model in the 3.x line** as of this snapshot — Pro is either preview (`gemini-3.1-pro-preview`) or a generation back (`gemini-2.5-pro`).

## Gemini 2.5 series (still current and supported)

> Source: https://ai.google.dev/gemini-api/docs/models

| Model ID | Purpose |
|---|---|
| `gemini-2.5-pro` | "Most advanced model for complex tasks" |
| `gemini-2.5-flash` | Price-performance for reasoning tasks |
| `gemini-2.5-flash-lite` | Fastest and most budget-friendly multimodal |
| `gemini-2.5-flash-image` ("Nano Banana") | Fast creative image workflows |

## Version and lifecycle naming

> Source: https://ai.google.dev/gemini-api/docs/models

- **Stable** — points to a specific stable snapshot; generally does not change under you.
- **Preview** — usable in production but can be deprecated with **at least 2 weeks' notice**.
- **Experimental** — not suitable for production; most restrictive rate limits, no stability guarantee.
- **`-latest` suffix** (e.g. `gemini-flash-latest`) — a pointer to the newest release in that family, **not** a pinned snapshot. Never pin production to it.

**Confirmed precedent:** `gemini-3-pro-preview` **was shut down March 9, 2026**, with Google directing users to `gemini-3.1-pro-preview` to avoid disruption — the concrete example of the 2-week preview policy in practice.

## Per-model specs (verified pages)

> Source: https://ai.google.dev/gemini-api/docs/models/gemini-2.5-pro
> Source: https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash
> Source: https://ai.google.dev/gemini-api/docs/models/gemini-3.1-pro-preview

| Model | Input token limit | Output token limit | Knowledge cutoff | Thinking | Inputs |
|---|---|---|---|---|---|
| `gemini-2.5-pro` | 1,048,576 | 65,536 | January 2025 | Yes | Audio, image, video, text, PDF |
| `gemini-2.5-flash` | 1,048,576 | 65,536 | January 2025 | Yes | Audio, image, video, text, PDF |
| `gemini-3.1-pro-preview` | 1,048,576 | 65,536 | **UNVERIFIED** (not published in fetched docs) | Yes | Text, image, video, audio, PDF |
| `gemini-3.6-flash` | 1,000,000 (per latest-model page) | 64,000 | **UNVERIFIED** (not published in fetched docs) | Yes (agentic) | Multimodal |

`gemini-2.5-pro` and `gemini-2.5-flash` output **text only** (no native audio/image generation) and support caching, code execution, file search, function calling, structured outputs, Google Search grounding, and Google Maps grounding. Neither supports the Live API. `gemini-2.5-pro` is described as Google's "state-of-the-art thinking model" for analyzing large datasets, codebases, and documents.

`gemini-3.1-pro-preview` additionally supports the Batch API, Flex inference, and Priority inference; file search on it is **AI Studio only**; no audio/image generation, no Live API. Latest update noted as February 2026.

**UNVERIFIED across the whole 3.x generation:** exact knowledge-cutoff dates for `gemini-3.6-flash`, `gemini-3.5-flash`, `gemini-3.5-flash-lite`, and `gemini-3.1-pro-preview` were not present on the fetched pages. Only the 2.5-generation cutoff (January 2025) is explicitly published. Do not state a 3.x cutoff as fact.

## Google's own tier heuristic

> Source: https://ai.google.dev/gemini-api/docs/latest-model

"If you need the most capable model, look for 'Pro.' If you need fast and cost-effective, look for 'Flash.' For maximum throughput at minimum cost, choose 'Flash-Lite.'"

- **Pro** — complex multi-step reasoning, software engineering, scientific research, large document analysis, agentic workflows with custom tools.
- **Flash** — described as handling "80–90% of production workloads" (chatbots, summarization, classification) at roughly one-tenth Pro's cost. `gemini-3.6-flash` targets code generation, spatial/multimodal reasoning, and multi-step agentic workflows at stronger performance and lower price than `gemini-3.5-flash`.
- **Flash-Lite** — low-latency, cost-optimized multimodal for high-frequency lightweight tasks: high-volume agentic subagent execution, simple data extraction, structured JSON parsing, high-volume translation (chat messages, reviews, support tickets).

## Gemini API pricing (AI Studio)

> Source: https://ai.google.dev/gemini-api/docs/pricing

Three access tiers: **Free** (limited model access, free tokens, AI Studio — note that free-tier content **may be used to improve Google's products**, stated explicitly on the pricing page); **Paid** (higher rate limits, context caching, Batch API at 50% off, advanced models); **Enterprise** (custom security, dedicated support, provisioned throughput, volume discounts).

Paid-tier, per 1M tokens, USD:

| Model | Input | Output | Context caching | Google Search grounding |
|---|---|---|---|---|
| `gemini-3.6-flash` | $1.50 | $7.50 | $0.15 write + $1.00/1M tok/hour storage | 5,000 free req/month, then $14/1,000 |
| `gemini-3.5-flash` | $1.50 | $9.00 | $0.15 write + $1.00/1M tok/hour | 5,000 free/month, then $14/1,000 |
| `gemini-3.5-flash-lite` | $0.30 | $2.50 | $0.03 write + $1.00/1M tok/hour | 5,000 free/month, then $14/1,000 |
| `gemini-3.1-flash-lite` | $0.25 (text/image/video), $0.50 (audio) | $1.50 | $0.025–$0.05 write + $1.00/1M tok/hour | 5,000 free/month, then $14/1,000 |
| `gemini-3.1-pro-preview` | $2.00–$4.00 (tiered by prompt length) | $12.00–$18.00 | $0.20–$0.40 write + $4.50/1M tok/hour | 5,000 free/month, then $14/1,000 |
| `gemini-2.5-pro` | $1.25–$2.50 (tiered) | $10.00–$15.00 | $0.125–$0.25 write + $4.50/1M tok/hour | 1,500 RPD free, then $35/1,000 |
| `gemini-2.5-flash` | $0.30 (text/image/video), $1.00 (audio) | $2.50 | $0.03–$0.1 write + $1.00/1M tok/hour | 1,500 RPD free, then $35/1,000 |
| `gemini-2.5-flash-lite` | $0.10 (text/image/video), $0.30 (audio) | $0.40 | $0.01–$0.03 write + $1.00/1M tok/hour | 1,500 RPD free, then $35/1,000 |

**Tiered-pricing pattern:** Gemini 3.1 Pro Preview and Gemini 2.5 Pro charge more per token once prompt length crosses an internal threshold (consistent with the >200K break documented on Vertex pricing below). Gemini 3.6/3.5 Flash and Flash-Lite show flat per-token pricing regardless of prompt length in the fetched paid-tier table.

**Batch** roughly halves cost — e.g. `gemini-3.5-flash` drops from $1.50/$9.00 to **$0.75/$4.50** per 1M input/output.

### Embeddings, image, video

- `gemini-embedding-2-preview`: text $0.20, image $0.45, audio $6.50, video $12.00 per 1M tokens (paid); free for all input types on the free tier.
- `gemini-embedding-001`: text $0.15 per 1M tokens (paid); free input on the free tier.
- `gemini-3.1-flash-image` ("Nano Banana 2"): input $0.50/1M tokens; output text $3.00/1M, output images $60.00/1M tokens (≈$0.045–$0.151 per image by resolution).
- `gemini-2.5-flash-image` ("Nano Banana"): $0.039/image standard, $0.0195/image batch.
- Veo 3.1 video: $0.05–$0.60 per second depending on model and resolution.

## Vertex AI (Agent Platform) pricing

> Source: https://cloud.google.com/vertex-ai/generative-ai/pricing

Gemini 3 series, per 1M tokens:

| Model | Input (≤200K) | Input (>200K) | Output |
|---|---|---|---|
| `gemini-3.1-pro-preview` | $2.00 | $4.00 | $12.00 |
| `gemini-3.6-flash` | $1.50 | $1.50 (flat) | $7.50 |
| `gemini-3.5-flash` | $1.50 | $1.50 (flat) | $9.00 |
| `gemini-3.5-flash-lite` | $0.30 | $0.30 (flat) | $2.50 |
| `gemini-3-flash-preview` | $0.50 | $0.50 (flat) | $3.00 |

Gemini 2.5 series, per 1M tokens:

| Model | Input (≤200K) | Input (>200K) | Output |
|---|---|---|---|
| `gemini-2.5-pro` | $1.25 | $2.50 | $10.00 |
| `gemini-2.5-flash` | $0.30 | $0.30 (flat) | $2.50 |
| `gemini-2.5-flash-lite` | $0.10 | $0.10 (flat) | $0.40 |

**Vertex pricing modifiers:** priority tier **1.8x** standard; flex/batch **0.5x**; cached tokens **90% discount**; grounding with custom data **$2.50 per 1,000 prompts**.

**Gap:** the fetched Vertex pricing page did not surface a distinct **Claude-on-Vertex** pricing table in this pass. Claude pricing on Vertex is referenced from Anthropic's docs as matching first-party Claude API rates, billed through Google Cloud — see `claude-catalog.md` for the per-model $/MTok figures and `cloud-availability.md` for Vertex model IDs and endpoint premiums. Confirm authoritative Claude-on-Vertex rates directly at `cloud.google.com/vertex-ai/generative-ai/pricing#claude-models` before quoting exact numbers.

## Sources

- https://ai.google.dev/gemini-api/docs/models
- https://ai.google.dev/gemini-api/docs/latest-model
- https://ai.google.dev/gemini-api/docs/models/gemini-2.5-pro
- https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash
- https://ai.google.dev/gemini-api/docs/models/gemini-3.1-pro-preview
- https://ai.google.dev/gemini-api/docs/models/gemini-3-pro-preview
- https://ai.google.dev/gemini-api/docs/pricing
- https://cloud.google.com/vertex-ai/generative-ai/pricing

Fetched: 2026-08-05
