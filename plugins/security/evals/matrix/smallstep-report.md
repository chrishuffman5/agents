# smallstep — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| smallstep-renewal-window | recent | When step ca renew runs in daemon mode to keep a service certificate continuously fresh, at what percentage of the certificate's total lifetime does it actually trigger renewal? Answer concisely with the percentage. | regex: `(?i)\b66\s*(percent|%)?` |
| smallstep-max-host-ssh-duration | recent | In a step-ca authority configuration, what is the maximum duration allowed for an SSH host certificate, expressed in hours? Answer concisely. | regex: `(?i)\b1680\s*h(ours?)?` |
| smallstep-default-tls-duration | stable | By default, how long is a TLS leaf certificate valid for when issued by a step-ca authority using its default claims configuration? Answer concisely. | regex: `(?i)\b24\s*h(ours?)?` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `smallstep-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
