#!/usr/bin/env bash
# ============================================================================
# Debian - Package Audit
#
# Purpose : Package counts, pending security updates, held packages,
#           backports packages, recently installed/upgraded, orphans,
#           APT pinning, package integrity, unattended-upgrades status.
# Version : 1.0.0
# Targets : Debian 11+ (Bullseye and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Package Counts
#   2. Pending Security Updates
#   3. All Pending Updates
#   4. Held Packages
#   5. Packages from Backports
#   6. Recently Installed/Upgraded
#   7. Orphaned Packages
#   8. APT Pinning
#   9. Package Integrity
#  10. Unattended-Upgrades Status
# ============================================================================
set -euo pipefail

echo "=== DEBIAN PACKAGE AUDIT ==="
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Package Counts ---"
dpkg --get-selections | grep -c ' install$' | xargs echo "Installed:"
dpkg --get-selections | grep -c ' hold$' | xargs echo "Held:" || echo "Held: 0"
dpkg --get-selections | grep -c ' deinstall$' | xargs echo "Deinstall-marked:" || echo "Deinstall-marked: 0"
echo ""

echo "--- Pending Security Updates ---"
apt-get -s upgrade 2>/dev/null | grep -i 'security' | head -30 || \
    apt-get --just-print upgrade 2>/dev/null | grep '^Inst' | \
    grep -i 'security' | head -30 || echo "None detected (run apt-get update first)"
echo ""

echo "--- All Pending Updates ---"
apt-get --just-print upgrade 2>/dev/null | grep '^Inst' | head -30 || echo "None or not updated"
echo ""

echo "--- Held Packages ---"
apt-mark showhold 2>/dev/null || dpkg --get-selections | grep 'hold$' || echo "None"
echo ""

echo "--- Packages from Backports ---"
apt-cache policy 2>/dev/null | grep -B2 'backports' | grep -v 'backports' | \
    grep '^\*\*\*' | awk '{print $2}' | head -20 2>/dev/null || echo "None detected or requires review"
echo ""

echo "--- Recently Installed Packages (last 30 days) ---"
grep ' install ' /var/log/dpkg.log* 2>/dev/null | \
    awk '{print $4}' | sort -u | tail -30
echo ""

echo "--- Recently Upgraded Packages (last 7 days) ---"
grep ' upgrade ' /var/log/dpkg.log 2>/dev/null | \
    awk -v d="$(date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null)" '$1 >= d {print $4, $5, "->", $6}' | \
    sort | tail -20
echo ""

echo "--- Packages with rc Status (removed, config remains) ---"
dpkg -l | grep '^rc' | awk '{print $2}' | head -20
echo ""

echo "--- Orphaned Packages ---"
if command -v deborphan &>/dev/null; then
    echo "Library orphans:"
    deborphan 2>/dev/null | head -20
    echo ""
    echo "All orphans:"
    deborphan --all-packages 2>/dev/null | head -20
else
    echo "deborphan not installed (apt-get install deborphan)"
fi
echo ""

echo "--- APT Pinning (priorities) ---"
apt-cache policy 2>/dev/null | head -40
echo ""

echo "--- Package Integrity Check (dpkg --audit) ---"
dpkg --audit 2>/dev/null || echo "No issues found"
echo ""

echo "--- Unattended-Upgrades Status ---"
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    echo "unattended-upgrades is configured:"
    grep -v '^//' /etc/apt/apt.conf.d/50unattended-upgrades | grep -v '^$' | head -20
    echo ""
    echo "Last run:"
    ls -la /var/log/unattended-upgrades/ 2>/dev/null | head -5
else
    echo "unattended-upgrades not configured"
fi
