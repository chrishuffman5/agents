# google-workspace — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `mail-collab` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| google-workspace-domain-cap | stable | In Google Workspace, what is the maximum number of domains, combining primary, alias, and secondary domains, that a single account can have? Answer concisely. | regex: `\b600\b` |
| google-workspace-dkim-bit | stable | When generating a new DKIM signing key for a domain in the Google Workspace Admin Console, what key length in bits is recommended? Answer concisely. | regex: `\b2048\b` |
| google-workspace-gwmme-gap | recent | When migrating from Google Workspace to Microsoft 365 with a tool like GWMME, does the migration bring over Google Chat history and Meet recordings along with email, calendar, and contacts? Answer in one sentence. | regex: `(?i)(\bno\b|does not|doesn't|won't|not\b)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **100%** | 10s | 402 | $0.8819 | $0.0735 |
| no-skill | 12 | **75%** | 7.8s | 217 | $0.4402 | $0.0489 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 75% | +25pp | 10s | 7.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 11.5s | $0.0296 |
| claude-haiku-4-5 | no-skill | 66.7% | 9.4s | $0.0272 |
| claude-opus-5 | skill | 100% | 8.6s | $0.1174 |
| claude-opus-5 | no-skill | 83.3% | 6.3s | $0.0663 |

_Full per-cell aggregates (harness × model × effort × mode) in `google-workspace-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
