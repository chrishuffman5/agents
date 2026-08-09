# sast — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sast-fp-rate-enterprise | recent | Without tuning, what false-positive rate range do enterprise SAST tools like Checkmarx and Veracode typically exhibit? Answer concisely. | regex: `(?i)30.{0,4}50\s*%` |
| sast-fp-rate-gate-target | recent | What false-positive rate threshold is recommended as a tuning target for SAST findings that gate a CI/CD pipeline merge? Answer concisely. | regex: `(?i)(<|less than)\s*20\s*%` |
| sast-sanitizer-techniques | stable | Name two specific secure-coding techniques that SAST tools treat as sanitizers, which break the taint chain and thereby reduce injection-vulnerability false positives. Answer concisely. | contains_all: `parameterized queries``, ``output encoding` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 5.6s | 255 | $0.5774 | $0.2887 |
| no-skill | 9 | **11.1%** | 6.2s | 405 | $0.1829 | $0.1829 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 5.6s | 6.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.9s | rates n/c |
| claude-opus-5 | skill | 33.3% | 7.3s | $0.2887 |
| claude-opus-5 | no-skill | 16.7% | 7.3s | $0.1829 |

_Full per-cell aggregates (harness × model × effort × mode) in `sast-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
