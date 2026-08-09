# zscaler — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| zscaler-datacenters | stable | Roughly how many global data centers does Zscaler operate its Zero Trust Exchange from, and what percentage of the Fortune 500 use Zscaler? Answer concisely with both figures. | contains_all: `150+``, ``40%` |
| zscaler-url-categories | recent | Roughly how many URL categories does Zscaler ZIA maintain for URL filtering, kept updated in real time by ThreatLabZ? Answer concisely. | regex: `(?i)200\+?` |
| zscaler-zdx-probe-interval | recent | By default, how often does the Zscaler Client Connector agent run ZDX synthetic probes such as HTTP GET, DNS lookup, and traceroute? Answer concisely. | regex: `(?i)5\s*minutes?` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `zscaler-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
