# Function calling

Read when defining tools, debugging a tool round trip, or porting tool definitions off Chat Completions.

## Tool categories

> Source: https://developers.openai.com/api/docs/guides/function-calling

Three kinds live in the same `tools` array:

- **Function tools** — JSON-Schema-defined, structured input and output. The default choice.
- **Custom tools** — freeform text input, no schema.
- **Built-in tools** — platform-provided (web search, code execution, MCP servers). See `built-in-tools.md`.

## Function tool definition

> Source: https://developers.openai.com/api/docs/guides/function-calling

| Field | Purpose |
|---|---|
| `type` | Always `"function"` |
| `name` | Function identifier, e.g. `"get_weather"` |
| `description` | Guidance on when and how to use it |
| `parameters` | JSON Schema for arguments |
| `strict` | Enforce schema compliance via Structured Outputs — recommended `true` |

```json
{
  "type": "function",
  "name": "get_weather",
  "description": "Retrieves current weather for the given location.",
  "parameters": {
    "type": "object",
    "properties": {
      "location": { "type": "string", "description": "City and country e.g. Bogotá, Colombia" },
      "units": { "type": "string", "enum": ["celsius", "fahrenheit"], "description": "Units the temperature will be returned in." }
    },
    "required": ["location", "units"],
    "additionalProperties": false
  },
  "strict": true
}
```

These fields sit at the **top level** of the tool object. Chat Completions nested them under a `function` key; a copied definition will be rejected.

Parameters accept full JSON Schema — property types, enums, nested objects, recursive structures — subject to the strict-mode subset below.

## Strict mode

> Source: https://developers.openai.com/api/docs/guides/function-calling

`"strict": true` enforces schema-conforming calls using Structured Outputs under the hood. Requirements:

- `additionalProperties: false` on **every** object, not just the root.
- **Every** property listed in `required`.
- Optional fields expressed as a nullable union — `"type": ["string", "null"]` — never by omission from `required`.

```json
// STRICT — optional field modeled as nullable, still required
{ "strict": true,
  "parameters": {
    "properties": { "units": { "type": ["string", "null"], "enum": ["celsius", "fahrenheit"] } },
    "required": ["location", "units"],
    "additionalProperties": false } }

// NON-STRICT — omission from required is allowed, no guarantee
{ "parameters": {
    "properties": { "units": { "type": "string", "enum": ["celsius", "fahrenheit"] } },
    "required": ["location"] } }
```

Strict mode inherits the full Structured Outputs schema subset — the same unsupported keywords and caps apply. See `structured-outputs.md` before writing anything non-trivial.

## `tool_choice`

> Source: https://developers.openai.com/api/docs/guides/function-calling

| Value | Effect |
|---|---|
| `"auto"` (default) | Model calls zero, one, or multiple functions |
| `"required"` | Model must call at least one function |
| `{"type": "function", "name": "get_weather"}` | Forces that exact function |
| `{"type": "allowed_tools", "mode": "auto", "tools": [...]}` | Restricts the callable set without forcing a call |
| `"none"` | Emulates having no functions available |

`allowed_tools` is the right tool for per-turn scoping — narrowing what a model may call at a given step without rebuilding the tool array or forcing a call it does not need.

## Parallel calls

> Source: https://developers.openai.com/api/docs/guides/function-calling

On GPT-5 and later, functions execute in parallel **by default**. Set `"parallel_tool_calls": false` to force exactly zero-or-one call per turn — necessary when your handlers are not idempotent or share mutable state.

## Call and result shapes

> Source: https://developers.openai.com/api/docs/guides/function-calling

A call arrives in `output` as:

```json
[{ "id": "fc_12345xyz",
   "call_id": "call_12345xyz",
   "type": "function_call",
   "name": "get_weather",
   "arguments": "{\"location\":\"Paris, France\"}" }]
```

Two distinct identifiers. `call_id` is what you echo back; `id` is the item's own identifier. Mixing them up is the most common reason a result appears to be ignored.

`arguments` is a **JSON-encoded string** and must be parsed.

Submit results as:

```json
{ "type": "function_call_output",
  "call_id": "call_12345xyz",
  "output": "The weather in Paris today is 25C." }
```

`output` can be a plain string (text, JSON, or an error code), an array of image/file objects, or a simple success/failure indicator for void functions. Returning an error string is legitimate — the model can recover from it, which it cannot do from an exception you swallow.

Handling multiple calls:

```javascript
input.push(...response.output);
for (const toolCall of response.output) {
  if (toolCall.type !== "function_call") continue;
  const result = await callFunction(toolCall.name, JSON.parse(toolCall.arguments));
  input.push({ type: "function_call_output", call_id: toolCall.call_id, output: result.toString() });
}
```

Push the model's `output` items back **unchanged** before appending your outputs. Rebuilding them by hand loses reasoning items and breaks the chain.

## Full round trip

> Source: https://developers.openai.com/api/docs/guides/function-calling

```javascript
// 1. Initial request
response = await openai.responses.create({
  model: "gpt-5.6",
  tools: tools,
  input: [{ role: "user", content: "What's the weather in Paris?" }]
});

// 2-3. Extract + execute
for (const item of response.output) {
  if (item.type === "function_call" && item.name === "get_weather") {
    const result = getWeather(JSON.parse(item.arguments).location);
    // 4. Submit result
    input.push({ type: "function_call_output", call_id: item.call_id, output: result });
  }
}

// 5. Final response
response = await openai.responses.create({ model: "gpt-5.6", tools: tools, input: input });
```

## Best practices

> Source: https://developers.openai.com/api/docs/guides/function-calling

1. Write clear, detailed function names, descriptions, and use-cases.
2. Use enums and object structures to make invalid states unrepresentable; apply strict mode.
3. Keep the active toolset small — **aim for fewer than 20 functions**; defer rarely-needed ones via tool search rather than always including them.
4. Never ask the model to fill in a parameter your code already knows.
5. Function definitions consume input tokens on every request. With a large library, tool search is a token-efficiency measure, not a nicety.

Point 4 is also a security property: a parameter the model cannot influence is a parameter it cannot be prompt-injected into. Threat modeling for that belongs to the `ai-security` skill.

## Sources

- https://developers.openai.com/api/docs/guides/function-calling

Fetched: 2026-08-05
