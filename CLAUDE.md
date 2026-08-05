# Domain Expert Marketplace

This repository is a **Claude Code plugin marketplace**: one plugin per IT domain (18 domains, 186+ technologies) plus a cross-domain task-agent plugin. The catalog lives at `.claude-plugin/marketplace.json`; every plugin lives under `plugins/`.

## Repository layout

```
.claude-plugin/marketplace.json     ← the marketplace catalog (sources are repo-root-relative ./plugins/<domain>; never set metadata.pluginRoot — hosts that honor it would double-resolve the path)
plugins/
├── <domain>/                       ← one plugin per domain (database, os, security, …)
│   ├── .claude-plugin/plugin.json
│   ├── agents/<domain>-specialist.md
│   ├── evals/trigger-evals.json    ← positive + near-miss trigger prompts per skill
│   └── skills/
│       ├── overview/               ← cross-technology domain guidance
│       ├── <category>/             ← (categorized domains) selection guidance, e.g. security/iam
│       └── <technology>/           ← one skill per technology, e.g. /database:postgresql
│           ├── SKILL.md
│           ├── references/         ← deep docs, loaded on demand
│           │   └── versions/<v>.md ← version-specific nuances (new/deprecated features)
│           ├── scripts/            ← runnable diagnostics (scripts/versions/<v>/ for version-specific)
│           └── assets/             ← templates/config files used in output
└── domain-expert-core/             ← cross-domain task agents + update-plugin & ultimate-tech-stack skills
docs/    evals/                     ← eval dashboard and harness (repo-level)
```

## Conventions (enforced — apply to every change)

**Structure**
- Skill = technology. Plugin = domain. Skill folder name is the invocation name (`/security:entra-id`), so folders are kebab-case and self-explanatory.
- Version-specific knowledge is NEVER a skill or nested SKILL.md — it goes in `references/versions/<v>.md` of the technology skill.
- No `SKILL.md` below a skill's top level. Bundled content only in `references/`, `scripts/`, `assets/`.

**SKILL.md quality** (from the skills-evals training; violations block merge)
- Frontmatter: `name` (= folder name), `description`, `license: MIT`. The description states WHAT the skill covers, WHEN to use it (concrete trigger terms), and when NOT to (negative clause for overlapping skills — duckdb/kafka/grafana/splunk/spark exist in multiple plugins with different angles).
- Body: 200–500 lines is the target; never above 1000. Push detail into `references/` with when-to-read pointers.
- Directives over essays ("Always X. Never Y." + short why), outcomes + constraints over rigid step lists, no no-op filler lines.
- Each plugin's `evals/trigger-evals.json` keeps one positive and one near-miss negative prompt per skill; add a case when adding or renaming a skill.

**Agents**
- Each domain plugin ships `<domain>-specialist.md` with a knowledge map of its own `skills/` tree (paths relative to the plugin root). Cross-domain task agents live only in `domain-expert-core` and must not hardcode other plugins' file paths — they delegate to domain specialists or degrade gracefully.

## Validation

Before committing structural changes:

```bash
claude plugin validate .                      # marketplace catalog
claude plugin validate ./plugins/<domain>     # each touched plugin (checks plugin.json + skill/agent frontmatter)
```

Also grep for stale pre-marketplace paths — `skills/<domain>/...` at repo root must not appear inside `plugins/`.

## Versioning

Each plugin pins its own `version` in `plugin.json` — bump it on every release of that plugin or users never receive the update. `renames` in marketplace.json is append-only history (old monolithic `domain-expert` → `domain-expert-core`).
