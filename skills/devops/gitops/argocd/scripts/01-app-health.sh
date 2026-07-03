#!/usr/bin/env bash
# Purpose:        ArgoCD application fleet triage - everything not Healthy+Synced, with the reason
# Applies to:     ArgoCD 2.8+ (argocd CLI, logged in; read-only RBAC suffices)
# Read-only:      yes
# Inputs:         none (argocd login already done)
# Interpretation: OutOfSync + Healthy = drift or a pending change waiting on manual sync - diff it before syncing
#                 (someone may have hotfixed the cluster). Synced + Degraded = the manifests applied but the workload
#                 is failing (pods crashing - this is a Kubernetes problem, not a GitOps one; hand to pod triage).
#                 Unknown health = ArgoCD cannot reach the cluster or the resource has no health check. Many apps
#                 OutOfSync at once = a repo-wide change or a broken ApplicationSet generator.
# Next step:      02-sync-failures.sh for apps whose SYNC operations fail; kubectl pod triage for Degraded ones

set -euo pipefail

echo "== Apps not Healthy/Synced"
argocd app list -o wide 2>/dev/null | awk 'NR==1 || $5 != "Synced" || $6 != "Healthy"'

echo
echo "== Fleet summary"
argocd app list -o json 2>/dev/null |
    python3 -c "
import json, sys, collections
apps = json.load(sys.stdin)
sync = collections.Counter(a['status']['sync']['status'] for a in apps)
health = collections.Counter(a['status']['health']['status'] for a in apps)
print('sync:  ', dict(sync)); print('health:', dict(health))
"
