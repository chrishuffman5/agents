# pulsar — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `messaging` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| pulsar-key-shared-subscription | stable | Which Apache Pulsar subscription type delivers messages to many consumers while preserving ordering per key, with individual acknowledgment? Answer concisely. | regex: `(?i)key.?shared` |
| pulsar-nonpersistent-storage | stable | For a non-persistent topic in Apache Pulsar, where is the message data actually stored? Answer concisely. | regex: `(?i)(broker\s*memory|memory\s*only|in.?memory)` |
| pulsar-kop | recent | What does the Pulsar feature called KoP provide? Answer in one sentence. | regex: `(?i)kafka` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 8.9s | 312 | $0.8995 | $0.0818 |
| no-skill | 12 | **91.7%** | 7.5s | 251 | $0.435 | $0.0395 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 91.7% | +0pp | 8.9s | 7.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 6.9s | $0.0201 |
| claude-haiku-4-5 | no-skill | 100% | 6.3s | $0.0151 |
| claude-opus-5 | skill | 83.3% | 10.8s | $0.1557 |
| claude-opus-5 | no-skill | 83.3% | 8.6s | $0.0688 |

_Full per-cell aggregates (harness × model × effort × mode) in `pulsar-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
