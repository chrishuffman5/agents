# azure — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `cloud-platforms` · runs: **256 / 256**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| azure-firewall-idle-cost | recent | In a hub and spoke Azure network design, if you deploy Azure Firewall Standard and it sits completely idle with zero traffic, does it still generate a bill, and roughly how much per month in dollars? Answer concisely. | regex: `(?i)\b912\b` |
| azure-cobalt-arm | recent | Microsoft's new Arm based Azure VM series such as Dpsv6 runs on a custom Microsoft designed processor. What is that processor called? Answer concisely. | contains_all: `Cobalt 100` |
| azure-aks-standard-sla | stable | When you choose the Standard pricing tier for the Azure Kubernetes Service control plane instead of the Free tier, what SLA percentage does Microsoft guarantee when the cluster spans availability zones? Answer concisely. | contains_all: `99.95` |
| azure-entra-p1-conditional-access | stable | Which tier of Microsoft Entra ID licensing is the minimum required to enable Conditional Access policies, such as requiring multi factor authentication from untrusted networks? Answer concisely. | regex: `(?i)\bP1\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 128 | **68.8%** | 15.8s | 372 | $9.684 | $0.11 |
| no-skill | 128 | **58.6%** | 12.9s | 224 | $5.1689 | $0.0689 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 78.8% | 65.4% | +13.4pp | 17s | 12.1s |
| codex | 75% | 63.5% | +11.5pp | 15s | 10.6s |
| pi | 33.3% | 33.3% | +0pp | 15.2s | 19.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 14.7s | $0.0457 |
| claude-haiku-4-5 | no-skill | 58.3% | 8s | $0.0265 |
| claude-opus-5 | skill | 100% | 9.9s | $0.1191 |
| claude-opus-5 | no-skill | 100% | 7.9s | $0.0592 |
| claude-sonnet-5 | skill | 91.7% | 5.8s | $0.0892 |
| claude-sonnet-5 | no-skill | 83.3% | 5.4s | $0.063 |
| gemma4:12b | skill | 50% | 29.3s | $0.2084 |
| gemma4:12b | no-skill | 50% | 22.2s | $0.1476 |
| glm-4.7-flash:q4_K_M-32k | skill | 56.2% | 13.3s | $0.3782 |
| glm-4.7-flash:q4_K_M-32k | no-skill | 25% | 9.6s | $0.3587 |
| gpt-5.6-luna | skill | 83.3% | 17.2s | $0.0055 |
| gpt-5.6-luna | no-skill | 75% | 10.6s | $0.0028 |
| gpt-5.6-sol | skill | 83.3% | 17.1s | $0.135 |
| gpt-5.6-sol | no-skill | 75% | 12.1s | $0.0768 |
| gpt-5.6-terra | skill | 100% | 16.9s | $0.036 |
| gpt-5.6-terra | no-skill | 66.7% | 12.2s | $0.0389 |
| ollama/gemma4:12b | skill | 37.5% | 7.4s | $0 |
| ollama/gemma4:12b | no-skill | 37.5% | 4s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | skill | 25% | 2.9s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | no-skill | 12.5% | 12.8s | $0 |
| ollama/qwen3.6:27b | skill | 37.5% | 35.3s | $0 |
| ollama/qwen3.6:27b | no-skill | 50% | 41.7s | $0 |

_Full per-cell aggregates (harness × model × effort × mode) in `azure-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
