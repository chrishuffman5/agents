#!/usr/bin/env bash
# Purpose:        Workflow duration statistics - find the pipelines eating developer time and runner minutes
# Applies to:     GitHub Actions via gh CLI 2.x
# Read-only:      yes
# Inputs:         optionally REPO="-R __OWNER/REPO__"
# Prereqs:        gh, jq
# Interpretation: Rising average duration = growing test suite or cache misses (check cache hit logs in a slow run vs
#                 a fast one). High variance on the same workflow = runner queue time or flaky retries, not the build
#                 itself. The billable levers, in order: cache dependencies properly, split long jobs into parallel
#                 matrix jobs, gate expensive jobs on paths, and only then bigger runners.
# Next step:      Open the slowest run's timing breakdown (gh run view --json jobs) and attack the longest job first

set -euo pipefail
REPO="${REPO:-}"

gh run list $REPO --status success --limit 50 --json workflowName,createdAt,updatedAt |
    jq -r '
        map(. + { mins: (((.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 60) })
        | group_by(.workflowName)[]
        | {
            workflow: .[0].workflowName,
            runs: length,
            avg_min: (map(.mins) | add / length * 10 | round / 10),
            max_min: (map(.mins) | max * 10 | round / 10)
          }
        | [.workflow, (.runs|tostring), (.avg_min|tostring), (.max_min|tostring)]
        | @tsv
    ' | sort -t$'\t' -k3 -rn | column -t -s$'\t'
