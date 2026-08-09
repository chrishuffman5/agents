# google-workspace — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `mail-collab` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `google-workspace-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
