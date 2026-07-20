# Scripts Standard — Deterministic Skill Artifacts

The determinism goal: when an agent needs to diagnose or operate on a technology, it should **deliver a tested, shipped script verbatim** instead of generating one from memory. Generated scripts vary run-to-run and can be subtly wrong; shipped scripts are reviewed once and reused forever. This reduces tokens (no generation, no self-correction), reduces attempts-to-correct, and makes agent behavior reproducible for evals.

## Current Coverage (audited 2026-07-19, post-marketplace-restructure)

Each domain is now its own plugin under `plugins/<domain>/`, and every technology is a flat skill directory under `plugins/<domain>/skills/<technology>/` (the old `skills/<domain>/<category>/<technology>/` nesting was flattened — category groupings like `orchestration`, `service-mesh`, or `firewall` survive only as thin overview-style skills with a `references/concepts.md`, not as directories that contain other technologies).

| Domain | Coverage | Detail |
|---|---|---|
| `os` | ✅ Full | All 19 OS-domain skills ship `scripts/` — 8 base OSes (windows-server, windows-client, rhel, rocky-alma, ubuntu, debian, sles, macos) plus 11 related-topic skills (apparmor, btrfs-snapper, failover-clustering, hyper-v, macos-developer-toolchain, macos-mdm-deployment, macos-platform-sso, rhel-podman, selinux, sles-ha-extension, wsl) |
| `cli-scripting` | ✅ Full | All 7 tools ship `scripts/`: bash (4), nodejs (4), powershell (4), python (4), kubectl (3), aws-cli (1), azure-cli (1) |
| `virtualization` | ✅ Full | All 6 platforms ship `scripts/`: cloud-vms (3), vmware (3), kvm (2), proxmox (2), citrix (1), nutanix (1) |
| `analytics` | ⚠️ Partial | ssas (6), ssrs (5), power-bi (4), tableau (4), grafana (4); remaining: duckdb, looker, metabase, qlik-sense, superset, thoughtspot |
| `etl` | ⚠️ Partial | airflow (5), ssis (4), dbt-core (4), spark (4), adf (3); remaining: aws-glue, dbt-cloud, duckdb, fivetran, informatica, kafka, nifi, synapse-pipelines, talend |
| `storage` | ⚠️ Partial | netapp-ontap (4), ceph (3), aws-s3 (3), storage-spaces-direct (2); remaining: azure-blob, dell-powerstore, dell-unity, gcs, glusterfs, hpe-alletra, minio, pure-storage |
| `database` | ⚠️ Partial | sql-server (66, per-version under `scripts/versions/<v>/`), postgresql (5), mongodb (5), mysql (4), redis (4); remaining: 24 engines |
| `messaging` | ⚠️ Partial | kafka (3), rabbitmq (3), aws-sqs-sns (2); remaining: azure-service-bus, gcp-pubsub, nats, pulsar, redis-streams |
| `containers` | ⚠️ Partial | kubernetes (4), docker (2); remaining: aks, consul, containerd, eks, gke, helm, istio, linkerd, openshift, podman, rancher |
| `networking` | ⚠️ Partial | cisco-ios-xe (2), panos (2), bind (2), haproxy (2); remaining: ~60 other technologies |
| `monitoring` | ⚠️ Partial | prometheus (3), elk (2); grafana ops scripts live under the `analytics` plugin's `grafana` skill, not the `monitoring` plugin's |
| `devops` | ⚠️ Partial | github-actions (2), terraform (2), ansible (2), argocd (2); remaining: azure-devops, bicep, chef, circleci, cloudformation, flux, github, gitlab-ci, jenkins, opentofu, pulumi, puppet, saltstack |
| `security` | ⚠️ Partial | entra-id (3), ad-ds (2), vault (2), crowdstrike (1) — read-only defensive audits |
| `cloud-platforms` | ⚠️ Partial | aws (3), azure (2) — FinOps cost/idle audits; remaining: gcp |
| `mail-collab` | ⚠️ Partial | postfix (2), m365 (1); remaining: exchange, google-workspace |
| `backend` | ⚠️ Partial | aspnet-core (1), django (1), express (1) — project/dep audits; remaining: aspnet-minimal-apis, fastapi, flask, go-web, nestjs, rails, rust-web, spring-boot |
| `frontend` | ⚠️ Partial | react (1), nextjs (1), angular (1) — build/bundle audits; remaining: angular-signals, astro, blazor, gatsby, htmx, nextjs-app-router, nuxt, react-server-components, remix, svelte, vue |
| `api-realtime` | ⚠️ Partial | rest (1), graphql (1), grpc (1) — contract/endpoint checks; remaining: odata, signalr, socketio, sse, websocket |

**All 18 domains now have at least partial script coverage.** Remaining work is depth (more technologies per domain), driven by eval deltas and real usage.

## The Standard

### Location

```
plugins/<domain>/skills/<technology>/scripts/                    # version-agnostic scripts
plugins/<domain>/skills/<technology>/scripts/versions/<v>/       # version-specific scripts (preferred when syntax differs by version)
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
- The domain specialist agent's Knowledge Map notes that scripts exist (update `plugins/<domain>/agents/<domain>-specialist.md`)

## Rollout Order

Re-prioritized 2026-07-03 by measured agent-vs-baseline eval deltas (runs `20260702-233837` in `evals/results/`): domains where baseline accuracy collapsed get scripts first.

1. **analytics** (delta +4) — ✅ started: ssas/ssrs/power-bi/tableau/grafana packs shipped; remaining tools on demand
2. **etl** (+3) — ✅ started: airflow/ssis/dbt-core/spark/adf packs shipped; remaining tools on demand
3. **storage** (+3) — ✅ started: netapp-ontap/ceph/aws-s3/storage-spaces-direct packs shipped; remaining platforms on demand
4. **database** (+5 on navigation suite) — ✅ started: postgresql/mysql/mongodb/redis packs shipped alongside sql-server; remaining engines on demand
5. **cli-scripting / cloud-platforms / messaging** (+2) — messaging ✅ started (kafka/rabbitmq/sqs packs); cloud-platforms cost/usage pulls remain
6. **containers / networking / monitoring** (+1) — kubectl triage bundles, `show`-command packs, query packs
7. **devops / mail-collab / security** (0 measured delta) — after their eval suites are hardened with newer version-gated content
8. **virtualization** (+3) — already fully covered; audit existing scripts against the header contract instead

Each domain lands as its own `feat/scripts-<domain>` PR: scripts + SKILL.md listings + agent Knowledge Map update, per the Definition of Done.
