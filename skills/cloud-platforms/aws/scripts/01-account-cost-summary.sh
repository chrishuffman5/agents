#!/usr/bin/env bash
# Purpose:        Month-to-date spend by service with prior-month comparison - the FinOps "where is the money going" opener
# Applies to:     AWS via CLI v2 + Cost Explorer (read-only IAM: ce:GetCostAndUsage)
# Read-only:      yes
# Inputs:         AWS credentials/profile in the environment; Cost Explorer must be enabled on the account
# Prereqs:        jq
# Interpretation: Rank services by MTD cost - the top 3-5 are where optimization pays. A service that jumped vs last
#                 month is your investigation lead (new workload, a misconfigured autoscaler, forgotten resources, or
#                 egress). EC2/RDS at the top = commitment-discount candidates (see 02); S3/data-transfer at the top =
#                 lifecycle and egress-architecture problems. This is directional - the console gives the breakdown by tag.
# Next step:      02-savings-coverage.sh for RI/SP coverage; tag-based drilldown in Cost Explorer for the jumped service

set -euo pipefail
start=$(date -u +%Y-%m-01)
end=$(date -u +%Y-%m-%d)
lm_start=$(date -u -d "$start -1 month" +%Y-%m-01 2>/dev/null || date -u -v-1m -v1d +%Y-%m-01)
lm_end=$(date -u -d "$start -1 day" +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d)

echo "== Month-to-date by service ($start .. $end)"
aws ce get-cost-and-usage --time-period Start="$start",End="$end" --granularity MONTHLY --metrics UnblendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[0].Groups[].[Keys[0],Metrics.UnblendedCost.Amount]' --output text 2>/dev/null |
    sort -k2 -rn | head -15 | awk '{printf "%-45s $%.2f\n", $1, $2}'

echo
echo "== Prior full month total (for trend)"
aws ce get-cost-and-usage --time-period Start="$lm_start",End="$lm_end" --granularity MONTHLY --metrics UnblendedCost \
    --query 'ResultsByTime[0].Total.UnblendedCost.Amount' --output text 2>/dev/null | awk '{printf "$%.2f\n", $1}'
