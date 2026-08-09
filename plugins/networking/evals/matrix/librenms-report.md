# librenms — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| librenms-rrdcached-scale-threshold | recent | At approximately what device count should a LibreNMS deployment enable rrdcached to avoid RRDtool write performance problems? Answer concisely. | regex: `(?i)\b500\b` |
| librenms-device-library-size | recent | Roughly how many device definitions are included in the LibreNMS device library? Answer concisely. | regex: `(?i)10,?000` |
| librenms-tech-stack | stable | What PHP framework and primary database engine does LibreNMS run on? Answer concisely. | contains_all: `Laravel``, ``MySQL` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **33.3%** | 7.4s | 301 | $1.3612 | $0.3403 |
| no-skill | 9 | **11.1%** | 5.5s | 103 | $0.1732 | $0.1732 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 33.3% | 11.1% | +22.2pp | 7.4s | 5.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.9s | rates n/c |
| claude-opus-5 | skill | 66.7% | 10.5s | $0.3403 |
| claude-opus-5 | no-skill | 16.7% | 5.8s | $0.1732 |

_Full per-cell aggregates (harness × model × effort × mode) in `librenms-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
