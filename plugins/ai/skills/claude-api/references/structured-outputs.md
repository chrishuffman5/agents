# Structured Outputs and Strict Tool Use

Read when the response must be machine-parseable, or when tool inputs must validate against a schema.

## Two complementary features

> Source: https://platform.claude.com/docs/en/build-with-claude/structured-outputs

1. **JSON outputs** — `output_config.format` constrains the entire response to a JSON Schema.
2. **Strict tool use** — `"strict": true` on a tool definition guarantees the call's `input` validates against `input_schema`.

Use the first when you want data back; use the second when you want a reliable call into your own code. They compose.

Supported models: `claude-opus-5`, `claude-opus-4-8`, `claude-opus-4-7`, `claude-opus-4-6`, `claude-sonnet-5`, `claude-sonnet-4-6`, `claude-sonnet-4-5-20250929`, `claude-haiku-4-5-20251001`, `claude-mythos-5`, `claude-mythos-preview`, `claude-opus-4-5-20251101`. Available on the Claude API, Claude Platform on AWS, Amazon Bedrock, Google Cloud, and Microsoft Foundry — notably broader platform coverage than the server tools.

## JSON output

> Source: https://platform.claude.com/docs/en/build-with-claude/structured-outputs

```json
{
  "output_config": {
    "format": {
      "type": "json_schema",
      "schema": {
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "email": {"type": "string"},
          "demo_requested": {"type": "boolean"}
        },
        "required": ["name", "email", "demo_requested"],
        "additionalProperties": false
      }
    }
  }
}
```

Claude returns valid JSON matching the schema directly in the text content block — no wrapper object, no retry loop for schema violations. Delete any "respond only with JSON" prompt scaffolding and post-hoc repair code once this is enabled.

## JSON Schema support matrix

> Source: https://platform.claude.com/docs/en/build-with-claude/structured-outputs

**Supported**: `object`, `array`, `string`, `integer`, `number`, `boolean`, `null`; `enum`; `const`; `anyOf`; `allOf`; `$ref` / `$def` / `definitions`; string `format` values `date-time`, `time`, `date`, `email`, `uri`, `ipv4`, `uuid`; array `minItems` (only 0 or 1); `required`; `additionalProperties: false`.

**Not supported**: recursive schemas; numeric constraints (`minimum`, `maximum`, `multipleOf`); string length constraints (`minLength`, `maxLength`); `additionalProperties` set to anything other than `false`; external `$ref` URLs; complex types inside `enum`.

Design to the supported subset and enforce the rest in your code. A schema using `minimum` or `maxLength` is not a working guardrail here — validate those server-side after parsing.

## Strict tool use

> Source: https://platform.claude.com/docs/en/build-with-claude/structured-outputs

```json
{
  "tools": [{
    "name": "search_flights",
    "strict": true,
    "input_schema": {
      "type": "object",
      "properties": {"destination": {"type": "string"}, "date": {"type": "string", "format": "date"}},
      "required": ["destination", "date"],
      "additionalProperties": false
    }
  }]
}
```

The same schema subset applies. Strict mode composes with `defer_loading` (tool search) without recompilation, because the grammar is built from the full toolset.

## SDK helpers

> Source: https://platform.claude.com/docs/en/build-with-claude/structured-outputs

| Language | Helper |
|---|---|
| Python / TypeScript | `client.messages.parse()` with Pydantic models or Zod schemas (`zodOutputFormat()`) |
| Java | `outputConfig(Class<T>)` |
| Ruby | `Anthropic::BaseModel` + `output_config: {format: Model}` |
| PHP | Classes implementing `StructuredOutputModel` |
| C# | Generic `Create<T>()` |
| Go | Raw JSON schema via `OutputConfigParam` |

Schema-grammar compilation is cached automatically for **24 hours**, so repeated requests with the same schema do not re-pay the compile cost. Keep schemas stable rather than generating them per request.

## Sources

- https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool

Fetched: 2026-08-05
