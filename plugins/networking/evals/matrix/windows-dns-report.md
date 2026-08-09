# windows-dns — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 7.4s | 395 | $0.6735 | $0.3368 |
| no-skill | 9 | **11.1%** | 6s | 328 | $0.2176 | $0.2176 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 7.4s | 6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.5s | rates n/c |
| claude-opus-5 | skill | 33.3% | 9.9s | $0.3368 |
| claude-opus-5 | no-skill | 16.7% | 6.8s | $0.2176 |

_Full per-cell aggregates (harness × model × effort × mode) in `windows-dns-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
