# asm — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| asm-internet-scan-tools | stable | Which three internet-wide scanning data providers are named as indexing the entire internet daily, providing data that EASM tools leverage or replicate? Answer concisely. | contains_all: `Shodan``, ``Censys``, ``FOFA` |
| asm-crtsh | recent | Which certificate transparency log lookup site is named as a source for enumerating subdomains during external attack surface discovery? Answer concisely. | contains_all: `crt.sh` |
| asm-vm-integration-tools | stable | In the EASM-to-VM workflow, which three named vulnerability scanners does a newly discovered exposed host commonly get added to for credentialed scanning? Answer concisely. | contains_all: `Tenable``, ``Qualys``, ``Rapid7` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `asm-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
