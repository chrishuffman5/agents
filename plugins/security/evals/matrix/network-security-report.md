# network-security — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| network-security-encrypted-traffic-share | stable | Roughly what percentage of traffic on a modern enterprise network is TLS encrypted, according to typical network security guidance on visibility challenges? Answer concisely with the range. | contains_all: `80``, ``95` |
| network-security-ja3-fingerprinting | recent | What TLS client fingerprinting technique, supported by Suricata, lets analysts identify malware command-and-control traffic without decrypting the TLS session? Answer concisely. | contains_all: `JA3` |
| network-security-af-packet-capture | recent | Which high-throughput, NIC-bypassing packet capture method used for high-throughput Suricata deployments is available only on Linux? Answer concisely. | contains_all: `AF_PACKET` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.1s | 151 | $0.5574 | $0.1858 |
| no-skill | 9 | **33.3%** | 6.2s | 227 | $0.1764 | $0.0588 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 5.1s | 6.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.5s | rates n/c |
| claude-opus-5 | skill | 50% | 5.2s | $0.1858 |
| claude-opus-5 | no-skill | 50% | 7.1s | $0.0588 |

_Full per-cell aggregates (harness × model × effort × mode) in `network-security-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
