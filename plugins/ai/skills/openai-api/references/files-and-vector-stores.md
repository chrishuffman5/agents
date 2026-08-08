# Files and Vector Stores APIs

Read when uploading files for any purpose, or when building/tuning retrieval for the `file_search` tool.

## Files API

> Source: https://developers.openai.com/api/docs/api-reference/files

### Endpoints

| Endpoint | Method | Notes |
|---|---|---|
| `/files` | `POST` | Upload; up to 512 MB per file, 2.5 TB per project; 1,000 req/min per user; `purpose` required |
| `/files` | `GET` | List; `after` cursor pagination; `limit` 1–10,000 (default 10,000); `order` asc/desc by `created_at`; filter by `purpose` |
| `/files/{file_id}` | `GET` | Retrieve metadata |
| `/files/{file_id}/content` | `GET` | Retrieve raw content |
| `/files/{file_id}` | `DELETE` | Delete — **also removes the file from every vector store that references it** |

That delete behavior is global. There is no per-store detach; deleting a file to clean up one index silently degrades every other index built on it.

### Upload parameters

- `file` (required) — multipart form data.
- `purpose` (required).
- `expires_after` (optional) — expiration settings. Set this on transient uploads; the 2.5 TB project ceiling is reached by accumulation, not by any single job.

### Purpose values

Eight supported values: `assistants`, `assistants_output`, `batch`, `batch_output`, `fine-tune`, `fine-tune-results`, `vision`, `user_data`.

Note `assistants` is the purpose used for vector-store/file-search uploads even though the Assistants **API** is sunsetting on 2026-08-26 — the purpose string and the deprecated product are not the same thing.

### File object schema

| Field | Type | Notes |
|---|---|---|
| `id` | string | |
| `bytes` | number | file size |
| `created_at` | number | Unix timestamp |
| `filename` | string | |
| `object` | string | always `"file"` |
| `purpose` | string enum | one of the eight above |
| `status` | string | `"uploaded"`, `"processed"`, `"error"` — **deprecated field** |
| `expires_at` | number | optional |
| `status_details` | string | optional, deprecation-related |

Do not build logic on `status`; it is marked deprecated. For retrieval readiness, check the **vector store file** status instead.

### Size constraints

| Context | Limit |
|---|---|
| Individual file | 512 MB |
| Batch API input file | 200 MB, `.jsonl` only |
| Assistants API per-file tokens | 2,000,000 (Assistants API sunsets 2026-08-26) |

## Vector Stores API

> Source: https://developers.openai.com/api/docs/api-reference/vector-stores

### Store management

| Endpoint | Method |
|---|---|
| `/vector_stores` | `POST` — create |
| `/vector_stores` | `GET` — list |
| `/vector_stores/{vector_store_id}` | `GET` — retrieve |
| `/vector_stores/{vector_store_id}` | `POST` — modify |
| `/vector_stores/{vector_store_id}` | `DELETE` — delete |
| `/vector_stores/{vector_store_id}/search` | `POST` — search contents |

The `/search` endpoint queries a store directly, without a model in the loop. Use it to evaluate retrieval quality in isolation before blaming the model for a bad answer.

### File management

| Endpoint | Method |
|---|---|
| `/vector_stores/{vector_store_id}/files` | `POST` — attach file |
| `/vector_stores/{vector_store_id}/files` | `GET` — list files |
| `/vector_stores/{vector_store_id}/files/{file_id}` | `GET` — retrieve file detail |
| `/vector_stores/{vector_store_id}/files/{file_id}` | `POST` — update file attributes |
| `/vector_stores/{vector_store_id}/files/{file_id}` | `DELETE` — remove from store |
| `/vector_stores/{vector_store_id}/files/{file_id}/content` | `GET` — parsed file content |

### File batches

| Endpoint | Method |
|---|---|
| `/vector_stores/{vector_store_id}/file_batches` | `POST` — create batch, up to **2,000 files** |
| `/vector_stores/{vector_store_id}/file_batches/{batch_id}` | `GET` — retrieve status |
| `/vector_stores/{vector_store_id}/file_batches/{batch_id}/files` | `GET` — list files in batch |
| `/vector_stores/{vector_store_id}/file_batches/{batch_id}/cancel` | `POST` — cancel |

Use file batches for bulk ingestion rather than looping the single-attach endpoint — one status object to poll instead of N.

### Create parameters

- `name` (optional) — display name.
- `description` (optional).
- `file_ids` (optional) — File ids attached at creation.
- `chunking_strategy` (optional).
- `expires_after` (optional) — `{ anchor, days }`.
- `metadata` (optional) — up to 16 key/value pairs; keys ≤64 chars, values ≤512 chars.

### Chunking strategies

| Strategy | Behavior |
|---|---|
| `auto` (default) | 800 max chunk-size tokens, 400 overlap tokens |
| `static` | custom `max_chunk_size_tokens` (100–4,096) and `chunk_overlap_tokens` |

The `auto` default carries **50% overlap** (400 of 800), which inflates `usage_bytes` and retrieval redundancy. Tune `static` when documents are already well-structured; keep `auto` for prose where context bleeds across boundaries.

Chunking is fixed at attach time — changing strategy means re-attaching the files.

### Search parameters

| Parameter | Notes |
|---|---|
| `query` | string or array of strings |
| `filters` | comparison or compound filters over file attributes |
| `max_num_results` | 1–50 (default varies) |
| `ranking_options` | re-ranking configuration |
| `rewrite_query` | boolean — enables query rewriting/optimization |

Set file `attributes` at attach time even when you have no filtering need yet; adding them later requires an update call per file, and metadata filtering is the cheapest precision win in retrieval.

### Object schemas

**VectorStore:** `id`, `created_at`, `status` (`"completed"` | `"in_progress"` | `"expired"`), `file_counts` (cancelled, completed, failed, in_progress, total), `usage_bytes`, `last_active_at`, `expires_at`, `metadata`, `object: "vector_store"`.

**VectorStoreFile:** `id`, `created_at`, `status`, `usage_bytes`, `last_error`, `attributes`, `chunking_strategy`, `object: "vector_store.file"`.

**Search results:** `data` — array of matching chunks with `file_id`, `filename`, `score`, `content`, `attributes`; plus `has_more`, `next_page`, `search_query`.

Check `file_counts.failed` after ingestion. A store reporting `status: "completed"` with failed files still answers queries — just without those documents.

## Gaps — do not fill from memory

The container-files sub-API used for code interpreter outputs was not fetched; its endpoint paths are unverified.

## Sources

- https://developers.openai.com/api/docs/api-reference/files
- https://developers.openai.com/api/docs/api-reference/vector-stores

Fetched: 2026-08-05
