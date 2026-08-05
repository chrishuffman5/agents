# Skills in Claude Code

Contents:
- Skills vs custom commands
- Bundled skills
- Where skills live, precedence, discovery scope
- Nested skills, symlinks, skills-as-plugins, live reload
- Cowork / cloud sessions / scheduled tasks
- Reference content vs task content
- Arguments
- Dynamic context injection
- Running a skill in a subagent
- Skill content lifecycle and compaction
- Pre-approving tools
- Evaluating skills with skill-creator
- Listing budget and trigger troubleshooting
- Sharing

## Skills vs custom commands

> Source: https://code.claude.com/docs/en/skills

Create a `SKILL.md` and Claude adds it to its toolkit; Claude uses it when relevant, or you invoke it directly with `/skill-name`. Create a skill when you keep pasting the same instructions/checklist/procedure into chat, or when a section of CLAUDE.md has grown into a procedure rather than a fact — unlike CLAUDE.md, a skill's body loads only when used, so long reference material costs almost nothing until needed.

**Custom commands have been merged into skills.** `.claude/commands/deploy.md` and `.claude/skills/deploy/SKILL.md` both create `/deploy` and behave the same; existing `.claude/commands/` files keep working. Skills add a directory for supporting files, frontmatter to control who invokes them, and automatic loading when relevant.

Claude Code follows the Agent Skills open standard (agentskills.io) and extends it with invocation control, subagent execution (`context: fork`), and dynamic context injection (`` !`command` ``).

## Bundled skills

> Source: https://code.claude.com/docs/en/skills

Claude Code ships bundled skills such as `/doctor`, `/code-review`, `/batch`, `/debug`, `/loop`, `/claude-api`. Bundled skills are prompt-based (Claude orchestrates via tools); most built-in *commands* instead execute fixed logic directly. `/verify` and `/code-review` run only on explicit invocation (not automatically) as of Claude Code v2.1.215+. Disable all bundled skills except `/doctor` via the `disableBundledSkills` setting.

Three bundled skills for running/verifying an app (require v2.1.145+):

| Skill | Purpose |
|---|---|
| `/run` | Launch and drive your app to see a change working |
| `/verify` | Build and run your app to confirm a code change does what it should, without falling back to tests/type checks |
| `/run-skill-generator` | Teach `/run` and `/verify` how to build and launch your project; records a per-project skill at `.claude/skills/run-<name>/` |

## Where skills live

> Source: https://code.claude.com/docs/en/skills

| Location | Path | Applies to |
|---|---|---|
| Enterprise | managed settings | All users in the organization |
| Personal | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<skill-name>/SKILL.md` | This project only |
| Plugin | `<plugin>/skills/<skill-name>/SKILL.md` | Where the plugin is enabled |

Precedence on name collision: enterprise > personal > project. Any of these overrides a bundled skill with the same name. Plugin skills use a `plugin-name:skill-name` namespace so they never conflict. If a skill and a `.claude/commands/` file share a name, the skill wins.

**Discovery scope.** Project skills load from `.claude/skills/` in the starting directory and every parent up to the repo root. `--add-dir` adds another directory's `.claude/skills/` at startup — normally `--add-dir` / `/add-dir` grant only file access, not configuration discovery; skills are the one exception. The `permissions.additionalDirectories` setting does **not** load skills.

**Nested `.claude/skills/`.** Skills also load from nested directories below the working directory; they activate the first time Claude reads or edits a file in that subdirectory, not at session startup. A naming collision with a nested skill produces a directory-qualified command, e.g. `/apps/web:deploy`, and Claude Code appends the qualified-variants list to the root skill's content with an instruction to also invoke the matching variant.

**Symlinks.** A skill-name entry in enterprise/personal/project locations can symlink elsewhere; Claude Code follows it and loads the skill once even if reachable from multiple locations.

**Skills-as-plugins.** Add `.claude-plugin/plugin.json` to a skill folder and it loads as a plugin named `<name>@skills-dir`, able to bundle agents, hooks, and MCP servers too. Inside a project's `.claude/skills/`, this requires accepting the workspace trust dialog first.

**Live change detection.** Claude Code watches skill directories and picks up SKILL.md text edits within the current session — except a brand-new top-level skills directory (restart required) and plugin skill non-text changes (`hooks/`, `.mcp.json`, `agents/`, `output-styles/`), which need `/reload-plugins`.

**Skill directory layout**

```text
my-skill/
├── SKILL.md           # Main instructions (required)
├── template.md        # Template for Claude to fill in
├── examples/
│   └── sample.md      # Example output showing expected format
└── scripts/
    └── validate.sh    # Script Claude can execute
```

## Cowork, cloud sessions, scheduled tasks

> Source: https://code.claude.com/docs/en/skills

Cowork and cloud sessions (including routines) do **not** read `~/.claude/skills/` on your machine — they load skills enabled for your claude.ai account (synced at session start) plus, for cloud sessions, project skills committed to `.claude/skills/` in the cloned repo. A personal-only skill invoked by a routine reports "not found". Fixes: enable it for your claude.ai account, commit it to the repo, or ship it via a plugin declared in `.claude/settings.json` (repo-declared plugins install at session start). Desktop scheduled tasks run locally and use normal local-session discovery.

## Reference content vs task content

> Source: https://code.claude.com/docs/en/skills

**Reference content** (conventions, patterns, domain knowledge) runs inline for Claude to apply alongside conversation context.

**Task content** (step-by-step actions like deploy/commit/codegen) — pair with `disable-model-invocation: true` to require manual invocation, and optionally `context: fork` to run in its own subagent.

Keep the body concise: once loaded, content stays in context across turns, so every line is a recurring token cost. State what to do, not how and why.

## Arguments

> Source: https://code.claude.com/docs/en/skills

`$ARGUMENTS` holds everything typed after the skill name (`/fix-issue 123`). If the skill does not reference `$ARGUMENTS`, Claude Code appends `ARGUMENTS: <input>` at the end. Individual args: `$ARGUMENTS[N]` or `$N`. Stacking: `/write-tests /fix-issue 123` loads both skills and passes trailing text `123` as `$ARGUMENTS` to each — up to 6 skills stacked, stopping at the first non-inline-invocable skill (e.g. one with `context: fork`).

## Dynamic context injection

> Source: https://code.claude.com/docs/en/skills

`` !`<command>` `` runs a shell command **before** the skill content reaches Claude — the placeholder is replaced with literal output. This is preprocessing, not something Claude executes:

```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---

## Pull request context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
- Changed files: !`gh pr diff --name-only`

## Your task
Summarize this pull request...
```

Only recognized when `!` starts a line or follows whitespace. For multi-line commands use a fenced ` ```! ` block. Substitution runs once — output is not re-scanned for further placeholders. Disable entirely with `"disableSkillShellExecution": true` in settings (bundled/managed skills unaffected).

## Running a skill in a subagent

> Source: https://code.claude.com/docs/en/skills

`context: fork` runs the skill content as the prompt for an isolated subagent with no access to conversation history, in the **background** by default (the session keeps working; the result arrives when done). `background: false` blocks the invoking turn instead (requires v2.1.218+). `agent:` picks the subagent type (`Explore`, `Plan`, `general-purpose`, or a custom `.claude/agents/` subagent); default `general-purpose`. A forked background skill's edits fall outside session checkpoints — `/rewind` will not undo them, use git.

```yaml
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---

Research $ARGUMENTS thoroughly:
1. Find relevant files using Glob and Grep
2. Read and analyze the code
3. Summarize findings with specific file references
```

## Skill content lifecycle

> Source: https://code.claude.com/docs/en/skills

Once invoked, rendered SKILL.md content enters the conversation as a single message and persists for the rest of the session — Claude Code does not re-read it on later turns. `allowed-tools` grants still clear on your next message. Re-invoking a skill with identical rendered content adds only a short "already loaded" note rather than a duplicate copy (v2.1.202+). Auto-compaction re-attaches the most recent invocation of each skill after a summary, keeping the first 5,000 tokens per skill within a shared 25,000-token budget across all re-attached skills (oldest dropped first).

## Pre-approving tools

> Source: https://code.claude.com/docs/en/skills

`allowed-tools` grants tool access without prompting **for the invoking turn only**; it does not restrict which tools otherwise exist. For project-checked-in skills this takes effect only after the workspace trust dialog is accepted — review project skills before trusting a repo, since a skill can grant itself broad tool access.

```yaml
---
name: commit
description: Stage and commit the current changes
disable-model-invocation: true
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status *)
---
```

## Evaluating skills with skill-creator

> Source: https://code.claude.com/docs/en/skills

```text
/plugin install skill-creator@claude-plugins-official
```

If the marketplace is not found: `/plugin marketplace add anthropics/claude-plugins-official`, then retry. Then ask, e.g., "evaluate my summarize-changes skill with skill-creator". It automates:

- **Test cases** — prompts, input files, expected behavior stored in `evals/evals.json` inside the skill directory
- **Isolated runs** — one subagent per test case, recording token count and duration
- **Grading** — checks assertions against output, writing pass/fail with evidence to `grading.json`
- **Benchmark** — aggregates pass rate, time, and tokens for with-skill vs without-skill into `benchmark.json`
- **Version comparison** — blind A/B between two skill versions
- **Description tuning** — generates should-trigger / should-not-trigger prompts, measures hit rate, proposes description edits
- **Review viewer** — HTML report for inspecting outputs and recording qualitative feedback

## Listing budget and trigger troubleshooting

> Source: https://code.claude.com/docs/en/skills

If Claude does not trigger your skill: check that the description includes natural user keywords, verify it appears via "What skills are available?", try rephrasing to match the description, or invoke directly with `/skill-name`. If it triggers too often: make the description more specific or set `disable-model-invocation: true`.

The skill listing (names + descriptions loaded into context) is budgeted at **1% of the model's context window** by default (`skillListingBudgetFraction`, e.g. `0.02` for 2%; or the `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var for a fixed char count). On overflow, descriptions are dropped starting with the least-invoked skills. `/doctor` estimates the listing's context cost. Each entry's combined `description` + `when_to_use` text is separately capped at 1,536 chars (`skillListingMaxDescChars`).

## Sharing

> Source: https://code.claude.com/docs/en/skills

- **Project skills** — commit `.claude/skills/` to version control.
- **Plugins** — create a `skills/` directory in your plugin.
- **Managed** — deploy organization-wide through managed settings.

## Sources

- https://code.claude.com/docs/en/skills

Fetched: 2026-08-05
