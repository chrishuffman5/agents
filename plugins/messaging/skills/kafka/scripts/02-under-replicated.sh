#!/usr/bin/env bash
# Purpose:        Broker-side health - under-replicated, under-min-ISR, and offline partitions (the data-safety triage)
# Applies to:     Kafka 3.x/4.x (kafka-topics CLI)
# Read-only:      yes
# Inputs:         __BOOTSTRAP__ - broker bootstrap servers; add --command-config for SASL/TLS
# Interpretation: Under-replicated (ISR < replicas) = a broker is down or falling behind (check its disk/network/GC) -
#                 durability is reduced but writes continue. Under-min-ISR = producers with acks=all are now FAILING
#                 writes on those partitions - this is a producer-visible outage. Unavailable/offline = no leader -
#                 reads AND writes down for those partitions. Fix order: offline first, then under-min-ISR, then URP.
# Next step:      Identify the common broker across the flagged partitions and fix/restart it; 03-topic-config-audit.sh after recovery

set -euo pipefail

BOOTSTRAP="__BOOTSTRAP__"

echo "== Under-replicated partitions"
kafka-topics --bootstrap-server "$BOOTSTRAP" --describe --under-replicated-partitions

echo
echo "== Under min-ISR partitions (producer-visible failures with acks=all)"
kafka-topics --bootstrap-server "$BOOTSTRAP" --describe --under-min-isr-partitions

echo
echo "== Unavailable partitions (no leader - full outage for these)"
kafka-topics --bootstrap-server "$BOOTSTRAP" --describe --unavailable-partitions
