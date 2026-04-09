#!/usr/bin/env bash
# ============================================================================
# macOS MDM - Enrollment Status, ADE, Bootstrap Token & Push Certificate
#
# Version : 1.0.0
# Targets : macOS 14+ (Sonoma and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Checks: enrollment status, server URL, ADE/DEP, supervision, bootstrap
#         token escrow, push certificate, enrollment record, last check-in
# ============================================================================
set -euo pipefail

BOLD=$(tput bold 2>/dev/null || echo "")
RESET=$(tput sgr0 2>/dev/null || echo "")
GREEN=$(tput setaf 2 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
RED=$(tput setaf 1 2>/dev/null || echo "")
CYAN=$(tput setaf 6 2>/dev/null || echo "")

header() { echo; echo "${BOLD}${CYAN}=== $1 ===${RESET}"; echo; }
ok()     { echo "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo "  ${YELLOW}[WARN]${RESET}  $1"; }
fail()   { echo "  ${RED}[FAIL]${RESET}  $1"; }
info()   { echo "  [INFO]  $1"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "${RED}This script must be run with sudo.${RESET}"
    exit 1
  fi
}

# -- 1. MDM Enrollment Status --------------------------------------------------
check_enrollment_status() {
  header "MDM Enrollment Status"

  local enrolled=false
  local enroll_output
  enroll_output=$(profiles status -type enrollment 2>/dev/null || echo "")

  if echo "$enroll_output" | grep -q "MDM enrollment: Yes"; then
    ok "Device is MDM enrolled"
    enrolled=true
  else
    warn "Device does NOT appear to be MDM enrolled"
  fi

  local server_url
  server_url=$(profiles show -type enrollment 2>/dev/null \
    | grep -i "ServerURL\|MDMServiceURL" | awk -F'= ' '{print $2}' | head -1 | xargs 2>/dev/null || echo "")
  if [[ -n "$server_url" ]]; then
    info "MDM Server URL: $server_url"
  fi

  if echo "$enroll_output" | grep -q "DEP enrollment: Yes\|Automated"; then
    ok "Enrollment type: Automated Device Enrollment (ADE/DEP)"
  elif [[ "$enrolled" == "true" ]]; then
    info "Enrollment type: User Approved MDM (UAMDM) or manual"
  fi

  local supervised
  supervised=$(profiles status -type enrollment 2>/dev/null \
    | grep -i "supervised" | awk -F': ' '{print $2}' | head -1 | xargs 2>/dev/null || echo "unknown")
  if [[ "$supervised" == "Yes" ]] || echo "$enroll_output" | grep -qi "supervised: yes"; then
    ok "Device is supervised"
  else
    warn "Device is NOT supervised (limited restriction capability)"
  fi
}

# -- 2. Bootstrap Token --------------------------------------------------------
check_bootstrap_token() {
  header "Bootstrap Token"

  local bt_output
  bt_output=$(profiles status -type bootstraptoken 2>/dev/null || echo "")

  if echo "$bt_output" | grep -q "Bootstrap Token supported on server: YES"; then
    ok "MDM server supports Bootstrap Token"
  else
    warn "MDM server does NOT support Bootstrap Token (or not enrolled)"
  fi

  if echo "$bt_output" | grep -q "Bootstrap Token escrowed to server: YES"; then
    ok "Bootstrap Token is escrowed to MDM server"
  else
    fail "Bootstrap Token is NOT escrowed -- FileVault and Secure Token operations may fail"
  fi
}

# -- 3. Push Certificate / APNs ------------------------------------------------
check_push_certificate() {
  header "MDM Push Certificate"

  local push_topic
  push_topic=$(profiles show -type enrollment 2>/dev/null \
    | grep -i "Topic\|PushCertTopic" | awk -F'= ' '{print $2}' | head -1 | xargs 2>/dev/null || echo "")

  if [[ -n "$push_topic" ]]; then
    info "APNs Push Topic: $push_topic"
  else
    warn "Could not determine APNs push topic from enrollment profile"
  fi

  local identity_certs
  identity_certs=$(security find-certificate -a -c "MDM" /Library/Keychains/System.keychain 2>/dev/null \
    | grep -c "labl" || echo "0")
  if [[ "$identity_certs" -gt 0 ]]; then
    ok "MDM identity certificate(s) found in System Keychain: $identity_certs"
  else
    info "No certificates labeled 'MDM' in System Keychain (may use different label)"
  fi
}

# -- 4. ADE / DEP Profile ------------------------------------------------------
check_ade_profile() {
  header "ADE (Automated Device Enrollment) Profile"

  local dep_enrolled
  dep_enrolled=$(profiles status -type enrollment 2>/dev/null \
    | grep -i "DEP enrollment" | awk -F': ' '{print $2}' | xargs 2>/dev/null || echo "")
  [[ -n "$dep_enrolled" ]] && info "DEP enrollment status: $dep_enrolled"

  local activation_record="/private/var/db/MobileAsset/AssetsV2/com_apple_MobileAsset_MDMProfileURL/activation_record.plist"
  if [[ -f "$activation_record" ]]; then
    ok "ADE activation record present"
    local mdm_url
    mdm_url=$(defaults read "$activation_record" "url" 2>/dev/null || echo "")
    [[ -n "$mdm_url" ]] && info "ADE MDM URL: $mdm_url"
  else
    info "ADE activation record not found at expected path (may vary by macOS version)"
  fi
}

# -- 5. Enrollment Record Detail -----------------------------------------------
check_enrollment_record() {
  header "Enrollment Record"

  local record="/private/var/db/MDMClientEnrollment.plist"
  if [[ -f "$record" ]]; then
    ok "Enrollment record found: $record"
    for key in ServerURL OrganizationName MDMServiceURL EnrollmentProfileName; do
      local val
      val=$(defaults read "$record" "$key" 2>/dev/null || echo "")
      [[ -n "$val" ]] && info "$key: $val"
    done
  else
    info "Enrollment record not found at $record"
  fi
}

# -- 6. Last Check-in ----------------------------------------------------------
check_last_checkin() {
  header "MDM Last Check-in"

  local last_event
  last_event=$(log show --predicate 'subsystem == "com.apple.ManagedClient"' \
    --last 24h --style compact 2>/dev/null \
    | grep -i "commandCompleted\|CheckInSuccess\|MDMCommand" \
    | tail -3 || echo "")

  if [[ -n "$last_event" ]]; then
    ok "Recent MDM activity found in last 24h:"
    echo "$last_event" | while read -r line; do info "$line"; done
  else
    warn "No recent MDM activity in logs (last 24h) -- device may not be checking in"
  fi
}

# -- Main ----------------------------------------------------------------------
main() {
  require_root
  echo "${BOLD}macOS MDM Enrollment Status Report${RESET}"
  echo "Date: $(date)"
  echo "Host: $(hostname)"
  echo "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
  echo "Hardware: $(system_profiler SPHardwareDataType 2>/dev/null | grep 'Model Name' | awk -F': ' '{print $2}' | xargs)"

  check_enrollment_status
  check_bootstrap_token
  check_push_certificate
  check_ade_profile
  check_enrollment_record
  check_last_checkin

  echo
  echo "${BOLD}Report complete.${RESET}"
}

main "$@"
