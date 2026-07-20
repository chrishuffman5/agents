#!/bin/bash
# ============================================================================
# macOS - Application Inventory
# Version : 1.0.0
# Targets : macOS 14+ (Sonoma and later)
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================

set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

echo "$SEP"
echo "  macOS APPLICATION INVENTORY"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "$SEP"

# -- Section 1: /Applications ------------------------------------------------
section "SECTION 1 - Applications (/Applications)"

APP_COUNT=$(find /Applications -maxdepth 2 -name "*.app" 2>/dev/null | wc -l | tr -d ' ')
echo "  Total .app bundles: $APP_COUNT"
echo ""

echo "  Application listing:"
find /Applications -maxdepth 2 -name "*.app" -print0 2>/dev/null \
    | xargs -0 -I{} bash -c '
        NAME=$(basename "{}" .app)
        VER=$(defaults read "{}"/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "?")
        ARCH=$(file "{}"/Contents/MacOS/* 2>/dev/null | head -1 | grep -o "arm64\|x86_64\|universal" | head -1 || echo "?")
        printf "    %-40s  v%-12s  %s\n" "$NAME" "$VER" "$ARCH"
    ' 2>/dev/null | sort || echo "    Unable to enumerate applications"

# -- Section 2: Homebrew Packages --------------------------------------------
section "SECTION 2 - Homebrew Packages"

if command -v brew &>/dev/null; then
    BREW_PREFIX=$(brew --prefix 2>/dev/null)
    echo "  Homebrew prefix: $BREW_PREFIX"
    echo ""

    FORMULA_COUNT=$(brew list --formula 2>/dev/null | wc -l | tr -d ' ')
    CASK_COUNT=$(brew list --cask 2>/dev/null | wc -l | tr -d ' ')
    echo "  Formulae installed: $FORMULA_COUNT"
    echo "  Casks installed   : $CASK_COUNT"

    echo ""
    echo "  Installed formulae:"
    brew list --formula --versions 2>/dev/null | sed 's/^/    /' || echo "    Unable to list"

    echo ""
    echo "  Installed casks:"
    brew list --cask --versions 2>/dev/null | sed 's/^/    /' || echo "    Unable to list"

    echo ""
    echo "  Outdated packages:"
    OUTDATED=$(brew outdated 2>/dev/null)
    if [[ -n "$OUTDATED" ]]; then
        echo "$OUTDATED" | sed 's/^/    /'
    else
        echo "    All packages up to date"
    fi
else
    echo "  [INFO] Homebrew is not installed"
fi

# -- Section 3: Mac App Store Apps -------------------------------------------
section "SECTION 3 - Mac App Store Apps"

if command -v mas &>/dev/null; then
    echo "  Installed via App Store (mas list):"
    mas list 2>/dev/null | sed 's/^/    /' || echo "    Unable to list"
else
    echo "  [INFO] mas (Mac App Store CLI) not installed"
    echo "         Install: brew install mas"
    echo ""
    echo "  System profiler App Store apps:"
    system_profiler SPApplicationsDataType 2>/dev/null \
        | grep -B1 "Obtained from: Apple" \
        | grep "Location:" \
        | awk -F'/' '{print $NF}' \
        | sort \
        | head -30 \
        | sed 's/^/    /' \
        || echo "    Unable to query"
fi

# -- Section 4: Login Items --------------------------------------------------
section "SECTION 4 - Login Items"

echo "  Login items (sfltool):"
sfltool dumpbtm 2>/dev/null | head -40 | sed 's/^/    /' || echo "    sfltool output unavailable (may require sudo or Full Disk Access)"

# -- Section 5: Developer Tools -----------------------------------------------
section "SECTION 5 - Developer Tools"

echo "  Xcode CLT path : $(xcode-select -p 2>/dev/null || echo 'Not installed')"

if command -v xcodebuild &>/dev/null; then
    echo "  Xcode version  : $(xcodebuild -version 2>/dev/null | head -1)"
fi

echo "  Git             : $(git --version 2>/dev/null || echo 'Not installed')"
echo "  Python3         : $(python3 --version 2>/dev/null || echo 'Not installed')"
echo "  Ruby            : $(ruby --version 2>/dev/null | head -1 || echo 'Not installed')"
echo "  Node.js         : $(node --version 2>/dev/null || echo 'Not installed')"
echo "  Swift           : $(swift --version 2>/dev/null | head -1 || echo 'Not installed')"

echo ""
echo "$SEP"
echo "  Application inventory complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
