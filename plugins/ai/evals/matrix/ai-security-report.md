# ai-security — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **58.3%** | 11s | 435 | $1.7421 | $0.2489 |
| no-skill | 12 | **16.7%** | 10.4s | 422 | $0.5684 | $0.2842 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 58.3% | 16.7% | +41.6pp | 11s | 10.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 9.9s | $0.0799 |
| claude-haiku-4-5 | no-skill | 0% | 9.5s | rates n/c |
| claude-opus-5 | skill | 83.3% | 12.1s | $0.3164 |
| claude-opus-5 | no-skill | 33.3% | 11.2s | $0.2336 |

_Full per-cell aggregates (harness × model × effort × mode) in `ai-security-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
