# cloudflare-dns — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cloudflare-dns-secondary-xfer-speed | recent | For Cloudflare Secondary DNS, roughly how fast does a zone transfer complete at the P99 percentile? Answer concisely. | regex: `(?i)800\s*ms` |
| cloudflare-dns-families-ip | recent | For Cloudflare's 1.1.1.1 for Families resolver, which IPv4 address blocks both malware and adult content, as opposed to malware only? Answer concisely. | contains_all: `1.1.1.3` |
| cloudflare-dns-proxied-ttl | stable | When a DNS record is proxied, orange cloud, through Cloudflare, what TTL value does it display regardless of the value you configured? Answer concisely. | contains_all: `300` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cloudflare-dns-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
