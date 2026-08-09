# circleci — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| circleci-cache-ttl | recent | How many days does a CircleCI dependency cache normally stay valid before it automatically expires, assuming the cache key does not change? Answer concisely with the number of days. | regex: `(?i)15\s*days?` |
| circleci-ssh-debug-window | stable | After a CircleCI job finishes running with SSH rerun enabled, for how long afterward can you still SSH into the container or VM to debug? Answer concisely. | regex: `(?i)2\s*hours?` |
| circleci-2xlarge-specs | stable | In CircleCI's resource class table, what are the vCPU count, RAM in GB, and per-minute credit cost of the 2xlarge resource class? Answer concisely with all three numbers. | contains_all: `16``, ``32``, ``80` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 12.2s | 452 | $1.2362 | $0.1545 |
| no-skill | 12 | **66.7%** | 9.1s | 367 | $0.5774 | $0.0722 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 66.7% | +0pp | 12.2s | 9.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 12.4s | $0.1182 |
| claude-haiku-4-5 | no-skill | 33.3% | 7.9s | $0.06 |
| claude-opus-5 | skill | 100% | 12.1s | $0.1666 |
| claude-opus-5 | no-skill | 100% | 10.2s | $0.0762 |

_Full per-cell aggregates (harness × model × effort × mode) in `circleci-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
