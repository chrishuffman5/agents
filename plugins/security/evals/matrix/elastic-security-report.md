# elastic-security — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| elastic-security-esql-introduced | recent | In which minor version of the Elastic Stack was the ES|QL piped query language first introduced? Answer concisely. | regex: `(?i)8\.11` |
| elastic-security-fleet-server-scale | recent | According to common Elastic Security guidance, roughly how many Elastic Agents can a single Fleet Server manage before you need to scale horizontally? Answer concisely. | regex: `(?i)10,?000` |
| elastic-security-detection-rule-count | stable | About how many prebuilt detection rules does Elastic Security ship with, mapped to the MITRE ATT&CK framework? Answer concisely. | regex: `(?i)1,?300\+?` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 5.7s | 128 | $0.5598 | $0.5598 |
| no-skill | 9 | **22.2%** | 4.9s | 149 | $0.1703 | $0.0852 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 22.2% | +-13.9pp | 5.7s | 4.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.5s | rates n/c |
| claude-opus-5 | skill | 16.7% | 5.7s | $0.5598 |
| claude-opus-5 | no-skill | 33.3% | 5.6s | $0.0852 |

_Full per-cell aggregates (harness × model × effort × mode) in `elastic-security-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
