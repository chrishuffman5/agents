# Cursor rules, AGENTS.md, and context management

Read this when writing or debugging `.cursor/rules/*.mdc`, deciding between rules and `AGENTS.md`, resolving rule-precedence conflicts across team/project/user scope, choosing `@`-mentions, or explaining how Cursor indexes a codebase.

## Rules directory structure

> Source: https://cursor.com/docs/context/rules

Project rules live in `.cursor/rules` as `.mdc` files:

```
.cursor/rules/
  rule-name.mdc           # recognized as a project rule
  plain-file.md           # ignored — needs .mdc extension
  frontend/
    components.mdc        # organized in folders
```

Plain markdown files must use the `.mdc` extension **with YAML frontmatter** to function as project rules. A `.md` file in this directory is not a rule and produces no error — it simply never loads. Check the extension first whenever a user reports "my rule isn't being applied".

Subdirectories under `.cursor/rules/` are supported for organization.

## The four rule types

> Source: https://cursor.com/docs/context/rules

| Type | Trigger | Frontmatter |
|------|---------|-------------|
| Always Apply | Every chat session | `alwaysApply: true` |
| Apply Intelligently | When Agent determines relevance | `description` field + `alwaysApply: false` |
| Apply to Specific Files | When a file matches a glob pattern | `globs` field + `alwaysApply: false` |
| Apply Manually | Only via `@`-mention in chat | Omit both `globs` and `description` |

Frontmatter format:

```yaml
---
description: "Purpose of this rule"
alwaysApply: false
globs: src/**/*.tsx, src/**/*.ts
---
```

Resolution behavior:

- When `alwaysApply: true`, the rule is always included and **`globs` and `description` are ignored**.
- Otherwise the rule auto-attaches when a file matches `globs`.
- Otherwise Agent selects it based on the `description` field's relevance to the task — so a vague `description` is the reason an "Apply Intelligently" rule never fires.
- With neither field set, the rule loads only on explicit `@`-mention.

**Glob syntax:** `*` matches any single filename segment; `**` matches recursive directories. Examples: `*.ts` (root-level TS files), `src/**/*.tsx` (React files anywhere under `src/`), comma-separated for multiple patterns: `docs/**/*.md, docs/**/*.mdx`.

## Rule authoring best practices

> Source: https://cursor.com/docs/context/rules

- Keep rules under 500 lines; split large rules into multiple files.
- Reference other files rather than copying their content into the rule.
- Write concrete, actionable guidance rather than vague principles.
- Avoid duplicating existing codebase documentation.

Rules are model context, not enforcement. Anything that must happen every time — formatting, secret scanning, blocking a command class — belongs in `.cursor/hooks.json` or `.cursor/permissions.json` instead. See `hooks.md` and `agent-and-permissions.md`.

## AGENTS.md support

> Source: https://cursor.com/docs/context/rules

`AGENTS.md` is a plain markdown file with **no frontmatter or metadata**, placed at the project root or in subdirectories. Nested `AGENTS.md` files are supported, and **more specific (deeper) instructions take precedence** over parent-directory versions.

The Cursor CLI also loads `AGENTS.md` and `CLAUDE.md` at the project root as rules (per the CLI docs — see `cloud-agents-and-cli.md`). This is the practical bridge for a repo that already carries `CLAUDE.md`: the CLI reads it, and `AGENTS.md` covers the IDE.

Choose `AGENTS.md` for broad always-on project guidance where no conditional targeting is needed, and `.cursor/rules/*.mdc` when the guidance should be glob-scoped, description-selected, or manually invoked.

## Team rules and precedence

> Source: https://cursor.com/docs/context/rules

Enterprise teams manage organization-wide rules via a dashboard at `cursor.com/dashboard/team-content`.

Application and precedence order: **Team Rules → Project Rules → User Rules**, with earlier sources in that list taking precedence when guidance conflicts. A user rule therefore cannot override a team rule — point admins here when they ask how to make a policy stick across a team's editors.

## Memories

> Source: https://cursor.com/docs/context/rules

No dedicated "Memories" documentation page could be located on `cursor.com` or `docs.cursor.com` as of 2026-08-05. Direct URL attempts (`/docs/context/memories`, `/docs/agent/memories`, `/help/customization/memories.md`) 404'd or redirected to Rules content; a full-text search of the site's `llms.txt` index for "memor" returned zero hits; the product changelog carried no Memories entry.

The closest official content is the Rules system above and the `@`-mentions/context page, neither of which documents an auto-generated persistent "Memories" feature by that name.

**Treat Memories as undocumented.** Do not describe its storage location, generation trigger, per-project scope, or enable/disable UI. If a user insists the feature exists in their build, say the documentation was not findable and work from Rules + `AGENTS.md`.

## @ Mentions for context

> Source: https://cursor.com/docs/context/@-symbols

The `@` mention system attaches specific context to a chat or agent conversation:

| Mention | Attaches |
|---|---|
| `@auth.ts` | A specific file |
| `@src/components/` | A folder (use `/` after selection to navigate deeper) |
| `@Terminals` | Terminal output |
| `@Past Chats` | Previous conversations |
| `@Browser` | Built-in browser context |
| `@Commit (Diff of Working State)` | Uncommitted changes |
| `@Branch (Diff with Main)` | Full branch diff comparison |

Multiple `@` items can be attached in a single conversation by invoking `@` repeatedly.

Documented guidance: "Use @ mentions when you know which files are relevant. If you're not sure which files matter, skip it — Agent finds relevant files through its own search." Over-attaching context is a real anti-pattern here, not just a cost concern.

`@`-mention is also the only way to load an "Apply Manually" rule (one with neither `globs` nor `description`).

## Codebase indexing

> Source: https://cursor.com/docs/context/codebase-indexing

Cursor builds embeddings of the codebase **without storing raw source code**: "Filenames are obfuscated and code chunks are encrypted. When Agent searches, Cursor retrieves the embeddings and decrypts the chunks on the client side." Code content is held in memory during indexing and then discarded — never stored in plaintext. File paths are encrypted before server transmission.

**Instant Grep** is a custom search engine described as outperforming `ripgrep` on large codebases. It runs automatically and supports regex and word-boundary matching for tracing references across files.

**Multi-root workspaces** are supported and all codebases are indexed automatically and available as Agent context, but:

- Some features — worktrees explicitly — are **disabled** in multi-root setups.
- **Cloud Agents do not support multi-root workspaces.**

Raise both constraints before recommending a multi-root workspace to anyone using worktree isolation or cloud agents.

## Unverified

- `.cursorignore` — referenced by the agent tooling and sandbox docs (workspace read/write "respects `.cursorignore`") but its file format, syntax, and precedence were not documented on any fetched page.
- Whether Privacy Mode alters or skips indexing/embedding generation was not stated on the codebase-indexing page. See `enterprise-and-privacy.md` for what the privacy docs do state.

## Sources

- https://cursor.com/docs/context/rules
- https://cursor.com/docs/context/@-symbols
- https://cursor.com/help/customization/context.md
- https://cursor.com/docs/context/codebase-indexing

Fetched: 2026-08-05
