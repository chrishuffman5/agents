# azure-dns — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| azure-dns-forwarding-ruleset-limit | recent | In Azure DNS Private Resolver, how many forwarding rules can a single DNS forwarding ruleset contain? Answer concisely with the number. | regex: `(?i)1,?000` |
| azure-dns-autoreg-single-zone | recent | In Azure Private DNS, can a single VNet have auto-registration enabled for more than one private DNS zone at the same time? Answer in one sentence. | regex: `(?i)(\bno\b|cannot|only one|single zone)` |
| azure-dns-dnssec-public-only | stable | Does Azure DNS support DNSSEC on private DNS zones, or only on public zones? Answer in one sentence. | regex: `(?i)(public|not.{0,20}private)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.6s | 212 | $1.3432 | $0.2239 |
| no-skill | 9 | **33.3%** | 4.9s | 46 | $0.1558 | $0.0519 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 6.6s | 4.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.2s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 100% | 9s | $0.2239 |
| claude-opus-5 | no-skill | 50% | 5.4s | $0.0519 |

_Full per-cell aggregates (harness × model × effort × mode) in `azure-dns-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
