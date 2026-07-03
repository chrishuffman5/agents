#!/usr/bin/env bash
# Purpose:        BIND configuration and zone validation plus server status - catch config rot before a reload bites
# Applies to:     BIND 9.18+/9.20 (run on the DNS server; named-checkconf/rndc need appropriate permissions)
# Read-only:      yes
# Inputs:         adjust __NAMED_CONF__ if not /etc/named.conf (Debian/Ubuntu: /etc/bind/named.conf)
# Interpretation: named-checkconf -z parses every zone as a reload would - errors here mean the NEXT reload/restart
#                 fails or silently drops zones (SERVFAIL for clients). rndc status shows recursive client load vs
#                 limits and whether zone transfers are backed up. 9.20 note: legacy directives (auto-dnssec) removed -
#                 checkconf failures after upgrade usually name them.
# Next step:      02-resolution-battery.sh to test actual resolution; fix config errors before any planned reload

set -euo pipefail
CONF="__NAMED_CONF__"

echo "== Config check"
named-checkconf "$CONF" && echo "named-checkconf: OK"

echo
echo "== Zone load check (parses all zones)"
named-checkconf -z "$CONF" | grep -v ': loaded serial' | head -20 || echo "all zones loaded clean"

echo
echo "== Server status"
rndc status
