#!/usr/bin/env bash
# ============================================================================
# Rocky/AlmaLinux v8 - CentOS Migration Artifact Detection
#
# Purpose : Detect if the system was converted from CentOS 8, identify
#           migration artifacts, residual CentOS-signed packages, and
#           check for repo cleanup completeness.
# Version : 1.0.0
# Targets : Rocky Linux 8 / AlmaLinux 8 (migrated from CentOS 8)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Distro Identification
#   2. Residual CentOS Release Packages
#   3. CentOS-Signed Packages
#   4. Leftover CentOS Repo Files
#   5. Migration Log Artifacts
#   6. Orphaned Packages
#   7. GPG Key Audit
#   8. distro-sync Completeness
# ============================================================================
set -euo pipefail

PASS=0
WARN=0
FAIL=0

pass()  { echo "[PASS] $*"; ((PASS++));  }
warn()  { echo "[WARN] $*"; ((WARN++));  }
fail()  { echo "[FAIL] $*"; ((FAIL++));  }
info()  { echo "[INFO] $*"; }

echo "=== CentOS Migration Status Check ==="
echo "Date: $(date)"
echo ""

# --- Distro identification ---
info "Distro identification"
if [ -f /etc/rocky-release ]; then
    cat /etc/rocky-release
elif [ -f /etc/almalinux-release ]; then
    cat /etc/almalinux-release
else
    warn "Neither Rocky nor AlmaLinux release file found"
fi

# --- Residual CentOS release packages ---
echo ""
info "Checking for residual CentOS release packages..."
CENTOS_PKGS=$(rpm -qa | grep -iE '^centos-(linux|stream)-(release|repos|gpg-keys)' || true)
if [ -n "$CENTOS_PKGS" ]; then
    fail "Residual CentOS release packages found:"
    echo "$CENTOS_PKGS" | while read -r pkg; do echo "  - $pkg"; done
else
    pass "No CentOS release packages found"
fi

# --- CentOS-signed packages ---
echo ""
info "Checking for packages signed with CentOS GPG key..."
CENTOS_SIGNED=$(rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE} %{SIGPGP:pgpsig}\n' 2>/dev/null \
    | grep -i "Key ID" | grep -i "8483c65d\|483c65d" || true)
if [ -n "$CENTOS_SIGNED" ]; then
    warn "Packages still signed with CentOS GPG key detected:"
    echo "$CENTOS_SIGNED" | head -20
    warn "These may be packages that weren't updated during migration"
else
    pass "No packages with CentOS GPG signatures detected"
fi

# --- Leftover CentOS repo files ---
echo ""
info "Checking for leftover CentOS repo files..."
CENTOS_REPOS=$(find /etc/yum.repos.d/ -name "*centos*" -o -name "*CentOS*" 2>/dev/null | sort || true)
if [ -n "$CENTOS_REPOS" ]; then
    fail "CentOS repo files still present:"
    echo "$CENTOS_REPOS" | while read -r f; do echo "  - $f"; done
else
    pass "No CentOS repo files found in /etc/yum.repos.d/"
fi

# --- Migration log artifacts ---
echo ""
info "Checking for migration log artifacts..."
for logpath in /var/log/migrate2rocky.log /var/log/almalinux-deploy.log; do
    if [ -f "$logpath" ]; then
        info "Migration log found: $logpath"
        LAST_LINE=$(tail -1 "$logpath")
        info "Last log entry: $LAST_LINE"
        if echo "$LAST_LINE" | grep -qi "complete\|success\|done"; then
            pass "Migration log indicates successful completion"
        else
            warn "Migration log last entry does not confirm success — review $logpath"
        fi
    fi
done

# --- Orphaned packages ---
echo ""
info "Checking for orphaned packages not from active repos..."
ORPHANS=$(dnf list extras 2>/dev/null | grep -v "^Extra" | grep -v "^Loaded" | grep -v "^$" || true)
if [ -n "$ORPHANS" ]; then
    ORPHAN_COUNT=$(echo "$ORPHANS" | wc -l)
    warn "$ORPHAN_COUNT orphaned package(s) not from any active repo:"
    echo "$ORPHANS" | head -20
    if [ "$ORPHAN_COUNT" -gt 20 ]; then
        warn "(output truncated — run: dnf list extras)"
    fi
else
    pass "No orphaned packages detected"
fi

# --- GPG key audit ---
echo ""
info "Checking installed GPG keys..."
rpm -q gpg-pubkey --qf "%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n" | \
    grep -i "centos\|rocky\|alma\|redhat" || true

# --- distro-sync completeness ---
echo ""
info "Checking if distro-sync artifacts remain..."
CENTOS_RELEASE=$(rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}\n' | grep '\.centos\.' || true)
if [ -n "$CENTOS_RELEASE" ]; then
    warn "Packages with .centos. in release string (may need distro-sync):"
    echo "$CENTOS_RELEASE" | head -20
else
    pass "No packages with .centos. release tag found"
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
echo "PASS: $PASS | WARN: $WARN | FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "ACTION REQUIRED: Migration artifacts present. Consider running:"
    echo "  dnf distro-sync  # to realign packages"
    echo "  dnf remove <centos-packages>  # to remove residual CentOS pkgs"
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo "WARNINGS present — review above items"
    exit 0
else
    echo "System appears clean of CentOS migration artifacts"
    exit 0
fi
