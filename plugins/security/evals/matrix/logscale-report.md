# logscale — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| logscale-community-edition-limits | recent | What is the daily ingestion cap and the data retention period for CrowdStrike Falcon LogScale's free Community Edition? Answer concisely. | contains_all: `16 GB``, ``7 days` |
| logscale-former-name | stable | CrowdStrike Falcon LogScale was previously known by a different product name before CrowdStrike's rebrand. What was that earlier name? Answer concisely. | regex: `(?i)\bhumio\b` |
| logscale-compression-ratio | recent | LogScale's index-free storage architecture compresses raw log data using zstd compression. What approximate compression ratio does it achieve? Answer concisely. | regex: `(?i)(10\s*:\s*1|10x|10-to-1)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 5.1s | 150 | $0.6199 | $0.31 |
| no-skill | 9 | **33.3%** | 4.1s | 46 | $0.1625 | $0.0542 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 33.3% | +-16.6pp | 5.1s | 4.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.4s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5.7s | $0.31 |
| claude-opus-5 | no-skill | 50% | 4.4s | $0.0542 |

_Full per-cell aggregates (harness × model × effort × mode) in `logscale-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
