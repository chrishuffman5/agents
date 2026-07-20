#!/bin/bash
# ============================================================================
# macOS - LaunchAgents and LaunchDaemons Inventory
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
echo "  macOS LAUNCH AGENTS & DAEMONS INVENTORY"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "$SEP"

count_plists() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        find "$dir" -name "*.plist" 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

list_non_apple() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        find "$dir" -name "*.plist" 2>/dev/null | while read -r plist; do
            LABEL=$(basename "$plist" .plist)
            if [[ ! "$LABEL" =~ ^com\.apple\. ]]; then
                # Extract program or first argument
                PROG=$(/usr/libexec/PlistBuddy -c "Print :Program" "$plist" 2>/dev/null || \
                       /usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null || \
                       echo "unknown")
                ENABLED=$(/usr/libexec/PlistBuddy -c "Print :Disabled" "$plist" 2>/dev/null || echo "false")
                if [[ "$ENABLED" == "true" ]]; then
                    STATUS="disabled"
                else
                    STATUS="enabled"
                fi
                printf "    %-50s  %-8s  %s\n" "$LABEL" "$STATUS" "$PROG"
            fi
        done
    fi
}

# -- Section 1: Summary ------------------------------------------------------
section "SECTION 1 - Summary"

SYS_DAEMONS="/Library/LaunchDaemons"
SYS_AGENTS="/Library/LaunchAgents"
USER_AGENTS="$HOME/Library/LaunchAgents"
APPLE_DAEMONS="/System/Library/LaunchDaemons"
APPLE_AGENTS="/System/Library/LaunchAgents"

echo "  Location                              Total   Non-Apple"
echo "  ----------------------------------------  ------  ---------"

for dir_label_pair in \
    "/System/Library/LaunchDaemons|System Daemons (Apple)" \
    "/System/Library/LaunchAgents|System Agents (Apple)" \
    "/Library/LaunchDaemons|Third-Party Daemons" \
    "/Library/LaunchAgents|Third-Party Agents" \
    "$HOME/Library/LaunchAgents|User Agents"; do

    DIR="${dir_label_pair%%|*}"
    LABEL="${dir_label_pair##*|}"
    TOTAL=$(count_plists "$DIR")
    if [[ -d "$DIR" ]]; then
        NON_APPLE=$(find "$DIR" -name "*.plist" 2>/dev/null | xargs -I{} basename {} .plist | grep -cv "^com\.apple\." || echo "0")
    else
        NON_APPLE=0
    fi
    printf "  %-40s  %5s   %5s\n" "$LABEL" "$TOTAL" "$NON_APPLE"
done

# -- Section 2: Third-Party LaunchDaemons ------------------------------------
section "SECTION 2 - Non-Apple LaunchDaemons (/Library/LaunchDaemons)"

RESULT=$(list_non_apple "$SYS_DAEMONS")
if [[ -n "$RESULT" ]]; then
    echo "  Label                                              Status    Program"
    echo "  --------------------------------------------------  --------  -------"
    echo "$RESULT"
else
    echo "  No non-Apple LaunchDaemons found"
fi

# -- Section 3: Third-Party LaunchAgents (system) ----------------------------
section "SECTION 3 - Non-Apple LaunchAgents (/Library/LaunchAgents)"

RESULT=$(list_non_apple "$SYS_AGENTS")
if [[ -n "$RESULT" ]]; then
    echo "  Label                                              Status    Program"
    echo "  --------------------------------------------------  --------  -------"
    echo "$RESULT"
else
    echo "  No non-Apple system LaunchAgents found"
fi

# -- Section 4: User LaunchAgents -------------------------------------------
section "SECTION 4 - User LaunchAgents (~/Library/LaunchAgents)"

if [[ -d "$USER_AGENTS" ]]; then
    USER_LIST=$(list_non_apple "$USER_AGENTS")
    # Also list Apple agents here since user dir can have anything
    ALL_USER=$(find "$USER_AGENTS" -name "*.plist" 2>/dev/null | while read -r plist; do
        LABEL=$(basename "$plist" .plist)
        PROG=$(/usr/libexec/PlistBuddy -c "Print :Program" "$plist" 2>/dev/null || \
               /usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null || \
               echo "unknown")
        ENABLED=$(/usr/libexec/PlistBuddy -c "Print :Disabled" "$plist" 2>/dev/null || echo "false")
        if [[ "$ENABLED" == "true" ]]; then STATUS="disabled"; else STATUS="enabled"; fi
        printf "    %-50s  %-8s  %s\n" "$LABEL" "$STATUS" "$PROG"
    done)
    if [[ -n "$ALL_USER" ]]; then
        echo "  Label                                              Status    Program"
        echo "  --------------------------------------------------  --------  -------"
        echo "$ALL_USER"
    else
        echo "  No user LaunchAgents found"
    fi
else
    echo "  ~/Library/LaunchAgents directory does not exist"
fi

# -- Section 5: Currently Loaded Jobs ----------------------------------------
section "SECTION 5 - Currently Loaded Non-Apple Jobs"

echo "  System domain (non-Apple):"
sudo launchctl list 2>/dev/null \
    | awk '$3 !~ /^com\.apple\./ && $3 !~ /^-$/ {printf "    %-6s %-6s %s\n", $1, $2, $3}' \
    | head -30 \
    || echo "    Requires sudo for system domain"

echo ""
echo "  GUI domain (non-Apple):"
launchctl list 2>/dev/null \
    | awk '$3 !~ /^com\.apple\./ && $3 !~ /^-$/ {printf "    %-6s %-6s %s\n", $1, $2, $3}' \
    | head -30 \
    || echo "    Unable to query GUI domain"

echo ""
echo "$SEP"
echo "  LaunchAgent/Daemon inventory complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
