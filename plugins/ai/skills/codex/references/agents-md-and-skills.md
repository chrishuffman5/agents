# Codex `AGENTS.md` and Skills

Read when instructions aren't reaching the model, when structuring guidance across a monorepo, or when packaging a repeatable workflow as a Codex Skill. For *authoring* high-quality SKILL.md content (progressive disclosure technique, description writing, evals), use the `agent-skills` sibling skill. All facts as of 2026-08-05.

## AGENTS.md discovery

> Source: https://learn.chatgpt.com/docs/agent-configuration/agents-md

Codex reads `AGENTS.md` before doing any work and builds an instruction chain **once per run** — in the TUI, once per launched session. Changing an `AGENTS.md` mid-session does not re-read it; restart.

Discovery has two levels:

1. **Global scope** — Codex home, default `~/.codex`. Checks `AGENTS.override.md` first, falls back to `AGENTS.md`. Only the **first non-empty file** at this level is used.
2. **Project scope** — walks from the Git root down to the current working directory. In each directory it checks `AGENTS.override.md`, then `AGENTS.md`, then any names configured in `project_doc_fallback_filenames`. **At most one file per directory.**

## Merge order and override semantics

> Source: https://learn.chatgpt.com/docs/agent-configuration/agents-md

Codex **concatenates** discovered files from the root down, joined by blank lines. Nothing is replaced or dropped — files closer to the current directory simply appear later in the combined prompt, so their guidance overrides earlier guidance by recency. A nested `payments/AGENTS.override.md` supersedes repo-root guidance for work done in `payments/`.

Two file names:

| Name | Role |
|---|---|
| `AGENTS.md` | Persistent guidance; the checked-in team standard |
| `AGENTS.override.md` | Temporary replacement; takes precedence within its directory |

`project_doc_max_bytes` defaults to **32 KiB**. Split large instruction sets across nested directories rather than growing one file past the cap. When a repo's root guidance stops taking effect after it grows, check this limit first.

Codex reads `AGENTS.md`, not `CLAUDE.md`. In a repo shared with Claude Code, maintain both — Claude Code can bridge with an `@AGENTS.md` import from its `CLAUDE.md` (see the `claude-code` sibling), so `AGENTS.md` can remain the single authored source.

## What belongs where

> Source: https://learn.chatgpt.com/docs/agent-configuration/agents-md

The docs draw the division explicitly:

- **AGENTS.md** shapes behavior. Required team guidance belongs here or in checked-in docs.
- **Memories** carry local context forward. Treat them as a helpful recall layer, **not** the source of truth for rules that must always apply.
- **Skills** package repeatable processes.
- **MCP** connects Codex to systems outside the local workspace.

None of these is enforcement. A rule that must hold regardless of model behavior belongs in `requirements.toml`, sandbox configuration, or an execpolicy `.rules` file — see `enterprise.md`.

`codex debug prompt-input` renders the exact model-visible prompt input list as JSON. That is the definitive answer to "did my AGENTS.md actually load?" — use it before rewriting instructions that may never have been read.

## Codex Skills

> Source: https://learn.chatgpt.com/docs/build-skills

Skills are reusable workflow packages extending both ChatGPT and Codex, bundling "instructions, resources, and optional scripts so either product can follow a workflow reliably." They are built on the open agent-skills standard.

Required layout:

```
my-skill/
├── SKILL.md          (required)
├── scripts/          (optional)
├── references/       (optional)
├── assets/           (optional)
└── agents/openai.yaml (optional)
```

`SKILL.md` must carry frontmatter with `name` and `description`, followed by the workflow instructions.

### Discovery

Codex scans **upward through `.agents/skills` directories**:

| Scope | Location |
|---|---|
| Repository | `.agents/skills` in the current directory, parent folders, and the repo root |
| User | `$HOME/.agents/skills` |
| Admin | `/etc/codex/skills` |
| System | Skills built into Codex |

Note the directory name: `.agents/skills`, not `.codex/skills`. A skill placed in the wrong directory is simply never discovered, with no error.

### Activation

Two modes:

1. **Explicit** — `$skill` in Codex, `@skill` in ChatGPT.
2. **Implicit** — Codex/ChatGPT autonomously selects a matching skill from its `description`.

Because implicit selection reads only the description, a vague description is the usual cause of a skill that "never triggers".

### Progressive disclosure and the 8,000-character budget

Codex initially loads only each skill's **name and description**, capped at **8,000 characters total across all listed skills**, and loads the full `SKILL.md` body only once a skill is selected or invoked.

This makes descriptions a shared, finite resource. When a team adds skills and older ones stop being selected, that budget is the first thing to check — trim descriptions rather than adding more.

### Creating skills

Use the built-in creator — `$skill-creator` in Codex, `@skill-creator` in ChatGPT — which asks what the skill does, when it should trigger, and whether it should stay instruction-only. Hand-authoring a folder with a `SKILL.md` works equally well.

### Relationship to MCP

Skills can **declare MCP servers as optional dependencies** via `agents/openai.yaml`, using them as tools. Skills do not replace MCP and MCP does not replace skills: the skill supplies the procedure, the MCP server supplies the reach.

The full `agents/openai.yaml` schema beyond MCP dependency declaration is **not documented in the fetched corpus** — do not assert additional fields.

## Sources

- https://learn.chatgpt.com/docs/agent-configuration/agents-md
- https://learn.chatgpt.com/docs/build-skills
- https://learn.chatgpt.com/docs/developer-commands?surface=cli
- https://learn.chatgpt.com/docs/config-file/config-advanced

Fetched: 2026-08-05
