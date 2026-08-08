# Prompt caching

Read when cutting cost or latency on repeated prefixes, when `cached_tokens` is unexpectedly zero, or when cache costs rose after a GPT-5.6 upgrade.

## How it works

> Source: https://developers.openai.com/api/docs/guides/prompt-caching

Requests are routed to machines by hashing the prompt prefix — roughly the **first 256 tokens**. A lookup then checks whether that prefix is already cached on the target machine.

- **Cache hit** — the cached computation for the matching prefix is reused.
- **Cache miss** — the full prompt is processed; eligible prefixes may then be cached for later requests.

Set `prompt_cache_key` to influence routing and improve hit rates across requests that share a long common prefix. Without it, requests sharing a prefix can land on different machines and miss.

## Minimum token threshold

> Source: https://developers.openai.com/api/docs/guides/prompt-caching

| Model generation | Minimum |
|---|---|
| GPT-5.6 and later | strict **1,024 tokens** |
| GPT-5.5 and earlier | 1,024–2,048; behavior near 1,024 is less consistent |

Below the minimum, nothing is cached and nothing is reported as wrong. `cached_tokens` appears in usage details on every request regardless of prompt length — it is simply 0.

## Cache TTL and retention

> Source: https://developers.openai.com/api/docs/guides/prompt-caching

**GPT-5.6+:** controlled via `prompt_cache_options.ttl`. Only `"30m"` is currently supported as the default, though actual retention may exceed that minimum in practice.

**Earlier models:** the deprecated `prompt_cache_retention` field.

- `"in_memory"` policy — typical inactivity eviction in 5–10 minutes, up to 1 hour maximum.
- Extended **24h** retention — available for GPT-5.5, GPT-5.4, GPT-5.2, GPT-5.1 variants, GPT-5, and GPT-4.1.

The 24h option existing only on the deprecated field and older models is a genuine trade-off: an agent loop with hour-scale gaps may cache better on GPT-5.5 than on GPT-5.6. Measure rather than assuming newer is better here.

## Supported models

> Source: https://developers.openai.com/api/docs/guides/prompt-caching

Works on "gpt-4o and newer." GPT-5.6 adds improved reliability and explicit breakpoint control.

## Pricing impact

> Source: https://developers.openai.com/api/docs/guides/prompt-caching

| Generation | Cache write cost | Cache read cost |
|---|---|---|
| Before GPT-5.6 | **no additional fee** | discounted (cached-input rate) |
| GPT-5.6+ | **1.25x the uncached input-token rate** | discounted (cached-input rate) |

This is the most important change in this file. On pre-5.6 models a low-hit-rate cache was merely useless; on GPT-5.6+ it is **actively more expensive than not caching at all**, because every miss now pays a 1.25x write. Teams that upgrade without revisiting cache strategy see costs go up, not down.

Token accounting: `cache_write_tokens` tracks writes, `cached_tokens` tracks reads. Compare the two — a healthy cache reads far more than it writes. Roughly, writes must be amortized over more than a handful of reads before the 1.25x premium pays back at the per-model cached-input rate (see `models-and-pricing.md`).

## Prompt structuring strategy

> Source: https://developers.openai.com/api/docs/guides/prompt-caching

Place static content — instructions, examples, tool definitions — at the **start** of the prompt; put variable and user-specific content at the **end**. This applies to text, images, and tool definitions alike, all of which must be **byte-identical** across requests to match.

Common byte-identity breakers: a timestamp or request id in the system prompt, non-deterministic JSON key ordering when serializing tool definitions, and reordering a tools array. Use `scripts/cache-prefix-diff.py` to find exactly where two request bodies diverge.

For GPT-5.6+, place explicit `prompt_cache_breakpoint` markers after stable content blocks, and optionally set `prompt_cache_options.mode: "explicit"` to disable automatic breakpoint detection. On GPT-5.6+ that mode is also a cost control — it stops the platform from paying 1.25x to write breakpoints you never read back.

## Interaction with conversation state

`previous_response_id` re-bills all prior input tokens on every turn (see `responses-api.md`). Caching is what makes that affordable: the chained prefix is stable and static-first by construction, so it should hit. If a chained conversation's cost is growing linearly with turn count, check `cached_tokens` before redesigning the architecture — a broken cache is the more likely cause.

## Sources

- https://developers.openai.com/api/docs/guides/prompt-caching
- https://developers.openai.com/api/docs/guides/conversation-state

Fetched: 2026-08-05
