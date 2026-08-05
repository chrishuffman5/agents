# Models and pricing

Read before any cost estimate, model pin, or capacity plan. **Re-verify against the live pricing page** — this is a 2026-08-05 snapshot and OpenAI's model naming has changed substantially across generations.

Prices are USD per 1M tokens unless noted. A blank cell means the figure was not shown on the page, **not** that the feature is unavailable.

## Frontier GPT-5.6 family

> Source: https://developers.openai.com/api/docs/models
> Source: https://developers.openai.com/api/docs/pricing

| Model ID | Positioning | Context | Max output | Knowledge cutoff | Input | Cached input | Output |
|---|---|---|---|---|---|---|---|
| `gpt-5.6-sol` | Frontier model for complex professional work | 1.05M | 128K | 2026-02-16 | $5.00 | $0.50 | $30.00 |
| `gpt-5.6-terra` | Balances intelligence and cost | 1.05M | 128K | 2026-02-16 | $2.00 | $0.20 | $12.00 |
| `gpt-5.6-luna` | Optimized for cost-sensitive workloads | 1.05M | 128K | 2026-02-16 | $0.20 | $0.02 | $1.20 |

All three support function/tool calling, web search, file search, and computer use.

Note the naming split: OpenAI's guide examples use the bare `gpt-5.6` while the models page enumerates the sol/terra/luna trio. Confirm which string your account accepts before pinning it in config.

The 25x input-price spread between `sol` and `luna` at identical context and output limits makes tier selection the single largest cost lever in this family — larger than caching or batching. Route by task difficulty first.

## Prior GPT-5.x generations

> Source: https://developers.openai.com/api/docs/pricing

| Model ID | Input | Cached input | Output |
|---|---|---|---|
| `gpt-5.5` | $5.00 | $0.50 | $30.00 |
| `gpt-5.5-pro` | $30.00 | — | $180.00 |
| `gpt-5.4` | $2.50 | $0.25 | $15.00 |
| `gpt-5.4-mini` | $0.75 | $0.075 | $4.50 |
| `gpt-5.4-nano` | $0.20 | $0.02 | $1.25 |
| `gpt-5.4-pro` | $30.00 | — | $180.00 |
| `gpt-5.2` | $1.75 | $0.175 | $14.00 |
| `gpt-5.2-pro` | $21.00 | — | $168.00 |
| `gpt-5.1` | $1.25 | $0.125 | $10.00 |
| `gpt-5` | $1.25 | $0.125 | $10.00 |
| `gpt-5-mini` | $0.25 | $0.025 | $2.00 |
| `gpt-5-nano` | $0.05 | $0.005 | $0.40 |
| `gpt-5-pro` | $15.00 | — | $120.00 |

`-pro` variants cost 6–12x their base model and show no cached-input rate on the pricing page. Never default to a `-pro` tier for throughput work.

## GPT-4.1 family

> Source: https://developers.openai.com/api/docs/pricing

| Model ID | Input | Cached input | Output |
|---|---|---|---|
| `gpt-4.1` | $2.00 | $0.50 | $8.00 |
| `gpt-4.1-mini` | $0.40 | $0.10 | $1.60 |
| `gpt-4.1-nano` | $0.10 | $0.025 | $0.40 |

## GPT-4o family

> Source: https://developers.openai.com/api/docs/pricing

| Model ID | Input | Cached input | Output |
|---|---|---|---|
| `gpt-4o` | $2.50 | $1.25 | $10.00 |
| `gpt-4o-2024-05-13` | $5.00 | — | $15.00 |
| `gpt-4o-mini` | $0.15 | $0.075 | $0.60 |

GPT-4o's cached-input discount is only 2x, versus 10x on GPT-5.x. Caching economics do not transfer across generations.

## Reasoning (o-series) models

> Source: https://developers.openai.com/api/docs/pricing

| Model ID | Input | Cached input | Output |
|---|---|---|---|
| `o1` | $15.00 | $7.50 | $60.00 |
| `o1-pro` | $150.00 | — | $600.00 |
| `o3` | $2.00 | $0.50 | $8.00 |
| `o3-pro` | $20.00 | — | $80.00 |
| `o3-mini` | $1.10 | $0.55 | $4.40 |
| `o4-mini` | $1.10 | $0.275 | $4.40 |

## Legacy models

> Source: https://developers.openai.com/api/docs/pricing

| Model ID | Input | Output |
|---|---|---|
| `gpt-4-turbo-2024-04-09` | $10.00 | $30.00 |
| `gpt-4-0613` | $30.00 | $60.00 |
| `gpt-3.5-turbo` | $0.50 | $1.50 |
| `gpt-3.5-turbo-0125` | $0.50 | $1.50 |
| `gpt-3.5-turbo-1106` | $1.00 | $2.00 |
| `davinci-002` | $2.00 | $2.00 |
| `babbage-002` | $0.40 | $0.40 |

`gpt-3.5-turbo` and `gpt-4-turbo` do **not** support Structured Outputs — legacy JSON mode only. `gpt-3.5-turbo` is also more expensive than `gpt-5-nano` on both input and output, so "downgrade to 3.5 to save money" is wrong on current pricing.

## Embeddings

> Source: https://developers.openai.com/api/docs/pricing

| Model ID | $ / 1M tokens |
|---|---|
| `text-embedding-3-small` | $0.02 |
| `text-embedding-3-large` | $0.13 |
| `text-embedding-ada-002` | $0.10 |

`text-embedding-ada-002` costs 5x `text-embedding-3-small`. There is no pricing reason to stay on ada-002.

## Moderation

> Source: https://developers.openai.com/api/docs/pricing

`omni-moderation-latest` — free.

## Realtime / audio models

> Source: https://developers.openai.com/api/docs/pricing

| Model ID | Audio input | Cached | Audio output |
|---|---|---|---|
| `gpt-realtime-2.1` | $32.00 | $0.40 | $64.00 |
| `gpt-realtime-2.1-mini` | $10.00 | $0.30 | $20.00 |

Audio tokens cost roughly an order of magnitude more than text tokens on comparable tiers. Budget realtime workloads by audio minute, not by text-token intuition.

## Image generation models

> Source: https://developers.openai.com/api/docs/pricing

| Model ID | Text input | Output |
|---|---|---|
| `gpt-image-2` (standard) | $5.00 | $30.00 |
| `gpt-image-1.5` | $5.00 | $10.00 |
| `gpt-image-1-mini` | $2.00 | $8.00 |

`gpt-image-2` bills by **output tokens driven by resolution and quality**; older models used per-image pricing. The flat figure above is the pricing page's headline rate — a 3840x2160 high-quality generation is not the same cost as a 1024x1024 low. Reference images and text prompts also consume input tokens.

## Video (Sora)

> Source: https://developers.openai.com/api/docs/pricing

| Model ID | Resolution | Standard $/sec | Batch $/sec |
|---|---|---|---|
| `sora-2` | 720p | $0.10 | $0.05 |
| `sora-2-pro` | 720p | $0.30 | $0.15 |
| `sora-2-pro` | 1080p | $0.70 | $0.35 |

## Batch discount

> Source: https://developers.openai.com/api/docs/pricing

Batch generally halves the synchronous rate — `gpt-5.6-sol` input drops to $2.50, `gpt-5.6-luna` input to $0.10, `gpt-4o-mini` input to $0.075. The batch guide frames it as a flat "50% cost discount."

## Fine-tuning-eligible base models

> Source: https://developers.openai.com/api/docs/guides/fine-tuning

Supervised, vision, and preference fine-tuning: `gpt-4.1-2025-04-14`, `gpt-4.1-mini-2025-04-14`, `gpt-4.1-nano-2025-04-14`, `gpt-4o-2024-08-06`. Reinforcement/reasoning fine-tuning: `o4-mini-2025-04-16`.

No GPT-5.x model appears on the fine-tuning eligibility list as of this snapshot — tuning means dropping back a generation. Depth on methods and data prep belongs to the `fine-tuning` skill.

## Gaps — do not fill from memory

- The models page returned a partial catalog. **Context windows, max output, and knowledge cutoffs are confirmed only for the GPT-5.6 trio.** GPT-4.1, GPT-4o, o-series, realtime, transcription, and TTS figures were not captured.
- Blank cached-input cells mean "not shown on the page," not "unavailable." Re-verify before quoting.
- Rate-limit numbers per model are not on the pricing page — see `rate-limits.md`.

## Sources

- https://developers.openai.com/api/docs/models
- https://developers.openai.com/api/docs/pricing
- https://developers.openai.com/api/docs/guides/fine-tuning

Fetched: 2026-08-05
