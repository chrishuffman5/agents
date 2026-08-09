# astro — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `frontend` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| astro-client-visible-directive | stable | In Astro, which client hydration directive waits until the component scrolls into the viewport before hydrating it? Answer concisely. | contains_all: `client:visible` |
| astro-v5-content-config-path | recent | In Astro 5, at what file path do you define content collection configuration, replacing the old version 4 location? Answer concisely. | contains_all: `content.config.ts` |
| astro-server-islands-key | recent | For Astro Server Islands, what environment variable name should you set to keep prop encryption stable across separate deployments? Answer concisely. | contains_all: `ASTRO_KEY` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 7.7s | 256 | $0.8964 | $0.1494 |
| no-skill | 12 | **41.7%** | 6.3s | 155 | $0.2075 | $0.0415 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 41.7% | +8.3pp | 7.7s | 6.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 33.3% | 7.4s | $0.0257 |
| claude-opus-5 | skill | 100% | 10.8s | $0.1494 |
| claude-opus-5 | no-skill | 50% | 5.2s | $0.052 |

_Full per-cell aggregates (harness × model × effort × mode) in `astro-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
