#!/usr/bin/env bash
# Purpose:        Client connection audit - who is connected, idle herds, blocked clients, and output-buffer pressure
# Applies to:     Redis 7.2+ (redis-cli)
# Read-only:      yes
# Inputs:         __HOST__ __PORT__
# Interpretation: Thousands of connections from one app host = missing client-side pooling. Clients with huge omem
#                 (output buffer) are slow consumers - usually a subscriber not reading fast enough; they can OOM the
#                 server and get killed by client-output-buffer-limit. blocked_clients are in BLPOP/XREAD waits -
#                 normal for queue patterns, suspicious otherwise. Long idle+flags=N connections = leak; consider a
#                 sane 'timeout' config.
# Next step:      Fix pooling/slow consumers at the named client hosts; 01-server-health.sh to confirm pressure relief

set -euo pipefail

HOST="__HOST__"
PORT="__PORT__"
R() { redis-cli -h "$HOST" -p "$PORT" "$@"; }

echo "== Client counts"
R INFO clients

echo
echo "== Top clients by output buffer (omem) and idle"
R CLIENT LIST | awk '
{
    for (i = 1; i <= NF; i++) {
        split($i, kv, "=");
        if (kv[1] == "addr") addr = kv[2];
        if (kv[1] == "idle") idle = kv[2];
        if (kv[1] == "omem") omem = kv[2];
        if (kv[1] == "cmd")  cmd  = kv[2];
    }
    printf "%-28s idle=%-8s omem=%-12s cmd=%s\n", addr, idle, omem, cmd;
}' | sort -t= -k3 -rn | head -25
