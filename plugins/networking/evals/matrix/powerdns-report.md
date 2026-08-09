# powerdns — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **50%** | 8.7s | 221 | $1.3831 | $0.2305 |
| no-skill | 9 | **22.2%** | 5.8s | 270 | $0.2216 | $0.1108 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 22.2% | +27.8pp | 8.7s | 5.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.2s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.7s | rates n/c |
| claude-opus-5 | skill | 100% | 12.2s | $0.2305 |
| claude-opus-5 | no-skill | 33.3% | 6.9s | $0.1108 |

_Full per-cell aggregates (harness × model × effort × mode) in `powerdns-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
