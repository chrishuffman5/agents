#!/usr/bin/env bash
# ============================================================================
# kubectl - Cluster Health Report
#
# Purpose : Cluster overview including nodes, pod summary, resource usage,
#           unhealthy pods detail, and recent warning events.
# Version : 1.0.0
# Targets : Kubernetes 1.24+
# Safety  : Read-only. No modifications to cluster state.
#
# Usage:
#   ./01-cluster-health.sh                       # current namespace
#   ./01-cluster-health.sh -n my-namespace       # specific namespace
#   ./01-cluster-health.sh -A                    # all namespaces
#
# Sections:
#   1. Nodes
#   2. Node Conditions and Taints
#   3. Node Resource Usage
#   4. Pod Status Summary
#   5. Top Pods
#   6. Unhealthy Pods Detail
#   7. Recent Warning Events
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..60})"
NS_FLAG=""
NS_LABEL="current namespace"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NS_FLAG="-n $2"; NS_LABEL="namespace: $2"; shift 2 ;;
    -A|--all-namespaces) NS_FLAG="-A"; NS_LABEL="all namespaces"; shift ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

section() {
  echo ""
  echo "$SEP"
  echo "  $1"
  echo "$SEP"
}

section "Kubernetes Cluster Health Report"
echo "  Context: $(kubectl config current-context)"
echo "  Scope:   ${NS_LABEL}"
echo "  Time:    $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# -- Section 1: Nodes --------------------------------------------------------
section "NODES"
kubectl get nodes -o wide

# -- Section 2: Node Conditions and Taints ------------------------------------
section "NODE CONDITIONS"
NOT_READY=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\n"}{end}' | grep -v True || true)
if [[ -n "$NOT_READY" ]]; then
  echo "  WARNING: Nodes not ready:"
  echo "$NOT_READY" | sed 's/^/    /'
else
  echo "  All nodes Ready."
fi

echo ""
echo "  Taints:"
kubectl get nodes -o jsonpath='{range .items[*]}  {.metadata.name}: {range .spec.taints[*]}{.key}={.value}:{.effect} {end}{"\n"}{end}' 2>/dev/null || echo "  (none)"

# -- Section 3: Node Resource Usage -------------------------------------------
section "NODE RESOURCE USAGE"
if kubectl top nodes 2>/dev/null; then
  :
else
  echo "  (metrics-server not available)"
fi

# -- Section 4: Pod Status Summary --------------------------------------------
section "POD STATUS SUMMARY (${NS_LABEL})"
TOTAL=$(kubectl get pods ${NS_FLAG} --no-headers 2>/dev/null | wc -l | tr -d ' ')
RUNNING=$(kubectl get pods ${NS_FLAG} --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
PENDING=$(kubectl get pods ${NS_FLAG} --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')
FAILED=$(kubectl get pods ${NS_FLAG} --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l | tr -d ' ')
SUCCEEDED=$(kubectl get pods ${NS_FLAG} --field-selector=status.phase=Succeeded --no-headers 2>/dev/null | wc -l | tr -d ' ')

echo "  Total:     ${TOTAL}"
echo "  Running:   ${RUNNING}"
echo "  Pending:   ${PENDING}"
echo "  Failed:    ${FAILED}"
echo "  Succeeded: ${SUCCEEDED}"

# -- Section 5: Top Pods ------------------------------------------------------
section "TOP PODS BY CPU (${NS_LABEL})"
if kubectl top pods ${NS_FLAG} --sort-by=cpu 2>/dev/null | head -15; then
  :
else
  echo "  (metrics-server not available)"
fi

# -- Section 6: Unhealthy Pods Detail -----------------------------------------
section "UNHEALTHY PODS DETAIL"
UNHEALTHY=$(kubectl get pods ${NS_FLAG} \
  --field-selector='status.phase!=Running,status.phase!=Succeeded' \
  --no-headers 2>/dev/null || true)

if [[ -z "$UNHEALTHY" ]]; then
  echo "  All pods are healthy."
else
  echo "$UNHEALTHY" | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    POD=$(echo "$line" | awk '{print $1}')
    NS_PART=""
    if [[ "$NS_FLAG" == "-A" ]]; then
      NS_PART=$(echo "$line" | awk '{print $1}')
      POD=$(echo "$line" | awk '{print $2}')
      echo ""
      echo "  --- $NS_PART/$POD ---"
      kubectl get events -n "$NS_PART" \
        --field-selector="involvedObject.name=$POD" \
        --sort-by=.lastTimestamp 2>/dev/null | tail -5 | sed 's/^/    /' || true
    else
      echo ""
      echo "  --- $POD ---"
      kubectl get events \
        --field-selector="involvedObject.name=$POD" \
        --sort-by=.lastTimestamp 2>/dev/null | tail -5 | sed 's/^/    /' || true
    fi
  done
fi

# -- Section 7: Recent Warning Events -----------------------------------------
section "RECENT WARNING EVENTS"
kubectl get events ${NS_FLAG} \
  --field-selector=type=Warning \
  --sort-by=.lastTimestamp \
  -o custom-columns='TIME:.lastTimestamp,NS:.metadata.namespace,REASON:.reason,OBJECT:.involvedObject.name,MSG:.message' \
  2>/dev/null | tail -15 || echo "  (no warning events)"

echo ""
echo "$SEP"
echo "  Report complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
