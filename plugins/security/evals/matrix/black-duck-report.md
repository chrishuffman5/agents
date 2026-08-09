# black-duck — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| black-duck-bdba-file-limit | recent | In Black Duck Binary Analysis (BDBA), what is the default maximum file size limit for binaries being scanned? Answer concisely. | regex: `(?i)2\s*GB` |
| black-duck-knowledgebase-projects | recent | Approximately how many open source projects does the Black Duck KnowledgeBase track? Answer concisely. | regex: `(?i)3\.5\s*(million|m\b)` |
| black-duck-soup-standard | stable | Which IEC standard for medical device software is most closely associated with the requirement to produce a SOUP list documenting third-party and open-source components? Answer concisely. | regex: `(?i)iec\s*62304` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `black-duck-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
