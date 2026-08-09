# ai-security — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ai-security-redteam-exfiltration | recent | In an internal Anthropic red-team test where the attacker controlled the prompt content via phishing, in how many out of 25 attempts did the attacker succeed at exfiltrating AWS credentials before environmental egress controls were applied? Answer concisely. | contains_all: `24` |
| ai-security-adaptive-attack-rate | recent | Roughly what attack success rate did Anthropic measure against Claude Opus 4.5 using an internal adaptive Best-of-N jailbreak attacker running 100 attempts per environment? Answer concisely. | regex: `(?i)~?\s?1\s?%` |
| ai-security-owasp-2025-risk-movement | stable | In the OWASP Top 10 for LLM Applications 2025 edition, which risk category moved up from 6th place to 2nd place? Answer concisely. | contains_all: `Sensitive``, ``Disclosure` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `ai-security-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
