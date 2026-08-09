# suricata — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| suricata-failopen-nfq | recent | In a Suricata inline IPS deployment, which suricata.yaml NFQ setting should always be enabled so a Suricata crash or overload does not cause a full network outage? Answer concisely. | contains_all: `fail-open` |
| suricata-file-extraction-hash | stable | What hash algorithm does Suricata use to name files saved through its file-extraction feature, enabling automated malware hash lookups? Answer concisely. | contains_all: `SHA256` |
| suricata-dhcp-version | recent | Starting in which major Suricata version does the DHCP event type get added to EVE JSON logging? Answer concisely. | regex: `(?i)\b8(\.0)?\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 6.3s | 252 | $0.5686 | $0.2843 |
| no-skill | 9 | **22.2%** | 5.2s | 141 | $0.1759 | $0.088 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 6.3s | 5.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.3s | rates n/c |
| claude-opus-5 | skill | 33.3% | 6.9s | $0.2843 |
| claude-opus-5 | no-skill | 33.3% | 5.6s | $0.088 |

_Full per-cell aggregates (harness × model × effort × mode) in `suricata-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
