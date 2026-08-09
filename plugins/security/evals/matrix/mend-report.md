# mend — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| mend-renovate-package-managers | recent | Comparing Renovate to GitHub Dependabot for dependency updates, roughly how many package managers does Renovate support versus Dependabot's package manager count? Answer concisely with both approximate numbers. | contains_all: `100``, ``15` |
| mend-license-types-tracked | recent | For license compliance policy purposes, roughly how many distinct open-source license types does Mend track? Answer concisely. | contains_all: `300` |
| mend-sbom-formats | stable | In which two standard SBOM formats can Mend export a project's software dependency inventory? Answer concisely. | contains_all: `CycloneDX``, ``SPDX` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `mend-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
