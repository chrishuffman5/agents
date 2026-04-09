#!/bin/bash
# ============================================================================
# macOS - Security Audit
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
echo "  macOS SECURITY AUDIT"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "$SEP"

PASS=0
WARN=0
FAIL=0

check_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
check_warn() { echo "  [WARN] $1"; WARN=$((WARN + 1)); }
check_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

# -- Section 1: FileVault ----------------------------------------------------
section "SECTION 1 - FileVault Encryption"

FV_STATUS=$(fdesetup status 2>/dev/null || echo "Unknown")
if echo "$FV_STATUS" | grep -q "On"; then
    check_pass "FileVault is enabled"
elif echo "$FV_STATUS" | grep -q "Off"; then
    check_fail "FileVault is disabled — data at rest is unencrypted"
else
    check_warn "FileVault status: $FV_STATUS"
fi

# -- Section 2: Gatekeeper ---------------------------------------------------
section "SECTION 2 - Gatekeeper"

GK_STATUS=$(spctl --status 2>/dev/null || echo "unknown")
if echo "$GK_STATUS" | grep -q "enabled"; then
    check_pass "Gatekeeper is enabled"
else
    check_fail "Gatekeeper is disabled — unsigned apps can run"
fi

# -- Section 3: SIP ----------------------------------------------------------
section "SECTION 3 - System Integrity Protection"

SIP_STATUS=$(csrutil status 2>&1)
if echo "$SIP_STATUS" | grep -q "enabled"; then
    check_pass "SIP is enabled"
else
    check_fail "SIP is disabled — system files are unprotected"
fi

# -- Section 4: Application Firewall -----------------------------------------
section "SECTION 4 - Application Firewall"

FW_STATE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "unknown")
if echo "$FW_STATE" | grep -q "enabled"; then
    check_pass "Application Firewall is enabled"
else
    check_warn "Application Firewall is disabled"
fi

STEALTH=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null || echo "")
if echo "$STEALTH" | grep -q "enabled"; then
    check_pass "Stealth mode is enabled"
else
    check_warn "Stealth mode is disabled"
fi

# -- Section 5: XProtect -----------------------------------------------------
section "SECTION 5 - XProtect"

XPROTECT_PLIST="/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist"
if [[ -f "$XPROTECT_PLIST" ]]; then
    XP_VER=$(defaults read "$XPROTECT_PLIST" CFBundleShortVersionString 2>/dev/null || echo "unknown")
    check_pass "XProtect installed (version: $XP_VER)"
else
    check_warn "XProtect bundle not found at expected path"
fi

# -- Section 6: Remote Login (SSH) -------------------------------------------
section "SECTION 6 - Remote Login (SSH)"

SSH_STATUS=$(sudo systemsetup -getremotelogin 2>/dev/null || echo "unknown")
if echo "$SSH_STATUS" | grep -qi "off"; then
    check_pass "Remote Login (SSH) is disabled"
elif echo "$SSH_STATUS" | grep -qi "on"; then
    check_warn "Remote Login (SSH) is enabled — ensure access is restricted"
else
    echo "  [INFO] $SSH_STATUS"
fi

# -- Section 7: Screen Sharing and Remote Management --------------------------
section "SECTION 7 - Sharing Services"

for svc in "Screen Sharing" "Remote Management" "File Sharing" "Remote Apple Events"; do
    PID=$(pgrep -f "$svc" 2>/dev/null || echo "")
    if [[ -n "$PID" ]]; then
        check_warn "$svc appears to be running"
    else
        check_pass "$svc is not running"
    fi
done

# -- Section 8: Guest Account ------------------------------------------------
section "SECTION 8 - Guest Account"

GUEST=$(defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null || echo "unknown")
if [[ "$GUEST" == "0" ]] || [[ "$GUEST" == "false" ]]; then
    check_pass "Guest account is disabled"
elif [[ "$GUEST" == "1" ]] || [[ "$GUEST" == "true" ]]; then
    check_warn "Guest account is enabled"
else
    echo "  [INFO] Guest account status: $GUEST"
fi

# -- Section 9: Auto-Update Settings -----------------------------------------
section "SECTION 9 - Automatic Update Settings"

AUTO_CHECK=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo "unknown")
AUTO_DL=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload 2>/dev/null || echo "unknown")
CRITICAL=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall 2>/dev/null || echo "unknown")

[[ "$AUTO_CHECK" == "1" ]] && check_pass "Automatic update check enabled" || check_warn "Automatic update check: $AUTO_CHECK"
[[ "$AUTO_DL" == "1" ]] && check_pass "Automatic download enabled" || check_warn "Automatic download: $AUTO_DL"
[[ "$CRITICAL" == "1" ]] && check_pass "Critical update auto-install enabled" || check_warn "Critical update auto-install: $CRITICAL"

# -- Section 10: Screen Lock -------------------------------------------------
section "SECTION 10 - Screen Lock"

ASK_PWD=$(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "unknown")
ASK_DELAY=$(defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo "unknown")

if [[ "$ASK_PWD" == "1" ]]; then
    check_pass "Password required after screensaver/sleep"
else
    check_warn "Password NOT required after screensaver/sleep"
fi

if [[ "$ASK_DELAY" == "0" ]]; then
    check_pass "Password required immediately (no delay)"
else
    check_warn "Password delay: ${ASK_DELAY}s (recommend 0)"
fi

# -- Summary ------------------------------------------------------------------
section "SUMMARY"

TOTAL=$((PASS + WARN + FAIL))
echo "  Total checks : $TOTAL"
echo "  Passed       : $PASS"
echo "  Warnings     : $WARN"
echo "  Failed       : $FAIL"

echo ""
echo "$SEP"
echo "  Security audit complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
