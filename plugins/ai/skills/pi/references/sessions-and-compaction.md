# pi: Sessions, Tree History, Sharing, and Compaction

Read this when navigating or recovering session history, when building tooling over session files, or when tuning context behavior.

## Tree-structured history

> Source: https://pi.dev/docs/latest/sessions

Sessions live under `~/.pi/agent/sessions/` as hierarchical trees — one JSONL file per session. "Every entry has an `id` and `parentId`, and the current position is the active leaf." A single session file therefore holds multiple conversation branches; branching does not require a new file.

`/tree` opens interactive navigation: jump to any previous point and continue from there. Controls: ↑/↓ move between entries, ←/→ page, Ctrl+←/Ctrl+→ fold and unfold branches.

Selection behavior matters and is easy to misread:

- Selecting a **user** message moves the active leaf to that message's **parent** and places the message text in the editor, ready to edit and resubmit.
- Selecting a **non-user** entry moves the leaf to that point with an empty editor, so the conversation continues from there.

Nothing is deleted by navigating — the abandoned branch remains in the file and can be returned to.

## Session commands

> Source: https://pi.dev/docs/latest/sessions

| Command / flag | Effect |
|---|---|
| `/resume` or `pi -r` | Browse and select previous sessions |
| `/fork <path\|id>` | New session starting from an earlier user message |
| `/clone` | Duplicate the current active branch into a new session |
| `/name <name>` | Set a human-readable display name |
| `--session <path\|id>` | Use a specific session file or partial session ID |
| `-c` / `--continue` | Resume the most recent session |
| `--fork <path\|id>` | Fork into a new file at launch |
| `--no-session` | Ephemeral, unsaved |

`--no-session` also leaves `PI_SESSION_FILE` unset in the bash-tool environment — scripts that key off that variable must handle its absence.

## Sharing and export

> Source: https://pi.dev/docs/latest/sessions

- `/export [file]` — export the session to HTML or JSONL.
- `/share` — upload the session as a **private GitHub gist** with a shareable HTML link. `PI_SHARE_VIEWER_URL` overrides the viewer base URL.

Treat both as data-egress operations. A session transcript can contain source code, command output, environment details, and any secret a tool happened to print. "Private gist" means unlisted on GitHub, not access-controlled to your org — anyone with the link can read it.

**Unverified:** gist retention/expiry and visibility options beyond "private" are not documented on the fetched pages.

## Session file format

> Source: https://pi.dev/docs/latest/session-format

Path convention: `~/.pi/agent/sessions/--<path>--/<timestamp>_<uuid>.jsonl`.

Base structure for all entries except the header:

```
{
  type: string,
  id: string (8-char hex),
  parentId: string | null,
  timestamp: string (ISO format)
}
```

Header (first line only):

```json
{"type":"session","version":3,"id":"uuid","timestamp":"...","cwd":"/path"}
```

Entry types:

| Type | Contents |
|---|---|
| `SessionMessageEntry` | Conversation messages wrapping `AgentMessage` objects with roles `user`, `assistant`, `toolResult`, `bashExecution`, `custom` |
| `ModelChangeEntry` | `{"type":"model_change","provider":"...","modelId":"..."}` |
| `ThinkingLevelChangeEntry` | `{"type":"thinking_level_change","thinkingLevel":"..."}` |
| `CompactionEntry` | Summary of earlier context, optional `retainedTail` array, `tokensBefore` count |
| `BranchSummaryEntry` | Created on branch switch, with `fromId` referencing the branched-from entry |
| `CustomEntry` | Extension state, **not sent to the LLM**: `{"type":"custom","customType":"...","data":{}}` |
| `CustomMessageEntry` | Extension-injected message **sent to the LLM**: `content`, `display` boolean, optional `details` |
| `LabelEntry` | Bookmark: `{"type":"label","targetId":"...","label":"..."}` |
| `SessionInfoEntry` | Display name: `{"type":"session_info","name":"..."}` |

The `CustomEntry` vs `CustomMessageEntry` distinction is the one to get right when auditing what an extension actually put in front of the model.

Version-gated detail for parsers: `references/versions/session-format-v3.md`.

## Auto-compaction

> Source: https://pi.dev/docs/latest/compaction

Trigger: `contextTokens > contextWindow - reserveTokens`.

| Setting | Default | Purpose |
|---|---|---|
| `reserveTokens` | 16384 | Response buffer |
| `keepRecentTokens` | 20000 | Recent content preserved verbatim |

Algorithm:

1. Walk backward through messages accumulating tokens until the `keepRecentTokens` threshold is reached.
2. Identify a valid cut point — it must land on a user/assistant message boundary, **never mid-tool-result**.
3. Extract messages from the previous compaction boundary to the cut point.
4. Generate an LLM summary in a structured format.
5. Append a `CompactionEntry` tracking file operations.
6. Reload the session using the summary plus the kept messages.

Across repeated compactions: "On repeated compactions, the summarized span starts at the previous compaction's kept boundary (`firstKeptEntryId`), not at the compaction entry itself" — preserving content through multiple compression cycles and recalculating token counts to reflect the actual pre-compaction context.

Configuration in `~/.pi/agent/settings.json` or project `.pi/settings.json`:

```json
{
  "compaction": {
    "enabled": true,
    "reserveTokens": 16384,
    "keepRecentTokens": 20000
  }
}
```

`"enabled": false` disables the automatic pass while leaving manual `/compact [instructions]` available — the right setting when transcript fidelity matters more than session length, since compaction is lossy by construction.

Raise `reserveTokens` when responses are being truncated; raise `keepRecentTokens` when the agent forgets recent work after a compaction. Both increase how early compaction triggers.

Compaction events are also visible in JSON mode as `compaction_start` / `compaction_end` (see `modes-and-cli.md`).

## Sources

- https://pi.dev/docs/latest/sessions
- https://pi.dev/docs/latest/session-format
- https://pi.dev/docs/latest/compaction
- https://pi.dev/docs/latest/usage
- https://pi.dev/docs/latest/environment-variables

Fetched: 2026-08-05
