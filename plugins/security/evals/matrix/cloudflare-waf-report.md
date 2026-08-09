# cloudflare-waf — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cloudflare-waf-paranoia-level | stable | In Cloudflare's OWASP Core Ruleset configuration, what is the name of the setting that controls how aggressively rules are applied, ranging from PL1 through PL4? Answer concisely. | regex: `(?i)paranoia` |
| cloudflare-waf-under-attack-mode | stable | What is the name of the Cloudflare security level setting that issues a JavaScript challenge to every visitor, intended for use during an active DDoS incident? Answer concisely. | regex: `(?i)under attack` |
| cloudflare-waf-processing-order | recent | In Cloudflare's edge security processing order, which is evaluated first: custom WAF rules or the managed rulesets like the Cloudflare OWASP Core Ruleset? Answer with just which one comes first. | regex: `(?i)custom` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cloudflare-waf-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
