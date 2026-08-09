# claude-code — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| claude-code-auth-precedence | stable | In Claude Code's authentication precedence order, which one wins when both an ANTHROPIC_AUTH_TOKEN and an ANTHROPIC_API_KEY are set in the environment? Answer concisely. | regex: `(?i)AUTH_TOKEN` |
| claude-code-oauth-token-lifetime | recent | For CI use, how long is the token minted by claude setup-token valid for? Answer concisely. | regex: `(?i)(one.year|1.year|12.month)` |
| claude-code-mcp-output-limits | recent | In Claude Code, at what token count does MCP tool output trigger a warning, and at what token count does it get truncated? Answer concisely with both numbers. | regex: `(?i)10,?000.{0,60}25,?000` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **58.3%** | 38s | 870 | $2.455 | $0.3507 |
| no-skill | 12 | **50%** | 9.2s | 423 | $0.5058 | $0.0843 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 58.3% | 50% | +8.3pp | 38s | 9.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 41.8s | $0.181 |
| claude-haiku-4-5 | no-skill | 16.7% | 8.8s | $0.0965 |
| claude-opus-5 | skill | 83.3% | 34.1s | $0.4186 |
| claude-opus-5 | no-skill | 83.3% | 9.6s | $0.0819 |

_Full per-cell aggregates (harness × model × effort × mode) in `claude-code-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
