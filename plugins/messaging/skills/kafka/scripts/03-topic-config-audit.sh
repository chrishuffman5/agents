#!/usr/bin/env bash
# Purpose:        Topic configuration audit - RF vs min.insync.replicas sanity, retention, and partition counts
# Applies to:     Kafka 3.x/4.x (kafka-topics CLI)
# Read-only:      yes
# Inputs:         __BOOTSTRAP__ - broker bootstrap servers
# Interpretation: RF=1 topics have zero durability - one broker loss = data loss (fine for scratch, a finding for
#                 anything else). RF=3 with min.insync.replicas=1 defeats acks=all (a write can ack with one copy);
#                 the standard is RF=3 + min.insync=2. Retention overrides far above the default on high-volume topics
#                 are your disk-usage explanation. Partition counts define the consumer parallelism ceiling from
#                 01-consumer-lag.sh.
# Next step:      Fix min.insync/RF gaps via kafka-configs (change window - ISR shrink risk during reassignment)

set -euo pipefail

BOOTSTRAP="__BOOTSTRAP__"

echo "== Topics: partitions and RF"
kafka-topics --bootstrap-server "$BOOTSTRAP" --describe 2>/dev/null |
    awk '/^Topic:/ && $2 !~ /^__/ { printf "%-50s partitions=%-5s rf=%s\n", $2, $6, $8 }' | sort

echo
echo "== Non-default topic configs (retention, min.insync, cleanup.policy)"
kafka-configs --bootstrap-server "$BOOTSTRAP" --entity-type topics --describe 2>/dev/null |
    grep -E 'retention\.ms|min\.insync\.replicas|cleanup\.policy' | grep -v '^$' | head -40
