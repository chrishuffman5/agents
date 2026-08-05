# Responses API — core

Read when composing a `responses.create` call, deciding how to carry conversation state, or running long tasks asynchronously.

## Create endpoint and confirmed parameters

> Source: https://developers.openai.com/api/docs/api-reference/responses
> Source: https://developers.openai.com/api/docs/guides/text

`POST /v1/responses`

| Parameter | Type | Notes |
|---|---|---|
| `model` | string | e.g. `"gpt-5.6"` |
| `input` | string \| array | Plain string, or array of message items with `role` (`developer`, `user`, `assistant`) and `content` |
| `instructions` | string | System/developer-level instructions, e.g. `"Talk like a pirate."` |
| `reasoning` | object | e.g. `{ "effort": "low" }` — reasoning-model effort control |
| `previous_response_id` | string | Chains responses into a threaded conversation |
| `conversation` | string | Attaches the response to a persisted Conversation object id |
| `store` | boolean | Persist server-side; default true, 30-day retention |
| `stream` | boolean | SSE streaming of response events |
| `background` | boolean | Run asynchronously for long tasks |
| `tools` | array | Function tools, built-in tools (`web_search`, `file_search`, `code_interpreter`, `computer`, `image_generation`), or MCP tools |
| `tool_choice` | string \| object | `"auto"`, `"required"`, `"none"`, forced-function object, or `allowed_tools` object |
| `parallel_tool_calls` | boolean | `false` restricts to zero or one tool call per turn |
| `metadata` | object | Custom key/value pairs |

**Unverified — do not present as confirmed.** The live reference page returned only a partial/paginated schema when fetched on 2026-08-05. `temperature`, `max_output_tokens`, `text.format`, `text.verbosity`, `truncation`, `include`, and `prompt_cache_key` appear in other guide pages in this skill's corpus and are individually sourced there, but no single canonical create-parameter table was obtainable. The reference page states 32+ additional properties exist beyond what was captured. Check the live reference before asserting a parameter's name, type, or default.

## Response object (confirmed fields)

> Source: https://developers.openai.com/api/docs/api-reference/responses

| Field | Notes |
|---|---|
| `id` | Unique identifier; the value you pass to `previous_response_id` |
| `created_at` | Unix timestamp, seconds |
| `error` | `ResponseError` or null — `code` and `message` |
| `incomplete_details` | Object or null — `reason` is `"max_output_tokens"` or `"content_filter"` |
| `instructions` | string \| array \| object \| null |
| `status` | `"in_progress"`, `"completed"`, `"incomplete"`; background responses add `"queued"`, `"failed"`, `"cancelled"` |
| `output` | Typed array of output items: messages, `function_call`, `reasoning`, tool-call items |
| `output_text` | SDK convenience accessor concatenating text output |

Always branch on `status` and `incomplete_details` before reading `output_text`. A truncated or content-filtered response still returns 200 with partial output.

## Cancel endpoint

> Source: https://developers.openai.com/api/docs/api-reference/responses

`POST /v1/responses/{response_id}/cancel`

"Cancels a model response with the given ID. Only responses created with the `background` parameter set to `true` can be cancelled." Idempotent — cancelling an already-final response returns the final Response object rather than an error, so retry logic does not need a guard.

## Basic usage

> Source: https://developers.openai.com/api/docs/guides/text

```python
response = client.responses.create(
    model="gpt-5.6",
    input="Write a one-sentence bedtime story about a unicorn.",
)
print(response.output_text)
```

```javascript
const response = await client.responses.create({
  model: "gpt-5.6",
  input: "Write a one-sentence bedtime story about a unicorn.",
});
console.log(response.output_text);
```

## Conversation state

> Source: https://developers.openai.com/api/docs/guides/conversation-state

### `previous_response_id`

Pass the prior response's `id` and the model receives the full prior context.

**Billing:** all previous input tokens for responses in the chain are billed as input tokens on **every subsequent call**. Chaining is a convenience feature, not a cost optimization — prompt caching is what keeps a long chain affordable.

WebSocket-mode nuance: the connection-local cache holds only the most recent response for low-latency continuation. If an uncached response id cannot be resolved, start a fresh turn with `previous_response_id: null` and supply the full input context manually.

### Conversations API

```python
conversation = openai.conversations.create()

response = openai.responses.create(
    model="gpt-5.6",
    input=[{"role": "user", "content": "Your question"}],
    conversation=conversation.id,
)
```

Conversations store messages, tool calls, tool outputs, and other items as a durable cross-session, cross-device object.

### Retention

| Object | Retention |
|---|---|
| Response with `store: true` (default) | 30 days |
| Response with `store: false` | not persisted |
| Conversation, and any response attached to one | **no 30-day TTL — persists indefinitely** |

That asymmetry is the main reason to choose Conversations over id-chaining for anything a user returns to across sessions. It is also a data-governance consideration: attaching a response to a conversation opts it out of automatic expiry.

### Context window accounting

The context window is "the total tokens that can be used for both input and output tokens (and for some models, reasoning tokens)" — a single ceiling shared by input, output, and reasoning. Reasoning tokens are not visible in your prompt but consume the same budget. Use the tokenizer tool to estimate consumption and avoid truncation.

## Background mode

> Source: https://developers.openai.com/api/docs/guides/background

Set `"background": true` to run long tasks (documented in the context of models like GPT-5.2 and GPT-5.2 Pro) without client timeout concerns: OpenAI "kicks off these tasks asynchronously, and developers can poll response objects to check status over time."

```python
resp = client.responses.create(model="gpt-5.6", input="...", background=True)
# poll roughly every 2s while status is "queued" or "in_progress"
result = client.responses.retrieve(resp.id)
```

Terminal states end polling: `completed`, `failed`, `cancelled`, `incomplete`.

### Streaming a background response

Set both `background: true` and `stream: true` to receive events immediately while execution continues asynchronously. Record each event's `sequence_number`; after a dropped connection, resume with the `starting_after` parameter set to the last-seen sequence number. Without that cursor a dropped connection means re-running the whole task.

### Zero Data Retention

ZDR projects automatically force `store=false` for background responses. Data is held on disk roughly 10 minutes, solely to support polling. Design ZDR background flows to consume results immediately — nothing is retrievable later.

## SDK setup

> Source: https://developers.openai.com/api/docs/libraries

Python:

```bash
pip install openai
export OPENAI_API_KEY="your_api_key_here"
```

```python
from openai import OpenAI
client = OpenAI()
```

Node:

```bash
npm install openai
export OPENAI_API_KEY="your_api_key_here"
```

```javascript
import OpenAI from "openai";
const client = new OpenAI();
```

Both clients read `OPENAI_API_KEY` from the environment automatically.

**Unverified:** SDK version numbers and changelogs were not on the fetched libraries page, and SDKs for languages other than Python and Node were not confirmed today. Do not assert that a Go/Java/.NET/Ruby SDK exists or what it is called without checking.

## Sources

- https://developers.openai.com/api/docs/api-reference/responses
- https://developers.openai.com/api/docs/guides/text
- https://developers.openai.com/api/docs/guides/conversation-state
- https://developers.openai.com/api/docs/guides/background
- https://developers.openai.com/api/docs/libraries

Fetched: 2026-08-05
