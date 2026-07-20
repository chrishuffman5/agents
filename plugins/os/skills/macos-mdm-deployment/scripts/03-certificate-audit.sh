#!/usr/bin/env bash
# ============================================================================
# macOS MDM - Certificate & Trust Store Audit
#
# Version : 1.0.0
# Targets : macOS 14+ (Sonoma and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Checks: system keychain certificates, MDM identity cert, CA trust,
#         SCEP status, certificate expiry summary
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
    echo "This script must be run with sudo."
    exit 1
  fi
}

WARN_DAYS=30
FAIL_DAYS=7

# -- 1. System Keychain Certificates -------------------------------------------
audit_system_keychain() {
  header "System Keychain Certificates"

  local keychain="/Library/Keychains/System.keychain"

  local certs
  certs=$(security find-certificate -a -p "$keychain" 2>/dev/null || echo "")

  if [[ -z "$certs" ]]; then
    warn "No certificates found in System Keychain"
    return
  fi

  local count
  count=$(echo "$certs" | grep -c "BEGIN CERTIFICATE" || echo "0")
  info "Total certificates in System Keychain: $count"

  security find-certificate -a "$keychain" 2>/dev/null | \
    grep "labl" | sed 's/.*"labl"<blob>="//' | sed 's/"//' | \
    sort -u | head -30 | while read -r label; do
      info "Cert: $label"
    done
}

# -- 2. MDM Identity Certificate -----------------------------------------------
check_mdm_identity() {
  header "MDM Identity Certificate"

  local keychain="/Library/Keychains/System.keychain"
  local mdm_labels=("MDM" "Profile" "Device Management" "com.apple.mgmt")

  for label_pattern in "${mdm_labels[@]}"; do
    local cert_pem
    cert_pem=$(security find-certificate -c "$label_pattern" -p "$keychain" 2>/dev/null || echo "")
    if [[ -n "$cert_pem" ]]; then
      ok "Found certificate matching '$label_pattern'"

      local expiry_str
      expiry_str=$(echo "$cert_pem" | openssl x509 -noout -enddate 2>/dev/null \
        | sed 's/notAfter=//' || echo "")
      if [[ -n "$expiry_str" ]]; then
        local today_epoch expiry_epoch days_remaining
        today_epoch=$(date +%s)
        expiry_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_str" +%s 2>/dev/null || echo "0")
        days_remaining=$(( (expiry_epoch - today_epoch) / 86400 ))
        if [[ "$days_remaining" -lt "$FAIL_DAYS" ]]; then
          fail "MDM Identity ($label_pattern) -- expires in $days_remaining days"
        elif [[ "$days_remaining" -lt "$WARN_DAYS" ]]; then
          warn "MDM Identity ($label_pattern) -- expires in $days_remaining days"
        else
          ok "MDM Identity ($label_pattern) -- expires in $days_remaining days"
        fi
      fi

      local subject
      subject=$(echo "$cert_pem" | openssl x509 -noout -subject 2>/dev/null \
        | sed 's/subject=//' || echo "")
      [[ -n "$subject" ]] && info "  Subject: $subject"
    fi
  done
}

# -- 3. CA / Trust Certificates -------------------------------------------------
check_ca_trust() {
  header "Trusted CA Certificates (MDM-Deployed)"

  local keychain="/Library/Keychains/System.keychain"
  local ca_count
  ca_count=$(security find-certificate -a "$keychain" 2>/dev/null | grep -c "labl" || echo "0")
  info "Certificates in System Keychain: $ca_count"

  local profile_db="/var/db/ConfigurationProfiles"
  if [[ -d "$profile_db" ]]; then
    local ca_profiles
    ca_profiles=$(find "$profile_db" -name "*.plist" 2>/dev/null \
      | xargs grep -l "com.apple.security.pkcs1\|com.apple.security.root" 2>/dev/null \
      | wc -l | xargs || echo "0")
    info "Certificate payload profiles found: $ca_profiles"
  fi
}

# -- 4. SCEP Status -------------------------------------------------------------
check_scep() {
  header "SCEP Certificate Status"

  local scep_plist="/Library/Managed Preferences/com.apple.security.scep"
  if defaults read "$scep_plist" &>/dev/null 2>&1; then
    ok "SCEP configuration profile found"
    local scep_url
    scep_url=$(defaults read "$scep_plist" "PayloadContent" 2>/dev/null \
      | grep -i "URL\|Server" | head -3 || echo "")
    [[ -n "$scep_url" ]] && info "SCEP config: $scep_url"
  else
    info "No SCEP managed preferences found (SCEP may not be in use)"
  fi

  info "Scanning keychain for SCEP-pattern certificates..."
  security find-certificate -a /Library/Keychains/System.keychain 2>/dev/null | \
    grep -i "labl\|SCEP" | grep -i "SCEP\|device\|client" | head -5 || \
    info "  No SCEP-pattern certificates found in System Keychain"
}

# -- 5. Expiring Certificates Summary ------------------------------------------
check_expiring_certs() {
  header "Certificate Expiry Summary (System Keychain)"

  info "Checking certificate expiry (threshold: warn=${WARN_DAYS}d, fail=${FAIL_DAYS}d)..."
  echo

  local keychain="/Library/Keychains/System.keychain"
  local all_pem
  all_pem=$(security find-certificate -a -p "$keychain" 2>/dev/null || echo "")

  if [[ -z "$all_pem" ]]; then
    info "No certificates to check"
    return
  fi

  local today_epoch near_expiry=0 pem_block=""
  today_epoch=$(date +%s)

  while IFS= read -r line; do
    if [[ "$line" == "-----BEGIN CERTIFICATE-----" ]]; then
      pem_block="$line"
    elif [[ "$line" == "-----END CERTIFICATE-----" ]]; then
      pem_block="$pem_block
$line"
      local subject expiry_str expiry_epoch days_remaining
      subject=$(echo "$pem_block" | openssl x509 -noout -subject 2>/dev/null \
        | sed 's/subject= *//' | head -c 80 || echo "unknown")
      expiry_str=$(echo "$pem_block" | openssl x509 -noout -enddate 2>/dev/null \
        | sed 's/notAfter=//' || echo "")

      if [[ -n "$expiry_str" ]]; then
        expiry_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_str" +%s 2>/dev/null || echo "9999999999")
        days_remaining=$(( (expiry_epoch - today_epoch) / 86400 ))
        if [[ "$days_remaining" -lt "$WARN_DAYS" ]]; then
          near_expiry=$((near_expiry + 1))
          if [[ "$days_remaining" -lt "$FAIL_DAYS" ]]; then
            fail "CRITICAL ($days_remaining days): $subject"
          else
            warn "Expiring ($days_remaining days): $subject"
          fi
        fi
      fi
      pem_block=""
    else
      pem_block="$pem_block
$line"
    fi
  done <<< "$all_pem"

  if [[ "$near_expiry" -eq 0 ]]; then
    ok "No certificates expiring within ${WARN_DAYS} days"
  else
    warn "Total certificates needing attention: $near_expiry"
  fi
}

# -- Main ----------------------------------------------------------------------
main() {
  require_root
  echo "${BOLD}macOS MDM Certificate & Trust Audit${RESET}"
  echo "Date: $(date)"
  echo "Host: $(hostname)"
  echo "macOS: $(sw_vers -productVersion)"

  audit_system_keychain
  check_mdm_identity
  check_ca_trust
  check_scep
  check_expiring_certs

  echo
  echo "${BOLD}Report complete.${RESET}"
}

main "$@"
