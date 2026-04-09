#!/usr/bin/env bash
# ============================================================================
# Btrfs/Snapper - Snapshot Inventory
#
# Purpose : Snapper snapshot list, age distribution, type breakdown,
#           space usage via qgroups, cleanup configuration, and
#           systemd timer health.
# Version : 1.0.0
# Targets : SLES 15+ with Snapper managing Btrfs snapshots
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Snapper Configuration
#   2. Snapshot List and Count
#   3. Age Distribution
#   4. Type Breakdown
#   5. Space Usage (qgroups)
#   6. Timer Status
#   7. Cleanup Recommendations
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
echo "  Snapper Snapshot Inventory - $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"

if ! command -v snapper &>/dev/null; then
    echo "  [ERROR] snapper is not installed"
    exit 1
fi

CONFIGS=$(snapper list-configs 2>/dev/null | awk 'NR>2 {print $1}')
if [[ -z "$CONFIGS" ]]; then
    echo "  [ERROR] No Snapper configurations found"
    exit 1
fi

for CONFIG in $CONFIGS; do
    section "SNAPPER CONFIG: $CONFIG"

    # Cleanup configuration
    CONFIG_FILE="/etc/snapper/configs/$CONFIG"
    echo "  --- Cleanup Configuration ---"
    if [[ -f "$CONFIG_FILE" ]]; then
        grep -E '^(NUMBER_|TIMELINE_|EMPTY_|SUBVOLUME=)' "$CONFIG_FILE" 2>/dev/null \
            | sort | sed 's/^/    /'
    else
        echo "    Config file not found: $CONFIG_FILE"
    fi

    # Full snapshot list
    echo ""
    echo "  --- Snapshot List ---"
    snapper -c "$CONFIG" list 2>/dev/null | head -25 | sed 's/^/    /' \
        || { echo "    Could not list snapshots"; continue; }

    TOTAL=$(snapper -c "$CONFIG" list 2>/dev/null | awk 'NR>2 && NF>1 {c++} END {print c+0}')
    echo ""
    echo "  Total snapshots: $TOTAL"
    if [[ "$TOTAL" -ge 100 ]]; then
        echo "  [WARN] High snapshot count -- consider running cleanup"
    elif [[ "$TOTAL" -ge 50 ]]; then
        echo "  [INFO] Moderate snapshot count -- monitor disk space"
    else
        echo "  [OK]   Snapshot count within normal range"
    fi

    # Age distribution
    echo ""
    echo "  --- Age Distribution ---"
    WEEK_AGO=$(date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d' 2>/dev/null || echo "")
    MONTH_AGO=$(date -d '30 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-30d '+%Y-%m-%d' 2>/dev/null || echo "")

    if [[ -n "$WEEK_AGO" ]]; then
        COUNT_WEEK=$(snapper -c "$CONFIG" list 2>/dev/null | awk -v w="$WEEK_AGO" \
            'NR>2 && $0 ~ /[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
            match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/); d=substr($0,RSTART,RLENGTH);
            if(d >= w) c++} END {print c+0}')
        COUNT_MONTH=$(snapper -c "$CONFIG" list 2>/dev/null | awk -v w="$MONTH_AGO" \
            'NR>2 && $0 ~ /[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
            match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/); d=substr($0,RSTART,RLENGTH);
            if(d >= w) c++} END {print c+0}')
        echo "    Last 7 days:  $COUNT_WEEK snapshots"
        echo "    Last 30 days: $COUNT_MONTH snapshots"
        echo "    All time:     $TOTAL snapshots"
    fi

    # Type breakdown
    echo ""
    echo "  --- Type Breakdown ---"
    SNAP_LIST=$(snapper -c "$CONFIG" list 2>/dev/null)
    PRE_COUNT=$(echo "$SNAP_LIST" | awk 'NR>2 {print $3}' | grep -c "pre" || echo "0")
    POST_COUNT=$(echo "$SNAP_LIST" | awk 'NR>2 {print $3}' | grep -c "post" || echo "0")
    SINGLE_COUNT=$(echo "$SNAP_LIST" | awk 'NR>2 {print $3}' | grep -c "single" || echo "0")
    TIMELINE_COUNT=$(echo "$SNAP_LIST" | grep -c "timeline" || echo "0")
    echo "    pre:      $PRE_COUNT"
    echo "    post:     $POST_COUNT"
    echo "    single:   $SINGLE_COUNT"
    echo "    timeline: $TIMELINE_COUNT"

    # Space usage via qgroups
    echo ""
    echo "  --- Space Usage (qgroups) ---"
    if btrfs qgroup show / &>/dev/null 2>&1; then
        echo "    [OK] Qgroups enabled"
        echo ""
        echo "    Top 10 snapshots by exclusive space:"
        btrfs qgroup show -reF / 2>/dev/null \
            | awk 'NR>2 && /^0\// {print $1, $4}' \
            | sort -k2 -h | tail -10 \
            | while read qid size; do
                echo "      qgroup $qid: $size exclusive"
            done
    else
        echo "    [INFO] Qgroups not enabled -- snapshot space accounting unavailable"
        echo "    Enable with: btrfs quota enable / && btrfs quota rescan /"
    fi

    # Timer status
    echo ""
    echo "  --- Systemd Timer Status ---"
    for TIMER in snapper-timeline.timer snapper-cleanup.timer; do
        status=$(systemctl is-active "$TIMER" 2>/dev/null || echo "not-found")
        enabled=$(systemctl is-enabled "$TIMER" 2>/dev/null || echo "not-found")
        printf "    %-30s active=%-10s enabled=%s\n" "$TIMER" "$status" "$enabled"
    done

    echo ""
done

# Cleanup recommendations
section "CLEANUP RECOMMENDATIONS"
TOTAL_ALL=$(snapper list 2>/dev/null | awk 'NR>2 && NF>1 {c++} END {print c+0}')
echo "  Total snapshots (all configs): $TOTAL_ALL"
echo ""
echo "  To run cleanup:"
echo "    snapper cleanup number"
echo "    snapper cleanup timeline"
echo "    snapper cleanup empty-pre-post"
echo ""
echo "  To delete a range:"
echo "    snapper delete 1-N"

echo ""
echo "$SEP"
echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"
