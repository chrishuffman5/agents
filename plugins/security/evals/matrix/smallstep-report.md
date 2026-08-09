# smallstep — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **25%** | 6.8s | 289 | $0.8001 | $0.2667 |
| no-skill | 9 | **33.3%** | 5.4s | 151 | $0.1706 | $0.0569 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 6.8s | 5.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.2s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.3s | rates n/c |
| claude-opus-5 | skill | 50% | 8.5s | $0.2667 |
| claude-opus-5 | no-skill | 50% | 6.5s | $0.0569 |

_Full per-cell aggregates (harness × model × effort × mode) in `smallstep-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
