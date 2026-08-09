# fortios — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| fortios-np7-max-throughput | recent | What is the maximum throughput of Fortinet's NP7 network processor used for hardware-accelerated forwarding on FortiGate appliances? Answer concisely. | contains_all: `200 Gbps` |
| fortios-fgcp-failover-time | recent | In FortiGate FGCP active-passive high availability, roughly how fast does failover occur for new sessions? Answer concisely. | regex: `(?i)(under|less than|<)\s*1\s*second` |
| fortios-proxy-based-inspection | stable | Which FortiOS UTM inspection mode fully buffers and reconstructs content, giving the best detection of evasive techniques like chunked encoding at the cost of higher latency? Answer concisely. | regex: `(?i)proxy[- ]based` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `fortios-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
