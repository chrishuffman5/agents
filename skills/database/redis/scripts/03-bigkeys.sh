#!/usr/bin/env bash
# Purpose:        Find the biggest keys per type (SCAN-based, production-safe) - the memory hogs and O(N) landmines
# Applies to:     Redis 7.2+ (redis-cli --bigkeys uses SCAN; safe on production, still adds load - prefer off-peak or a replica)
# Read-only:      yes
# Inputs:         __HOST__ __PORT__
# Interpretation: Multi-million-member collections found here are both memory hogs and latency bombs (any O(N) command
#                 on them stalls the server - cross-check 02-slowlog.sh). Giant keys also serialize badly: they block
#                 during DUMP/RESTORE migrations and cluster resharding. Fixes: split into sharded keys
#                 (key:{bucket}), cap with trimming (LPUSH+LTRIM, XADD MAXLEN), or add TTLs.
# Next step:      MEMORY USAGE <key> on suspects for exact cost; plan the split/trim for the top offenders

set -euo pipefail

HOST="__HOST__"
PORT="__PORT__"

redis-cli -h "$HOST" -p "$PORT" --bigkeys

echo
echo "== Sample exact sizes of suspects with:"
echo "   redis-cli -h $HOST -p $PORT MEMORY USAGE <key> SAMPLES 0"
