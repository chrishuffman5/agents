# wireless — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| wireless-wifi7-specs | recent | What is the maximum PHY data rate for Wi-Fi 7 (802.11be), and what is the widest channel width it supports? Answer concisely with both numbers. | contains_all: `46``, ``320` |
| wireless-rssi-targets | recent | In enterprise Wi-Fi site surveys, what target RSSI values in dBm are typically used for voice and video coverage versus general data coverage? Answer concisely with both numbers. | contains_all: `67``, ``72` |
| wireless-6ghz-wpa3 | stable | Does the 6 GHz Wi-Fi band permit legacy WPA2 security, or does it require WPA3? Answer in one sentence. | regex: `(?i)\bwpa3\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 5.2s | 153 | $0.5664 | $0.2832 |
| no-skill | 9 | **33.3%** | 4.3s | 120 | $0.1608 | $0.0536 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 33.3% | +-16.6pp | 5.2s | 4.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.7s | rates n/c |
| claude-opus-5 | skill | 33.3% | 6.4s | $0.2832 |
| claude-opus-5 | no-skill | 50% | 4.7s | $0.0536 |

_Full per-cell aggregates (harness × model × effort × mode) in `wireless-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
