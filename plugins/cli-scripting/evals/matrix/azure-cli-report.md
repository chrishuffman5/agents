# azure-cli — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `cli-scripting` · runs: **256 / 256**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| azurecli-config-dir-env | recent | Which environment variable can be set to override the directory where the Azure CLI stores its token cache, configuration, and profile? Answer concisely. | contains_all: `AZURE_CONFIG_DIR` |
| azurecli-nsg-persistent | recent | Unlike Linux firewalld rules, do Azure Network Security Group rules created through the Azure CLI need an extra step to persist across restarts, or are they persistent by default? Answer in one sentence. | regex: `(?i)\bpersistent\b` |
| azurecli-device-code-login | stable | Which az login flag lets you authenticate from a headless machine or over an SSH session by printing a code to enter in a browser on another device? Answer with the exact flag. | contains_all: `--use-device-code` |
| azurecli-no-wait-flag | stable | Which global Azure CLI flag lets a long-running operation such as VM creation or resource group deletion return immediately instead of blocking until it finishes? Answer with the exact flag. | contains_all: `--no-wait` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 128 | **85.9%** | 11.6s | 230 | $7.1098 | $0.0646 |
| no-skill | 128 | **87.5%** | 10.5s | 119 | $4.1851 | $0.0374 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 90.4% | 96.2% | +-5.8pp | 13.5s | 11s |
| codex | 98.1% | 96.2% | +1.9pp | 11.6s | 8.1s |
| pi | 50% | 50% | +0pp | 7.4s | 14.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 9.2s | $0.0231 |
| claude-haiku-4-5 | no-skill | 100% | 8.1s | $0.015 |
| claude-opus-5 | skill | 100% | 7.8s | $0.1248 |
| claude-opus-5 | no-skill | 100% | 5.5s | $0.0548 |
| claude-sonnet-5 | skill | 83.3% | 5.1s | $0.099 |
| claude-sonnet-5 | no-skill | 83.3% | 4.6s | $0.063 |
| gemma4:12b | skill | 93.8% | 21.5s | $0.0864 |
| gemma4:12b | no-skill | 100% | 20s | $0.0725 |
| glm-4.7-flash:q4_K_M-32k | skill | 81.2% | 11.7s | $0.1545 |
| glm-4.7-flash:q4_K_M-32k | no-skill | 87.5% | 9s | $0.0842 |
| gpt-5.6-luna | skill | 100% | 17.9s | $0.0023 |
| gpt-5.6-luna | no-skill | 100% | 6.6s | $0.0008 |
| gpt-5.6-sol | skill | 100% | 14.3s | $0.066 |
| gpt-5.6-sol | no-skill | 100% | 7.8s | $0.0229 |
| gpt-5.6-terra | skill | 100% | 10.1s | $0.0186 |
| gpt-5.6-terra | no-skill | 100% | 11.6s | $0.0078 |
| ollama/gemma4:12b | skill | 50% | 5.9s | $0 |
| ollama/gemma4:12b | no-skill | 50% | 6.1s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | skill | 50% | 2.3s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | no-skill | 50% | 2.6s | $0 |
| ollama/qwen3.6:27b | skill | 50% | 14.1s | $0 |
| ollama/qwen3.6:27b | no-skill | 50% | 35.6s | $0 |

_Full per-cell aggregates (harness × model × effort × mode) in `azure-cli-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
