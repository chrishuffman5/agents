# claude-code — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `claude-code-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
