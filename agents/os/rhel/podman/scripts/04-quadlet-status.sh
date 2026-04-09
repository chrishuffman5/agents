#!/usr/bin/env bash
# ============================================================================
# Podman - Quadlet Unit Status
#
# Version : 1.0.0
# Targets : RHEL 9.2+ with Podman 4.4+ installed (Quadlet support)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Quadlet Availability
#   2. Unit File Inventory
#   3. Systemd Unit Status
#   4. Auto-Update Configuration
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }

IS_ROOT=false; (( EUID == 0 )) && IS_ROOT=true
SC_OPTS=""; $IS_ROOT || SC_OPTS="--user"

# -- 1. Quadlet Availability -------------------------------------------------
header "QUADLET AVAILABILITY"

GEN="/usr/lib/systemd/system-generators/podman-system-generator"
[[ -x "$GEN" ]] && pass "System generator present" || warn "System generator not found (requires Podman 4.4+)"

UGEN="/usr/lib/systemd/user-generators/podman-user-generator"
[[ -x "$UGEN" ]] && pass "User generator present"

PVER=$(podman --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "0.0")
MAJ=$(echo "$PVER" | cut -d. -f1); MIN=$(echo "$PVER" | cut -d. -f2)
if (( MAJ > 4 || (MAJ == 4 && MIN >= 4) )); then
  pass "Podman $PVER supports Quadlet"
else
  warn "Podman $PVER -- Quadlet requires 4.4+"
fi

# -- 2. Unit File Inventory --------------------------------------------------
header "QUADLET UNIT FILE INVENTORY"

SYS_DIRS=("/etc/containers/systemd" "/usr/share/containers/systemd" "/usr/lib/containers/systemd")
USR_DIR="${HOME}/.config/containers/systemd"
EXTS=("container" "volume" "network" "pod" "image" "kube")
TOTAL=0

for DIR in "${SYS_DIRS[@]}"; do
  [[ -d "$DIR" ]] || continue
  info "Scanning: $DIR"
  for EXT in "${EXTS[@]}"; do
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      echo "  [.${EXT}] $f"; (( TOTAL++ ))
    done < <(find "$DIR" -name "*.${EXT}" 2>/dev/null | sort)
  done
done

if [[ -d "$USR_DIR" ]]; then
  info "Scanning: $USR_DIR"
  for EXT in "${EXTS[@]}"; do
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      echo "  [.${EXT}] $f"; (( TOTAL++ ))
    done < <(find "$USR_DIR" -name "*.${EXT}" 2>/dev/null | sort)
  done
fi

(( TOTAL > 0 )) && info "Total Quadlet files: $TOTAL" || info "No Quadlet unit files found"

# -- 3. Systemd Unit Status --------------------------------------------------
header "SYSTEMD UNIT STATUS"

info "Container-related units:"
systemctl $SC_OPTS list-units --type=service \
  --state=active,failed 2>/dev/null | grep -iE '(container|podman)' \
  || info "No active/failed container units"

# Check status of each .container file
for DIR in "${SYS_DIRS[@]}" "$USR_DIR"; do
  [[ -d "$DIR" ]] || continue
  find "$DIR" -name "*.container" 2>/dev/null | while read -r cfile; do
    UNIT=$(basename "$cfile" .container).service
    STATE=$(systemctl $SC_OPTS is-active "$UNIT" 2>/dev/null || echo "unknown")
    case "$STATE" in
      active)   pass "$UNIT -- active" ;;
      failed)   fail "$UNIT -- failed" ;;
      inactive) warn "$UNIT -- inactive" ;;
      *)        info "$UNIT -- $STATE" ;;
    esac
  done
done

# -- 4. Auto-Update Configuration --------------------------------------------
header "AUTO-UPDATE CONFIGURATION"

info "Containers with autoupdate label:"
podman ps -a --format '{{.Names}}' 2>/dev/null | while read -r NAME; do
  [[ -z "$NAME" ]] && continue
  LABEL=$(podman inspect --format '{{index .Config.Labels "io.containers.autoupdate"}}' "$NAME" 2>/dev/null || echo "")
  [[ -n "$LABEL" ]] && pass "  $NAME: autoupdate=$LABEL"
done

for SCOPE in "" "--user"; do
  LBL="system"; [[ "$SCOPE" == "--user" ]] && LBL="user"
  ACTIVE=$(systemctl $SCOPE is-active podman-auto-update.timer 2>/dev/null || echo "not-found")
  if [[ "$ACTIVE" == "active" ]]; then
    pass "Auto-update timer active ($LBL)"
  elif [[ "$ACTIVE" == "inactive" ]]; then
    warn "Auto-update timer inactive ($LBL). Enable: systemctl $SCOPE enable --now podman-auto-update.timer"
  fi
done

# Deprecation notice
PFULL=$(podman --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "0")
(( PFULL >= 5 )) && warn "'podman generate systemd' removed in Podman 5 -- use Quadlet"
(( PFULL == 4 )) && warn "'podman generate systemd' deprecated -- migrate to Quadlet"

echo -e "\n${BOLD}Quadlet status check complete.${NC}"
