#!/usr/bin/env bash
# Purpose:        Interface error and drop sweep - CRC/input errors, drops, err-disabled ports, and flap counts
# Applies to:     Cisco IOS-XE 17.x (SSH exec, read-only)
# Read-only:      yes
# Inputs:         __DEVICE__ and __USER__
# Interpretation: CRC/input errors climbing = layer-1 (cable, SFP, duplex) - counters only matter as DELTAS, so run
#                 twice a few minutes apart. Output drops on an uplink = congestion/QoS (microbursts don't show in
#                 5-min averages). err-disabled names its cause (bpduguard, port-security...) - fix the cause before
#                 'shut/no shut'. High interface resets = flapping - check the far end too.
# Next step:      For L1 errors: swap cable/SFP and re-measure deltas; for drops: 'show policy-map interface' on the congested port

set -euo pipefail
DEVICE="__DEVICE__"
USER="__USER__"

ssh "${USER}@${DEVICE}" <<'IOS'
terminal length 0
show interfaces counters errors
show interfaces status err-disabled
show interfaces | include line protocol|input errors|output drops|interface resets
IOS
