# containerlab — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| containerlab-reconfigure-flag | recent | In Containerlab, what flag do you add to the clab deploy command to force it to re-apply node startup configurations on an already-running lab? Answer concisely. | contains_all: `reconfigure` |
| containerlab-server-sizing | recent | As a rule of thumb, what server specs, cpu cores and RAM, does Containerlab guidance suggest for running a 4-spine, 8-leaf fabric using native container images? Answer concisely with both numbers. | contains_all: `16``, ``64` |
| containerlab-root-required | stable | Does deploying a Containerlab topology require root privileges on the host, since it manipulates network namespaces? Answer in one sentence. | regex: `(?i)(\byes\b|root|sudo)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `containerlab-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
