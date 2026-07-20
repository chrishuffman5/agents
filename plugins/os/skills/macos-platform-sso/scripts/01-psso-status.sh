#!/usr/bin/env bash
# ============================================================================
# macOS Platform SSO - Registration State, IdP Connection & Token Validity
#
# Version : 1.0.0
# Targets : macOS 14+ (Sonoma and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Checks: PSSO profile, SSO extension app, registration state,
#         extension state, token validity, IdP connectivity, log activity
#
# Note: Some checks require user context (not root) for full SSO state.
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

# -- 1. PSSO Profile Check -----------------------------------------------------
check_psso_profile() {
  header "Platform SSO MDM Profile"

  local psso_plist="/Library/Managed Preferences/com.apple.extensiblesso"

  if defaults read "$psso_plist" &>/dev/null 2>&1; then
    ok "Platform SSO MDM profile is installed (com.apple.extensiblesso)"

    local ext_id
    ext_id=$(defaults read "$psso_plist" ExtensionIdentifier 2>/dev/null || echo "")
    [[ -n "$ext_id" ]] && info "SSO Extension: $ext_id"

    local auth_method
    auth_method=$(defaults read "$psso_plist" AuthenticationMethod 2>/dev/null || echo "")
    [[ -n "$auth_method" ]] && info "Authentication Method: $auth_method"

    local team_id
    team_id=$(defaults read "$psso_plist" TeamIdentifier 2>/dev/null || echo "")
    [[ -n "$team_id" ]] && info "Team ID: $team_id"
  else
    warn "No Platform SSO MDM profile found (com.apple.extensiblesso)"
    info "PSSO requires an MDM-delivered com.apple.extensiblesso profile"
    return
  fi

  local psso_profile_count
  psso_profile_count=$(sudo profiles show -all 2>/dev/null \
    | grep -c "extensiblesso\|SingleSignOn\|SSOExtension" || echo "0")
  info "SSO-related profile count: $psso_profile_count"
}

# -- 2. SSO Extension App Installed --------------------------------------------
check_sso_extension_app() {
  header "SSO Extension App"

  local extensions=(
    "com.microsoft.CompanyPortalMac.ssoextension:/Applications/Company Portal.app"
    "com.microsoft.intune.mac.ssoextension:/Applications/Company Portal.app"
    "com.okta.mobile.auth-client:/Applications/Okta Verify.app"
    "com.jamf.connect.login:/Applications/Jamf Connect.app"
  )

  local found=false
  for entry in "${extensions[@]}"; do
    local bundle_id="${entry%%:*}"
    local app_path="${entry##*:}"
    if [[ -d "$app_path" ]]; then
      ok "Found: $app_path"
      local version
      version=$(defaults read "$app_path/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "unknown")
      info "  Version: $version"
      info "  Bundle ID: $bundle_id"
      found=true
    fi
  done

  if [[ "$found" == "false" ]]; then
    warn "No recognized SSO extension app found in /Applications"
    info "Checked: Company Portal, Okta Verify, Jamf Connect"
  fi
}

# -- 3. PSSO Registration State ------------------------------------------------
check_psso_registration() {
  header "Platform SSO Registration State"

  local psso_state
  psso_state=$(app-sso platform -s 2>/dev/null || echo "command_unavailable")

  if [[ "$psso_state" == "command_unavailable" ]]; then
    warn "app-sso platform -s not available (requires macOS 13+)"
    return
  fi

  echo "$psso_state" | while read -r line; do info "$line"; done

  if echo "$psso_state" | grep -qi "registered\|complete\|active"; then
    ok "Platform SSO is registered"
  elif echo "$psso_state" | grep -qi "not registered\|unregistered\|pending"; then
    warn "Platform SSO is NOT registered -- user registration required"
    info "To trigger registration: app-sso platform --register"
  else
    info "Could not determine registration state from output"
  fi
}

# -- 4. SSO Extension State ----------------------------------------------------
check_sso_extension_state() {
  header "SSO Extension State"

  local sso_list
  sso_list=$(app-sso -l 2>/dev/null || echo "unavailable")

  if [[ "$sso_list" == "unavailable" ]]; then
    warn "app-sso -l failed -- may require user context (run without sudo)"
    return
  fi

  if [[ -z "$sso_list" ]]; then
    warn "No SSO extensions found -- PSSO profile may not be installed"
    return
  fi

  ok "SSO extensions:"
  echo "$sso_list" | while read -r line; do info "  $line"; done
}

# -- 5. Token Validity ----------------------------------------------------------
check_token_validity() {
  header "Token Validity"

  local token_state
  token_state=$(app-sso -t 2>/dev/null || echo "unavailable")

  if [[ "$token_state" != "unavailable" ]] && [[ -n "$token_state" ]]; then
    ok "Token cache accessible"
    echo "$token_state" | head -20 | while read -r line; do info "$line"; done
  else
    info "Token cache unavailable via app-sso -t"
  fi

  local klist_output
  klist_output=$(klist 2>/dev/null || echo "No Kerberos credentials")

  if echo "$klist_output" | grep -q "Credentials cache"; then
    ok "Kerberos TGT present"
    echo "$klist_output" | head -10 | while read -r line; do info "$line"; done
  else
    info "No Kerberos TGT (may use OAuth2/OIDC tokens only)"
  fi
}

# -- 6. IdP Connectivity -------------------------------------------------------
check_idp_connectivity() {
  header "IdP Connectivity"

  local psso_plist="/Library/Managed Preferences/com.apple.extensiblesso"
  if defaults read "$psso_plist" &>/dev/null 2>&1; then
    local raw_urls
    raw_urls=$(defaults read "$psso_plist" URLs 2>/dev/null || echo "")
    if [[ -n "$raw_urls" ]]; then
      info "Configured SSO URLs:"
      echo "$raw_urls" | tr ',' '\n' | tr -d '()' | grep -v '^$' | while read -r url; do
        url=$(echo "$url" | xargs)
        if [[ -n "$url" ]]; then
          if curl -s --max-time 5 --head "$url" &>/dev/null; then
            ok "  Reachable: $url"
          else
            warn "  Unreachable: $url"
          fi
        fi
      done
    fi
  fi

  local idp_endpoints=(
    "https://login.microsoftonline.com"
    "https://graph.microsoft.com"
    "https://login.okta.com"
  )

  info "Testing common IdP endpoints:"
  for endpoint in "${idp_endpoints[@]}"; do
    if curl -s --max-time 5 --head "$endpoint" &>/dev/null; then
      ok "  Reachable: $endpoint"
    else
      warn "  Unreachable: $endpoint"
    fi
  done
}

# -- 7. PSSO Log Activity ------------------------------------------------------
check_psso_logs() {
  header "Platform SSO Log Activity (last 1h)"

  local sso_log
  sso_log=$(log show \
    --predicate 'subsystem == "com.apple.AppSSO" OR subsystem == "com.apple.AuthenticationServices"' \
    --last 1h --style compact 2>/dev/null \
    | grep -v "^Filtering\|^---\|^Timestamp" \
    | tail -15 || echo "")

  if [[ -n "$sso_log" ]]; then
    ok "Recent SSO log activity:"
    echo "$sso_log" | while read -r line; do info "$line"; done
  else
    info "No SSO log activity in last 1h"
  fi
}

# -- Main ----------------------------------------------------------------------
main() {
  echo "${BOLD}macOS Platform SSO Status Report${RESET}"
  echo "Date: $(date)"
  echo "Host: $(hostname)"
  echo "macOS: $(sw_vers -productVersion) (Build: $(sw_vers -buildVersion))"
  echo "User: $(whoami)"

  check_psso_profile
  check_sso_extension_app
  check_psso_registration
  check_sso_extension_state
  check_token_validity
  check_idp_connectivity
  check_psso_logs

  echo
  echo "${BOLD}Report complete.${RESET}"
  echo "Note: Some checks require running in user context (not root)."
  echo "If run with sudo, re-run as the target user for full SSO state."
}

main "$@"
