#!/usr/bin/env bash
# Purpose:        Triage one traffic flow through PAN-OS - policy match test, live sessions, and global drop counters
# Applies to:     PAN-OS 10.x/11.x (SSH, read-only operational commands)
# Read-only:      yes
# Inputs:         __FIREWALL__, __USER__, __SRC_IP__, __DST_IP__, __DST_PORT__, zones __FROM_ZONE__/__TO_ZONE__
# Interpretation: test security-policy-match names the rule that WOULD match - if it is not the rule you expect,
#                 a shadow rule above it wins (policy order problem). Sessions present but application 'incomplete' =
#                 three-way handshake never finished (routing/return-path, not policy). Drop counters with delta yes
#                 taken twice show ACTIVE drop reasons (deny, TCP sanity, DoS protection) during the repro window.
# Next step:      Fix the shadowing rule or the return path; re-test with the same inputs

set -euo pipefail
FIREWALL="__FIREWALL__"
USER="__USER__"

ssh "${USER}@${FIREWALL}" <<'PANOS'
set cli pager off
test security-policy-match from __FROM_ZONE__ to __TO_ZONE__ source __SRC_IP__ destination __DST_IP__ destination-port __DST_PORT__ protocol 6
show session all filter source __SRC_IP__ destination __DST_IP__
show counter global filter delta yes severity drop
PANOS
