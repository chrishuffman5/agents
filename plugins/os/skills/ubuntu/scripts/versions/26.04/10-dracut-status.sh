#!/usr/bin/env bash
# ============================================================================
# Ubuntu 26.04 - Dracut Initramfs Status
#
# Purpose : Detect dracut vs initramfs-tools, inventory modules, verify
#           initramfs files, and test regeneration readiness.
# Version : 26.1.0
# Targets : Ubuntu 26.04 LTS (Resolute Raccoon)
# Safety  : Read-only unless run as root (regeneration test modifies /boot).
#
# Sections:
#   1. Ubuntu Version
#   2. Initramfs Generator Detection
#   3. Initramfs Files
#   4. Dracut Module Inventory
#   5. Custom Dracut Config
#   6. Regeneration Test
#   7. Boot Cmdline
# ============================================================================
set -euo pipefail

PASS=0; WARN=0; FAIL=0
result() {
    local s=$1 m=$2
    printf "%-10s %s\n" "[$s]" "$m"
    case $s in
        PASS) ((PASS++)) ;;
        WARN) ((WARN++)) ;;
        FAIL) ((FAIL++)) ;;
    esac
}

echo "=== Dracut Initramfs Status (Ubuntu 26.04+) ==="
echo "Host: $(hostname) | Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# -- 1. Ubuntu version -----------------------------------------------------
echo "--- Ubuntu Version ---"
if grep -q "26.04" /etc/os-release 2>/dev/null; then
    result PASS "Ubuntu 26.04 detected -- dracut is the default initramfs generator"
elif grep -q "24.04" /etc/os-release 2>/dev/null; then
    result WARN "Ubuntu 24.04 -- dracut may be manually installed; initramfs-tools is default"
else
    DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    result WARN "Unexpected OS: $DISTRO"
fi

# -- 2. Generator detection ------------------------------------------------
echo ""
echo "--- Initramfs Generator Detection ---"
DRACUT_INSTALLED=false

if command -v dracut &>/dev/null; then
    DRACUT_VER=$(dracut --version 2>/dev/null | head -1)
    result PASS "dracut installed: $DRACUT_VER"
    DRACUT_INSTALLED=true
else
    result FAIL "dracut not found -- not installed or not in PATH"
fi

if dpkg -l initramfs-tools 2>/dev/null | grep -q "^ii"; then
    INITRAMFS_VER=$(dpkg -l initramfs-tools | awk '/^ii/{print $3}')
    result WARN "initramfs-tools also installed ($INITRAMFS_VER) -- may conflict with dracut"
else
    result PASS "initramfs-tools not installed -- dracut is sole generator"
fi

# -- 3. Initramfs files ----------------------------------------------------
echo ""
echo "--- Initramfs Files ---"
KERNEL=$(uname -r)
DRACUT_IMG="/boot/initramfs-${KERNEL}.img"
INITRD_IMG="/boot/initrd.img-${KERNEL}"

if [[ -f "$DRACUT_IMG" ]]; then
    DRACUT_SIZE=$(du -sh "$DRACUT_IMG" | cut -f1)
    DRACUT_MTIME=$(stat -c "%y" "$DRACUT_IMG" | cut -d. -f1)
    result PASS "Dracut initramfs present: $DRACUT_IMG ($DRACUT_SIZE, modified: $DRACUT_MTIME)"
else
    result WARN "Dracut initramfs not found at $DRACUT_IMG"
fi

if [[ -f "$INITRD_IMG" ]]; then
    INITRD_SIZE=$(du -sh "$INITRD_IMG" | cut -f1)
    result WARN "Legacy initrd present: $INITRD_IMG ($INITRD_SIZE) -- verify dracut is managing boot"
fi

# -- 4. Module inventory ---------------------------------------------------
echo ""
echo "--- Dracut Module Inventory ---"
if $DRACUT_INSTALLED; then
    MODULE_LIST=$(dracut --list-modules 2>/dev/null | sort || echo "failed")
    MODULE_COUNT=$(echo "$MODULE_LIST" | wc -l)
    echo "       Total modules available: $MODULE_COUNT"

    for mod in network dm crypt kernel-modules systemd; do
        if echo "$MODULE_LIST" | grep -q "^${mod}$"; then
            result PASS "Module available: $mod"
        else
            result WARN "Module not found: $mod"
        fi
    done
fi

# -- 5. Custom config ------------------------------------------------------
echo ""
echo "--- Custom Dracut Config ---"
if ls /etc/dracut.conf.d/*.conf &>/dev/null; then
    for f in /etc/dracut.conf.d/*.conf; do
        echo "       $f:"
        grep -v "^#" "$f" | grep -v "^$" | sed 's/^/         /' || true
    done
else
    echo "       No custom config files in /etc/dracut.conf.d/"
fi

# -- 6. Regeneration test --------------------------------------------------
echo ""
echo "--- Regeneration Test ---"
if $DRACUT_INSTALLED; then
    if dracut --no-hostonly --print-cmdline 2>/dev/null | head -3; then
        result PASS "dracut dry-run successful (--print-cmdline)"
    else
        result WARN "dracut dry-run produced no output -- run 'dracut --force' manually"
    fi
else
    result WARN "dracut not installed -- cannot test regeneration"
fi

# -- 7. Boot cmdline -------------------------------------------------------
echo ""
echo "--- Current Boot Cmdline ---"
CMDLINE=$(cat /proc/cmdline)
echo "       $CMDLINE"
if echo "$CMDLINE" | grep -q "rd\."; then
    result PASS "dracut rd.* options detected in cmdline"
else
    echo "       No rd.* options (normal for default boot)"
fi

echo ""
echo "=== Summary: PASS=$PASS  WARN=$WARN  FAIL=$FAIL ==="
echo ""
echo "Key commands:"
echo "  dracut --force                    # regenerate for current kernel"
echo "  dracut --regenerate-all --force   # regenerate for all kernels"
echo "  dracut --list-modules             # list available modules"
echo "  lsinitrd /boot/initramfs-\$(uname -r).img | head -30"
