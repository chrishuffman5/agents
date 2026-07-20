#!/usr/bin/env bash
# ============================================================================
# Podman - Rootless Configuration Audit
#
# Version : 1.0.0
# Targets : RHEL 8+ with Podman installed
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. User and subuid/subgid Mapping
#   2. Namespace and cgroup Configuration
#   3. Rootless Storage and Networking
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }

CURRENT_USER="${SUDO_USER:-$USER}"
CURRENT_UID=$(id -u "$CURRENT_USER")

# -- 1. User and subuid/subgid -----------------------------------------------
header "USER & SUBUID/SUBGID MAPPING"

info "User: $CURRENT_USER (UID: $CURRENT_UID)"
(( CURRENT_UID == 0 )) && warn "Running as root -- re-run as target user for accurate checks"

SUBUID=$(grep "^${CURRENT_USER}:" /etc/subuid 2>/dev/null || echo "")
SUBGID=$(grep "^${CURRENT_USER}:" /etc/subgid 2>/dev/null || echo "")

if [[ -n "$SUBUID" ]]; then
  COUNT=$(echo "$SUBUID" | cut -d: -f3)
  (( COUNT >= 65536 )) && pass "subuid: $SUBUID ($COUNT UIDs)" || warn "subuid range small ($COUNT) -- 65536+ recommended"
else
  fail "No subuid entry. Fix: sudo usermod --add-subuids 100000-165535 $CURRENT_USER"
fi

[[ -n "$SUBGID" ]] && pass "subgid: $SUBGID" || fail "No subgid entry. Fix: sudo usermod --add-subgids 100000-165535 $CURRENT_USER"

# -- 2. Namespace and cgroup --------------------------------------------------
header "NAMESPACE & CGROUP CONFIGURATION"

MAX_NS=$(cat /proc/sys/user/max_user_namespaces 2>/dev/null || echo "0")
if (( MAX_NS >= 15000 )); then
  pass "max_user_namespaces: $MAX_NS"
elif (( MAX_NS > 0 )); then
  warn "max_user_namespaces: $MAX_NS (consider 15000+)"
else
  fail "User namespaces disabled. Fix: sudo sysctl -w user.max_user_namespaces=15000"
fi

if (( CURRENT_UID != 0 )); then
  UID_MAP=$(podman unshare cat /proc/self/uid_map 2>/dev/null || echo "failed")
  [[ "$UID_MAP" != "failed" ]] && pass "User namespace creation works" || fail "Cannot create user namespace"
fi

CGROUP_TYPE=$(stat -fc %T /sys/fs/cgroup/ 2>/dev/null || echo "unknown")
case "$CGROUP_TYPE" in
  cgroup2fs)
    pass "cgroup v2 active -- rootless resource limits supported"
    DELEGATE="/etc/systemd/system/user@.service.d/delegate.conf"
    if [[ -f "$DELEGATE" ]] && grep -q "Delegate=yes" "$DELEGATE"; then
      pass "cgroup delegation configured"
    else
      warn "cgroup delegation not configured -- rootless resource limits may not work"
    fi
    ;;
  tmpfs) warn "cgroup v1 active -- rootless resource limits NOT available" ;;
  *)     warn "Could not determine cgroup version: $CGROUP_TYPE" ;;
esac

info "XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-not set}"
if [[ -n "${XDG_RUNTIME_DIR:-}" ]] && [[ -d "$XDG_RUNTIME_DIR" ]]; then
  pass "XDG_RUNTIME_DIR exists: $XDG_RUNTIME_DIR"
elif [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  fail "XDG_RUNTIME_DIR not set -- rootless Podman may fail"
fi

# -- 3. Storage and Networking ------------------------------------------------
header "ROOTLESS STORAGE & NETWORKING"

STORE="${HOME}/.local/share/containers/storage"
if [[ -d "$STORE" ]]; then
  USAGE=$(du -sh "$STORE" 2>/dev/null | cut -f1)
  pass "Rootless storage exists ($USAGE)"
else
  info "Rootless storage not yet initialized"
fi

USER_CONF="${HOME}/.config/containers/storage.conf"
[[ -f "$USER_CONF" ]] && info "User storage.conf: $USER_CONF"

NET_MODE="unknown"
command -v pasta &>/dev/null && { pass "pasta installed"; NET_MODE="pasta"; }
command -v slirp4netns &>/dev/null && { pass "slirp4netns installed"; [[ "$NET_MODE" == "unknown" ]] && NET_MODE="slirp4netns"; }
[[ "$NET_MODE" == "unknown" ]] && fail "No rootless networking backend found"

if (( CURRENT_UID != 0 )); then
  BACKEND=$(podman info --format '{{.Host.NetworkBackend}}' 2>/dev/null || echo "unknown")
  info "Active network backend: $BACKEND"
fi

UNPRIV=$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start 2>/dev/null || echo "1024")
info "ip_unprivileged_port_start: $UNPRIV"
(( UNPRIV <= 80 )) && pass "Can bind port 80 in rootless mode" || info "Cannot bind ports < $UNPRIV in rootless mode"

echo -e "\n${BOLD}Rootless audit complete.${NC}"
