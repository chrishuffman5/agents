#!/usr/bin/env bash
# Purpose:        Elasticsearch cluster health triage - status, node balance, and the reason for unassigned shards
# Applies to:     Elasticsearch 8.x/9.x (works for OpenSearch with the same endpoints)
# Read-only:      yes
# Inputs:         __ES_URL__ (e.g. https://es.example.com:9200); add -u user:pass / --cacert as your cluster requires
# Prereqs:        curl, jq
# Interpretation: yellow = replicas unassigned (single-node clusters are permanently yellow - expected); red = PRIMARY
#                 shards missing - data unavailable for those indices. allocation/explain names the exact reason for
#                 the first unassigned shard: disk watermarks (roll/delete indices or add disk), allocation filtering,
#                 or node loss. Disk over the high watermark = ES relocates shards away; over flood-stage = indices go
#                 read-only (write failures cascade to every producer).
# Next step:      02-index-audit.sh for the size/ILM picture; fix the named allocation reason

set -euo pipefail
ES="__ES_URL__"

echo "== Cluster health"
curl -sf "${ES}/_cluster/health?pretty"

echo
echo "== Nodes (disk, heap)"
curl -sf "${ES}/_cat/nodes?v&h=name,node.role,heap.percent,disk.used_percent,cpu,load_1m"

echo
echo "== Unassigned shard explanation (first offender)"
curl -sf "${ES}/_cluster/allocation/explain?pretty" 2>/dev/null | head -40 || echo "no unassigned shards"
