# Version-gated behavior — Python `openai-agents` 0.19.x (and the JS package as of 2026-08-05)

Read this first when a documented feature "doesn't exist" in the user's install, when an import fails, or when a dependency-resolution conflict appears.

## Python package baseline

> Source: https://raw.githubusercontent.com/openai/openai-agents-python/main/pyproject.toml, https://openai.github.io/openai-agents-python/quickstart/

Observed on `main` on 2026-08-05:

- Version pinned in `pyproject.toml`: **0.19.4**
- `requires-python = ">=3.10"`

Runtime dependency floors — a resolver conflict against any of these is the first thing to check when an import or model call fails in an old environment:

| Dependency | Constraint | Why it matters |
|---|---|---|
| `openai` | `>=2.45.0,<3` | the Responses API surface the SDK calls |
| `pydantic` | `>=2.12.2,<3` | tool-schema generation and `output_type` |
| `griffelib` | `>=2,<3` | docstring parsing for tool descriptions |
| `typing-extensions` | `>=4.12.2,<5` | – |
| `requests` | `>=2.0,<3` | – |
| `websockets` | `>=15.0,<17` | realtime WebSocket transport |
| `mcp` | `>=1.19.0,<3` (Python >=3.10) | MCP client transports |

Optional extras: `[voice]` (STT/TTS pipeline), `[redis]` (`RedisSession`), `[litellm]` (`LitellmModel`), `[any-llm]` (`AnyLLMModel`).

## JS package baseline

> Source: https://github.com/openai/openai-agents-js, https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/quickstart.mdx

- Runtimes: **Node.js 22+**, Deno, Bun. Cloudflare Workers is **experimental** and requires `nodejs_compat`.
- **Zod v4** is required for tool schemas and structured outputs — a project pinned to Zod v3 will fail here, and this is the single most common install-time break.
- Repo layout (pnpm workspace monorepo): `packages/`, `examples/`, `docs/` (Astro/Starlight `.mdx`), `integration-tests/`, `helpers/`.

## Model defaults observed on this date

> Source: https://openai.github.io/openai-agents-python/models/

With no `model` set, agents default to **`gpt-5.4-mini`** with `reasoning.effort="none"` and `verbosity="low"`. Override globally with `OPENAI_DEFAULT_MODEL`, per-run with `RunConfig(model=...)`, or per-agent. Realtime agents document **`gpt-realtime-2.1`**; computer-use examples document **`gpt-5.4`**.

Do not restate these defaults as permanent — verify against the user's installed version before debugging a "wrong model" report.

## Feature gates

| Feature | Requires |
|---|---|
| Deferred tool loading (`defer_loading` / `deferLoading` + tool search) | GPT-5.4+ **and** the Responses API; rejected by Chat Completions and the AI SDK adapter |
| Hosted tools (web/file search, code interpreter, image generation, tool search, programmatic tool calling) | `OpenAIResponsesModel` |
| JS function-tool `outputSchema`, `allowedCallers` | Responses API only |
| `conversationId` / `previousResponseId` | Responses API (and Conversations API for `conversationId`) |
| Structured Outputs | `gpt-4o-mini` and later (platform-level requirement) |
| `toolChoice: 'computer'` selecting the GA built-in computer tool | `computerTool()` on OpenAI Responses; older preview selectors still accepted for legacy integrations |
| Browser WebRTC realtime | TypeScript SDK only — Python realtime is server WebSocket only |
| `VoicePipeline` (STT→agent→TTS) | Python only, `openai-agents[voice]` |
| Tool-level guardrails | documented for the TypeScript SDK |
| `await using` MCP disposal | `esnext.disposable` in `tsconfig.json` |

## Naming instability to watch

> Source: https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/quickstart.md, https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/tools.md

Every current Python doc page fetched on 2026-08-05 (`quickstart.md`, `tools.md`, `human_in_the_loop.md`) shows the tool decorator as **`@tool` imported from `agents.decorators`**.

> Unverified: whether `@function_tool` still exists in the package as a separate, more configurable decorator. This could not be confirmed against the SDK source or changelog in this pass. If a user's code imports `@function_tool`, check their installed version rather than asserting it was removed or renamed.

`RunItemStreamEvent.name` includes `handoff_occured` — misspelled deliberately for backward compatibility. Do not "fix" it in user code.

## Sources

- https://raw.githubusercontent.com/openai/openai-agents-python/main/pyproject.toml
- https://openai.github.io/openai-agents-python/quickstart/
- https://openai.github.io/openai-agents-python/models/
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/quickstart.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/tools.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/human_in_the_loop.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/streaming.md
- https://github.com/openai/openai-agents-js
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/quickstart.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/tools.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/mcp.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/agents.mdx
- https://developers.openai.com/api/docs/guides/structured-outputs

Fetched: 2026-08-05
