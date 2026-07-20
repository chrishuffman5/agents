#!/usr/bin/env bash
# Purpose:        Cluster-wide pod triage - every not-Running/not-Ready pod with restart counts and its latest events
# Applies to:     Kubernetes 1.28+ (kubectl with read access; works on EKS/AKS/GKE/OpenShift)
# Read-only:      yes
# Inputs:         optionally narrow with NS="-n __NAMESPACE__" (default: all namespaces)
# Interpretation: Walk the status ladder: Pending = scheduling (resources, taints, PVC binding); ImagePullBackOff =
#                 registry/auth/tag; CrashLoopBackOff = app or probe (read logs --previous); OOMKilled in last-state =
#                 memory limits. High restarts with Running status = flapping probes or slow startup - check
#                 liveness vs startup probe configuration.
# Next step:      kubectl logs --previous on the named pods; 03-recent-events.sh for the cluster-wide event picture

set -euo pipefail
NS="${NS:---all-namespaces}"

echo "== Pods not Running/Succeeded, or not Ready"
kubectl get pods $NS -o wide | awk 'NR==1 || ($4 !~ /Running|Completed|Succeeded/) || ($3 ~ /\// && substr($3,1,index($3,"/")-1) != substr($3,index($3,"/")+1))' | head -40

echo
echo "== Restart leaders"
kubectl get pods $NS --sort-by='.status.containerStatuses[0].restartCount' -o custom-columns='NS:.metadata.namespace,POD:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,REASON:.status.containerStatuses[0].lastState.terminated.reason' 2>/dev/null | tail -15
