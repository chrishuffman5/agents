# Tool Use: Custom Tools, `tool_choice`, and the Tool Search Tool

Read when defining tools, debugging a `tool_use`/`tool_result` round trip, or when a large tool catalog is eating context.

## Tool categories

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview

- **Client tools** run in your application. This covers your own custom tools (you supply `input_schema`) *and* Anthropic-schema tools you still execute yourself: `bash`, `text_editor`, `computer`, `memory`. Claude returns `stop_reason: "tool_use"` with one or more `tool_use` blocks; you execute and reply with `tool_result`.
- **Server tools** run on Anthropic's infrastructure with no handler code: `web_search`, `web_fetch`, `code_execution`, `tool_search`, `advisor`, and the MCP connector. Their results appear directly in the response — unless a server tool is called in the same parallel batch as a client tool, in which case the turn returns for your client tool first.

## Custom tool definition

```json
{
  "name": "get_weather",
  "description": "Get the current weather for a given location.",
  "input_schema": {
    "type": "object",
    "properties": {
      "location": {"type": "string", "description": "City and state, e.g. San Francisco, CA"}
    },
    "required": ["location"]
  }
}
```

Add `"strict": true` to guarantee the emitted call matches the schema exactly (see `structured-outputs.md`).

## The round trip

Request 1 carries `tools` and `tool_choice`:

```json
{
  "model": "claude-opus-5",
  "max_tokens": 1024,
  "tools": [ /* tool defs */ ],
  "tool_choice": {"type": "auto", "disable_parallel_tool_use": true},
  "messages": [{"role": "user", "content": "What's the weather in San Francisco?"}]
}
```

Claude replies with a `tool_use` block:

```json
{"type": "tool_use", "id": "toolu_01A09q90qw90lq917835lq9", "name": "get_weather", "input": {"location": "San Francisco, CA"}}
```

Execute it, then append the assistant content **unchanged** plus a `tool_result`:

```json
{
  "messages": [
    {"role": "user", "content": "What's the weather in San Francisco?"},
    {"role": "assistant", "content": [ /* same content array Claude returned */ ]},
    {"role": "user", "content": [
      {"type": "tool_result", "tool_use_id": "toolu_01A09q90qw90lq917835lq9", "content": "15 degrees Celsius, partly cloudy"}
    ]}
  ]
}
```

The SDKs ship a **Tool Runner** helper that executes your tools and returns results automatically — prefer it to hand-rolled loop code.

## `tool_choice`

| Value | Effect |
|---|---|
| `{"type":"auto"}` | Default — Claude decides |
| `{"type":"any"}` | Must call some tool |
| `{"type":"tool","name":"..."}` | Force a specific tool |
| `{"type":"none"}` | No tool calls |

`disable_parallel_tool_use: true` restricts Claude to at most one tool call per turn. Note that `any`/`tool` raise the tool-use system-prompt overhead (see `models-and-pricing.md`).

Steer frequency through the system prompt, not the schema: "Use the tools to investigate before responding" nudges calls up; "Use your judgment about whether to call a tool" keeps them conservative.

When a required parameter is missing from the user's prompt, Opus is more likely to ask for clarification while Sonnet may guess a plausible value — documented as a tendency, not a guarantee. Mark parameters `required` and validate server-side rather than relying on the model to ask.

## Tool search tool

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool

Lets Claude discover and load only the tools it needs from a large catalog. A 5-server MCP setup (GitHub/Slack/Sentry/Grafana/Splunk) can burn ~55k tokens in definitions before any work happens; tool search typically cuts that by >85%, loading the 3–5 tools actually needed. Selection accuracy degrades past 30–50 available tools and stays high with search even across thousands.

**Use it when**: 10+ tools available, definitions >10k tokens, accuracy dropping, aggregating 200+ MCP tools, or a growing library. **Skip it** for <10 tools, tools used on every request, or definitions totaling <100 tokens.

Two variants:

| Variant | Type string | Query style | Limit |
|---|---|---|---|
| Regex | `tool_search_tool_regex_20251119` | Python `re.search()` patterns, case-insensitive (`"get_.*_data"`) | 200-char pattern |
| BM25 | `tool_search_tool_bm25_20251119` | Natural-language queries | 500-char query |

Model compatibility (both variants): Fable 5, Mythos 5, Opus 5, Opus 4.8, Opus 4.7, Opus 4.6, Sonnet 4.6, Opus 4.5 (`claude-opus-4-5-20251101`), Sonnet 4.5 (`claude-sonnet-4-5-20250929`), Haiku 4.5 (`claude-haiku-4-5-20251001`). Opus 4.1 and earlier do **not** support it. Generally available on the Claude API. On Amazon Bedrock, server-side tool search works only via **InvokeModel**, not Converse; on Claude Platform on AWS it behaves exactly like the Claude API.

### How it works

1. Include the tool search tool in `tools`.
2. Include **every** tool's full definition in `tools`, marking the ones that should not load upfront with `defer_loading: true`.
3. Claude's initial context holds only the search tool plus non-deferred tools.
4. Claude searches; the API returns up to 5 matches as `tool_reference` blocks and auto-expands them into full definitions.
5. Claude calls the discovered tool.

```json
{
  "model": "claude-opus-5",
  "max_tokens": 2048,
  "messages": [{"role": "user", "content": "What is the weather in San Francisco?"}],
  "tools": [
    {"type": "tool_search_tool_regex_20251119", "name": "tool_search_tool_regex"},
    {
      "name": "get_weather",
      "description": "Get the weather at a specific location",
      "input_schema": {"type": "object", "properties": {"location": {"type": "string"}, "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}}, "required": ["location"]},
      "defer_loading": true
    }
  ]
}
```

### Rules

- You still send every definition on every request — the API needs them server-side to run the search and expand references. `defer_loading` controls context, not payload.
- **Never** set `defer_loading: true` on the search tool itself; at least one tool must stay non-deferred or the request 400s ("At least one tool must have defer_loading=false").
- Keep your 3–5 most-used tools non-deferred.
- A `defer_loading: true` tool **cannot** carry `cache_control` (400). Put the breakpoint on a non-deferred tool. Deferred tools are excluded from the system-prompt prefix, so prefix caching survives; discovered references are appended inline.
- Search covers tool names, descriptions, argument names, and argument descriptions — write descriptions that contain the words a query would use.
- Strict-mode grammar builds from the full toolset, so `defer_loading` composes with `strict` without recompilation.
- For MCP tools, set `defer_loading` on the `mcp_toolset` `default_config` or per-tool `configs`, never per-tool in the top-level array.

### Response and errors

```json
{
  "content": [
    {"type": "server_tool_use", "id": "srvtoolu_01ABC123", "name": "tool_search_tool_regex", "input": {"pattern": "weather"}},
    {"type": "tool_search_tool_result", "tool_use_id": "srvtoolu_01ABC123",
     "content": {"type": "tool_search_tool_search_result", "tool_references": [{"type": "tool_reference", "tool_name": "get_weather"}]}},
    {"type": "tool_use", "id": "toolu_01XYZ789", "name": "get_weather", "input": {"location": "San Francisco", "unit": "fahrenheit"}}
  ],
  "stop_reason": "tool_use"
}
```

Never return a `tool_result` for the search's `srvtoolu_...` ID — the API rejects it. Pass the assistant content back unchanged, adding only the `tool_result` for the discovered tool. An empty `tool_references` array means no match, not an error.

Tool-result-level errors arrive with HTTP 200: `error_code` in `invalid_tool_input`, `unavailable`, `too_many_requests`, `execution_time_exceeded`. HTTP 400s: all tools deferred, or `tool_reference` naming a tool absent from `tools`.

Limits: max 10,000 deferred tools per request; up to 5 matches returned per search by default.

Billing: tool search is not metered as a server tool (no `usage.server_tool_use` entry); the definitions it loads count as ordinary input tokens.

### Custom client-side tool search

Implement your own retrieval (e.g. embeddings) by returning `tool_reference` blocks from your own tool's result:

```json
{"type": "tool_result", "tool_use_id": "toolu_your_tool_id", "content": [{"type": "tool_reference", "tool_name": "discovered_tool_name"}]}
```

Every referenced tool still needs a full definition in the top-level `tools` array, normally with `defer_loading: true`.

## Sources

- https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool
- https://platform.claude.com/docs/en/about-claude/pricing

Fetched: 2026-08-05
