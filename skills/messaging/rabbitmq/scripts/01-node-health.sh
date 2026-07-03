#!/usr/bin/env bash
# Purpose:        RabbitMQ node health - alarms, listeners, quorum-critical queues, and version state in one pass
# Applies to:     RabbitMQ 3.13+/4.x (rabbitmq-diagnostics / rabbitmqctl on a cluster node, or via ssh)
# Read-only:      yes
# Inputs:         run on a cluster node (or prefix with: ssh __NODE__)
# Interpretation: Any memory/disk alarm = the broker is BLOCKING publishers right now - that is why producers hang
#                 (not crash). check_port_connectivity failures name dead listeners. Queues in the quorum-critical
#                 list would lose availability if one more node dies - do not proceed with rolling restarts until it
#                 is empty.
# Next step:      02-queue-depths.sh for where messages pile up; clear alarms by freeing memory/disk, not by raising watermarks blindly

set -euo pipefail

echo "== Status (alarms, memory, disk)"
rabbitmq-diagnostics status | grep -A5 -E 'Alarms|Memory|Free Disk' | head -30

echo
echo "== Health checks"
rabbitmq-diagnostics check_running && echo "running: OK"
rabbitmq-diagnostics check_local_alarms && echo "alarms: none"
rabbitmq-diagnostics check_port_connectivity && echo "ports: OK"

echo
echo "== Quorum-critical queues (empty = safe for single-node maintenance)"
rabbitmq-diagnostics check_if_node_is_quorum_critical || true

echo
echo "== Cluster members"
rabbitmqctl cluster_status --formatter=json 2>/dev/null | head -5 || rabbitmqctl cluster_status | head -20
