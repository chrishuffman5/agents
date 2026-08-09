# sonic — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **25%** | 5.1s | 177 | $0.5725 | $0.1908 |
| no-skill | 9 | **33.3%** | 4.7s | 124 | $0.1751 | $0.0584 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 5.1s | 4.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.1s | rates n/c |
| claude-opus-5 | skill | 50% | 6.3s | $0.1908 |
| claude-opus-5 | no-skill | 50% | 5.5s | $0.0584 |

_Full per-cell aggregates (harness × model × effort × mode) in `sonic-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
