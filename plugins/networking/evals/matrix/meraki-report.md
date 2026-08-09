# meraki — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| meraki-action-batch-limits | recent | When using Meraki Dashboard action batches for bulk API operations, how many actions can a single batch contain when run synchronously, and how many when run asynchronously? Answer concisely with both numbers. | regex: `(?i)(?=.*\b100\b)(?=.*\b1000\b)` |
| meraki-license-grace | recent | If a Cisco Meraki organization's licenses expire and are not renewed, how many days pass before the devices become non-functional? Answer concisely. | regex: `(?i)(30\s*days|thirty\s*days)` |
| meraki-autovpn-protocol | stable | What VPN protocol suite does Cisco Meraki AutoVPN use to automatically build tunnels between MX security appliances? Answer concisely. | regex: `(?i)ipsec` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `meraki-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
