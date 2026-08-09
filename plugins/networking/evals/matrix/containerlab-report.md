# containerlab — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| containerlab-reconfigure-flag | recent | In Containerlab, what flag do you add to the clab deploy command to force it to re-apply node startup configurations on an already-running lab? Answer concisely. | contains_all: `reconfigure` |
| containerlab-server-sizing | recent | As a rule of thumb, what server specs, cpu cores and RAM, does Containerlab guidance suggest for running a 4-spine, 8-leaf fabric using native container images? Answer concisely with both numbers. | contains_all: `16``, ``64` |
| containerlab-root-required | stable | Does deploying a Containerlab topology require root privileges on the host, since it manipulates network namespaces? Answer in one sentence. | regex: `(?i)(\byes\b|root|sudo)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 8.3s | 278 | $1.4156 | $0.2359 |
| no-skill | 9 | **22.2%** | 5.8s | 296 | $0.1878 | $0.0939 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 22.2% | +27.8pp | 8.3s | 5.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.8s | rates n/c |
| claude-opus-5 | skill | 100% | 11.1s | $0.2359 |
| claude-opus-5 | no-skill | 33.3% | 6.2s | $0.0939 |

_Full per-cell aggregates (harness × model × effort × mode) in `containerlab-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
