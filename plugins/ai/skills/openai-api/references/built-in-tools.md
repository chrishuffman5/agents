# Built-in tools

Read when enabling web search, file search, code interpreter, computer use, or image generation on a Responses call.

All built-in tools are enabled by adding an entry to the `tools` array. The model decides whether and when to invoke them, subject to `tool_choice`. You never write an executor for them — that is the entire point, and the most common confusion when porting from a hand-rolled Chat Completions tool loop.

## Web search

> Source: https://developers.openai.com/api/docs/guides/tools-web-search

**Tool type:** `web_search`. The legacy `web_search_preview` type still works but lacks newer features — do not use it in new code.

```javascript
tools: [{ type: "web_search" }]
```

| Option | Values / notes |
|---|---|
| `search_context_size` | `"low"` \| `"medium"` \| `"high"` — how much retrieved context reaches the model |
| `return_token_budget` | `"unlimited"` for extensive research runs; GPT-5+ reasoning models only |
| `external_web_access` | boolean, default `true`; `false` gives cache-only mode |
| `search_content_types` | array of `"image"` and/or `"text"` for mixed-media search |
| `image_settings` | `max_results`, `caption` |
| `filters` | up to 100 `allowed_domains` or `blocked_domains`; omit the `http(s)://` scheme |
| `user_location` | approximate geography — country code, city, region, or timezone |

`search_context_size` is the main cost/quality dial: retrieved context is billed as input tokens, so `"high"` on a chatty endpoint is a real line item. `external_web_access: false` is the control to reach for when a workload must not make live outbound fetches.

Response shape:

1. A `web_search_call` item — `id`, `status`, `action` (`"search"` | `"open_page"` | `"find_in_page"`), optional `queries` and `sources`.
2. A `message` item — text in `message.content[0].text`, with inline `url_citation` annotations carrying url, title, and location.

**Compliance requirement, not a suggestion:** "When displaying web results to end users, inline citations must be made clearly visible and clickable in your user interface." A UI that strips annotations violates OpenAI's stated terms of use for the tool.

```python
response = client.responses.create(
    model="gpt-5.6",
    tools=[{"type": "web_search"}],
    input="What was a positive news story from today?"
)
print(response.output_text)
```

## File search

> Source: https://developers.openai.com/api/docs/guides/tools-file-search

**Tool type:** `file_search`.

Setup order matters:

1. Create a vector store (endpoints in `files-and-vector-stores.md`).
2. Upload files via the Files API with `purpose: "assistants"`.
3. Attach file ids to the vector store.
4. **Wait for files to reach `completed` status before querying.** Querying earlier returns results silently missing those files — not an error.

```
tools: [{ type: "file_search", vector_store_ids: ["<vector_store_id>"] }]
```

Multiple store ids are allowed in the array.

| Option | Effect |
|---|---|
| `max_num_results` | Caps retrieved chunks — cuts tokens and latency, may cut answer quality |
| `include: ["file_search_call.results"]` | Returns the actual retrieved chunk content, not just annotations |
| `filters` | Metadata filtering by file attributes via `type`/`key`/`value` objects |

Turn on `include: ["file_search_call.results"]` whenever you are debugging retrieval quality — without it you see citations but not what was actually retrieved, and cannot tell a retrieval failure from a reasoning failure.

Supported formats: 23+ file types (PDF, Word, code files, plain text, and others). Plain-text files must be UTF-8, UTF-16, or ASCII encoded.

Response shape: a `file_search_call` item (status + queries) plus a `message` item with output and file citations.

## Code interpreter

> Source: https://developers.openai.com/api/docs/guides/tools-code-interpreter

**Tool type:** `code_interpreter`. Models refer to it internally as "the python tool."

Auto container mode — created or reused automatically:

```
"container": { "type": "auto", "memory_limit": "4g", "file_ids": [...] }
```

Memory tiers: `1g` (default), `4g`, `16g`, `64g`. Above-default tiers bill at built-in-tool rates, so raise it only when a workload actually needs it.

Explicit mode: pre-create a container with `POST /v1/containers` and reference its id in the tool config. Use this when several responses must share state.

**Expiration: containers expire after 20 minutes of inactivity and all data is discarded irrecoverably.** Any generated artifact you care about must be downloaded before then — there is no recovery path.

File handling:

- Input: files included in model input auto-upload into the container.
- Output: generated files surface as `container_file_citation` annotations carrying `file_id`, `container_id`, and filename. Dedicated endpoints exist to upload, list, and download container files.

Language support: Python is primary; the tool also processes documents, images, C/C++/C#/Java/PHP/Ruby source, CSV/JSON/XML, and PNG/JPEG/GIF.

```javascript
const resp = await client.responses.create({
  model: "gpt-5.6",
  tools: [{ type: "code_interpreter", container: { type: "auto", memory_limit: "4g" } }],
  input: "solve the equation 3x + 11 = 14"
});
```

**Unverified:** the container-files sub-API endpoint paths (list/download) were not fetched. Check the API reference rather than guessing paths.

## Computer use

> Source: https://developers.openai.com/api/docs/guides/tools-computer-use

**Tool type:** `computer`. **Required model:** `gpt-5.6`, or `gpt-5.4` for earlier support. Other models will not drive this loop.

The loop:

1. Model receives a screenshot as `computer_screenshot` input.
2. Model returns a `computer_call` with a **batched `actions[]` array**.
3. Your harness executes the actions sequentially.
4. You capture a new screenshot and send it back as `computer_call_output`.
5. Repeat until the model stops emitting `computer_call` items.

Send screenshots with `detail: "original"` to preserve resolution — downscaled screenshots degrade click accuracy directly.

Supported actions: `click`, `double_click`, `drag` (path array), `move`, `scroll` (x/y deltas), `type`, `keypress`, `wait`, `screenshot`. Mouse actions accept an optional `keys` array for modifier-assisted actions such as Ctrl+click.

```javascript
const response = await client.responses.create({
  model: "gpt-5.6",
  tools: [{ type: "computer" }],
  input: "Check if Filters panel is open. Click Show filters if needed."
});
```

The first `computer_call.actions[]` typically opens with a screenshot action, then batches click/type actions. Follow-up calls send `computer_call_output` with a base64 screenshot, referencing the previous response id to continue the thread.

Because actions arrive batched, your harness must decide what happens when action 3 of 5 fails. Executing the remainder blindly against a changed screen is how computer-use agents do damage. Isolation guidance for that belongs to the `sandboxing` skill.

## Image generation

> Source: https://developers.openai.com/api/docs/guides/image-generation

Two paths:

- **Image API** — standalone generation/editing endpoints. Best for single-image workflows.
- **Responses API `image_generation` tool** — image generation inside conversational/agentic flows, with multi-turn editing.

Models: `gpt-image-2` (latest), `gpt-image-1.5`, `gpt-image-1`, `gpt-image-1-mini`. **Organization verification may be required.**

Capabilities: text-to-image generation; editing via new prompts or mask-based partial edits; image references as input; multi-turn iterative refinement via `previous_response_id` or image ids; streaming with `partial_images` set to 0–3.

| Option | Values |
|---|---|
| size | `1024x1024` up to `3840x2160`, or `auto` |
| quality | `low` / `medium` / `high` / `auto` |
| format | PNG (default) / JPEG / WebP |
| compression | 0–100% for JPEG/WebP |
| background | opaque or automatic — **transparent background is not supported on `gpt-image-2`** |

If a design requires transparency, `gpt-image-2` is the wrong model; that constraint drives model choice, not a post-processing step.

Pricing: `gpt-image-2` bills by output tokens based on resolution and quality; older models used per-image pricing. Text prompts and reference images consume input tokens. Rates in `models-and-pricing.md`.

## Gaps — do not fill from memory

- The **MCP built-in tool type** is referenced in the migration guide's tool list but its dedicated guide was not fetched. Do not describe its configuration fields. Protocol-level MCP questions belong to the `mcp` skill.
- Container-files sub-API paths were not fetched.

## Sources

- https://developers.openai.com/api/docs/guides/tools-web-search
- https://developers.openai.com/api/docs/guides/tools-file-search
- https://developers.openai.com/api/docs/guides/tools-code-interpreter
- https://developers.openai.com/api/docs/guides/tools-computer-use
- https://developers.openai.com/api/docs/guides/image-generation

Fetched: 2026-08-05
