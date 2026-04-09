#!/usr/bin/env bash
# ============================================================================
# Podman - System Health Check
#
# Version : 1.0.0
# Targets : RHEL 8+ with Podman installed
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Podman Version and Runtime
#   2. Storage Configuration
#   3. Registry Configuration
#   4. System Info
#   5. cgroup Detection
#   6. Buildah and Skopeo
#   7. Disk Usage
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }

# -- 1. Podman Version and Runtime -------------------------------------------
header "PODMAN VERSION & RUNTIME"

if ! command -v podman &>/dev/null; then
  fail "Podman not found in PATH. Install: dnf install -y podman"
  exit 1
fi

PODMAN_VERSION=$(podman --version)
pass "Podman installed: $PODMAN_VERSION"

RUNTIME=$(podman info --format '{{.Host.OCIRuntime.Name}}' 2>/dev/null || echo "unknown")
RUNTIME_PATH=$(podman info --format '{{.Host.OCIRuntime.Path}}' 2>/dev/null || echo "unknown")
info "OCI Runtime: $RUNTIME ($RUNTIME_PATH)"

case "$RUNTIME" in
  crun) pass "Using crun (recommended for RHEL 9+)" ;;
  runc) info "Using runc (default for RHEL 8)" ;;
  *)    warn "Unknown OCI runtime: $RUNTIME" ;;
esac

CONMON=$(podman info --format '{{.Host.Conmon.Path}}' 2>/dev/null || echo "not found")
info "conmon path: $CONMON"
if [[ "$CONMON" != "not found" ]] && [[ -x "$CONMON" ]]; then
  pass "conmon is present and executable"
else
  fail "conmon not found or not executable"
fi

# -- 2. Storage Configuration ------------------------------------------------
header "STORAGE CONFIGURATION"

GRAPH_DRIVER=$(podman info --format '{{.Store.GraphDriverName}}' 2>/dev/null || echo "unknown")
GRAPH_ROOT=$(podman info --format '{{.Store.GraphRoot}}' 2>/dev/null || echo "unknown")
RUN_ROOT=$(podman info --format '{{.Store.RunRoot}}' 2>/dev/null || echo "unknown")

info "Storage driver:  $GRAPH_DRIVER"
info "Graph root:      $GRAPH_ROOT"
info "Run root:        $RUN_ROOT"

case "$GRAPH_DRIVER" in
  overlay)   pass "Overlay storage driver in use (recommended)" ;;
  vfs)       warn "VFS storage driver -- slow, not recommended for production" ;;
  devmapper) warn "DevMapper storage driver -- legacy, consider migration to overlay" ;;
  *)         warn "Unrecognized storage driver: $GRAPH_DRIVER" ;;
esac

if [[ -d "$GRAPH_ROOT" ]]; then
  USED_PCT=$(df --output=pcent "$GRAPH_ROOT" 2>/dev/null | tail -1 | tr -d ' %')
  if [[ -n "$USED_PCT" ]]; then
    if (( USED_PCT < 70 )); then
      pass "Storage usage on $GRAPH_ROOT: ${USED_PCT}% used"
    elif (( USED_PCT < 85 )); then
      warn "Storage usage on $GRAPH_ROOT: ${USED_PCT}% used -- consider pruning"
    else
      fail "Storage usage on $GRAPH_ROOT: ${USED_PCT}% used -- critically high"
    fi
  fi
fi

# -- 3. Registry Configuration -----------------------------------------------
header "REGISTRY CONFIGURATION"

REG_FILE="/etc/containers/registries.conf"
USER_REG="${HOME}/.config/containers/registries.conf"

if [[ -f "$REG_FILE" ]]; then
  pass "System registries.conf present: $REG_FILE"
  SEARCH=$(grep 'unqualified-search-registries' "$REG_FILE" 2>/dev/null || echo "not set")
  info "Unqualified search: $SEARCH"
else
  warn "No system registries.conf at $REG_FILE"
fi

[[ -f "$USER_REG" ]] && info "User registries.conf present: $USER_REG"

POLICY="/etc/containers/policy.json"
if [[ -f "$POLICY" ]]; then
  pass "Image policy.json present: $POLICY"
else
  warn "No policy.json -- signature verification may not be configured"
fi

# -- 4. System Info -----------------------------------------------------------
header "PODMAN SYSTEM INFO"

podman system info 2>/dev/null | grep -E \
  'version|arch|os|kernel|hostname|cgroupVersion|cgroupManager|eventLogger' \
  || warn "Could not retrieve full system info"

# -- 5. cgroup Detection -----------------------------------------------------
header "CGROUP DETECTION"

CGROUP_TYPE=$(stat -fc %T /sys/fs/cgroup/ 2>/dev/null || echo "unknown")
case "$CGROUP_TYPE" in
  cgroup2fs) pass "cgroup v2 active (full resource control available)" ;;
  tmpfs)     warn "cgroup v1 active -- rootless resource limits not available" ;;
  *)         warn "Could not determine cgroup version: $CGROUP_TYPE" ;;
esac

CGROUP_MGR=$(podman info --format '{{.Host.CgroupManager}}' 2>/dev/null || echo "unknown")
info "cgroup manager: $CGROUP_MGR"

# -- 6. Buildah and Skopeo ---------------------------------------------------
header "BUILDAH & SKOPEO"

if command -v buildah &>/dev/null; then
  pass "Buildah: $(buildah --version)"
else
  warn "Buildah not installed (dnf install -y buildah)"
fi

if command -v skopeo &>/dev/null; then
  pass "Skopeo: $(skopeo --version)"
else
  warn "Skopeo not installed (dnf install -y skopeo)"
fi

# -- 7. Disk Usage ------------------------------------------------------------
header "DISK USAGE (podman system df)"

podman system df 2>/dev/null || warn "Could not retrieve disk usage"

echo -e "\n${BOLD}Health check complete.${NC}"
