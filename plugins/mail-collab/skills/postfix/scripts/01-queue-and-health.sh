#!/usr/bin/env bash
# Purpose:        Postfix queue depth, deferred-reason summary, and service state - the "mail is stuck / delayed" opener
# Applies to:     Postfix 3.8+ (run on the mail host; postqueue is world-executable, mailq needs no privilege)
# Read-only:      yes
# Inputs:         none
# Interpretation: A deep 'deferred' queue with reasons clustered on one destination = that recipient/relay is the
#                 problem (greylisting, their outage, your IP reputation), not Postfix. Deep 'active' = local delivery
#                 or relay throughput bottleneck. Growing 'hold' = admin-held mail nobody released. 'Connection timed
#                 out' reasons = network/firewall; 'Relay access denied' = you're not authorized to that next hop;
#                 '4xx greylisted' = normal, retries clear it. The reason histogram tells you where to look before you
#                 touch config.
# Next step:      02-tls-and-auth-config.sh for TLS/relay posture; investigate the top deferred destination

set -euo pipefail

echo "== Queue summary"
postqueue -p | tail -1
echo
echo "== Messages by queue"
for q in incoming active deferred hold; do
    n=$(find "/var/spool/postfix/$q" -type f 2>/dev/null | wc -l)
    printf '%-10s %s\n' "$q" "$n"
done

echo
echo "== Top deferred reasons"
postqueue -p | grep -A1 '^[A-F0-9]' | grep -oE '\((.*)\)' | sort | uniq -c | sort -rn | head -12

echo
echo "== Service and config sanity"
postfix status 2>/dev/null || systemctl is-active postfix
postconf -n | grep -E 'mydestination|relayhost|inet_interfaces|mynetworks' | head
