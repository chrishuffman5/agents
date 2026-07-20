#!/usr/bin/env bash
# ============================================================================
# SLES - Supportconfig Collection and Analysis
#
# Purpose : Run supportconfig diagnostic collection and provide guided
#           analysis of the output archive. Checks for common issues
#           and summarizes key findings.
# Version : 1.0.0
# Targets : SLES 15 SP5+
# Safety  : Read-only (analysis mode). Supportconfig collection writes
#           to /var/log/ but does not modify system configuration.
#
# Sections:
#   1. Supportconfig Availability
#   2. Collection (optional)
#   3. Archive Analysis
#   4. Quick Health Summary
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

ANALYZE_ONLY=false
ARCHIVE_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --analyze)
            ANALYZE_ONLY=true
            ARCHIVE_PATH="${2:-}"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--analyze /path/to/scc_archive.txz]"
            echo ""
            echo "Without arguments: runs supportconfig and analyzes output"
            echo "With --analyze: analyzes an existing supportconfig archive"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

echo "$SEP"
echo "  SLES Supportconfig Collection and Analysis"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"

# ── Section 1: Supportconfig Availability ────────────────────────────────────
section "SECTION 1 - Supportconfig Availability"

if ! command -v supportconfig &>/dev/null; then
    echo "  [ERROR] supportconfig not installed"
    echo "  Install with: zypper install supportutils"
    exit 1
fi

echo "  supportconfig version: $(rpm -q supportutils 2>/dev/null || echo 'unknown')"
echo ""

# ── Section 2: Collection ───────────────────────────────────────────────────
if [[ "$ANALYZE_ONLY" == false ]]; then
    section "SECTION 2 - Running Supportconfig Collection"

    echo "  Running supportconfig -A (full collection)..."
    echo "  This may take several minutes..."
    echo ""

    supportconfig -A 2>&1 | tail -5 | sed 's/^/  /'

    # Find the most recent archive
    ARCHIVE_PATH=$(ls -t /var/log/scc_*.txz 2>/dev/null | head -1)
    if [[ -z "$ARCHIVE_PATH" ]]; then
        echo "  [ERROR] No supportconfig archive found after collection"
        exit 1
    fi
    echo ""
    echo "  Archive created: $ARCHIVE_PATH"
    echo "  Size: $(du -h "$ARCHIVE_PATH" 2>/dev/null | awk '{print $1}')"
fi

# ── Section 3: Archive Analysis ─────────────────────────────────────────────
section "SECTION 3 - Archive Analysis"

if [[ -z "$ARCHIVE_PATH" || ! -f "$ARCHIVE_PATH" ]]; then
    echo "  [ERROR] Archive not found: $ARCHIVE_PATH"
    echo "  Run without --analyze to collect, or specify valid archive path"
    exit 1
fi

TMPDIR=$(mktemp -d /tmp/scc_analysis_XXXXXX)
trap "rm -rf $TMPDIR" EXIT

echo "  Extracting: $ARCHIVE_PATH"
tar xf "$ARCHIVE_PATH" -C "$TMPDIR" 2>/dev/null || {
    echo "  [ERROR] Failed to extract archive"
    exit 1
}

# Find the extracted directory
ANALYSIS_DIR=$(find "$TMPDIR" -maxdepth 1 -type d -name "scc_*" | head -1)
if [[ -z "$ANALYSIS_DIR" ]]; then
    ANALYSIS_DIR="$TMPDIR"
fi

echo "  Analyzing contents..."
echo ""

# System identity
if [[ -f "$ANALYSIS_DIR/basic-environment.txt" ]]; then
    echo "  --- System Identity ---"
    grep -A2 "hostname" "$ANALYSIS_DIR/basic-environment.txt" 2>/dev/null | head -5 | sed 's/^/    /'
    grep "SUSE Linux\|VERSION_ID" "$ANALYSIS_DIR/basic-environment.txt" 2>/dev/null | head -3 | sed 's/^/    /'
    echo ""
fi

# Recent errors
if [[ -f "$ANALYSIS_DIR/messages.txt" ]]; then
    echo "  --- Recent Errors (from messages.txt) ---"
    error_count=$(grep -ci "error\|fail\|panic\|oops" "$ANALYSIS_DIR/messages.txt" 2>/dev/null || echo "0")
    echo "    Total error/fail/panic lines: $error_count"
    grep -i "error\|fail\|panic\|oops" "$ANALYSIS_DIR/messages.txt" 2>/dev/null | tail -10 | sed 's/^/    /'
    echo ""
fi

# Failed systemd units
if [[ -f "$ANALYSIS_DIR/systemd.txt" ]]; then
    echo "  --- Failed systemd Units ---"
    grep -i "failed" "$ANALYSIS_DIR/systemd.txt" 2>/dev/null | head -10 | sed 's/^/    /' || echo "    None found"
    echo ""
fi

# AppArmor denials
if [[ -f "$ANALYSIS_DIR/security-apparmor.txt" ]]; then
    echo "  --- AppArmor Denials ---"
    denial_count=$(grep -c "DENIED" "$ANALYSIS_DIR/security-apparmor.txt" 2>/dev/null || echo "0")
    echo "    Denial count: $denial_count"
    grep "DENIED" "$ANALYSIS_DIR/security-apparmor.txt" 2>/dev/null | tail -5 | sed 's/^/    /' || true
    echo ""
fi

# ── Section 4: Quick Health Summary ──────────────────────────────────────────
section "SECTION 4 - Quick Health Summary"

echo "  Archive: $ARCHIVE_PATH"
echo "  Analysis directory: $ANALYSIS_DIR"
echo ""
echo "  Key files in archive:"
ls -la "$ANALYSIS_DIR"/*.txt 2>/dev/null | awk '{print "    " $NF " (" $5 " bytes)"}' | head -20

echo ""
echo "  To upload to SUSE support:"
echo "    supportconfig -u -r <SR-NUMBER>"
echo ""
echo "  To share the archive:"
echo "    $ARCHIVE_PATH"

echo ""
echo "$SEP"
echo "  Supportconfig Analysis Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
