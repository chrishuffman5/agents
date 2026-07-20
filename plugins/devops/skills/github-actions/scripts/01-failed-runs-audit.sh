#!/usr/bin/env bash
# Purpose:        Recent failed workflow runs with their failing jobs - the CI triage entry point
# Applies to:     GitHub Actions via gh CLI 2.x (authenticated; run inside the repo or pass -R owner/repo)
# Read-only:      yes
# Inputs:         optionally REPO="-R __OWNER/REPO__"
# Prereqs:        gh, jq
# Interpretation: The same job failing across many runs = deterministic breakage (fix the code/config); scattered
#                 different jobs = flakiness or infrastructure (runner capacity, rate limits, external deps). Failures
#                 clustered after a specific time = correlate with merged PRs and action/runner-image updates
#                 (ubuntu-latest migrations are a classic).
# Next step:      gh run view <id> --log-failed for the top offender; 02-workflow-duration-trend.sh for slowness instead of failure

set -euo pipefail
REPO="${REPO:-}"

echo "== Last 20 failed runs"
gh run list $REPO --status failure --limit 20 \
    --json databaseId,workflowName,headBranch,event,createdAt \
    --template '{{range .}}{{.databaseId}}	{{.workflowName}}	{{.headBranch}}	{{.event}}	{{.createdAt}}{{"\n"}}{{end}}'

echo
echo "== Failure counts by workflow (last 50 runs)"
gh run list $REPO --limit 50 --json workflowName,conclusion |
    jq -r 'group_by(.workflowName)[] | [.[0].workflowName, (map(select(.conclusion == "failure")) | length | tostring) + "/" + (length | tostring)] | @tsv'
