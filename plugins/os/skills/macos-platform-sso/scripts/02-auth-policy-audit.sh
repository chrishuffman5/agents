#!/usr/bin/env bash
# ============================================================================
# macOS Platform SSO - Authentication Policy Audit (Sequoia+)
#
# Version : 1.0.0
# Targets : macOS 14+ (Sonoma and later); policy checks require macOS 15+
# Safety  : Read-only. No modifications to system configuration.
#
# Checks: OS version, PSSO profile config, FileVault policy, login policy,
#         unlock policy, NFC status, grace periods, account sync, smart card
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

# -- 0. Version Check -----------------------------------------------------------
check_os_version() {
  header "macOS Version & Policy Support"

  local macos_version major_version
  macos_version=$(sw_vers -productVersion)
  major_version=$(echo "$macos_version" | cut -d. -f1)

  info "macOS version: $macos_version"

  if [[ "$major_version" -ge 15 ]]; then
    ok "macOS $macos_version: Full authentication policy support (Sequoia+)"
  elif [[ "$major_version" -ge 13 ]]; then
    warn "macOS $macos_version: Basic PSSO; FileVault/Login/Unlock policies require Sequoia (15+)"
  else
    fail "macOS $macos_version: Platform SSO not supported (requires macOS 13+)"
    exit 0
  fi
}

# -- 1. PSSO Profile Full Audit ------------------------------------------------
audit_psso_profile() {
  header "Platform SSO Profile Configuration"

  local psso_plist="/Library/Managed Preferences/com.apple.extensiblesso"

  if ! defaults read "$psso_plist" &>/dev/null 2>&1; then
    warn "No com.apple.extensiblesso managed profile found"
    info "Authentication policies require an MDM-delivered PSSO profile"
    return
  fi

  ok "PSSO profile present"

  local profile_keys=(
    "ExtensionIdentifier"
    "TeamIdentifier"
    "AuthenticationMethod"
    "Type"
    "ScreenLockedBehavior"
    "TokenToUserMapping"
  )

  info "Profile key values:"
  for key in "${profile_keys[@]}"; do
    local val
    val=$(defaults read "$psso_plist" "$key" 2>/dev/null || echo "(not set)")
    info "  $key: $val"
  done
}

# -- 2. FileVault Policy -------------------------------------------------------
check_filevault_policy() {
  header "FileVault Authentication Policy"

  local macos_major
  macos_major=$(sw_vers -productVersion | cut -d. -f1)

  if [[ "$macos_major" -lt 15 ]]; then
    info "FileVaultPolicy requires macOS 15 Sequoia or later -- skipping"
    return
  fi

  local fv_policy
  fv_policy=$(app-sso platform -s 2>/dev/null | grep -i "FileVault\|filevault" || echo "")

  if [[ -n "$fv_policy" ]]; then
    info "FileVault policy state from app-sso:"
    echo "$fv_policy" | while read -r line; do info "  $line"; done
  fi

  local fv_status
  fv_status=$(fdesetup status 2>/dev/null || echo "unknown")
  info "FileVault status: $fv_status"

  if echo "$fv_status" | grep -q "On"; then
    ok "FileVault is enabled"
    local psso_plist="/Library/Managed Preferences/com.apple.extensiblesso"
    if defaults read "$psso_plist" &>/dev/null 2>&1; then
      local fv_policy_key
      fv_policy_key=$(defaults read "$psso_plist" FileVaultPolicy 2>/dev/null || echo "")
      if [[ -n "$fv_policy_key" ]]; then
        ok "FileVaultPolicy is configured in PSSO profile"
        info "  $fv_policy_key"
      else
        info "FileVaultPolicy not set (users must use local password for FV)"
      fi
    fi
  else
    warn "FileVault is not enabled -- FileVaultPolicy has no effect"
  fi
}

# -- 3. Login Policy ------------------------------------------------------------
check_login_policy() {
  header "Login Window Authentication Policy"

  local macos_major
  macos_major=$(sw_vers -productVersion | cut -d. -f1)

  if [[ "$macos_major" -lt 15 ]]; then
    info "LoginPolicy requires macOS 15 Sequoia or later -- skipping"
    return
  fi

  local psso_plist="/Library/Managed Preferences/com.apple.extensiblesso"
  if defaults read "$psso_plist" &>/dev/null 2>&1; then
    local login_key
    login_key=$(defaults read "$psso_plist" LoginPolicy 2>/dev/null || echo "")
    if [[ -n "$login_key" ]]; then
      ok "LoginPolicy is configured in PSSO profile"
      info "  $login_key"
    else
      info "LoginPolicy not explicitly set (default: password only)"
    fi

    local grace_period
    grace_period=$(defaults read "$psso_plist" LoginGracePeriod 2>/dev/null || echo "")
    if [[ -n "$grace_period" ]]; then
      info "Login grace period: ${grace_period}s ($(( grace_period / 60 )) minutes)"
    fi
  fi

  local loginwindow_plist="/Library/Managed Preferences/com.apple.loginwindow"
  if defaults read "$loginwindow_plist" &>/dev/null 2>&1; then
    ok "loginwindow managed preferences present"
    local disable_console
    disable_console=$(defaults read "$loginwindow_plist" DisableConsoleAccess 2>/dev/null || echo "not set")
    info "  DisableConsoleAccess: $disable_console"
  fi
}

# -- 4. Unlock Policy -----------------------------------------------------------
check_unlock_policy() {
  header "Screen Unlock Authentication Policy"

  local macos_major
  macos_major=$(sw_vers -productVersion | cut -d. -f1)

  if [[ "$macos_major" -lt 15 ]]; then
    info "UnlockPolicy requires macOS 15 Sequoia or later -- skipping"
    return
  fi

  local psso_plist="/Library/Managed Preferences/com.apple.extensiblesso"
  if defaults read "$psso_plist" &>/dev/null 2>&1; then
    local unlock_key
    unlock_key=$(defaults read "$psso_plist" UnlockPolicy 2>/dev/null || echo "")
    if [[ -n "$unlock_key" ]]; then
      ok "UnlockPolicy is configured in PSSO profile"
      info "  $unlock_key"
    else
      info "UnlockPolicy not explicitly set (default: password)"
    fi

    local unlock_grace
    unlock_grace=$(defaults read "$psso_plist" UnlockGracePeriod 2>/dev/null || echo "")
    if [[ -n "$unlock_grace" ]]; then
      info "Unlock grace period: ${unlock_grace}s ($(( unlock_grace / 60 )) minutes)"
    fi

    local screen_lock_behavior
    screen_lock_behavior=$(defaults read "$psso_plist" ScreenLockedBehavior 2>/dev/null || echo "")
    if [[ -n "$screen_lock_behavior" ]]; then
      info "ScreenLockedBehavior: $screen_lock_behavior"
    fi
  fi
}

# -- 5. NFC Status (Tahoe) -----------------------------------------------------
check_nfc_status() {
  header "NFC Tap-to-Login Status (macOS 26 Tahoe+)"

  local macos_major
  macos_major=$(sw_vers -productVersion | cut -d. -f1)

  if [[ "$macos_major" -lt 26 ]]; then
    info "NFC Tap-to-Login requires macOS 26 Tahoe or later"
    info "Current macOS: $(sw_vers -productVersion)"
    return
  fi

  ok "macOS supports NFC Tap-to-Login (Tahoe+)"

  local psso_plist="/Library/Managed Preferences/com.apple.extensiblesso"
  if defaults read "$psso_plist" &>/dev/null 2>&1; then
    local nfc_key
    nfc_key=$(defaults read "$psso_plist" NFCEnabled 2>/dev/null \
      || defaults read "$psso_plist" EnableNFC 2>/dev/null \
      || echo "")
    if [[ -n "$nfc_key" ]]; then
      info "NFC policy in PSSO profile: $nfc_key"
    else
      info "NFC policy key not found in PSSO profile"
    fi
  fi
}

# -- 6. Grace Period Summary ----------------------------------------------------
grace_period_summary() {
  header "Grace Period Configuration Summary"

  local psso_plist="/Library/Managed Preferences/com.apple.extensiblesso"

  if ! defaults read "$psso_plist" &>/dev/null 2>&1; then
    info "No PSSO profile -- grace period configuration not applicable"
    return
  fi

  info "Grace periods prevent lockout when IdP is unreachable:"
  echo

  local login_grace
  login_grace=$(defaults read "$psso_plist" LoginGracePeriod 2>/dev/null || echo "not configured")
  info "  LoginGracePeriod:   $login_grace"

  local unlock_grace
  unlock_grace=$(defaults read "$psso_plist" UnlockGracePeriod 2>/dev/null || echo "not configured")
  info "  UnlockGracePeriod:  $unlock_grace"

  echo
  if [[ "$login_grace" == "not configured" ]] && [[ "$unlock_grace" == "not configured" ]]; then
    warn "No grace periods configured -- users may be locked out if IdP is unreachable"
    info "  Recommendation: LoginGracePeriod >= 900 (15 min), UnlockGracePeriod >= 300 (5 min)"
  else
    ok "Grace periods are configured"
  fi
}

# -- Main ----------------------------------------------------------------------
main() {
  echo "${BOLD}macOS Platform SSO - Authentication Policy Audit${RESET}"
  echo "Date: $(date)"
  echo "Host: $(hostname)"
  echo "macOS: $(sw_vers -productVersion) (Build: $(sw_vers -buildVersion))"

  check_os_version
  audit_psso_profile
  check_filevault_policy
  check_login_policy
  check_unlock_policy
  check_nfc_status
  grace_period_summary

  echo
  echo "${BOLD}Report complete.${RESET}"
  echo "Policies marked 'requires Sequoia' need macOS 15+ to function."
  echo "NFC Tap-to-Login requires macOS 26 Tahoe+ and a supported IdP extension."
}

main "$@"
