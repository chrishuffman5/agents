# Copilot customization files reference

Read before writing or debugging any `copilot-instructions.md`, `*.instructions.md`, `*.prompt.md`, or `*.agent.md` file, and when instructions "aren't being applied." These files are the only Copilot configuration shared across the IDE, the cloud agent, the CLI, and github.com.

## Repository custom instructions

> Source: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions

**Repository-wide**: `.github/copilot-instructions.md`. Markdown, no frontmatter needed. Applies to all Copilot requests made in the repository's context.

**Path-specific**: `NAME.instructions.md` under `.github/instructions/` or its subdirectories. YAML frontmatter with `applyTo` is required.

```markdown
---
applyTo: "app/models/**/*.rb"
---

Model classes use ActiveRecord scopes; never inline raw SQL.
```

| Frontmatter field | Required | Notes |
|---|---|---|
| `applyTo` | yes | Glob or comma-separated globs in one string: `"**/*.ts,**/*.tsx"` |
| `excludeAgent` | no | Excludes specific tools/agents, e.g. `excludeAgent: "code-review"` |

Glob semantics:

| Pattern | Matches |
|---|---|
| `*.py` | Python files in the current directory only |
| `**/*.py` | Python files recursively in all directories |
| `src/*.py` | Python files directly in `src`, not subdirectories |
| `src/**/*.py` | Python files recursively within `src` |

**Combination, not replacement**: if a path-specific file matches the current file *and* repository-wide instructions exist, both are included.

### Agent instructions files

`AGENTS.md` can live anywhere in the repository; **the nearest file in the directory tree to the working context takes precedence**. A single `CLAUDE.md` or `GEMINI.md` at the repository root is also recognized as agent instructions.

### Precedence

Highest to lowest when multiple instruction types apply:

1. Personal instructions
2. Repository instructions
3. Organization instructions

### What to put in them

GitHub's content guidance for effective instructions:

- Repository summary and high-level details.
- Bootstrap, build, test, run, and lint command sequences.
- Environment setup steps — **including steps that appear optional**.
- Project layout and architecture overview.
- CI/CD workflows and validation pipelines.
- Key file and config file locations, dependency information, directory structure, main source files.

Constraints: **no longer than about two pages**, and task-agnostic (describe the repository, not a single job).

### Application and verification

Instructions apply **immediately on save** and are automatically included in Copilot requests. In Copilot Chat, attach the repository to bring its custom instructions in; the UI shows which instruction files influenced a given response — use that display rather than reasoning about which file should have matched.

## Prompt files

> Source: https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file

- Location: `.github/prompts/`
- Naming: `filename.prompt.md`
- Invocation: `/filename` (no extension) in Copilot Chat — `explain-code.prompt.md` → `/explain-code`
- **Availability: public preview, and only in VS Code, Visual Studio, and JetBrains IDEs** as of 2026-08-05.

Frontmatter fields:

| Field | Notes |
|---|---|
| `agent` | Set to `'agent'` to enable agent mode for this prompt |
| `description` | Brief summary of the prompt's purpose |

Input variables use `${input:variableName:prompt text}`; Copilot prompts the user for each variable when the prompt file runs.

```markdown
---
agent: 'agent'
description: 'Generate a clear code explanation with examples'
---

Explain the following code in a clear, beginner-friendly way:

Code to explain: ${input:code:Paste your code here}
Target audience: ${input:audience:Who is this explanation for?}

Please provide:
* A brief overview of what the code does
* A step-by-step breakdown of the main parts
* Explanation of any key concepts
* A simple example showing how it works
* Common use cases
```

## Custom agents (`.agent.md`)

> Source: https://docs.github.com/en/copilot/reference/custom-agents-configuration
> Source: https://code.visualstudio.com/docs/copilot/chat/chat-modes

Locations: workspace `.github/agents`, user profile `~/.copilot/agents`. In VS Code these are the same objects formerly called "chat modes."

| Frontmatter field | Required | Notes |
|---|---|---|
| `description` | **yes** | Purpose and capabilities of the agent |
| `name` | no | Optional display name |
| `target` | no | `vscode` or `github-copilot`; defaults to both when omitted |
| `tools` | no | Available tools; omit for all, `[]` for none |
| `model` | no | Which model executes the agent |
| `disable-model-invocation` | no | `true` = must be selected manually, never auto-invoked |
| `user-invocable` | no | Controls whether it can be manually selected |
| `mcp-servers` | no | Additional MCP server configuration for this agent |
| `metadata` | no | Arbitrary name/value annotations |

`tools` accepts several forms:

- Comma-separated string — `tools: "read, edit, search"`
- YAML array — `tools: ["read", "edit", "search"]`
- All tools — omit the property, or `tools: ["*"]`
- Namespaced MCP tools — `custom-mcp/tool-1`, `github/*`
- Disabled — `tools: []`

Tool aliases:

| Alias | Maps to | Purpose |
|---|---|---|
| `read` | `view` | Read file contents |
| `edit` | `str_replace`, etc. | Modify files |
| `search` | `search` | Find files/text |
| `execute` | `bash`, `powershell` | Run shell commands |
| `agent` | Custom agent tools | Invoke other agents |
| `web` | Web tools | URL fetching — **not available to the cloud agent** |

Hard limits and precedence:

- Agent body maximum **30,000 characters**.
- The filename minus `.md`/`.agent.md` determines identity and precedence: **repository-level overrides organization-level overrides enterprise-level**.

```yaml
---
name: testing-specialist
description: Focuses on test coverage and quality
tools: ["read", "edit", "search"]
---

[Markdown content describing agent behavior]
```

**Handoffs** (VS Code): custom agents support guided transitions — a planning agent into an implementation agent, or into a code-review agent with context carried over. Restrict a planning agent to read-only tools so it cannot make changes during the planning phase.

For authoring quality *content* inside these files — progressive disclosure, directive style, description writing — defer to the `agent-skills` sibling skill; this reference covers the format only.

## Copilot Spaces

> Source: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/copilot-spaces/create-copilot-spaces

Spaces are the non-file alternative for grounding context: organizational containers that centralize content for a specific task.

Creation: `github.com/copilot/spaces` → **Create space** → name it → choose personal or organization ownership → confirm → optionally add a description. Name and description are editable later via the edit icon.

Two kinds of context:

- **Instructions** — free-form text defining Copilot's focus, expertise, task types, and boundaries (e.g. "You are a SQL generator… generate SQL queries based on the user's goals").
- **Sources** — files, folders, and repositories; URLs to GitHub PRs and issues; locally uploaded documents (images, text, spreadsheets); pasted text such as notes or transcripts.

**Repository vs. individual file**: attaching a whole repository uses smart search to retrieve relevant material — right for large-scale questions. Attaching individual files loads them fully into context — right when specific documents must always be prioritized. A space attached to a repository automatically tracks the latest code on the **main branch**.

Files can be added from GitHub's code view via the **Add to space** icon at the top of any file.

## Choosing between the mechanisms

> Derived from the sourced sections above; no separate source page.

| Need | Use |
|---|---|
| Always-on repo conventions for everyone | `.github/copilot-instructions.md` |
| Rules that only apply to some paths | `.github/instructions/*.instructions.md` with `applyTo` |
| A reusable, parameterized task | `.github/prompts/*.prompt.md` |
| A persona with a restricted toolset | `.github/agents/*.agent.md` |
| Curated grounding docs shared by a team, not in the repo | Copilot Space |
| Cross-tool instructions also read by other agents | `AGENTS.md` (nearest-wins) |

## Sources

- https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions
- https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file
- https://docs.github.com/en/copilot/reference/custom-agents-configuration
- https://code.visualstudio.com/docs/copilot/chat/chat-modes
- https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/copilot-spaces/create-copilot-spaces

Fetched: 2026-08-05
