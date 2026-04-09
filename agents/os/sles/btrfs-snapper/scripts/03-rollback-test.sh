#!/usr/bin/env bash
# ============================================================================
# Btrfs/Snapper - Rollback Readiness Check
#
# Purpose : Verify system rollback readiness including default subvolume,
#           GRUB snapshot entries, snapshot chain integrity, Snapper
#           configuration, and GRUB plugin status.
# Version : 1.0.0
# Targets : SLES 15+ with Snapper + GRUB snapshot integration
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Default Subvolume
#   2. Running Subvolume
#   3. Snapper Configuration
#   4. Available Snapshots
#   5. Snapshot Read-Only Status
#   6. GRUB Snapshot Plugin
#   7. Rollback Command Availability
#   8. Summary
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
PASS=0
FAIL=0

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

pass() { echo "  [OK]    $*"; ((PASS++)); }
fail() { echo "  [FAIL]  $*"; ((FAIL++)); }
warn() { echo "  [WARN]  $*"; }
info() { echo "  [INFO]  $*"; }

echo "$SEP"
echo "  Rollback Readiness Check - $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"

# ── Default Subvolume ────────────────────────────────────────────────────────
section "DEFAULT SUBVOLUME"

DEFAULT_SUBVOL=$(btrfs subvolume get-default / 2>/dev/null || echo "unknown")
echo "  $DEFAULT_SUBVOL"
if echo "$DEFAULT_SUBVOL" | grep -qE "path @$|path /@$"; then
    pass "Default subvolume is @ (live root)"
elif echo "$DEFAULT_SUBVOL" | grep -q "snapshot"; then
    warn "Default subvolume appears to be a snapshot -- system may be in rollback state"
else
    warn "Default subvolume path does not match expected @ pattern"
fi

# ── Running Subvolume ────────────────────────────────────────────────────────
section "CURRENTLY RUNNING SUBVOLUME"

RUNNING=$(cat /proc/self/mountinfo 2>/dev/null | awk '$5 == "/" {print $4}' | head -1)
echo "  Root mount subvolume path: ${RUNNING:-unknown}"
if [[ "$RUNNING" == "/@" || "$RUNNING" == "@" || "$RUNNING" == "/" ]]; then
    pass "Running from live root subvolume"
else
    warn "Running from: $RUNNING (may be snapshot or non-standard layout)"
fi

# ── Snapper Configuration ────────────────────────────────────────────────────
section "SNAPPER CONFIGURATION"

if command -v snapper &>/dev/null; then
    pass "snapper is installed"
else
    fail "snapper is not installed -- rollback functionality unavailable"
fi

CONFIGS=$(snapper list-configs 2>/dev/null | awk 'NR>2 {print $1}')
if [[ -n "$CONFIGS" ]]; then
    pass "Snapper configs found: $CONFIGS"
else
    fail "No Snapper configurations -- rollback not configured"
fi

# ── Available Snapshots ──────────────────────────────────────────────────────
section "AVAILABLE ROLLBACK SNAPSHOTS"

SNAP_COUNT=$(snapper list 2>/dev/null | awk 'NR>2 && NF>1 {c++} END {print c+0}')
echo "  Total snapshots available: $SNAP_COUNT"
if [[ "$SNAP_COUNT" -ge 3 ]]; then
    pass "$SNAP_COUNT snapshots available for rollback"
elif [[ "$SNAP_COUNT" -ge 1 ]]; then
    warn "Only $SNAP_COUNT snapshot(s) -- limited rollback options"
else
    fail "No snapshots -- rollback is not possible"
fi

echo ""
echo "  Most recent snapshots:"
snapper list 2>/dev/null | head -10 | tail -7 | sed 's/^/    /' || true

# ── Snapshot Read-Only Status ────────────────────────────────────────────────
section "SNAPSHOT READ-ONLY VERIFICATION"

SNAPSHOT_DIR="/.snapshots"
if [[ -d "$SNAPSHOT_DIR" ]]; then
    pass "Snapshot directory exists: $SNAPSHOT_DIR"
    SNAPSHOTS=$(ls "$SNAPSHOT_DIR" 2>/dev/null | grep -E '^[0-9]+$' | tail -5)
    RO_FAIL=0
    for SNAP_ID in $SNAPSHOTS; do
        SNAP_PATH="$SNAPSHOT_DIR/$SNAP_ID/snapshot"
        if [[ -d "$SNAP_PATH" ]]; then
            RO=$(btrfs property get "$SNAP_PATH" ro 2>/dev/null || echo "unknown")
            if echo "$RO" | grep -q "ro=true"; then
                echo "    Snapshot $SNAP_ID: read-only (correct)"
            else
                warn "Snapshot $SNAP_ID: NOT read-only -- may cause rollback issues"
                ((RO_FAIL++))
            fi
        fi
    done
    if [[ "$RO_FAIL" -eq 0 ]]; then
        pass "All checked snapshots are read-only"
    fi
else
    fail "Snapshot directory $SNAPSHOT_DIR not found"
fi

# ── GRUB Snapshot Plugin ─────────────────────────────────────────────────────
section "GRUB SNAPSHOT PLUGIN"

if rpm -q grub2-snapper-plugin &>/dev/null 2>&1; then
    pass "grub2-snapper-plugin is installed"
else
    fail "grub2-snapper-plugin not installed -- snapshot boot entries will not appear"
fi

GRUB_CFG="/boot/grub2/grub.cfg"
if [[ -f "$GRUB_CFG" ]]; then
    SNAP_ENTRIES=$(grep -c "snapshot" "$GRUB_CFG" 2>/dev/null || echo "0")
    if [[ "$SNAP_ENTRIES" -gt 0 ]]; then
        pass "GRUB config contains $SNAP_ENTRIES snapshot-related lines"
    else
        warn "GRUB config exists but no snapshot entries -- run: grub2-mkconfig -o $GRUB_CFG"
    fi

    echo ""
    echo "  Sample GRUB snapshot entries:"
    grep "menuentry.*snapshot" "$GRUB_CFG" 2>/dev/null | head -3 \
        | sed "s/menuentry '//;s/' {//" | sed 's/^/    /' || echo "    None found"
else
    warn "GRUB config not found at $GRUB_CFG"
fi

# ── Rollback Command ─────────────────────────────────────────────────────────
section "ROLLBACK COMMAND AVAILABILITY"

if snapper --help 2>/dev/null | grep -q rollback; then
    pass "snapper rollback command is available"
else
    warn "snapper rollback not found in help -- version may be outdated"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
section "ROLLBACK READINESS SUMMARY"

echo "  PASS: $PASS  FAIL: $FAIL"
if [[ "$FAIL" -eq 0 ]]; then
    echo "  [OK] System is ready for rollback operations"
else
    echo "  [ACTION] $FAIL check(s) failed -- address before relying on rollback"
fi

echo ""
echo "$SEP"
echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"
