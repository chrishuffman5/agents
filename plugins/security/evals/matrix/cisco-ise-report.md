# cisco-ise — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cisco-ise-tacacs-port | stable | What TCP port does TACACS+ use for Cisco ISE device administration traffic? Answer concisely. | regex: `\b49\b` |
| cisco-ise-monitor-mode-duration | recent | Before enabling full 802.1X enforcement on Cisco ISE, how long should an organization typically run in Monitor Mode first to build a device inventory? Answer concisely. | regex: `30\D{1,5}90\s*days` |
| cisco-ise-ad-forest-limit | recent | In ISE 3.x, what is the maximum number of Active Directory forests that Cisco ISE can join? Answer concisely. | regex: `\b50\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-ise-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
