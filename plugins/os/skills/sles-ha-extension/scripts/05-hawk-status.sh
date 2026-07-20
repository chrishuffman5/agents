#!/usr/bin/env bash
# ============================================================================
# HA Extension - HAWK Status Check
#
# Purpose : HAWK web service availability, port 7630 accessibility,
#           TLS certificate status, firewall rules, and cluster
#           connectivity through HAWK.
# Version : 1.0.0
# Targets : SLES 15+ with SUSE HA Extension
# Safety  : Read-only. No modifications to cluster configuration.
#
# Sections:
#   1. HAWK Service Status
#   2. Port 7630 Listener
#   3. HTTPS Connectivity Test
#   4. TLS Certificate Status
#   5. Firewall Check
#   6. HAWK Log Tail
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
HAWK_PORT=7630
HAWK_CERT="/etc/hawk/hawk.pem"
HAWK_KEY="/etc/hawk/hawk.key"
HAWK_LOG="/var/log/hawk/hawk.log"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

echo "$SEP"
echo "  HAWK Status Check - $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"

# ── Service Status ──────────────────────────────────────────────────────────
section "HAWK SERVICE STATUS"

systemctl status hawk --no-pager -l 2>/dev/null | head -20 | sed 's/^/  /' \
    || echo "  hawk service not found"

echo ""
echo "  Package:"
rpm -q hawk2 2>/dev/null | sed 's/^/  /' || echo "  hawk2 not installed"

# ── Port Listener ───────────────────────────────────────────────────────────
section "PORT $HAWK_PORT LISTENER STATUS"

if command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null | grep ":$HAWK_PORT" | sed 's/^/  /' \
        || echo "  Port $HAWK_PORT is NOT listening"
else
    echo "  ss not available"
fi

# ── HTTPS Test ──────────────────────────────────────────────────────────────
section "HAWK HTTPS CONNECTIVITY TEST"

local_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
hawk_url="https://${local_ip}:${HAWK_PORT}"
echo "  Testing: $hawk_url"

if command -v curl &>/dev/null; then
    http_code=$(curl -sk -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 "$hawk_url" 2>/dev/null || echo "FAILED")
    echo "  HTTP response: $http_code"
    if [[ "$http_code" =~ ^[23] ]]; then
        echo "  [OK]   HAWK is reachable"
    elif [ "$http_code" = "FAILED" ]; then
        echo "  [WARN] HAWK is NOT reachable -- check service and firewall"
    else
        echo "  [INFO] Unexpected response code: $http_code"
    fi
else
    echo "  curl not available"
fi

# ── TLS Certificate ─────────────────────────────────────────────────────────
section "TLS CERTIFICATE STATUS"

if [ -f "$HAWK_CERT" ]; then
    echo "  Certificate: $HAWK_CERT"
    ls -l "$HAWK_CERT" 2>/dev/null | sed 's/^/  /'

    if command -v openssl &>/dev/null; then
        echo ""
        echo "  Certificate details:"
        openssl x509 -in "$HAWK_CERT" -noout \
            -subject -issuer -startdate -enddate 2>/dev/null \
            | sed 's/^/    /'

        expiry=$(openssl x509 -in "$HAWK_CERT" -noout -enddate 2>/dev/null \
            | cut -d= -f2 || echo "unknown")
        echo ""
        echo "  Expiry: $expiry"

        expiry_epoch=$(openssl x509 -in "$HAWK_CERT" -noout -enddate 2>/dev/null \
            | cut -d= -f2 | xargs -I{} date -d {} +%s 2>/dev/null || echo "0")
        now_epoch=$(date +%s)
        if [[ "${expiry_epoch:-0}" -gt 0 ]]; then
            days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
            if [ "$days_left" -gt 30 ]; then
                echo "  [OK]   $days_left days until expiry"
            elif [ "$days_left" -gt 0 ]; then
                echo "  [WARN] Certificate expires in $days_left days"
            else
                echo "  [ERROR] Certificate has EXPIRED"
            fi
        fi
    fi
else
    echo "  Certificate not found at $HAWK_CERT"
    echo "  HAWK may use a dynamically generated certificate"
fi

if [ -f "$HAWK_KEY" ]; then
    echo ""
    echo "  Private key: $HAWK_KEY"
    key_perms=$(stat -c "%a" "$HAWK_KEY" 2>/dev/null || echo "unknown")
    if [[ "$key_perms" != "600" && "$key_perms" != "640" ]]; then
        echo "  [WARN] Key permissions: $key_perms -- should be 600 or 640"
    else
        echo "  [OK]   Key permissions: $key_perms"
    fi
fi

# ── Firewall Check ──────────────────────────────────────────────────────────
section "FIREWALL STATUS FOR PORT $HAWK_PORT"

if command -v firewall-cmd &>/dev/null; then
    echo "  Active zones:"
    firewall-cmd --get-active-zones 2>/dev/null | sed 's/^/    /' || true
    echo ""
    echo "  Checking for hawk/port 7630:"
    firewall-cmd --list-all 2>/dev/null | grep -E "hawk|7630" | sed 's/^/    /' \
        || echo "    Port 7630 not explicitly listed in active zone rules"
else
    echo "  firewall-cmd not found"
fi

# ── HAWK Log ────────────────────────────────────────────────────────────────
section "RECENT HAWK LOG ENTRIES"

if [ -f "$HAWK_LOG" ]; then
    tail -20 "$HAWK_LOG" 2>/dev/null | sed 's/^/  /'
else
    echo "  $HAWK_LOG not found"
    echo "  Checking journal:"
    journalctl -u hawk --no-pager -n 10 2>/dev/null | sed 's/^/  /' \
        || echo "  No hawk entries in journal"
fi

echo ""
echo "$SEP"
echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"
