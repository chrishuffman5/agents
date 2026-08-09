# nginx — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nginx-ingress-retirement | recent | Is the community ingress-nginx Kubernetes Ingress Controller project still actively maintained, or was it retired? Answer in one sentence. | regex: `(?i)retir` |
| nginx-plus-r35-api-version | recent | NGINX Plus R35 shipped an updated version of its live activity monitoring REST API. What API version number does R35 introduce? Answer concisely. | regex: `(?i)(version\s*9|\bv9\b)` |
| nginx-keepalive-per-worker | stable | In an NGINX upstream block, does the keepalive directive set the maximum idle keepalive connections for the whole server, or per worker process? Answer concisely. | regex: `(?i)per\s*worker` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `nginx-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
