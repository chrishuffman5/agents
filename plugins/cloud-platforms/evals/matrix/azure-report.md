# azure — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `cloud-platforms` · runs: **144 / 288** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 72 | **87.5%** | 13.6s | 339 | $4.6126 | $0.0732 |
| no-skill | 72 | **76.4%** | 9.4s | 189 | $2.5533 | $0.0464 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 86.1% | 80.6% | +5.5pp | 10.2s | 7.1s |
| codex | 88.9% | 72.2% | +16.7pp | 17.1s | 11.6s |

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
| gpt-5.6-luna | skill | 83.3% | 17.2s | $0.0055 |
| gpt-5.6-luna | no-skill | 75% | 10.6s | $0.0028 |
| gpt-5.6-sol | skill | 83.3% | 17.1s | $0.135 |
| gpt-5.6-sol | no-skill | 75% | 12.1s | $0.0768 |
| gpt-5.6-terra | skill | 100% | 16.9s | $0.036 |
| gpt-5.6-terra | no-skill | 66.7% | 12.2s | $0.0389 |

_Full per-cell aggregates (harness × model × effort × mode) in `azure-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
