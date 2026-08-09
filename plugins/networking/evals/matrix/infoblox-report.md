# infoblox — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| infoblox-wapi-current-version | recent | What is the current WAPI REST API version supported on Infoblox NIOS 9.0? Answer concisely. | contains_all: `2.13` |
| infoblox-pdns-retention | recent | How many months of historical DNS resolution data does Infoblox BloxOne Passive DNS typically retain for threat hunting? Answer concisely. | regex: `(?i)12\+?[\s-]*months?` |
| infoblox-gmc-auto-promotion | stable | In an Infoblox NIOS Grid, if the Grid Master becomes unreachable, does the Grid Master Candidate promote itself automatically, or does it require manual intervention? Answer in one sentence. | regex: `(?i)automat` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 8.9s | 492 | $1.4941 | $0.2988 |
| no-skill | 9 | **33.3%** | 4.4s | 95 | $0.1664 | $0.0555 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 33.3% | +8.4pp | 8.9s | 4.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 83.3% | 13.2s | $0.2988 |
| claude-opus-5 | no-skill | 50% | 4.7s | $0.0555 |

_Full per-cell aggregates (harness × model × effort × mode) in `infoblox-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
