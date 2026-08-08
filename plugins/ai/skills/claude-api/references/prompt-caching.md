# Prompt Caching

Read when cutting cost or latency on repeated prefixes, or when a cache hit rate is unexpectedly zero.

## How it works

> Source: https://platform.claude.com/docs/en/build-with-claude/prompt-caching

The API checks for a cached prefix match, uses it if found, and otherwise processes the full prompt and caches the prefix once the response begins. Default lifetime is **5 minutes**; a **1-hour** TTL costs 2x base input on the write.

Supported on all active models: Opus 5/4.8/4.7/4.6/4.5, Sonnet 5/4.6/4.5, Haiku 4.5, Fable 5, Mythos 5.

A cache entry only becomes usable once the response that created it begins — it can never be hit within the same request that writes it.

## Minimum cacheable tokens

> Source: https://platform.claude.com/docs/en/build-with-claude/prompt-caching

Prompts below the minimum are **silently not cached** — no error, no warning.

| Model | Minimum tokens |
|---|---|
| Opus 5, Fable 5, Mythos 5 | 512 |
| Opus 4.8, Sonnet 5, Sonnet 4.6, Sonnet 4.5 | 1,024 |
| Opus 4.7 | 2,048 |
| Opus 4.6, Opus 4.5 | 4,096 |
| Haiku 4.5 | 4,096 |
| Haiku 3.5 | 2,048 |

Always confirm caching actually happened by reading `cache_creation_input_tokens` and `cache_read_input_tokens` from `usage`. Never assume it worked because the parameter was present.

## Breakpoints and TTL

> Source: https://platform.claude.com/docs/en/build-with-claude/prompt-caching

Up to **4 cache breakpoints** per request, allowing independently cached sections.

```json
// 5-minute (default, included in base pricing)
"cache_control": { "type": "ephemeral" }

// 1-hour (2x base input token price for the write)
"cache_control": { "type": "ephemeral", "ttl": "1h" }
```

## Automatic vs explicit

> Source: https://platform.claude.com/docs/en/build-with-claude/prompt-caching

**Automatic** — one top-level `cache_control`; the system places the breakpoint on the last cacheable block. Recommended for multi-turn conversations:

```json
{
  "model": "claude-opus-5",
  "max_tokens": 1024,
  "cache_control": {"type": "ephemeral"},
  "system": "You are a helpful assistant.",
  "messages": [{"role": "user", "content": "What are the key themes in Pride and Prejudice?"}]
}
```

**Explicit** — `cache_control` on individual content blocks, for caching independent sections:

```json
{
  "model": "claude-opus-5",
  "max_tokens": 1024,
  "system": [
    {"type": "text", "text": "You are an AI assistant analyzing literary works.", "cache_control": {"type": "ephemeral"}}
  ],
  "messages": [{"role": "user", "content": "Analyze Pride and Prejudice."}]
}
```

## Usage accounting

> Source: https://platform.claude.com/docs/en/build-with-claude/prompt-caching

| Field | Meaning |
|---|---|
| `cache_creation_input_tokens` | Tokens newly written to cache |
| `cache_read_input_tokens` | Tokens served from a hit |
| `input_tokens` | Tokens **after the last breakpoint** — the uncached remainder |

```
total_input_tokens = cache_read_input_tokens + cache_creation_input_tokens + input_tokens
```

Example: `{"input_tokens":50,"cache_read_input_tokens":100000,"cache_creation_input_tokens":0,"output_tokens":503}` — 100,000 tokens from cache, 50 new, total input 100,050. Note that `input_tokens` alone badly understates the request, so cost dashboards must sum all three.

## Practices

> Source: https://platform.claude.com/docs/en/build-with-claude/prompt-caching

- Use automatic caching for multi-turn conversations.
- Place breakpoints on static content: system prompts, tool definitions, large context documents, the conversation-history prefix.
- Keep the breakpoint on the last block that is identical across requests — any byte of drift above it is a full miss.
- `cache_read_input_tokens` do **not** count toward ITPM on any current model except Haiku 3.5, which does count them. This makes caching a throughput lever, not just a discount.
- Batches stack with caching, but hits are best-effort because processing is concurrent — see `batches-and-files.md`.
- Anything rendered into the prompt invalidates breakpoints when it changes, including `effort` and `budget_tokens` (see `thinking-and-effort.md`). Freeze them for the life of a cached session.

## Sources

- https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- https://platform.claude.com/docs/en/api/rate-limits

Fetched: 2026-08-05
