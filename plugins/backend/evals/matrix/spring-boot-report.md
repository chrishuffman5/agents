# spring-boot — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `backend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **50%** | 7.2s | 348 | $0.9571 | $0.1595 |
| no-skill | 9 | **33.3%** | 5.6s | 104 | $0.1668 | $0.0556 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 7.2s | 5.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.5s | rates n/c |
| claude-opus-5 | skill | 100% | 10.7s | $0.1595 |
| claude-opus-5 | no-skill | 50% | 6.1s | $0.0556 |

_Full per-cell aggregates (harness × model × effort × mode) in `spring-boot-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
