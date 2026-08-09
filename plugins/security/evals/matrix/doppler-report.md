# doppler — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| doppler-workspace-roles | stable | In Doppler, what are the four workspace-level roles, ranging from full access including billing down to read-only access? Answer concisely by listing all four. | contains_all: `Owner``, ``Admin``, ``Member``, ``Viewer` |
| doppler-service-account-token | recent | Doppler distinguishes several credential types for authenticating to its API. Which one is described as tied to a service account rather than an individual user, meant for use in CI/CD pipelines? Answer concisely. | regex: `(?i)service\s*account\s*token` |
| doppler-ehr-tls-version | stable | What is the minimum TLS version used for all communication in Doppler's Encrypted HTTP Relay, the mechanism behind its secret fetch API? Answer concisely. | regex: `(?i)tls\s*1\.2` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `doppler-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
