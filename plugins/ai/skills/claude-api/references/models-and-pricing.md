# Models, Context Windows, and Pricing

All figures are a snapshot of Anthropic's docs on 2026-08-05. Prices and lineups move — re-verify against the source URLs before using these in a budget or contract.

## Current model lineup

> Source: https://platform.claude.com/docs/en/about-claude/models/overview

| Model | Claude API ID (= alias) | AWS Bedrock ID | Google Cloud ID | Context | Max output | Extended thinking (`type:"enabled"`) | Adaptive thinking | Reliable knowledge cutoff | Training cutoff |
|---|---|---|---|---|---|---|---|---|---|
| Claude Fable 5 | `claude-fable-5` | `anthropic.claude-fable-53` | `claude-fable-5` | 1M | 128k | No | Yes (always on) | Jan 2026 | Jan 2026 |
| Claude Mythos 5 (invitation-only, Project Glasswing) | `claude-mythos-5` | — | — | 1M | 128k | No | Yes (always on) | — | — |
| Claude Opus 5 | `claude-opus-5` | `anthropic.claude-opus-53` | `claude-opus-5` | 1M | 128k | No | Yes | May 2026 | May 2026 |
| Claude Sonnet 5 | `claude-sonnet-5` | `anthropic.claude-sonnet-53` | `claude-sonnet-5` | 1M | 128k | No | Yes | Jan 2026 | Jan 2026 |
| Claude Haiku 4.5 | `claude-haiku-4-5-20251001` (alias `claude-haiku-4-5`) | `anthropic.claude-haiku-4-5-20251001-v1:0` | `claude-haiku-4-5@20251001` | 200k | 64k | Yes | No | Feb 2025 | Jul 2025 |

Legacy but still available:

| Model | Claude API ID | Context | Max output | Extended thinking | Adaptive thinking |
|---|---|---|---|---|---|
| Claude Opus 4.8 | `claude-opus-4-8` | 1M | 128k | No | Yes |
| Claude Opus 4.7 | `claude-opus-4-7` | 1M | 128k | No | Yes |
| Claude Opus 4.6 | `claude-opus-4-6` | 1M | 128k | Yes (deprecated) | Yes |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` | 1M | 128k | Yes (deprecated) | Yes |
| Claude Sonnet 4.5 | `claude-sonnet-4-5-20250929` (alias `claude-sonnet-4-5`) | 200k | 64k | Yes | No |
| Claude Opus 4.5 | `claude-opus-4-5-20251101` (alias `claude-opus-4-5`) | 200k | 64k | Yes | No |
| Claude Opus 4.1 | retired except Bedrock / Google Cloud | — | — | — | — |
| Claude Opus 4 | retired except Google Cloud | — | — | — | — |
| Claude Haiku 3.5 | retired except Bedrock / Google Cloud | — | — | — | — |

Rules that follow from the table:

- Every model ID is a **pinned snapshot**. Dated IDs are obviously fixed; from Claude 4.6 onward the *dateless* IDs are pinned too. There is no evergreen "latest" pointer.
- Fable 5 / Mythos 5 / Opus 4.7+ use a newer tokenizer producing **~30% more tokens** for the same text than pre-4.7 models. Recount; never carry old estimates across that boundary.
- `effort` defaults to `high` on Opus 4.8 everywhere (API, Claude Code, claude.ai) and on Opus 5 / Sonnet 5 on the API and Claude Code.
- Max output above is the **synchronous** ceiling. On the Message Batches API, Opus 5/4.8/4.7/4.6 and Sonnet 5/4.6 reach **300k output tokens** with beta header `output-300k-2026-03-24`.
- `GET /v1/models` returns `max_input_tokens`, `max_tokens`, and `capabilities` — prefer it to hardcoding.
- Bedrock offers global and regional endpoints for Sonnet 4.5+ (incl. 4.6); Google Cloud offers global, multi-region, and regional.
- "Claude Platform on AWS" uses **Claude API model IDs**, not Bedrock-style IDs, and follows Anthropic's deprecation schedule rather than Bedrock's.

## Base pricing (per MTok, USD)

> Source: https://platform.claude.com/docs/en/about-claude/pricing

| Model | Base input | 5m cache write | 1h cache write | Cache hit/refresh | Output |
|---|---|---|---|---|---|
| Claude Fable 5 | $10 | $12.50 | $20 | $1 | $50 |
| Claude Mythos 5 | $10 | $12.50 | $20 | $1 | $50 |
| Claude Opus 5 | $5 | $6.25 | $10 | $0.50 | $25 |
| Claude Opus 4.8 / 4.7 / 4.6 / 4.5 | $5 | $6.25 | $10 | $0.50 | $25 |
| Claude Opus 4.1 (retired) | $15 | $18.75 | $30 | $1.50 | $75 |
| Claude Opus 4 (retired) | $15 | $18.75 | $30 | $1.50 | $75 |
| Claude Sonnet 5 (through Aug 31, 2026 — introductory) | $2 | $2.50 | $4 | $0.20 | $10 |
| Claude Sonnet 5 (from Sep 1, 2026) | $3 | $3.75 | $6 | $0.30 | $15 |
| Claude Sonnet 4.6 / 4.5 | $3 | $3.75 | $6 | $0.30 | $15 |
| Claude Sonnet 4 (retired) | $3 | $3.75 | $6 | $0.30 | $15 |
| Claude Haiku 4.5 | $1 | $1.25 | $2 | $0.10 | $5 |
| Claude Haiku 3.5 (retired) | $0.80 | $1 | $1.60 | $0.08 | $4 |

Sonnet 5's introductory rate expires **Aug 31, 2026** — model any Sonnet 5 budget past that date at $3/$15.

**Long context is not surcharged.** Claude 4.6+ and Mythos Preview include the full 1M-token window at standard per-token pricing; caching and batch discounts apply across the whole window.

### Batch pricing (50% off base)

| Model | Batch input | Batch output |
|---|---|---|
| Claude Fable 5 / Mythos 5 | $5 | $25 |
| Claude Opus 5 / 4.8 / 4.7 / 4.6 / 4.5 | $2.50 | $12.50 |
| Claude Opus 4.1 / 4 (retired) | $7.50 | $37.50 |
| Claude Sonnet 5 (through Aug 31, 2026) | $1 | $5 |
| Claude Sonnet 5 (from Sep 1, 2026) / 4.6 / 4.5 / 4 | $1.50 | $7.50 |
| Claude Haiku 4.5 | $0.50 | $2.50 |
| Claude Haiku 3.5 (retired) | $0.40 | $2 |

### Fast mode (research preview, API-only)

| Model | Input | Output |
|---|---|---|
| Claude Opus 5 / Opus 4.8 | $10/MTok | $50/MTok |

Applies across the full context window, including >200k input. **Not available with the Batch API.** Errors on Opus 4.7; on Opus 4.6 it silently runs at standard speed and price. Stacks with caching and data-residency multipliers.

### Multipliers

| Multiplier | Value | Applies to |
|---|---|---|
| Batch API | 0.5x | input + output |
| 5-minute cache write | 1.25x base input | write only |
| 1-hour cache write | 2x base input | write only |
| Cache read (hit) | 0.1x base input | read only |
| `inference_geo: "us"` | 1.1x | every token category, Claude 4.6+ only (400 on earlier models) |

The 1.1x US data-residency multiplier also applies to Microsoft Foundry's US Data Zone Standard deployment. Multipliers stack.

## Tool token overhead

> Source: https://platform.claude.com/docs/en/about-claude/pricing

Added to input tokens whenever at least one tool is supplied:

| Model | `tool_choice: auto/none` | `tool_choice: any/tool` |
|---|---|---|
| Claude Opus 5 | 286 | 406 |
| Claude Opus 4.8 | 290 | 410 |
| Claude Opus 4.7 | 675 | 804 |
| Claude Opus 4.6 / Sonnet 4.6 / Haiku 4.5 / Opus 4.5 | ~496–497 | ~588–589 |
| Claude Sonnet 5 | 354 | 474 |
| Claude Opus 4.1 / 4 / Sonnet 4 (retired) | 313 | 315 |
| Claude Haiku 3.5 (retired) | 264 | 355 |

Per-tool costs on top of that overhead:

- **Bash tool**: +325 input tokens/definition on Opus 5/4.8/4.7; +244 on Opus 4.6, Sonnet 4.6 and earlier.
- **Text editor tool** (`text_editor_20250429`, Claude 4.x): +700 input tokens.
- **Computer use tool**: 735 input tokens per definition on Claude 4.x, plus 466–499 tokens of system prompt overhead, plus screenshot image and tool-result tokens.
- **Web search**: **$10 per 1,000 searches** plus standard token costs. One search = one use regardless of result count; errored searches are not billed.
- **Web fetch**: no surcharge beyond tokens. Sizing: ~10 kB page ≈ 2,500 tokens; ~100 kB doc ≈ 25,000; ~500 kB PDF ≈ 125,000. Cap with `max_content_tokens`.
- **Code execution**: free alongside `web_search_20260209`+ or `web_fetch_20260209`+. Standalone, billed by execution time with a 5-minute minimum, **1,550 free hours/org/month**, then **$0.05/hour/container**. Attaching files bills execution time even if the tool is never called, because files preload onto the container.

## Claude Platform on AWS billing

> Source: https://platform.claude.com/docs/en/about-claude/pricing

Bills through AWS/Azure Marketplace in **Claude Consumption Units**: token usage is rated in USD at standard per-model/feature rates, discounts are applied, then converted at **$0.01/CCU** and reported hourly. Postpaid only, no prepaid credits. `inference_geo: "us"` applies its 1.1x before CCU conversion.

## Worked cost example

> Source: https://platform.claude.com/docs/en/about-claude/pricing

Claude Managed Agents, Opus 5, one hour, 50k input / 15k output:

- Input: 50,000 × $5/1M = $0.25
- Output: 15,000 × $25/1M = $0.375
- Session runtime: 1.0 hr × $0.08/hr = $0.08
- **Total $0.705** with no caching.

With 40k of the 50k input served from cache: input $0.05 + cache read $0.02 + output $0.375 + runtime $0.08 = **$0.525** — a 26% cut from caching alone.

## Spend caps

> Source: https://platform.claude.com/docs/en/about-claude/pricing

Monthly spend caps by tier: Start $500, Build $1,000, Scale $200,000, Custom negotiated (no cap). Rate-limit tables are in `rate-limits-and-token-counting.md`.

## Sources

- https://platform.claude.com/docs/en/about-claude/models/overview
- https://platform.claude.com/docs/en/about-claude/pricing

Fetched: 2026-08-05
