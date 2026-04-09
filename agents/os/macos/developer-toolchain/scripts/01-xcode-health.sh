#!/usr/bin/env bash
# ============================================================================
# macOS Developer Toolchain - Xcode Health Check
#
# Version : 1.0.0
# Targets : macOS 14+ with Xcode 15 or later
# Safety  : Read-only. No modifications to system configuration.
#
# Checks: active developer directory, Xcode installations, CLT, Swift,
#         Clang, available SDKs, simulator inventory, SPM
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }

echo -e "${BOLD}Xcode Health Check${NC} — $(hostname) — $(date)"

# -- 1. Active Developer Directory ----------------------------------------------
header "ACTIVE DEVELOPER DIRECTORY"

DEV_DIR=$(xcode-select --print-path 2>/dev/null || echo "NOT SET")
info "Developer directory: $DEV_DIR"

if [[ "$DEV_DIR" == "/Library/Developer/CommandLineTools" ]]; then
  warn "Active developer dir points to CLT only -- full Xcode not active"
  info "Switch with: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
elif [[ -d "$DEV_DIR" ]]; then
  pass "Developer directory exists and is reachable"
else
  fail "Developer directory does not exist: $DEV_DIR"
fi

if xcodebuild -license check &>/dev/null 2>&1; then
  pass "Xcode license accepted"
else
  warn "Xcode license may not be accepted -- run: sudo xcodebuild -license accept"
fi

# -- 2. Xcode Installations -----------------------------------------------------
header "XCODE INSTALLATIONS"

XCODE_FOUND=0
for app in /Applications/Xcode*.app; do
  [[ -d "$app" ]] || continue
  XCODE_FOUND=1
  VERSION=$("$app/Contents/Developer/usr/bin/xcodebuild" -version 2>/dev/null | head -1 || echo "unknown")
  BUILD=$("$app/Contents/Developer/usr/bin/xcodebuild" -version 2>/dev/null | tail -1 || echo "")
  info "$app -> $VERSION ($BUILD)"
done

if [[ $XCODE_FOUND -eq 0 ]]; then
  warn "No Xcode.app found in /Applications"
fi

SPOTLIGHT_XCODES=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null || true)
if [[ -n "$SPOTLIGHT_XCODES" ]]; then
  while IFS= read -r xc; do
    [[ -n "$xc" ]] && info "Spotlight found: $xc"
  done <<< "$SPOTLIGHT_XCODES"
fi

if command -v xcodebuild &>/dev/null; then
  ACTIVE_XCODE=$(xcodebuild -version 2>/dev/null | head -1)
  pass "Active Xcode: $ACTIVE_XCODE"
else
  fail "xcodebuild not available -- Xcode or CLT not installed"
fi

# -- 3. Xcode Command Line Tools ------------------------------------------------
header "COMMAND LINE TOOLS"

CLT_PKG="com.apple.pkg.CLTools_Executables"
CLT_VERSION=$(pkgutil --pkg-info="$CLT_PKG" 2>/dev/null | awk '/version:/ {print $2}')

if [[ -n "$CLT_VERSION" ]]; then
  pass "CLT installed -- version: $CLT_VERSION"
else
  warn "CLT package not detected via pkgutil"
fi

if [[ -d "/Library/Developer/CommandLineTools" ]]; then
  pass "CLT directory exists: /Library/Developer/CommandLineTools"
else
  warn "CLT directory not found -- run: xcode-select --install"
fi

XCODE_SELECT_VER=$(xcode-select --version 2>/dev/null || echo "unavailable")
info "xcode-select version: $XCODE_SELECT_VER"

# -- 4. Swift and Clang Versions ------------------------------------------------
header "SWIFT AND CLANG VERSIONS"

if command -v swift &>/dev/null; then
  SWIFT_VER=$(swift --version 2>/dev/null | head -1)
  pass "Swift: $SWIFT_VER"
  if [[ -n "${TOOLCHAINS:-}" ]]; then
    warn "TOOLCHAINS env var set: $TOOLCHAINS (overriding Xcode bundled toolchain)"
  fi
else
  fail "swift not found in PATH"
fi

if command -v clang &>/dev/null; then
  CLANG_VER=$(clang --version 2>/dev/null | head -1)
  pass "Clang: $CLANG_VER"
else
  fail "clang not found in PATH"
fi

if command -v swiftc &>/dev/null; then
  info "swiftc path: $(command -v swiftc)"
fi

if command -v swiftenv &>/dev/null; then
  info "swiftenv installed: $(swiftenv --version 2>/dev/null)"
  info "swiftenv active: $(swiftenv version 2>/dev/null)"
fi

# -- 5. Available SDKs ----------------------------------------------------------
header "AVAILABLE SDKS"

if command -v xcodebuild &>/dev/null; then
  xcodebuild -showsdks 2>/dev/null | grep -E '^\s+' | while read -r line; do
    info "$line"
  done
else
  warn "xcodebuild not available -- cannot list SDKs"
fi

MACOS_SDK=$(xcrun --show-sdk-path --sdk macosx 2>/dev/null || echo "not found")
info "Active macOS SDK path: $MACOS_SDK"

MACOS_SDK_VER=$(xcrun --show-sdk-version --sdk macosx 2>/dev/null || echo "unknown")
info "Active macOS SDK version: $MACOS_SDK_VER"

# -- 6. Simulator Inventory -----------------------------------------------------
header "SIMULATOR INVENTORY"

if xcrun simctl list runtimes &>/dev/null 2>&1; then
  RUNTIME_COUNT=$(xcrun simctl list runtimes 2>/dev/null | grep -c "iOS\|macOS\|watchOS\|tvOS\|visionOS" || echo "0")
  info "Installed simulator runtimes: $RUNTIME_COUNT"
  xcrun simctl list runtimes 2>/dev/null | grep -v "^==" | grep -v "^$" | while read -r line; do
    info "  $line"
  done

  BOOTED=$(xcrun simctl list devices 2>/dev/null | grep "Booted" | wc -l | tr -d ' ')
  if [[ "$BOOTED" -gt 0 ]]; then
    warn "$BOOTED simulator(s) currently booted"
  else
    pass "No simulators currently running"
  fi
else
  info "Simulator not available (CLT-only install)"
fi

# -- 7. Swift Package Manager ---------------------------------------------------
header "SWIFT PACKAGE MANAGER"

if command -v swift &>/dev/null; then
  SPM_VER=$(swift package --version 2>/dev/null | head -1 || echo "unavailable")
  info "swift package version: $SPM_VER"
fi

if [[ -f "Package.swift" ]]; then
  info "Package.swift found in current directory"
  swift package show-dependencies 2>/dev/null | head -20 || true
fi

SPM_CACHE="${HOME}/.swiftpm/cache"
if [[ -d "$SPM_CACHE" ]]; then
  CACHE_SIZE=$(du -sh "$SPM_CACHE" 2>/dev/null | cut -f1 || echo "unknown")
  info "SPM cache size: $CACHE_SIZE ($SPM_CACHE)"
fi

echo -e "\n${BOLD}Xcode health check complete.${NC}"
