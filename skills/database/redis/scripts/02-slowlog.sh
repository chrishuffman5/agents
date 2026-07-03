#!/usr/bin/env bash
# Purpose:        Recent slow commands from SLOWLOG plus current latency events - what is actually stalling Redis
# Applies to:     Redis 7.2+ (redis-cli)
# Read-only:      yes
# Inputs:         __HOST__ __PORT__
# Interpretation: Redis is single-threaded for command execution - ONE slow command stalls everyone behind it. The
#                 classics in this log: KEYS (never in prod - use SCAN), SMEMBERS/LRANGE on huge collections (paginate),
#                 heavy Lua scripts, and O(N) commands on million-member structures. Times are microseconds and exclude
#                 network. LATENCY HISTORY names non-command stalls too (fork for RDB/AOF rewrite, AOF fsync).
# Next step:      Replace/paginate the offending command patterns; 03-bigkeys.sh to find the structures behind them

set -euo pipefail

HOST="__HOST__"
PORT="__PORT__"
R() { redis-cli -h "$HOST" -p "$PORT" "$@"; }

echo "== Slowlog (threshold: $(R CONFIG GET slowlog-log-slower-than | tail -1) microseconds)"
R SLOWLOG GET 25

echo
echo "== Latency events (requires latency-monitor-threshold > 0)"
R LATENCY LATEST
