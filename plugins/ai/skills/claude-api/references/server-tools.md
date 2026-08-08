# Server Tools: Web Search, Web Fetch, Code Execution

Read when enabling Anthropic-hosted tools, sizing their cost, or debugging their result blocks. Computer use is in `computer-use.md`, the MCP connector in `mcp-connector.md`, the advisor tool in `advisor-tool.md`, and the tool search tool in `tool-use.md`.

## Web search tool

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool

Tool versions as of 2026-08-05:

| Type string | Adds |
|---|---|
| `web_search_20250305` | Basic search |
| `web_search_20260209` | **Dynamic filtering** — Claude writes and runs code inside code execution to filter results before they reach context. Claude 4.6+ and Mythos Preview |
| `web_search_20260318` | `response_inclusion` control |

Dynamic filtering: `allowed_callers` defaults to `["code_execution_20260120"]` on `web_search_20260209`+, and the API auto-provisions code execution at no extra charge beyond tokens. On models without programmatic tool calling you must set `allowed_callers: ["direct"]` or the request 400s.

```json
{
  "type": "web_search_20250305",
  "name": "web_search",
  "max_uses": 5,
  "allowed_domains": ["example.com", "trusteddomain.org"],
  "blocked_domains": ["untrustedsource.com"],
  "user_location": {
    "type": "approximate",
    "city": "San Francisco",
    "region": "California",
    "country": "US",
    "timezone": "America/Los_Angeles"
  }
}
```

Use `allowed_domains` **or** `blocked_domains`, never both — setting both is a 400. `max_uses` caps searches per request; exceeding it yields a `web_search_tool_result` carrying `max_uses_exceeded`.

**Response blocks**: `server_tool_use` (the issued query) → `web_search_tool_result` containing `web_search_result` items (`url`, `title`, `page_age`, `encrypted_content`). Citations use `web_search_result_location` blocks (`url`, `title`, `encrypted_index`, `cited_text` up to 150 chars). Citation fields do **not** count toward token usage. Pass `encrypted_content` / `encrypted_index` back unmodified on later turns or the request 400s.

**Errors** inside `web_search_tool_result_error`: `too_many_requests`, `invalid_tool_input`, `max_uses_exceeded`, `query_too_long`, `request_too_large`, `unavailable`. They return HTTP 200 with the error embedded and are not billed.

**Availability**: Claude API, Claude Platform on AWS, Microsoft Foundry (Hosted-on-Anthropic only). **Not** on Amazon Bedrock. Google Cloud supports only basic (non-dynamic-filtering) search.

**Pricing**: $10 per 1,000 searches plus standard token costs for search-generated content.

## Web fetch tool

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-fetch-tool

Fetches full content from URLs and PDFs. Results are inserted directly into the conversation with no `tool_result` from you — except when web fetch is called alongside a client tool in the same parallel batch, where the response returns `stop_reason: "tool_use"` first and the fetch runs once you send back the client tool result.

| Type string | Adds |
|---|---|
| `web_fetch_20250910` | Basic fetch |
| `web_fetch_20260209` | Dynamic filtering |
| `web_fetch_20260309` | + cache bypass (`use_cache`) |
| `web_fetch_20260318` | + `response_inclusion` |

Dynamic filtering models: Fable 5, Opus 4.8, Mythos 5, Mythos Preview, Opus 4.7, Opus 4.6, Sonnet 5, Sonnet 4.6.

Availability: Claude API, Claude Platform on AWS, Microsoft Foundry (Hosted-on-Anthropic). **Not** on Amazon Bedrock or Google Cloud. Mythos Preview: API and Microsoft Foundry only.

```json
{
  "type": "web_fetch_20250910",
  "name": "web_fetch",
  "max_uses": 10,
  "allowed_domains": ["example.com", "docs.example.com"],
  "blocked_domains": ["private.example.com"],
  "citations": {"enabled": true},
  "max_content_tokens": 100000
}
```

- `allowed_domains` and `blocked_domains` cannot be combined.
- `use_cache` (default `true`, requires `web_fetch_20260309`+): set `false` only for rapidly-changing sources or on explicit request — it adds latency.
- `response_inclusion` (requires `web_fetch_20260318`+): `"excluded"` drops nested `server_tool_use`/result blocks when the fetch was consumed by a completed code-execution call in the same turn, cutting output token cost in agentic loops. Default `"full"`. Direct calls and paused code-execution calls always return in full.
- `max_uses`: failed fetches still count; no default limit.
- `max_content_tokens`: approximate truncation of **text** content only, not binary PDFs.
- **Citations are off by default** for web fetch (unlike web search) — enable explicitly.

**Security — URL validation**: web fetch can only retrieve URLs that already appeared in conversation context (user messages, client tool results, prior search/fetch results). It cannot fetch Claude-generated URLs or URLs surfaced by container-based tools (code execution, bash). This is the primary defense against exfiltration through constructed URLs.

**Exfiltration risk**: enabling web fetch where Claude processes untrusted input alongside sensitive data still carries exfiltration risk. Mitigate by disabling the tool, capping `max_uses`, or restricting `allowed_domains` to known-safe hosts.

**Errors** (HTTP 200, Claude sees them and continues): `invalid_tool_input`, `url_too_long` (>250 chars), `url_not_allowed` (domain filter, org settings, private address, robots.txt), `url_not_in_prior_context`, `url_not_accessible`, `too_many_requests`, `unsupported_content_type` (only text/HTML/PDF), `max_uses_exceeded`, `unavailable`.

**Result shape**: `web_fetch_tool_result` → `web_fetch_result` with `url`, `content` (a `document` block; PDFs use `source.type: "base64"`, `media_type: "application/pdf"`), and `retrieved_at`. Usage reports `server_tool_use.web_fetch_requests`.

**Known limitation**: web fetch does not support pages rendered dynamically with JavaScript.

**Search + fetch together**: when both are enabled and the user names a resource without a URL, Claude searches first, then fetches.

```json
{
  "tools": [
    {"type": "web_search_20250305", "name": "web_search", "max_uses": 3},
    {"type": "web_fetch_20250910", "name": "web_fetch", "max_uses": 5, "citations": {"enabled": true}}
  ]
}
```

**Streaming**: `server_tool_use` streams the URL, then the stream pauses during retrieval, then `web_fetch_tool_result` arrives whole in a single `content_block_start` (no deltas).

**Pricing**: no surcharge beyond tokens. Sizing: 10 kB page ≈ 2,500 tokens; 100 kB doc ≈ 25,000; 500 kB research PDF ≈ 125,000. Supported in the Batches API at the same price.

## Code execution tool

> Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/code-execution-tool

| Type string | Runtime |
|---|---|
| `code_execution_20250825` | Bash + file ops, all supported models |
| `code_execution_20260120` | + REPL state persistence, + programmatic tool calling from inside the sandbox |
| `code_execution_20260521` | Same runtime as `20260120`, adds a 90-second wall-clock hint in the tool description for programmatic-tool-calling cells |

All three are GA — no beta header. Web search/fetch `_20260209`+ require `code_execution_20260120`+ as their backing version.

```json
{
  "model": "claude-opus-5",
  "max_tokens": 4096,
  "messages": [{"role": "user", "content": "Use the code execution tool to calculate the mean and standard deviation of [1,2,...,10]"}],
  "tools": [{"type": "code_execution_20250825", "name": "code_execution"}]
}
```

**Container**: Python 3.11 on x86_64 Linux, **5 GiB RAM, 5 GiB disk, 1 CPU**, and **no internet access**. Nothing can be pip-installed at runtime — if a library is not pre-installed, the approach must change.

Pre-installed: pandas, numpy, scipy, scikit-learn, statsmodels, matplotlib, seaborn, pyarrow, openpyxl, xlsxwriter, xlrd, pillow, python-pptx, python-docx, pypdf, pdfplumber, pypdfium2, pdf2image, pdfkit, tabula-py, reportlab[pycairo], img2pdf, sympy, mpmath, tqdm, python-dateutil, pytz, joblib; CLI tools unzip, unrar, 7zip, bc, rg, fd, sqlite.

**Container lifecycle**: expires 30 days after creation; checkpointed after ~5 minutes idle and restored on reuse inside that window. Reuse by passing the `container` ID from a previous response to persist files — with `code_execution_20260120`+ the Python REPL state persists too. Omit `container` to get a fresh one; expired containers cannot be reused.

**Errors**: `unavailable`, `execution_time_exceeded` (all tools), `invalid_tool_input`, `too_many_requests`; bash-specific `output_file_too_large`; text-editor-specific `file_not_found`. Long turns can end `stop_reason: "pause_turn"` — resend the paused assistant content unchanged.

**Usage field**: `{"usage": {"input_tokens": 105, "output_tokens": 239, "server_tool_use": {"code_execution_requests": 1}}}`.

**Pricing**: free alongside `web_search_20260209`+ or `web_fetch_20260209`+. Standalone, billed by execution time with a 5-minute minimum, 1,550 free hours/org/month, then $0.05/hour/container. Attaching files bills execution time even when the tool is never called, because files preload onto the container.

**Availability**: Claude API, Claude Platform on AWS, Microsoft Foundry (Hosted-on-Anthropic). **Not** on Amazon Bedrock or Google Cloud.

## Sources

- https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-fetch-tool
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/code-execution-tool
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
- https://platform.claude.com/docs/en/about-claude/pricing

Fetched: 2026-08-05
