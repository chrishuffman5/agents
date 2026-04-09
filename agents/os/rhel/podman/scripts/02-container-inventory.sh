#!/usr/bin/env bash
# ============================================================================
# Podman - Container Inventory
#
# Version : 1.0.0
# Targets : RHEL 8+ with Podman installed
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Running Containers
#   2. All Containers (including stopped)
#   3. Pods
#   4. Images
#   5. Volumes
#   6. Networks
#   7. Port Mappings
#   8. Resource Usage Snapshot
#   9. System Disk Usage
# ============================================================================
set -euo pipefail

BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }
info()   { echo -e "${CYAN}[INFO]${NC} $*"; }

# -- 1. Running Containers ---------------------------------------------------
header "RUNNING CONTAINERS"

RUNNING=$(podman ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
if [[ -n "$RUNNING" ]]; then
  echo "$RUNNING"
else
  info "No running containers"
fi

# -- 2. All Containers -------------------------------------------------------
header "ALL CONTAINERS (including stopped)"

ALL=$(podman ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Created}}" 2>/dev/null)
if [[ -n "$ALL" ]]; then
  echo "$ALL"
else
  info "No containers found"
fi

TOTAL=$(podman ps -a -q 2>/dev/null | wc -l)
RUNNING_COUNT=$(podman ps -q 2>/dev/null | wc -l)
STOPPED_COUNT=$(( TOTAL - RUNNING_COUNT ))
info "Summary: ${RUNNING_COUNT} running, ${STOPPED_COUNT} stopped, ${TOTAL} total"

# -- 3. Pods ------------------------------------------------------------------
header "PODS"

POD_COUNT=$(podman pod ps -q 2>/dev/null | wc -l)
if (( POD_COUNT > 0 )); then
  podman pod ps --format "table {{.Id}}\t{{.Name}}\t{{.Status}}\t{{.NumContainers}}\t{{.InfraId}}" 2>/dev/null
else
  info "No pods defined"
fi

# -- 4. Images ----------------------------------------------------------------
header "IMAGES"

podman images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.Created}}" 2>/dev/null

IMAGE_COUNT=$(podman images -q 2>/dev/null | wc -l)
DANGLING=$(podman images -f dangling=true -q 2>/dev/null | wc -l)
info "Total images: ${IMAGE_COUNT} (${DANGLING} dangling)"

# -- 5. Volumes ---------------------------------------------------------------
header "VOLUMES"

VOL_COUNT=$(podman volume ls -q 2>/dev/null | wc -l)
if (( VOL_COUNT > 0 )); then
  podman volume ls 2>/dev/null
else
  info "No volumes defined"
fi
info "Total volumes: $VOL_COUNT"

# -- 6. Networks --------------------------------------------------------------
header "NETWORKS"

podman network ls 2>/dev/null

# -- 7. Port Mappings ---------------------------------------------------------
header "PORT MAPPINGS"

PORTS=$(podman ps --format '{{.Names}}\t{{.Ports}}' 2>/dev/null | awk -F'\t' '$2 != ""')
if [[ -n "$PORTS" ]]; then
  printf "%-30s %s\n" "CONTAINER" "PORTS"
  echo "$PORTS"
else
  info "No containers with exposed ports"
fi

# -- 8. Resource Usage Snapshot -----------------------------------------------
header "RESOURCE USAGE (snapshot)"

RUNNING_IDS=$(podman ps -q 2>/dev/null)
if [[ -n "$RUNNING_IDS" ]]; then
  podman stats --no-stream \
    --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null \
    || info "Could not retrieve stats"
else
  info "No running containers -- skipping resource stats"
fi

# -- 9. System Disk Usage ----------------------------------------------------
header "SYSTEM DISK USAGE"

podman system df 2>/dev/null

echo -e "\n${BOLD}Inventory complete.${NC}"
