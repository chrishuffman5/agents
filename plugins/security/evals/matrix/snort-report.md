# snort — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| snort-eol-date | recent | When did Snort 2 reach end of life, stated as month and year? Answer concisely. | contains_all: `January``, ``2026` |
| snort-hyperscan-improvement | recent | What throughput improvement range does enabling Hyperscan pattern matching typically provide for content-heavy Snort 3 rulesets? Answer concisely with the range. | regex: `(?i)2\s*(-|to)\s*5\s*x` |
| snort-openappid-app-count | stable | Roughly how many distinct applications can Snort 3's OpenAppID engine identify through application fingerprinting? Answer concisely with the approximate number. | regex: `(?i)3,?000\+?` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **0%** | 6.5s | 210 | $0.5715 | rates n/c |
| no-skill | 9 | **0%** | 5.5s | 205 | $0.1742 | rates n/c |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 0% | 0% | +0pp | 6.5s | 5.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 0% | 7.1s | rates n/c |
| claude-opus-5 | no-skill | 0% | 6.4s | rates n/c |

_Full per-cell aggregates (harness × model × effort × mode) in `snort-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
