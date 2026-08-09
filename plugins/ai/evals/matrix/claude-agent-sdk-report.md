# claude-agent-sdk — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| claude-agent-sdk-node-python-min | stable | What are the minimum Node.js and Python versions required to use the Claude Agent SDK? Answer concisely. | contains_all: `18``, ``3.10` |
| claude-agent-sdk-v2-session-removed | recent | The experimental V2 session API in the Claude Agent SDK, using createSession with send and stream, was removed as of which TypeScript SDK version? Answer concisely. | contains_all: `0.3.142` |
| claude-agent-sdk-capacity-disk | recent | When capacity planning to host Claude Agent SDK sessions, what starting resource allocation per agent is recommended for RAM, disk, and CPU? Answer concisely. | regex: `(?i)1\s*gi?b.{0,40}5\s*gi?b.{0,40}1\s*cpu` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `claude-agent-sdk-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
