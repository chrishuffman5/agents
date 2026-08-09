# spring-boot — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `backend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| spring-boot-mockitobean | recent | In Spring Boot 4.0, which annotation replaces the removed MockBean annotation for mocking beans in tests? Answer concisely. | contains_all: `MockitoBean` |
| spring-boot-undertow-removed | recent | Spring Boot 4.0 dropped support for one embedded servlet container because it lacks Servlet 6.1 support. Which server was removed? Answer concisely. | contains_all: `Undertow` |
| spring-boot-property-priority | stable | In Spring Boot's configuration property resolution order, which takes precedence when both are set: command line arguments or environment variables? Answer concisely. | regex: `(?i)command.?line` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `spring-boot-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
