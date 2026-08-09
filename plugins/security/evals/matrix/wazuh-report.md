# wazuh — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| wazuh-fim-frequency | recent | In a Wazuh agent ossec.conf file, what is the default file integrity monitoring scan frequency in seconds for the syscheck module, and how many hours does that equal? Answer concisely. | contains_all: `43200``, ``12 hours` |
| wazuh-agent-port | stable | What TCP port does a Wazuh agent use by default to connect to the Wazuh manager? Answer concisely. | regex: `(?i)1514` |
| wazuh-rule-levels | stable | In the Wazuh rule severity scale, what range of levels is classified as Critical, meaning a confirmed attack? Answer concisely. | regex: `(?i)13\s*-\s*15` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 8.2s | 273 | $0.6359 | $0.1272 |
| no-skill | 9 | **22.2%** | 4.5s | 43 | $0.1691 | $0.0846 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 22.2% | +19.5pp | 8.2s | 4.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 9.5s | $0.0299 |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 33.3% | 6.8s | $0.273 |
| claude-opus-5 | no-skill | 33.3% | 4.9s | $0.0846 |

_Full per-cell aggregates (harness × model × effort × mode) in `wazuh-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
