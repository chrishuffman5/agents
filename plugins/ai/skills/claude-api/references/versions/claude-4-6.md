# Model Generation: Claude 4.6

Covers Opus 4.6 (`claude-opus-4-6`) and Sonnet 4.6 (`claude-sonnet-4-6`). This is the transitional generation: both thinking modes work, but the manual one is already deprecated. Read when supporting a codebase that straddles the manual/adaptive boundary.

## Capability envelope

> Source: https://platform.claude.com/docs/en/about-claude/models/overview

- Context **1M**, max output **128k**.
- Dateless IDs are **pinned snapshots** starting with this generation — `claude-opus-4-6` will not silently become a newer model.
- Still on the pre-4.7 tokenizer, so token counts stay comparable to 4.5 and are ~30% lower than Fable 5 / Opus 4.7+.

## Thinking — both modes, one deprecated

> Source: https://platform.claude.com/docs/en/build-with-claude/extended-thinking

Manual `thinking: {"type": "enabled"}` still **works** but is **deprecated** here; it becomes a 400 on 4.7+. Treat 4.6 as the last chance to migrate rather than a stable target.

Interleaving differs sharply by model and mode:

| Model | Manual mode | Adaptive mode |
|---|---|---|
| Sonnet 4.6 | `interleaved-thinking-2025-05-14` still works, deprecated | Auto-interleaves, no header |
| Opus 4.6 | **No interleaved thinking at all** | Auto-interleaves |

Opus 4.6 in manual mode losing interleaving entirely is the trap — a tool-heavy agent that relied on interleaved thinking on 4.5 will quietly stop interleaving until it moves to adaptive.

Both 4.6 models keep and bill prior turns' thinking blocks as input (like Opus 4.5, unlike Sonnet 4.5 and Haiku 4.5).

## Effort

> Source: https://platform.claude.com/docs/en/build-with-claude/effort

`output_config.effort` is supported on both Opus 4.6 and Sonnet 4.6, no beta header, default `high`. `max` is supported; **`xhigh` is not** on this generation (it starts at Opus 4.7 / Sonnet 5 / Fable 5 / Mythos 5).

For computer use specifically, `medium` is the recommended default on Sonnet 4.6 and Opus 4.6 — it has the best accuracy-to-cost ratio, and `max` adds cost without accuracy gain on UI tasks.

## Pricing behavior new in 4.6

> Source: https://platform.claude.com/docs/en/about-claude/pricing

- The **full 1M-token window bills at standard per-token rates** on 4.6+ and Mythos Preview. No long-context surcharge.
- `inference_geo` becomes available: `"us"` applies a **1.1x** multiplier to every token category; `"global"` (default) is standard. Earlier models 400 on the parameter.
- Base rates: Opus 4.6 at $5/$25 per MTok; Sonnet 4.6 at $3/$15.

## Caching

> Source: https://platform.claude.com/docs/en/build-with-claude/prompt-caching

Minimum cacheable prompt: **4,096** tokens on Opus 4.6, **1,024** on Sonnet 4.6. Opus 4.6's high floor means moderate system prompts silently fail to cache — check `cache_creation_input_tokens`.

## Streaming interruption recovery changes here

> Source: https://platform.claude.com/docs/en/build-with-claude/streaming

From 4.6 onward, resume an interrupted stream by putting the captured partial content in a **`user`** message instructing continuation ("Your previous response was interrupted and ended with [previous_response]. Continue from where you left off."), not by replaying it as an assistant prefix. Code written for 4.5 must be updated at this boundary.

## Tools

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool
> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool
> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-fetch-tool
> Source: https://platform.claude.com/docs/en/about-claude/pricing

- Computer use beta header is **`computer-use-2025-11-24`**, and `computer_20251124` with `enable_zoom` is available.
- Web search **dynamic filtering** (`web_search_20260209`+) requires Claude 4.6 or newer — this generation is the floor for it. Web fetch dynamic filtering likewise covers Opus 4.6 and Sonnet 4.6.
- Tool search is supported on both models.
- Tool-use system prompt overhead ~496–497 (`auto`/`none`) / ~588–589 (`any`/`tool`); bash tool +244 input tokens per definition.
- Advisor tool: Sonnet 4.6 is the **minimum-capability advisor**; both 4.6 models can act as executor or advisor within the compatibility matrix in `../advisor-tool.md`.

## Batch and output

> Source: https://platform.claude.com/docs/en/build-with-claude/batch-processing

Opus 4.6 and Sonnet 4.6 support the **300k output token** batch beta (`output-300k-2026-03-24`) — batch-only, not on synchronous Messages.

Fast mode does **not** apply: on Opus 4.6 the `speed` parameter runs at standard speed and standard pricing rather than erroring, so a Fast-mode config silently does nothing here.

## Sources

- https://platform.claude.com/docs/en/about-claude/models/overview
- https://platform.claude.com/docs/en/about-claude/pricing
- https://platform.claude.com/docs/en/build-with-claude/extended-thinking
- https://platform.claude.com/docs/en/build-with-claude/effort
- https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- https://platform.claude.com/docs/en/build-with-claude/streaming
- https://platform.claude.com/docs/en/build-with-claude/batch-processing
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-fetch-tool
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

Fetched: 2026-08-05
