# helm — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `containers` · runs: **36 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| helm4-release-version | recent | What is the current Helm major and minor release, the one announced at KubeCon 2025? Answer concisely. | contains_all: `4.1` |
| helm-apply-strategy | stable | Between Helm 3 and Helm 4, which version switched from client-side three-way merge to Server-Side Apply for reconciling manifests? Answer concisely. | regex: `(?i)helm\s*4` |
| helm-hook-weight-order | stable | For Helm hooks, does a hook with weight -5 run before or after a hook with weight 5? Answer in one sentence. | regex: `(?i)before` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **77.8%** | 10.8s | 304 | $1.4283 | $0.102 |
| no-skill | 18 | **72.2%** | 10.2s | 258 | $0.7708 | $0.0593 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 75% | +0pp | 8.7s | 9.2s |
| codex | 83.3% | 66.7% | +16.6pp | 14.9s | 12.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 8.6s | $0.0335 |
| claude-haiku-4-5 | no-skill | 66.7% | 9.6s | $0.0282 |
| claude-opus-5 | skill | 83.3% | 8.8s | $0.1714 |
| claude-opus-5 | no-skill | 83.3% | 8.7s | $0.0753 |
| gpt-5.6-sol | skill | 83.3% | 14.9s | $0.0874 |
| gpt-5.6-sol | no-skill | 66.7% | 12.4s | $0.0704 |

_Full per-cell aggregates (harness × model × effort × mode) in `helm-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
