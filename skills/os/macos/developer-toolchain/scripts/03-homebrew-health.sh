#!/usr/bin/env bash
# ============================================================================
# macOS Developer Toolchain - Homebrew Health Check
#
# Version : 1.0.0
# Targets : macOS 14+ with Homebrew installed
# Safety  : Read-only. No modifications to system configuration.
#
# Checks: installation path (Apple Silicon vs Intel), version, doctor,
#         outdated packages, tap inventory, cask inventory, disk usage
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }

echo -e "${BOLD}Homebrew Health Check${NC} — $(hostname) — $(date)"

# -- 1. Homebrew Installation (Apple Silicon vs Intel) --------------------------
header "HOMEBREW INSTALLATION"

ARCH=$(uname -m)
info "Architecture: $ARCH"

if [[ "$ARCH" == "arm64" ]]; then
  BREW_PREFIX="/opt/homebrew"
  info "Apple Silicon Mac -- expected prefix: $BREW_PREFIX"
elif [[ "$ARCH" == "x86_64" ]]; then
  BREW_PREFIX="/usr/local"
  info "Intel Mac -- expected prefix: $BREW_PREFIX"
else
  BREW_PREFIX=""
  warn "Unknown architecture: $ARCH"
fi

BREW_BIN=""
if command -v brew &>/dev/null; then
  BREW_BIN=$(command -v brew)
  pass "brew found: $BREW_BIN"
elif [[ -x "/opt/homebrew/bin/brew" ]]; then
  BREW_BIN="/opt/homebrew/bin/brew"
  warn "brew not in PATH -- found at /opt/homebrew/bin/brew"
elif [[ -x "/usr/local/bin/brew" ]]; then
  BREW_BIN="/usr/local/bin/brew"
  warn "brew not in PATH -- found at /usr/local/bin/brew"
else
  fail "Homebrew not installed or not found"
  info "Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi

ACTUAL_PREFIX=$("$BREW_BIN" --prefix 2>/dev/null)
info "Actual Homebrew prefix: $ACTUAL_PREFIX"

if [[ -n "$BREW_PREFIX" ]] && [[ "$ACTUAL_PREFIX" != "$BREW_PREFIX" ]]; then
  warn "Homebrew prefix ($ACTUAL_PREFIX) does not match expected for this arch ($BREW_PREFIX)"
  if [[ "$ARCH" == "arm64" ]] && [[ "$ACTUAL_PREFIX" == "/usr/local" ]]; then
    warn "Intel Homebrew detected on Apple Silicon -- may be a Rosetta 2 install"
    info "Consider migrating: https://github.com/nicoverbruggen/homebrew-migration-guide"
  fi
else
  pass "Homebrew prefix matches expected location for $ARCH"
fi

# -- 2. Homebrew Version and Config ---------------------------------------------
header "HOMEBREW VERSION AND CONFIG"

BREW_VERSION=$("$BREW_BIN" --version 2>/dev/null | head -1)
pass "Homebrew version: $BREW_VERSION"

CELLAR=$("$BREW_BIN" --cellar 2>/dev/null)
CASKROOM=$("$BREW_BIN" --caskroom 2>/dev/null)
info "Cellar (formulae): $CELLAR"
info "Caskroom (casks): $CASKROOM"

ANALYTICS=$("$BREW_BIN" analytics 2>/dev/null | head -1 || echo "unknown")
info "Analytics: $ANALYTICS"

# -- 3. Doctor Output -----------------------------------------------------------
header "HOMEBREW DOCTOR"

info "Running brew doctor (may take 10-30 seconds)..."
DOCTOR_OUTPUT=$("$BREW_BIN" doctor 2>&1 || true)

if echo "$DOCTOR_OUTPUT" | grep -q "Your system is ready to brew"; then
  pass "brew doctor: Your system is ready to brew"
elif echo "$DOCTOR_OUTPUT" | grep -q "Warning"; then
  WARN_COUNT=$(echo "$DOCTOR_OUTPUT" | grep -c "Warning:" || echo "0")
  warn "brew doctor found $WARN_COUNT warning(s):"
  echo "$DOCTOR_OUTPUT" | grep -A2 "Warning:" | while read -r line; do
    [[ -n "$line" ]] && warn "  $line"
  done
else
  warn "brew doctor output unclear -- review manually"
  echo "$DOCTOR_OUTPUT" | head -20 | while read -r line; do info "  $line"; done
fi

# -- 4. Outdated Packages -------------------------------------------------------
header "OUTDATED PACKAGES"

info "Checking for outdated formulae (requires network)..."
OUTDATED=$("$BREW_BIN" outdated 2>/dev/null || echo "")

if [[ -z "$OUTDATED" ]]; then
  pass "All installed formulae are up to date"
else
  OUTDATED_COUNT=$(echo "$OUTDATED" | wc -l | tr -d ' ')
  warn "$OUTDATED_COUNT outdated package(s):"
  echo "$OUTDATED" | while read -r line; do warn "  $line"; done
  info "Update with: brew upgrade"
fi

OUTDATED_CASKS=$("$BREW_BIN" outdated --cask 2>/dev/null || echo "")
if [[ -z "$OUTDATED_CASKS" ]]; then
  pass "All installed casks are up to date"
else
  CASK_COUNT=$(echo "$OUTDATED_CASKS" | wc -l | tr -d ' ')
  warn "$CASK_COUNT outdated cask(s):"
  echo "$OUTDATED_CASKS" | while read -r line; do warn "  $line"; done
fi

# -- 5. Tap Inventory -----------------------------------------------------------
header "TAP INVENTORY"

TAPS=$("$BREW_BIN" tap 2>/dev/null || echo "")
if [[ -z "$TAPS" ]]; then
  info "No additional taps configured"
else
  TAP_COUNT=$(echo "$TAPS" | wc -l | tr -d ' ')
  info "Configured taps ($TAP_COUNT):"
  echo "$TAPS" | while read -r tap; do
    case "$tap" in
      homebrew/core|homebrew/cask) pass "  $tap (official)" ;;
      homebrew/*) info "  $tap (official extended)" ;;
      *)          info "  $tap (third-party)" ;;
    esac
  done
fi

# -- 6. Cask Inventory ----------------------------------------------------------
header "CASK INVENTORY"

CASKS=$("$BREW_BIN" list --cask 2>/dev/null || echo "")
if [[ -z "$CASKS" ]]; then
  info "No casks installed"
else
  CASK_TOTAL=$(echo "$CASKS" | wc -l | tr -d ' ')
  info "Installed casks: $CASK_TOTAL"
  echo "$CASKS" | while read -r cask; do
    info "  $cask"
  done
fi

# -- 7. Disk Usage ---------------------------------------------------------------
header "DISK USAGE"

if [[ -d "$ACTUAL_PREFIX" ]]; then
  BREW_SIZE=$(du -sh "$ACTUAL_PREFIX" 2>/dev/null | cut -f1 || echo "unknown")
  info "Total Homebrew directory size: $BREW_SIZE ($ACTUAL_PREFIX)"
fi

if [[ -d "$CELLAR" ]]; then
  CELLAR_SIZE=$(du -sh "$CELLAR" 2>/dev/null | cut -f1 || echo "unknown")
  info "Formulae (Cellar) size: $CELLAR_SIZE"
  FORMULA_COUNT=$(ls "$CELLAR" 2>/dev/null | wc -l | tr -d ' ')
  info "Formulae installed: $FORMULA_COUNT"
fi

CACHE=$("$BREW_BIN" --cache 2>/dev/null || echo "")
if [[ -n "$CACHE" ]] && [[ -d "$CACHE" ]]; then
  CACHE_SIZE=$(du -sh "$CACHE" 2>/dev/null | cut -f1 || echo "unknown")
  if [[ "$CACHE_SIZE" != "0B" ]]; then
    warn "Homebrew cache: $CACHE_SIZE (clear with: brew cleanup --prune=all)"
  else
    pass "Homebrew cache is empty"
  fi
fi

AVAIL=$(df -h "$ACTUAL_PREFIX" 2>/dev/null | tail -1 | awk '{print $4}' || echo "unknown")
info "Available space on Homebrew volume: $AVAIL"

echo -e "\n${BOLD}Homebrew health check complete.${NC}"
