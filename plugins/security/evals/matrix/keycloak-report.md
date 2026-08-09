# keycloak — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| keycloak-organizations-ga-version | recent | As of which major Keycloak release did the Organizations feature for multi-tenancy become generally available, after being in preview in an earlier release? Answer concisely. | regex: `(?i)\b26(\.0)?\b` |
| keycloak-quarkus-transition-version | recent | Starting with which Keycloak version did the project switch from a WildFly-based distribution to a Quarkus-based runtime? Answer concisely. | regex: `(?i)\b17(\.0)?\b` |
| keycloak-clustering-tech | stable | In a clustered Keycloak deployment, what technology handles distributed session caching, and what technology handles cluster node discovery and communication? Answer concisely. | contains_all: `Infinispan``, ``JGroups` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `keycloak-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
