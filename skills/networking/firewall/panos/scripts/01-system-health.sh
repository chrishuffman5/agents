#!/usr/bin/env bash
# Purpose:        PAN-OS firewall health bundle - system state, resources, HA status, session pressure
# Applies to:     PAN-OS 10.x/11.x (SSH to the management interface, read-only operational commands)
# Read-only:      yes
# Inputs:         __FIREWALL__ and __USER__ (superreader role suffices)
# Interpretation: Dataplane CPU sustained high with session count near maximum = capacity, not config. HA state must be
#                 active/passive as designed - 'suspended' or mismatched sync state means failover will NOT work; fix
#                 before any maintenance. Session table near max = new sessions get dropped (users see intermittent
#                 failures, not a clean outage).
# Next step:      02-traffic-triage.sh for a specific traffic problem; 'show running resource-monitor' live during spikes

set -euo pipefail
FIREWALL="__FIREWALL__"
USER="__USER__"

ssh "${USER}@${FIREWALL}" <<'PANOS'
set cli pager off
show system info | match "model\|sw-version\|uptime"
show system resources | match "load average\|Mem"
show high-availability state
show session info
show system disk-space
PANOS
