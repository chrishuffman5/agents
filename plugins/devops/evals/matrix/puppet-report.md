# puppet — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| puppet-checkin-interval | recent | By default, how often does a Puppet agent contact the Puppet Server over HTTPS to request and apply a new catalog? Answer concisely. | regex: `(?i)(30\s*min)` |
| puppet-facter-ohai | stable | Facter is Puppet's system fact collector. Which equivalent fact-gathering tool from the Chef ecosystem is it directly compared to here? Answer concisely. | contains_all: `Ohai` |
| puppet-hiera-node-precedence | stable | In the sample Hiera hierarchy shown for Puppet, which data source is checked first, before per-environment, per-OS, and common data? Answer concisely. | regex: `(?i)per-?node` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 9.5s | 249 | $1.0631 | $0.1063 |
| no-skill | 12 | **83.3%** | 8.8s | 278 | $0.5067 | $0.0507 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 83.3% | +0pp | 9.5s | 8.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 10.1s | $0.0363 |
| claude-haiku-4-5 | no-skill | 66.7% | 7.2s | $0.027 |
| claude-opus-5 | skill | 100% | 8.8s | $0.153 |
| claude-opus-5 | no-skill | 100% | 10.4s | $0.0665 |

_Full per-cell aggregates (harness × model × effort × mode) in `puppet-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
