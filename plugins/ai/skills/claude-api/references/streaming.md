# Streaming (SSE)

Read when implementing or debugging a streamed Messages request.

## Enabling

> Source: https://platform.claude.com/docs/en/build-with-claude/streaming

Set `"stream": true` to receive incremental server-sent events instead of one JSON payload. The Python and TypeScript SDKs expose `client.messages.stream(...)` as a context manager, with `.text_stream` / `.on("text", cb)` for text only and `.get_final_message()` / `.finalMessage()` to accumulate the complete `Message`. Use the accumulator on large `max_tokens` requests — it avoids HTTP timeouts that a single blocking call would hit.

## Event flow

> Source: https://platform.claude.com/docs/en/build-with-claude/streaming

1. `message_start` — a `Message` object with empty `content`.
2. Per content block: `content_block_start` → one or more `content_block_delta` → `content_block_stop`. Each block's `index` matches its position in the final `content` array.
3. One or more `message_delta` events carrying top-level changes such as `stop_reason`. **`usage` here is cumulative, not incremental.**
4. `message_stop`.

`ping` events may appear anywhere. Anthropic may add new event types under its versioning policy, so unknown types must be ignored gracefully rather than treated as failures.

`error` events can arrive mid-stream:

```sse
event: error
data: {"type": "error", "error": {"type": "overloaded_error", "message": "Overloaded"}}
```

That is the streaming form of HTTP 529. During server-side fallback, a `fallback` content block arrives as a `content_block_start`/`content_block_stop` pair with no deltas between, at each model boundary.

## Delta types

> Source: https://platform.claude.com/docs/en/build-with-claude/streaming

- **`text_delta`** — `{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"ello frien"}}`
- **`input_json_delta`** (on `tool_use` blocks) — partial JSON strings. Accumulate and parse **only after `content_block_stop`**; current models emit one complete key/value at a time but chunk it across multiple deltas, so any intermediate parse can fail.
  `{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"location\": \"San Fra"}}}`
- **`thinking_delta`** — `{"delta":{"type":"thinking_delta","thinking":"I need to find the GCD..."}}`. A `signature_delta` fires just before `content_block_stop` on a thinking block, verifying its integrity. With `display: "omitted"` on the thinking config, no `thinking_delta` events fire at all — only the `signature_delta`, so do not treat their absence as a stalled stream.

## Full basic stream

> Source: https://platform.claude.com/docs/en/build-with-claude/streaming

```sse
event: message_start
data: {"type":"message_start","message":{"id":"msg_...","type":"message","role":"assistant","content":[],"model":"claude-opus-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: ping
data: {"type":"ping"}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":15}}

event: message_stop
data: {"type":"message_stop"}
```

## Streaming with tools

> Source: https://platform.claude.com/docs/en/build-with-claude/streaming

`tool_use` blocks stream as `content_block_start` (`{"type":"tool_use","id":"toolu_...","name":"get_weather","input":{}}`), then `input_json_delta` chunks, then `content_block_stop`.

Server tools stream a `server_tool_use` block the same way, but the **result block lands whole** — e.g. `web_search_tool_result` arrives as a single `content_block_start`/`content_block_stop` pair with no deltas. Do not build UI that assumes every block streams incrementally.

Fine-grained streaming of tool input JSON is available per tool via `eager_input_streaming`.

## Error recovery after an interruption

> Source: https://platform.claude.com/docs/en/build-with-claude/streaming

The correct recovery differs by model generation — using the wrong one produces malformed continuations:

- **Claude 4.5 and earlier**: capture the partial content and re-send it as the start of a new `assistant` message in a continuation request.
- **Claude 4.6 and later**: capture the partial content but put it in a **user** message instructing continuation, e.g. `"Your previous response was interrupted and ended with [previous_response]. Continue from where you left off."`

Tool-use and thinking blocks cannot be partially recovered. Resume only from the most recent complete text block.

## Sources

- https://platform.claude.com/docs/en/build-with-claude/streaming

Fetched: 2026-08-05
