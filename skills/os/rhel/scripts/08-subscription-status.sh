#!/usr/bin/env bash
# ============================================================================
# RHEL - Subscription Status
#
# Purpose : Report subscription validity, enabled repos, entitlements,
#           SCA mode, Insights registration, and Satellite connectivity.
# Version : 1.0.0
# Targets : RHEL 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. System Identity
#   2. Subscription Status
#   3. Content Access Mode
#   4. Enabled Repositories
#   5. Entitlements
#   6. Insights Registration
#   7. Satellite/CDN Connectivity
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

echo "RHEL Subscription Status Report"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"

# ── Section 1: System Identity ──────────────────────────────────────────────
section "1. System Identity"

echo "  Release: $(cat /etc/redhat-release 2>/dev/null || echo 'unknown')"

if command -v subscription-manager &>/dev/null; then
    identity=$(subscription-manager identity 2>/dev/null || echo "Not registered")
    echo "$identity" | sed 's/^/  /'
else
    echo "  [WARN] subscription-manager not installed"
    echo ""
    echo "$SEP"
    echo "  Cannot complete subscription audit without subscription-manager"
    echo "$SEP"
    exit 0
fi

# ── Section 2: Subscription Status ──────────────────────────────────────────
section "2. Subscription Status"

sub_status=$(subscription-manager status 2>/dev/null || echo "Unable to determine status")
echo "$sub_status" | sed 's/^/  /'

# ── Section 3: Content Access Mode ──────────────────────────────────────────
section "3. Content Access Mode"

# Check for SCA
sca_indicator=$(subscription-manager status 2>/dev/null | grep -i "content access\|simple content" || true)
if [[ -n "$sca_indicator" ]]; then
    echo "  [OK]   Simple Content Access (SCA) mode detected"
    echo "  $sca_indicator"
else
    # Check consumed subscriptions (classic mode indicator)
    consumed=$(subscription-manager list --consumed 2>/dev/null | grep -c "Subscription Name" || echo 0)
    if [[ "$consumed" -gt 0 ]]; then
        echo "  [INFO] Classic entitlement mode -- $consumed subscription(s) attached"
    else
        echo "  [WARN] No subscriptions attached and SCA not detected"
    fi
fi

# rhsm.conf content access setting
if [[ -f /etc/rhsm/rhsm.conf ]]; then
    echo ""
    echo "  RHSM configuration:"
    grep -E "hostname|baseurl|manage_repos" /etc/rhsm/rhsm.conf 2>/dev/null | grep -v "^#" | sed 's/^/    /'
fi

# ── Section 4: Enabled Repositories ─────────────────────────────────────────
section "4. Enabled Repositories"

echo "  subscription-manager repos:"
subscription-manager repos --list-enabled 2>/dev/null | grep "Repo ID" | sed 's/^/    /' || echo "    Unable to list"

echo ""
echo "  dnf repolist:"
dnf repolist 2>/dev/null | sed 's/^/    /'

echo ""
repo_count=$(dnf repolist 2>/dev/null | tail -n +2 | wc -l)
echo "  Total enabled repos: $repo_count"

# Check for key repos
for repo_pattern in "baseos" "appstream"; do
    if dnf repolist 2>/dev/null | grep -qi "$repo_pattern"; then
        echo "  [OK]   $repo_pattern repository enabled"
    else
        echo "  [WARN] $repo_pattern repository not found"
    fi
done

# ── Section 5: Entitlements ─────────────────────────────────────────────────
section "5. Entitlements"

echo "  Consumed subscriptions:"
consumed_list=$(subscription-manager list --consumed 2>/dev/null | grep -A2 "Subscription Name\|Expires\|Status" || echo "None listed")
echo "$consumed_list" | head -30 | sed 's/^/    /'

# Check for expiring subscriptions
expiring=$(subscription-manager list --consumed 2>/dev/null | grep -A1 "Expires" | grep -v "^--$" || true)
if echo "$expiring" | grep -qi "$(date +%Y)"; then
    echo ""
    echo "  [WARN] Subscriptions expiring this year detected -- review renewal"
fi

# ── Section 6: Insights Registration ────────────────────────────────────────
section "6. Insights Registration"

if command -v insights-client &>/dev/null; then
    echo "  insights-client version: $(rpm -q insights-client 2>/dev/null)"
    insights-client --status 2>/dev/null | sed 's/^/  /' || echo "  Unable to query status"
else
    echo "  [INFO] insights-client not installed"
    echo "  Install: dnf install insights-client && insights-client --register"
fi

# ── Section 7: Satellite/CDN Connectivity ───────────────────────────────────
section "7. Satellite/CDN Connectivity"

# Determine content source
content_host=$(grep "^hostname" /etc/rhsm/rhsm.conf 2>/dev/null | awk -F= '{print $2}' | xargs)
if [[ -n "$content_host" ]]; then
    echo "  Content source: $content_host"

    if echo "$content_host" | grep -qi "subscription.rhsm.redhat.com"; then
        echo "  [INFO] Connected directly to Red Hat CDN"
    else
        echo "  [INFO] Connected to Satellite or custom RHSM server"
    fi

    # Test connectivity
    if curl -s --connect-timeout 5 -o /dev/null "https://$content_host" 2>/dev/null; then
        echo "  [OK]   HTTPS connectivity to $content_host"
    else
        echo "  [WARN] Cannot reach $content_host over HTTPS"
    fi
else
    echo "  [WARN] No hostname found in /etc/rhsm/rhsm.conf"
fi

# Entitlement certificate check
cert_count=$(ls /etc/pki/entitlement/*.pem 2>/dev/null | wc -l || echo 0)
echo ""
echo "  Entitlement certificates: $cert_count"

consumer_cert="/etc/pki/consumer/cert.pem"
if [[ -f "$consumer_cert" ]]; then
    echo "  [OK]   Consumer identity certificate present"
    expiry=$(openssl x509 -in "$consumer_cert" -enddate -noout 2>/dev/null | awk -F= '{print $2}')
    echo "  Consumer cert expires: ${expiry:-unknown}"
else
    echo "  [WARN] Consumer identity certificate not found -- system may not be registered"
fi

echo ""
echo "$SEP"
echo "  Subscription Status Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
