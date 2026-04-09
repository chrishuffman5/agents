#!/bin/bash
# ============================================================================
# macOS - Log Analysis (Unified Logging)
# Version : 1.0.0
# Targets : macOS 14+ (Sonoma and later)
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================

set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
TIMEFRAME="${1:-1h}"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

echo "$SEP"
echo "  macOS LOG ANALYSIS"
echo "  Timeframe    : last $TIMEFRAME"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "$SEP"

# -- Section 1: Error and Fault Summary --------------------------------------
section "SECTION 1 - Error and Fault Count (last $TIMEFRAME)"

ERROR_COUNT=$(log show --last "$TIMEFRAME" --predicate 'messageType == error' --style compact 2>/dev/null | wc -l | tr -d ' ')
FAULT_COUNT=$(log show --last "$TIMEFRAME" --predicate 'messageType == fault' --style compact 2>/dev/null | wc -l | tr -d ' ')

echo "  Errors       : $ERROR_COUNT"
echo "  Faults       : $FAULT_COUNT"

# -- Section 2: Top Error Subsystems -----------------------------------------
section "SECTION 2 - Top Error Subsystems (last $TIMEFRAME)"

log show --last "$TIMEFRAME" --predicate 'messageType == error' --style compact 2>/dev/null \
    | awk -F'[\\[\\]]' '{print $2}' \
    | sort | uniq -c | sort -rn | head -15 \
    | awk '{printf "  %6d  %s\n", $1, $2}' \
    || echo "  Unable to parse error subsystems"

# -- Section 3: Top Fault Subsystems -----------------------------------------
section "SECTION 3 - Top Fault Subsystems (last $TIMEFRAME)"

log show --last "$TIMEFRAME" --predicate 'messageType == fault' --style compact 2>/dev/null \
    | awk -F'[\\[\\]]' '{print $2}' \
    | sort | uniq -c | sort -rn | head -15 \
    | awk '{printf "  %6d  %s\n", $1, $2}' \
    || echo "  Unable to parse fault subsystems"

# -- Section 4: Recent Crash Reports -----------------------------------------
section "SECTION 4 - Recent Crash Reports"

echo "  User-level crashes (~Library/Logs/DiagnosticReports/):"
USER_CRASHES=$(ls -lt ~/Library/Logs/DiagnosticReports/*.{crash,ips} 2>/dev/null | head -10)
if [[ -n "$USER_CRASHES" ]]; then
    echo "$USER_CRASHES" | awk '{printf "    %s %s %s  %s\n", $6, $7, $8, $NF}'
else
    echo "    No recent user crash reports found"
fi

echo ""
echo "  System-level crashes (/Library/Logs/DiagnosticReports/):"
SYS_CRASHES=$(ls -lt /Library/Logs/DiagnosticReports/*.{crash,ips,panic} 2>/dev/null | head -10)
if [[ -n "$SYS_CRASHES" ]]; then
    echo "$SYS_CRASHES" | awk '{printf "    %s %s %s  %s\n", $6, $7, $8, $NF}'
else
    echo "    No recent system crash reports found"
fi

# -- Section 5: Kernel Panics ------------------------------------------------
section "SECTION 5 - Kernel Panics"

PANICS=$(ls /Library/Logs/DiagnosticReports/*.panic 2>/dev/null)
if [[ -n "$PANICS" ]]; then
    PANIC_COUNT=$(echo "$PANICS" | wc -l | tr -d ' ')
    echo "  [WARN] $PANIC_COUNT kernel panic report(s) found:"
    echo "$PANICS" | while read -r f; do
        echo "    $(basename "$f")"
    done
else
    echo "  [OK]   No kernel panic reports found"
fi

# -- Section 6: Kernel Errors ------------------------------------------------
section "SECTION 6 - Kernel Errors (last $TIMEFRAME)"

log show --last "$TIMEFRAME" --predicate 'process == "kernel" AND messageType == error' --style compact 2>/dev/null \
    | tail -20 \
    | sed 's/^/    /' \
    || echo "    No kernel errors in timeframe"

# -- Section 7: WindowServer Faults ------------------------------------------
section "SECTION 7 - WindowServer Faults (last $TIMEFRAME)"

log show --last "$TIMEFRAME" --predicate 'subsystem == "com.apple.WindowServer" AND messageType == fault' --style compact 2>/dev/null \
    | tail -10 \
    | sed 's/^/    /' \
    || echo "    No WindowServer faults in timeframe"

echo ""
echo "$SEP"
echo "  Log analysis complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "  Tip: Adjust timeframe with: $0 <timeframe> (e.g., 30m, 2h, 1d)"
echo "$SEP"
