# asm — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **25%** | 5.9s | 253 | $0.683 | $0.2277 |
| no-skill | 9 | **22.2%** | 4.7s | 58 | $0.1696 | $0.0848 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 5.9s | 4.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.3s | rates n/c |
| claude-opus-5 | skill | 50% | 8.4s | $0.2277 |
| claude-opus-5 | no-skill | 33.3% | 4.9s | $0.0848 |

_Full per-cell aggregates (harness × model × effort × mode) in `asm-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
