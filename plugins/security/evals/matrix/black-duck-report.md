# black-duck — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **25%** | 5.4s | 159 | $0.7165 | $0.2388 |
| no-skill | 9 | **11.1%** | 5s | 100 | $0.1522 | $0.1522 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 11.1% | +13.9pp | 5.4s | 5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.4s | rates n/c |
| claude-opus-5 | skill | 50% | 7.2s | $0.2388 |
| claude-opus-5 | no-skill | 16.7% | 4.8s | $0.1522 |

_Full per-cell aggregates (harness × model × effort × mode) in `black-duck-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
