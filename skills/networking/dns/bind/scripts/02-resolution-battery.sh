#!/usr/bin/env bash
# Purpose:        DNS resolution battery against one server - serial consistency across NS set, DNSSEC validation, response timing
# Applies to:     any authoritative/recursive DNS (dig required); written for BIND but server-agnostic
# Read-only:      yes
# Inputs:         __ZONE__ (the zone to test) and __SERVER__ (the DNS server IP to interrogate)
# Interpretation: SOA serials differing across the NS set = zone transfer problem (check allow-transfer, notify, TSIG) -
#                 clients get answers depending on which NS they hit. status: SERVFAIL with +dnssec but working with
#                 +cd = DNSSEC validation failure (expired signatures are the classic - check signature dates).
#                 Query times: authoritative answers should be single-digit ms locally; hundreds of ms = overload
#                 or upstream recursion problems.
# Next step:      Fix transfers/signatures per the failing check; re-run the battery to confirm

set -euo pipefail
ZONE="__ZONE__"
SERVER="__SERVER__"

echo "== SOA serial on each NS"
for ns in $(dig +short NS "$ZONE" @"$SERVER"); do
    serial=$(dig +short SOA "$ZONE" @"$ns" 2>/dev/null | awk '{print $3}')
    printf '%-40s serial=%s\n' "$ns" "${serial:-UNREACHABLE}"
done

echo
echo "== DNSSEC check (AD flag / SERVFAIL vs +cd)"
dig +dnssec +noall +comments "$ZONE" SOA @"$SERVER" | grep -E 'status|flags'
dig +cd +noall +comments "$ZONE" SOA @"$SERVER" | grep -E 'status'

echo
echo "== Response timing (5 samples)"
for i in 1 2 3 4 5; do dig +noall +stats "$ZONE" A @"$SERVER" | grep 'Query time'; done
