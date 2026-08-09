# appsec — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `appsec-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
