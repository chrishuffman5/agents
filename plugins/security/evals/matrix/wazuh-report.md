# wazuh — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| wazuh-fim-frequency | recent | In a Wazuh agent ossec.conf file, what is the default file integrity monitoring scan frequency in seconds for the syscheck module, and how many hours does that equal? Answer concisely. | contains_all: `43200``, ``12 hours` |
| wazuh-agent-port | stable | What TCP port does a Wazuh agent use by default to connect to the Wazuh manager? Answer concisely. | regex: `(?i)1514` |
| wazuh-rule-levels | stable | In the Wazuh rule severity scale, what range of levels is classified as Critical, meaning a confirmed attack? Answer concisely. | regex: `(?i)13\s*-\s*15` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `wazuh-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
