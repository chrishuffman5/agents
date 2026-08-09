# nodejs — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `cli-scripting` · runs: **256 / 256**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nodejs-temporal-default | recent | Starting with which Node.js version does the Temporal global date and time API become enabled by default without needing an experimental flag? Answer with just the version number. | regex: `(?i)\b26\b` |
| nodejs-module-version-147 | recent | In Node.js 26, native addons like better-sqlite3 must be rebuilt after upgrading because NODE_MODULE_VERSION was bumped to what number? Answer with just the number. | regex: `(?i)\b147\b` |
| nodejs-sqlite-builtin | stable | Which Node.js built-in module, stabilized in Node 24, provides a synchronous SQLite database API without needing a third-party package like better-sqlite3? Answer with the module's exact name. | contains_all: `node:sqlite` |
| nodejs-watch-flag | stable | Since Node.js 20, which built-in command-line flag automatically restarts your script whenever a watched file changes, removing the need for a tool like nodemon? Answer with the exact flag. | contains_all: `--watch` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 128 | **62.5%** | 22.6s | 646 | $12.3708 | $0.1546 |
| no-skill | 128 | **57.8%** | 23.1s | 684 | $7.5031 | $0.1014 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 57.7% | 50% | +7.7pp | 24.4s | 18.2s |
| codex | 80.8% | 73.1% | +7.7pp | 21.3s | 26.1s |
| pi | 33.3% | 41.7% | +-8.4pp | 21.8s | 27.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 25% | 18.1s | $0.1238 |
| claude-haiku-4-5 | no-skill | 33.3% | 10.7s | $0.0597 |
| claude-opus-5 | skill | 100% | 11.9s | $0.1653 |
| claude-opus-5 | no-skill | 58.3% | 15.5s | $0.1427 |
| claude-sonnet-5 | skill | 83.3% | 7s | $0.1207 |
| claude-sonnet-5 | no-skill | 58.3% | 5.1s | $0.0938 |
| gemma4:12b | skill | 37.5% | 54.2s | $0.2994 |
| gemma4:12b | no-skill | 43.8% | 78.5s | $0.2571 |
| glm-4.7-flash:q4_K_M-32k | skill | 37.5% | 38.2s | $0.9978 |
| glm-4.7-flash:q4_K_M-32k | no-skill | 56.2% | 19.8s | $0.3396 |
| gpt-5.6-luna | skill | 91.7% | 13.4s | $0.003 |
| gpt-5.6-luna | no-skill | 83.3% | 9.9s | $0.0017 |
| gpt-5.6-sol | skill | 100% | 12.9s | $0.0617 |
| gpt-5.6-sol | no-skill | 83.3% | 8.5s | $0.0542 |
| gpt-5.6-terra | skill | 100% | 11.4s | $0.021 |
| gpt-5.6-terra | no-skill | 83.3% | 11.2s | $0.0194 |
| ollama/gemma4:12b | skill | 37.5% | 11.5s | $0 |
| ollama/gemma4:12b | no-skill | 50% | 24.3s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | skill | 37.5% | 17.6s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | no-skill | 25% | 4.3s | $0 |
| ollama/qwen3.6:27b | skill | 25% | 36.3s | $0 |
| ollama/qwen3.6:27b | no-skill | 50% | 53.1s | $0 |

_Full per-cell aggregates (harness × model × effort × mode) in `nodejs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
