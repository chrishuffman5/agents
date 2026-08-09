# plugins — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| plugins-version-resolution-order | stable | In Claude Code plugin versioning, if both plugin.json and the marketplace entry declare a version, which one takes effect? Answer concisely. | contains_all: `plugin.json` |
| plugins-renames-min-version | recent | What is the minimum Claude Code version required for the marketplace.json renames field to actually take effect? Answer concisely. | contains_all: `2.1.193` |
| plugins-strict-marketplaces-lockdown | stable | In Claude Code managed settings, what value of strictKnownMarketplaces produces total lockdown, blocking even the official marketplace from being added? Answer concisely. | regex: `(?i)(empty\s*array|empty\s*list|\[\s*\])` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 30.9s | 482 | $2.3631 | $0.2148 |
| no-skill | 12 | **41.7%** | 22.4s | 924 | $0.8789 | $0.1758 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 41.7% | +50pp | 30.9s | 22.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 51.1s | $0.1257 |
| claude-haiku-4-5 | no-skill | 33.3% | 11s | $0.0549 |
| claude-opus-5 | skill | 100% | 10.7s | $0.2891 |
| claude-opus-5 | no-skill | 50% | 33.8s | $0.2564 |

_Full per-cell aggregates (harness × model × effort × mode) in `plugins-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
