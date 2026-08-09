# sonic — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sonic-dash-acronym | recent | In the SONiC ecosystem, what does the acronym DASH stand for, and which major cloud provider implements it for SmartNIC offload? Answer concisely. | contains_all: `Disaggregated``, ``Azure` |
| sonic-config-reload | recent | If you hand-edit /etc/sonic/config_db.json directly on a SONiC switch, does that change take effect immediately, or must you run another command to apply it? Name the command in one sentence. | regex: `(?i)(config reload|config load)` |
| sonic-sai-acronym | stable | In SONiC, what does the acronym SAI stand for? Answer concisely. | contains_all: `Abstraction``, ``Interface` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `sonic-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
