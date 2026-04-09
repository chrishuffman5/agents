#!/usr/bin/env bash
# ============================================================================
# macOS MDM - Declarative Device Management (DDM) Status
#
# Version : 1.0.0
# Targets : macOS 14+ (Sonoma and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Checks: DDM support, declarations inventory, activation status,
#         software update declarations, status reports, DDM vs legacy
# ============================================================================
set -euo pipefail

BOLD=$(tput bold 2>/dev/null || echo "")
RESET=$(tput sgr0 2>/dev/null || echo "")
GREEN=$(tput setaf 2 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
CYAN=$(tput setaf 6 2>/dev/null || echo "")

header() { echo; echo "${BOLD}${CYAN}=== $1 ===${RESET}"; echo; }
ok()     { echo "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo "  ${YELLOW}[WARN]${RESET}  $1"; }
info()   { echo "  [INFO]  $1"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run with sudo."
    exit 1
  fi
}

# -- 1. DDM Support Check ------------------------------------------------------
check_ddm_support() {
  header "DDM Support"

  local macos_version major_version
  macos_version=$(sw_vers -productVersion)
  major_version=$(echo "$macos_version" | cut -d. -f1)

  if [[ "$major_version" -ge 14 ]]; then
    ok "macOS $macos_version supports DDM (Sonoma+)"
  elif [[ "$major_version" -ge 13 ]]; then
    warn "macOS $macos_version has partial DDM support (Ventura -- expanded in Sonoma)"
  else
    warn "macOS $macos_version has limited or no DDM support"
  fi

  local ddm_capable
  ddm_capable=$(profiles show -type enrollment 2>/dev/null \
    | grep -i "DeclarativeManagement\|DDM\|Declarative" | head -3 || echo "")
  if [[ -n "$ddm_capable" ]]; then
    ok "MDM server declares DDM capability"
    echo "$ddm_capable" | while read -r line; do info "  $line"; done
  else
    info "MDM server DDM capability not detected in enrollment profile"
  fi
}

# -- 2. DDM Declarations Inventory ---------------------------------------------
ddm_declarations() {
  header "DDM Declarations Inventory"

  local ddm_base="/var/db/ConfigurationProfiles"

  if [[ ! -d "$ddm_base" ]]; then
    warn "ConfigurationProfiles database not found"
    return
  fi

  info "Searching for DDM declaration files..."
  local ddm_files
  ddm_files=$(find "$ddm_base" -name "*.json" -o -name "*declaration*" -o -name "*DDM*" 2>/dev/null \
    | head -20 || echo "")

  if [[ -n "$ddm_files" ]]; then
    ok "DDM-related files found:"
    echo "$ddm_files" | while read -r f; do
      info "  $f"
      if [[ "$f" == *.json ]]; then
        local dtype
        dtype=$(python3 -c "import json,sys; d=json.load(open('$f')); print(d.get('Type','unknown'))" 2>/dev/null || echo "")
        [[ -n "$dtype" ]] && info "    Type: $dtype"
      fi
    done
  else
    info "No DDM declaration files found (may be embedded in profile database)"
  fi

  local mc_state="/Library/Application Support/com.apple.ManagedClient"
  if [[ -d "$mc_state" ]]; then
    info "ManagedClient state directory exists: $mc_state"
    ls "$mc_state" 2>/dev/null | head -10 | while read -r item; do
      info "  - $item"
    done
  fi
}

# -- 3. DDM Activation Status ---------------------------------------------------
ddm_activations() {
  header "DDM Activation Status"

  info "Checking DDM activation events in logs (last 2h)..."

  local ddm_log
  ddm_log=$(log show \
    --predicate 'subsystem == "com.apple.ManagedClient" AND (message CONTAINS "declaration" OR message CONTAINS "DDM" OR message CONTAINS "activation")' \
    --last 2h --style compact 2>/dev/null \
    | grep -v "^Filtering\|^---\|^Timestamp" \
    | tail -20 || echo "")

  if [[ -n "$ddm_log" ]]; then
    ok "DDM-related log entries found:"
    echo "$ddm_log" | while read -r line; do info "  $line"; done
  else
    info "No DDM declaration/activation log entries in last 2h"
  fi
}

# -- 4. Software Update Declarations -------------------------------------------
ddm_software_update() {
  header "DDM Software Update Declarations"

  local su_prefs="/Library/Managed Preferences/com.apple.SoftwareUpdate"
  if defaults read "$su_prefs" &>/dev/null 2>&1; then
    ok "MDM-managed Software Update preferences found"
    for key in AutomaticCheckEnabled AutomaticDownload AutomaticallyInstallMacOSUpdates \
                AllowPreReleaseInstallation RestrictSoftwareUpdateRequireAdminToInstall; do
      local val
      val=$(defaults read "$su_prefs" "$key" 2>/dev/null || echo "not set")
      info "$key: $val"
    done
  else
    info "No MDM-managed Software Update preferences"
  fi

  info "Checking Software Update MDM state..."
  local su_state
  su_state=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate 2>/dev/null \
    | grep -E "LastSuccessfulDate|AutomaticCheckEnabled|CriticalUpdateInstall" || echo "")
  [[ -n "$su_state" ]] && echo "$su_state" | while read -r line; do info "$line"; done
}

# -- 5. DDM Status Reports -----------------------------------------------------
ddm_status_reports() {
  header "DDM Status Channel"

  info "Checking for DDM status report events (last 4h)..."

  local status_log
  status_log=$(log show \
    --predicate 'subsystem == "com.apple.ManagedClient" AND message CONTAINS "StatusReport"' \
    --last 4h --style compact 2>/dev/null \
    | tail -10 || echo "")

  if [[ -n "$status_log" ]]; then
    ok "DDM status report events found"
    echo "$status_log" | while read -r line; do info "  $line"; done
  else
    info "No DDM status report events in last 4h"
    info "  (Reports are device-initiated; absence may be normal if state is stable)"
  fi

  info "Checking for DDM status item storage..."
  for possible_path in \
    "/var/db/ConfigurationProfiles/Store/Checkpoints" \
    "/var/db/ConfigurationProfiles/DDMStatus" \
    "/Library/Application Support/com.apple.ManagedClient/DDM"; do
    if [[ -d "$possible_path" ]]; then
      ok "DDM status path found: $possible_path"
      ls "$possible_path" 2>/dev/null | head -5 | while read -r f; do info "  $f"; done
    fi
  done
}

# -- 6. DDM vs Legacy Command Activity -----------------------------------------
ddm_vs_legacy() {
  header "DDM vs Legacy MDM Command Activity (last 24h)"

  local legacy_count
  legacy_count=$(log show \
    --predicate 'subsystem == "com.apple.ManagedClient" AND message CONTAINS "MDMCommand"' \
    --last 24h 2>/dev/null | grep -c "MDMCommand" || echo "0")

  local ddm_count
  ddm_count=$(log show \
    --predicate 'subsystem == "com.apple.ManagedClient" AND message CONTAINS "declaration"' \
    --last 24h 2>/dev/null | grep -c "declaration" || echo "0")

  info "Legacy MDM command events (last 24h): $legacy_count"
  info "DDM declaration events (last 24h): $ddm_count"

  if [[ "$ddm_count" -gt 0 ]]; then
    ok "Device has active DDM declaration activity"
  else
    info "No DDM activity detected -- device may be using legacy MDM commands only"
  fi
}

# -- Main ----------------------------------------------------------------------
main() {
  require_root
  echo "${BOLD}macOS DDM (Declarative Device Management) Status Report${RESET}"
  echo "Date: $(date)"
  echo "Host: $(hostname)"
  echo "macOS: $(sw_vers -productVersion) (Build: $(sw_vers -buildVersion))"

  check_ddm_support
  ddm_declarations
  ddm_activations
  ddm_software_update
  ddm_status_reports
  ddm_vs_legacy

  echo
  echo "${BOLD}Report complete.${RESET}"
}

main "$@"
