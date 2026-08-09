# aqua — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aqua-enforcer-heartbeat | recent | How frequently does the Aqua Enforcer send a heartbeat to the Aqua Console or Gateway? Answer concisely. | regex: `(?i)15\s*sec` |
| aqua-ebpf-kernel-version | recent | What is the minimum Linux kernel version required for the Aqua Enforcer to use its preferred eBPF-based kernel monitoring mechanism, instead of falling back to a kernel module? Answer concisely. | regex: `(?i)4\.14` |
| aqua-saas-soc2 | stable | What compliance certification does Aqua state its SaaS-hosted Console holds? Answer concisely. | contains_all: `SOC 2` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 7.5s | 529 | $0.97 | $0.97 |
| no-skill | 9 | **11.1%** | 7.2s | 304 | $0.2181 | $0.2181 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 11.1% | +-2.8pp | 7.5s | 7.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4s | rates n/c |
| claude-opus-5 | skill | 16.7% | 10.5s | $0.97 |
| claude-opus-5 | no-skill | 16.7% | 8.8s | $0.2181 |

_Full per-cell aggregates (harness × model × effort × mode) in `aqua-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
