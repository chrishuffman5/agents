---
name: plugin-builder
description: "Interactive orchestration pipeline that remodels an existing skills repo (or a pile of .claude/ assets) into a well-architected Claude Code plugin or marketplace repo, and plans greenfield plugins. Interviews the user on intent before acting, inventories existing skills/commands/agents/hooks, strategizes which components each plugin should ship (skill vs agent vs hook vs command vs MCP server), proposes an architecture for sign-off, scaffolds manifests and migrations, then delegates per-skill content builds to skill-builder. WHEN: \"turn this skills repo into a plugin\", \"remodel my repo into a marketplace\", \"restructure these skills into plugins\", \"what should be a skill vs an agent vs a hook\", \"plan a new plugin\", \"design my plugin architecture\". Do NOT use for building or refreshing a single technology skill's content (skill-builder), for plugin.json/marketplace.json mechanics questions outside a restructuring engagement (ai plugin's plugins skill), for creating one subagent (agent-creator), or for updating installed plugin versions (update-plugin)."
license: MIT
---

# Plugin Builder — Architecture and Remodel Orchestration

One level above skill-builder: where skill-builder turns one technology into one skill, plugin-builder decides what a whole plugin — or a whole marketplace — should be. It is the entry-point skill an orchestrating session or cross-domain task agent invokes to refine an existing skills repo into a plugin repo, restructure a monolithic plugin into a marketplace, or plan a greenfield plugin: strategizing which skills, agents, hooks, and servers should exist, then delegating each research-grade content build to skill-builder.

**This skill is interactive by design.** skill-builder minimizes user questions; plugin-builder front-loads them. Architecture is intent: no inventory can tell you who the plugin is for, how it ships, or what the user means by "remodel". Interview first, propose second, build third.

## The Interview-First Contract

- **Never begin restructuring on an unconfirmed guess about intent.** The Phase 0 interview is mandatory even when the request seems obvious — "turn my skills into a plugin" has at least four materially different readings (see the question bank).
- **Ask decisions, not facts.** Anything the repo can answer (what exists, line counts, overlaps, git activity) comes from the Phase 1 inventory. Asking the user for it wastes their attention and erodes trust in the questions that matter.
- **Batch questions with AskUserQuestion** — up to 4 per call, concrete options plus the built-in free-text escape, multiSelect where choices coexist. Aim for ≤ 2 rounds; a targeted follow-up later beats a ten-question wall now.
- **Three mandatory checkpoints**, each requiring a user answer: (0) the intent interview, (2) architecture sign-off before any file moves, (3) explicit confirmation before destructive migration steps — deleting originals, renaming a published plugin, dropping a skill.
- **Record answers verbatim in `INTERVIEW.md`.** Answers are scope. A scope change reopens the interview delta — it never silently rewrites the plan.

## The Orchestrator Contract

Inherited from skill-builder and just as binding here:

- Delegate bulk reading to background agents; only the decision documents (`INTERVIEW.md`, `INVENTORY.md`, `ARCHITECTURE.md`) live in parent context. Never read a whole skills tree inline.
- Content builds are skill-builder engagements — never write a research-grade skill in the parent session.
- Steer running agents with SendMessage instead of respawning; launch independent agents in one message; report progress as short status lines, not summaries of findings.

Model assignment: inventory and audit agents run `model: sonnet`; architecture drafting stays in the parent session (it must merge interview, inventory, and judgment — the one place parent context earns its cost); content builds inherit skill-builder's assignments; mechanical checks run `model: haiku` or plain shell.

If the ai plugin's `plugins` skill is installed, load it when an engagement hits deep manifest or distribution mechanics (dependencies, channels, enterprise lockdown). Do not depend on it: `references/component-architecture.md` carries everything this pipeline needs and this skill must degrade gracefully when other plugins are absent.

## Pipeline at a Glance

| Phase | Who | Interactive? | Output |
|---|---|---|---|
| 0. Intent interview | Orchestrator + user | YES — AskUserQuestion | `INTERVIEW.md` |
| 1. Inventory | script + 1–3 sonnet auditors | no | `INVENTORY.md` |
| 2. Architecture | Orchestrator drafts; user signs off | YES — sign-off checkpoint | `ARCHITECTURE.md` (approved) |
| 3. Restructure + scaffold | Orchestrator + shell | destructive steps only | manifests, moved trees, `MIGRATION.md` |
| 4. Content build-out | skill-builder / agent-creator per item | inherited from those skills | skills, agents, evals |
| 5. Validate + release | shell + 1 sonnet verifier | no | validation report |

## Workspace

`remodel/<target-name>/` at the target repo's root. Add `remodel/` to that repo's `.gitignore` before writing anything — it is intermediate material, exactly like skill-builder's `research/`. Retain it after shipping: it is the durable record of why the architecture is what it is, and the resume point if the session is interrupted.

```
remodel/<target>/
├── INTERVIEW.md      ← Phase 0: questions asked, answers verbatim, inferred-and-confirmed facts
├── INVENTORY.md      ← Phase 1: inventory_repo.py output + auditor manifests, appended verbatim
├── ARCHITECTURE.md   ← Phase 2: the proposal, then the signed-off plan (start from assets/architecture-template.md)
└── MIGRATION.md      ← Phase 3+: every move, rename, merge, and deletion actually performed
```

This pipeline requires the target to be a git repository. If it is not, stop and have the user initialize one — restructuring without version control is unrecoverable.

## Phase 0 — Intent Interview

Read `references/intake-interview.md` first — it holds the question bank, the AskUserQuestion mechanics, and the `INTERVIEW.md` schema. The interview must pin down, at minimum:

1. **Engagement shape.** Remodel an existing repo | restructure plugin(s) into a marketplace | greenfield plugin | audit-only (propose, don't build).
2. **Audience and distribution.** Personal, team, or community; marketplace repo, direct git install, or skills-dir plugin. This single answer decides namespacing, versioning strategy, and how much release machinery the architecture needs.
3. **Domain boundaries.** What the user considers one coherent domain, and what is explicitly out of scope.
4. **Content ambition.** Reorganize what exists vs research-grade rebuilds. Each rebuild is a multi-hour skill-builder engagement — get sizing consent before proposing twenty of them.
5. **Enforcement and integration appetite.** Behaviors that must always happen (hook candidates) and external systems to reach (MCP candidates).

Write `INTERVIEW.md`. Every later phase cites it; nothing overrides it silently.

## Phase 1 — Inventory

Run the deterministic census first:

```bash
python scripts/inventory_repo.py <target-repo> > remodel/<target>/INVENTORY.md
python scripts/inventory_repo.py <target-repo> --summary     # what the orchestrator actually reads
```

It finds skills, commands, agents, hooks, MCP/LSP configs, monitors, plugin and marketplace manifests, and flags structural issues (components inside `.claude-plugin/`, nested SKILL.md files, malformed hooks JSON, agent-override collisions, missing versions).

Then spawn sonnet auditors — background, one message — for what a script cannot judge:

- **Content auditor:** existing skills against the marketplace bar (line budgets, descriptions as trigger surfaces, references, source traceability). Returns a per-skill verdict table, ≤ 30 lines: `keep | refresh | rebuild | merge | drop`, one-phrase reason each.
- **Overlap auditor:** skills covering the same technology or concern from different angles. Returns overlap pairs and the angle each owns, ≤ 20 lines — this feeds merge decisions and every description NOT-clause.
- **Usage auditor** (remodels of live repos only): git history for what is actively maintained vs abandoned, ≤ 15 lines.

Append their returns to `INVENTORY.md` verbatim. Auditors judge; the orchestrator and user decide — a `drop` verdict is a proposal until checkpoint 3 confirms it.

## Phase 2 — Architecture Strategy

Draft `ARCHITECTURE.md` from `assets/architecture-template.md`, merging interview and inventory. Two decisions carry the whole design:

**Plugin taxonomy — what is a plugin?** One plugin per coherent domain a user would install as a unit. Skill = technology, plugin = domain, marketplace = catalog of domains.

| Shape | Choose when |
|---|---|
| Single plugin | One domain, one audience, installed as one unit |
| Marketplace of plugins | Multiple domains, selective install, per-domain versioning and ownership |
| Bundle plugin (`name` + `dependencies` only) | "The standard set" for a team, composed from existing plugins |

Never split by component type ("all agents in one plugin, all skills in another") — split by domain, and let each plugin carry its own skills, agents, and hooks.

**Component placement — what should each capability be?** Full decision guide with traps in `references/component-architecture.md`; the condensed table:

| You are shipping | Component |
|---|---|
| Knowledge or guidance the model loads on demand | Skill (`skills/<name>/SKILL.md`) |
| A delegatable worker with its own context, tools, and model | Agent (`agents/*.md`) |
| Behavior that must happen every time, deterministically, on a lifecycle event | Hook (`hooks/hooks.json`) |
| Tools that reach an external system or API | MCP server (`.mcp.json`) |
| Language diagnostics and code navigation | LSP (`.lsp.json`) — prefer the official LSP plugins |
| A long-running watcher that notifies the session | Monitor (`monitors/monitors.json`) |
| An executable the model should run from Bash | `bin/` |
| A whole-session persona enforced on the main thread | `settings.json` `agent` |
| Look and feel | `themes/`, `output-styles/` |

Smell tests worth memorizing:

- A skill that says "always do X after every edit" is a hook wearing a skill costume. If it must always happen, the harness enforces it — the model's memory does not.
- An agent whose body re-teaches a technology is a skill wearing an agent costume. Agents hold a knowledge map and delegate depth to skills.
- One mega-skill spanning a domain is a plugin wearing a skill costume — split per technology.
- Version-specific content as its own skill is always wrong — it is `references/versions/<v>.md` inside the technology skill.

Close the phase at the **sign-off checkpoint**: present a compact summary plus the path to the full proposal, then AskUserQuestion for approval or per-section amendments. No file moves before sign-off. Record the approval (and any amendments) in `ARCHITECTURE.md` itself.

## Phase 3 — Restructure and Scaffold

Execute the approved architecture. The mechanics that bite, in order of how often they do (full detail: `references/component-architecture.md` § Migration traps):

- Only `plugin.json` lives in `.claude-plugin/`. Any component directory placed there silently fails to load — the single most common remodel error.
- `.claude/` migration: `skills/` and `commands/` copy over; hooks move from `settings.json` into `hooks/hooks.json` with the identical format. Project `.claude/agents/` originals **override** same-named plugin agents — delete the originals or the plugin version never takes effect. Migrated skills keep working unnamespaced from `.claude/` copies, so remove those too or users get duplicates.
- Namespacing changes every invocation: `/foo` becomes `/plugin-name:foo`. Grep the repo's docs, READMEs, and other skills for old invocation names and update them.
- Version strategy comes from the interview: explicit semver in `plugin.json` (updates ship only on bump — bump on every release) or omit versions entirely for commit-SHA flow (every push updates). Never set a version in both `plugin.json` and the marketplace entry — `plugin.json` wins silently.
- `renames` in the marketplace catalog is append-only history. Never change a published plugin's `name` without adding the rename entry.
- Marketplace catalog: relative `./` sources resolved from the marketplace root; never rely on `metadata.pluginRoot` (hosts that honor it double-resolve the path).
- A plugin-root `CLAUDE.md` is not loaded as context — repo instructions that must ship become a skill.

Log every move in `MIGRATION.md` as it is performed, not after. Destructive steps — deleting originals, dropping skills, renaming published plugins — get checkpoint-3 confirmation first, batched into one question wherever possible.

## Phase 4 — Content Build-Out

Work through `ARCHITECTURE.md`'s per-skill verdicts:

- **new | rebuild** → a full skill-builder engagement each. The quality bar travels with it even outside this marketplace: 200–500 line SKILL.md, trigger-tuned description carrying the NOT-clauses the overlap audit demanded, at least one `references/` file, source traceability.
- **refresh** → skill-builder's refresh mode, seeded from the skill's `## Sources` footer.
- **keep** → mechanical fixes only (run skill-builder's `audit_skill.py`; fix frontmatter, budgets, footers). Do not rewrite content the audit passed.
- **merge | drop** → fold or remove, recorded in `MIGRATION.md`, confirmed at checkpoint 3.

Run engagements sequentially or in small batches — each is its own multi-hour pipeline. Give the user a running order up front and let them reprioritize between engagements.

Agents: each domain plugin ships a specialist agent holding a knowledge map of its own `skills/` tree (paths relative to the plugin root — never into other plugins). Create or update them via agent-creator, and remember plugin-shipped agents cannot declare `hooks`, `mcpServers`, or `permissionMode`.

Evals: every plugin ships `evals/trigger-evals.json` with one positive and one near-miss negative prompt per skill. The near-miss comes from the overlap audit — the adjacent request that should route elsewhere.

## Phase 5 — Validate and Release

1. `claude plugin validate <marketplace-root>` plus each plugin; `--strict` in CI.
2. Run `audit_skill.py` (from skill-builder) across every skill directory; fix failures, justify warnings.
3. Trigger-eval sweep: every skill has its positive/negative pair; every overlap found in Phase 1 has its NOT-clause in a description.
4. Versions pinned in each `plugin.json` only; everything touched this engagement is bumped.
5. Report: final tree, what was migrated vs built vs deferred, eval counts, and the workspace location kept for the next engagement. Keep it to logistics — the architecture rationale already lives in `ARCHITECTURE.md`.

## Failure Handling

| Failure | Response |
|---|---|
| User's answers change mid-build | Reopen the interview delta, amend `ARCHITECTURE.md` with a dated changelog line, re-confirm sign-off. Never silently diverge from the signed plan. |
| Existing content fails the quality audit wholesale | Do not quietly convert "remodel" into "rebuild everything" — that is a sizing change; take it back to the user with the verdict table (checkpoint). |
| A skill-builder engagement stalls or fails | Its own failure table governs it. The remodel continues on other items; record the stall in `MIGRATION.md`. |
| Target repo is not under git | Stop. Require version control before any restructuring. |
| Plugin name collision or reserved marketplace name | Surface it and pick a replacement with the user — names are the namespace and the install identity; never auto-rename. |
| Inventory finds credentials or secrets in assets | Stop that item, tell the user, and never copy the material into a distributable plugin. |
| Session interrupted | Resume from the workspace: `INTERVIEW.md` + `INVENTORY.md` + `ARCHITECTURE.md` + `MIGRATION.md` reconstruct the run state. Spawn only what is missing. |

## Worked Example

This repository is the worked example. A monolithic `domain-expert` plugin was remodeled into an 18-domain marketplace: the interview pins audience (community) and distribution (marketplace repo); inventory maps ~186 technologies and their overlaps (kafka, grafana, splunk, duckdb each claimed by multiple domains); the architecture lands on one plugin per domain plus a `domain-expert-core` plugin for cross-domain task agents, overlap resolved by angle-splitting with mutual NOT-clauses; migration preserves history with a `renames` entry (`domain-expert` → `domain-expert-core`) and per-plugin versions; build-out runs skill-builder-grade pipelines per technology (the ai plugin's 21 source-traced skills are that phase's visible output); validation gates every release on `claude plugin validate` plus per-skill trigger evals.

## Bundled Content

- `references/intake-interview.md` — the question bank, AskUserQuestion mechanics, sizing-consent rules, and the `INTERVIEW.md` schema. Read before Phase 0.
- `references/component-architecture.md` — the full component decision guide, plugin taxonomy, namespacing, versioning/distribution strategy, and migration traps. Read before Phase 2 and Phase 3.
- `assets/architecture-template.md` — the `ARCHITECTURE.md` skeleton the sign-off is built on.
- `scripts/inventory_repo.py` — deterministic repo census; run in Phase 1 and re-run after Phase 3 to verify the moves landed where the plan said.

## Sources

- https://code.claude.com/docs/en/plugins  (component placement and migration behavior, distilled via the ai plugin's source-traced `plugins` corpus)
- https://code.claude.com/docs/en/plugins-reference
- https://code.claude.com/docs/en/plugin-marketplaces
- This repository's conventions: CLAUDE.md, the skill-builder pipeline, and the 2026-07/08 marketplace restructuring.

Fetched: 2026-08-05
