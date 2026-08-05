# Model Generation: Claude 4.5 and Earlier

Covers Opus 4.5 (`claude-opus-4-5-20251101`), Sonnet 4.5 (`claude-sonnet-4-5-20250929`), Haiku 4.5 (`claude-haiku-4-5-20251001`), and the retired Opus 4.1 / Opus 4 / Sonnet 4 / Haiku 3.5. Read when maintaining an older integration or planning a migration off one.

## Capability envelope

> Source: https://platform.claude.com/docs/en/about-claude/models/overview

- Context **200k**, max output **64k** on Opus 4.5, Sonnet 4.5, and Haiku 4.5 — a quarter of the 1M/128k envelope on 4.6+. Prompts designed for 1M context do not port down.
- Model IDs are dated snapshots; the dateless aliases `claude-opus-4-5`, `claude-sonnet-4-5`, `claude-haiku-4-5` map to them.
- Opus 4.1 is retired except on Bedrock and Google Cloud; Opus 4 is retired except on Google Cloud; Haiku 3.5 is retired except on Bedrock and Google Cloud.
- Uses the pre-4.7 tokenizer — token counts are roughly **30% lower** than Fable 5 / Mythos 5 / Opus 4.7+ for identical text.

## Thinking

> Source: https://platform.claude.com/docs/en/build-with-claude/extended-thinking

Manual extended thinking (`thinking: {"type": "enabled", "budget_tokens": N}`) is the **only** available mode on this generation. Adaptive thinking does not exist here.

Interleaved thinking requires beta header `interleaved-thinking-2025-05-14` on Opus 4.5, Sonnet 4.5, Opus 4.1, Opus 4, and Sonnet 4. **Haiku 4.5 does not support interleaved thinking** — the header is accepted and silently ignored.

Thinking-block preservation across turns splits within the generation: **Opus 4.5 keeps and bills** prior turns' thinking blocks as input, while Sonnet 4.5, Haiku 4.5, and earlier **strip** them.

## Effort

> Source: https://platform.claude.com/docs/en/build-with-claude/effort

`output_config.effort` is supported on **Opus 4.5 only** in this generation. On Opus 4.5, effort and `budget_tokens` are independent controls — set both. Sonnet 4.5, Haiku 4.5, and earlier models have no effort parameter.

## Caching

> Source: https://platform.claude.com/docs/en/build-with-claude/prompt-caching

Minimum cacheable prompt: **1,024** tokens on Sonnet 4.5; **4,096** on Opus 4.5 and Haiku 4.5; **2,048** on Haiku 3.5. These are far above the 512-token floor on Opus 5 / Fable 5, so short system prompts that cache on newer models will silently fail to cache here.

**Haiku 3.5 is the only model that counts `cache_read_input_tokens` toward ITPM** — caching does not buy throughput headroom there, only cost savings.

## Streaming interruption recovery

> Source: https://platform.claude.com/docs/en/build-with-claude/streaming

On 4.5 and earlier, resume an interrupted stream by re-sending the captured partial content as the start of a new **`assistant`** message. (4.6+ requires the user-message form instead.)

## Tools

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool
> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool
> Source: https://platform.claude.com/docs/en/about-claude/pricing

- Computer use beta header is **`computer-use-2025-01-24`** on Sonnet 4.5, Haiku 4.5, Opus 4.1, Sonnet 4, and Opus 4. `computer_20251124` and its `zoom` action are not available; `computer_20250124` enhanced actions are.
- Tool search works on Opus 4.5, Sonnet 4.5, and Haiku 4.5. **Opus 4.1 and earlier do not support it.**
- Tool-use system prompt overhead: ~496–497 (`auto`/`none`) / ~588–589 (`any`/`tool`) on Opus 4.5 and Haiku 4.5; 313/315 on Opus 4.1, Opus 4, and Sonnet 4; 264/355 on Haiku 3.5.
- Bash tool overhead is +244 input tokens per definition on this generation.

## Not available on this generation

> Source: https://platform.claude.com/docs/en/about-claude/pricing
> Source: https://platform.claude.com/docs/en/build-with-claude/batch-processing

- `inference_geo` — passing it returns 400 on pre-4.6 models.
- The 1M-context-at-standard-pricing arrangement (4.6+ and Mythos Preview only).
- Fast mode (Opus 5 / Opus 4.8 only).
- The `output-300k-2026-03-24` batch extended-output beta (Opus 5/4.8/4.7/4.6 and Sonnet 5/4.6 only).
- Structured outputs are supported on Opus 4.5, Sonnet 4.5, and Haiku 4.5 — but **not** on Opus 4.1 or earlier.

## Sources

- https://platform.claude.com/docs/en/about-claude/models/overview
- https://platform.claude.com/docs/en/about-claude/pricing
- https://platform.claude.com/docs/en/build-with-claude/extended-thinking
- https://platform.claude.com/docs/en/build-with-claude/effort
- https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- https://platform.claude.com/docs/en/build-with-claude/streaming
- https://platform.claude.com/docs/en/build-with-claude/batch-processing
- https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool

Fetched: 2026-08-05
