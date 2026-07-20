#!/usr/bin/env bash
# Purpose:        Cardinality audit - top metric names and label pairs by series count, straight from the TSDB status API
# Applies to:     Prometheus 2.x/3.x HTTP API
# Read-only:      yes
# Inputs:         __PROM_URL__
# Prereqs:        curl, jq
# Interpretation: One metric owning a huge share of series = the explosion source - almost always a label carrying an
#                 unbounded value (IDs, paths, IPs, pod hashes). Fix at the SOURCE (drop/relabel in scrape config,
#                 fix the instrumentation) - recording rules do not reduce ingest cardinality. seriesCountByLabelValuePair
#                 names the guilty label directly. Every series costs ~memory and churn; unbounded labels are the #1
#                 Prometheus killer.
# Next step:      metric_relabel_configs to drop the offending label/metric; re-check headStats after the next scrape cycles

set -euo pipefail
PROM="__PROM_URL__"

STATUS=$(curl -sf "${PROM}/api/v1/status/tsdb")

echo "== Top metrics by series count"
echo "$STATUS" | jq -r '.data.seriesCountByMetricName[] | [.value, .name] | @tsv' | head -15

echo
echo "== Top label=value pairs by series count"
echo "$STATUS" | jq -r '.data.seriesCountByLabelValuePair[] | [.value, .name] | @tsv' | head -15

echo
echo "== Labels with most distinct values"
echo "$STATUS" | jq -r '.data.labelValueCountByLabelName[] | [.value, .name] | @tsv' | head -10
