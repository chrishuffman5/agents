#!/usr/bin/env bash
# Purpose:        Ceph cluster health triage - overall status, health detail, capacity, and pool fill levels in one pass
# Applies to:     Ceph 19.2+ (Squid/Tentacle); run on a node with an admin/readonly keyring (or via cephadm shell)
# Read-only:      yes
# Inputs:         none (uses the local ceph.conf/keyring; prepend 'cephadm shell --' if containerized)
# Interpretation: HEALTH_WARN details name the problem class: PG_* = placement/recovery (see 03-pg-troubleshoot.sh),
#                 OSD_* = disk/daemon issues (see 02-osd-health.sh), MON_* = quorum/clock. 'ceph df' %USED over ~75%
#                 on any pool = plan capacity NOW - Ceph performance degrades well before full, and full_ratio (95%)
#                 stops writes cluster-wide.
# Next step:      02-osd-health.sh for OSD-class warnings; 03-pg-troubleshoot.sh for PG-class warnings

set -euo pipefail

echo "== Status"
ceph status

echo
echo "== Health detail"
ceph health detail

echo
echo "== Capacity (cluster and per pool)"
ceph df

echo
echo "== Monitor quorum"
ceph quorum_status --format json-pretty | head -40
