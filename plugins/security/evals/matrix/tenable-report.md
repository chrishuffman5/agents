# tenable — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| tenable-plugin-count | stable | Approximately how many vulnerability detection plugins are in the Tenable Nessus plugin library? Answer concisely. | regex: `(?i)200,?000` |
| tenable-aes-formula | recent | What two Tenable scores are combined, one being a 1-to-10 business-context rating and the other a dynamic threat-informed vulnerability score, to produce the Asset Exposure Score? Answer concisely. | contains_all: `ACR``, ``VPR` |
| tenable-credentialed-rate | stable | Roughly what percentage of vulnerabilities does a credentialed Tenable Nessus scan typically detect? Answer concisely. | regex: `(?i)\b95\+?%?\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.6s | 209 | $0.5663 | $0.1888 |
| no-skill | 9 | **22.2%** | 5.1s | 137 | $0.1693 | $0.0846 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 5.6s | 5.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.2s | rates n/c |
| claude-opus-5 | skill | 50% | 6s | $0.1888 |
| claude-opus-5 | no-skill | 33.3% | 5.6s | $0.0846 |

_Full per-cell aggregates (harness × model × effort × mode) in `tenable-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
