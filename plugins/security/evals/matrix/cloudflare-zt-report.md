# cloudflare-zt — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cloudflare-zt-free-tier-users | recent | How many users does the free tier of Cloudflare Zero Trust support with full Access and Gateway functionality? Answer concisely. | regex: `(?i)\b50\b` |
| cloudflare-zt-area1-acquisition-year | recent | In what year did Cloudflare acquire Area 1 Security, which became its email security product? Answer concisely. | regex: `(?i)\b2022\b` |
| cloudflare-zt-anycast-cities | stable | Approximately how many cities does Cloudflare's anycast network span? Answer concisely. | regex: `(?i)300\+?` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 4.2s | 36 | $0.5467 | $0.1822 |
| no-skill | 9 | **22.2%** | 5.9s | 53 | $0.1629 | $0.0814 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 4.2s | 5.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.7s | rates n/c |
| claude-opus-5 | skill | 50% | 4s | $0.1822 |
| claude-opus-5 | no-skill | 33.3% | 6.4s | $0.0814 |

_Full per-cell aggregates (harness × model × effort × mode) in `cloudflare-zt-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
