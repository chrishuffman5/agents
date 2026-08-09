# solarwinds-npm — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| solarwinds-npm-api-port | recent | What TCP port does the SolarWinds Orion Information Service REST API listen on by default? Answer concisely. | contains_all: `17778` |
| solarwinds-npm-2025-thinap | recent | Which SolarWinds NPM release added the ability to discover and manage individual thin access points as their own SNMP nodes, instead of only at the wireless controller level? Answer concisely. | contains_all: `2025.2` |
| solarwinds-npm-sql-backend | stable | Does SolarWinds Orion (NPM) require a Microsoft SQL Server backend to store its configuration and polling data? Answer in one sentence. | regex: `(?i)(\byes\b|requires|sql server)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 7.1s | 212 | $1.0739 | $0.358 |
| no-skill | 9 | **22.2%** | 4.8s | 82 | $0.1654 | $0.0827 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 7.1s | 4.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.1s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.9s | rates n/c |
| claude-opus-5 | skill | 50% | 10.2s | $0.358 |
| claude-opus-5 | no-skill | 33.3% | 5.2s | $0.0827 |

_Full per-cell aggregates (harness × model × effort × mode) in `solarwinds-npm-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
