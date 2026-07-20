#!/usr/bin/env bash
# Purpose:        Volume capacity and snapshot-reserve pressure across the cluster - find what fills up next
# Applies to:     ONTAP 9.14+ over SSH, readonly-role admin user
# Read-only:      yes
# Inputs:         __CLUSTER_MGMT__ and __USER__
# Interpretation: Volumes over ~90% with autosize disabled are the next incident. snapshot-space-used over the reserve
#                 spills into the data space silently - the classic "volume full but files fit" case; check snapshot
#                 policies and delete/age-out old snapshots. Thin-provisioned (space-guarantee none) volumes can
#                 overcommit the aggregate - cross-check against 01-cluster-health.sh aggregate usage.
# Next step:      Grow/autosize the top offenders or clean snapshots; re-run to confirm

set -euo pipefail

HOST="__CLUSTER_MGMT__"
USER="__USER__"

ssh "${USER}@${HOST}" <<'ONTAP'
set -showseparator ","
volume show -fields volume,vserver,size,used,percent-used,available,space-guarantee,autosize-mode -sort-by percent-used
volume show -fields volume,vserver,snapshot-space-used,percent-snapshot-space
snapshot policy show
ONTAP
