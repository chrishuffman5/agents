#!/usr/bin/env bash
# ============================================================================
# SLES - Package Audit
#
# Purpose : Package management health including pending patches, locked
#           packages, orphaned RPMs, repository health, and GPG key
#           validation.
# Version : 1.0.0
# Targets : SLES 15 SP5+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Pending Security Patches
#   2. Pending Recommended Patches
#   3. Package Locks
#   4. Orphaned Packages
#   5. Repository Health
#   6. GPG Keys
#   7. Services Needing Restart
#   8. Recent Package Transactions
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
echo "  SLES Package Audit - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"

# ── Section 1: Pending Security Patches ─────────────────────────────────────
section "SECTION 1 - Pending Security Patches"

if command -v zypper &>/dev/null; then
    sec_patches=$(zypper patches --category security 2>/dev/null | grep -c "Needed" || echo "0")
    echo "  Pending security patches: $sec_patches"
    if [[ "$sec_patches" -gt 0 ]]; then
        echo ""
        echo "  [WARN] Security patches pending -- apply with: zypper patch --category security"
        echo ""
        zypper patches --category security 2>/dev/null | grep "Needed" | head -20 | sed 's/^/    /'
    else
        echo "  [OK]   No pending security patches"
    fi
else
    echo "  zypper not available"
fi

# ── Section 2: Pending Recommended Patches ──────────────────────────────────
section "SECTION 2 - Pending Recommended Patches"

rec_patches=$(zypper patches --category recommended 2>/dev/null | grep -c "Needed" || echo "0")
echo "  Pending recommended patches: $rec_patches"
if [[ "$rec_patches" -gt 0 ]]; then
    zypper patches --category recommended 2>/dev/null | grep "Needed" | head -10 | sed 's/^/    /'
fi

# ── Section 3: Package Locks ────────────────────────────────────────────────
section "SECTION 3 - Package Locks"

locks=$(zypper locks 2>/dev/null)
if [[ -n "$locks" && ! "$locks" =~ "no locks" ]]; then
    echo "$locks" | sed 's/^/  /'
else
    echo "  No package locks configured"
fi

# ── Section 4: Orphaned Packages ────────────────────────────────────────────
section "SECTION 4 - Orphaned Packages"

echo "  Packages not provided by any enabled repository:"
orphans=$(zypper packages --orphaned 2>/dev/null | grep -c "^i" || echo "0")
echo "  Orphaned package count: $orphans"
if [[ "$orphans" -gt 0 ]]; then
    zypper packages --orphaned 2>/dev/null | grep "^i" | head -20 | sed 's/^/    /'
    echo ""
    echo "  [INFO] Orphaned packages may be from removed repos or manual installs"
fi

# ── Section 5: Repository Health ────────────────────────────────────────────
section "SECTION 5 - Repository Health"

echo "  Configured repositories:"
zypper repos 2>/dev/null | sed 's/^/    /' || echo "    Unable to list repos"

echo ""
echo "  Repository refresh test:"
zypper refresh --force 2>&1 | tail -20 | sed 's/^/    /' || echo "    Refresh failed"

# ── Section 6: GPG Keys ────────────────────────────────────────────────────
section "SECTION 6 - Imported GPG Keys"

echo "  RPM GPG keys:"
rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n' 2>/dev/null \
    | sed 's/^/    /' || echo "    Unable to list GPG keys"

# ── Section 7: Services Needing Restart ─────────────────────────────────────
section "SECTION 7 - Services Needing Restart"

echo "  Processes using deleted files (need service restart):"
zypper ps -s 2>/dev/null | head -30 | sed 's/^/    /' || echo "    Unable to check"

echo ""
echo "  Reboot required:"
if [ -f /run/reboot-needed ]; then
    echo "    YES -- /run/reboot-needed exists"
else
    zypper needs-rebooting 2>/dev/null && echo "    YES" || echo "    NO"
fi

# ── Section 8: Recent Package Transactions ──────────────────────────────────
section "SECTION 8 - Recent Package Transactions (last 20)"

if [[ -f /var/log/zypp/history ]]; then
    tail -20 /var/log/zypp/history 2>/dev/null | sed 's/^/    /'
else
    echo "    /var/log/zypp/history not found"
fi

echo ""
echo "$SEP"
echo "  Package Audit Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
