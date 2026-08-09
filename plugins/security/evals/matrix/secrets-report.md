# secrets — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| secrets-envelope-encryption | stable | In the envelope encryption pattern used by cloud key management systems, when you rotate the master key, which single component actually needs to be re-encrypted so you avoid re-encrypting all the underlying data? Answer in one sentence naming that component. | regex: `(?i)\b(data encryption key|dek)\b` |
| secrets-fips-140-3 | recent | What does FIPS 140-3 Level 3 certification guarantee about a hardware security module in terms of tamper protection? Answer concisely. | contains_all: `tamper-evident``, ``tamper-resistant` |
| secrets-rotation-versioning | recent | During secret rotation, what naming pattern does AWS Secrets Manager use to label the version that is the active current value versus the one that was previously active? Answer concisely naming both version labels. | contains_all: `AWSCURRENT``, ``AWSPREVIOUS` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `secrets-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
