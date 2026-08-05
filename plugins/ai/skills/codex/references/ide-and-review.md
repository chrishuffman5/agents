# Codex IDE extension and code review

Read when setting up the IDE extension, when the same prompt behaves differently in the IDE than the CLI, or when configuring `/review` and GitHub PR reviews. All facts as of 2026-08-05.

## Supported IDEs and install

> Source: https://learn.chatgpt.com/docs/ide

Supported editors:

- **VS Code** and VS Code-compatible editors (Cursor, Windsurf)
- **Xcode** (native integration)
- **JetBrains IDEs** (native integration)

Install: add the extension from the IDE's marketplace — VS Code Marketplace link `https://marketplace.visualstudio.com/items?itemName=openai.chatgpt` — then open Codex from the sidebar icon or the "Codex: Open Codex Sidebar" command, sign in with the OpenAI account, and start chatting with code context already loaded.

JetBrains- and Xcode-specific UI differences beyond "native integration" are **not detailed in the fetched corpus**. Neither is the keyboard-shortcut list.

Running the extension inside Cursor is supported, but Cursor's *own* agents and editor features are a separate product — use the `cursor` sibling skill for those.

## Features

> Source: https://learn.chatgpt.com/docs/ide

- **Editor integration** — brings open files and selections into the prompt; review edits in place.
- **Contextual awareness** — reference open files and recent chats from the composer.
- **In-place review** — focused diffs alongside source; accept or reject without navigating away.
- **Cloud delegation** — hand long-running tasks to Codex cloud while keeping chat continuity.

Best fit: focused localized edits, learning an unfamiliar codebase, reviewing changes immediately, and starting long tasks that finish in the cloud. The docs position the other surfaces as: **desktop app** for project coordination and long-running tasks, **ChatGPT web** for research and creation in the browser, **Codex CLI** for terminal inspection and automation, **Codex cloud** for parallel environments.

## Context differs between IDE and CLI

> Source: https://learn.chatgpt.com/docs/prompting

The IDE extension **automatically includes open files as context**. The CLI does not — paths must be mentioned explicitly, or attached with `/mention` and `@` path autocomplete. This is the standard explanation for "the same prompt works in my editor but not in the terminal."

- `@` + file path triggers autocomplete in both IDE and CLI: `@transform.ts`, `@foo.ts @schema.ts`.
- **Selection-based context**: highlight lines, then "Add to Codex Thread" from the command palette to include only those lines.

Practices the docs call out: open the relevant files before prompting; use selections to narrow focus; name the specific functions and modules rather than describing them; and reference existing conventions explicitly ("follow the patterns used in other tests").

## Settings layering

> Source: https://learn.chatgpt.com/docs/developer-settings

| Surface | Where settings live |
|---|---|
| Desktop / web app | ChatGPT preferences |
| CLI | `~/.codex/config.toml` |
| Project | `.codex/config.toml` |
| IDE extension | Shared `config.toml` agent settings **plus** editor-specific `chatgpt.*` keys |

Precedence follows the CLI's: CLI flags override project settings, which override user defaults (see `config-reference.md`). A team standard placed in `.codex/config.toml` therefore governs the IDE too — the `chatgpt.*` keys are only the editor-local ergonomics layer.

IDE-specific `chatgpt.*` keys:

| Key | Effect |
|---|---|
| `chatgpt.reviewDelivery` | `"inline"` (reviews land in the current chat) or `"detached"` (a separate review chat) |
| `composerEnterBehavior` | Whether Enter sends the message |
| `followUpQueueMode` | Whether follow-up messages queue or steer the currently running turn |
| `runCodexInWindowsSubsystemForLinux` | Execute Codex inside WSL when available |
| Font-size controls | Chat and rendered code |

`followUpQueueMode` is the one to change when a user complains that typing mid-turn derails the agent — queueing rather than steering usually matches expectations.

Other configurable areas: project/file-opening locations, command-output verbosity in chats, terminal tab defaults, model selection and reasoning effort, approval policy and sandbox preference, MCP server integrations, and Git config (branch naming, commit-message prompts).

Diagnostics are the same as the CLI: `/status`, `/debug-config`, and `--strict-config` for treating unrecognized keys as errors.

## `/review`

> Source: https://learn.chatgpt.com/docs/code-review

`/review` is available consistently across clients: ChatGPT Work (type it in the composer), the CLI (with preset options; see `codex review`), and the IDE extension (requires the project to be a Git repository).

Four scopes:

1. **Against a base branch** — finds the merge base and reviews the branch diff.
2. **Uncommitted changes** — staged, unstaged, and untracked files.
3. **A commit** — one specific commit's changes.
4. **Custom review instructions** — user-defined focus criteria.

Configuration:

- `review_model` in `config.toml` — review with a different (typically stronger) model than the one used for chat.
- `chatgpt.reviewDelivery = "detached"` — open reviews in a separate chat instead of the working one.

Output and interaction: findings appear as **inline comments in the review pane**. Leave feedback by hovering a line, clicking **+**, and writing a comment — Codex treats those as review guidance for the follow-up.

**Multi-repository projects**: when a project contains multiple folders each with its own Git repo, a repository selector in the review header switches which repo's findings are shown.

**Git actions in the review pane**: stage, unstage, or revert at three granularities — the whole diff (header buttons), an individual file, or a single hunk.

## GitHub PR context in the review pane

> Source: https://learn.chatgpt.com/docs/code-review

When Codex has GitHub access and the project is on a PR branch: view PR context and reviewer feedback in the sidebar, see comments alongside diffs in the review pane, and ask Codex to address specific feedback in place.

**Requirement**: install the GitHub CLI and run `gh auth login`. Missing `gh` auth is the usual reason the PR sidebar is empty.

## GitHub integration and `@codex`

> Source: https://learn.chatgpt.com/docs/third-party/github

Setup:

1. Set up Codex cloud for the target repository first.
2. Open Codex code-review settings at `chatgpt.com/codex/settings/code-review`.
3. Toggle **Code review** on for the repository.
4. Optionally enable **Automatic reviews** for all new PRs on that repo.

Request a review by commenting on a PR:

```
@codex review
@codex review for security regressions
```

Codex reacts with 👀, then posts a focused review covering **only P0 and P1 severity issues** — set expectations accordingly; it is not a style reviewer by default. Any `@codex` mention that does not say "review" starts a cloud chat/task using the PR as context.

Capabilities: reading PR diffs, posting GitHub code reviews, following repository guidance from `AGENTS.md`, and **pushing fixes** directly when it has permission.

Custom review rules live in `AGENTS.md` — root-level for repo-wide guidance, nested files for service-specific scope, and a dedicated **"Code Review Rules"** section for checks the reviewer should specifically apply.

The exact GitHub App OAuth permission scopes requested at install are **not stated in the fetched documentation**. Have the user read the consent screen before approving rather than accepting a described scope list.

## Sources

- https://learn.chatgpt.com/docs/ide
- https://learn.chatgpt.com/docs/prompting
- https://learn.chatgpt.com/docs/developer-settings
- https://learn.chatgpt.com/docs/code-review
- https://learn.chatgpt.com/docs/third-party/github
- https://learn.chatgpt.com/docs/developer-commands?surface=cli

Fetched: 2026-08-05
