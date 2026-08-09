# burp-suite — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| burp-suite-intruder-attack-types | stable | Burp Suite Intruder offers four attack types combining payload positions with payload lists. Name all four. Answer concisely. | contains_all: `Sniper``, ``Battering Ram``, ``Pitchfork``, ``Cluster Bomb` |
| burp-suite-bcheck-year | recent | In what year was BCheck, the scripting language for writing custom Burp Suite scan checks, introduced? Answer concisely. | regex: `(?i)\b2022\b` |
| burp-suite-sequencer-keyspace | recent | When analyzing a session token with Burp Suite Sequencer, what minimum effective key space in bits should the token show to be considered adequately random? Answer concisely. | regex: `(?i)\b64\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `burp-suite-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
