#!/usr/bin/env bash
# Purpose:        Warning events cluster-wide, newest first - the "what changed" feed for any Kubernetes incident
# Applies to:     Kubernetes 1.28+ (kubectl)
# Read-only:      yes
# Inputs:         none
# Interpretation: Repeated FailedScheduling names the constraint (Insufficient cpu/memory, taint, affinity). BackOff =
#                 crash loops (see 01). FailedMount = PVC/secret/CSI problems. Unhealthy = probe failures - if many
#                 pods at once, suspect the dependency they probe, not the pods. Evicted events cluster on a node =
#                 that node's pressure (see 02). Events expire (~1h default) - capture early in an incident.
# Next step:      Drill into the named objects with kubectl describe; correlate timestamps with deploys

set -euo pipefail

kubectl get events --all-namespaces --field-selector type=Warning \
    --sort-by='.lastTimestamp' \
    -o custom-columns='LAST:.lastTimestamp,NS:.metadata.namespace,KIND:.involvedObject.kind,NAME:.involvedObject.name,REASON:.reason,COUNT:.count,MESSAGE:.message' |
    tail -40
