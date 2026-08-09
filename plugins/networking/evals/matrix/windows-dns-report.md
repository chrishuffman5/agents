# windows-dns — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| windows-dns-scavenge-days | recent | With default Windows DNS Server aging and scavenging settings, how many total days pass before a stale dynamically-registered record becomes eligible for scavenging? Answer concisely. | regex: `(?i)\b14\b` |
| windows-dns-doh-kb | recent | Which Microsoft KB update introduced public-preview server-side DNS-over-HTTPS support for the Windows Server 2025 DNS Server role? Answer concisely. | contains_all: `KB5075899` |
| windows-dns-policies-gui | stable | Can Windows DNS Policies, introduced in Server 2016, be configured through the graphical DNS Manager console, or only via PowerShell? Answer in one sentence. | regex: `(?i)(powershell.{0,30}only|only.{0,20}powershell|no gui|not.{0,20}gui)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `windows-dns-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
