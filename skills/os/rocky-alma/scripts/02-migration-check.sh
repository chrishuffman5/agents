#!/usr/bin/env bash
# ============================================================================
# Rocky Linux / AlmaLinux - Migration Status Check
#
# Purpose : CentOS/RHEL migration status, ELevate availability,
#           migrate2rocky compatibility, repo health post-migration.
# Version : 1.0.0
# Targets : Rocky Linux 8+ / AlmaLinux 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Current Distro and Migration Origin
#   2. ELevate Tool Availability
#   3. migrate2rocky Eligibility
#   4. Post-Migration Verification
#   5. Leftover Packages from Prior Distro
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }
pass() { echo "  [PASS] $1"; }
warn() { echo "  [WARN] $1"; }
fail() { echo "  [FAIL] $1"; }

# -- Section 1: Current Distro and Migration Origin ------------------------
section "SECTION 1 - Current Distro and Migration Origin"

source /etc/os-release 2>/dev/null || true
echo "  Current OS   : ${NAME:-unknown} ${VERSION_ID:-unknown}"
echo "  Platform ID  : ${PLATFORM_ID:-unknown}"

echo ""
echo "  Migration Artifacts:"
[[ -f /var/log/migrate2rocky.log ]] && {
    pass "migrate2rocky.log found — Rocky migration was performed"
    tail -5 /var/log/migrate2rocky.log | sed 's/^/    /'
}

ls /var/log/leapp/ &>/dev/null && {
    pass "Leapp logs found — ELevate migration was performed"
    ls /var/log/leapp/ | sed 's/^/    /'
}

[[ ! -f /var/log/migrate2rocky.log ]] && ! ls /var/log/leapp/ &>/dev/null && \
    echo "  No migration logs detected (may be fresh install)"

# -- Section 2: ELevate Availability --------------------------------------
section "SECTION 2 - ELevate Availability"

echo "  ELevate (AlmaLinux project) — major version upgrades"
echo "  Supported targets as of 2026: AlmaLinux, CentOS Stream, Oracle Linux"
echo "  Note: Rocky Linux support removed from ELevate as of 2025-11-03"
echo ""

rpm -q leapp 2>/dev/null && {
    pass "leapp installed: $(rpm -q leapp)"
    leapp --version 2>/dev/null && true
} || echo "  leapp: not installed"

rpm -q leapp-data-almalinux 2>/dev/null && \
    pass "leapp-data-almalinux installed" || \
    echo "  leapp-data-almalinux: not installed"

[[ -f /var/log/leapp/leapp-report.txt ]] && {
    echo ""
    echo "  ELevate Pre-Upgrade Report Summary:"
    grep -E 'Risk Factor|Title' /var/log/leapp/leapp-report.txt | head -20 | sed 's/^/    /'
}

# -- Section 3: migrate2rocky Eligibility ----------------------------------
section "SECTION 3 - migrate2rocky Eligibility"

echo "  migrate2rocky: converts EL8/EL9 systems to Rocky Linux (same version)"
echo ""

EL_VER="${VERSION_ID%%.*}"
[[ "$EL_VER" =~ ^[89]$ ]] && pass "EL version $EL_VER is supported by migrate2rocky" || \
    warn "EL version $EL_VER may not be supported; check Rocky docs"

echo ""
echo "  Disk Space Requirements:"
for mountpoint in /usr /var /boot; do
    available=$(df -BM "$mountpoint" 2>/dev/null | awk 'NR==2{gsub("M","",$4); print $4}')
    case $mountpoint in
        /usr)  min=250 ;;
        /var)  min=1500 ;;
        /boot) min=50 ;;
    esac
    if [[ -n "$available" ]] && (( available >= min )); then
        pass "$mountpoint: ${available}MB available (min ${min}MB)"
    else
        fail "$mountpoint: ${available:-unknown}MB available (need ${min}MB)"
    fi
done

echo ""
echo "  Problematic Package Check:"
for pkg in plesk cpanel directadmin cloudlinux-release; do
    rpm -q "$pkg" &>/dev/null && fail "Found $pkg — migration may fail" || \
        pass "$pkg: not installed"
done

THIRD_PARTY_KERNELS=$(rpm -qa 'kernel*' | grep -Ev 'kernel(-core|-modules|-headers|-devel|-tools)?' | grep -v "^kernel-[0-9]")
[[ -n "$THIRD_PARTY_KERNELS" ]] && warn "Non-standard kernel packages: $THIRD_PARTY_KERNELS" || \
    pass "No non-standard kernel packages detected"

# -- Section 4: Post-Migration Verification --------------------------------
section "SECTION 4 - Post-Migration Verification"

echo "  Verifying RHEL compatibility markers:"

PLAT=$(grep PLATFORM_ID /etc/os-release | cut -d= -f2 | tr -d '"')
[[ "$PLAT" =~ ^platform:el ]] && pass "PLATFORM_ID is EL-compatible: $PLAT" || \
    warn "Unexpected PLATFORM_ID: $PLAT"

RH_REPOS=$(dnf repolist all 2>/dev/null | grep -c 'cdn.redhat.com' || echo 0)
(( RH_REPOS == 0 )) && pass "No Red Hat CDN repos (expected)" || \
    warn "$RH_REPOS repo(s) still pointing to Red Hat CDN"

rpm -q subscription-manager &>/dev/null && \
    warn "subscription-manager still installed — may not be needed" || \
    pass "subscription-manager absent (expected on Rocky/Alma)"

echo ""
echo "  Installed GPG Keys:"
rpm -qa gpg-pubkey --qf '  %{SUMMARY}\n' | sort

# -- Section 5: Leftover Packages from Prior Distro -----------------------
section "SECTION 5 - Leftover Packages from Prior Distro"

echo "  Scanning for packages not from Rocky/AlmaLinux repos..."
dnf list extras 2>/dev/null | tail -n +3 | head -20 | sed 's/^/  /' || \
    echo "  Unable to list extras (dnf issue)"

echo ""
echo "  CentOS-branded packages:"
rpm -qa | grep -iE 'centos' | sort | sed 's/^/  /' || echo "  None found"

echo ""
echo "$SEP"
echo "  Migration check complete"
echo "$SEP"
