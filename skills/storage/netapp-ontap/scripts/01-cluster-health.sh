#!/usr/bin/env bash
# Purpose:        One-pass ONTAP cluster health check - node state, HA failover readiness, aggregate capacity, open issues
# Applies to:     ONTAP 9.14+ (clustered), run over SSH as a readonly-role admin user
# Read-only:      yes
# Inputs:         __CLUSTER_MGMT__ - cluster management LIF hostname/IP; __USER__ - admin account with readonly role
# Interpretation: 'storage failover show' Possible=false means a node cannot take over its partner - fix BEFORE any
#                 maintenance. Aggregates over ~85% used degrade performance and block volume moves. 'system health
#                 status show' not-ok points at subsystem alerts - drill with 'system health alert show'.
# Next step:      02-volume-capacity.sh for the volume-level capacity picture

set -euo pipefail

HOST="__CLUSTER_MGMT__"
USER="__USER__"

ssh "${USER}@${HOST}" <<'ONTAP'
set -showseparator ","
cluster show
storage failover show
system health status show
storage aggregate show -fields aggregate,size,usedsize,percent-used,availsize,state
system node show -fields node,health,uptime
ONTAP
