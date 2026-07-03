#!/usr/bin/env bash
# Purpose:        Placement-group triage - stuck/degraded/undersized PGs and recovery progress
# Applies to:     Ceph 19.2+; run with an admin/readonly keyring
# Read-only:      yes
# Inputs:         none
# Interpretation: 'undersized' = fewer replicas than pool size (an OSD is missing) - data is at reduced redundancy,
#                 not lost. 'inconsistent' = scrub found mismatches (repair after identifying the bad copy).
#                 Stuck 'peering'/'unknown' PGs = OSDs cannot agree - usually network partition or a flapping OSD.
#                 Recovery/backfill percentages in 'ceph status' tell you how long until redundancy is restored;
#                 if recovery is starving client IO, tune recovery settings during the window, not permanently.
# Next step:      Map stuck PGs to OSDs (ceph pg map <pgid>) and fix the common OSD/host; 'ceph pg repair' only for confirmed inconsistent PGs

set -euo pipefail

echo "== PG state summary"
ceph pg stat

echo
echo "== Stuck PGs (inactive / unclean / stale)"
ceph pg dump_stuck inactive 2>/dev/null | head -30
ceph pg dump_stuck unclean  2>/dev/null | head -30
ceph pg dump_stuck stale    2>/dev/null | head -30

echo
echo "== PGs not active+clean, by state"
ceph pg ls 2>/dev/null | awk 'NR>1 && $2 !~ /^active\+clean$/ {print $2}' | sort | uniq -c | sort -rn | head -20
