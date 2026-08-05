# Sessions, state, memory, and artifacts reference

Read when choosing a `SessionService`, deciding a state key's lifetime, persisting binary output, or debugging state that vanished between turns.

## Session object and state

> Source: https://adk.dev/context/

A **Session** encapsulates the conversational context for a user:

- **ID** — unique session identifier
- **User ID** — the associated user
- **State** — mutable dictionary storing session data
- **Events** — history of interactions within the session

Sessions are created via a `SessionService` and passed to `runner.run_async()` calls.

**State prefixes** scope a key across levels:

| Prefix | Scope |
|---|---|
| `temp:` | Invocation-scoped — relevant only within the current turn |
| `user:` | User-level, persists across sessions (requires a persistent `SessionService`) |
| `app:` | Application-wide, accessible to all users |
| *(none)* | Session-specific (default) |

Examples: `context.state["temp:current_user_id"]` versus `context.state["user:display_preference"]`.

**State mutation** in callbacks and tools is auto-tracked: `context.state["key"] = value` adds the change to `EventActions.state_delta`, and the `SessionService` applies these deltas when persisting events — maintaining audit trails and the scope hierarchy. Each implementation handles delta tracking differently when persisting.

## SessionService implementations

> Source: https://adk.dev/context/
> Source: https://adk.dev/sessions/

| Type | Scope | Use case |
|---|---|---|
| `InMemoryService` | Runtime only | Development, testing |
| `DatabaseSessionService` | Persistent | Production with a database backend |
| `VertexAiSessionService` | Cloud-managed | Google Cloud integration |

`SessionService` manages the full lifecycle: creation, retrieval, updating (appending Events, modifying State), deletion. In-memory implementations are for "local testing and fast development" only — they lose all data on restart, so cloud-based or database options are recommended for production persistence.

A `Session` represents "a *single, ongoing interaction* between a user and your agent system" — a chronological record of messages and actions (Events) from one conversation, plus temporary session-specific data via its `State` property.

Sub-pages under Sessions (sitemap-listed): Rewind Sessions (`session/rewind/`), Migrate Sessions (`session/migrate/`), State (`state/`), Memory (`memory/`). Their contents were not fetched into this corpus.

## Memory

> Source: https://adk.dev/context/

`MemoryService` enables searching historical context and external knowledge, accessed through `ToolContext`:

```python
relevant_docs = tool_context.search_memory("query about topic")
```

## Artifacts

> Source: https://adk.dev/artifacts/

Artifacts are "named, versioned binary data associated either with a specific user interaction session or persistently with a user across multiple sessions" — files, images, audio, and other binary formats beyond plain text.

**Implementations**:

- `InMemoryArtifactService` — stores data in application memory (dict/hashmap); ideal for local development and testing; **not persistent**, data lost on app termination.
- `GcsArtifactService` — persists to Google Cloud Storage; suitable for production; supports user-level namespacing across sessions.

**Saving** — the service auto-handles versioning and returns the assigned version number:

```python
version = await context.save_artifact(filename="report.pdf", artifact=pdf_part)
```

**Loading**:

```python
artifact = await context.load_artifact(filename="report.pdf")             # latest
artifact = await context.load_artifact(filename="report.pdf", version=0)  # specific version
```

**Listing**:

```python
filenames = await context.list_artifacts()
```

**Versioning and namespacing**: each save creates a new version (0, 1, 2, …); load defaults to the latest unless a version is given. A plain filename (`"report.pdf"`) is session-scoped; a `"user:"` prefix (`"user:settings.json"`) makes the artifact accessible across all of that user's sessions.

**Data representation**: artifacts use the standard `google.genai.types.Part` object with `inline_data` containing `data` (raw bytes) and `mime_type` (e.g. `"application/pdf"`, `"image/png"`).

**Documented use cases**: generating and storing reports (PDF, CSV), managing user file uploads, caching expensive binary outputs, storing intermediate processing results, persistent user-specific data across sessions.

## Sources

- https://adk.dev/context/
- https://adk.dev/sessions/
- https://adk.dev/artifacts/

Fetched: 2026-08-05
