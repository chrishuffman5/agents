#!/usr/bin/env bash
# Purpose:        Index audit - biggest indices, shard-size sanity, and ILM errors (the disk-fill early-warning sweep)
# Applies to:     Elasticsearch 8.x/9.x with ILM (OpenSearch: same _cat endpoints, ISM instead of ILM)
# Read-only:      yes
# Inputs:         __ES_URL__
# Prereqs:        curl, jq
# Interpretation: Shards far outside the 10-50GB sweet spot: tiny shards by the hundreds = per-shard overhead eating
#                 heap (merge indices / fewer primaries); giant shards = slow recovery and hot spots. ILM errors =
#                 indices stuck in a phase (commonly rollover alias misconfig) - they stop aging out and fill the disk.
#                 Old indices in hot tiers that ILM should have moved are the cost/health finding.
# Next step:      Fix ILM errors via the named step; right-size shard counts in the index template for the next rollover

set -euo pipefail
ES="__ES_URL__"

echo "== Biggest indices"
curl -sf "${ES}/_cat/indices?v&h=index,health,pri,rep,docs.count,store.size&s=store.size:desc" | head -20

echo
echo "== ILM errors"
curl -sf "${ES}/*/_ilm/explain?only_errors=true" | jq -r '.indices | to_entries[] | [.key, .value.step, (.value.step_info.reason // "" | .[0:120])] | @tsv' 2>/dev/null | head -15 || echo "no ILM errors"
