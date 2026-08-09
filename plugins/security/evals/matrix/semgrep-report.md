# semgrep — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| semgrep-license | recent | Under what open source license is the core Semgrep OSS engine released? Answer concisely with the license name and version. | contains_all: `LGPL``, ``2.1` |
| semgrep-taint-oss-vs-pro | stable | For Semgrep taint analysis, which tier is required to follow tainted data across multiple files and function calls in a project, rather than only within a single file? Answer concisely naming the tier. | regex: `(?i)\bpro\b` |
| semgrep-secrets-validity-levels | recent | Semgrep Secrets reports a validity status for each detected secret after checking whether it is still active. Name the three possible validity status values it can report. Answer concisely. | contains_all: `valid``, ``invalid``, ``unknown` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 4.1s | 53 | $0.5552 | $0.1851 |
| no-skill | 9 | **33.3%** | 5.1s | 57 | $0.1702 | $0.0567 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 4.1s | 5.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4s | rates n/c |
| claude-opus-5 | skill | 50% | 4.7s | $0.1851 |
| claude-opus-5 | no-skill | 50% | 5.7s | $0.0567 |

_Full per-cell aggregates (harness × model × effort × mode) in `semgrep-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
