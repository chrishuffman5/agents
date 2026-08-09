# dns — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dns-bind-dot-version | recent | Starting with which version does BIND include a built-in DNS-over-TLS server? Answer concisely. | contains_all: `9.18` |
| dns-windows-doh-year | recent | In which year did Windows Server DNS gain a DNS-over-HTTPS server capability, currently in preview? Answer concisely. | contains_all: `2025` |
| dns-single-server-risk | stable | For production DNS redundancy, is it acceptable to run just a single authoritative DNS server for a zone? Answer in one sentence. | regex: `(?i)\bno\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 8s | 353 | $1.3689 | $0.2738 |
| no-skill | 9 | **22.2%** | 4.4s | 67 | $0.1569 | $0.0785 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 22.2% | +19.5pp | 8s | 4.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.8s | rates n/c |
| claude-opus-5 | skill | 83.3% | 12.8s | $0.2738 |
| claude-opus-5 | no-skill | 33.3% | 5.1s | $0.0785 |

_Full per-cell aggregates (harness × model × effort × mode) in `dns-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
