# qualys — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| qualys-trurisk-qds-ranges | recent | What are the numeric ranges for Qualys's Asset TruRisk Score and its QDS, the Qualys Detection Score, respectively? Answer concisely with both ranges. | regex: `(?i)(?=.*1.{0,4}1000)(?=.*0.{0,4}100)` |
| qualys-cloud-agent-interval | recent | By default, how often does the Qualys Cloud Agent run a full interval assessment scan on an endpoint? Answer concisely. | regex: `(?i)4\s*hours?` |
| qualys-qds-inputs | stable | Which FIRST.org exploitation-probability model and which US government known-exploited-vulnerabilities list does Qualys's QDS combine alongside CVSS to score detections? Answer concisely, naming both. | contains_all: `EPSS``, ``CISA KEV` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 5.1s | 188 | $0.6531 | $0.6531 |
| no-skill | 9 | **11.1%** | 5.2s | 88 | $0.166 | $0.166 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 11.1% | +-2.8pp | 5.1s | 5.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.1s | rates n/c |
| claude-opus-5 | skill | 16.7% | 6.5s | $0.6531 |
| claude-opus-5 | no-skill | 16.7% | 5.2s | $0.166 |

_Full per-cell aggregates (harness × model × effort × mode) in `qualys-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
