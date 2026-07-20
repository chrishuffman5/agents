#!/usr/bin/env bash
# Purpose:        Top resource consumers plus the pods running WITHOUT limits - the noisy-neighbor and OOM-risk audit
# Applies to:     Kubernetes 1.28+ (kubectl; metrics-server for the top section)
# Read-only:      yes
# Inputs:         none
# Interpretation: Pods without memory limits can OOM the node (kubelet evicts by QoS class - BestEffort dies first,
#                 but Burstable without limits can take the node down first). Top consumers far above their requests
#                 distort scheduling for everyone. The fix is right-sized requests+limits, not bigger nodes -
#                 cross-check with the actual usage shown here.
# Next step:      Set requests/limits on the flagged workloads' controllers; consider LimitRange defaults per namespace

set -euo pipefail

echo "== Top pod consumers (requires metrics-server)"
kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -20

echo
echo "== Containers with NO memory limit (namespace/pod/container)"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{range .spec.containers[?(@.resources.limits.memory=="")]}{.name}{end}{end}' >/dev/null 2>&1 || true
kubectl get pods --all-namespaces -o json |
    python3 -c "
import json, sys
for i in json.load(sys.stdin)['items']:
    for c in i['spec']['containers']:
        if not c.get('resources', {}).get('limits', {}).get('memory'):
            print(f\"{i['metadata']['namespace']}/{i['metadata']['name']}/{c['name']}\")
" | head -30
