# aws — cross-harness eval report

Generated: 2026-08-08T21:50:18.3314216-05:00 · plugin: `cloud-platforms` · runs: **0 / 576** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aws-scp-mgmt | stable | In AWS Organizations, do service control policies (SCPs) restrict the management account itself? Answer in one sentence. | regex: `(?i)(\bno\b|never|do(es)? not|not appl|exempt)` |
| aws-tag-limits | stable | For AWS resource tags: how many tags can a single resource carry, and what is the maximum character length of a tag key? Answer concisely with both numbers. | contains_all: `50``, ``128` |
| aws-cost-tag-backfill | recent | After you activate a cost allocation tag in AWS, how far back can AWS backfill your cost data for that tag? Answer concisely. | regex: `(?i)(12\s*month|twelve\s*month)` |
| aws-ou-depth | stable | In AWS Organizations, how many levels deep can you nest organizational units under the root? Answer concisely. | regex: `\b5\b|\bfive\b` |
| aws-enforced-for | recent | In AWS Organizations tag policies, if you enable enforcement (enforced_for) for a tag key, will that block creating a resource that is entirely missing the required tag? Answer in one or two sentences. | regex: `(?i)(\bno\b|does not|won't|will not|only.{0,60}(value|case|noncompliant|non-compliant))` |
| aws-migrationhub-status | recent | As of late 2025, can a brand-new AWS customer onboard to AWS Migration Hub and AWS Application Discovery Service? Answer in one sentence. | regex: `(?i)(\bno\b|closed|no longer|not available|cannot)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `aws-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
