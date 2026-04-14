#!/usr/bin/env bash
# ============================================================================
# Rocky Linux / AlmaLinux - System Health Dashboard
#
# Purpose : Distro detection (Rocky vs Alma vs CentOS), release, kernel,
#           repos, subscription-free status, EPEL status, SIG repos.
# Version : 1.0.0
# Targets : Rocky Linux 8+ / AlmaLinux 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Distro Identity (Rocky vs Alma vs other EL)
#   2. Kernel and Hardware
#   3. Uptime and Boot
#   4. Repository Status (no subscription needed)
#   5. EPEL and CRB Status
#   6. SIG and Extra Repos
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# -- Section 1: Distro Identity --------------------------------------------
section "SECTION 1 - Distro Identity"

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "  NAME         : ${NAME:-unknown}"
    echo "  VERSION_ID   : ${VERSION_ID:-unknown}"
    echo "  PLATFORM_ID  : ${PLATFORM_ID:-unknown}"
    echo "  ID           : ${ID:-unknown}"
    echo "  ID_LIKE      : ${ID_LIKE:-unknown}"
fi

echo ""
echo "  Release Files:"
[[ -f /etc/rocky-release ]]     && echo "  Rocky   : $(cat /etc/rocky-release)"
[[ -f /etc/almalinux-release ]] && echo "  AlmaLinux: $(cat /etc/almalinux-release)"
[[ -f /etc/centos-release ]]    && echo "  CentOS  : $(cat /etc/centos-release)"
[[ -f /etc/redhat-release ]]    && echo "  RH File : $(cat /etc/redhat-release)"

echo ""
echo "  RPM Release Package:"
rpm -q rocky-release 2>/dev/null     && echo "  -> Rocky Linux release package present"
rpm -q almalinux-release 2>/dev/null && echo "  -> AlmaLinux release package present"
rpm -q centos-release 2>/dev/null    && echo "  -> CentOS release package present"

SUBM_STATUS="OK (subscription-manager absent — expected)"
rpm -q subscription-manager &>/dev/null && SUBM_STATUS="WARNING: subscription-manager installed"
echo ""
echo "  Subscription Manager: $SUBM_STATUS"

# -- Section 2: Kernel and Hardware ----------------------------------------
section "SECTION 2 - Kernel and Hardware"
echo "  Kernel       : $(uname -r)"
echo "  Architecture : $(uname -m)"
echo "  Hostname     : $(hostname -f 2>/dev/null || hostname)"

if [[ "$(uname -m)" == "x86_64" ]]; then
    for level in v2 v3 v4; do
        if /lib64/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q "x86-64-$level (supported)"; then
            echo "  x86_64 Level : x86_64-$level supported"
        fi
    done
fi

echo ""
echo "  CPU Info:"
grep -m1 'model name' /proc/cpuinfo 2>/dev/null | sed 's/model name\s*: /  CPU Model   : /'
echo "  CPU Cores    : $(nproc)"

echo ""
echo "  Memory:"
free -h | awk '/^Mem:/{printf "  Total: %s  Used: %s  Free: %s  Available: %s\n",$2,$3,$4,$7}'

# -- Section 3: Uptime and Boot -------------------------------------------
section "SECTION 3 - Uptime and Boot"
echo "  Uptime       : $(uptime -p 2>/dev/null || uptime)"
echo "  Boot Time    : $(who -b 2>/dev/null | awk '{print $3, $4}' || echo 'unknown')"
echo "  Load Average : $(cut -d' ' -f1-3 /proc/loadavg)"

# -- Section 4: Repository Status -----------------------------------------
section "SECTION 4 - Repository Status (Subscription-Free)"
dnf repolist 2>/dev/null | head -30 || echo "  dnf not available"

echo ""
echo "  Repo Configuration Files:"
ls /etc/yum.repos.d/*.repo 2>/dev/null | while read f; do
    enabled=$(grep -c '^enabled=1' "$f" 2>/dev/null || echo 0)
    echo "  $(basename $f): ${enabled} enabled section(s)"
done

# -- Section 5: EPEL and CRB Status ---------------------------------------
section "SECTION 5 - EPEL and CRB Status"

for repo in epel epel-next crb powertools; do
    status=$(dnf repolist all 2>/dev/null | grep "^${repo}" | awk '{print $NF}' || echo "not configured")
    [[ -n "$status" ]] && echo "  $repo: $status" || echo "  $repo: not configured"
done

echo ""
rpm -q epel-release 2>/dev/null && echo "  EPEL package installed: yes" || echo "  EPEL package installed: no"

# -- Section 6: SIG and Extra Repos ---------------------------------------
section "SECTION 6 - SIG and Extra Repos"

echo "  Rocky SIG Packages:"
rpm -qa | grep -E '^rocky-release-' | sort || echo "  No Rocky SIG packages installed"

echo ""
echo "  AlmaLinux Extra Repos:"
rpm -qa | grep -E '^almalinux-release-' | sort || echo "  No AlmaLinux extra repo packages installed"

echo ""
echo "  ELRepo:"
rpm -q elrepo-release 2>/dev/null && echo "  ELRepo: installed" || echo "  ELRepo: not installed"

echo ""
echo "$SEP"
echo "  Health check complete"
echo "$SEP"
