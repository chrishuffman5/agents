# illumio — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| illumio-label-dimensions | stable | Illumio uses a four-dimensional label model to describe workloads instead of relying on IP addresses in policy. What are the four label dimensions? Answer concisely. | contains_all: `Role``, ``Application``, ``Environment``, ``Location` |
| illumio-enforcement-modes | stable | Illumio workloads can be placed into different enforcement modes to enable a gradual policy rollout. Name the mode meaning installed but not enforcing, the mode enforcing only known rules while allowing the rest, the mode that fully blocks non-permitted traffic, and the validation-only mode that logs what would be blocked. Answer concisely. | contains_all: `Idle``, ``Selective``, ``Full``, ``Test` |
| illumio-ven-enforcement-mechanism | recent | The Illumio VEN agent enforces policy by managing the workload native OS firewall. What underlying mechanism does it manage on Linux, and what does it manage on Windows? Answer concisely. | contains_all: `iptables``, ``WFP` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5s | 181 | $0.5719 | $0.1906 |
| no-skill | 9 | **22.2%** | 5.3s | 200 | $0.175 | $0.0875 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 5s | 5.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.1s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.1s | rates n/c |
| claude-opus-5 | skill | 50% | 5.8s | $0.1906 |
| claude-opus-5 | no-skill | 33.3% | 6.5s | $0.0875 |

_Full per-cell aggregates (harness × model × effort × mode) in `illumio-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
