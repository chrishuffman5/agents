# kentik — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| kentik-rest-api-base-url | recent | What is the base URL, including version path, for Kentik's REST API? Answer concisely. | contains_all: `api.kentik.com``, ``v5` |
| kentik-rtbh-prefix-length | recent | In Kentik's automated DDoS mitigation using RTBH (Remote Triggered Black Hole), what prefix length is announced via BGP community to null-route the attacked destination? Answer concisely. | contains_all: `/32` |
| kentik-flow-protocols-supported | stable | Name at least three flow export protocols or formats that Kentik ingests for network traffic analytics. Answer concisely. | contains_all: `NetFlow``, ``sFlow``, ``IPFIX` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 8.5s | 185 | $1.39 | $0.2317 |
| no-skill | 9 | **33.3%** | 4.2s | 138 | $0.1626 | $0.0542 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 8.5s | 4.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.5s | rates n/c |
| claude-opus-5 | skill | 100% | 11.5s | $0.2317 |
| claude-opus-5 | no-skill | 50% | 4.6s | $0.0542 |

_Full per-cell aggregates (harness × model × effort × mode) in `kentik-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
