# Scripts Standard — Deterministic Skill Artifacts

The determinism goal: when an agent needs to diagnose or operate on a technology, it should **deliver a tested, shipped script verbatim** instead of generating one from memory. Generated scripts vary run-to-run and can be subtly wrong; shipped scripts are reviewed once and reused forever. This reduces tokens (no generation, no self-correction), reduces attempts-to-correct, and makes agent behavior reproducible for evals.

## Current Coverage (audited 2026-07-02)

| Domain | Coverage | Detail |
|---|---|---|
| `os` | ✅ Full | All 8 OS trees ship `scripts/` (34 script dirs incl. per-version) |
| `cli-scripting` | ✅ Full | All 7 tools ship `scripts/` |
| `virtualization` | ✅ Full | All 6 platforms ship `scripts/` |
| `analytics` | ⚠️ Partial | ssas (6), ssrs (5), power-bi (4), tableau (4), grafana (4); remaining: looker, metabase, qlik-sense, superset, thoughtspot, duckdb-analytics |
| `database` | ⚠️ Partial | `sql-server` only (per-version diagnostic scripts, numbered) |
| All 13 other domains | ❌ None | api-realtime, backend, cloud-platforms, containers, devops, etl, frontend, mail-collab, messaging, monitoring, networking, security, storage |

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

Re-prioritized 2026-07-03 by measured agent-vs-baseline eval deltas (runs `20260702-233837` in `evals/results/`): domains where baseline accuracy collapsed get scripts first.

1. **analytics** (delta +4) — ✅ started: ssas/ssrs/power-bi/tableau/grafana packs shipped; remaining tools on demand
2. **etl** (+3) — Airflow metadata-DB queries, dbt artifact inspection, Spark history/API pulls
3. **storage** (+3) — array/cluster health bundles (ONTAP CLI, `ceph status` pack, S3 inventory/lifecycle audit)
4. **database** (+5 on navigation suite) — extend the sql-server pattern to postgresql, mysql, mongodb, redis; then remaining engines
5. **cli-scripting / cloud-platforms / messaging** (+2) — consumer-lag and queue diagnostics, cost/usage pulls
6. **containers / networking / monitoring** (+1) — kubectl triage bundles, `show`-command packs, query packs
7. **devops / mail-collab / security** (0 measured delta) — after their eval suites are hardened with newer version-gated content
8. **virtualization** (+3) — already fully covered; audit existing scripts against the header contract instead

Each domain lands as its own `feat/scripts-<domain>` PR: scripts + SKILL.md listings + agent Knowledge Map update, per the Definition of Done.
