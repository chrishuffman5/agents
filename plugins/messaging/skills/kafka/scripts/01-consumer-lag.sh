#!/usr/bin/env bash
# Purpose:        Consumer-group lag across all groups - THE Kafka health question, answered in one pass
# Applies to:     Kafka 3.x/4.x (kafka-consumer-groups CLI from the Kafka distribution)
# Read-only:      yes
# Inputs:         __BOOTSTRAP__ - broker bootstrap servers (host:9092); add --command-config for SASL/TLS clusters
# Interpretation: LAG growing monotonically = consumers cannot keep up (see the parallelism ceiling: consumers beyond
#                 partition count sit idle). LAG flat-high after an incident = consumers recovered but haven't caught
#                 up - fine if shrinking. CONSUMER-ID '-' rows = partitions with NO active consumer (group down or
#                 rebalance-stuck) - that data is going nowhere. A few partitions lagging while siblings are clean =
#                 hot-key skew or one stuck consumer instance (the host/client-id column names it).
# Next step:      02-under-replicated.sh if brokers are suspect; scale consumers only up to the partition count

set -euo pipefail

BOOTSTRAP="__BOOTSTRAP__"

kafka-consumer-groups --bootstrap-server "$BOOTSTRAP" --describe --all-groups 2>/dev/null |
    awk 'NR==1 || $1=="GROUP" {print; next} $6 != "-" && $6 > 0 {print}' | head -60

echo
echo "== Groups summary (state, members)"
kafka-consumer-groups --bootstrap-server "$BOOTSTRAP" --list 2>/dev/null | while read -r g; do
    kafka-consumer-groups --bootstrap-server "$BOOTSTRAP" --describe --group "$g" --state 2>/dev/null | tail -1
done
