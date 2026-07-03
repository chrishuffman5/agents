# Scripts Standard — Deterministic Skill Artifacts

The determinism goal: when an agent needs to diagnose or operate on a technology, it should **deliver a tested, shipped script verbatim** instead of generating one from memory. Generated scripts vary run-to-run and can be subtly wrong; shipped scripts are reviewed once and reused forever. This reduces tokens (no generation, no self-correction), reduces attempts-to-correct, and makes agent behavior reproducible for evals.

## Current Coverage (audited 2026-07-02)

| Domain | Coverage | Detail |
|---|---|---|
| `os` | ✅ Full | All 8 OS trees ship `scripts/` (34 script dirs incl. per-version) |
| `cli-scripting` | ✅ Full | All 7 tools ship `scripts/` |
| `virtualization` | ✅ Full | All 6 platforms ship `scripts/` |
| `database` | ⚠️ Partial | `sql-server` only (per-version diagnostic scripts, numbered) |
| All 14 other domains | ❌ None | analytics, api-realtime, backend, cloud-platforms, containers, devops, etl, frontend, mail-collab, messaging, monitoring, networking, security, storage |

## The Standard

### Location

```
skills/<domain>/<technology>/scripts/            # version-agnostic scripts
skills/<domain>/<technology>/<version>/scripts/  # version-specific scripts (preferred when syntax differs by version)
```

### Naming

`NN-purpose.ext` — two-digit prefix ordering scripts by **investigation/workflow order**, kebab-case purpose, native extension (`.sql`, `.ps1`, `.sh`, `.py`, `.yaml`).

Example (the `sql-server` pattern, which is the reference implementation):

```
01-server-health.sql
02-wait-stats.sql
03-top-queries-cpu.sql
04-top-queries-io.sql
```

### Header Contract

Every script begins with a comment header the agent can relay to the user without reading the whole body:

```
-- Purpose:        One line — what question this script answers
-- Applies to:     Technology + version range
-- Read-only:      yes | NO (destructive — see warnings)
-- Inputs:         Placeholders to replace, in UPPER_SNAKE tokens (e.g., __DATABASE_NAME__)
-- Interpretation: What healthy output looks like; what indicates a problem
-- Next step:      Which script to run next based on findings
```

### Rules

1. **Read-only by default.** Diagnostic scripts must not mutate state. Scripts that do mutate go in a clearly separated form (`90-fix-*` prefix range), are never first in the sequence, and carry explicit warnings plus a rollback note.
2. **One question per script.** A script answers one diagnostic question; chains are expressed through the `Next step` header and the numbering, not by mega-scripts.
3. **Placeholders, not examples.** Values the user must supply are `__UPPER_SNAKE__` tokens, so agents adapt only what is marked adaptable.
4. **Deterministic output.** Prefer ordered, bounded output (TOP N, sorted) so interpretation guidance stays valid.
5. **Exit codes / error behavior stated** for shell-executed scripts (`set -euo pipefail`, `$ErrorActionPreference='Stop'`).
6. **Version-gate honestly.** If syntax differs across supported versions, split into per-version `scripts/` dirs rather than branching inside one script.

### Definition of Done (per technology)

- `scripts/` exists with the top 5–10 diagnostic/operational questions for that technology covered
- Every script satisfies the header contract
- The technology's `SKILL.md` lists the scripts with one-line descriptions
- The domain specialist agent's Knowledge Map notes that scripts exist (update `agents/<domain>-specialist.md`)

## Rollout Order

Prioritized by troubleshooting frequency and eval value:

1. **database** — extend the sql-server pattern to postgresql, mysql, mongodb, redis first; then remaining engines
2. **containers** — kubectl diagnostic bundles (pod triage, node triage, networking triage) under `orchestration/kubernetes/`
3. **networking** — per-platform `show`-command bundles (routing-switching and firewall categories first)
4. **monitoring** — PromQL/SPL/query packs per tool (golden-signals starter queries, cardinality audits)
5. **devops** — pipeline debug checklists as scripts (runner diagnostics, state inspection for IaC)
6. **storage / messaging / mail-collab** — health-check and queue/lag/mail-trace bundles
7. Remaining domains as demanded by eval results (see `evals/` — low-accuracy or high-token domains get scripts first)

Each domain lands as its own `feat/scripts-<domain>` PR: scripts + SKILL.md listings + agent Knowledge Map update, per the Definition of Done.
