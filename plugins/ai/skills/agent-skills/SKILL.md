---
name: agent-skills
description: "Authoring Agent Skills — SKILL.md format and frontmatter, progressive disclosure and token budgeting, Anthropic's authoring best practices, bundling references/scripts, and packaging skills for Claude Code, claude.ai, and the Skills API. WHEN: \"write a SKILL.md\", \"create an Agent Skill\", \"skill frontmatter\", \"skill description isn't triggering\", \"progressive disclosure\", \"disable-model-invocation\", \"allowed-tools in a skill\", \"context: fork\", \"upload a custom skill\", \"container.skills\", \"anthropics/skills\", \"skill-creator\". Do NOT use for configuring the Claude Code harness itself (settings.json, hooks, permissions, subagent files, plugin install/enterprise deploy) — that's the `claude-code` skill; for building agents programmatically — `agent-sdk`; for MCP servers/protocol — `mcp`; for designing eval suites and graders — `evals`; for threat modeling untrusted skills and prompt injection — `ai-security`."
license: MIT
---

# Agent Skills (authoring)

Agent Skills are filesystem folders — a `SKILL.md` plus optional references, scripts, and assets — that Claude loads on demand to turn a general agent into a specialist. This skill covers writing and packaging them.

## Choose the right container first

Always ask what kind of artifact the knowledge is before writing a SKILL.md. Wrong container is the most expensive mistake.

| Need | Use | Why |
|---|---|---|
| Procedure, checklist, or domain playbook reused across conversations | **Skill** | Body loads only when triggered — near-zero cost until used |
| Always-true project facts (build command, repo layout) | **CLAUDE.md** | Skills load on demand; facts you always need shouldn't be gated |
| Live external data or actions over a protocol (query a DB, file a ticket) | **MCP server** → `mcp` sibling | Skills carry knowledge, not connections |
| One-off instruction for the current task | Plain prompt | Skills exist to stop repetition, not to hold single-use text |
| Isolated worker with its own context and tool policy | Subagent → `claude-code` sibling | Skills can fork into a subagent, but the agent definition lives elsewhere |

Create a skill when you keep pasting the same instructions into chat, or when a CLAUDE.md section has grown from a fact into a procedure. Skills and MCP compose: a skill may instruct Claude to call MCP tools, but always by fully qualified `ServerName:tool_name`.

## Frontmatter: the enforced spec

Required in every SKILL.md, on every surface: `name` and `description`.

| Field | Constraint |
|---|---|
| `name` | ≤64 chars; lowercase letters, numbers, hyphens only; no XML tags; must not contain "anthropic" or "claude" |
| `description` | non-empty; ≤1024 chars; no XML tags; must state **what** the skill does **and when** to use it |

Always match the folder name to `name` — the Skills API rejects an upload whose top-level directory doesn't match (case/underscore insensitive), and Claude Code defaults `name` to the directory name anyway.

Never assume every frontmatter key is portable. Claude Code accepts a large extension set (`allowed-tools`, `context: fork`, `argument-hint`, …); claude.ai uploads, the Skills API, and `package_skill.py` accept **only** `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools` and hard-fail on anything else. Read `references/skill-md-format.md` before using any field beyond name/description.

## Skill anatomy

A skill is a directory. Only `SKILL.md` is required; everything else is bundled content Claude reaches for on demand.

```text
my-skill/
├── SKILL.md           # Frontmatter + instructions (required, top level only)
├── references/        # Deep docs read on demand, one level deep from SKILL.md
├── scripts/           # Executables Claude runs; source never enters context
└── assets/            # Templates, schemas, example outputs
```

Minimal working skill, spec-level and portable to every surface:

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

Start from that shape, not from a blank file — the `anthropics/skills` repo template is deliberately this small. Add a reference file only when the body outgrows its budget, and a script only when the work is mechanical and repeatable.

## Progressive disclosure is the architecture

Skills are cheap because content loads in stages. Design to that model or the skill wastes context on every session.

| Level | Loaded | Cost | Content |
|---|---|---|---|
| 1 — Metadata | Always, at startup | ~100 tokens per skill | `name` + `description` |
| 2 — Instructions | When triggered | Target under 5k tokens | SKILL.md body |
| 3 — Resources | Only when referenced | Zero until read | `references/`, `scripts/`, `assets/` |

Rules that follow from this:

- Keep the SKILL.md body **under 500 lines**. Split when approaching the limit — do not let a body grow past it "just this once".
- Keep every reference file **one level deep from SKILL.md**. Claude may partially read (`head -100`) a file, and a reference-of-a-reference is where information silently goes missing.
- Give every reference file over ~100 lines a table of contents at the top, so a partial read still reveals full scope.
- Prefer a script over prose when the work is mechanical: script source never enters context, only its output does.
- There is no practical limit on bundled content — large API dumps, datasets, and example galleries cost nothing until accessed. Bundle generously, reference precisely.

Always state, next to each reference pointer, *when* to read it. "See `references/forms.md`" is dead weight; "Read `references/forms.md` when filling AcroForm fields" is routing.

## Write the description like it's the whole product

The description is the only part Claude sees before triggering. A perfect body behind a vague description never runs.

- Always third person — the text is injected into the system prompt. "Extracts text and tables from PDF files", never "I can help you with PDFs".
- Always state what + when, with concrete trigger terms a user would actually type (file extensions, tool names, error strings, quoted phrases).
- Add a negative clause when sibling skills overlap, naming the skill that should win instead. Ambiguous neighbors are the main cause of misrouting.
- Never write "Helps with documents" / "Processes data" / "Does stuff with files". Claude may be choosing among 100+ skills on description text alone.

Model description example from Anthropic's docs:

```yaml
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

Name the skill for what it does: gerund form preferred (`processing-pdfs`, `analyzing-spreadsheets`), noun phrase (`pdf-processing`) or action form (`process-pdfs`) acceptable. Never `helper`, `utils`, `tools`, `documents`, `data`.

## Body writing rules

**Concise is the top principle.** The context window is shared with the system prompt, history, every other skill's metadata, and the actual request. Assume Claude is already very smart — add only what Claude does not already know. Challenge each paragraph: does it justify its token cost? Delete explanations of general concepts (what a PDF is, why a library is popular).

**Match freedom to fragility.**

| Task shape | Give Claude | Form |
|---|---|---|
| Many valid approaches, context-dependent | High freedom | Prose heuristics, checklists |
| Preferred pattern, variation tolerable | Medium freedom | Pseudocode, parameterized scripts |
| Fragile, error-prone, consistency critical | Low freedom | Exact command: "Run exactly `python scripts/migrate.py --verify --backup`. Do not modify the command or add flags." |

**Other body directives:**

- Use one term consistently throughout — always "API endpoint", never a rotation of "URL" / "route" / "path".
- Never write time-sensitive branching ("before August 2025 use X"). Keep a "Current method" section and bury deprecated guidance in a collapsed `<details>` block.
- Always forward slashes in paths (`scripts/helper.py`), even when authoring on Windows — backslashes break on Unix.
- Give one default with an explicit escape hatch, never a menu ("pypdf, or pdfplumber, or PyMuPDF, or…").
- Concrete input/output example pairs beat descriptions of style.
- For multi-step work, provide a copyable checklist; for quality-critical work, provide a feedback loop (run validator → fix → re-run → proceed only on pass).
- In Claude Code, an invoked skill's rendered content stays in context for the rest of the session — every line is a recurring cost, not a one-time one. State what to do, not why.

Read `references/authoring-best-practices.md` for the full pattern catalog (template / examples / conditional-workflow patterns, plan-validate-execute, visual analysis) and Anthropic's pre-share checklist.

## Bundling scripts and resources

Ship a utility script even when Claude could write equivalent code — it is more reliable, deterministic, and free in context. When you do:

- Always say explicitly whether Claude should **execute** it ("Run `analyze_form.py`") or **read it as reference** ("See `analyze_form.py` for the algorithm"). Ambiguity gets you both, or neither.
- Scripts must solve, not defer: handle error conditions in the script instead of letting Claude interpret a raw traceback. Make failures verbose and actionable ("Field 'signature_date' not found. Available fields: …").
- Justify every configuration constant in a comment. `TIMEOUT = 47` with no rationale is a defect.
- List required packages explicitly with install commands; never assume availability. On the Claude API surface there is **no network access and no runtime package installation**, so API-targeted skills must use pre-installed packages only.
- For high-stakes or batch operations use plan-validate-execute: produce a plan file, validate it with a script, then execute.

## Know which surface you are targeting

Behavior and limits differ per surface; a skill is not automatically portable.

| Surface | Custom skills | Pre-built (pptx/xlsx/docx/pdf) | Network / packages | Sharing scope |
|---|---|---|---|---|
| Claude Code | Filesystem, no upload | Not available (the open-source Claude API skill ships bundled) | Full network; local installs fine | Personal, project, or plugin |
| claude.ai | Zip upload via Settings > Features (paid plans, code execution on) | Yes, automatic for document work | Full/partial/none per user or admin settings | Individual user only — not org-managed |
| Claude API | Upload via Skills API (`/v1/skills`) | Yes, by `skill_id` | **No network, no runtime installs** | Workspace-wide |

Custom skills **do not sync across surfaces** — uploaded to claude.ai ≠ available via API ≠ present in Claude Code. Claude Platform on AWS and Microsoft Foundry inherit API behavior.

Read `references/api-and-surfaces.md` when using skills through the Messages API (`container.skills`, up to 8 per request, beta headers, Skills API CRUD and versioning, `pause_turn` handling, file download) or when packaging for claude.ai. Version-pinned API details live in `references/versions/api-skills-2025-10-02-beta.md`.

## Claude Code extensions worth knowing

Claude Code implements the open Agent Skills standard and adds invocation control, arguments, dynamic context, and subagent execution. Use them only in Claude-Code-targeted skills — they break portable packaging.

- `disable-model-invocation: true` — manual `/name` only; use for side-effecting workflows (`/deploy`, `/commit`) and to remove a noisy skill from the listing entirely.
- `user-invocable: false` — hidden from the `/` menu; background knowledge Claude may load but users don't run.
- `allowed-tools` — pre-approves tools **for the invoking turn only**; grants clear on the next user message. It never restricts what otherwise exists.
- `context: fork` (+ `agent:`) — runs the skill body as an isolated subagent prompt, in the background by default.
- `` !`command` `` — shell output substituted into the body **before** Claude sees it, for injecting `gh pr diff` and friends.
- `$ARGUMENTS`, `$0`/`$1`, `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}` — argument and path substitution.

Read `references/claude-code-skills.md` for skill locations and precedence, nested/monorepo discovery, plugin packaging, content lifecycle and compaction behavior, and the listing budget. Feature-gating by Claude Code version is in `references/versions/claude-code-2.1.md` — check it before relying on any of the above.

## When the skill doesn't trigger

Diagnose in this order, cheapest first:

1. Ask "What skills are available?" — if it isn't listed, it isn't discoverable (wrong directory, or crowded out).
2. Check the description for the words a user would actually say. Add them.
3. Invoke directly with `/skill-name` to confirm the body works; a working body plus no auto-trigger is a description problem, not a content problem.
4. Check the listing budget: names + descriptions get ~1% of the context window by default in Claude Code, and overflow drops least-invoked skills first. Combined `description` + `when_to_use` is capped at 1,536 chars per entry.

Triggering too often is the same problem inverted: narrow the description or set `disable-model-invocation: true`.

## Evaluate before you polish

Build evaluations **before** writing extensive documentation. Anthropic's evaluation-driven loop: run Claude on representative tasks with no skill and record the gaps → build ~3 test scenarios over those gaps → establish a baseline → write the minimum instructions that pass → iterate.

Develop with two Claude instances: one that drafts and refines the skill, and a fresh one that tests it cold on real tasks; feed specific failure observations back. Watch how Claude navigates — unexpected exploration paths, missed references, or a section it leans on constantly (promote it into SKILL.md) and files it never opens (delete or signal them better).

Install `skill-creator` (`/plugin install skill-creator@claude-plugins-official`) to automate test cases (`evals/evals.json`), isolated per-case subagent runs with token/duration capture, grading to `grading.json`, with-skill vs without-skill benchmarking, blind A/B between versions, and description trigger-rate tuning.

For designing graders, LLM-as-judge rubrics, and regression suites in general, use the `evals` sibling — this skill covers only the skill-specific evaluation loop.

## Consuming third-party skills

Treat installing a skill as installing software with your credentials attached.

- Only run skills you wrote or obtained from Anthropic. A malicious skill can direct Claude to invoke tools or execute code well outside its stated purpose — data exfiltration, unauthorized system access.
- Audit every bundled file before use, not just SKILL.md: scripts, images, resources. Look for network calls, file access, and operations that don't match the stated purpose.
- Skills that fetch external URLs are the highest risk: fetched content can carry instructions, and a trustworthy skill can be compromised when its dependency changes.
- In Claude Code, a project skill's `allowed-tools` only takes effect after the workspace trust dialog — review checked-in skills before trusting a repo, because a skill can grant itself broad tool access.
- Agent Skills are **not** covered by Zero Data Retention arrangements; skill definitions and execution data fall under standard retention.

For threat modeling, prompt-injection defense, and tool-poisoning analysis, use the `ai-security` sibling. For sandboxing and egress control while running skills, use `sandboxing`. Platform security tooling (SIEM/EDR/SAST) belongs to the marketplace's `security` plugin.

## Where the examples live

`github.com/anthropics/skills` is the public reference collection: `skills/` (examples by category), `spec/` (the Agent Skills specification), `template/` (a deliberately minimal starter), and a `.claude-plugin/` config so it can be added as a Claude Code marketplace. Useful reads there: `skill-creator` (authoring + evaluation tooling), `mcp-builder`, `brand-guidelines`, `webapp-testing`, `web-artifacts-builder`. Note the document skills (`docx`, `pdf`, `pptx`, `xlsx`) are source-available, not open source; most others are Apache 2.0.

## Validate before shipping

```bash
python3 scripts/validate-skill.py path/to/my-skill
```

Read-only lint: checks frontmatter presence and field constraints, name/folder agreement, description length and third-person phrasing, body line count against the 500-line target, Windows-style paths, reference nesting depth, and portable-frontmatter compliance for API/claude.ai packaging. It reports; it never edits.

## Reference files

- `references/skill-md-format.md` — full frontmatter field tables (spec + Claude Code extensions), portable-field matrix, string substitutions, invocation-control matrix. Read when using any field beyond `name`/`description`.
- `references/authoring-best-practices.md` — Anthropic's core principles, progressive-disclosure patterns, workflow/feedback-loop patterns, anti-patterns, executable-code guidance, evaluation loop, pre-share checklist. Read when drafting or reviewing a skill body.
- `references/claude-code-skills.md` — skill locations and precedence, discovery scope, bundled skills, arguments, dynamic context injection, `context: fork`, content lifecycle and compaction, listing budget, sharing. Read for anything Claude-Code-specific.
- `references/api-and-surfaces.md` — Messages API `container.skills`, beta headers, Skills API CRUD/versioning, multi-turn container reuse, `pause_turn`, file download, upload limits, claude.ai packaging, `anthropics/skills` repo layout. Read when shipping to the API or claude.ai.
- `references/versions/claude-code-2.1.md` — Claude Code version gates for skill features. Read before relying on any extension field.
- `references/versions/api-skills-2025-10-02-beta.md` — beta headers, code-execution tool versions, ID/version formats. Read before writing API calls.

## Sources

- https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview
- https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices
- https://docs.claude.com/en/docs/agents-and-tools/agent-skills/quickstart
- https://docs.claude.com/en/docs/build-with-claude/skills-guide
- https://code.claude.com/docs/en/skills
- https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- https://github.com/anthropics/skills
- https://github.com/anthropics/skills/blob/main/template/SKILL.md
- https://github.com/anthropics/skills/tree/main/skills
- https://github.com/anthropics/skills/tree/main/skills/skill-creator

Fetched: 2026-08-05
