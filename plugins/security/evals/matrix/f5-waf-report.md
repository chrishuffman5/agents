# f5-waf — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| f5-waf-signature-count | recent | Approximately how many attack signatures does the F5 Advanced WAF signature library include? Answer concisely. | regex: `(?i)9,?000\+?` |
| f5-waf-datasafe-encryption | recent | What encryption algorithm and key size does F5 DataSafe use to generate its per-session key when encrypting form field values in the browser? Answer concisely. | regex: `(?i)rsa-?\s*2048` |
| f5-waf-positive-security-model | stable | Does F5 Advanced WAF's positive security model work as an allowlist that denies everything not explicitly defined, or as a blocklist that only denies known bad patterns? Answer concisely, naming the model type it actually is. | regex: `(?i)allow-?list` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 7.1s | 327 | $0.7335 | $0.2445 |
| no-skill | 9 | **11.1%** | 5.1s | 193 | $0.1731 | $0.1731 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 11.1% | +13.9pp | 7.1s | 5.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.7s | rates n/c |
| claude-opus-5 | skill | 50% | 10.5s | $0.2445 |
| claude-opus-5 | no-skill | 16.7% | 5.8s | $0.1731 |

_Full per-cell aggregates (harness × model × effort × mode) in `f5-waf-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
