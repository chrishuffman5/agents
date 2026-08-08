# Migrating from Chat Completions to Responses

Read when porting an existing `chat.completions` codebase, or when deciding whether to port at all.

## Status as of 2026-08-05

> Source: https://developers.openai.com/api/docs/guides/migrate-to-responses

Chat Completions **remains fully operational and supported, with no announced deprecation date.** OpenAI's guidance is a recommendation, not a forced migration: "While Chat Completions remains supported, Responses is recommended for all new projects."

Separately and much more urgently: **the Assistants API — a different, older product — is being deprecated, with full sunset on 2026-08-26.** Code calling Assistants, Threads, or Runs needs a migration plan now. Do not conflate the two; telling a team their Chat Completions code has a sunset date is wrong.

## Field-by-field mapping

> Source: https://developers.openai.com/api/docs/guides/migrate-to-responses

| Aspect | Chat Completions | Responses |
|---|---|---|
| Endpoint | `POST /v1/chat/completions` | `POST /v1/responses` |
| Input structure | `messages` array | `input` (string or Items) + `instructions` |
| Output structure | `choices[0].message.content` | `response.output_text` or typed `output` array |
| Item types | messages only | messages, reasoning, function calls, tool outputs |
| State management | manual transcript tracking | `previous_response_id`, manual replay, or Conversations API |
| Native tools | custom implementations required | built-in web search, file search, code interpreter, computer use, MCP |
| Function definitions | externally tagged | internally tagged |
| Structured outputs | `response_format` parameter | `text.format` parameter |

Side-by-side:

```javascript
// Chat Completions
const completion = await client.chat.completions.create({
  model: "gpt-5.6",
  messages: [
    { role: "system", content: "You are a helpful assistant." },
    { role: "user", content: "Hello!" },
  ],
});
console.log(completion.choices[0].message.content);

// Responses
const response = await client.responses.create({
  model: "gpt-5.6",
  instructions: "You are a helpful assistant.",
  input: "Hello!",
});
console.log(response.output_text);
```

## The two changes that break silently

**Internally vs externally tagged function definitions.** Chat Completions nests the definition under a `function` key; Responses puts `type`, `name`, `description`, `parameters`, and `strict` at the top level of the tool object. A copied definition is rejected, and copied *result-handling* code reads the wrong path. See `function-calling.md`.

**`response_format` → `text.format`.** A schema left under `response_format` is not an error the model reports as a schema violation — you simply lose the structured-output guarantee. Move every schema and re-test. See `structured-outputs.md`.

## Claimed benefits

> Source: https://developers.openai.com/api/docs/guides/migrate-to-responses

OpenAI's stated gains: a "3% improvement in SWE-bench" versus Chat Completions; "40% to 80% improvement" in cache utilization; agentic multi-tool-call support within a single API request; and stateful context that preserves reasoning and tool context across turns.

Treat these as vendor claims. The cache-utilization figure is the one most likely to matter in practice, because Responses keeps reasoning and tool items in a stable prefix instead of forcing you to rebuild the transcript each turn — but it only materializes if your prompt is structured static-first (see `prompt-caching.md`).

## Recommended migration order

> Source: https://developers.openai.com/api/docs/guides/migrate-to-responses

1. Start with simple text flows.
2. Update the endpoint and output handling.
3. Decide on a state-management strategy (`previous_response_id`, Conversations, or manual replay).
4. Migrate function definitions.
5. Move Structured Outputs schemas.
6. Update streaming handlers.
7. Full rollout.

Do step 3 as a deliberate decision, not a default. `previous_response_id` re-bills the entire prior input on every turn; manual replay keeps you in control of what is resent; Conversations buys durability at the cost of indefinite retention. See `responses-api.md`.

Step 6 is a full rewrite, not a tweak: Chat Completions streaming deltas and Responses SSE events are different event models with different names. See `streaming.md`.

## Sources

- https://developers.openai.com/api/docs/guides/migrate-to-responses

Fetched: 2026-08-05
