# SKILL.md format and frontmatter reference

Contents:
- Minimal spec-level SKILL.md
- Required field constraints
- Claude Code frontmatter field table
- Portable-frontmatter matrix (what claude.ai / Skills API accept)
- String substitutions
- Invocation control matrix
- Naming and description rules

## Minimal spec-level SKILL.md

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview

```markdown
---
name: your-skill-name
description: Brief description of what this Skill does and when to use it
---

# Your Skill Name

## Instructions
[Clear, step-by-step guidance for Claude to follow]

## Examples
[Concrete examples of using this Skill]
```

Required fields are `name` and `description`. The `anthropics/skills` repo template is even shorter — frontmatter plus "Insert instructions below".

## Required field constraints

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview

`name`:
- Maximum 64 characters
- Only lowercase letters, numbers, and hyphens
- Cannot contain XML tags
- Cannot contain the reserved words "anthropic" or "claude"

`description`:
- Must be non-empty
- Maximum 1024 characters
- Cannot contain XML tags
- Must state both what the Skill does and when to use it

Upload requirements for the Skills API additionally demand a top-level `SKILL.md`, a single common root directory across all files, a top-level directory name matching the `name` field (case/underscore insensitive), and a maximum uncompressed upload of 30 MB.

## Claude Code frontmatter field table

> Source: https://code.claude.com/docs/en/skills

Claude Code skills follow the Agent Skills open standard (agentskills.io) and extend it. All fields are optional; only `description` is recommended so Claude knows when to use the skill. Boolean fields accept `yes`/`no`/`on`/`off`/`1`/`0` in any case plus `true`/`false` (Claude Code v2.1.218+; earlier versions accept only `true`/`false`).

```yaml
---
name: my-skill
description: What this skill does
disable-model-invocation: true
allowed-tools: Read Grep
---
```

| Field | Required | Description |
|---|---|---|
| `name` | No | Display name in skill listings. Defaults to directory name. |
| `description` | Recommended | What the skill does and when to use it. If omitted, uses the first markdown paragraph. Put the key use case first — combined `description` + `when_to_use` is truncated at **1,536 characters** in the skill listing. |
| `when_to_use` | No | Additional trigger phrases/example requests, appended to `description`; counts toward the 1,536-char cap. |
| `argument-hint` | No | Autocomplete hint for expected arguments, e.g. `[issue-number]`. |
| `arguments` | No | Named positional arguments for `$name` substitution. Space-separated string or YAML list; names map to positions in order. |
| `disable-model-invocation` | No | `true` prevents Claude from auto-loading the skill (manual `/name` only). Also blocks preloading into subagents and (v2.1.196+) scheduled-task firing. Default `false`. |
| `user-invocable` | No | `false` hides the skill from the `/` menu (background knowledge only). Default `true`. |
| `allowed-tools` | No | Tools Claude can use without asking during the invoking turn; grant clears on the next message. Space/comma-separated string or YAML list. |
| `disallowed-tools` | No | Tools removed from Claude's pool while the skill is active; clears on the next message. Cannot remove `EndConversation` while other tools remain. |
| `model` | No | Model override for the current turn only (not saved to settings). Accepts the same values as `/model`, or `inherit`. |
| `effort` | No | Effort level override: `low`, `medium`, `high`, `xhigh`, `max` (model-dependent). Default: inherits session. |
| `context` | No | `fork` runs the skill in a forked subagent context. |
| `agent` | No | Subagent type used when `context: fork` is set (`Explore`, `Plan`, `general-purpose`, or custom). Default `general-purpose`. |
| `background` | No | With `context: fork` only; `false` waits for the result in the invoking turn instead of running in background. Default `true`. Requires v2.1.218+. |
| `hooks` | No | Hooks scoped to this skill's lifecycle. |
| `paths` | No | Glob patterns limiting auto-activation to matching files. Comma-separated string or YAML list. |
| `shell` | No | `bash` (default) or `powershell` for inline `!command` execution in this skill. |
| `metadata` | No | Free-form YAML map for custom tooling; Claude Code ignores it (drops non-map values). |
| `license` | No | Agent Skills spec field; Claude Code accepts but does not act on it. |
| `compatibility` | No | Agent Skills spec field (environment requirements), up to 500 chars; accepted but unused by Claude Code. |

## Portable-frontmatter matrix

> Source: https://code.claude.com/docs/en/skills

| Distribution path | Frontmatter fields allowed |
|---|---|
| Claude Code skills (any level, including plugins) | Every field in the table above |
| claude.ai skill uploads, Skills API, `package_skill.py` from anthropics/skills | `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools` **only** |

Including a disallowed field fails packaging/upload with a hard error:

```
Unexpected key(s) in SKILL.md frontmatter: argument-hint. Allowed properties are: allowed-tools, compatibility, description, license, metadata, name
```

Design consequence: if a skill must ship to both Claude Code and the API/claude.ai, keep frontmatter to the portable six and express everything else in the body.

## String substitutions (Claude Code)

> Source: https://code.claude.com/docs/en/skills

| Variable | Description |
|---|---|
| `$ARGUMENTS` | All arguments passed at invocation. If absent from the content, appended as `ARGUMENTS: <value>`. |
| `$ARGUMENTS[N]` | Specific 0-based-index argument. |
| `$N` | Shorthand for `$ARGUMENTS[N]`, e.g. `$0`, `$1`. |
| `$name` | Named argument from the `arguments` frontmatter list (positional mapping). |
| `${CLAUDE_SESSION_ID}` | Current session ID. |
| `${CLAUDE_EFFORT}` | Current effort level: `low`/`medium`/`high`/`xhigh`/`max`. |
| `${CLAUDE_SKILL_DIR}` | Directory containing this skill's SKILL.md (for plugin skills, the skill's subdirectory, not the plugin root). Substituted in both skill markdown and `allowed-tools` Bash rules — the latter requires v2.1.129+. |
| `${CLAUDE_PROJECT_DIR}` | Project root directory (same value hooks/MCP servers receive). Requires v2.1.196+. |

Indexed args use shell-style quoting: `/my-skill "hello world" second` → `$0` = `hello world`, `$1` = `second`. Unmatched indexed placeholders stay literal; unmatched named placeholders expand to an empty string. Escape a literal `$` before a digit / `ARGUMENTS` / an argument name with `\$`.

Pre-approving a bundled script with `${CLAUDE_SKILL_DIR}`:

```yaml
---
name: render-chart
description: Render a chart from a CSV file
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/render.sh *)
---

Run `${CLAUDE_SKILL_DIR}/scripts/render.sh <csv-file>` to render the chart.
```

## Invocation control matrix

> Source: https://code.claude.com/docs/en/skills

| Frontmatter | You can invoke | Claude can invoke | Context loading |
|---|---|---|---|
| (default) | Yes | Yes | Description always in context; full skill loads when invoked |
| `disable-model-invocation: true` | Yes | No | Description not in context; full skill loads only when you invoke |
| `user-invocable: false` | No | Yes | Description always in context; full skill loads when invoked |

Use `disable-model-invocation: true` for side-effecting workflows (`/deploy`, `/commit`) you want to trigger yourself. Use `user-invocable: false` for background knowledge that is not an actionable command.

Three ways to restrict which skills Claude can invoke:
1. Deny the `Skill` tool entirely in `/permissions`.
2. Allow/deny specific skills: `Skill(commit)` (exact match), `Skill(review-pr *)` (prefix match).
3. `disable-model-invocation: true` in the skill's own frontmatter (removes it from Claude's context entirely).

## Naming and description rules

> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices
> Source: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview

- Prefer gerund names: `processing-pdfs`, `analyzing-spreadsheets`, `managing-databases`, `testing-code`, `writing-documentation`. Noun phrases (`pdf-processing`) and action forms (`process-pdfs`) are acceptable.
- Avoid vague (`helper`, `utils`, `tools`), overly generic (`documents`, `data`, `files`), reserved-word (`anthropic-helper`, `claude-tools`), and internally inconsistent naming across a collection.
- Always write descriptions in third person — the text is injected into the system prompt. "Processes Excel files and generates reports", not "I can help you...".
- Be specific and include key terms; each skill has exactly one description and Claude may be selecting from 100+ skills.

Effective examples:

```yaml
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```
```yaml
description: Analyze Excel spreadsheets, create pivot tables, generate charts. Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx files.
```
```yaml
description: Generate descriptive commit messages by analyzing git diffs. Use when the user asks for help writing commit messages or reviewing staged changes.
```

Avoid: `Helps with documents`, `Processes data`, `Does stuff with files`.

## Sources

- https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview
- https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices
- https://code.claude.com/docs/en/skills
- https://github.com/anthropics/skills/blob/main/template/SKILL.md

Fetched: 2026-08-05
