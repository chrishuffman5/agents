# Sessions and conversation state

Read this when a conversation spans more than one run: choosing a persistence strategy, picking a session backend, trimming history, or reasoning about billing and retention of server-side state.

## Python sessions

> Source: https://openai.github.io/openai-agents-python/sessions/

Sessions manage conversation history automatically across runs: the SDK retrieves stored history before each run and persists new interactions afterward.

Protocol (`SessionABC`) — implement these four to build a custom backend:

```python
class MyCustomSession(SessionABC):
    async def get_items(limit: int | None = None) -> List[TResponseInputItem]
    async def add_items(items: List[TResponseInputItem]) -> None
    async def pop_item() -> TResponseInputItem | None
    async def clear_session() -> None
```

Built-in implementations:

| Implementation | Use case | Notes |
|---|---|---|
| `SQLiteSession` | local development | lightweight, file or in-memory |
| `AsyncSQLiteSession` | async SQLite | uses the `aiosqlite` driver |
| `RedisSession` | distributed systems | low-latency shared memory across workers |
| `SQLAlchemySession` | production databases | any SQLAlchemy-compatible DB |
| `MongoDBSession` | horizontally-scalable storage | multi-process, ordered via sequence counters |
| `DaprSession` | cloud-native deployments | 30+ backends with telemetry |
| `OpenAIConversationsSession` | server-managed history | data stored in OpenAI's infrastructure |
| `OpenAIResponsesCompactionSession` | long conversations | auto-compaction wrapper around an underlying session |
| `EncryptedSession` | security-required contexts | transparent encryption wrapper for any backend |
| `AdvancedSQLiteSession` | analytics / branching | conversation branching and usage tracking |

```python
session = SQLiteSession("user_123", "conversations.db")
result = await Runner.run(agent, "Hello", session=session)
result = await Runner.run(agent, "Follow-up", session=session)
```

Runner behavior: retrieve prior history via `session.get_items()`, prepend it to the current input, save all new items after the run via `session.add_items()`.

Customize the merge with `session_input_callback`:

```python
def keep_recent_history(history, new_input):
    return history[-10:] + new_input

result = await Runner.run(
    agent, "Message", session=session,
    run_config=RunConfig(session_input_callback=keep_recent_history)
)
```

"The callback receives copies of both lists, so you can safely mutate them." Only new-turn items are persisted afterward, regardless of reordering.

Cap retrieval per run:

```python
result = await Runner.run(
    agent, "Summarize recent updates", session=session,
    run_config=RunConfig(session_settings=SessionSettings(limit=50))
)
```

Default `limit=None` retrieves all available items.

Memory operations: `get_items()`, `add_items([item1, item2])`, `pop_item()` (removes the last item), `clear_session()`. The documented correction pattern is `pop_item()` twice — once for the assistant response, once for the user input — to drop a bad exchange before continuing.

**Hard constraint**: sessions cannot be combined with `conversation_id`, `previous_response_id`, or `auto_previous_response_id` in the same run. Choose client-side session management *or* OpenAI's server-side mechanisms.

Different session IDs keep separate histories in the same backing store. A session can be shared across multiple agents, which then all see identical history. To resume an interrupted run, pass the same session instance or one pointing at the identical store.

## TypeScript sessions

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/sessions.mdx

Built-in implementations: `MemorySession` (in-memory, dev/testing), `OpenAIConversationsSession` (Conversations API), `OpenAIResponsesCompactionSession` (wraps a session and auto-compresses long history via the Responses API, with configurable triggers/modes; manual compaction between turns is available for low-latency streaming).

Custom sessions implement the `Session` interface. Specialized capability interfaces: `RunContextAwareSession<TContext>` (access run metadata to route or partition storage), `SessionHistoryRewriteAwareSession`, `SessionHistoryTransactionAwareSession`, `OpenAIResponsesCompactionAwareSession`.

Sessions expose CRUD helpers for inspecting, editing, and removing conversation items — the basis for undo and audit features. `sessionInputCallback` (per-run option or `Runner` default) customizes the merge of stored history and new turn input, enabling trimming and deduplication. Sessions support resumable runs from a saved `RunState` after interruptions such as approval checkpoints.

## Choosing a state strategy

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/running-agents.mdx

| Strategy | Where state lives | Best for | What you pass next turn |
|---|---|---|---|
| `result.history` | app memory | small chat loops, full manual control, any provider | `result.history` |
| `session` | your storage + SDK | persistent chat state, resumable runs, custom stores | the same `session` instance (or a store-backed one) |
| `conversationId` | OpenAI Conversations API | shared server-side state across workers/services | the same `conversationId` + only the new user turn |
| `previousResponseId` | OpenAI Responses API only | simplest server-managed continuation without creating a conversation | `result.lastResponseId` + only the new user turn |

`result.history` and `session` are client-managed; `conversationId` and `previousResponseId` are OpenAI-managed and Responses-only. Pick **one** persistence strategy per conversation — mixing client-managed history with server-managed state duplicates context unless deliberately reconciled. `conversationId` and `previousResponseId` are also mutually exclusive with each other: use `conversationId` for a named, shareable server-side conversation resource, `previousResponseId` for the cheapest continuation primitive.

```typescript
// conversationId — create once, reuse every turn; the SDK sends only new items
const conv = await openai.conversations.create({});
await run(agent, 'Hi', { conversationId: conv.id });

// previousResponseId — chain from the last response
const r1 = await run(agent, 'Hi');
const r2 = await run(agent, 'Follow-up', { previousResponseId: r1.lastResponseId });
```

## Platform-side conversation state, billing, and retention

> Source: https://developers.openai.com/api/docs/guides/conversation-state

Three platform mechanisms sit under the SDK's options:

1. **Manual state management** — pass the full alternating `user`/`assistant` message array on every request.
2. **Conversations API** — create a conversation object once and reference its ID; the platform persists "items, which can be messages, tool calls, tool outputs, and other data."
3. **`previous_response_id`** — chain each request off the prior response ID, giving the model full prior context without creating a conversation resource.

Cost and lifetime facts that change design decisions:

- With `previous_response_id` chaining, "all previous input tokens for responses in the chain are billed as input tokens" on each new call — the chain is not free context.
- For reasoning models, every item in the prior response's `output` array must be preserved to keep reasoning context and assistant-phase values intact across turns.
- Response objects persist **30 days** by default, configurable with `store: false`.
- Conversation objects and their items have **no TTL** — items attached to a conversation persist indefinitely. Treat this as a data-retention decision, not an implementation detail.

## Gaps

- Constructor signatures for Python's `EncryptedSession` and `AdvancedSQLiteSession` were named but not detailed on the fetched overview page; do not assert their parameters.

## Sources

- https://openai.github.io/openai-agents-python/sessions/
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/sessions.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/running-agents.mdx
- https://developers.openai.com/api/docs/guides/conversation-state

Fetched: 2026-08-05
