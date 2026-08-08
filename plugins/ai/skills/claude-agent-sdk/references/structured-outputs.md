# Agent SDK Structured Outputs

Read this when an agent must return validated JSON rather than prose, or when a run fails with `error_max_structured_output_retries`.

## How it works

> Source: https://code.claude.com/docs/en/agent-sdk/structured-outputs

Structured outputs let you define the exact shape of returned data. The agent still uses any tools it needs mid-task; you get validated JSON matching your schema at the end.

Define a JSON Schema and pass it via `outputFormat`/`output_format`. The SDK validates the output against it and **re-prompts on mismatch**. If validation does not succeed within the retry limit, the result is an error, not structured data.

The result arrives as `structured_output` on the `ResultMessage`/`result`-type message.

## Quick start

```typescript
const schema = {
  type: "object",
  properties: {
    company_name: { type: "string" },
    founded_year: { type: "number" },
    headquarters: { type: "string" }
  },
  required: ["company_name"]
};

try {
  for await (const message of query({
    prompt: "Research Anthropic and provide key company information",
    options: { outputFormat: { type: "json_schema", schema } }
  })) {
    if (message.type === "result" && message.subtype === "success" && message.structured_output) {
      console.log(message.structured_output);
    }
  }
} catch (error) {
  console.error(`Session ended with an error: ${error}`);
}
```

```python
schema = {
    "type": "object",
    "properties": {
        "company_name": {"type": "string"},
        "founded_year": {"type": "number"},
        "headquarters": {"type": "string"},
    },
    "required": ["company_name"],
}
async for message in query(
    prompt="Research Anthropic and provide key company information",
    options=ClaudeAgentOptions(output_format={"type": "json_schema", "schema": schema}),
):
    if isinstance(message, ResultMessage) and message.structured_output:
        print(message.structured_output)
```

## Type-safe schemas with Zod and Pydantic

The SDK validates against **JSON Schema draft-07** and rejects schemas declaring a newer version. Zod targets draft 2020-12 by default, so always convert with `target: "draft-7"`.

```typescript
const FeaturePlan = z.object({
  feature_name: z.string(),
  summary: z.string(),
  steps: z.array(z.object({
    step_number: z.number(),
    description: z.string(),
    estimated_complexity: z.enum(["low", "medium", "high"])
  })),
  risks: z.array(z.string())
});
type FeaturePlan = z.infer<typeof FeaturePlan>;
const schema = z.toJSONSchema(FeaturePlan, { target: "draft-7" });

for await (const message of query({ prompt: "...", options: { outputFormat: { type: "json_schema", schema } } })) {
  if (message.type === "result" && message.subtype === "success" && message.structured_output) {
    const parsed = FeaturePlan.safeParse(message.structured_output);
    if (parsed.success) { const plan: FeaturePlan = parsed.data; /* fully typed */ }
  }
}
```

```python
from pydantic import BaseModel

class Step(BaseModel):
    step_number: int
    description: str
    estimated_complexity: str

class FeaturePlan(BaseModel):
    feature_name: str
    summary: str
    steps: list[Step]
    risks: list[str]

options = ClaudeAgentOptions(output_format={"type": "json_schema", "schema": FeaturePlan.model_json_schema()})
# later:
plan = FeaturePlan.model_validate(message.structured_output)
```

## Config and schema support

- `type`: `"json_schema"`.
- `schema`: a JSON Schema object. Generate with `z.toJSONSchema(schema, { target: "draft-7" })` (Zod) or `.model_json_schema()` (Pydantic).
- Supported features: all basic types (object/array/string/number/boolean/null), `enum`, `const`, `required`, nested objects, `$ref` definitions.
- The `"format"` keyword (e.g. `"format": "email"`) is accepted as an annotation but **not enforced** by the SDK validator.
- **As of v2.1.205**, an invalid schema fails the run at startup with an error naming the problem. Before that version, an invalid schema was silently ignored and the agent returned unstructured text — and any schema containing `"format"` was itself treated as invalid.

## Error handling

`ResultMessage.subtype`:

| Subtype | Meaning |
|---|---|
| `success` | Output generated and validated — but may still lack `structured_output` if the run completed without producing one; treat that as failure too |
| `error_max_structured_output_retries` | No valid output after retries (validation failures), **or** a model-fallback retraction of an already-completed output with no successful retry — check the result's `errors` list to distinguish the two before debugging your schema |

```typescript
if (msg.type === "result") {
  if (msg.subtype === "success" && msg.structured_output) { /* use it */ }
  else if (msg.subtype === "error_max_structured_output_retries") { console.error("Could not produce valid output"); }
  else { console.error("Run ended without a structured output"); }
}
```

Tips to avoid errors: keep schemas focused (deep nesting and many required fields are harder to satisfy); make fields optional if the task might not surface all the information; write unambiguous prompts.

## Composing with multi-step tool use

Structured outputs are not limited to single-turn extraction. The documented TODO-extraction example has the agent autonomously choose Grep (search) plus Bash (`git blame`), then return one combined structured response — schema pattern `todos: array of {text, file, line, author?, date?}` plus `total_count`, with `author`/`date` optional because blame may not resolve for every item.

## Sources

- https://code.claude.com/docs/en/agent-sdk/structured-outputs

Fetched: 2026-08-05
