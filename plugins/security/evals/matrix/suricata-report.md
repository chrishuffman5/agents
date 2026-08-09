# suricata — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `suricata-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
