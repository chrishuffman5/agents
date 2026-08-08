# Model Generation: Claude 4.7 and Later

Covers Opus 4.7 (`claude-opus-4-7`), Opus 4.8 (`claude-opus-4-8`), Opus 5 (`claude-opus-5`), Sonnet 5 (`claude-sonnet-5`), Fable 5 (`claude-fable-5`), and Mythos 5 (`claude-mythos-5`, invitation-only). Read before targeting any of these — several parameters that worked on 4.6 now hard-fail.

## Breaking changes from 4.6

> Source: https://platform.claude.com/docs/en/build-with-claude/extended-thinking
> Source: https://platform.claude.com/docs/en/about-claude/models/overview

1. **Manual extended thinking is rejected.** `thinking: {"type": "enabled"}` returns **400**. Only adaptive thinking exists. Migrate to `{"type": "adaptive"}` plus `output_config.effort`.
2. **New tokenizer.** Opus 4.7+, Fable 5, and Mythos 5 produce **~30% more tokens** for the same text than pre-4.7 models. Every cost model, context budget, and truncation threshold must be recomputed with `count_tokens` against the target model.
3. `interleaved-thinking-2025-05-14` is unnecessary — adaptive thinking auto-interleaves and the header is ignored.

## Capability envelope

> Source: https://platform.claude.com/docs/en/about-claude/models/overview

All models in this generation: **1M context, 128k max output**, adaptive thinking (always on for Fable 5 and Mythos 5). Dateless IDs are pinned snapshots.

Reliable knowledge cutoffs: Opus 5 May 2026; Sonnet 5 and Fable 5 Jan 2026.

## Effort

> Source: https://platform.claude.com/docs/en/build-with-claude/effort

`effort` defaults to `high` throughout (on Opus 4.8 that default holds across API, Claude Code, and claude.ai; on Opus 5 and Sonnet 5 across API and Claude Code).

`xhigh` — extended capability for long-horizon agentic work (>30 minutes, million-token budgets) — is available on Fable 5, Mythos 5, Opus 5, Opus 4.8, Opus 4.7, and Sonnet 5. `max` is available on Opus 5/4.8/4.7, Sonnet 5, Fable 5, and Mythos 5.

Generation-specific behaviors:

- On **Opus 5**, thinking **cannot be disabled** at `xhigh` or `max` — `thinking: {"type": "disabled"}` at those levels returns 400.
- On **Opus 5**, effort does not reliably shorten visible response length; prompt for length separately.
- Running `xhigh`/`max` on Opus 4.7/4.8/5 requires a large `max_tokens` (64k+ starting point) so thinking and tool calls have room.
- Recommended starting points: Opus 4.7/4.8 `xhigh` for coding/agentic work with `high` as the floor elsewhere; Opus 5 `high`, stepping up for demanding work; Sonnet 5 `high`, `xhigh` for the hardest tasks, `medium` for cost savings, `low` for latency-sensitive chat.

## Pricing

> Source: https://platform.claude.com/docs/en/about-claude/pricing

- Opus 5, Opus 4.8, Opus 4.7: $5 input / $25 output per MTok.
- Sonnet 5: $2/$10 introductory **through Aug 31, 2026**, then $3/$15.
- Fable 5 and Mythos 5: $10/$50 — twice Opus 5, so treat Fable 5 as a premium tier, not a drop-in.
- Full 1M window at standard per-token rates; `inference_geo: "us"` applies 1.1x.
- **Fast mode** (research preview, API-only) reprices Opus 5 and Opus 4.8 to $10/$50 per MTok across the full window. Not available with the Batch API. It **errors on Opus 4.7**.

Tool-use system prompt overhead varies unusually within this generation — Opus 4.7 is by far the most expensive: 675 (`auto`/`none`) / 804 (`any`/`tool`), versus Opus 5 at 286/406, Opus 4.8 at 290/410, and Sonnet 5 at 354/474. Bash tool overhead is **+325** per definition on Opus 5/4.8/4.7 (up from +244 earlier).

## Caching

> Source: https://platform.claude.com/docs/en/build-with-claude/prompt-caching

Minimum cacheable prompt: **512** on Opus 5, Fable 5, and Mythos 5; **1,024** on Opus 4.8 and Sonnet 5; **2,048** on Opus 4.7. These floors are lower than 4.6's, so more prompts cache — but a prompt tuned to Opus 4.7's 2,048 floor is not automatically portable downward.

## Rate limits

> Source: https://platform.claude.com/docs/en/api/rate-limits

**Fable 5 has materially lower ITPM/OTPM than Opus 5 at every tier** (Start 500k/100k vs 2M/400k; Build 1.5M/300k vs 5M/1M; Scale 4M/800k vs 10M/2M). Do not plan Fable 5 throughput by analogy to Opus 5.

Opus 4.8/4.7 share a **combined** Opus 4.x bucket with Opus 4.6/4.5; Opus 5 and Sonnet 5 each get their own bucket.

## Tools

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool
> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-fetch-tool
> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool
> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool

- Computer use: beta header `computer-use-2025-11-24` on Opus 5, Sonnet 5, Opus 4.8, and Opus 4.7. These models accept screenshots up to **2576 px** on the long edge (versus 1568 px earlier), so less downscaling and better click precision. Opus 4.7 closes most of the precision gap to Sonnet 4.6.
- Web fetch dynamic filtering (`web_fetch_20260209`+) covers Fable 5, Opus 4.8, Mythos 5, Mythos Preview, Opus 4.7, and Sonnet 5.
- Tool search is supported on Fable 5, Mythos 5, Opus 5, Opus 4.8, and Opus 4.7.
- Advisor: Opus 5, Fable 5, and Mythos 5 return **encrypted** `advisor_redacted_result` — use `claude-opus-4-8` as the advisor when your client needs plaintext. Advisor choices narrow as the executor gets stronger (Opus 5 may only be advised by Mythos 5, Fable 5, or Opus 5; Fable 5 only by Fable 5 or Opus 5).
- Structured outputs are supported across `claude-opus-5`, `claude-opus-4-8`, `claude-opus-4-7`, `claude-sonnet-5`, and `claude-mythos-5`.

## Batch

> Source: https://platform.claude.com/docs/en/build-with-claude/batch-processing

Opus 5/4.8/4.7 and Sonnet 5 support **300k output tokens** in batches via `output-300k-2026-03-24` (batch-only). A single 300k generation can exceed an hour — plan against the 24-hour batch window.

## Sources

- https://platform.claude.com/docs/en/about-claude/models/overview
- https://platform.claude.com/docs/en/about-claude/pricing
- https://platform.claude.com/docs/en/build-with-claude/extended-thinking
- https://platform.claude.com/docs/en/build-with-claude/effort
- https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- https://platform.claude.com/docs/en/build-with-claude/batch-processing
- https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- https://platform.claude.com/docs/en/api/rate-limits
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-fetch-tool
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

Fetched: 2026-08-05
