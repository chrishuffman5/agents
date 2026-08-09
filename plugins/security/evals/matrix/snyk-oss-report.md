# snyk-oss — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| snyk-oss-reachability-languages | recent | Snyk Open Source reachability analysis, which checks whether your code actually calls a vulnerable function, is available for which three programming languages? Answer concisely naming all three. | contains_all: `JavaScript``, ``Java``, ``Python` |
| snyk-oss-sbom-formats | stable | The snyk sbom command can generate output in which two SBOM standard formats? Answer concisely naming both. | contains_all: `CycloneDX``, ``SPDX` |
| snyk-oss-target-vs-project | recent | In Snyk terminology, if a monorepo contains ten separate package.json manifest files, how many separate Snyk Projects does scanning that repository create? Answer concisely with the number. | regex: `(?i)\b10\b|\bten\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `snyk-oss-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
