#!/usr/bin/env bash
# ============================================================================
# SLES - Registration Status
#
# Purpose : Detailed SUSEConnect registration status including base
#           system, modules, extensions, RMT connectivity, and
#           subscription health.
# Version : 1.0.0
# Targets : SLES 15 SP5+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Base System Registration
#   2. Registered Modules and Extensions
#   3. Available but Unregistered Products
#   4. Repository Credential Verification
#   5. RMT/SCC Connectivity
#   6. Subscription Details
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
echo "  SLES Registration Status - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"

# ── Section 1: Base System Registration ─────────────────────────────────────
section "SECTION 1 - Base System Registration"

if ! command -v SUSEConnect &>/dev/null; then
    echo "  [ERROR] SUSEConnect not installed"
    exit 1
fi

echo "  SUSEConnect version: $(SUSEConnect --version 2>/dev/null || echo 'unknown')"
echo ""

STATUS_OUTPUT=$(SUSEConnect --status 2>/dev/null || echo "FAILED")
if [[ "$STATUS_OUTPUT" == "FAILED" ]]; then
    echo "  [ERROR] SUSEConnect --status failed -- system may not be registered"
    echo "  Register with: SUSEConnect --regcode <ACTIVATION_KEY>"
else
    echo "$STATUS_OUTPUT" | head -20 | sed 's/^/  /'
fi

# ── Section 2: Registered Products ──────────────────────────────────────────
section "SECTION 2 - Registered Modules and Extensions"

echo "  Activated products:"
SUSEConnect --status 2>/dev/null | grep -E '"identifier"|"status"|"version"' \
    | sed 's/^/    /' || echo "    Unable to parse registration status"

echo ""
echo "  Product list (human-readable):"
SUSEConnect --list-extensions 2>/dev/null | grep "Activated" \
    | sed 's/^/    /' || echo "    No activated extensions found"

# ── Section 3: Available but Unregistered ────────────────────────────────────
section "SECTION 3 - Available but Unregistered Products"

SUSEConnect --list-extensions 2>/dev/null | grep "Not Activated" \
    | head -20 | sed 's/^/    /' || echo "    Unable to list available products"

# ── Section 4: Repository Credentials ────────────────────────────────────────
section "SECTION 4 - Repository Credential Verification"

CRED_DIR="/etc/zypp/credentials.d"
if [[ -d "$CRED_DIR" ]]; then
    cred_count=$(ls -1 "$CRED_DIR" 2>/dev/null | wc -l)
    echo "  Credential files in $CRED_DIR: $cred_count"
    ls -la "$CRED_DIR" 2>/dev/null | head -20 | sed 's/^/    /'
else
    echo "  [WARN] $CRED_DIR not found"
fi

echo ""
echo "  System credentials file:"
if [[ -f /etc/zypp/credentials.d/SCCcredentials ]]; then
    echo "    SCCcredentials: present"
    stat -c "    Permissions: %a  Owner: %U:%G  Modified: %y" \
        /etc/zypp/credentials.d/SCCcredentials 2>/dev/null || true
else
    echo "    SCCcredentials: NOT FOUND -- system may not be registered"
fi

# ── Section 5: RMT/SCC Connectivity ─────────────────────────────────────────
section "SECTION 5 - RMT/SCC Connectivity"

# Determine registration target
REG_URL=$(grep -r "url" /etc/zypp/services.d/ 2>/dev/null | head -1 | grep -oP 'https?://[^/]+' || echo "")
if [[ -z "$REG_URL" ]]; then
    REG_URL="https://scc.suse.com"
    echo "  Registration target: SCC (SUSE Customer Center)"
else
    echo "  Registration target: $REG_URL (likely RMT)"
fi

echo ""
echo "  Connectivity test:"
if command -v curl &>/dev/null; then
    http_code=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 10 "$REG_URL" 2>/dev/null || echo "FAILED")
    echo "    $REG_URL -> HTTP $http_code"
    if [[ "$http_code" =~ ^[23] ]]; then
        echo "    [OK]   Registration server reachable"
    else
        echo "    [WARN] Registration server may not be reachable"
    fi
else
    echo "    curl not available -- cannot test connectivity"
fi

# ── Section 6: Subscription Details ──────────────────────────────────────────
section "SECTION 6 - Subscription Details"

echo "  OS release:"
cat /etc/os-release 2>/dev/null | grep -E "^(NAME|VERSION|VERSION_ID|PRETTY_NAME)" \
    | sed 's/^/    /'

echo ""
echo "  Registered repositories (count and status):"
zypper repos 2>/dev/null | tail -n +3 | awk -F'|' '{
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3);
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4);
    printf "    %-50s enabled=%s\n", $3, $4
}' | head -30 || echo "    Unable to list repos"

echo ""
total_repos=$(zypper repos 2>/dev/null | tail -n +3 | wc -l)
enabled_repos=$(zypper repos 2>/dev/null | grep -c "Yes" || echo "0")
echo "  Total repos: $total_repos  Enabled: $enabled_repos"

echo ""
echo "$SEP"
echo "  Registration Status Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
