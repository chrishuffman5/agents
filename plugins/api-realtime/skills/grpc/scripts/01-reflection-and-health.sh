#!/usr/bin/env bash
# Purpose:        Probe a gRPC server via reflection and the standard health service - what does it expose and is it serving?
# Applies to:     gRPC servers with reflection and/or the grpc.health.v1 service (uses grpcurl)
# Read-only:      yes (lists services and calls the read-only Health/Check)
# Inputs:         __GRPC_TARGET__ (host:port); add -plaintext for non-TLS, -H "authorization: Bearer ..." if needed
# Prereqs:        grpcurl
# Interpretation: Reflection ENABLED lets any client (and attacker) enumerate every service and method - convenient in
#                 dev, a surface-disclosure finding in production; gate or disable it there. The health check's status
#                 SERVING/NOT_SERVING per service is what load balancers key on - NOT_SERVING means the LB should be
#                 pulling that backend; if it isn't, the health integration is misconfigured. No health service at all =
#                 the LB is guessing (TCP-only checks miss app-level failures).
# Next step:      Disable reflection in prod if exposed; ensure grpc.health.v1 is implemented and wired to the LB

set -euo pipefail
TARGET="__GRPC_TARGET__"
FLAGS="${GRPCURL_FLAGS:--plaintext}"

echo "== Services via reflection"
if grpcurl $FLAGS "$TARGET" list 2>/dev/null; then
    echo "(reflection ENABLED - fine for dev, review for production exposure)"
else
    echo "reflection disabled or unreachable (disabled is preferable in production)"
fi

echo
echo "== Health check (grpc.health.v1)"
grpcurl $FLAGS "$TARGET" grpc.health.v1.Health/Check 2>/dev/null ||
    echo "no standard health service responding - load balancers cannot do app-level health checks"
