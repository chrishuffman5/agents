# Batch API

Read when moving latency-tolerant work off the synchronous path, or when a batch job fails validation or expires.

## Why batch

> Source: https://developers.openai.com/api/docs/guides/batch

Two independent wins: a **"50% cost discount compared to synchronous APIs,"** and a **separate, substantially higher rate-limit pool** that leaves your synchronous limits untouched. The second matters more than the first for anyone throttled at tier 1–3 — batch is how you run bulk work without starving interactive traffic.

## Endpoints

> Source: https://developers.openai.com/api/docs/guides/batch

1. **Create Batch** — submit a job referencing an input file id and a target endpoint.
2. **Retrieve Batch** — status and metadata.
3. **Cancel Batch** — stop an in-progress batch; cancellation takes up to 10 minutes.
4. **List Batches** — paginated listing.

## Request file format

> Source: https://developers.openai.com/api/docs/guides/batch

JSONL, one request per line:

| Field | Notes |
|---|---|
| `custom_id` | Caller-assigned id used to map results back to requests |
| `method` | `"POST"` |
| `url` | Target API endpoint path, e.g. `/v1/responses` |
| `body` | Endpoint-specific request body |

Validate the file before uploading with `scripts/validate-batch-jsonl.py` — a malformed line fails the whole batch at validation, after upload, with a turnaround measured in minutes.

## Supported target endpoints

> Source: https://developers.openai.com/api/docs/guides/batch

`/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/responses`, `/v1/moderations`, `/v1/images/generations`, `/v1/images/edits`, `/v1/videos`.

## Completion window

> Source: https://developers.openai.com/api/docs/guides/batch

Only `"24h"` is currently available, guaranteeing completion within 24 hours. There is no faster tier to buy — if a workload cannot tolerate a 24-hour worst case, it is not a batch workload.

## Limits

> Source: https://developers.openai.com/api/docs/guides/batch

| Limit | Value |
|---|---|
| Requests per batch | 50,000 max |
| Input file size | 200 MB max, `.jsonl` only |
| Embedding inputs per batch | 50,000 max |
| Batch creation rate | 2,000 batches per hour |
| Queued token limits | model-specific — check account Platform Settings |

The 200 MB ceiling usually binds before the 50,000-request one on anything with long prompts. Split by size, not just by count.

## Status values

> Source: https://developers.openai.com/api/docs/guides/batch

| Status | Meaning |
|---|---|
| `validating` | Input file validation in progress |
| `failed` | Validation unsuccessful |
| `in_progress` | Actively processing |
| `finalizing` | Preparing results |
| `completed` | Ready for download |
| `expired` | Did not complete within the 24h window |
| `cancelling` | Cancellation initiated |
| `cancelled` | Successfully cancelled |

`expired` is a real outcome, not an anomaly — build for partial completion rather than assuming every submitted batch returns a full result set.

## Implementation notes

> Source: https://developers.openai.com/api/docs/guides/batch

- **Output file order may not match input order.** Always join on `custom_id`. Positional matching will produce silently mismatched results.
- Output files auto-delete **30 days** after batch completion.
- Video batch outputs remain downloadable for only **24 hours** after completion — a much tighter window that is easy to miss.
- Failed requests are reported in a **separate error file** with error details. Reconciling success count against submitted count is not enough; read the error file.

## Gaps — do not fill from memory

Batch queued-token limits are described as "model-specific" but exact numbers were not shown on the fetched page. Read them from account settings.

## Sources

- https://developers.openai.com/api/docs/guides/batch

Fetched: 2026-08-05
