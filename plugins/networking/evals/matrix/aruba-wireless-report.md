# aruba-wireless — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aruba-wireless-ap730-wifi7 | recent | Which HPE Aruba access point model is the first to support Wi-Fi 7 (802.11be), including Multi-Link Operation? Answer concisely. | contains_all: `730` |
| aruba-wireless-airmatch-cadence | recent | Aruba AirMatch computes a network-wide optimal RF channel and power plan. How often does it push this updated plan out to the access points? Answer concisely. | regex: `(?i)(once\s*(a|per)\s*day|daily|24\s*hour)` |
| aruba-wireless-6ghz-wpa3 | stable | For an SSID broadcast in the 6 GHz band on Aruba access points, what wireless security protocol is mandatory? Answer concisely. | regex: `(?i)wpa3` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `aruba-wireless-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
