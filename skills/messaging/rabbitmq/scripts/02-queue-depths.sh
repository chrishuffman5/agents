#!/usr/bin/env bash
# Purpose:        Queue depth/consumer/memory ranking - find where messages pile up and which queues have nobody consuming
# Applies to:     RabbitMQ 3.13+/4.x (rabbitmqctl on a cluster node)
# Read-only:      yes
# Inputs:         adjust __VHOST__ if not default '/'
# Interpretation: Deep queue + zero consumers = the dead-consumer case (app down or connection churn) - that backlog
#                 is also a memory/disk liability. Deep queue + consumers present = consumers too slow (scale them or
#                 speed processing; check prefetch). messages_unacknowledged high vs ready = consumers holding acks -
#                 prefetch too high or handler stuck. Queues named *-dlq with ANY depth deserve a drain plan - a DLQ
#                 nobody reads is deferred data loss.
# Next step:      03-connections-channels.sh for the consumer side; fix the named consumer apps first

set -euo pipefail

VHOST="__VHOST__"   # usually /

echo "== Queues by depth"
rabbitmqctl list_queues -p "$VHOST" name messages messages_ready messages_unacknowledged consumers memory type --formatter=pretty_table 2>/dev/null |
    head -40

echo
echo "== Zero-consumer queues with backlog"
rabbitmqctl list_queues -p "$VHOST" name messages consumers 2>/dev/null |
    awk 'NR>1 && $3 == 0 && $2 > 0 {printf "%-50s backlog=%s\n", $1, $2}'
