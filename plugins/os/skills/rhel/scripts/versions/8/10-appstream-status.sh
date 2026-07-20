#!/usr/bin/env bash
# ============================================================================
# RHEL 8 - AppStream Module Stream Inventory
#
# Purpose : Inventory all Application Stream module states including enabled,
#           disabled, and installed profiles. Reports stream defaults and
#           AppStream repository health.
# Version : 1.0.0
# Targets : RHEL 8.x
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. System and Subscription Context
#   2. Enabled Module Streams
#   3. Disabled Module Streams
#   4. Installed Module Profiles
#   5. Key Stream Status
#   6. AppStream Repository Health
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }
ok()   { echo "  [OK]   $1"; }
warn() { echo "  [WARN] $1"; }
info() { echo "  [INFO] $1"; }

# Guard: RHEL 8 only
if [[ -f /etc/redhat-release ]]; then
    rhel_ver=$(rpm -E '%{rhel}' 2>/dev/null || echo "unknown")
    if [[ "$rhel_ver" != "8" ]]; then
        warn "This script targets RHEL 8. Detected: RHEL ${rhel_ver}"
    fi
else
    echo "ERROR: Not a Red Hat system." >&2; exit 1
fi

echo "RHEL 8 AppStream Module Inventory"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Host: $(hostname -f 2>/dev/null || hostname)"

# ── Section 1: System Context ───────────────────────────────────────────────
section "1. System and Subscription Context"

echo "  $(cat /etc/redhat-release 2>/dev/null)"
echo "  Kernel: $(uname -r)"

if command -v subscription-manager &>/dev/null; then
    sub_status=$(subscription-manager status 2>/dev/null | grep -i "overall status" || echo "Unable to query")
    echo "  Subscription: $sub_status"
else
    warn "subscription-manager not found"
fi

# ── Section 2: Enabled Module Streams ───────────────────────────────────────
section "2. Enabled Module Streams"

enabled_modules=$(dnf module list --enabled 2>/dev/null | grep -v "^$\|^Hint\|^Name\|^Red Hat\|^Extra\|^Last\|^\-" || true)
if [[ -z "$enabled_modules" ]]; then
    info "No module streams currently enabled"
else
    echo "$enabled_modules" | sed 's/^/    /'
fi

# ── Section 3: Disabled Module Streams ──────────────────────────────────────
section "3. Disabled Module Streams"

disabled_modules=$(dnf module list --disabled 2>/dev/null | grep -v "^$\|^Hint\|^Name\|^Red Hat\|^Extra\|^Last\|^\-" || true)
if [[ -z "$disabled_modules" ]]; then
    info "No module streams explicitly disabled"
else
    echo "$disabled_modules" | sed 's/^/    /'
fi

# ── Section 4: Installed Module Profiles ────────────────────────────────────
section "4. Installed Module Profiles"

installed_modules=$(dnf module list --installed 2>/dev/null | grep -v "^$\|^Hint\|^Name\|^Red Hat\|^Extra\|^Last\|^\-" || true)
if [[ -z "$installed_modules" ]]; then
    info "No module profiles currently installed"
else
    echo "$installed_modules" | sed 's/^/    /'
fi

# ── Section 5: Key Stream Status ────────────────────────────────────────────
section "5. Key Stream Status for Common Modules"

key_modules=("php" "python38" "python39" "nodejs" "ruby" "postgresql" "nginx" "perl" "maven")
for mod in "${key_modules[@]}"; do
    mod_info=$(dnf module list "$mod" 2>/dev/null | grep -v "^$\|^Hint\|^Red Hat\|^Extra\|^Last\|^\-" | tail -n +2 || true)
    if [[ -n "$mod_info" ]]; then
        active_stream=$(echo "$mod_info" | awk '$4 == "[e]" || $4 == "[i]" {print $2}' | head -1)
        default_stream=$(echo "$mod_info" | awk '$4 == "[d]" || $5 == "[d]" {print $2}' | head -1)
        if [[ -n "$active_stream" ]]; then
            ok "$mod -- active stream: $active_stream"
        elif [[ -n "$default_stream" ]]; then
            info "$mod -- default stream: $default_stream (not enabled)"
        else
            info "$mod -- available (no default stream set)"
        fi
    else
        info "$mod -- not found in enabled repositories"
    fi
done

# ── Section 6: AppStream Repository Health ──────────────────────────────────
section "6. AppStream Repository Health"

repo_list=$(dnf repolist 2>/dev/null || true)
if echo "$repo_list" | grep -qi "appstream"; then
    ok "AppStream repository is enabled"
    echo "$repo_list" | grep -i "appstream" | sed 's/^/    /'
else
    warn "AppStream repository not found in enabled repos"
fi

if echo "$repo_list" | grep -qi "baseos"; then
    ok "BaseOS repository is enabled"
else
    warn "BaseOS repository not found in enabled repos"
fi

if [[ -d /etc/dnf/modules.d ]]; then
    mod_files=$(ls /etc/dnf/modules.d/*.module 2>/dev/null | wc -l || echo 0)
    info "Module configuration files in /etc/dnf/modules.d/: $mod_files"
fi

echo ""
echo "$SEP"
echo "  AppStream Inventory Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
