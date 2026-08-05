# pi session format — version 3

Read this when writing a parser, exporter, or audit tool over pi's `.jsonl` session files. This is the only versioned artifact documented in pi's docs; the docs themselves are published under an unversioned `/docs/latest/` path with no per-release changelog pages, so there is no other version-gated behavior to record here as of 2026-08-05.

## Version marker

> Source: https://pi.dev/docs/latest/session-format

The version lives on the header line, which is always the first line of the file:

```json
{"type":"session","version":3,"id":"uuid","timestamp":"...","cwd":"/path"}
```

The same header shape appears as the first record of the `--mode json` event stream (see `../modes-and-cli.md`), so a stream consumer and a file parser can share the version check.

**Always branch on `version` before parsing.** Only `version: 3` is documented; treat any other value as unknown and refuse rather than guessing. Versions 1 and 2 are not described in the fetched documentation — their entry shapes are unverified here.

## File layout in version 3

> Source: https://pi.dev/docs/latest/session-format

Path convention: `~/.pi/agent/sessions/--<path>--/<timestamp>_<uuid>.jsonl`, one session per file. `PI_CODING_AGENT_SESSION_DIR` relocates the root.

Every entry after the header carries:

```
{
  type: string,
  id: string (8-char hex),
  parentId: string | null,
  timestamp: string (ISO format)
}
```

Entries form a **tree** through `id`/`parentId`; the current position is the active leaf. A parser must not assume file order equals conversation order — reconstruct the active branch by walking `parentId` from the leaf, or a fork's abandoned branch will be replayed as if it were part of the conversation.

## Entry types in version 3

> Source: https://pi.dev/docs/latest/session-format

| `type` | Payload |
|---|---|
| `SessionHeader` (`session`) | First line only; carries `version`, `id`, `timestamp`, `cwd` |
| `SessionMessageEntry` | Wraps `AgentMessage` objects; roles `user`, `assistant`, `toolResult`, `bashExecution`, `custom` |
| `ModelChangeEntry` (`model_change`) | `provider`, `modelId` |
| `ThinkingLevelChangeEntry` (`thinking_level_change`) | `thinkingLevel` |
| `CompactionEntry` | Summary of earlier context; optional `retainedTail` array of messages; `tokensBefore` count |
| `BranchSummaryEntry` | Written on branch switch; `fromId` references the branched-from entry |
| `CustomEntry` (`custom`) | `customType`, `data` — extension state, **never sent to the LLM** |
| `CustomMessageEntry` | `content`, `display` boolean, optional `details` — extension-injected and **sent to the LLM** |
| `LabelEntry` (`label`) | `targetId`, `label` — bookmarks |
| `SessionInfoEntry` (`session_info`) | `name` — display name |

## Parser notes

> Source: https://pi.dev/docs/latest/session-format
> Source: https://pi.dev/docs/latest/compaction

- To reconstruct "what the model actually saw" at a point in time, include `SessionMessageEntry` and `CustomMessageEntry`, and exclude `CustomEntry`.
- `CompactionEntry` marks a lossy boundary: content before it exists in the file but was replaced by a summary in the model's context. Repeated compactions summarize from the previous compaction's `firstKeptEntryId`, not from the compaction entry, so spans overlap in the file.
- `ModelChangeEntry` and `ThinkingLevelChangeEntry` let an audit tool attribute each turn to a specific provider/model and reasoning level.
- Ephemeral runs (`--no-session`) write no file at all, and `PI_SESSION_FILE` is unset.

**Unverified:** field-level types beyond those listed (e.g. the full `AgentMessage` shape, `retainedTail` element schema) are not published on the fetched pages. Inspect a real session file rather than assuming.

## Sources

- https://pi.dev/docs/latest/session-format
- https://pi.dev/docs/latest/sessions
- https://pi.dev/docs/latest/compaction
- https://pi.dev/docs/latest/json
- https://pi.dev/docs/latest/environment-variables

Fetched: 2026-08-05
