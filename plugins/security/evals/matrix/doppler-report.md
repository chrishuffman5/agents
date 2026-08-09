# doppler — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **25%** | 4.8s | 151 | $0.6967 | $0.2322 |
| no-skill | 9 | **33.3%** | 5.9s | 183 | $0.2275 | $0.0758 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 4.8s | 5.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.9s | rates n/c |
| claude-opus-5 | skill | 50% | 5.8s | $0.2322 |
| claude-opus-5 | no-skill | 50% | 6.3s | $0.0758 |

_Full per-cell aggregates (harness × model × effort × mode) in `doppler-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
