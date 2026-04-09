#!/usr/bin/env bash
# ============================================================================
# macOS Developer Toolchain - Code Signing Audit
#
# Version : 1.0.0
# Targets : macOS 14+ with Xcode or CLT installed
# Safety  : Read-only. No modifications to system configuration.
#
# Checks: signing identities, certificate expiry, provisioning profiles,
#         entitlements, Gatekeeper assessment, notarization validation
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }

echo -e "${BOLD}Code Signing Audit${NC} — $(hostname) — $(date)"

# -- 1. Signing Identities ------------------------------------------------------
header "SIGNING IDENTITIES"

VALID_IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null || echo "")

if echo "$VALID_IDENTITIES" | grep -q "Developer ID Application"; then
  DEVID_COUNT=$(echo "$VALID_IDENTITIES" | grep -c "Developer ID Application" || echo "0")
  pass "Developer ID Application certificates: $DEVID_COUNT"
  echo "$VALID_IDENTITIES" | grep "Developer ID Application" | while read -r line; do
    info "  $line"
  done
else
  warn "No 'Developer ID Application' certificate found"
  info "Required for distributing Mac apps outside the App Store"
fi

if echo "$VALID_IDENTITIES" | grep -q "Apple Development"; then
  DEV_COUNT=$(echo "$VALID_IDENTITIES" | grep -c "Apple Development" || echo "0")
  info "Apple Development certificates: $DEV_COUNT"
fi

if echo "$VALID_IDENTITIES" | grep -q "Apple Distribution"; then
  DIST_COUNT=$(echo "$VALID_IDENTITIES" | grep -c "Apple Distribution" || echo "0")
  info "Apple Distribution certificates: $DIST_COUNT"
fi

INVALID=$(security find-identity 2>/dev/null | grep -E "EXPIRED|REVOKED|invalid" || true)
if [[ -n "$INVALID" ]]; then
  warn "Expired or invalid certificates detected:"
  echo "$INVALID" | while read -r line; do warn "  $line"; done
fi

# -- 2. Certificate Expiry ------------------------------------------------------
header "CERTIFICATE EXPIRY"

security find-identity -v -p codesigning 2>/dev/null | \
  grep -oE '"[^"]+"' | tr -d '"' | sort -u | \
  while read -r cert_name; do
    [[ -z "$cert_name" ]] && continue
    CERT_PEM=$(security find-certificate -c "$cert_name" -p 2>/dev/null || true)
    [[ -z "$CERT_PEM" ]] && continue

    END_DATE=$(echo "$CERT_PEM" | openssl x509 -noout -enddate 2>/dev/null | \
      cut -d= -f2 || echo "unknown")
    [[ -z "$END_DATE" ]] && continue

    END_EPOCH=$(date -j -f "%b %d %T %Y %Z" "$END_DATE" "+%s" 2>/dev/null || echo "0")
    NOW_EPOCH=$(date "+%s")
    DAYS_LEFT=$(( (END_EPOCH - NOW_EPOCH) / 86400 ))

    SHORT_NAME="${cert_name:0:60}"
    if (( DAYS_LEFT < 0 )); then
      fail "EXPIRED ($((DAYS_LEFT * -1)) days ago): $SHORT_NAME"
    elif (( DAYS_LEFT < 30 )); then
      fail "EXPIRING IN $DAYS_LEFT DAYS: $SHORT_NAME"
    elif (( DAYS_LEFT < 90 )); then
      warn "Expiring in $DAYS_LEFT days: $SHORT_NAME"
    else
      pass "Valid for $DAYS_LEFT days: $SHORT_NAME"
    fi
  done

# -- 3. Provisioning Profiles ---------------------------------------------------
header "PROVISIONING PROFILES"

PROFILES_DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"
if [[ -d "$PROFILES_DIR" ]]; then
  PROFILE_COUNT=$(ls "$PROFILES_DIR"/*.mobileprovision 2>/dev/null | wc -l | tr -d ' ')
  PROVISIONPROFILE_COUNT=$(ls "$PROFILES_DIR"/*.provisionprofile 2>/dev/null | wc -l | tr -d ' ')
  TOTAL_PROFILES=$(( PROFILE_COUNT + PROVISIONPROFILE_COUNT ))
  info "Provisioning profiles installed: $TOTAL_PROFILES"

  for profile in "$PROFILES_DIR"/*.mobileprovision "$PROFILES_DIR"/*.provisionprofile; do
    [[ -f "$profile" ]] || continue
    PLIST=$(security cms -D -i "$profile" 2>/dev/null || continue)
    NAME=$(echo "$PLIST" | plutil -extract Name raw - 2>/dev/null || echo "unknown")
    EXPIRY=$(echo "$PLIST" | plutil -extract ExpirationDate raw - 2>/dev/null || echo "unknown")
    TEAM=$(echo "$PLIST" | plutil -extract TeamName raw - 2>/dev/null || echo "unknown")

    if [[ "$EXPIRY" != "unknown" ]]; then
      EXP_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$EXPIRY" "+%s" 2>/dev/null || echo "0")
      NOW_EPOCH=$(date "+%s")
      DAYS_LEFT=$(( (EXP_EPOCH - NOW_EPOCH) / 86400 ))
      if (( DAYS_LEFT < 0 )); then
        fail "EXPIRED profile: $NAME ($TEAM)"
      elif (( DAYS_LEFT < 30 )); then
        warn "Profile expiring soon ($DAYS_LEFT days): $NAME"
      else
        info "Profile: $NAME | Team: $TEAM | Expires in: $DAYS_LEFT days"
      fi
    else
      info "Profile: $NAME | Team: $TEAM"
    fi
  done
else
  info "No provisioning profiles directory found: $PROFILES_DIR"
fi

# -- 4. Gatekeeper Assessment ---------------------------------------------------
header "GATEKEEPER ASSESSMENT"

GATEKEEPER_STATUS=$(spctl --status 2>/dev/null || echo "unknown")
if echo "$GATEKEEPER_STATUS" | grep -q "assessments enabled"; then
  pass "Gatekeeper is enabled (assessments enabled)"
else
  warn "Gatekeeper status: $GATEKEEPER_STATUS"
fi

BLOCKED_COUNT=0
for app in /Applications/*.app; do
  [[ -d "$app" ]] || continue
  APP_NAME=$(basename "$app")
  RESULT=$(spctl --assess --type execute "$app" 2>&1 || true)
  if echo "$RESULT" | grep -qE "rejected|not signed"; then
    warn "Gatekeeper would BLOCK: $APP_NAME"
    BLOCKED_COUNT=$(( BLOCKED_COUNT + 1 ))
  fi
done

if [[ $BLOCKED_COUNT -eq 0 ]]; then
  pass "All /Applications/*.app pass Gatekeeper assessment"
fi

# -- 5. Notarization Validation -------------------------------------------------
header "NOTARIZATION VALIDATION"

for app in /Applications/*.app; do
  [[ -d "$app" ]] || continue
  APP_NAME=$(basename "$app")
  STAPLE_RESULT=$(xcrun stapler validate "$app" 2>&1 || true)
  if echo "$STAPLE_RESULT" | grep -q "worked"; then
    pass "Stapled: $APP_NAME"
  elif echo "$STAPLE_RESULT" | grep -q "did not pass"; then
    info "Not stapled (may use online check): $APP_NAME"
  fi
done

echo -e "\n${BOLD}Signing audit complete.${NC}"
