# prisma-cloud — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| prisma-cloud-builtin-policies | recent | Approximately how many built-in detection policies does Prisma Cloud ship out of the box across all its policy types? Answer concisely. | regex: `(?i)2,?000\+?` |
| prisma-cloud-iac-formats | stable | Name at least three infrastructure-as-code formats that Prisma Cloud's Code Security module can scan for misconfigurations. Answer concisely. | contains_all: `Terraform``, ``CloudFormation``, ``Helm` |
| prisma-cloud-app-embedded-defender | recent | Which specific twistcli subcommand embeds Prisma Cloud's Defender agent directly inside a container image, for environments like Fargate where a DaemonSet cannot be deployed? Answer concisely. | regex: `(?i)twistcli\s+embed` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `prisma-cloud-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
