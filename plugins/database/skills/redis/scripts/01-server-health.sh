#!/usr/bin/env bash
# Purpose:        Redis health vitals in one pass - memory, eviction policy sanity, hit ratio, replication, persistence
# Applies to:     Redis 7.2+ (redis-cli; works against Redis 8 and most compatible forks)
# Read-only:      yes
# Inputs:         __HOST__ __PORT__ (and -a password / --tls as your deployment requires)
# Interpretation: used_memory near maxmemory with policy 'noeviction' = writes will start failing (OOM errors) - either
#                 a cache that should evict (set allkeys-lru) or an undersized store. Hit ratio under ~90% for a cache =
#                 keys expiring too fast or working set exceeding memory. mem_fragmentation_ratio well above ~1.5 =
#                 fragmentation (activedefrag worth enabling). rdb_last_bgsave_status/aof_last_write_status not 'ok' =
#                 persistence silently broken - that IS the incident.
# Next step:      02-slowlog.sh for latency complaints; 03-bigkeys.sh for memory hogs

set -euo pipefail

HOST="__HOST__"
PORT="__PORT__"
R() { redis-cli -h "$HOST" -p "$PORT" "$@"; }

echo "== Memory"
R INFO memory | grep -E '^(used_memory_human|used_memory_peak_human|maxmemory_human|maxmemory_policy|mem_fragmentation_ratio):'

echo "== Hit ratio and load"
R INFO stats | grep -E '^(keyspace_hits|keyspace_misses|evicted_keys|expired_keys|instantaneous_ops_per_sec|rejected_connections|total_connections_received):'

echo "== Replication"
R INFO replication | grep -E '^(role|connected_slaves|master_link_status|master_last_io_seconds_ago|slave_repl_offset|master_repl_offset):'

echo "== Persistence"
R INFO persistence | grep -E '^(rdb_last_bgsave_status|rdb_last_save_time|aof_enabled|aof_last_write_status|aof_last_bgrewrite_status):'

echo "== Keyspace"
R INFO keyspace
