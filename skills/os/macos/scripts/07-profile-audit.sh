#!/bin/bash
# ============================================================================
# macOS - MDM Profile Audit
# Version : 1.0.0
# Targets : macOS 14+ (Sonoma and later)
# Safety  : Read-only. No modifications to system configuration.
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
echo "  macOS MDM PROFILE AUDIT"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "$SEP"

# Check for root/sudo
if [[ $EUID -ne 0 ]]; then
    echo "  [INFO] Running without sudo. Some profile details may be unavailable."
    echo "         For full output, run: sudo $0"
    echo ""
fi

# -- Section 1: MDM Enrollment Status ----------------------------------------
section "SECTION 1 - MDM Enrollment Status"

ENROLL=$(sudo profiles status -type enrollment 2>/dev/null || profiles status -type enrollment 2>/dev/null || echo "Unable to query enrollment")
echo "$ENROLL" | sed 's/^/  /'

# -- Section 2: Bootstrap Token -----------------------------------------------
section "SECTION 2 - Bootstrap Token"

BT=$(sudo profiles status -type bootstraptoken 2>/dev/null || echo "Unable to query (requires sudo)")
echo "$BT" | sed 's/^/  /'

# -- Section 3: Installed Configuration Profiles -----------------------------
section "SECTION 3 - Installed Configuration Profiles"

PROFILES_OUTPUT=$(sudo profiles show -all 2>/dev/null || profiles show 2>/dev/null || echo "Unable to list profiles")
if [[ -n "$PROFILES_OUTPUT" ]] && ! echo "$PROFILES_OUTPUT" | grep -q "no profiles"; then
    echo "$PROFILES_OUTPUT" | sed 's/^/  /'
else
    echo "  No configuration profiles installed"
fi

# -- Section 4: Profile Summary (types and identifiers) ----------------------
section "SECTION 4 - Profile Summary"

sudo profiles show -type configuration 2>/dev/null \
    | grep -E "profileIdentifier|profileDisplayName|profileOrganization" \
    | sed 's/^/  /' \
    || echo "  Unable to enumerate configuration profiles"

# -- Section 5: Restrictions -------------------------------------------------
section "SECTION 5 - Active Restrictions"

RESTRICTIONS=$(sudo defaults read /Library/Managed\ Preferences/com.apple.applicationaccess 2>/dev/null || echo "")
if [[ -n "$RESTRICTIONS" ]]; then
    echo "  com.apple.applicationaccess managed preferences:"
    echo "$RESTRICTIONS" | head -40 | sed 's/^/    /'
else
    echo "  No managed application access restrictions found"
fi

# -- Section 6: Certificates -------------------------------------------------
section "SECTION 6 - MDM-Installed Certificates"

# List certificates from System keychain that may be MDM-related
CERTS=$(security find-certificate -a /Library/Keychains/System.keychain 2>/dev/null \
    | grep "labl" | sed 's/.*<blob>=//' | sort -u)
if [[ -n "$CERTS" ]]; then
    echo "  System keychain certificates:"
    echo "$CERTS" | head -20 | sed 's/^/    /'
else
    echo "  No certificates found in System keychain"
fi

# -- Section 7: Platform SSO State -------------------------------------------
section "SECTION 7 - Platform SSO"

if command -v app-sso &>/dev/null; then
    echo "  SSO extensions:"
    app-sso -l 2>/dev/null | sed 's/^/    /' || echo "    Unable to query SSO extensions"

    echo ""
    echo "  Platform SSO state:"
    app-sso platform -s 2>/dev/null | sed 's/^/    /' || echo "    Platform SSO not configured or not available"
else
    echo "  app-sso command not available"
fi

# -- Section 8: Supervised Status --------------------------------------------
section "SECTION 8 - Supervision and ADE"

SUPERVISED=$(sudo profiles status -type enrollment 2>/dev/null | grep -i "supervised" || echo "Unknown")
echo "  $SUPERVISED"

ADE=$(sudo profiles status -type enrollment 2>/dev/null | grep -i "DEP\|Automated" || echo "Unknown")
echo "  $ADE"

# -- Section 9: MDM Server Info ----------------------------------------------
section "SECTION 9 - MDM Server"

SERVER_URL=$(sudo profiles show -type enrollment 2>/dev/null \
    | grep -i "ServerURL\|MDMServiceURL" | head -1 || echo "")
if [[ -n "$SERVER_URL" ]]; then
    echo "  $SERVER_URL"
else
    echo "  MDM server URL not found (device may not be enrolled)"
fi

echo ""
echo "$SEP"
echo "  Profile audit complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
