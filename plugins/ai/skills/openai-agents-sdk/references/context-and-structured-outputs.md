# Context objects and structured outputs

Read this when injecting application state or dependencies into tools, when deciding how to get data in front of the model, or when a structured output is being rejected by the schema validator.

## Context objects (Python)

> Source: https://openai.github.io/openai-agents-python/context/, https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/context.md

"Context" means two different things in this SDK; conflating them is the usual source of confusion.

**Local context (`RunContextWrapper`)** — data and dependencies available to *your* code during tool execution, callbacks, and lifecycle hooks. Create a Python object (dataclass or Pydantic model), pass it via `context=` on the run method, and read it through `RunContextWrapper[T]`.

Quoted directly: "The context object is **not** sent to the LLM. It is purely a local object that you can read from, write to and call methods on it."

Constraint: "every agent, tool function, lifecycle etc for a given agent run must use the same *type* of context."

Common uses: user identity, loggers, data fetchers, mutable app state.

`RunContextWrapper` properties:

| Property | Contents |
|---|---|
| `wrapper.context` | your object |
| `wrapper.usage` | token/request usage across the run |
| `wrapper.tool_input` | structured input for nested `Agent.as_tool()` runs |
| `wrapper.approve_tool()` / `wrapper.reject_tool()` | programmatic approval control |

`ToolContext` extends `RunContextWrapper` with `tool_name`, `tool_call_id`, `tool_arguments` (raw argument string), and `tool_namespace` (the Responses namespace, when applicable).

**Agent/LLM context** — what the model actually sees, limited to conversation history. Four ways to expose data to it:

1. Instructions / system prompt — static string or dynamic function. Best for information that is consistently relevant.
2. `Runner.run()` input — message-level, lower in the command hierarchy than instructions.
3. Function tools — on-demand; the LLM decides when to fetch.
4. Retrieval or web search tools — grounds responses in external data.

In TypeScript the equivalent is the caller-created context object passed to `Runner.run()`, forwarded to every tool, guardrail, and handoff, and likewise never sent to the model.

## Structured outputs

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/agents.mdx, https://developers.openai.com/api/docs/guides/structured-outputs

Setting `output_type` (Python — Pydantic models, dataclasses) or `outputType` (TypeScript — a Zod schema `z.object({...})` or JSON-schema-compatible object) makes the SDK use the platform's Structured Outputs feature automatically instead of returning plain text.

Platform behavior underneath:

- Structured Outputs guarantees **schema adherence**. JSON mode guarantees only syntactically valid JSON, with no schema conformance check.
- Structured Outputs is enabled with `"strict": true` plus a schema and requires `gpt-4o-mini` or later; JSON mode uses `"type": "json_object"` and works from `gpt-3.5-turbo` onward. Prefer Structured Outputs whenever possible.
- Use function calling (tools) to connect the model to external functions and data; use text-format Structured Outputs to shape the response shown to a user.
- Wire format on the Responses API: `text: { format: { type: "json_schema", strict: true, schema: {...} } }`.

### Supported schema surface

Types: string, number, boolean, integer, object, array, enum, `anyOf`. Recursive schemas and `$defs`/definitions are supported.

| Constraint family | Supported keywords |
|---|---|
| String | `pattern` (regex), `format`: `date-time`, `time`, `date`, `duration`, `email`, `hostname`, `ipv4`, `ipv6`, `uuid` |
| Number | `multipleOf`, `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum` |
| Array | `minItems`, `maxItems` |

**Hard requirements** — these are what actually reject a schema:

- The root must be an object; no top-level `anyOf`.
- Every field must be `required`. Emulate optional fields with a `["type", "null"]` union.
- `additionalProperties: false` on every object.
- Maximum 5,000 total properties and 10 levels of nesting.
- Combined property/enum name length capped at 120,000 characters.
- Up to 1,000 enum values total across all properties; any single enum with 250+ values is capped at 15,000 characters.

**Unsupported keywords**: `allOf`, `not`, `dependentRequired`, `if`/`then`/`else`. Fine-tuned models additionally lack `minLength`, `maxLength`, `pattern`, `format`, and the numeric constraints.

### Failure modes to handle explicitly

- **Incomplete responses** — the generation hit max tokens. Detect and handle separately from a validation error.
- **Refusals** — the `refusal` field is populated instead of schema-conforming content when the model safety-refuses. Handle it programmatically; it is not a schema bug.

Streaming is supported, and the SDKs parse incrementally.

Best practices from the platform guide: use intuitive property names and descriptions; instruct the model on what to do with input that does not fit the schema (return empty or default fields); split the task or add few-shot examples when the model makes mistakes; generate the schema from Pydantic/Zod so code types and schema never drift. The first request with a new schema carries extra latency; subsequent identical schemas do not.

## SDK-to-platform mapping

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/agents.mdx

| SDK concept | OpenAI platform feature | When it matters |
|---|---|---|
| `outputType` / `output_type` | Structured Outputs | agent should return typed JSON / a Zod-validated object rather than text |
| `tools` / hosted tools | Tools | model should search, retrieve, execute code, or call functions |
| `conversationId` / `previousResponseId` (`conversation_id` / `previous_response_id`) | Conversation state | OpenAI should persist or chain conversation state between turns |

`conversationId`/`previousResponseId` are **run-time** controls passed to `run()`/`Runner.run()`, not `Agent` constructor fields, and they are incompatible with SDK `Session` objects — see `sessions-and-state.md`.

## Gaps

- The `developers.openai.com` Responses API landing/overview page was not fetched; only the Structured Outputs and Conversation State sub-guides were. The SDK-to-Responses-API relationship above is reconstructed from the Agents SDK docs' own cross-references plus those two sub-guides.

## Sources

- https://openai.github.io/openai-agents-python/context/
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/context.md
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/agents.mdx
- https://developers.openai.com/api/docs/guides/structured-outputs
- https://developers.openai.com/api/docs/guides/conversation-state

Fetched: 2026-08-05
