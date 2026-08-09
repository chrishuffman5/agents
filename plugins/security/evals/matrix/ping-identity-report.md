# ping-identity — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ping-identity-ports | recent | In a typical PingFederate deployment diagram, what two TCP ports are shown for the federation runtime versus the administrative console? Answer concisely with both port numbers. | contains_all: `9031``, ``9999` |
| ping-identity-davinci-connectors | recent | Roughly how many connectors does Ping Identity's DaVinci no-code orchestration platform offer for building identity journeys? Answer concisely. | regex: `(?i)200\+?` |
| ping-identity-protocols | stable | Name at least three of the federation and authorization protocols that PingFederate supports out of the box. Answer concisely. | contains_all: `SAML 2.0``, ``OIDC``, ``OAuth 2.0` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `ping-identity-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
