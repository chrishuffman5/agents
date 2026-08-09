# aruba-aoscx — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aruba-aoscx-cx10000-dpu | recent | The Aruba CX 10000 switch integrates a DPU on each line card to offload stateful firewall, NAT, and micro-segmentation at line rate. Which vendor makes this DPU? Answer concisely. | contains_all: `Pensando` |
| aruba-aoscx-srv6-preview | recent | Aruba AOS-CX 10.15 introduced a preview implementation of IPv6 Segment Routing. Which two switch platform families support this preview? Answer concisely. | contains_all: `9300``, ``10000` |
| aruba-aoscx-vsx-l3 | stable | In an Aruba AOS-CX VSX pair, do the two switches share a single Layer 3 routing table, or does each maintain its own? Answer in one sentence. | regex: `(?i)(own|independent|not shared|separate)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 8.2s | 483 | $1.5876 | $0.2646 |
| no-skill | 9 | **22.2%** | 5.5s | 172 | $0.1795 | $0.0898 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 22.2% | +27.8pp | 8.2s | 5.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.1s | rates n/c |
| claude-opus-5 | skill | 100% | 13.2s | $0.2646 |
| claude-opus-5 | no-skill | 33.3% | 5.6s | $0.0898 |

_Full per-cell aggregates (harness × model × effort × mode) in `aruba-aoscx-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
