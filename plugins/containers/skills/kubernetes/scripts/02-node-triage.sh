#!/usr/bin/env bash
# Purpose:        Node health triage - NotReady nodes, pressure conditions, and allocatable headroom
# Applies to:     Kubernetes 1.28+ (kubectl; metrics-server needed for the top section)
# Read-only:      yes
# Inputs:         none
# Interpretation: NotReady with condition reasons: MemoryPressure/DiskPressure = the kubelet is evicting - fix capacity
#                 before pods churn; PIDPressure = runaway process fork; NetworkUnavailable = CNI down on that node.
#                 Allocatable percentages near 100% on requests mean the scheduler has no headroom - pending pods
#                 follow. One bad node pattern: cordon it, drain it (respect PDBs), investigate, uncordon.
# Next step:      kubectl describe node <name> for the flagged nodes; check the node OS with the os-specialist if kubelet-external

set -euo pipefail

echo "== Nodes"
kubectl get nodes -o wide

echo
echo "== Pressure conditions (anything True besides Ready is a finding)"
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[?(@.status=="True")]}{.type}{" "}{end}{"\n"}{end}'

echo
echo "== Resource usage (requires metrics-server)"
kubectl top nodes 2>/dev/null || echo "metrics-server not available"
