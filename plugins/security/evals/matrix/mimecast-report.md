# mimecast — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| mimecast-spam-score-scale | stable | What numeric scale does Mimecast use for its inbound spam scoring, and around what score is typically treated as the spam threshold for quarantine? Answer concisely. | contains_all: `100``, ``70` |
| mimecast-continuity-rto | recent | For Mimecast Email Continuity during a primary mail server outage, what is the target recovery time objective for making the emergency inbox available, and how many days of email history does that emergency inbox retain? Answer concisely. | contains_all: `5 minutes``, ``30 days` |
| mimecast-archive-dedup-savings | recent | Mimecast Archive uses single-instance storage to deduplicate identical messages. By roughly what percentage range does this reduce storage footprint? Answer concisely. | contains_all: `20``, ``40` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 5.4s | 329 | $0.6517 | $0.6517 |
| no-skill | 9 | **0%** | 5.8s | 192 | $0.1807 | rates n/c |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 0% | +8.3pp | 5.4s | 5.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.1s | rates n/c |
| claude-opus-5 | skill | 16.7% | 7.3s | $0.6517 |
| claude-opus-5 | no-skill | 0% | 6.6s | rates n/c |

_Full per-cell aggregates (harness × model × effort × mode) in `mimecast-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
