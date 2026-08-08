# Structured Outputs

Read when you need schema-guaranteed JSON, when a schema is being rejected, or when porting a `response_format` schema off Chat Completions.

## What it guarantees

> Source: https://developers.openai.com/api/docs/guides/structured-outputs

"Structured Outputs is a feature that ensures the model will always generate responses that adhere to your supplied JSON Schema."

Benefits per the docs: reliable type-safe parsing, programmatically detectable safety refusals via a `refusal` field, and simpler prompting — no hand-engineered formatting instructions.

This is a hard guarantee about *shape*, not about *correctness*. A schema-valid response can still be wrong. Validate business rules in code; do not encode them as schema constraints you expect the model to reason about.

## Enabling it

> Source: https://developers.openai.com/api/docs/guides/structured-outputs

Responses API:

```
text: { format: { type: "json_schema", "strict": true, "schema": ... } }
```

Chat Completions used `response_format`. Moving a schema across without renaming the parameter silently drops the guarantee.

Prefer the SDK helpers so schema and types cannot drift:

```python
response = client.responses.parse(
    model="gpt-5.6",
    input=[...],
    text_format=YourModel,          # Pydantic
)
```

```javascript
const response = await openai.responses.parse({
    model: "gpt-5.6",
    input: [...],
    text: { format: zodTextFormat(YourSchema, "schema_name") },   // Zod
});
```

## Strict-mode schema requirements

> Source: https://developers.openai.com/api/docs/guides/structured-outputs

- **Every property required.** There are no optional properties — output semantics differ from input semantics.
- `additionalProperties: false` is **mandatory on every object**, not only the root.
- Only the supported JSON Schema subset is valid.

Model an optional value as a nullable union (`"type": ["string", "null"]`) kept in `required`. Dropping it from `required` is the single most common rejection.

## Supported types and constraints

> Source: https://developers.openai.com/api/docs/guides/structured-outputs

| Category | Supported |
|---|---|
| Types | string, number, boolean, integer, object, array, enum, `anyOf` |
| String | `pattern`, `format` (date-time, email, uuid, and others) |
| Number | `minimum`, `maximum`, `multipleOf`, `exclusiveMinimum`, `exclusiveMaximum` |
| Array | `minItems`, `maxItems` |

**Unsupported keywords — these are rejected, not degraded:** `allOf`, `not`, `dependentRequired`, `if`/`then`/`else`.

`allOf` is the one that bites schema-generation tooling: many JSON Schema generators emit `allOf` for inheritance or composition. Flatten composed schemas before submitting.

## Limits

> Source: https://developers.openai.com/api/docs/guides/structured-outputs

| Limit | Value |
|---|---|
| Root schema type | must be an object — **not** `anyOf` at the root |
| Total object properties | 5,000 |
| Nesting depth | 10 levels |
| Schema string size | 120,000 characters |
| Enum values across all properties | 1,000 combined |

The enum cap is combined across the whole schema, not per property — a schema with several large category enums hits it faster than expected.

Run `scripts/validate-strict-schema.py` against a schema before shipping it; it checks all of the above offline.

## Refusals

> Source: https://developers.openai.com/api/docs/guides/structured-outputs

```javascript
if (item.type == "refusal") { console.log(item.refusal); }
```

Safety refusals surface as a `refusal` field/item **instead of** a schema-conforming payload. Code that assumes the schema shape always arrives will throw on a refusal.

## Model compatibility

> Source: https://developers.openai.com/api/docs/guides/structured-outputs

Supported: `gpt-4o-mini`, `gpt-4o-2024-08-06`, `gpt-5.6`, and later.

Not supported: `gpt-3.5-turbo`, `gpt-4-turbo` — those must use legacy JSON mode, which has no guarantee.

## Best practices

> Source: https://developers.openai.com/api/docs/guides/structured-outputs

- Prefer SDK-native Pydantic/Zod integration over hand-written schema strings.
- Include explicit instructions for how the model should behave on incompatible or edge-case inputs — the schema forces a shape, so without guidance the model will invent plausible values rather than signalling "unknown."
- Test schemas with evals to tune generation quality (see the `evals` skill).
- Handle three distinct terminal cases separately: incomplete responses (`incomplete_details.reason: "max_output_tokens"`), refusals, and content-filter terminations.

## Streaming

> Source: https://developers.openai.com/api/docs/guides/structured-outputs

Structured Outputs works with streaming through SDK helpers that support incremental field parsing, so you can render fields as they arrive rather than waiting for the full response.

## Sources

- https://developers.openai.com/api/docs/guides/structured-outputs

Fetched: 2026-08-05
