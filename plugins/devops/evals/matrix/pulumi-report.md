# pulumi — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `devops` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| pulumi-go-sdk-version | recent | What is the minimum Go version required to use the Pulumi Go SDK per the language support requirements? Answer concisely. | contains_all: `1.21` |
| pulumi-parallel-default | stable | When you run pulumi up without specifying the parallel flag, is there a default cap on how many resource operations run concurrently? Answer in one sentence. | regex: `(?i)(unlimited|no\s*(default\s*)?limit|not\s*limited)` |
| pulumi-urn-meaning | stable | In Pulumi, what does the acronym URN stand for? Answer concisely. | contains_all: `Uniform Resource Name` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `pulumi-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
