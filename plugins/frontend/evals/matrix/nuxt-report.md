# nuxt — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `frontend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `nuxt-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
