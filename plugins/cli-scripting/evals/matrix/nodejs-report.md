# nodejs — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `cli-scripting` · runs: **144 / 288** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nodejs-temporal-default | recent | Starting with which Node.js version does the Temporal global date and time API become enabled by default without needing an experimental flag? Answer with just the version number. | regex: `\b26\b` |
| nodejs-module-version-147 | recent | In Node.js 26, native addons like better-sqlite3 must be rebuilt after upgrading because NODE_MODULE_VERSION was bumped to what number? Answer with just the number. | regex: `\b147\b` |
| nodejs-sqlite-builtin | stable | Which Node.js built-in module, stabilized in Node 24, provides a synchronous SQLite database API without needing a third-party package like better-sqlite3? Answer with the module's exact name. | contains_all: `node:sqlite` |
| nodejs-watch-flag | stable | Since Node.js 20, which built-in command-line flag automatically restarts your script whenever a watched file changes, removing the need for a tool like nodemon? Answer with the exact flag. | contains_all: `--watch` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 72 | **83.3%** | 12.4s | 288 | $4.5876 | $0.0765 |
| no-skill | 72 | **66.7%** | 10.1s | 195 | $2.6463 | $0.0551 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 69.4% | 50% | +19.4pp | 12.3s | 10.4s |
| codex | 97.2% | 83.3% | +13.9pp | 12.6s | 9.8s |

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
| gpt-5.6-luna | skill | 91.7% | 13.4s | $0.003 |
| gpt-5.6-luna | no-skill | 83.3% | 9.9s | $0.0017 |
| gpt-5.6-sol | skill | 100% | 12.9s | $0.0617 |
| gpt-5.6-sol | no-skill | 83.3% | 8.5s | $0.0542 |
| gpt-5.6-terra | skill | 100% | 11.4s | $0.021 |
| gpt-5.6-terra | no-skill | 83.3% | 11.2s | $0.0194 |

_Full per-cell aggregates (harness × model × effort × mode) in `nodejs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
