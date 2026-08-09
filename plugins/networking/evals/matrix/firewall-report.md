# firewall — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| firewall-zone-count-guideline | recent | As a rule of thumb for minimizing zone sprawl, roughly how many security zones should cover most enterprise firewall deployments? Answer concisely with a number range. | regex: `(?i)5\s*(-|to)\s*8` |
| firewall-panos-nat-prenat | recent | On PAN-OS, when you write a security policy rule for a destination NAT scenario, should the destination address in that rule match the pre-NAT public IP or the post-NAT private IP? Answer concisely. | regex: `(?i)pre-?nat` |
| firewall-stateful-return-traffic | stable | In a stateful firewall, once a session is established and permitted, does the return traffic need its own explicit matching rule? Answer in one sentence. | regex: `(?i)\bno\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `firewall-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
