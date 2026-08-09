# coredns — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| coredns-nodelocal-ip | recent | What link-local IP address does Kubernetes NodeLocal DNSCache use for its per-node cache listener? Answer concisely. | contains_all: `169.254.20.10` |
| coredns-113-doh3 | recent | Which experimental encrypted DNS transport, layered over QUIC and HTTP/3, did CoreDNS 1.13 add support for? Answer concisely. | regex: `(?i)(doh3|http/?3)` |
| coredns-default-since | stable | Since which Kubernetes version has CoreDNS been the default cluster DNS server, replacing kube-dns? Answer concisely. | contains_all: `1.13` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 8.5s | 394 | $1.3039 | $0.2608 |
| no-skill | 9 | **22.2%** | 4.4s | 60 | $0.1703 | $0.0852 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 22.2% | +19.5pp | 8.5s | 4.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.9s | rates n/c |
| claude-opus-5 | skill | 83.3% | 13.2s | $0.2608 |
| claude-opus-5 | no-skill | 33.3% | 4.6s | $0.0852 |

_Full per-cell aggregates (harness × model × effort × mode) in `coredns-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
