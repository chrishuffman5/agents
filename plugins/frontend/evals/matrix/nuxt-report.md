# nuxt — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `frontend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nuxt-server-route-method-source | stable | In Nuxt, for a server handler file like hello.post.ts under the server api directory, what part of the filename tells Nitro which HTTP method to register? Answer concisely. | regex: `(?i)suffix` |
| nuxt-v4-shallowref-default | recent | In Nuxt 4, what does the framework use as the default ref behavior in place of the deep reactive refs from Nuxt 3? Answer concisely. | contains_all: `shallowRef` |
| nuxt-nitro-hosting-targets | recent | Roughly how many hosting targets can a Nuxt Nitro build output be deployed to? Answer concisely. | contains_all: `15` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 7.1s | 358 | $0.968 | $0.1613 |
| no-skill | 9 | **33.3%** | 4.5s | 152 | $0.1774 | $0.0591 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 7.1s | 4.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.1s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.4s | rates n/c |
| claude-opus-5 | skill | 100% | 11s | $0.1613 |
| claude-opus-5 | no-skill | 50% | 5s | $0.0591 |

_Full per-cell aggregates (harness × model × effort × mode) in `nuxt-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
