# Rate Limits, Spend Tiers, and Token Counting

Read when sizing throughput, diagnosing 429s, or pre-flighting request size.

## Rate limit model

> Source: https://platform.claude.com/docs/en/api/rate-limits

Two independent controls: **spend limits** (max monthly USD an org can incur) and **rate limits** (requests and tokens over a window). Limits are set at the org level by usage tier; new orgs may start in an "Evaluation" tier below standard limits.

Limits use a **token-bucket** algorithm — capacity replenishes continuously rather than resetting on the minute. A "60 RPM" limit can behave like ~1 request/second, so a burst can 429 even when the per-minute average is under the limit. Smooth your request rate; do not batch-fire at the start of each minute.

Rate limits are per model — different models do not share a bucket, except where the tables below combine a generation. Limits are shared across `inference_geo` values: `"us"` and `"global"` draw from the same pool.

### Monthly spend caps

| Tier | Cap |
|---|---|
| Start | $500 |
| Build | $1,000 |
| Scale | $200,000 |
| Custom | No cap (negotiated) |

### Cache-aware ITPM — the main throughput lever

Only **uncached** input counts toward ITPM on most models:

- `input_tokens` (after the last breakpoint) → counts
- `cache_creation_input_tokens` → counts
- `cache_read_input_tokens` → does **not** count. Exception: **Claude Haiku 3.5** does count cache reads.

A 2,000,000 ITPM limit with an 80% hit rate effectively processes ~10,000,000 input tokens/minute (2M counted uncached + 8M free cached).

OTPM is evaluated in real time against tokens actually generated — `max_tokens` does not affect OTPM accounting, so there is no rate-limit reason to set it low.

## Messages API limits by tier

> Source: https://platform.claude.com/docs/en/api/rate-limits

**Start tier**

| Model | RPM | ITPM | OTPM |
|---|---|---|---|
| Claude Fable 5 | 1,000 | 500,000 | 100,000 |
| Claude Opus 5 | 1,000 | 2,000,000 | 400,000 |
| Claude Opus 4.x* | 1,000 | 2,000,000 | 400,000 |
| Claude Sonnet 5 | 1,000 | 2,000,000 | 400,000 |
| Claude Sonnet 4.x** | 1,000 | 2,000,000 | 400,000 |
| Claude Haiku 4.5 | 1,000 | 2,000,000 | 400,000 |
| Claude Haiku 3.5† | 1,000 | 100,000 | 20,000 |

**Build tier**

| Model | RPM | ITPM | OTPM |
|---|---|---|---|
| Claude Fable 5 | 2,000 | 1,500,000 | 300,000 |
| Claude Opus 5 | 5,000 | 5,000,000 | 1,000,000 |
| Claude Opus 4.x* | 5,000 | 5,000,000 | 1,000,000 |
| Claude Sonnet 5 | 5,000 | 5,000,000 | 1,000,000 |
| Claude Sonnet 4.x** | 5,000 | 5,000,000 | 1,000,000 |
| Claude Haiku 4.5 | 5,000 | 5,000,000 | 1,000,000 |
| Claude Haiku 3.5† | 2,000 | 200,000 | 40,000 |

**Scale tier**

| Model | RPM | ITPM | OTPM |
|---|---|---|---|
| Claude Fable 5 | 4,000 | 4,000,000 | 800,000 |
| Claude Opus 5 | 10,000 | 10,000,000 | 2,000,000 |
| Claude Opus 4.x* | 10,000 | 10,000,000 | 2,000,000 |
| Claude Sonnet 5 | 10,000 | 10,000,000 | 2,000,000 |
| Claude Sonnet 4.x** | 10,000 | 10,000,000 | 2,000,000 |
| Claude Haiku 4.5 | 10,000 | 10,000,000 | 2,000,000 |
| Claude Haiku 3.5† | 4,000 | 400,000 | 80,000 |

\* Opus 4.x is a **combined** bucket across Opus 4.8/4.7/4.6/4.5; Opus 5 has its own.
\*\* Sonnet 4.x is a combined bucket across Sonnet 4.6/4.5; Sonnet 5 has its own.
† Haiku 3.5 counts `cache_read_input_tokens` toward ITPM, unlike every other model.

Note Fable 5's markedly lower ITPM at every tier — plan Fable 5 throughput separately rather than assuming parity with Opus 5.

Custom tier limits above Scale are negotiated with sales.

### Message Batches API limits (shared across models)

| Tier | RPM | Max batch requests in processing queue | Max requests per batch |
|---|---|---|---|
| Start | 1,000 | 200,000 | 100,000 |
| Build | 2,000 | 300,000 | 100,000 |
| Scale | 4,000 | 500,000 | 100,000 |

### Claude Managed Agents

Create endpoints (agents/sessions/environments) 300 req/min; read endpoints (retrieve/list/stream) 1,200 req/min. Separate pool from the Messages API.

## Response headers

> Source: https://platform.claude.com/docs/en/api/rate-limits

| Header | Meaning |
|---|---|
| `retry-after` | Seconds to wait before retrying |
| `anthropic-ratelimit-requests-limit` / `-remaining` / `-reset` | Request-count status (reset in RFC 3339) |
| `anthropic-ratelimit-tokens-limit` / `-remaining` / `-reset` | The most restrictive token limit currently in effect |
| `anthropic-ratelimit-input-tokens-*` / `-output-tokens-*` | Input/output-specific variants |
| `anthropic-priority-input-tokens-*` / `-output-tokens-*` | Priority Tier only |

`anthropic-ratelimit-tokens-*` reflects whichever limit currently binds — it will show a Workspace limit when that is tighter than the org limit, so do not read it as an org-level figure.

## Workspace limits

> Source: https://platform.claude.com/docs/en/api/rate-limits

Set lower per-Workspace spend and rate limits to protect shared org capacity; unused Workspace capacity remains available to other Workspaces. You cannot set limits on the default Workspace, and org-wide limits always apply even when Workspace limits sum to more.

Request increases via **Request rate limit increase** on the Limits page in the Claude Console. That path is not available for Claude Platform on AWS — contact your account representative instead.

## Token counting endpoint

> Source: https://platform.claude.com/docs/en/build-with-claude/token-counting

`POST /v1/messages/count_tokens` accepts the same structured inputs as Messages (system, tools, images, PDFs, thinking blocks) and returns only the input estimate. It is **free** and does not consume Messages rate limit — it has its own RPM pool: Start 2,000/min, Build 4,000/min, Scale 8,000/min.

```bash
curl https://api.anthropic.com/v1/messages/count_tokens \
  -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d '{"model":"claude-opus-5","system":"You are a scientist","messages":[{"role":"user","content":"Hello, Claude"}]}'
```

Response: `{"input_tokens": 14}`.

Caveats that make the number differ from your bill:

- It is an **estimate**, and it includes Anthropic system-added tokens that are not billed to you.
- Server-tool token counts reflect only the first sampling call.
- Thinking blocks from **previous** assistant turns are ignored; current-turn thinking counts.
- Caching logic is not applied — `cache_control` blocks are accepted but ignored, since caching only happens during actual message creation.
- Fable 5 and Mythos 5 use the post-Opus-4.7 tokenizer (~30% more tokens for the same text). Recount against the target model; never reuse counts across that boundary.

## Sources

- https://platform.claude.com/docs/en/api/rate-limits
- https://platform.claude.com/docs/en/build-with-claude/token-counting

Fetched: 2026-08-05
