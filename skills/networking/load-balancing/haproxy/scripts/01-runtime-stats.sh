#!/usr/bin/env bash
# Purpose:        HAProxy runtime health from the stats socket - down backends, queueing, error rates per server
# Applies to:     HAProxy 2.4+ (stats socket enabled: 'stats socket /var/run/haproxy.sock mode 660 level admin' - level operator suffices for reads)
# Read-only:      yes
# Inputs:         __SOCKET__ - stats socket path (default /var/run/haproxy.sock); requires socat
# Interpretation: status DOWN servers with check_status naming the failed health check (L4TOUT = connect timeout to
#                 the server, L7STS = HTTP check got a bad status). qcur > 0 = requests queueing because maxconn is
#                 reached - raise server maxconn or add capacity. Climbing eresp/econ = the backend erroring/refusing,
#                 not HAProxy. All servers of one backend DOWN = the app tier is the outage, HAProxy is the messenger.
# Next step:      02-config-check.sh before any fix that edits configuration; investigate the failing health-check target

set -euo pipefail
SOCKET="${1:-__SOCKET__}"

echo "== Backends/servers not UP"
echo "show stat" | socat stdio "$SOCKET" |
    awk -F, 'NR==1 || ($18 != "UP" && $18 != "OPEN" && $18 != "" && $2 != "FRONTEND")' |
    cut -d, -f1,2,18,19,37 | column -t -s,

echo
echo "== Queue and error snapshot (pxname, svname, qcur, econ, eresp)"
echo "show stat" | socat stdio "$SOCKET" |
    awk -F, 'NR>1 && ($3 > 0 || $14 > 0 || $15 > 0) {print $1","$2",q="$3",econ="$14",eresp="$15}' | head -20

echo
echo "== Server states"
echo "show servers state" | socat stdio "$SOCKET" | head -25
