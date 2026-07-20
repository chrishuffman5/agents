#!/usr/bin/env bash
# ============================================================================
# Rocky Linux / AlmaLinux - Repository Health Check
#
# Purpose : Repository config, GPG keys, enabled repos, mirror status,
#           EPEL and ELRepo health verification.
# Version : 1.0.0
# Targets : Rocky Linux 8+ / AlmaLinux 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Repository Overview
#   2. GPG Key Verification
#   3. Repo Configuration Audit
#   4. Mirror Connectivity Test
#   5. DNF Cache and Metadata
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }
pass() { echo "  [PASS] $1"; }
warn() { echo "  [WARN] $1"; }
fail() { echo "  [FAIL] $1"; }

# -- Section 1: Repository Overview ---------------------------------------
section "SECTION 1 - Repository Overview"

echo "  Enabled Repositories:"
dnf repolist 2>/dev/null | sed 's/^/  /' || echo "  Error running dnf repolist"

echo ""
echo "  All Repositories (including disabled):"
dnf repolist all 2>/dev/null | awk '{printf "  %-40s %s\n", $1, $NF}' | head -40

# -- Section 2: GPG Key Verification --------------------------------------
section "SECTION 2 - GPG Key Verification"

echo "  Installed GPG Public Keys:"
rpm -qa gpg-pubkey --qf '  %-40{SUMMARY}\n' 2>/dev/null | head -20

echo ""
echo "  GPG Key Files Present:"
ls /etc/pki/rpm-gpg/ 2>/dev/null | sed 's/^/  /'

echo ""
echo "  Expected Keys by Distro:"
source /etc/os-release 2>/dev/null || true
case "${ID:-unknown}" in
    rocky)
        [[ -f /etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial ]] && \
            pass "Rocky official GPG key present" || \
            fail "Rocky official GPG key MISSING"
        ;;
    almalinux)
        ls /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux* &>/dev/null && \
            pass "AlmaLinux GPG key(s) present" || \
            fail "AlmaLinux GPG key MISSING"
        ;;
    *)
        warn "Unknown distro ID: ${ID:-unknown}"
        ;;
esac

# -- Section 3: Repo Configuration Audit ----------------------------------
section "SECTION 3 - Repo Configuration Audit"

echo "  Checking repo files in /etc/yum.repos.d/:"
echo ""

for repofile in /etc/yum.repos.d/*.repo; do
    [[ -f "$repofile" ]] || continue
    echo "  File: $(basename $repofile)"

    GPGCHECK_DISABLED=$(grep -c 'gpgcheck=0' "$repofile" 2>/dev/null || echo 0)
    (( GPGCHECK_DISABLED > 0 )) && warn "  gpgcheck=0 found in $(basename $repofile)" || \
        pass "  gpgcheck enabled"

    RH_URL=$(grep -c 'cdn.redhat.com\|subscription.rhsm.redhat.com' "$repofile" 2>/dev/null || echo 0)
    (( RH_URL > 0 )) && fail "  Red Hat CDN URL found in $(basename $repofile)" || \
        pass "  No Red Hat CDN URLs"

    ENABLED=$(grep -c '^enabled=1' "$repofile" 2>/dev/null || echo 0)
    echo "  Enabled sections: $ENABLED"
    echo ""
done

# -- Section 4: Mirror Connectivity Test -----------------------------------
section "SECTION 4 - Mirror Connectivity Test"

echo "  Testing connectivity to distro mirrors..."
echo ""

source /etc/os-release 2>/dev/null || true

case "${ID:-unknown}" in
    rocky)
        MIRRORS=(
            "dl.rockylinux.org"
            "mirrors.rockylinux.org"
        )
        ;;
    almalinux)
        MIRRORS=(
            "repo.almalinux.org"
            "mirrors.almalinux.org"
        )
        ;;
    *)
        MIRRORS=("mirror.centos.org")
        ;;
esac

for mirror in "${MIRRORS[@]}"; do
    if curl -sf --max-time 10 "https://${mirror}" -o /dev/null 2>/dev/null; then
        pass "Reachable: $mirror"
    else
        warn "Unreachable or slow: $mirror"
    fi
done

echo ""
echo "  EPEL Mirror:"
if curl -sf --max-time 10 "https://dl.fedoraproject.org/pub/epel/" -o /dev/null 2>/dev/null; then
    pass "EPEL mirror reachable: dl.fedoraproject.org"
else
    warn "EPEL mirror unreachable"
fi

# -- Section 5: DNF Cache and Metadata ------------------------------------
section "SECTION 5 - DNF Cache and Metadata"

echo "  DNF Configuration:"
grep -E '^(best|skip_if_unavailable|fastestmirror|install_weak_deps|keepcache)' \
    /etc/dnf/dnf.conf 2>/dev/null | sed 's/^/  /' || echo "  /etc/dnf/dnf.conf: not found"

echo ""
CACHE_SIZE=$(du -sh /var/cache/dnf 2>/dev/null | awk '{print $1}' || echo "unknown")
echo "  Cache Size    : $CACHE_SIZE"

echo ""
echo "  Last Metadata Refresh:"
ls -la /var/cache/dnf/*/repomd.xml 2>/dev/null | sort -k6,7 | tail -5 | \
    awk '{printf "  %-30s %s %s %s\n", $9, $6, $7, $8}' || echo "  No cache metadata found"

echo ""
echo "  Module Stream Status:"
dnf module list --enabled 2>/dev/null | head -20 | sed 's/^/  /' || \
    echo "  No modules enabled or dnf modules unavailable"

echo ""
echo "$SEP"
echo "  Repo health check complete"
echo "$SEP"
