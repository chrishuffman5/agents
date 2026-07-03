#!/usr/bin/env bash
# Purpose:        Docker disk usage breakdown with reclaimable-space preview - answer "why is the host disk full" without pruning anything
# Applies to:     Docker Engine 24+ (docker CLI)
# Read-only:      yes
# Inputs:         none
# Interpretation: RECLAIMABLE in 'system df' = what a prune would recover, split by images/containers/volumes/cache.
#                 Dangling images = untagged layers from rebuilds (safe to prune). Stopped containers holding volumes
#                 are why "docker volume prune" alone recovers little. Build cache growing unbounded = no cache GC
#                 policy on a busy build host. NEVER prune volumes without confirming nothing stateful lives there.
# Next step:      Targeted cleanup with user signoff: image prune (dangling first), container prune, builder prune --keep-storage

set -euo pipefail

echo "== Summary"
docker system df

echo
echo "== Dangling images"
docker images -f dangling=true --format '{{.ID}}\t{{.Size}}\t{{.CreatedSince}}' | head -15

echo
echo "== Exited containers (age, size)"
docker ps -a -f status=exited --format '{{.Names}}\t{{.Size}}\t{{.Status}}' | head -15

echo
echo "== Volumes not referenced by any container"
docker volume ls -f dangling=true -q | head -15
