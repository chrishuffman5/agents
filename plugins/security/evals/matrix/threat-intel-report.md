# threat-intel — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| threat-intel-pyramid-of-pain-top | stable | In David Bianco's Pyramid of Pain, which indicator category sits at the very top as hardest for attackers to change and most valuable for defenders to detect. Answer concisely. | regex: `(?i)\bTTPs?\b` |
| threat-intel-tlp2-changes | recent | Under TLP 2.0, what did the old marking TLP:WHITE get renamed to, and what new marking level was added between TLP:AMBER and TLP:RED? Answer concisely with both terms. | contains_all: `CLEAR``, ``AMBER+STRICT` |
| threat-intel-kill-chain-stages | stable | How many stages does the Lockheed Martin Cyber Kill Chain have, from reconnaissance through actions on objectives? Answer concisely with the number. | regex: `(?i)\b(seven|7)\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.4s | 59 | $0.5551 | $0.185 |
| no-skill | 9 | **33.3%** | 4.8s | 41 | $0.1559 | $0.052 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 5.4s | 4.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5s | rates n/c |
| claude-opus-5 | skill | 50% | 6.3s | $0.185 |
| claude-opus-5 | no-skill | 50% | 4.7s | $0.052 |

_Full per-cell aggregates (harness × model × effort × mode) in `threat-intel-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
