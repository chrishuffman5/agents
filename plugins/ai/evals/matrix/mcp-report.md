# mcp — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| mcp-current-spec-revision | recent | As of current guidance, what is the latest stable Model Context Protocol specification revision date? Answer concisely. | contains_all: `2025-11-25` |
| mcp-protocol-version-fallback | stable | If an MCP client sends no MCP-Protocol-Version header on a post-initialization HTTP request, which protocol version should the server assume? Answer concisely. | contains_all: `2025-03-26` |
| mcp-elicitation-form-mode-rule | stable | In MCP's elicitation form mode, what kinds of information must a server never request from the user, such as passwords or access tokens? Answer concisely. | regex: `(?i)(password|credential|payment)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `mcp-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
