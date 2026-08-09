# splunk-soar — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| splunk-soar-app-count | recent | Approximately how many pre-built apps does Splunk SOAR ship with for integrating third-party security tools? Answer concisely. | regex: `(?i)\b300\+?\b` |
| splunk-soar-artifact-term | stable | In Splunk SOAR's container-based data model, what term describes an individual piece of evidence, such as an IP address, domain, or file hash, attached to a container? Answer concisely. | contains_all: `Artifact` |
| splunk-soar-automation-broker | recent | What is the name of the on-premises component that lets a cloud-hosted Splunk SOAR instance reach and act on internal, non-internet-facing systems? Answer concisely. | contains_all: `automation broker` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 6.1s | 49 | $0.547 | $0.2735 |
| no-skill | 9 | **33.3%** | 4.7s | 66 | $0.171 | $0.057 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 33.3% | +-16.6pp | 6.1s | 4.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.7s | rates n/c |
| claude-opus-5 | skill | 33.3% | 6.3s | $0.2735 |
| claude-opus-5 | no-skill | 50% | 4.3s | $0.057 |

_Full per-cell aggregates (harness × model × effort × mode) in `splunk-soar-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
