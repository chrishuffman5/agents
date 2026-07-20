#!/usr/bin/env bash
# Purpose:        LIF placement, port health, and failover configuration - the network side of ONTAP incidents
# Applies to:     ONTAP 9.14+ over SSH, readonly-role admin user
# Read-only:      yes
# Inputs:         __CLUSTER_MGMT__ and __USER__
# Interpretation: LIFs shown 'home false' migrated during a past event and never reverted - performance may be riding
#                 the wrong node/port. Ports admin-up but link-down = cabling/switch problem. Data LIFs sharing one
#                 physical port with no failover targets = single point of failure the next port flap will find.
# Next step:      'network interface revert' for stranded LIFs (change window); fix failover-group gaps

set -euo pipefail

HOST="__CLUSTER_MGMT__"
USER="__USER__"

ssh "${USER}@${HOST}" <<'ONTAP'
set -showseparator ","
network interface show -fields lif,vserver,address,curr-node,curr-port,home-node,home-port,is-home,status-oper
network port show -fields node,port,link,mtu,speed-oper
network interface show -failover
ONTAP
