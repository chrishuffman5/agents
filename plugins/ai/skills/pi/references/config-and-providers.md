# pi: Configuration, Environment, and Providers

Read this when a setting isn't applying, when wiring a custom or local model endpoint, or when auditing what pi reads from the environment.

## Settings files and precedence

> Source: https://pi.dev/docs/latest/settings

| Location | Scope |
|---|---|
| `~/.pi/agent/settings.json` | Global (all projects) |
| `.pi/settings.json` | Project (current directory) |

Project overrides global. Nested objects are **deep-merged**, not replaced — a project file that sets one key inside `compaction` keeps the global values for the others:

```json
// Global
{ "theme": "dark", "compaction": { "enabled": true, "reserveTokens": 16384 } }
// Project
{ "compaction": { "reserveTokens": 8192 } }
// Result
{ "theme": "dark", "compaction": { "enabled": true, "reserveTokens": 8192 } }
```

Note the project file only loads for a **trusted** project (see `security-and-exclusions.md`).

Common top-level properties:

```json
{
  "defaultProvider": "anthropic",
  "defaultModel": "claude-sonnet-4-20250514",
  "defaultThinkingLevel": "medium",
  "theme": "dark",
  "compaction": {
    "enabled": true,
    "reserveTokens": 16384,
    "keepRecentTokens": 20000
  },
  "retry": {
    "enabled": true,
    "maxRetries": 3,
    "baseDelayMs": 2000,
    "provider": {
      "timeoutMs": 3600000,
      "maxRetries": 0,
      "maxRetryDelayMs": 60000
    }
  }
}
```

Other documented arrays that live in the same file: `extensions`, `packages`, `prompts`, `themes` (see `extensions.md` and `resources-and-packages.md`).

Edit the file directly, or use `/settings` in interactive mode for common options.

## models.json — custom models and providers

> Source: https://pi.dev/docs/latest/models
> Source: https://pi.dev/docs/latest/custom-provider

Location: `~/.pi/agent/models.json`. Provider-keyed structure:

```json
{
  "providers": {
    "provider-name": {
      "baseUrl": "API endpoint",
      "api": "API type",
      "apiKey": "authentication",
      "models": []
    }
  }
}
```

Supported `api` values:

| Value | Use for |
|---|---|
| `openai-completions` | Most compatible; the default choice for Ollama, LM Studio, vLLM, and OpenAI-compatible gateways |
| `openai-responses` | OpenAI Responses-style endpoints |
| `anthropic-messages` | Anthropic Messages-shaped endpoints |
| `google-generative-ai` | Google Generative AI-shaped endpoints |

Model identity: the configured `id` field drives `/model` listings, `--model` pattern matching, and status displays. `name` is a human-readable secondary label only.

Thinking levels: models supporting extended thinking define a `thinkingLevelMap` covering pi's seven levels (`off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`). Each level maps to a provider-specific string, is omitted (provider default), or is set `null` to hide an unsupported level from the UI. A model supporting only off/high/max sets `minimal`, `low`, and `medium` to `null`.

Composition order, quoted: "Pi composes `models.json` overrides above registered native providers" — so a `models.json` entry takes precedence over a provider registered natively or via an extension's `pi.registerProvider()`.

**Unverified:** the fetched pages do not publish a field-by-field JSON schema for `models.json` (required vs optional fields beyond the above, validation rules). The `custom-provider` page emphasizes programmatic `pi.registerProvider()` registration instead. Do not assert field requirements that are not shown here.

## Environment variables

> Source: https://pi.dev/docs/latest/environment-variables

**Injected into commands run by pi's bash tool** — useful for scripts and hooks that need to know their own session:

| Var | Purpose |
|---|---|
| `PI_SESSION_ID` | Current session ID |
| `PI_SESSION_FILE` | Absolute path to the session JSONL file; **unset for ephemeral sessions** |
| `PI_PROVIDER` | Currently selected provider |
| `PI_MODEL` | Currently selected model ID |
| `PI_REASONING_LEVEL` | Effective reasoning level (off … max) |

**Read by pi at startup:**

| Var | Purpose |
|---|---|
| `PI_CODING_AGENT_DIR` | Override config directory (default `~/.pi/agent`) |
| `PI_CODING_AGENT_SESSION_DIR` | Override session storage location |
| `PI_PACKAGE_DIR` | Override the package directory |
| `PI_OFFLINE` | Disable startup network operations, including update checks |
| `PI_SKIP_VERSION_CHECK` | Disable version-check requests |
| `PI_TELEMETRY` | Override telemetry settings |
| `PI_CACHE_RETENTION` | `long` enables extended provider prompt caching |
| `PI_SHARE_VIEWER_URL` | Override the base URL used by `/share` |
| `PI_HARDWARE_CURSOR` | `1` shows the hardware cursor |
| `VISUAL`, `EDITOR` | External editor fallback when the `externalEditor` setting is unset |
| `HTTP_PROXY`, `HTTPS_PROXY` | Proxy outbound requests |

**Process marker:** `PI_CODING_AGENT` is set to `true` by the CLI/RPC so a script can detect it is running inside pi.

For restricted networks, combine `HTTPS_PROXY` with `PI_OFFLINE`. `PI_TELEMETRY` is documented only as "override telemetry settings" — the accepted values and what is collected were not on the fetched pages; treat specifics as unverified.

## Providers

> Source: https://pi.dev/docs/latest/providers

Enumerated on the providers page: Anthropic, OpenAI, Azure OpenAI, DeepSeek, NVIDIA NIM, Google Gemini, Amazon Bedrock, Mistral, Groq, Cerebras, Cloudflare (AI Gateway & Workers AI), xAI, OpenRouter, Hugging Face, Fireworks, Together AI — plus regional providers Qwen, Xiaomi, MiniMax, Kimi. The GitHub README's "40+ supported providers" counts individual regional/local variants; prefer this enumerated list when answering "is X supported".

Documented API-key environment variables:

| Provider | Env var |
|---|---|
| Anthropic | `ANTHROPIC_API_KEY` |
| OpenAI | `OPENAI_API_KEY` |
| Azure OpenAI | `AZURE_OPENAI_API_KEY` |
| DeepSeek | `DEEPSEEK_API_KEY` |
| Google Gemini | `GEMINI_API_KEY` |
| Amazon Bedrock | `AWS_BEARER_TOKEN_BEDROCK` |
| Groq | `GROQ_API_KEY` |
| OpenRouter | `OPENROUTER_API_KEY` |
| xAI | `XAI_API_KEY` |

Variables for the providers not listed here were not documented on the fetched page — check `/login` or the provider's own docs rather than guessing.

Subscription logins (Claude Pro/Max, ChatGPT Plus/Pro, GitHub Copilot) go through `/login` and are stored in `~/.pi/agent/auth.json`.

## Adding a custom provider

> Source: https://pi.dev/docs/latest/providers

Two methods:

1. **`models.json`** — "Add Ollama, LM Studio, vLLM, or any provider that speaks a supported API (OpenAI Completions, OpenAI Responses, Anthropic Messages, Google Generative AI)."
2. **Extension** — for providers needing custom API implementations or OAuth flows, register programmatically with `pi.registerProvider(name, config)` (see `extensions.md`).

Use method 1 whenever the endpoint is API-compatible; it is declarative and requires no executable code. Method 2 means shipping code that runs with full user privileges.

## Switching models

> Source: https://pi.dev/docs/latest/providers

| Surface | Mechanism |
|---|---|
| TUI | `/model`, `/login <provider>`, `/logout` |
| CLI | `--provider`, `--model <provider/id:thinking>`, `--thinking`, `--models` (Ctrl+P cycle set) |
| RPC | `{"type":"set_model","provider":"anthropic","modelId":"claude-sonnet-4-20250514"}` |
| SDK | `session.setModel()`, `session.cycleModel()` |

Model switches are recorded in the session file as a `ModelChangeEntry`, so a transcript shows exactly which model produced which turn.

## Sources

- https://pi.dev/docs/latest/settings
- https://pi.dev/docs/latest/environment-variables
- https://pi.dev/docs/latest/models
- https://pi.dev/docs/latest/custom-provider
- https://pi.dev/docs/latest/providers
- https://pi.dev/docs/latest/quickstart
- https://pi.dev/docs/latest/session-format

Fetched: 2026-08-05
