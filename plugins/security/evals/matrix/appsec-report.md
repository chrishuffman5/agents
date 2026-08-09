# appsec — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| appsec-precommit-secret-scanners | recent | Which two open source secret-scanning tools are named as options to run during the pre-commit stage of a DevSecOps pipeline? Answer concisely. | contains_all: `detect-secrets``, ``git-secrets` |
| appsec-shift-left-cost | stable | Roughly by what factor does catching a security issue early via shift-left practices reduce remediation cost compared to finding it in production? Answer concisely. | regex: `(?i)\b10\b\D{0,4}\b100\b` |
| appsec-asvs-level3 | stable | Under the OWASP ASVS, which verification level requires penetration testing and architectural review, and is reserved for critical applications like finance and healthcare? Answer concisely. | regex: `(?i)level\s*3|\bl3\b|\bthree\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 5.2s | 174 | $0.6381 | $0.319 |
| no-skill | 9 | **11.1%** | 5.4s | 114 | $0.1609 | $0.1609 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 5.2s | 5.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5.8s | $0.319 |
| claude-opus-5 | no-skill | 16.7% | 6.2s | $0.1609 |

_Full per-cell aggregates (harness × model × effort × mode) in `appsec-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
