# pfsense — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| pfsense-carp-min-ips | recent | In a pfSense CARP high-availability pair, what is the minimum number of IP addresses needed per interface once you count both physical nodes and the shared virtual IP? Answer concisely. | regex: `(?i)(\bthree\b|\b3\b)` |
| pfsense-altq-limitation | recent | Does pfSense's legacy ALTQ traffic shaping framework work with modern multi-queue network interface cards? Answer in one sentence. | regex: `(?i)(\bno\b|does not)` |
| pfsense-freebsd-base | stable | What open-source operating system does pfSense build on, using its pf engine as the underlying firewall? Answer concisely. | contains_all: `FreeBSD` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.9s | 247 | $1.2638 | $0.2106 |
| no-skill | 9 | **33.3%** | 4.6s | 62 | $0.1637 | $0.0546 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 6.9s | 4.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.9s | rates n/c |
| claude-opus-5 | skill | 100% | 9.3s | $0.2106 |
| claude-opus-5 | no-skill | 50% | 4.9s | $0.0546 |

_Full per-cell aggregates (harness × model × effort × mode) in `pfsense-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
