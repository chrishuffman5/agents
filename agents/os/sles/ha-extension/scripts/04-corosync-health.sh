#!/usr/bin/env bash
# ============================================================================
# HA Extension - Corosync Health Check
#
# Purpose : Corosync ring/link status, token timeout configuration,
#           current membership, quorum votes, runtime statistics,
#           authentication key, and recent errors.
# Version : 1.0.0
# Targets : SLES 15+ with SUSE HA Extension
# Safety  : Read-only. No modifications to cluster configuration.
#
# Sections:
#   1. Corosync Service Status
#   2. Ring / Link Status
#   3. Quorum Status
#   4. Totem Configuration
#   5. Current Membership
#   6. Runtime Statistics
#   7. Authentication Key
#   8. Recent Errors
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
COROSYNC_CONF="/etc/corosync/corosync.conf"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

echo "$SEP"
echo "  Corosync Health Check - $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"

# ── Service Status ──────────────────────────────────────────────────────────
section "COROSYNC SERVICE STATUS"

systemctl status corosync --no-pager -l 2>/dev/null | head -20 | sed 's/^/  /' \
    || echo "  ERROR: corosync status failed"

# ── Ring / Link Status ──────────────────────────────────────────────────────
section "RING / LINK STATUS"

if command -v corosync-cfgtool &>/dev/null; then
    corosync-cfgtool -s 2>/dev/null | sed 's/^/  /' \
        || echo "  ERROR: corosync-cfgtool failed"

    echo ""
    ring_output=$(corosync-cfgtool -s 2>/dev/null || true)
    if echo "$ring_output" | grep -qi "fault\|error\|faulty"; then
        echo "  [ERROR] RING FAULT DETECTED -- investigate corosync network"
    else
        echo "  [OK]   Ring status: no faults detected"
    fi
else
    echo "  corosync-cfgtool not found"
fi

# ── Quorum Status ───────────────────────────────────────────────────────────
section "QUORUM STATUS"

if command -v corosync-quorumtool &>/dev/null; then
    corosync-quorumtool -s 2>/dev/null | sed 's/^/  /' \
        || echo "  ERROR: corosync-quorumtool failed"
    echo ""
    echo "  Expected votes:"
    corosync-quorumtool -e 2>/dev/null | sed 's/^/    /' || echo "    Not available"
else
    echo "  corosync-quorumtool not found"
fi

# ── Totem Configuration ─────────────────────────────────────────────────────
section "TOTEM CONFIGURATION"

if [ -f "$COROSYNC_CONF" ]; then
    echo "  Cluster name, transport, token settings:"
    grep -E "cluster_name|transport|token|consensus|join|max_messages" \
        "$COROSYNC_CONF" 2>/dev/null | sed 's/^/    /'

    echo ""
    echo "  Interface / nodelist:"
    grep -E "bindnetaddr|mcastaddr|mcastport|ring._addr|node\b|nodeid" \
        "$COROSYNC_CONF" 2>/dev/null | head -20 | sed 's/^/    /'
else
    echo "  $COROSYNC_CONF not found"
fi

# ── Current Membership ──────────────────────────────────────────────────────
section "CURRENT MEMBERSHIP"

echo "  Node membership:"
corosync-quorumtool -s 2>/dev/null | grep -A20 "Membership information" \
    | sed 's/^/    /' || echo "    Could not retrieve membership"

# ── Runtime Statistics ──────────────────────────────────────────────────────
section "RUNTIME STATISTICS"

if command -v corosync-cmapctl &>/dev/null; then
    echo "  Token retransmits:"
    corosync-cmapctl stats.totem.total_token_retransmitted 2>/dev/null \
        | sed 's/^/    /' || echo "    Not available"

    echo "  Commit retransmits:"
    corosync-cmapctl stats.totem.total_commit_retransmitted 2>/dev/null \
        | sed 's/^/    /' || echo "    Not available"
else
    echo "  corosync-cmapctl not available"
fi

# ── Authentication Key ──────────────────────────────────────────────────────
section "AUTHENTICATION KEY"

authkey="/etc/corosync/authkey"
if [ -f "$authkey" ]; then
    echo "  Authkey present: $authkey"
    ls -l "$authkey" 2>/dev/null | sed 's/^/  /'
    echo "  MD5: $(md5sum "$authkey" 2>/dev/null | cut -d' ' -f1 || echo 'unknown')"
    echo "  NOTE: MD5 must match on ALL cluster nodes"
else
    echo "  [WARN] $authkey not found"
fi

# ── Recent Errors ───────────────────────────────────────────────────────────
section "RECENT COROSYNC ERRORS"

corosync_log="/var/log/cluster/corosync.log"
if [ -f "$corosync_log" ]; then
    grep -iE "error|warning|fault|retransmit" "$corosync_log" 2>/dev/null \
        | tail -20 | sed 's/^/  /' \
        || echo "  No errors found in $corosync_log"
else
    echo "  $corosync_log not found -- checking journal"
    journalctl -u corosync --no-pager -n 30 2>/dev/null \
        | grep -iE "error|warning|fault" | tail -10 | sed 's/^/  /' \
        || echo "  No relevant journal entries"
fi

echo ""
echo "$SEP"
echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"
