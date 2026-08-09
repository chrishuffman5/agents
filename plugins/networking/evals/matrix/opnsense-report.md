# opnsense — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| opnsense-suricata-inline-version | recent | Starting in which OPNsense release did Suricata gain true inline IPS mode using FreeBSD divert sockets, letting it drop and modify packets instead of only alerting? Answer concisely. | contains_all: `26.1` |
| opnsense-hostwatch-default | recent | Is OPNsense's passive host discovery feature, hostwatch, enabled by default in version 26.1? Answer in one sentence. | regex: `(?i)(\byes\b|enabled by default)` |
| opnsense-hardenedbsd-base | stable | What security-hardened FreeBSD fork serves as the base operating system for OPNsense? Answer concisely. | contains_all: `HardenedBSD` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 10.6s | 763 | $1.456 | $0.2912 |
| no-skill | 9 | **11.1%** | 5.4s | 156 | $0.1777 | $0.1777 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 11.1% | +30.6pp | 10.6s | 5.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.7s | rates n/c |
| claude-opus-5 | skill | 83.3% | 15.9s | $0.2912 |
| claude-opus-5 | no-skill | 16.7% | 6.3s | $0.1777 |

_Full per-cell aggregates (harness × model × effort × mode) in `opnsense-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
