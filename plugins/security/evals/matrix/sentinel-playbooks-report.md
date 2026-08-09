# sentinel-playbooks — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sentinel-playbooks-logic-apps-timeout | recent | For Sentinel playbooks built on Azure Logic Apps, what is the default timeout for a single action, and what is the maximum duration for an entire workflow? Answer concisely with both time values. | contains_all: `30 seconds``, ``90 days` |
| sentinel-playbooks-virustotal-rate-limit | recent | What request rate limit does the VirusTotal free tier API impose, which Sentinel playbook designers need to account for with throttling? Answer concisely. | regex: `(?i)4\s*(req(uests)?)?\s*(per|/)\s*min` |
| sentinel-playbooks-trigger-types | stable | Sentinel playbooks can be started by three different trigger types. Name all three. Answer concisely. | contains_all: `Incident trigger``, ``Alert trigger``, ``Entity trigger` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 7.4s | 408 | $0.6986 | $0.2329 |
| no-skill | 9 | **11.1%** | 8s | 334 | $0.2013 | $0.2013 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 11.1% | +13.9pp | 7.4s | 8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 6.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.7s | rates n/c |
| claude-opus-5 | skill | 50% | 7.9s | $0.2329 |
| claude-opus-5 | no-skill | 16.7% | 10.2s | $0.2013 |

_Full per-cell aggregates (harness × model × effort × mode) in `sentinel-playbooks-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
