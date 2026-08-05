# Streaming

Read when building or debugging an SSE consumer for the Responses API, or when porting Chat Completions delta handling.

## Consumption loop

> Source: https://developers.openai.com/api/docs/guides/streaming-responses

```python
from openai import OpenAI
client = OpenAI()
stream = client.responses.create(
    model="gpt-5.6",
    input=[{"role": "user", "content": "Your prompt here"}],
    stream=True,
)
for event in stream:
    print(event)
```

```javascript
import { OpenAI } from "openai";
const client = new OpenAI();
const stream = await client.responses.create({
  model: "gpt-5.6",
  input: [{ role: "user", content: "Your prompt here" }],
  stream: true,
});
for await (const event of stream) {
  console.log(event);
}
```

Responses emits **named typed events**, not Chat Completions' `choices[].delta` chunks. A ported handler must be rewritten, not adapted — there is no field-level correspondence.

## Confirmed event types

> Source: https://developers.openai.com/api/docs/guides/streaming-responses

Lifecycle:

- `response.created`
- `response.in_progress`
- `response.failed`
- `response.completed`

Item and content structure:

- `response.output_item.added`
- `response.output_item.done`
- `response.content_part.added`
- `response.content_part.done`

Text and refusals:

- `response.output_text.delta`
- `response.output_text.annotation.added`
- `response.text.done`
- `response.refusal.delta`
- `response.refusal.done`

Function calls:

- `response.function_call_arguments.delta`
- `response.function_call_arguments.done`

File search progress:

- `response.file_search_call.in_progress`
- `response.file_search_call.searching`
- `response.file_search_call.completed`

Code interpreter progress:

- `response.code_interpreter.in_progress`
- `response.code_interpreter_call_code.delta`
- `response.code_interpreter_call_code.done`
- `response.code_interpreter_call.interpreting`
- `response.code_interpreter_call.completed`

Errors:

- `error`

## Handling rules

Accumulate `response.function_call_arguments.delta` fragments and parse only after the matching `.done` — partial JSON is not valid JSON, and a parser that tries mid-stream will throw on nearly every call.

Handle unknown event types gracefully. The list above is what was documented on 2026-08-05; OpenAI adds events, and a consumer that raises on an unrecognized `type` breaks on a docs update you never read.

Treat `error` as an in-band event, not a transport failure. It arrives on a 200 stream.

`response.output_text.annotation.added` is how web-search `url_citation` annotations arrive during streaming — if you render citations (required for web search, see `built-in-tools.md`), you must handle this event, not just the text deltas.

## Resuming a dropped stream

> Source: https://developers.openai.com/api/docs/guides/background

Only background responses are resumable. Set `background: true` alongside `stream: true`, record each event's `sequence_number`, and reconnect with `starting_after` set to the last-seen value. Without background mode, a dropped connection means re-running the request from scratch. Details in `responses-api.md`.

## Gaps — do not fill from memory

Per-event JSON payload schemas (the exact fields on, say, `response.output_text.delta`) were **not** captured. Only event-type names and the basic consumption loop are confirmed. Read field names off the live event objects or the API reference rather than assuming.

## Sources

- https://developers.openai.com/api/docs/guides/streaming-responses
- https://developers.openai.com/api/docs/guides/background

Fetched: 2026-08-05
