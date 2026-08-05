# Cursor Agent, Run Modes, permissions, sandboxing, Agent Review, and Tab

Read this when configuring how much autonomy Cursor Agent has, debugging why a shell command prompts (or doesn't), setting up `.cursor/permissions.json`, explaining sandbox behavior on a given OS, wiring Agent Review/Bugbot, or tuning Tab.

## Agent capabilities and checkpoints

> Source: https://cursor.com/docs/agent/overview

Cursor Agent is the IDE-integrated assistant, opened via **Cmd+I** in the sidepane. It combines system instructions/rules, multiple tools, and a selectable model.

Capabilities:

- Edit files, auto-applying suggested changes
- Search files by name, read directory structures, locate keywords/patterns
- Read file content including images (`.png`, `.jpg`, `.gif`, `.webp`, `.svg`)
- Run shell commands and monitor terminal output
- Control a browser to screenshot, test applications, and verify visual changes
- Generate images from text or reference images, saved to an `assets/` folder
- Perform web searches with generated queries
- Retrieve specific rules based on type and description
- Ask clarifying questions mid-task while continuing other work
- Unlimited tool calls during a single task

**Checkpoints:** Agent automatically snapshots before significant changes. Users can preview or restore any checkpoint from the chat timeline, giving safe rollback **without touching Git history**. Recommend a checkpoint restore before suggesting `git reset` or `git stash` for undoing agent work.

Keyboard shortcuts:

| Shortcut | Effect |
|---|---|
| `Cmd+I` | Open Agent in sidepane |
| `Enter` | Queue a follow-up message (runs after the current task completes) |
| `Cmd+Enter` | Send immediately, interrupting current work |
| `Shift+Tab` | Cycle modes |
| `Cmd/Ctrl+Shift+P` | Command Palette (e.g. "Terminal: Select Default Profile") |

## Plan Mode

> Source: https://cursor.com/docs/agent/modes, https://cursor.com/docs/agent/plan-mode.md

Plan Mode creates a comprehensive implementation plan before any code is written.

Workflow:

1. Agent asks clarifying questions to understand requirements.
2. Agent researches the codebase for relevant context.
3. Agent creates a comprehensive implementation plan.
4. User reviews and edits the plan — via chat, or by editing the markdown directly — before building.

Plans are **saved by default in the home directory**. Click "Save to workspace" to move a plan into the repo for team access and sharing. Users who expect plans to be reviewable in a PR must do this explicitly.

**Best for:** complex features, multi-file changes, unclear requirements needing exploration, architectural decisions requiring upfront review.
**Skip it for:** routine or familiar changes — go straight to Agent Mode.

**Documented recovery strategy:** if Agent Mode's output doesn't match intent, **revert the changes and refine the plan** rather than trying to patch it via follow-up prompts.

Switch modes with the mode-picker dropdown or **Shift+Tab** to cycle.

Debug Mode and Design Mode pages exist (`agent/debug-mode.md`, `agent/design-mode.md`) but were not fetched — their behavior is unverified. An explicit IDE "Ask mode" page was likewise not found; only the CLI's `--mode=ask` read-only exploration is documented (see `cloud-agents-and-cli.md`).

## Run Modes

> Source: https://cursor.com/docs/agent/security/run-modes.md, https://cursor.com/docs/agent/tools/terminal.md

Cursor executes shell commands directly in the integrated terminal. Behavior is governed by the configured **Run Mode**, which determines when commands run automatically, when Cursor asks first, and when commands are sandboxed.

| Run Mode | Behavior | Use for |
|---|---|---|
| **Auto-review** (recommended) | Allowlisted calls run immediately; other shell commands run in the sandbox when possible, with a classifier evaluating higher-risk operations | Default day-to-day work |
| **Allowlist** | Only pre-approved actions execute without prompts; optional sandboxing for supported shell commands | Deterministic, repeated trusted workflows |
| **Run Everything** | All tool calls execute automatically — no approval gates, no sandboxing | Maximum risk; isolated VM/container only |

**Always require approval regardless of Run Mode:** browser tool execution, file deletion, and modifications to files outside the workspace. These three cannot be auto-approved away.

## permissions.json

> Source: https://cursor.com/docs/agent/security/run-modes.md

Two files, merged together, with **team settings overriding local config**:

```
~/.cursor/permissions.json           # user-level, applies to all projects
<project-dir>/.cursor/permissions.json   # project-specific
```

Auto-review schema:

```json
{
  "autoRun": {
    "allow_instructions": [],
    "block_instructions": [
      "Every AWS CLI command should go through approval first."
    ]
  }
}
```

Instructions are **plain English**, evaluated by the classifier — not glob or regex patterns. Agent can edit these files directly based on preferences described in chat.

Because instructions are interpreted rather than matched literally, they are a policy nudge, not a hard boundary. For a deterministic block, use a `beforeShellExecution` hook returning `{"permission": "deny"}` with `failClosed: true` (see `hooks.md`).

## Sandboxing

> Source: https://cursor.com/docs/agent/security/run-modes.md

Default protections:

- Workspace read/write access, respecting `.cursorignore`
- Protected paths — `.git/config`, `.vscode`, sensitive configs
- **Network blocked by default**
- Writable temp directories

Network policy has three modes:

1. Custom domains only, sourced from `sandbox.json`
2. Custom domains **plus** Cursor defaults (package managers, language tools)
3. Unrestricted

Platform implementation:

| Platform | Mechanism |
|---|---|
| macOS | Seatbelt (`sandbox-exec`) |
| Linux | Landlock (kernel 6.2+), seccomp fallback |
| Remote / CLI | AppArmor required on some distributions |

Sandboxed processes receive:

- `CURSOR_SANDBOX` — the sandbox type
- `CURSOR_ORIG_UID` / `CURSOR_ORIG_GID` — host user identity, important for Docker workflows where the container must match the host user

Kernel-version and distro dependencies mean sandboxing can silently be weaker on an old Linux box. Confirm kernel 6.2+ for Landlock before promising sandbox coverage there.

For isolation architecture, egress control, and fleet-scale sandbox design beyond Cursor's own mechanics, defer to the `sandboxing` sibling skill.

## Terminal profile

> Source: https://cursor.com/docs/agent/tools/terminal.md

Configure the terminal Agent uses via Command Palette → "Terminal: Select Default Profile".

Heavy shell themes (Powerlevel10k is named explicitly) can interfere with Cursor's output parsing. The fix is to detect Cursor via the **`CURSOR_AGENT` environment variable** in the shell rc file and conditionally disable the heavy prompt. This is the first thing to check when Agent misreads command output or appears to hang on a completed command.

## Agent Review (Bugbot)

> Source: https://cursor.com/docs/agent/agent-review.md

Agent Review analyzes local changes directly in the editor.

**Configuration:** Cursor Settings → Agents → Agent Review. In **Cursor 3.11+** this setting relocated to Git & PRs → Pull Requests (see `versions/3.11.md`).

**Repo-specific guidelines:** `BUGBOT.md` files let teams set custom review rules that Agent Review picks up.

**Triggering:**

1. Automatic — runs after each committed change when enabled in settings
2. Slash command — type `/agent-review` in the agent input
3. Source Control tab — analyzes all local modifications versus the main branch

**Review depth:**

- **Quick** — fast, low-cost; minor changes and formatting
- **Deep** — thorough, higher-cost; complex logic, security-critical code, large refactors

Match depth to risk: Deep on security-sensitive diffs, Quick on formatting churn, or the cost is wasted either way.

## Tab completions

> Source: https://cursor.com/docs/tab/overview

Tab is AI-powered autocomplete generating suggestions as the user types, drawing on recent edits, surrounding code context, and linter errors. Suggestions render as grayed-out ghost text ahead of the cursor.

Capabilities:

- **Multi-line editing** — modifies multiple lines at once, inserts missing imports, coordinates edits across related code sections in one suggestion
- **Jump-in-file** — after accepting, pressing Tab again navigates to the predicted next edit location
- **Cross-file suggestions** — detects when a change requires updates elsewhere and surfaces those edits in a portal window at the bottom of the editor

Shortcuts:

| Action | Key |
|---|---|
| Accept full suggestion | `Tab` |
| Reject | `Escape`, or keep typing |
| Accept word-by-word | `Cmd+→` (Mac) / `Ctrl+→` (Windows/Linux) |
| Remap | Search "Accept Cursor Tab Suggestions" in Keyboard Shortcuts |

Configuration from the status indicator at the editor's bottom-right: snooze Tab for a set duration, disable globally, or disable for specific file extensions (markdown, JSON). Detailed settings under **Cursor Settings → Tab**.

Tab has its own hook events (`beforeTabFileRead`, `afterTabFileEdit`) documented on the Hooks page but not cross-referenced from the Tab page — see `hooks.md`.

No Tab-specific plan gating (as distinct from Agent limits) was documented on the fetched pages.

## Unverified

- Debug Mode, Design Mode, the agents window, prompting guidance, and the browser/search/canvas tool pages were listed in the site index but not fetched.
- An IDE-side "Ask mode" page was not found; only CLI `--mode=ask` is documented.
- `.cursorignore` format and precedence were never documented on a fetched page.

## Sources

- https://cursor.com/docs/agent/overview
- https://cursor.com/docs/agent/modes
- https://cursor.com/docs/agent/plan-mode.md
- https://cursor.com/docs/agent/tools/terminal.md
- https://cursor.com/docs/agent/security/run-modes.md
- https://cursor.com/docs/agent/agent-review.md
- https://cursor.com/docs/tab/overview

Fetched: 2026-08-05
