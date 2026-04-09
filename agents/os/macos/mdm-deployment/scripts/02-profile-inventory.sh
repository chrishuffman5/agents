#!/usr/bin/env bash
# ============================================================================
# macOS MDM - Profile Inventory & Restriction Audit
#
# Version : 1.0.0
# Targets : macOS 14+ (Sonoma and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Checks: installed profiles, profiles by type, payload summary,
#         restrictions in effect, FileVault status, profile database
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

# -- 1. All Installed Profiles -------------------------------------------------
list_all_profiles() {
  header "All Installed Configuration Profiles"

  local profile_output
  profile_output=$(profiles show -all 2>/dev/null || echo "")

  if [[ -z "$profile_output" ]]; then
    warn "No profiles found or profiles tool unavailable"
    return
  fi

  local count
  count=$(echo "$profile_output" | grep -c "attribute: name:" || echo "0")
  info "Total profiles installed: $count"
  echo

  echo "$profile_output" | grep -E "attribute: name:|attribute: identifier:" | \
    sed 's/.*attribute: name: /  Name: /' | \
    sed 's/.*attribute: identifier: /  ID:   /' || true
}

# -- 2. Profiles by Type -------------------------------------------------------
list_profiles_by_type() {
  header "Profiles by Payload Type"

  for ptype in enrollment configuration credential; do
    local type_output
    type_output=$(profiles show -type "$ptype" 2>/dev/null || echo "")
    local count
    count=$(echo "$type_output" | grep -c "attribute: name:" || echo "0")
    info "Type [$ptype]: $count profile(s)"
    if [[ "$count" -gt 0 ]]; then
      echo "$type_output" | grep "attribute: name:" | sed 's/.*attribute: name: /    - /' || true
    fi
  done
}

# -- 3. Key Payload Summary ----------------------------------------------------
payload_summary() {
  header "Payload Type Summary"

  local managed_prefs="/Library/Managed Preferences"
  if [[ -d "$managed_prefs" ]]; then
    local domain_count
    domain_count=$(ls "$managed_prefs" 2>/dev/null | wc -l | xargs)
    info "Managed preference domains: $domain_count"
    ls "$managed_prefs" 2>/dev/null | head -20 | while read -r domain; do
      info "  - $domain"
    done
  else
    info "No managed preferences directory found"
  fi

  local key_payloads=(
    "com.apple.applicationaccess:Restrictions"
    "com.apple.mobiledevice.passwordpolicy:Password Policy"
    "com.apple.wifi.managed:Wi-Fi"
    "com.apple.security.firewall:Firewall"
    "com.apple.systempolicy.managed:Gatekeeper"
    "com.apple.extensiblesso:Platform SSO"
    "com.apple.notificationsettings:Notifications"
  )

  echo
  info "Key payload presence:"
  for entry in "${key_payloads[@]}"; do
    local domain="${entry%%:*}"
    local label="${entry##*:}"
    if defaults read "$managed_prefs/$domain" &>/dev/null 2>&1; then
      ok "$label ($domain)"
    else
      info "$label ($domain) -- not present"
    fi
  done
}

# -- 4. Restrictions in Effect -------------------------------------------------
check_restrictions() {
  header "Active Restrictions (com.apple.applicationaccess)"

  local restrictions_plist="/Library/Managed Preferences/com.apple.applicationaccess"

  if ! defaults read "$restrictions_plist" &>/dev/null 2>&1; then
    info "No applicationaccess restrictions profile found"
    return
  fi

  local keys=(
    "allowCamera"
    "allowAirDrop"
    "allowAppInstallation"
    "allowiCloudDocumentSync"
    "allowScreenShot"
    "allowBluetoothModification"
    "allowEraseContentAndSettings"
    "allowPasswordAutoFill"
    "allowPasswordSharing"
    "forceEncryptedBackup"
  )

  for key in "${keys[@]}"; do
    local val
    val=$(defaults read "$restrictions_plist" "$key" 2>/dev/null || echo "not set")
    if [[ "$val" == "0" ]]; then
      warn "$key = FALSE (restricted)"
    elif [[ "$val" == "1" ]]; then
      ok "$key = TRUE (allowed)"
    else
      info "$key = $val"
    fi
  done
}

# -- 5. FileVault Status -------------------------------------------------------
check_filevault() {
  header "FileVault Status"

  local fv_status
  fv_status=$(fdesetup status 2>/dev/null || echo "unknown")
  info "FileVault: $fv_status"

  if echo "$fv_status" | grep -q "On"; then
    ok "FileVault is enabled"
    local ik
    ik=$(fdesetup hasinstitutionalrecoverykey 2>/dev/null || echo "unknown")
    info "Institutional Recovery Key: $ik"
    local pk
    pk=$(fdesetup haspersonalrecoverykey 2>/dev/null || echo "unknown")
    info "Personal Recovery Key: $pk"
  else
    warn "FileVault is NOT enabled -- disk is not encrypted"
  fi
}

# -- 6. ConfigurationProfiles Database -----------------------------------------
check_profile_database() {
  header "ConfigurationProfiles Database"

  local db_dir="/var/db/ConfigurationProfiles"
  if [[ -d "$db_dir" ]]; then
    ok "Database directory exists: $db_dir"
    local file_count
    file_count=$(find "$db_dir" -type f 2>/dev/null | wc -l | xargs)
    info "Files in database: $file_count"
  else
    warn "ConfigurationProfiles database directory not found"
  fi
}

# -- Main ----------------------------------------------------------------------
main() {
  require_root
  echo "${BOLD}macOS MDM Profile Inventory Report${RESET}"
  echo "Date: $(date)"
  echo "Host: $(hostname)"
  echo "macOS: $(sw_vers -productVersion)"

  list_all_profiles
  list_profiles_by_type
  payload_summary
  check_restrictions
  check_filevault
  check_profile_database

  echo
  echo "${BOLD}Report complete.${RESET}"
}

main "$@"
