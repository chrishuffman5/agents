#!/usr/bin/env bash
# Purpose:        Point-in-time latency/IOPS/throughput sample per volume - localize "storage is slow" to specific volumes
# Applies to:     ONTAP 9.14+ over SSH, readonly-role admin user (statistics commands may need advanced privilege)
# Read-only:      yes
# Inputs:         __CLUSTER_MGMT__ and __USER__; runs a ~30-second sample
# Interpretation: Volume latency > ~1-2ms (SSD/AFF) or ~10ms (hybrid) sustained = investigate: one hot volume with high
#                 IOPS = workload problem (QoS-limit or move it); ALL volumes slow on one node = node/aggregate-level
#                 issue (CPU, disk, takeover state - cross-check 01-cluster-health.sh). Use QoS statistics to see
#                 whether a policy group is throttling (latency from "QoS" vs "disk" in workload breakdown).
# Next step:      For sustained hot volumes: 'qos statistics volume latency show' live during the incident; consider QoS policy or volume move

set -euo pipefail

HOST="__CLUSTER_MGMT__"
USER="__USER__"

ssh "${USER}@${HOST}" <<'ONTAP'
set -showseparator ","
statistics volume show -sort-key total_ops -interval 30 -iterations 1
qos statistics volume performance show -iterations 1
ONTAP
