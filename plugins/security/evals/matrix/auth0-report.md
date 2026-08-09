# auth0 — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| auth0-mgmt-api-rate-limit | stable | What is the Auth0 Management API rate limit, in requests per second, that you should plan bulk operations around? Answer concisely. | regex: `(?i)\b50\b` |
| auth0-fga-basis | recent | Auth0 Fine-Grained Authorization, known as Okta FGA, is based on which open source project and which Google authorization model, respectively? Answer concisely. | contains_all: `OpenFGA``, ``Zanzibar` |
| auth0-log-code-limit-wc | recent | In Auth0 tenant logs, which short event code indicates an account was blocked specifically because too many failed logins occurred for that account, as distinct from an IP-based block? Answer concisely. | contains_all: `limit_wc` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `auth0-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
