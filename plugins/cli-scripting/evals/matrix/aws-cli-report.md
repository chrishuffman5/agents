# aws-cli — cross-harness eval report

Generated: 2026-08-08T21:50:18.3314216-05:00 · plugin: `cli-scripting` · runs: **3 / 576** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 3 | **66.7%** | 59s | 2857 | $0.196 | $0.098 |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | — | — | 10.6s | — |
| codex | 50% | — | — | 83.2s | — |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 10.6s | $0.196 |
| gemma4:12b | skill | 50% | 83.2s | $0 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-cli-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
