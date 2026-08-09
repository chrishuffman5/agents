# gitlab-ci — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| gitlab-ci-oldest-supported | recent | As of GitLab CI 18.9, which is the oldest GitLab minor version still officially supported for upgrade paths? Answer concisely. | contains_all: `18.7` |
| gitlab-ci-short-sha | stable | In GitLab CI, how many characters long is the value of the CI_COMMIT_SHORT_SHA predefined variable? Answer concisely. | regex: `(?i)\b8\b|eight` |
| gitlab-ci-cache-compression | recent | GitLab CI 18.9 added new cache compression options. Besides the default gzip, what faster compression algorithm can you choose for pipeline caching? Answer concisely. | contains_all: `zstd` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 20.1s | 720 | $1.4384 | $0.1438 |
| no-skill | 12 | **83.3%** | 9.8s | 457 | $0.6209 | $0.0621 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 83.3% | +0pp | 20.1s | 9.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 20.1s | $0.0696 |
| claude-haiku-4-5 | no-skill | 83.3% | 7.3s | $0.0237 |
| claude-opus-5 | skill | 100% | 20.2s | $0.1934 |
| claude-opus-5 | no-skill | 83.3% | 12.3s | $0.1005 |

_Full per-cell aggregates (harness × model × effort × mode) in `gitlab-ci-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
