# xsiam — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| xsiam-automation-integrations | recent | The Automation Center in Cortex XSIAM, built on XSOAR technology, ships with roughly how many pre-built integrations from the XSOAR marketplace? Answer concisely. | regex: `(?i)900\+?` |
| xsiam-qradar-migration | recent | Cortex XSIAM absorbed customers from which discontinued IBM SaaS SIEM product line after IBM divested it to Palo Alto Networks? Answer concisely. | regex: `(?i)qradar` |
| xsiam-bioc-rules | stable | In Cortex XSIAM, what data source do BIOC (Behavioral IOC) rules operate on to perform behavioral pattern matching? Answer concisely. | regex: `(?i)cortex\s*xdr\s*agent` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 10s | 408 | $0.8332 | $0.1666 |
| no-skill | 9 | **33.3%** | 5s | 158 | $0.178 | $0.0593 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 33.3% | +8.4pp | 10s | 5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 11.8s | $0.0976 |
| claude-haiku-4-5 | no-skill | 0% | 4.6s | rates n/c |
| claude-opus-5 | skill | 50% | 8.2s | $0.2127 |
| claude-opus-5 | no-skill | 50% | 5.1s | $0.0593 |

_Full per-cell aggregates (harness × model × effort × mode) in `xsiam-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
