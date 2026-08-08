# Extended Thinking, Adaptive Thinking, and `effort`

Read when configuring reasoning depth or migrating a thinking-enabled integration to a newer model.

## Manual extended thinking

> Source: https://platform.claude.com/docs/en/build-with-claude/extended-thinking

`thinking: {"type": "enabled", "budget_tokens": N}` is the legacy mode. It is **deprecated on Claude 4.6** (still functional) and **rejected with 400 on Claude 4.7 and later** — Opus 4.7/4.8/5, Sonnet 5, Fable 5, Mythos 5 support adaptive thinking only. On Claude 4.5 and earlier thinking-capable models, manual mode is the **only** mode. Claude Mythos Preview supports both.

```json
{
  "model": "claude-sonnet-4-6",
  "max_tokens": 16000,
  "thinking": {"type": "enabled", "budget_tokens": 10000},
  "messages": [{"role": "user", "content": "Are there an infinite number of prime numbers such that n mod 4 == 3?"}]
}
```

Responses contain `thinking` content blocks (each with a `signature`) interleaved before and among `text` blocks.

### `budget_tokens` rules

- Minimum **1,024**; the API rejects lower.
- Must be **less than `max_tokens`** because thinking tokens count against it — except with interleaved thinking, where the budget spans all thinking blocks in one assistant turn and may exceed `max_tokens`.
- Cannot combine with `max_tokens: 0` (cache pre-warming), since budget < max_tokens is required.
- It is a **target, not a hard cap**. Claude may stop early; `max_tokens` remains the real ceiling.
- Tuning: start near the 1,024 floor for simple tasks; start at 16,000+ for complex ones. For budgets above 32k use the **Batch API** to avoid timeouts and open-connection limits.
- Monitor `usage.output_tokens_details.thinking_tokens` for billed reasoning tokens — when streaming, it appears only on the final `message_delta`.

### Interleaved thinking (thinking between tool calls in one turn)

- Opus 4.5, Sonnet 4.5, and earlier Claude 4 models (Opus 4.1, Opus 4, Sonnet 4): add beta header `interleaved-thinking-2025-05-14`.
- **Sonnet 4.6**: the header still works with manual mode but is deprecated — prefer adaptive thinking, which auto-interleaves.
- **Opus 4.6**: manual mode has **no** interleaved thinking at all; only its adaptive mode interleaves.
- **Haiku 4.5**: no interleaved thinking; the header is accepted and ignored.
- Only supported for tools used through the Messages API.

### Other manual-mode constraints

The final assistant turn of a thinking-enabled request **must begin with a thinking block** (adaptive thinking drops this requirement).

Changing `budget_tokens` between requests **invalidates cache breakpoints**, exactly like switching thinking modes, because the budget is rendered into the prompt. Hold it constant for the life of a cached conversation.

## Migrating manual → adaptive

> Source: https://platform.claude.com/docs/en/build-with-claude/extended-thinking

Required when using Opus 4.6 / Sonnet 4.6 (deprecated there) or moving to Opus 4.7/4.8/5, Sonnet 5, Fable 5, or Mythos 5 (400 there).

Before:

```json
{"model": "claude-sonnet-4-6", "max_tokens": 16000, "thinking": {"type": "enabled", "budget_tokens": 10000}}
```

After:

```json
{"model": "claude-sonnet-4-6", "max_tokens": 16000, "thinking": {"type": "adaptive"}, "output_config": {"effort": "high"}}
```

(`effort: "high"` is the default — shown only for illustration.)

This is a **behavior change, not a syntax change**. With adaptive thinking Claude decides per request whether and how much to think, and may skip thinking entirely on easy inputs at low effort. Adaptive thinking auto-interleaves, so `interleaved-thinking-2025-05-14` becomes unnecessary and is ignored.

Thinking-block preservation across turns also differs: Opus 4.5 and 4.6+ models **keep and bill** prior turns' thinking blocks as input, while Sonnet 4.5, Haiku 4.5, and earlier strip them. Budget for that difference when migrating a long conversation.

## The `effort` parameter

> Source: https://platform.claude.com/docs/en/build-with-claude/effort

`output_config.effort` is available with no beta header on Fable 5, Mythos 5, Opus 5, Opus 4.8, Mythos Preview, Opus 4.7, Opus 4.6, Sonnet 5, Sonnet 4.6, and Opus 4.5.

Default is **`high`** everywhere it is supported — setting `high` explicitly is identical to omitting it. It affects **all output tokens** (text, tool calls and arguments, and thinking when active) and does not require thinking to be enabled.

| Level | Notes |
|---|---|
| `max` | Absolute maximum capability, no token constraint. Opus 5/4.8/4.7/4.6, Mythos Preview, Sonnet 5/4.6, Fable 5, Mythos 5 |
| `xhigh` | Extended capability for long-horizon agentic/coding work (>30 min, million-token budgets). Fable 5, Mythos 5, Opus 5/4.8/4.7, Sonnet 5 — not every `max`-capable model supports it |
| `high` | Default; equals omitting the parameter |
| `medium` | Balanced, moderate token savings |
| `low` | Most efficient; significant savings with some capability reduction — good for subagents and simple tasks |

Per-model guidance:

- **Sonnet 5**: defaults `high`; step to `xhigh` for the hardest coding/agentic tasks, `medium` as a cost-saving default (roughly Sonnet 4.6-at-high quality), `low` for latency-sensitive chat.
- **Opus 4.7 / 4.8**: start `xhigh` for coding and agentic work; treat `high` as the floor for intelligence-sensitive work.
- **Opus 5**: start `high`, step to `xhigh`/`max` for demanding work. Effort does **not** reliably shorten visible response length on Opus 5 — prompt for length separately. Thinking **cannot be disabled** at `xhigh`/`max` on Opus 5; `thinking: {"type": "disabled"}` at those levels returns 400.

When running `xhigh`/`max` on Opus 4.7/4.8/5, set a large `max_tokens` (64k+ as a starting point) to leave room for thinking and tool calls across subagents.

```json
{
  "model": "claude-opus-5",
  "max_tokens": 4096,
  "messages": [{"role": "user", "content": "Analyze the trade-offs between microservices and monolithic architectures"}],
  "output_config": {"effort": "medium"}
}
```

Effort changes tool behavior too: lower effort produces fewer or combined tool calls, less preamble, and terser confirmations; higher effort produces more calls, upfront plan explanation, and detailed summaries. Tune effort before rewriting a prompt to fix over- or under-calling.

`effort` is request-level and set independently per request, but changing it mid-conversation **invalidates prompt caching** because it is rendered into the prompt. Hold it constant across a cached session.

On Opus 4.5 — an extended-thinking-only model that also supports effort — `effort` and `budget_tokens` are **independent controls**; set both.

## Sources

- https://platform.claude.com/docs/en/build-with-claude/extended-thinking
- https://platform.claude.com/docs/en/build-with-claude/effort

Fetched: 2026-08-05
