# powerdns — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| powerdns-versions | recent | What are the current major version numbers of the three PowerDNS suite products: Authoritative Server, Recursor, and DNSdist? Answer concisely with all three. | contains_all: `5.0``, ``5.4``, ``2.0` |
| powerdns-serve-stale | recent | Can PowerDNS Recursor keep answering queries using expired cache entries when the upstream authoritative servers become unreachable? Answer in one sentence. | regex: `(?i)(\byes\b|serve-?stale|serve-?expired)` |
| powerdns-auth-no-recursion | stable | Can the PowerDNS Authoritative Server perform recursive DNS lookups on behalf of clients? Answer in one sentence. | regex: `(?i)(\bno\b|does not)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `powerdns-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
