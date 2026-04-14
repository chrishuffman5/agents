#!/usr/bin/env bash
# ============================================================================
# RHEL 8 - Migration Readiness Assessment (RHEL 8 -> RHEL 9)
#
# Purpose : Assess system readiness for upgrading from RHEL 8 to RHEL 9.
#           Checks subscription, deprecated features, package inventory,
#           Leapp prerequisites, and potential blockers.
# Version : 1.0.0
# Targets : RHEL 8.x
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Subscription and Content Access
#   2. Kernel and Hardware Compatibility
#   3. Deprecated Features in Active Use
#   4. Key Package and Service Inventory
#   5. Leapp Prerequisites
#   6. Readiness Summary
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }
ok()   { echo "  [OK]   $1"; }
warn() { echo "  [WARN] $1"; }
fail() { echo "  [FAIL] $1"; }
info() { echo "  [INFO] $1"; }

ISSUES=0
WARNINGS=0
flag_fail() { fail "$1"; ((ISSUES++)) || true; }
flag_warn() { warn "$1"; ((WARNINGS++)) || true; }

# Guard
if [[ ! -f /etc/redhat-release ]]; then
    echo "ERROR: Not a Red Hat system." >&2; exit 1
fi
rhel_ver=$(rpm -E '%{rhel}' 2>/dev/null || echo "unknown")
if [[ "$rhel_ver" != "8" ]]; then
    flag_warn "Expected RHEL 8; detected RHEL ${rhel_ver}. Results may be inaccurate."
fi

echo "RHEL 8 -> RHEL 9 Migration Readiness Assessment"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Host: $(hostname -f 2>/dev/null || hostname)"
echo "Release: $(cat /etc/redhat-release 2>/dev/null)"

# ── Section 1: Subscription ─────────────────────────────────────────────────
section "1. Subscription and Content Access"

if command -v subscription-manager &>/dev/null; then
    overall=$(subscription-manager status 2>/dev/null | grep -i "overall status" | awk -F: '{print $2}' | xargs || echo "unknown")
    if echo "$overall" | grep -qi "current\|disabled"; then
        ok "Subscription status: $overall"
    else
        flag_fail "Subscription status: $overall -- Leapp requires active subscription"
    fi

    rhel9_repos=$(subscription-manager repos --list 2>/dev/null | grep -c "rhel-9" || echo 0)
    if [[ "$rhel9_repos" -gt 0 ]]; then
        ok "RHEL 9 repository entitlements found ($rhel9_repos repos)"
    else
        flag_warn "No RHEL 9 repositories found -- may need RHEL 9 entitlement"
    fi
else
    flag_fail "subscription-manager not found"
fi

# ── Section 2: Hardware Compatibility ────────────────────────────────────────
section "2. Kernel and Hardware Compatibility"

info "Running kernel: $(uname -r)"

arch=$(uname -m)
if [[ "$arch" == "x86_64" || "$arch" == "aarch64" || "$arch" == "ppc64le" || "$arch" == "s390x" ]]; then
    ok "Architecture $arch is supported for RHEL 9"
else
    flag_fail "Architecture $arch may not be supported for RHEL 9"
fi

# Root filesystem space
root_free_kb=$(df / | awk 'NR==2 {print $4}')
root_free_mb=$((root_free_kb / 1024))
if [[ "$root_free_kb" -gt 2097152 ]]; then
    ok "Root filesystem free space: ${root_free_mb} MB"
else
    flag_warn "Root filesystem free space may be insufficient: ${root_free_mb} MB (recommend >= 2 GB)"
fi

# Boot space
boot_free_kb=$(df /boot 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)
if [[ "$boot_free_kb" -gt 51200 ]]; then
    ok "/boot free space: $((boot_free_kb/1024)) MB"
else
    flag_fail "/boot free space too low: $((boot_free_kb/1024)) MB -- Leapp needs >= 50 MB"
fi

# ── Section 3: Deprecated Features ──────────────────────────────────────────
section "3. Deprecated Features in Active Use"

# Python 2
if command -v python2 &>/dev/null || rpm -q python2 &>/dev/null 2>/dev/null; then
    flag_warn "python2 installed -- RHEL 9 does not ship Python 2"
fi

if [[ -f /usr/bin/python ]]; then
    py_target=$(readlink -f /usr/bin/python 2>/dev/null || echo "unknown")
    if echo "$py_target" | grep -q "python2"; then
        flag_fail "/usr/bin/python points to python2 -- must update to python3"
    else
        ok "/usr/bin/python -> $py_target"
    fi
fi

# Legacy network scripts
if [[ -d /etc/sysconfig/network-scripts ]] && ls /etc/sysconfig/network-scripts/ifcfg-* &>/dev/null 2>/dev/null; then
    ifcfg_count=$(ls /etc/sysconfig/network-scripts/ifcfg-* 2>/dev/null | grep -v "ifcfg-lo" | wc -l)
    if [[ "$ifcfg_count" -gt 0 ]]; then
        flag_warn "$ifcfg_count ifcfg network script(s) found -- ifcfg support deprecated in RHEL 9"
    fi
else
    ok "No legacy ifcfg network scripts found"
fi

# iptables direct rules
if command -v iptables &>/dev/null; then
    ipt_rules=$(iptables -S 2>/dev/null | grep -v "^-P" | wc -l || echo 0)
    if [[ "$ipt_rules" -gt 0 ]]; then
        flag_warn "$ipt_rules iptables rule(s) found outside firewalld -- review before upgrade"
    else
        ok "No direct iptables rules detected"
    fi
fi

# VDO volumes
if command -v vdo &>/dev/null || lsblk -t 2>/dev/null | grep -q vdo; then
    flag_warn "VDO volumes detected -- verify LVM-VDO compatibility in RHEL 9"
fi

# ── Section 4: Package Inventory ─────────────────────────────────────────────
section "4. Key Package and Service Inventory"

check_pkg() {
    local pkg=$1 label=${2:-$1}
    if rpm -q "$pkg" &>/dev/null 2>/dev/null; then
        ver=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null)
        ok "$label installed: $ver"
    else
        info "$label not installed"
    fi
}
check_pkg leapp "Leapp upgrade tool"
check_pkg leapp-repository "Leapp repository"
check_pkg python3 "Python 3"
check_pkg chrony "chrony (NTP)"
check_pkg NetworkManager "NetworkManager"
check_pkg podman "Podman"

# Deprecated services
for svc in docker ntpd network; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        flag_warn "Service '$svc' is active -- deprecated/removed in RHEL 9"
    fi
done

# ── Section 5: Leapp Prerequisites ──────────────────────────────────────────
section "5. Leapp Prerequisites"

if rpm -q leapp &>/dev/null 2>/dev/null; then
    ok "Leapp installed: $(rpm -q --queryformat '%{VERSION}' leapp 2>/dev/null)"

    if [[ -f /var/log/leapp/leapp-report.txt ]]; then
        inhibitors=$(grep -c "inhibitor" /var/log/leapp/leapp-report.txt 2>/dev/null || echo 0)
        if [[ "$inhibitors" -gt 0 ]]; then
            flag_fail "$inhibitors inhibitor(s) in leapp report -- must be resolved"
        else
            ok "No inhibitors in last leapp report"
        fi
    else
        info "No leapp preupgrade report found -- run: leapp preupgrade"
    fi
else
    flag_warn "Leapp not installed -- install: dnf install leapp leapp-repository"
fi

# CDN connectivity
if curl -s --max-time 5 https://subscription.rhsm.redhat.com/subscription &>/dev/null; then
    ok "RHSM connectivity: reachable"
else
    flag_warn "RHSM endpoint not reachable -- Leapp requires CDN access"
fi

# ── Section 6: Summary ──────────────────────────────────────────────────────
section "6. Readiness Summary"

echo ""
echo "  Blockers : $ISSUES"
echo "  Warnings : $WARNINGS"
echo ""
if [[ "$ISSUES" -eq 0 && "$WARNINGS" -eq 0 ]]; then
    echo "  System appears ready for Leapp preupgrade assessment."
    echo "  Next step: leapp preupgrade"
elif [[ "$ISSUES" -eq 0 ]]; then
    echo "  $WARNINGS warning(s) require review before upgrade."
    echo "  Next step: Address warnings, then run: leapp preupgrade"
else
    echo "  $ISSUES blocker(s) must be resolved before upgrade."
    echo "  Next step: Resolve all [FAIL] items, then run: leapp preupgrade"
fi
echo ""
echo "  Reference: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/upgrading_from_rhel_8_to_rhel_9"
echo ""
echo "$SEP"
echo "  Migration Assessment Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
