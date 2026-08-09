# aruba-wireless — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **50%** | 9.7s | 473 | $1.4838 | $0.2473 |
| no-skill | 9 | **33.3%** | 4.7s | 147 | $0.1773 | $0.0591 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 9.7s | 4.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.3s | rates n/c |
| claude-opus-5 | skill | 100% | 14.9s | $0.2473 |
| claude-opus-5 | no-skill | 50% | 5.5s | $0.0591 |

_Full per-cell aggregates (harness × model × effort × mode) in `aruba-wireless-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
