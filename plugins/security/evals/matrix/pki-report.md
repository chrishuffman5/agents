# pki — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| pki-cab-forum-max-validity | stable | Under CA/Browser Forum baseline requirements enforced since 2020, what is the maximum validity period in days for a publicly-trusted TLS certificate? Answer concisely. | regex: `(?i)398\s*days?` |
| pki-lets-encrypt-6day | recent | In March 2025, Let's Encrypt launched a new opt-in short-lived certificate duration. How many days is that certificate valid for? Answer concisely. | regex: `(?i)(6[\s-]?day|six[\s-]?day)` |
| pki-fips-disallowed-algorithms | stable | Under FIPS 140-3 guidance for certificates, which two legacy hash algorithms and which weak RSA key size are explicitly disallowed? Answer concisely, naming all three. | contains_all: `MD5``, ``SHA-1``, ``1024` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `pki-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
