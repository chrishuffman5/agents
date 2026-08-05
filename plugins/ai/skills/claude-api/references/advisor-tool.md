# Advisor Tool

Read when a cheap executor model needs strategic guidance from a stronger model inside a single request.

## What it is

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

A faster/cheaper **executor** consults a higher-intelligence **advisor** mid-generation, inside one `/v1/messages` request. Good fit: long-horizon agentic work (coding agents, computer use, multistep research) where most turns are mechanical but planning quality decides the outcome. Poor fit: single-turn Q&A, pure pass-through model routing, or workloads where every turn needs full advisor capability — in those cases just run the stronger model.

Beta header as of 2026-08-05: **`advisor-tool-2026-03-01`**.

```json
{
  "model": "claude-sonnet-5",
  "max_tokens": 4096,
  "tools": [{"type": "advisor_20260301", "name": "advisor", "model": "claude-fable-5"}],
  "messages": [{"role": "user", "content": "Build a concurrent worker pool in Go with graceful shutdown."}]
}
```

With Opus 5, Fable 5, or Mythos 5 as advisor, the result content is `advisor_redacted_result` — encrypted, readable by the executor server-side but not by your client. Use `claude-opus-4-8` as advisor when you need plaintext `advisor_result` for logging or evaluation.

Availability: beta on the Claude API and Claude Platform on AWS. **Not** on Amazon Bedrock, Google Cloud, or Microsoft Foundry.

## Mechanics

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

1. Executor emits `server_tool_use` with `name: "advisor"` and **empty** `input` — the server builds the advisor's view from the transcript, so there is nothing for you to populate.
2. Anthropic runs a separate server-side inference on the advisor model, which receives the executor's full transcript (system prompt, tool definitions, prior turns and results, text produced so far this turn) as quoted context under its own Anthropic-supplied system prompt.
3. The advice returns as `advisor_tool_result`.
4. The executor continues, informed by it.

The advisor runs without tools and without context management, and its thinking blocks are dropped — only advice text reaches the executor.

Tool parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `type` | string | required | Must be `"advisor_20260301"` |
| `name` | string | required | Must be `"advisor"` |
| `model` | string | required | Advisor model ID; billed at that model's rates |
| `max_uses` | integer | unlimited | Per-request cap; exceeding returns `max_uses_exceeded` and the executor continues without advice |
| `max_tokens` | integer | advisor's own cap | Caps advisor output (thinking + text) per call; minimum 1024 |
| `caching` | object\|null | `null` | `{"type": "ephemeral", "ttl": "5m"\|"1h"}` — an on/off switch for advisor-side caching, not a breakpoint marker |

Also accepts `cache_control`, `allowed_callers`, `defer_loading`, `strict`.

Successful response:

```json
{
  "content": [
    {"type": "text", "text": "Let me consult the advisor on this."},
    {"type": "server_tool_use", "id": "srvtoolu_abc123", "name": "advisor", "input": {}},
    {"type": "advisor_tool_result", "tool_use_id": "srvtoolu_abc123",
     "content": {"type": "advisor_result", "text": "Use a channel-based coordination pattern..."}},
    {"type": "text", "text": "Here's the implementation..."}
  ]
}
```

Result variants (discriminated union on `content.type`): `advisor_result` (`text`, `stop_reason`) for plaintext advisors like Opus 4.8; `advisor_redacted_result` (`encrypted_content`, `stop_reason`) for Opus 5 / Fable 5 / Mythos 5. `stop_reason` appears only when the tool definition sets `max_tokens`. Round-trip content verbatim; branch on `content.type` if you swap advisor models mid-conversation.

Errors do not fail the request — the executor continues without advice: `max_uses_exceeded`, `too_many_requests` (advisor sub-inference throttled), `overloaded`, `prompt_too_long` (transcript exceeded the advisor's context), `execution_time_exceeded`, `unavailable`. A rate limit on the *executor* is different: that fails the whole request with HTTP 429.

## Model compatibility

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

The advisor must be Claude Sonnet 4.6 or more capable, and at least as capable as the executor. Equal pairs are allowed.

| Executor | Valid advisors |
|---|---|
| Claude Haiku 4.5 | Mythos 5, Fable 5, Opus 5, Opus 4.8, Opus 4.7, Opus 4.6, Sonnet 5, Sonnet 4.6 |
| Claude Sonnet 4.6 | Mythos 5, Fable 5, Opus 5, Opus 4.8, Opus 4.7, Opus 4.6, Sonnet 5, Sonnet 4.6 |
| Claude Sonnet 5 | Mythos 5, Fable 5, Opus 5, Opus 4.8, Opus 4.7, Sonnet 5 |
| Claude Opus 4.6 | Mythos 5, Fable 5, Opus 5, Opus 4.8, Opus 4.7, Opus 4.6, Sonnet 5 |
| Claude Opus 4.7 | Mythos 5, Fable 5, Opus 5, Opus 4.8, Opus 4.7 |
| Claude Opus 4.8 | Mythos 5, Fable 5, Opus 5, Opus 4.8, Opus 4.7 |
| Claude Opus 5 | Mythos 5, Fable 5, Opus 5 |
| Claude Fable 5 | Fable 5, Opus 5 |
| Claude Mythos 5 | Mythos 5, Opus 5 |

An invalid pair returns `400 invalid_request_error` naming the combination.

## Multi-turn, pausing, streaming

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

- Pass the full assistant content — including `advisor_tool_result` blocks — back on later turns, and **keep the advisor tool in `tools` on every turn whose history contains those blocks**, or the API returns `400 invalid_request_error`.
- There is no conversation-level cap. To stop consulting, remove the advisor tool from `tools` **and** strip all `advisor_tool_result` blocks from history; count calls client-side to enforce a budget.
- A response can end `stop_reason: "pause_turn"` with a pending advisor `server_tool_use` and no result. Resume by resending that assistant message unchanged with the same tool and beta header — no user message, no `tool_result`. A resumed turn can pause again.
- If the executor also called one of your tools in the same turn, the response ends `stop_reason: "tool_use"` instead; send `tool_result` as usual and the pending advisor call runs at the start of the next request.
- Advisor sub-inference does **not** stream. The executor's stream pauses at the `server_tool_use` block's `content_block_stop` with only ~30s SSE `ping` keepalives, then the full `advisor_tool_result` arrives in one `content_block_start` with no deltas, then executor output resumes, followed by a `message_delta` with updated `usage.iterations`.

## Billing

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

Advisor calls bill at the **advisor model's** rates and appear in `usage.iterations[]`:

```json
{
  "usage": {
    "input_tokens": 412, "output_tokens": 531,
    "iterations": [
      {"type": "message", "input_tokens": 412, "output_tokens": 89},
      {"type": "advisor_message", "model": "claude-fable-5", "input_tokens": 823, "output_tokens": 1612},
      {"type": "message", "input_tokens": 1348, "cache_read_input_tokens": 412, "output_tokens": 442}
    ]
  }
}
```

Top-level `usage` covers executor tokens only: `output_tokens` sums all executor iterations, while `input_tokens`/`cache_read_input_tokens` reflect only the first executor iteration. **Never estimate advisor cost from top-level usage — read `iterations`.**

Typical advisor output is 400–700 text tokens (1,400–1,800 with thinking) on lighter workloads; hard reasoning tasks push the mean to ~4,200–5,900 tokens when uncapped. Top-level `max_tokens` bounds the executor only. Priority Tier applies per model independently — an executor commitment does not extend to the advisor.

## Caching and cost control

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

Two independent layers:

- **Executor-side**: the `advisor_tool_result` block caches like any content block; a `cache_control` breakpoint after it hits on later turns whether the content is `text` or `encrypted_content`.
- **Advisor-side**: `caching: {"type": "ephemeral", "ttl": "5m"}` on the tool definition. Call N's advisor prompt is call N-1's plus one appended segment, so caching writes and reads incrementally. It breaks even at roughly **3 advisor calls per conversation** — enable it only for long loops, and keep the setting constant for the whole conversation because toggling causes misses.

Caching warning: `clear_thinking` with `keep` set to anything other than `"all"` shifts the advisor's quoted transcript each turn, causing advisor-cache misses (a cost problem, not a quality one). Set `keep: "all"` to keep the advisor cache stable. Default `keep` is `{type: "thinking_turns", value: 1}` on earlier Opus/Sonnet and all Haiku models; Opus 4.5+/Sonnet 4.6+ default to keeping all turns.

**Forcing a consult**: `"tool_choice": {"type": "tool", "name": "advisor"}`. This cannot combine with manual extended thinking (`thinking: {"type": "enabled"}` returns 400); adaptive thinking supports forced tool use.

**Trimming output (soft)**: address the advisor directly in a user message — it sees system and user messages as quoted context, so direct address lands better than third-person description: `"(Advisor: please keep your guidance under 80 words — I need a focused starting point, not a comprehensive plan.)"` Ask for ~80% of the true ceiling.

**Capping output (hard)**: set `max_tokens` on the tool definition (min 1024; above the advisor's own cap returns 400). Start at **2048** — in Anthropic's testing (n=40/config) that cut mean output ~7x with near-zero truncation, while `1024` cut ~10x but truncated ~10% of calls. On truncation the result carries `stop_reason: "max_tokens"` and the advice text gets `[Advisor output truncated at max_tokens=2048.]` appended.

**Nudging an under-calling executor** (Haiku and Sonnet only — it slightly *hurts* Opus): append a short reminder as a user message before turn `NUDGE_TURN` (default 2) if the advisor has not been called. This raised Haiku pass rates ~7 percentage points in Anthropic's internal eval, and 74% (Sonnet) to 98% (Haiku) of nudged attempts called the advisor immediately at turn 2. Measure your executor's baseline first-call turn first: if the baseline is turn N, set `NUDGE_TURN` > N — a turn-2 nudge against a turn-7+ baseline correlated with a 3–4 point task-performance drop in one eval.

**Suggested executor system prompt (coding)**: call `advisor()` before substantive work (before committing to an interpretation), when believing the task complete (after making the deliverable durable — write/save/commit first), when stuck, and when considering an approach change.

Feature interactions:

| Feature | Interaction |
|---|---|
| Batch processing | Supported; `usage.iterations` reported per item |
| Token counting | `count_tokens` returns the executor's first-iteration input only; for an advisor estimate, call it with `model` set to the advisor |
| Context editing | `clear_tool_uses` is not fully compatible with advisor blocks; see the `clear_thinking` warning above |
| `pause_turn` | A dangling advisor call with no client `tool_use` ends the response `pause_turn`; with a client tool call it ends `tool_use` and the advisor runs after your `tool_result` |

Effort pairing: for coding tasks, a Sonnet executor at `medium` effort plus an Opus advisor approximates Sonnet-at-default-effort intelligence at lower cost.

## Sources

- https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

Fetched: 2026-08-05
