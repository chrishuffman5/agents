# Message Batches API and Files API

Read when moving work off the synchronous path or when uploading documents once and referencing them by ID.

## Message Batches API

> Source: https://platform.claude.com/docs/en/build-with-claude/batch-processing

Submit many Messages requests together, poll, download results. **50% off input and output tokens** versus synchronous pricing (rate table in `models-and-pricing.md`). Most batches finish in under an hour.

### Limits

- **100,000 requests or 256 MB** per batch, whichever comes first.
- Results are available when all requests complete **or after 24 hours**, whichever is first; batches expire if not done within 24 hours.
- Results remain downloadable for **29 days** after creation. Metadata stays visible after that, but the results are gone — export anything you need to keep.
- Batches are scoped to a Workspace.
- Every request needs `max_tokens >= 1`; `max_tokens: 0` cache pre-warming is not supported inside a batch.
- Rate limits apply separately to Batches HTTP calls and to queued requests — see `rate-limits-and-token-counting.md`.

### Unsupported parameters inside a batch request

Validation error if present: `stream: true`, `speed` (Fast mode), `store` / `previous_thread_event_id` (Threads), `cache_hint` / `context_hint`, `max_tokens: 0`, `research_preview_2026_02: "active"`.

### Supported

Vision, tool use including **all** server tools (web search, web fetch, code execution, MCP connectors, advisor, tool search), system messages, multi-turn conversations, extended thinking, and most beta features.

### Create

`POST /v1/messages/batches`

```json
{
  "requests": [
    {"custom_id": "my-first-request", "params": {"model": "claude-opus-5", "max_tokens": 1024, "messages": [{"role": "user", "content": "Hello, world"}]}},
    {"custom_id": "my-second-request", "params": {"model": "claude-opus-5", "max_tokens": 1024, "messages": [{"role": "user", "content": "Hi again, friend"}]}}
  ]
}
```

`custom_id` must match `^[a-zA-Z0-9_-]{1,64}$`.

Initial response:

```json
{
  "id": "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
  "type": "message_batch",
  "processing_status": "in_progress",
  "request_counts": {"processing": 2, "succeeded": 0, "errored": 0, "canceled": 0, "expired": 0},
  "ended_at": null,
  "created_at": "2024-09-24T18:37:24.100435Z",
  "expires_at": "2024-09-25T18:37:24.100435Z",
  "cancel_initiated_at": null,
  "results_url": null
}
```

### Poll, list, retrieve, cancel

- Poll `GET /v1/messages/batches/{id}` until `processing_status == "ended"`.
- List `GET /v1/messages/batches?limit=20`, paginated with `before_id`/`after_id`.
- Fetch `results_url` from the retrieved batch and stream the `.jsonl`. Result types: `succeeded`, `errored` (not billed), `canceled` (not billed), `expired` (not billed).
- Cancel `POST /v1/messages/batches/{id}/cancel` → status `canceling`, then `ended` with partial results for whatever finished first.

**Results may arrive in a different order than submitted — always match on `custom_id`, never on position.**

```jsonl
{"custom_id":"my-second-request","result":{"type":"succeeded","message":{"id":"msg_...","type":"message","role":"assistant","model":"claude-opus-5","content":[{"type":"text","text":"Hello again!..."}],"stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":11,"output_tokens":36}}}}
```

### Caching inside batches

Supported, and the discounts stack with the batch discount. Because processing is async and concurrent, hits are best-effort — typical rates run 30–98% depending on traffic. To maximize: use identical `cache_control` blocks across all requests in the batch, keep a steady request stream (the default cache lives 5 minutes), and prefer the **1-hour TTL** since batches routinely run longer than 5 minutes.

### Server tools in batches

All server tools work and run the same server-side agentic loop as synchronous Messages. With no open connection to hold, the batch loop runs **more iterations per turn** before returning `stop_reason: "pause_turn"`; continue paused turns exactly as in sync by resubmitting the paused assistant content. The batch worker throttles `web_search` per org to protect shared capacity, so large search-heavy batches take longer.

### Extended output (beta)

Header `output-300k-2026-03-24` raises the `max_tokens` cap to **300,000** on Opus 5/4.8/4.7/4.6 and Sonnet 5/4.6. **Batch-only** — not available on synchronous Messages. Available on the Claude API and Claude Platform on AWS; not on Bedrock, Google Cloud, or Microsoft Foundry. A single 300k generation can take over an hour, so plan against the 24-hour window.

## Files API

> Source: https://platform.claude.com/docs/en/build-with-claude/files

Beta: requires `anthropic-beta: files-api-2025-04-14`. SDKs add it automatically for `beta.files.*` calls, but a Messages request that *references* a file still needs the header via the `betas` param — a common source of confusing 400s.

**Security**: uploaded files are **workspace-scoped, not user- or conversation-scoped**. Any API key in the workspace can read any file. Never accept a `file_id` from an end user; keep the user↔file mapping server-side and resolve it yourself.

### Upload

`POST /v1/files` (multipart) →

```json
{"id":"file_011CNha8iCJcU1wXNR6q4V8w","type":"file","filename":"document.pdf","mime_type":"application/pdf","size_bytes":1024000,"created_at":"2025-01-01T00:00:00Z","downloadable":false}
```

`downloadable` is `false` for files you upload; only files produced by skills or the code execution tool are downloadable.

### Reference in a request

```json
{
  "model": "claude-opus-5", "max_tokens": 1024,
  "messages": [{"role": "user", "content": [
    {"type": "text", "text": "Please summarize this document for me."},
    {"type": "document", "source": {"type": "file", "file_id": "file_011CNha8iCJcU1wXNR6q4V8w"}}
  ]}]
}
```

| File type | MIME type | Content block |
|---|---|---|
| PDF | `application/pdf` | `document` |
| Plain text | `text/plain` | `document` |
| Images | `image/jpeg`, `image/png`, `image/gif`, `image/webp` | `image` |
| Datasets/other (code execution) | varies | `container_upload` |

`document` blocks accept optional `title`, `context`, and `citations: {"enabled": true}`.

For unsupported formats (.docx, .xlsx): convert to plain text and inline it, or convert to PDF first to keep image and citation support. CSV and Markdown can be uploaded as `text/plain` or inlined directly.

### Manage

- List `GET /v1/files` (paginated, `limit` default 20, `before_id`/`after_id`).
- Metadata `GET /v1/files/{file_id}`.
- Delete `DELETE /v1/files/{file_id}` — irreversible.
- Download `GET /v1/files/{file_id}/content` — works only when `downloadable: true`; uploaded files return 400.

### Limits and pricing

- Max file size **500 MB**; total org storage **500 GB**.
- Filenames 1–255 chars; forbidden characters `< > : " | ? * \ /` and Unicode 0–31.
- Files persist until explicitly deleted and **cannot be modified or renamed** — upload a new one and delete the old.
- Upload, download, list, metadata, and delete are **free**; file content used in a Messages request bills as normal input tokens.
- Beta-period rate limit: ~100 requests/minute for file-related calls.
- Images are supported on all current models. The Files API is available on the Claude API, Claude Platform on AWS, and Microsoft Foundry (Hosted-on-Anthropic). **Not** on Amazon Bedrock or Google Cloud.

## Sources

- https://platform.claude.com/docs/en/build-with-claude/batch-processing
- https://platform.claude.com/docs/en/build-with-claude/files

Fetched: 2026-08-05
