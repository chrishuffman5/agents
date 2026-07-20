#!/usr/bin/env bash
# Purpose:        Reserved Instance / Savings Plans coverage and utilization - the commitment-discount opportunity check
# Applies to:     AWS via CLI v2 + Cost Explorer (read-only IAM: ce:GetSavingsPlansCoverage, ce:GetReservationCoverage/Utilization)
# Read-only:      yes
# Inputs:         AWS credentials/profile; Cost Explorer enabled
# Interpretation: Low SP/RI COVERAGE on steady compute = you are paying on-demand for baseline load - the clearest
#                 savings lever (commit to the trough, not the peak). Low UTILIZATION on existing commitments = you
#                 over-committed or workloads moved - wasted spend already sunk. The sweet spot is high coverage on
#                 the steady baseline AND high utilization. Never commit to bursty/variable load - keep that on-demand
#                 or Spot. Break-even math before any purchase, always.
# Next step:      Model a Savings Plan for the uncovered baseline in Cost Explorer's recommendations; do not buy without the break-even

set -euo pipefail
start=$(date -u -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-30d +%Y-%m-%d)
end=$(date -u +%Y-%m-%d)

echo "== Savings Plans coverage (last 30d)"
aws ce get-savings-plans-coverage --time-period Start="$start",End="$end" \
    --query 'SavingsPlansCoverages[0].Coverage.{CoveragePct:CoveragePercentage,OnDemand:OnDemandCost,Covered:SpendCoveredBySavingsPlans}' \
    --output table 2>/dev/null || echo "no SP coverage data"

echo
echo "== Savings Plans utilization (last 30d)"
aws ce get-savings-plans-utilization --time-period Start="$start",End="$end" \
    --query 'Total.Utilization.{UtilizationPct:UtilizationPercentage,Used:UsedCommitment,Unused:UnusedCommitment}' \
    --output table 2>/dev/null || echo "no active Savings Plans"

echo
echo "== EC2 RI utilization (last 30d)"
aws ce get-reservation-utilization --time-period Start="$start",End="$end" \
    --query 'Total.{UtilizationPct:UtilizationPercentage,Purchased:PurchasedHours,Unused:UnusedHours}' \
    --output table 2>/dev/null || echo "no RIs"
