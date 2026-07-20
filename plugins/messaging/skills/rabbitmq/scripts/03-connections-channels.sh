#!/usr/bin/env bash
# Purpose:        Connection and channel audit - leak detection, churn sources, and flow-controlled publishers
# Applies to:     RabbitMQ 3.13+/4.x (rabbitmqctl on a cluster node)
# Read-only:      yes
# Inputs:         none
# Interpretation: Hundreds of connections from one host = missing connection reuse (AMQP connections are expensive;
#                 apps should hold few connections with many channels). Channels in flow state = the broker is
#                 throttling that publisher (usually queue backpressure - see 02). High channel counts per connection
#                 (>100s) or steadily climbing totals = a channel leak; the peer_host column names the guilty app.
# Next step:      Fix pooling/reuse in the named apps; re-run and watch the totals fall

set -euo pipefail

echo "== Connections by peer host"
rabbitmqctl list_connections peer_host user state channels 2>/dev/null |
    awk 'NR>1 {count[$1]++; ch[$1]+=$4} END {for (h in count) printf "%-30s connections=%-6s channels=%s\n", h, count[h], ch[h]}' | sort -k2 -rn | head -20

echo
echo "== Flow-controlled channels (broker throttling these publishers)"
rabbitmqctl list_channels connection name state 2>/dev/null | awk 'NR==1 || /flow/' | head -20

echo
echo "== Totals"
rabbitmqctl list_connections 2>/dev/null | tail -n +2 | wc -l | xargs echo "connections:"
rabbitmqctl list_channels 2>/dev/null | tail -n +2 | wc -l | xargs echo "channels:"
