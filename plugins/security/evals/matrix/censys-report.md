# censys — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| censys-zmap-scan-time | recent | Roughly how long does it take for ZMap, the high-speed scanner developed at Censys, to scan the entire IPv4 address space? Answer concisely. | regex: `(?i)45\s*min` |
| censys-ipv4-address-count | stable | Approximately how many IPv4 addresses does Censys index through its internet-wide scanning? Answer concisely. | regex: `(?i)4\.3\s*(billion|bn)` |
| censys-asm-onboarding-time | recent | After providing seeds during Censys ASM onboarding, how long does it typically take before initial results are available? Answer concisely. | regex: `4\D{1,5}8\s*hours` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `censys-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
