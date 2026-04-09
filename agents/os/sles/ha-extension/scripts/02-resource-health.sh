#!/usr/bin/env bash
# ============================================================================
# HA Extension - Resource Health Check
#
# Purpose : Detailed resource status including failed actions, active
#           constraints, current placement, failure counts, and
#           orphaned/unmanaged resources.
# Version : 1.0.0
# Targets : SLES 15+ with SUSE HA Extension
# Safety  : Read-only. No modifications to cluster configuration.
#
# Sections:
#   1. All Resources (including stopped)
#   2. Failed Resource Actions
#   3. Active Constraints
#   4. Current Resource Placement
#   5. Resources with Failure Counts
#   6. Orphaned/Unmanaged Resources
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

echo "$SEP"
echo "  HA Resource Health Check - $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"

# ── All Resources ───────────────────────────────────────────────────────────
section "ALL RESOURCES (including stopped)"

crm_mon -1 -r -f -A 2>/dev/null | sed 's/^/  /' || {
    echo "  ERROR: Could not retrieve resource status"
    exit 1
}

# ── Failed Actions ──────────────────────────────────────────────────────────
section "FAILED RESOURCE ACTIONS"

failed=$(crm_mon -1 -r 2>/dev/null | awk '/Failed Resource Actions/,0' || true)
if [ -z "$failed" ] || echo "$failed" | grep -q "No failed"; then
    echo "  No failed resource actions"
else
    echo "$failed" | sed 's/^/  /'
fi

# ── Active Constraints ──────────────────────────────────────────────────────
section "ACTIVE CONSTRAINTS"

echo "  Location constraints:"
crm configure show 2>/dev/null | grep "^location" | sed 's/^/    /' || echo "    none"

echo ""
echo "  Colocation constraints:"
crm configure show 2>/dev/null | grep "^colocation" | sed 's/^/    /' || echo "    none"

echo ""
echo "  Order constraints:"
crm configure show 2>/dev/null | grep "^order" | sed 's/^/    /' || echo "    none"

# ── Current Placement ───────────────────────────────────────────────────────
section "CURRENT RESOURCE PLACEMENT"

crm_mon -1 2>/dev/null | grep -E "^\s+(Started|Master|Slave|Stopped|FAILED)" \
    | sed 's/^/  /' || echo "  No placement data"

# ── Failure Counts ──────────────────────────────────────────────────────────
section "RESOURCES WITH FAILURE COUNTS"

cibadmin -Q --scope status 2>/dev/null \
    | grep -E 'fail-count|migration-threshold' \
    | grep -v 'fail-count="0"' \
    | sed 's/^/  /' \
    || echo "  No elevated failure counts"

# ── Orphaned/Unmanaged ──────────────────────────────────────────────────────
section "ORPHANED/UNMANAGED RESOURCES"

crm_mon -1 -r 2>/dev/null | grep -iE "unmanaged|orphan" \
    | sed 's/^/  /' \
    || echo "  No unmanaged or orphaned resources detected"

echo ""
echo "$SEP"
echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"
