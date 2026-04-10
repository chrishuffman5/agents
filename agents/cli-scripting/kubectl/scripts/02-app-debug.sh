#!/usr/bin/env bash
# ============================================================================
# kubectl - Application Debugging Script
#
# Purpose : Debug an application by name or label selector. Checks deployment
#           status, pod states, container logs, events, service/endpoints,
#           and network connectivity.
# Version : 1.0.0
# Targets : Kubernetes 1.24+
# Safety  : Read-only except for temporary net-test pods (auto-deleted).
#
# Usage:
#   ./02-app-debug.sh my-api                     # default namespace
#   ./02-app-debug.sh my-api -n production       # specific namespace
#   ./02-app-debug.sh my-api --label "app=my-api,version=v2"
#   ./02-app-debug.sh my-api --lines 100
#
# Sections:
#   1. Deployment Status
#   2. Pod Status
#   3. Per-Pod Detail (logs, events, container status)
#   4. Service and Endpoints
#   5. Network Connectivity Test
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..60})"
APP_NAME="${1:-}"
NAMESPACE="default"
LABEL_SELECTOR=""
LOG_LINES=50

if [[ -z "$APP_NAME" ]]; then
  echo "Usage: $0 <app-name> [-n namespace] [--label selector] [--lines N]"
  echo "  Example: $0 my-api -n production"
  exit 1
fi

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
    --label) LABEL_SELECTOR="$2"; shift 2 ;;
    --lines) LOG_LINES="$2"; shift 2 ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

SELECTOR="${LABEL_SELECTOR:-app=${APP_NAME}}"

echo "$SEP"
echo "  App Debug: ${APP_NAME}"
echo "  Namespace: ${NAMESPACE}"
echo "  Selector:  ${SELECTOR}"
echo "$SEP"

# -- Section 1: Deployment Status ---------------------------------------------
echo ""
echo "$SEP"
echo "  DEPLOYMENT STATUS"
echo "$SEP"
if kubectl get deployment "$APP_NAME" -n "$NAMESPACE" 2>/dev/null; then
  echo ""
  kubectl describe deployment "$APP_NAME" -n "$NAMESPACE" | \
    grep -E '(Replicas:|Image:|Conditions:)' | head -10 || true
  echo ""
  echo "  Rollout history:"
  kubectl rollout history deployment/"$APP_NAME" -n "$NAMESPACE" 2>/dev/null || true
else
  echo "  No deployment named '${APP_NAME}' found."
fi

# -- Section 2: Pod Status ----------------------------------------------------
echo ""
echo "$SEP"
echo "  POD STATUS"
echo "$SEP"
PODS=$(kubectl get pods -n "$NAMESPACE" -l "$SELECTOR" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

if [[ -z "$PODS" ]]; then
  echo "  No pods found with selector: ${SELECTOR}"
else
  kubectl get pods -n "$NAMESPACE" -l "$SELECTOR" -o wide
fi

# -- Section 3: Per-Pod Detail ------------------------------------------------
echo "$PODS" | while IFS= read -r POD; do
  [[ -z "$POD" ]] && continue

  echo ""
  echo "$SEP"
  echo "  POD: ${POD}"
  echo "$SEP"

  PHASE=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
  echo "  Phase: ${PHASE}"

  # Container statuses
  CONTAINERS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{range .status.containerStatuses[*]}{.name}{"\t"}{.ready}{"\t"}{.restartCount}{"\n"}{end}' 2>/dev/null || true)
  if [[ -n "$CONTAINERS" ]]; then
    echo "  Containers:"
    echo "$CONTAINERS" | while IFS=$'\t' read -r cname cready crestarts; do
      echo "    ${cname}: ready=${cready} restarts=${crestarts}"
    done
  fi

  # Check for OOMKilled or termination reasons
  LAST_STATE=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || true)
  if [[ -n "$LAST_STATE" && "$LAST_STATE" != "" ]]; then
    EXIT_CODE=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}' 2>/dev/null || true)
    echo "  Last termination: ${LAST_STATE} (exit code: ${EXIT_CODE})"
  fi

  # Recent logs
  echo ""
  echo "  Recent logs (last ${LOG_LINES} lines):"
  kubectl logs "$POD" -n "$NAMESPACE" --tail="$LOG_LINES" 2>/dev/null \
    | tail -20 | sed 's/^/    /' || echo "    (no logs available)"

  # Previous logs if available
  if kubectl logs "$POD" -n "$NAMESPACE" --previous --tail=1 2>/dev/null | grep -q .; then
    echo ""
    echo "  Previous container logs (crash/restart):"
    kubectl logs "$POD" -n "$NAMESPACE" --previous --tail=20 2>/dev/null \
      | sed 's/^/    /' || true
  fi

  # Events for this pod
  echo ""
  echo "  Pod events:"
  kubectl get events -n "$NAMESPACE" \
    --field-selector="involvedObject.name=${POD}" \
    --sort-by=.lastTimestamp 2>/dev/null | tail -10 | sed 's/^/    /' || echo "    (no events)"
done

# -- Section 4: Service and Endpoints -----------------------------------------
echo ""
echo "$SEP"
echo "  SERVICE AND ENDPOINTS"
echo "$SEP"
if kubectl get service "$APP_NAME" -n "$NAMESPACE" 2>/dev/null; then
  echo ""
  kubectl get endpoints "$APP_NAME" -n "$NAMESPACE" 2>/dev/null || true
else
  echo "  No service named '${APP_NAME}' found."
  SERVICES=$(kubectl get services -n "$NAMESPACE" -l "$SELECTOR" --no-headers 2>/dev/null || true)
  if [[ -n "$SERVICES" ]]; then
    echo "  Services matching selector ${SELECTOR}:"
    echo "$SERVICES" | sed 's/^/    /'
  fi
fi

# -- Section 5: Network Connectivity Test -------------------------------------
echo ""
echo "$SEP"
echo "  NETWORK CONNECTIVITY TEST"
echo "$SEP"
SVC_PORT=$(kubectl get service "$APP_NAME" -n "$NAMESPACE" \
  -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "")

if [[ -n "$SVC_PORT" ]]; then
  echo "  Testing: http://${APP_NAME}.${NAMESPACE}.svc.cluster.local:${SVC_PORT}"
  if kubectl run "net-test-$(date +%s)" \
    --image=busybox:1.28 \
    --rm --restart=Never \
    -n "$NAMESPACE" \
    --timeout=30s \
    -- wget -qO- --timeout=5 "http://${APP_NAME}.${NAMESPACE}.svc.cluster.local:${SVC_PORT}/" \
    2>/dev/null; then
    echo "  Service is reachable."
  else
    echo "  Service unreachable or returned error."
  fi
else
  echo "  (no service found, skipping connectivity test)"
fi

echo ""
echo "$SEP"
echo "  Debug complete."
echo "$SEP"
