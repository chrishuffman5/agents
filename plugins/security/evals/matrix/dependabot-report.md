# dependabot — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dependabot-default-pr-limit | stable | If you do not set open-pull-requests-limit in a dependabot.yml update configuration, what is the default maximum number of open pull requests Dependabot keeps for that ecosystem? Answer concisely. | regex: `(?i)\b5\b` |
| dependabot-cvss-critical-range | stable | GitHub Dependabot alerts assign severity labels based on CVSS score. What CVSS score range maps to the Critical severity label? Answer concisely. | regex: `(?i)9(\.0)?\s*(-|to)\s*10(\.0)?` |
| dependabot-security-update-granularity | recent | When Dependabot automatically creates security update pull requests, does it open one PR per vulnerable dependency, or one PR per individual vulnerability? Answer in one sentence. | regex: `(?i)one.{0,4}(pr|pull request).{0,20}vulnerability` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `dependabot-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
