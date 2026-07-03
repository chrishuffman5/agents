#!/usr/bin/env bash
# Purpose:        Container health sweep - restarting/unhealthy/exited containers plus a one-shot resource snapshot
# Applies to:     Docker Engine 24+ (docker CLI)
# Read-only:      yes
# Inputs:         none
# Interpretation: 'Restarting' with a climbing restart count = crash loop; check 'docker logs --tail 50' and the exit
#                 code (137 = OOM/SIGKILL - check memory limits; 139 = segfault; 1 = app error). 'unhealthy' = the
#                 HEALTHCHECK is failing - inspect .State.Health for the probe output. In the stats snapshot, MEM %
#                 pinned at 100 of its limit = imminent OOM kill.
# Next step:      docker inspect --format '{{json .State}}' <name> on the flagged containers; fix limits or the app

set -euo pipefail

echo "== Problem containers"
docker ps -a --filter status=restarting --filter status=dead --filter health=unhealthy \
    --format '{{.Names}}\t{{.Status}}\t{{.Image}}'
docker ps -a --filter status=exited --format '{{.Names}}\t{{.Status}}\t{{.Image}}' | grep -v 'Exited (0)' | head -10 || true

echo
echo "== Resource snapshot (one-shot)"
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' | head -20
