# OpenAI — model catalog, pricing, and selection framework (as of 2026-08-05)

Read when the question names OpenAI, GPT, Codex, o-series, Sora, or asks for an OpenAI model ID / price / limit. Re-verify against the source URLs before quoting.

Sourcing note: `platform.openai.com/docs/models` and `platform.openai.com/docs/pricing` now issue a permanent 301 to `developers.openai.com/api/docs/…`. The URLs cited here are the redirect targets — OpenAI's current official API documentation host.

## Current flagship family: GPT-5.6

> Source: https://developers.openai.com/api/docs/models

Three tiers sharing identical context window, max output, and knowledge cutoff — differentiated only by price and intelligence.

| Model | Model ID | Purpose | Context | Max output | Knowledge cutoff | Input $/MTok | Output $/MTok |
|---|---|---|---|---|---|---|---|
| GPT-5.6 Sol | `gpt-5.6-sol` | "Frontier model for complex professional work" | 1.05M | 128K | Feb 16, 2026 | $5.00 | $30.00 |
| GPT-5.6 Terra | `gpt-5.6-terra` | Balances intelligence and cost | 1.05M | 128K | Feb 16, 2026 | $2.00 | $12.00 |
| GPT-5.6 Luna | `gpt-5.6-luna` | Cost-optimized for high-volume work | 1.05M | 128K | Feb 16, 2026 | $0.20 | $1.20 |

All three support function calling, web search, file search, computer use, and "all" reasoning-effort levels, plus multimodal (text/image) input, multilingual use, and vision via the Responses API. Cached-input pricing: Sol $0.50, Terra $0.20, Luna $0.02 per MTok.

### Long-context meter

> Source: https://developers.openai.com/api/docs/pricing

OpenAI charges a **separate, higher rate for long-context requests** — unlike Claude 4.6+, which prices the full window flat:

| Model | Standard in/out | Long-context in/out |
|---|---|---|
| `gpt-5.6-sol` | $5 / $30 | **$10 / $45** |
| `gpt-5.6-terra` | $2 / $12 | **$4 / $18** |
| `gpt-5.6-luna` | $0.20 / $1.20 | **$0.40 / $1.80** |

## Full current pricing table

> Source: https://developers.openai.com/api/docs/pricing

Per 1M tokens, USD:

| Model | Input | Cached input | Output | Notes |
|---|---|---|---|---|
| `gpt-5.6-sol` | $5.00 | $0.50 | $30.00 | Top tier, current flagship |
| `gpt-5.6-terra` | $2.00 | $0.20 | $12.00 | Mid-range |
| `gpt-5.6-luna` | $0.20 | $0.02 | $1.20 | Economical |
| `gpt-5.5` | $5.00 | $0.50 | $30.00 | 272K context limit; prior flagship |
| `gpt-5.5-pro` | $30.00 | — | $180.00 | Premium tier |
| `gpt-5.4` | $2.50 | $0.25 | $15.00 | 272K context limit |
| `gpt-5.4-mini` | $0.75 | $0.075 | $4.50 | Compact |
| `gpt-5.4-nano` | $0.20 | $0.02 | $1.25 | Ultra-lightweight |
| `gpt-5.2` | $1.75 | $0.175 | $14.00 | Established |
| `gpt-5` | $1.25 | $0.125 | $10.00 | Shutdown Dec 11, 2026 |
| `gpt-5-mini` | $0.25 | $0.025 | $2.00 | Budget; shutdown Dec 11, 2026 |
| `gpt-4o` | $2.50 | $1.25 | $10.00 | Multimodal, legacy family |
| `gpt-4o-mini` | $0.15 | $0.075 | $0.60 | Fastest legacy inference |
| `o1` | $15.00 | $7.50 | $60.00 | Reasoning-focused, legacy — shutdown Oct 23, 2026 |
| `o3` | $2.00 | $0.50 | $8.00 | Optimized reasoning, legacy |

**Pricing modifiers:** fast mode applies a **2x** multiplier; the Batch API gives a **50%** discount; regional data residency adds a **10%** surcharge for models released after March 5, 2026.

### Other families

- **Realtime / audio:** `gpt-realtime-2.1` — audio $32 / $0.40 cached / $64 per MTok, text $4 / $0.40 / $24, image $5 / $0.50. `gpt-realtime-2.1-mini` — audio $10 / $0.30 / $20, text $0.60 / $0.06 / $2.40.
- **Image generation:** `gpt-image-2` (standard) — text $5 / $1.25, image tokens $8 / $2 / $30. `gpt-image-1.5` (standard) — text $5 / $1.25 / $10, image tokens $8 / $2 / $32.
- **Video (Sora):** `sora-2` $0.10/sec at 720p; `sora-2-pro` $0.30–$0.70/sec (720p–1080p).
- **Embeddings:** `text-embedding-3-small` $0.02/MTok; `text-embedding-3-large` $0.13/MTok.

## GPT-5-Codex (agentic coding)

> Source: https://developers.openai.com/api/docs/models/gpt-5-codex

- **Model ID:** `gpt-5-codex`
- Pricing: input $1.25/MTok, cached input $0.125/MTok, output $10.00/MTok.
- Context window 400,000 tokens; max input 272,000; max output 128,000.
- "A version of GPT-5 optimized for agentic coding tasks," available **exclusively through the Responses API** — not Chat Completions.
- Supports streaming, structured outputs, function calling, image input, web search, prompt caching, reasoning tokens.
- Knowledge cutoff: **September 30, 2024** — notably older than the GPT-5.6 tiers.
- Smaller variant referenced on the same page: `codex-mini-latest` ($1.50 input / $6 output per MTok); full specs not confirmed there.

**UNVERIFIED:** no `gpt-5.6-codex` model ID was found in the fetched docs as of 2026-08-05. OpenAI's own model-selection guidance indicates Codex CLI/IDE products run on the general GPT-5.6 tiers (Sol/Terra/Luna). Treat any "5.6-codex" ID claim as unverified.

## Official model-selection framework

> Source: https://developers.openai.com/api/docs/guides/model-selection

Two-phase optimization:

1. **Optimize for accuracy first** — iterate on prompting and architecture until the accuracy target is met.
2. **Optimize for cost and latency second** — then maintain that accuracy with the cheapest, fastest model possible.

**Set the accuracy target from financial impact**, not an arbitrary round number. Worked example (fake-news classifier): each correctly classified article saves ~$50 in review costs; each misclassification costs ~$300 in remediation. That asymmetry computes to a break-even minimum accuracy of **85.8%**.

**Cost/latency tactics once the target is hit:** reduce API requests per task; minimize input volume and constrain output length; move to a smaller model that still clears the bar.

**Worked comparison** (1,000 articles, fake-news classification):

| Approach | Accuracy | Cost | Latency |
|---|---|---|---|
| GPT-4o zero-shot | 84.5% (below target) | $1.72 | <1s |
| GPT-4o few-shot (5 examples) | 91.5% (meets target) | $11.92 | <1s |
| GPT-4o-mini fine-tuned | 91.5% (meets target) | $0.21 | <1s |

Takeaway: a smaller fine-tuned model matched few-shot accuracy at under 2% of the cost, once the accuracy target was pinned down.

**Tier positioning:** `gpt-5.6-sol` for frontier capability, `gpt-5.6-terra` for balance, `gpt-5.6-luna` for efficient high-volume work.

**UNVERIFIED:** the fetched selection guide references "max reasoning effort" for demanding tasks needing more exploration/verification but did not enumerate the discrete reasoning-effort level names. Do not assert specific effort-level strings from memory.

## Sources

- https://developers.openai.com/api/docs/models
- https://developers.openai.com/api/docs/pricing
- https://developers.openai.com/api/docs/models/gpt-5-codex
- https://developers.openai.com/api/docs/guides/model-selection

Fetched: 2026-08-05
