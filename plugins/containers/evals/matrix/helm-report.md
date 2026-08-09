# helm — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 9 | **88.9%** | 10.8s | 177 | $1.0159 | $0.127 |
| no-skill | 6 | **66.7%** | 10.9s | 108 | $0.281 | $0.0703 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 66.7% | +16.6pp | 8.8s | 6.7s |
| codex | 100% | 66.7% | +33.3pp | 14.6s | 15.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 83.3% | 8.8s | $0.1714 |
| claude-opus-5 | no-skill | 66.7% | 6.7s | $0.0822 |
| gpt-5.6-sol | skill | 100% | 14.6s | $0.0529 |
| gpt-5.6-sol | no-skill | 66.7% | 15.1s | $0.0583 |

_Full per-cell aggregates (harness × model × effort × mode) in `helm-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
