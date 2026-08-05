# Anthropic Claude — model catalog, pricing, and mechanics (as of 2026-08-05)

Read when the question names Claude, Anthropic, Fable, Mythos, Opus, Sonnet, or Haiku, or asks for a Claude model ID / price / limit. Re-verify against the source URLs before quoting.

## Current lineup

> Source: https://platform.claude.com/docs/en/about-claude/models/overview

Anthropic's stated default: start with **Claude Opus 5** for complex agentic coding and enterprise work; use **Claude Fable 5** when the workload needs the highest available capability.

All current Claude models support text and image input, text output, multilingual use, and vision. Available via the Claude API, Amazon Bedrock, Claude Platform on AWS, Google Cloud (Vertex / Agent Platform), and Microsoft Foundry.

| Feature | Claude Fable 5 | Claude Opus 5 | Claude Sonnet 5 | Claude Haiku 4.5 |
|---|---|---|---|---|
| Description | Next-generation intelligence for long-running agents | Complex agentic coding and enterprise work | Best combination of speed and intelligence | Fastest model with near-frontier intelligence |
| Claude API ID / alias | `claude-fable-5` | `claude-opus-5` | `claude-sonnet-5` | `claude-haiku-4-5-20251001` (alias `claude-haiku-4-5`) |
| AWS Bedrock ID | `anthropic.claude-fable-5` | `anthropic.claude-opus-5` | `anthropic.claude-sonnet-5` | `anthropic.claude-haiku-4-5-20251001-v1:0` |
| Google Cloud ID | `claude-fable-5` | `claude-opus-5` | `claude-sonnet-5` | `claude-haiku-4-5@20251001` |
| Price in/out per MTok | $10 / $50 | $5 / $25 | $3 / $15 (introductory $2/$10 through Aug 31 2026) | $1 / $5 |
| Extended thinking (`thinking.type: "enabled"`) | No | No | No | Yes |
| Adaptive thinking | Yes (always on) | Yes | Yes | No |
| Comparative latency | Slower | Moderate | Fast | Fastest |
| Context window | 1M | 1M | 1M | 200k |
| Max output | 128k | 128k | 128k | 64k |
| Reliable knowledge cutoff | Jan 2026 | May 2026 | Jan 2026 | Feb 2025 |
| Training data cutoff | Jan 2026 | May 2026 | Jan 2026 | Jul 2025 |

**Fable 5 / Mythos 5 access.** Fable 5 (`claude-fable-5`) is Anthropic's most capable *widely released* model, GA on the Claude API, Amazon Bedrock, Claude Platform on AWS, Google Cloud, and Microsoft Foundry since **June 9, 2026**. Mythos 5 (`claude-mythos-5`) shares Fable 5's specs and pricing but is **limited availability only** — invitation-only Project Glasswing, requiring an Anthropic, AWS, or Google Cloud account team. `claude-mythos-preview` is the deprecated preview tier; migrate to `claude-mythos-5`.

Additional facts from the same page:

- **Every Claude model ID is a pinned snapshot.** Dated IDs (`…-20250929`) are fixed releases; from the 4.6 generation onward IDs use a dateless format that is *also* pinned, not an evergreen pointer.
- Fable 5's context tooltip: "~555k words / ~2.5M unicode characters." Fable 5 uses the tokenizer introduced with Opus 4.7 — the same text produces roughly **30% more tokens** than pre-4.7 models.
- **300k output beta:** Opus 5, Opus 4.8, Opus 4.7, Opus 4.6, Sonnet 5, and Sonnet 4.6 support up to 300k output tokens on the Message Batches API via the `output-300k-2026-03-24` beta header.
- **`effort` defaults:** on Opus 4.8 it defaults to `high` everywhere (API, Claude Code, claude.ai); on Opus 5 and Sonnet 5 it defaults to `high` on the Claude API and Claude Code only. Set it explicitly elsewhere.
- **Models API:** `GET /v1/models` returns `max_input_tokens`, `max_tokens`, and a `capabilities` object per model — the authoritative programmatic source.
- **Deprecated request parameters:** `temperature`, `top_p`, `top_k` return a **400 error** on any non-default value for Claude Opus 4.7 and later, and for Claude Mythos Preview. Use prompting instead.

### Legacy models (still available, migration recommended)

| Feature | Opus 4.8 | Opus 4.7 | Opus 4.6 | Sonnet 4.6 | Sonnet 4.5 | Opus 4.5 |
|---|---|---|---|---|---|---|
| Claude API ID | `claude-opus-4-8` | `claude-opus-4-7` | `claude-opus-4-6` | `claude-sonnet-4-6` | `claude-sonnet-4-5-20250929` | `claude-opus-4-5-20251101` |
| AWS Bedrock ID | `anthropic.claude-opus-4-8` | `anthropic.claude-opus-4-7` | `anthropic.claude-opus-4-6-v1` | `anthropic.claude-sonnet-4-6` | `anthropic.claude-sonnet-4-5-20250929-v1:0` | `anthropic.claude-opus-4-5-20251101-v1:0` |
| Google Cloud ID | `claude-opus-4-8` | `claude-opus-4-7` | `claude-opus-4-6` | `claude-sonnet-4-6` | `claude-sonnet-4-5@20250929` | `claude-opus-4-5@20251101` |
| Price in/out per MTok | $5/$25 | $5/$25 | $5/$25 | $3/$15 | $3/$15 | $5/$25 |
| Extended thinking | No | No | Yes (deprecated) | Yes (deprecated) | Yes | Yes |
| Adaptive thinking | Yes | Yes | Yes | Yes | No | No |
| Context window | 1M | 1M | 1M | 1M | 200k | 200k |
| Max output | 128k | 128k | 128k | 128k | 64k | 64k |
| Reliable knowledge cutoff | Jan 2026 | Jan 2026 | May 2025 | Aug 2025 | Jan 2025 | May 2025 |
| Training data cutoff | Jan 2026 | Jan 2026 | Aug 2025 | Jan 2026 | Jul 2025 | Aug 2025 |

## Pricing detail

> Source: https://platform.claude.com/docs/en/about-claude/pricing

Per million tokens, USD:

| Model | Base input | 5m cache write | 1h cache write | Cache hit/refresh | Output |
|---|---|---|---|---|---|
| Claude Fable 5 | $10 | $12.50 | $20 | $1 | $50 |
| Claude Mythos 5 (limited availability) | $10 | $12.50 | $20 | $1 | $50 |
| Claude Opus 5 | $5 | $6.25 | $10 | $0.50 | $25 |
| Claude Opus 4.8 | $5 | $6.25 | $10 | $0.50 | $25 |
| Claude Opus 4.7 | $5 | $6.25 | $10 | $0.50 | $25 |
| Claude Opus 4.6 | $5 | $6.25 | $10 | $0.50 | $25 |
| Claude Opus 4.5 | $5 | $6.25 | $10 | $0.50 | $25 |
| Claude Opus 4.1 (retired except Bedrock/GCP) | $15 | $18.75 | $30 | $1.50 | $75 |
| Claude Opus 4 (retired except GCP) | $15 | $18.75 | $30 | $1.50 | $75 |
| Claude Sonnet 5 (through Aug 31 2026) | $2 | $2.50 | $4 | $0.20 | $10 |
| Claude Sonnet 5 (from Sep 1 2026) | $3 | $3.75 | $6 | $0.30 | $15 |
| Claude Sonnet 4.6 | $3 | $3.75 | $6 | $0.30 | $15 |
| Claude Sonnet 4.5 | $3 | $3.75 | $6 | $0.30 | $15 |
| Claude Sonnet 4 (retired except Bedrock/GCP) | $3 | $3.75 | $6 | $0.30 | $15 |
| Claude Haiku 4.5 | $1 | $1.25 | $2 | $0.10 | $5 |
| Claude Haiku 3.5 (retired except Bedrock/GCP) | $0.80 | $1 | $1.60 | $0.08 | $4 |

Sonnet 5 introductory pricing ($2/$10) runs **through August 31, 2026**; standard pricing ($3/$15) starts **September 1, 2026**. Claude 4.7+ models and Claude Mythos Preview use the newer tokenizer producing ~30% more tokens for the same text than Sonnet 4.6 and earlier.

### Prompt caching multipliers (relative to base input)

| Cache operation | Multiplier | Duration |
|---|---|---|
| 5-minute cache write | 1.25x base input | Valid 5 minutes |
| 1-hour cache write | 2x base input | Valid 1 hour |
| Cache read (hit) | 0.1x base input | Same duration as the preceding write |

Caching pays off after **one** cache read on the 5-minute tier (1.25x write) or **two** reads on the 1-hour tier (2x write). Multipliers stack with the Batch API discount and the data-residency multiplier.

### Batch API (50% off input and output)

| Model | Batch input | Batch output |
|---|---|---|
| Claude Fable 5 / Mythos 5 | $5 | $25 |
| Claude Opus 5 / 4.8 / 4.7 / 4.6 / 4.5 | $2.50 | $12.50 |
| Claude Opus 4.1 (retired) | $7.50 | $37.50 |
| Claude Opus 4 (retired) | $7.50 | $37.50 |
| Claude Sonnet 5 (through Aug 31 2026) | $1 | $5 |
| Claude Sonnet 5 (from Sep 1 2026) / 4.6 / 4.5 | $1.50 | $7.50 |
| Claude Sonnet 4 (retired) | $1.50 | $7.50 |
| Claude Haiku 4.5 | $0.50 | $2.50 |
| Claude Haiku 3.5 (retired) | $0.40 | $2 |

### Long context, data residency, fast mode

- **Long context:** Claude 4.6+ models and Claude Mythos Preview include the full 1M-token window at **standard pricing** — a 900k-token request costs the same per-token rate as a 9k-token one. Caching and batch discounts apply across the full window.
- **Data residency:** on Claude 4.6+, `inference_geo: "us"` applies a **1.1x multiplier** to every token category (input, output, cache writes and reads). Global routing (`inference_geo: "global"`, the default) is standard price. Earlier models reject the parameter with a 400.
- **Fast mode** (research preview, **Opus 5 and Opus 4.8 only**): $10/MTok input, $50/MTok output across the full context window. First-party API only — not Bedrock, not Google Cloud, not Claude Platform on AWS. Not available with the Batch API. Stacks with caching and data-residency multipliers. Errors on Opus 4.7; runs at standard speed and price on Opus 4.6.

### Tool-use token overhead

System-prompt tokens added by tool definitions, on top of normal input/output:

| Model | `auto` / `none` | `any` / `tool` |
|---|---|---|
| Opus 5 | 286 | 406 |
| Opus 4.8 | 290 | 410 |
| Opus 4.7 | 675 | 804 |
| Opus 4.6 | 497 | 589 |
| Opus 4.5 | 496 | 588 |
| Sonnet 5 | 354 | 474 |
| Sonnet 4.6 | 497 | 589 |
| Sonnet 4.5 | 496 | 588 |
| Haiku 4.5 | 496 | 588 |

Server tool pricing: **web search** $10 per 1,000 searches plus standard token costs; **web fetch** free beyond token costs; **code execution** free when paired with `web_search_20260209`+ or `web_fetch_20260209`+ tools, otherwise billed by execution time (5-minute minimum, 1,550 free org-hours/month, then $0.05/hour/container).

### Worked cost examples

- Claude Managed Agents, Opus 5, one-hour session, 50,000 input + 15,000 output tokens, no caching: input $0.25 + output $0.375 + session runtime (1 hr × $0.08) = **$0.705**. With 40,000 of the input tokens served as cache reads: **$0.525**.
- Support tickets at ~3,700 tokens per conversation on Haiku 4.5: **≈$37.00 per 10,000 tickets**.

### Anthropic's own cost-optimization guidance

1. Match model to task — Haiku for simple work, Sonnet for most production workloads, Opus for the most complex reasoning.
2. Use prompt caching for repeated context.
3. Batch non-time-sensitive operations.
4. Monitor usage patterns to find optimization opportunities.

## Sources

- https://platform.claude.com/docs/en/about-claude/models/overview
- https://platform.claude.com/docs/en/about-claude/pricing

Fetched: 2026-08-05
