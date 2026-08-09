# aws-cli — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `cli-scripting` · runs: **390 / 390**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| awscli-login-version | recent | The AWS CLI has an 'aws login' command that signs you in using AWS console credentials through a browser flow. What minimum AWS CLI version introduced this command? Answer concisely. | contains_all: `2.32` |
| awscli-role-chaining | stable | When you use the AWS CLI to assume an IAM role from credentials that themselves came from an assumed role (role chaining), what is the maximum session duration of the chained session, regardless of what you pass to --duration-seconds? Answer concisely. | regex: `(?i)(1\s*hour|one\s*hour|3,?600)` |
| awscli-presign-max | stable | What is the maximum expiration time you can set on a presigned URL generated with 'aws s3 presign'? Answer concisely. | regex: `(?i)(604,?800|7\s*days|seven\s*days|one\s*week|1\s*week)` |
| awscli-text-none | recent | Using the AWS CLI with --output text, if your --query expression names a key that is absent or null in the response, what exact literal string does the CLI print for that value? Answer concisely. | contains_all: `None` |
| awscli-sso-logout | recent | With the AWS CLI, can 'aws sso logout' sign you out of a single named profile's SSO session only? Explain in one sentence what it actually does. | regex: `(?i)\ball\b` |
| awscli-cred-precedence | stable | In the AWS CLI v2 credential resolution order, which source wins when both are present: credentials set in environment variables, or credentials in the ~/.aws/credentials file? Answer concisely. | regex: `(?i)environment` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 198 | **77.8%** | 21.4s | 428 | $14.42 | $0.0936 |
| no-skill | 192 | **71.4%** | 14.2s | 388 | $9.5129 | $0.0694 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 85.7% | 71.8% | +13.9pp | 23.3s | 13.7s |
| codex | 89.7% | 83.3% | +6.4pp | 15.4s | 13.7s |
| pi | 33.3% | 44.4% | +-11.1pp | 29.8s | 16.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 94.4% | 11.6s | $0.0327 |
| claude-haiku-4-5 | no-skill | 66.7% | 7.9s | $0.0283 |
| claude-opus-5 | skill | 94.4% | 13.1s | $0.1879 |
| claude-opus-5 | no-skill | 83.3% | 9.3s | $0.116 |
| claude-sonnet-5 | skill | 83.3% | 7s | $0.1054 |
| claude-sonnet-5 | no-skill | 77.8% | 5.5s | $0.065 |
| gemma4:12b | skill | 58.3% | 33.7s | $0.1348 |
| gemma4:12b | no-skill | 45.8% | 39.2s | $0.2415 |
| glm-4.7-flash:q4_K_M-32k | skill | 79.2% | 15s | $0.1722 |
| glm-4.7-flash:q4_K_M-32k | no-skill | 62.5% | 12.5s | $0.1621 |
| gpt-5.6-luna | skill | 100% | 10.4s | $0.0037 |
| gpt-5.6-luna | no-skill | 100% | 8.1s | $0.0014 |
| gpt-5.6-sol | skill | 100% | 17.4s | $0.1087 |
| gpt-5.6-sol | no-skill | 100% | 10.8s | $0.0602 |
| gpt-5.6-terra | skill | 100% | 9.3s | $0.0252 |
| gpt-5.6-terra | no-skill | 100% | 8s | $0.0181 |
| ollama/gemma4:12b | skill | 33.3% | 6.7s | $0 |
| ollama/gemma4:12b | no-skill | 41.7% | 8s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | skill | 33.3% | 6.4s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | no-skill | 50% | 7s | $0 |
| ollama/qwen3.6:27b | skill | 33.3% | 76.4s | $0 |
| ollama/qwen3.6:27b | no-skill | 41.7% | 33.3s | $0 |
| qwen3.6:27b | skill | 100% | 125.8s | $0.242 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-cli-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
