#!/usr/bin/env bash
# Purpose:        OSD-level health - down/out OSDs, per-OSD fill skew, and commit/apply latency outliers
# Applies to:     Ceph 19.2+; run with an admin/readonly keyring
# Read-only:      yes
# Inputs:         none
# Interpretation: Down OSDs within one host/rack (see the tree) = node problem, not disk problem. 'osd df' %USE spread
#                 wider than ~10-15 points = balancer not doing its job (check 'ceph balancer status'). High commit/
#                 apply latency on specific OSDs in 'osd perf' = failing disk or overloaded device class - those OSDs
#                 drag every PG they host; check SMART on those drives.
# Next step:      For down OSDs: check the daemon/host; for latency outliers: smartctl the device before it fails hard

set -euo pipefail

echo "== OSD tree (find down/out and their failure domain)"
ceph osd tree

echo
echo "== Per-OSD utilization (skew check)"
ceph osd df

echo
echo "== Per-OSD latency (ms)"
ceph osd perf

echo
echo "== Balancer"
ceph balancer status
