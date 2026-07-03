#!/usr/bin/env bash
# Purpose:        IOS-XE device health bundle - version, CPU/memory, environment, recent logs in one SSH pass
# Applies to:     Cisco IOS-XE 17.x (SSH exec; read-only show commands, privilege 1 suffices for most)
# Read-only:      yes
# Inputs:         __DEVICE__ and __USER__
# Interpretation: CPU 'five minutes' over ~70% sustained = investigate the top process (IOSd high = control plane churn,
#                 often routing instability or SNMP abuse). Environment alarms (PSU/fan/temp) precede hardware death.
#                 Log tail: %SYS-, %LINK- flap patterns and %SEC- denials tell the recent story - correlate timestamps
#                 with the reported incident window.
# Next step:      02-interface-errors.sh if links/flaps appear; 'show processes cpu sorted' live during spikes

set -euo pipefail
DEVICE="__DEVICE__"
USER="__USER__"

ssh "${USER}@${DEVICE}" <<'IOS'
terminal length 0
show version | include uptime|Version|reload
show processes cpu | include CPU utilization
show processes memory | include Processor Pool
show environment summary
show logging | tail 30
IOS
