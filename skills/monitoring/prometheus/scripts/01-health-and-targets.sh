#!/usr/bin/env bash
# Purpose:        Prometheus health and scrape-target triage - down targets with their errors, plus TSDB vitals
# Applies to:     Prometheus 2.x/3.x HTTP API
# Read-only:      yes
# Inputs:         __PROM_URL__ - e.g. http://prometheus.example.com:9090
# Prereqs:        curl, jq
# Interpretation: Down targets' lastError distinguishes: connection refused (exporter down), timeout (network/overload),
#                 401/403 (auth drift). Many targets down in one job = the job's service discovery or a network path,
#                 not individual exporters. headStats numSeries is your live cardinality - compare across runs; a jump
#                 means a new label explosion (see 02-cardinality-audit.sh).
# Next step:      02-cardinality-audit.sh if series counts jumped; fix the named exporters/jobs otherwise

set -euo pipefail
PROM="__PROM_URL__"

echo "== Health"
curl -sf "${PROM}/-/healthy" && echo " healthy"
curl -sf "${PROM}/api/v1/status/buildinfo" | jq -r '.data | "version " + .version'

echo
echo "== Down targets"
curl -sf "${PROM}/api/v1/targets" |
    jq -r '.data.activeTargets[] | select(.health != "up") | [.labels.job, .scrapeUrl, .lastError[0:100]] | @tsv'

echo
echo "== TSDB head stats"
curl -sf "${PROM}/api/v1/status/tsdb" | jq '.data.headStats'
