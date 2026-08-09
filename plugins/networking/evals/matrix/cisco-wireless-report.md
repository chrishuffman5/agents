# cisco-wireless — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cisco-wireless-mlo-version | recent | Which Cisco IOS-XE wireless release first introduced Wi-Fi 7 Multi-Link Operation support on the Catalyst 9800 WLC? Answer concisely. | contains_all: `17.15` |
| cisco-wireless-320mhz-channels | recent | In the 6 GHz band on a Cisco Catalyst 9800 wireless deployment, how many non-overlapping 320 MHz channels are available? Answer concisely. | regex: `\b3\b` |
| cisco-wireless-cw9170-standard | stable | What Wi-Fi standard do the Cisco CW9170 and CW9178 access points support? Answer concisely. | regex: `(?i)(wi-?fi\s*7|802\.11be)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-wireless-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
