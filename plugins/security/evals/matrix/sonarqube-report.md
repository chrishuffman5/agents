# sonarqube — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sonarqube-clean-code-attributes | stable | SonarQube's Clean Code taxonomy defines four core attributes that clean code should have. Name all four. Answer concisely. | contains_all: `Consistency``, ``Intentionality``, ``Adaptability``, ``Responsibility` |
| sonarqube-default-gate-coverage | recent | Under SonarQube's default Sonar Way quality gate, what is the minimum test coverage percentage required on new code for the gate to pass? Answer concisely with the number. | regex: `(?i)\b80\s*%?` |
| sonarqube-branch-analysis-edition | recent | What is the minimum SonarQube edition, among Community, Developer, Enterprise, and Data Center, that supports branch analysis rather than only main-branch analysis? Answer concisely. | regex: `(?i)\bdeveloper\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 4.4s | 12 | $0.5496 | $0.2748 |
| no-skill | 9 | **22.2%** | 4.3s | 32 | $0.1686 | $0.0843 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 4.4s | 4.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.6s | rates n/c |
| claude-opus-5 | skill | 33.3% | 4.8s | $0.2748 |
| claude-opus-5 | no-skill | 33.3% | 4.6s | $0.0843 |

_Full per-cell aggregates (harness × model × effort × mode) in `sonarqube-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
