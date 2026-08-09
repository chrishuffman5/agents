# sophos-firewall — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sophos-firewall-v22-kernel | recent | What Linux kernel version baseline does the Sophos Firewall v22 hardened kernel use? Answer concisely. | contains_all: `6.6` |
| sophos-firewall-api-port | recent | What TCP port does the Sophos Firewall local WebAdmin API (APIController) use? Answer concisely. | contains_all: `4444` |
| sophos-firewall-heartbeat-red | stable | In Sophos Synchronized Security, what single-word color does the Security Heartbeat use to signal an active threat on an endpoint, triggering automatic network isolation? Answer in one word. | regex: `(?i)\bred\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.5s | 131 | $0.6318 | $0.2106 |
| no-skill | 9 | **22.2%** | 5s | 88 | $0.1583 | $0.0792 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 5.5s | 5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.1s | rates n/c |
| claude-opus-5 | skill | 50% | 6.1s | $0.2106 |
| claude-opus-5 | no-skill | 33.3% | 5.9s | $0.0792 |

_Full per-cell aggregates (harness × model × effort × mode) in `sophos-firewall-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
