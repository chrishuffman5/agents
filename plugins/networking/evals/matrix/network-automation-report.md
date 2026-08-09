# network-automation — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| network-automation-maturity-levels | recent | In a typical network automation maturity model that runs from manual CLI changes up through self-healing, closed-loop networks, how many maturity levels are usually defined? Answer concisely. | regex: `(?i)(\b5\b|\bfive\b)` |
| network-automation-batfish | stable | What free, open-source tool is commonly used to parse network device configurations offline and analyze reachability, routing correctness, and ACL behavior before a change is deployed? Answer concisely. | contains_all: `Batfish` |
| network-automation-ansible-no-state | stable | Unlike Terraform, does Ansible maintain a persistent state file that tracks what infrastructure or configuration it has previously deployed? Answer in one sentence. | regex: `(?i)\bno\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.6s | 226 | $1.1402 | $0.19 |
| no-skill | 9 | **33.3%** | 4.7s | 196 | $0.1801 | $0.06 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 6.6s | 4.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.9s | rates n/c |
| claude-opus-5 | skill | 100% | 8.8s | $0.19 |
| claude-opus-5 | no-skill | 50% | 5.6s | $0.06 |

_Full per-cell aggregates (harness × model × effort × mode) in `network-automation-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
