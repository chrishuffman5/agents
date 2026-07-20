#!/bin/bash
# ============================================================================
# macOS - Network Diagnostics
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
echo "  macOS NETWORK DIAGNOSTICS"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "$SEP"

# -- Section 1: Network Services ---------------------------------------------
section "SECTION 1 - Network Services"

networksetup -listallnetworkservices 2>/dev/null | sed 's/^/  /' || echo "  Unable to list services"

echo ""
echo "  Service order:"
networksetup -listnetworkserviceorder 2>/dev/null | head -20 | sed 's/^/    /'

# -- Section 2: Active Interface Info ----------------------------------------
section "SECTION 2 - Active Interface Details"

# Get the primary interface
PRIMARY=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
if [[ -n "$PRIMARY" ]]; then
    echo "  Primary interface: $PRIMARY"
    ifconfig "$PRIMARY" 2>/dev/null | sed 's/^/    /'
else
    echo "  Unable to determine primary interface"
fi

echo ""
echo "  Wi-Fi info:"
networksetup -getinfo "Wi-Fi" 2>/dev/null | sed 's/^/    /' || echo "    Wi-Fi service not found"

# -- Section 3: DNS Configuration --------------------------------------------
section "SECTION 3 - DNS Configuration"

echo "  scutil --dns (summary):"
scutil --dns 2>/dev/null | grep -E "nameserver|domain|search" | sort -u | head -20 | sed 's/^/    /'

echo ""
echo "  Configured DNS servers per service:"
for svc in $(networksetup -listallnetworkservices 2>/dev/null | tail -n +2); do
    DNS=$(networksetup -getdnsservers "$svc" 2>/dev/null | head -5)
    if ! echo "$DNS" | grep -q "aren't any"; then
        echo "    $svc: $DNS"
    fi
done

# -- Section 4: DNS Resolution Test ------------------------------------------
section "SECTION 4 - DNS Resolution Test"

for host in apple.com google.com; do
    RESULT=$(dig +short "$host" 2>/dev/null | head -1 || echo "FAILED")
    echo "  $host => $RESULT"
done

# -- Section 5: Connectivity Test --------------------------------------------
section "SECTION 5 - Connectivity Test"

if ping -c 2 -t 5 8.8.8.8 &>/dev/null; then
    echo "  [OK]   Internet reachable (8.8.8.8)"
else
    echo "  [FAIL] Cannot reach 8.8.8.8"
fi

if ping -c 2 -t 5 apple.com &>/dev/null; then
    echo "  [OK]   DNS resolution working (apple.com)"
else
    echo "  [WARN] Cannot resolve/reach apple.com"
fi

# -- Section 6: Wi-Fi Status -------------------------------------------------
section "SECTION 6 - Wi-Fi Status"

if command -v wdutil &>/dev/null; then
    echo "  wdutil info (requires sudo for full output):"
    sudo wdutil info 2>/dev/null | head -30 | sed 's/^/    /' || echo "    Run with sudo for Wi-Fi details"
else
    echo "  wdutil not available"
fi

# Fallback: airport utility
AIRPORT="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
if [[ -x "$AIRPORT" ]]; then
    echo ""
    echo "  airport -I:"
    "$AIRPORT" -I 2>/dev/null | grep -E "SSID|BSSID|channel|RSSI|noise|lastTxRate" | sed 's/^/    /'
fi

# -- Section 7: VPN Connections -----------------------------------------------
section "SECTION 7 - VPN Connections"

scutil --nc list 2>/dev/null | sed 's/^/  /' || echo "  No VPN connections configured"

# -- Section 8: Proxy Configuration ------------------------------------------
section "SECTION 8 - Proxy Configuration"

scutil --proxy 2>/dev/null | grep -v "^$" | head -20 | sed 's/^/  /'

# -- Section 9: Firewall Status ----------------------------------------------
section "SECTION 9 - Application Firewall"

FW_STATE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "unknown")
if echo "$FW_STATE" | grep -q "enabled"; then
    echo "  [OK]   $FW_STATE"
else
    echo "  [WARN] $FW_STATE"
fi

STEALTH=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null || echo "")
echo "  $STEALTH"

# -- Section 10: Listening Ports ---------------------------------------------
section "SECTION 10 - Listening Ports (top 20)"

netstat -an 2>/dev/null | grep LISTEN | head -20 | sed 's/^/  /' || echo "  Unable to list listening ports"

echo ""
echo "$SEP"
echo "  Network diagnostics complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
