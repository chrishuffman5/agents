# netskope — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| netskope-newedge-pop-count | recent | How many points of presence does Netskope's NewEdge private network infrastructure operate globally? Answer concisely. | contains_all: `75` |
| netskope-app-catalog-cci-scale | stable | Roughly how many cloud applications are covered in Netskope's app catalog for CASB purposes, and what numeric scale does the Cloud Confidence Index use to score each app's risk posture? Answer concisely. | contains_all: `40,000``, ``100` |
| netskope-gateway-anycast-domain | recent | What domain name does the Netskope Client use for anycast DNS resolution so it can automatically connect to the nearest NewEdge point of presence? Answer concisely. | contains_all: `gateway.yo.ng` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 4.6s | 185 | $0.6567 | $0.6567 |
| no-skill | 9 | **11.1%** | 7.1s | 202 | $0.2083 | $0.2083 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 11.1% | +-2.8pp | 4.6s | 7.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.3s | rates n/c |
| claude-opus-5 | skill | 16.7% | 5.7s | $0.6567 |
| claude-opus-5 | no-skill | 16.7% | 8.5s | $0.2083 |

_Full per-cell aggregates (harness × model × effort × mode) in `netskope-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
