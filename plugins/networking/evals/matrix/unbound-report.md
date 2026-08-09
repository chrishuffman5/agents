# unbound — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| unbound-doh-version | recent | What is the minimum Unbound version required to run as an incoming DNS-over-HTTPS (DoH) server? Answer concisely. | contains_all: `1.17` |
| unbound-pihole-port | recent | When running Unbound alongside Pi-hole on the same box, what non-standard port should Unbound listen on so it does not conflict with Pi-hole's use of port 53? Answer concisely. | contains_all: `5335` |
| unbound-rrset-cache-ratio | stable | In Unbound performance tuning, roughly how many times larger than msg-cache-size should you set rrset-cache-size? Answer concisely. | regex: `(?i)(2x|two\s*times|twice|double)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.6s | 190 | $0.6312 | $0.2104 |
| no-skill | 9 | **11.1%** | 4.8s | 121 | $0.1681 | $0.1681 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 11.1% | +13.9pp | 5.6s | 4.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.2s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.3s | rates n/c |
| claude-opus-5 | skill | 50% | 7.1s | $0.2104 |
| claude-opus-5 | no-skill | 16.7% | 5.5s | $0.1681 |

_Full per-cell aggregates (harness × model × effort × mode) in `unbound-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
