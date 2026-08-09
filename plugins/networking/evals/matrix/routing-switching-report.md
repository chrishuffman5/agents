# routing-switching — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| routing-switching-vxlan-mtu | recent | In a data center spine-leaf fabric running VXLAN, how many bytes of overhead does VXLAN encapsulation add, and what MTU should you set on the fabric links so encapsulated frames are not fragmented or dropped? Answer concisely with both numbers. | contains_all: `50``, ``9214` |
| routing-switching-stackwise-max | recent | For Cisco Catalyst 9200/9300 campus access switches using StackWise physical stacking, what is the maximum number of switches you can join into a single stack? Answer concisely. | regex: `(?i)\b8\b` |
| routing-switching-eigrp-arista | stable | Does Arista EOS support the EIGRP routing protocol the way Cisco IOS-XE and NX-OS do? Answer in one sentence. | regex: `(?i)(\bno\b|not (available|supported)|cisco-only|cisco proprietary)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 9.4s | 530 | $1.4403 | $0.2881 |
| no-skill | 9 | **22.2%** | 5.9s | 214 | $0.1753 | $0.0876 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 22.2% | +19.5pp | 9.4s | 5.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.2s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.6s | rates n/c |
| claude-opus-5 | skill | 83.3% | 14.7s | $0.2881 |
| claude-opus-5 | no-skill | 33.3% | 6.6s | $0.0876 |

_Full per-cell aggregates (harness × model × effort × mode) in `routing-switching-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
