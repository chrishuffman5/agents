#!/usr/bin/env bash
# ============================================================================
# kubectl - Namespace Resource Report
#
# Purpose : Per-namespace resource summary including pods, services,
#           deployments, resource usage, quotas, and warning events.
# Version : 1.0.0
# Targets : Kubernetes 1.24+
# Safety  : Read-only. No modifications to cluster state.
#
# Usage:
#   ./03-namespace-report.sh                    # all non-system namespaces
#   ./03-namespace-report.sh my-app staging     # specific namespaces
#
# Sections:
#   1. Summary Table
#   2. Per-Namespace Detail
#   3. Issue Summary
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..60})"

SYSTEM_NS="kube-system kube-public kube-node-lease"

# Determine namespaces to report
if [[ $# -gt 0 ]]; then
  NAMESPACES=("$@")
else
  mapfile -t NAMESPACES < <(kubectl get namespaces \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | \
    grep -vE "^(kube-system|kube-public|kube-node-lease)$")
fi

echo "$SEP"
echo "  Namespace Resource Report"
echo "  Context: $(kubectl config current-context)"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"

# -- Section 1: Summary Table ------------------------------------------------
printf "\n%-25s %6s %7s %5s %7s %6s\n" \
  "NAMESPACE" "PODS" "RUNNING" "SVCS" "DEPLOY" "ISSUES"
printf "%-25s %6s %7s %5s %7s %6s\n" \
  "$(printf '%.0s-' {1..25})" "------" "-------" "-----" "-------" "------"

NAMESPACES_WITH_ISSUES=()

for NS in "${NAMESPACES[@]}"; do
  TOTAL_PODS=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  RUNNING=$(kubectl get pods -n "$NS" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
  SVC_COUNT=$(kubectl get services -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  DEPLOY_COUNT=$(kubectl get deployments -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')

  ISSUE_COUNT=$((TOTAL_PODS - RUNNING))
  # Subtract succeeded pods from issues
  SUCCEEDED=$(kubectl get pods -n "$NS" --field-selector=status.phase=Succeeded --no-headers 2>/dev/null | wc -l | tr -d ' ')
  ISSUE_COUNT=$((ISSUE_COUNT - SUCCEEDED))
  [[ "$ISSUE_COUNT" -lt 0 ]] && ISSUE_COUNT=0

  printf "%-25s %6s %7s %5s %7s %6s\n" \
    "$NS" "$TOTAL_PODS" "$RUNNING" "$SVC_COUNT" "$DEPLOY_COUNT" "$ISSUE_COUNT"

  [[ "$ISSUE_COUNT" -gt 0 ]] && NAMESPACES_WITH_ISSUES+=("$NS")
done

# -- Section 2: Per-Namespace Detail ------------------------------------------
for NS in "${NAMESPACES[@]}"; do
  echo ""
  echo "$SEP"
  echo "  Namespace: ${NS}"
  echo "$SEP"

  # Pods
  echo ""
  echo "  Pods:"
  kubectl get pods -n "$NS" -o wide 2>/dev/null | sed 's/^/    /' || echo "    (none)"

  # Services
  echo ""
  echo "  Services:"
  kubectl get services -n "$NS" 2>/dev/null | sed 's/^/    /' || echo "    (none)"

  # Deployments
  echo ""
  echo "  Deployments:"
  kubectl get deployments -n "$NS" 2>/dev/null | sed 's/^/    /' || echo "    (none)"

  # StatefulSets (if any)
  STS_COUNT=$(kubectl get statefulsets -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$STS_COUNT" -gt 0 ]]; then
    echo ""
    echo "  StatefulSets:"
    kubectl get statefulsets -n "$NS" 2>/dev/null | sed 's/^/    /'
  fi

  # Resource usage
  echo ""
  echo "  Pod Resource Usage:"
  if kubectl top pods -n "$NS" --sort-by=cpu 2>/dev/null | head -10 | sed 's/^/    /'; then
    :
  else
    echo "    (metrics-server not available)"
  fi

  # Resource quotas
  QUOTA_COUNT=$(kubectl get resourcequota -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$QUOTA_COUNT" -gt 0 ]]; then
    echo ""
    echo "  Resource Quotas:"
    kubectl describe resourcequota -n "$NS" 2>/dev/null | \
      grep -E '(Resource|requests|limits|pods|services|----)' | head -20 | sed 's/^/    /'
  fi

  # Limit ranges
  LR_COUNT=$(kubectl get limitrange -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$LR_COUNT" -gt 0 ]]; then
    echo ""
    echo "  Limit Ranges:"
    kubectl get limitrange -n "$NS" 2>/dev/null | sed 's/^/    /'
  fi

  # Ingresses
  ING_COUNT=$(kubectl get ingress -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$ING_COUNT" -gt 0 ]]; then
    echo ""
    echo "  Ingresses:"
    kubectl get ingress -n "$NS" 2>/dev/null | sed 's/^/    /'
  fi

  # Warning events
  WARN_EVENTS=$(kubectl get events -n "$NS" \
    --field-selector=type=Warning \
    --sort-by=.lastTimestamp 2>/dev/null | tail -5 || true)
  if [[ -n "$WARN_EVENTS" ]] && echo "$WARN_EVENTS" | grep -q .; then
    echo ""
    echo "  Warning Events:"
    echo "$WARN_EVENTS" | sed 's/^/    /'
  fi
done

# -- Section 3: Issue Summary ------------------------------------------------
if [[ ${#NAMESPACES_WITH_ISSUES[@]} -gt 0 ]]; then
  echo ""
  echo "$SEP"
  echo "  NAMESPACES WITH POD ISSUES"
  echo "$SEP"
  for NS in "${NAMESPACES_WITH_ISSUES[@]}"; do
    echo ""
    echo "  Namespace: ${NS}"
    kubectl get pods -n "$NS" \
      --field-selector='status.phase!=Running,status.phase!=Succeeded' \
      -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,REASON:.status.reason' \
      2>/dev/null | sed 's/^/    /' || true
  done
fi

echo ""
echo "$SEP"
echo "  Report complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
