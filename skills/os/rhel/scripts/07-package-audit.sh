#!/usr/bin/env bash
# ============================================================================
# RHEL - Package Audit
#
# Purpose : Audit installed packages, pending updates, security errata,
#           module streams (RHEL 8/9), held packages, and GPG key status.
# Version : 1.0.0
# Targets : RHEL 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Package Summary
#   2. Pending Updates
#   3. Security Errata
#   4. Module Streams (RHEL 8/9)
#   5. GPG Key Status
#   6. Package Integrity
#   7. Recent Package Activity
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

echo "RHEL Package Audit"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"

rhel_ver=$(rpm -E '%{rhel}' 2>/dev/null || echo "unknown")
echo "RHEL Version: $rhel_ver"

# ── Section 1: Package Summary ──────────────────────────────────────────────
section "1. Package Summary"

total_pkgs=$(rpm -qa 2>/dev/null | wc -l)
echo "  Total installed packages: $total_pkgs"

echo ""
echo "  Package manager:"
if command -v dnf5 &>/dev/null; then
    echo "    dnf5 $(dnf5 --version 2>/dev/null | head -1)"
elif command -v dnf &>/dev/null; then
    echo "    dnf $(dnf --version 2>/dev/null | head -1)"
fi

echo ""
echo "  Kernel packages:"
rpm -q kernel --qf '    %{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null || echo "    unable to query"
echo "  Running kernel: $(uname -r)"

# ── Section 2: Pending Updates ──────────────────────────────────────────────
section "2. Pending Updates"

update_count=$(dnf check-update --quiet 2>/dev/null | grep -v "^$\|^Last\|^Obsoleting" | wc -l || echo 0)
echo "  Total pending updates: $update_count"

if [[ "$update_count" -gt 0 ]]; then
    echo ""
    echo "  Pending updates (first 20):"
    dnf check-update --quiet 2>/dev/null | grep -v "^$\|^Last\|^Obsoleting" | head -20 | sed 's/^/    /'
fi

# ── Section 3: Security Errata ──────────────────────────────────────────────
section "3. Security Errata"

sec_count=$(dnf updateinfo list --security 2>/dev/null | grep -c "RHSA" || echo 0)
echo "  Available RHSA (security) advisories: $sec_count"

if [[ "$sec_count" -gt 0 ]]; then
    echo ""
    echo "  Critical/Important advisories:"
    dnf updateinfo list --security 2>/dev/null | grep -E "Critical|Important" | head -15 | sed 's/^/    /'

    echo ""
    echo "  Security updates pending:"
    dnf check-update --security --quiet 2>/dev/null | grep -v "^$\|^Last" | head -15 | sed 's/^/    /'
fi

bug_count=$(dnf updateinfo list --bugfix 2>/dev/null | grep -c "RHBA" || echo 0)
echo ""
echo "  Available RHBA (bugfix) advisories: $bug_count"

# ── Section 4: Module Streams (RHEL 8/9) ────────────────────────────────────
section "4. Module Streams"

if [[ "$rhel_ver" == "8" || "$rhel_ver" == "9" ]]; then
    echo "  Enabled modules:"
    enabled_mods=$(dnf module list --enabled 2>/dev/null | grep -v "^$\|^Hint\|^Name\|^Red Hat\|^Last\|^\-" || true)
    if [[ -n "$enabled_mods" ]]; then
        echo "$enabled_mods" | sed 's/^/    /'
    else
        echo "    No module streams explicitly enabled"
    fi

    echo ""
    echo "  Installed module profiles:"
    installed_mods=$(dnf module list --installed 2>/dev/null | grep -v "^$\|^Hint\|^Name\|^Red Hat\|^Last\|^\-" || true)
    if [[ -n "$installed_mods" ]]; then
        echo "$installed_mods" | sed 's/^/    /'
    else
        echo "    No module profiles installed"
    fi

    echo ""
    echo "  Module config files: $(ls /etc/dnf/modules.d/*.module 2>/dev/null | wc -l || echo 0)"
elif [[ "$rhel_ver" == "10" ]]; then
    echo "  [INFO] RHEL 10 does not use module streams"
    echo "  AppStream packages use standard versioned package names"
else
    echo "  [INFO] Module status not checked (RHEL version: $rhel_ver)"
fi

# ── Section 5: GPG Key Status ──────────────────────────────────────────────
section "5. GPG Key Status"

echo "  Imported GPG keys:"
rpm -qa gpg-pubkey* --qf '    %{SUMMARY}\n' 2>/dev/null || echo "    unable to query"

echo ""
echo "  GPG key files in /etc/pki/rpm-gpg/:"
ls /etc/pki/rpm-gpg/ 2>/dev/null | sed 's/^/    /' || echo "    directory not found"

# ── Section 6: Package Integrity ────────────────────────────────────────────
section "6. Package Integrity (Quick Check)"

echo "  Checking for packages with missing files (sample of 20):"
rpm -qa 2>/dev/null | head -20 | while read -r pkg; do
    missing=$(rpm -V "$pkg" 2>/dev/null | grep "^missing" | wc -l)
    if [[ "$missing" -gt 0 ]]; then
        echo "    [WARN] $pkg: $missing missing file(s)"
    fi
done
echo "  (Full check: rpm -Va)"

# ── Section 7: Recent Package Activity ──────────────────────────────────────
section "7. Recent Package Activity"

echo "  Last 10 dnf transactions:"
dnf history list 2>/dev/null | head -12 | sed 's/^/    /'

echo ""
echo "  Last package update:"
dnf history list 2>/dev/null | grep -i "update\|upgrade" | head -1 | sed 's/^/    /'

last_update_date=$(dnf history list 2>/dev/null | awk 'NR==3 {print $4, $5, $6}')
if [[ -n "$last_update_date" ]]; then
    echo "  Most recent transaction date: $last_update_date"
fi

echo ""
echo "$SEP"
echo "  Package Audit Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
