#!/usr/bin/env bash
# ============================================================================
# RHEL 10 - Image Mode (bootc) Status Diagnostic
#
# Purpose : Detect image mode deployment, report current/staged/rollback
#           images, container registry configuration, soft-reboot readiness,
#           and auto-update timer status.
# Version : 1.0.0
# Targets : RHEL 10.x (Image Mode / bootc deployments)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Image Mode Detection
#   2. Current Booted Image
#   3. Staged Update
#   4. Rollback Target
#   5. Container Registry Config
#   6. Soft Reboot Readiness
#   7. Auto-Update Configuration
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }
ok()   { echo "  [OK]   $1"; }
warn() { echo "  [WARN] $1"; }
fail() { echo "  [FAIL] $1"; }
info() { echo "  [INFO] $1"; }

echo "RHEL 10 Image Mode (bootc) Status Report"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"

BOOTC_AVAILABLE=false

# ── Section 1: Image Mode Detection ─────────────────────────────────────────
section "1. Image Mode Detection"

if command -v bootc &>/dev/null; then
    ok "bootc binary found: $(bootc --version 2>/dev/null || echo 'version unknown')"
    BOOTC_AVAILABLE=true
else
    warn "bootc not installed -- system may be in traditional package mode"
fi

if command -v rpm-ostree &>/dev/null; then
    warn "rpm-ostree found -- may be an older OSTree deployment, not bootc"
fi

if [[ -f /run/ostree-booted ]]; then
    ok "System is booted from an immutable image (ostree/bootc)"
elif [[ "$BOOTC_AVAILABLE" == "true" ]]; then
    warn "bootc available but /run/ostree-booted not present -- verify image mode"
else
    info "Traditional (package-based) RHEL installation detected"
fi

# ── Section 2: Current Booted Image ─────────────────────────────────────────
section "2. Current Booted Image"

if [[ "$BOOTC_AVAILABLE" == "true" ]]; then
    bootc status 2>/dev/null | sed 's/^/    /' || warn "bootc status returned non-zero"

    if command -v jq &>/dev/null; then
        BOOTC_JSON=$(bootc status --format json 2>/dev/null || echo '{}')
        BOOTED_IMAGE=$(echo "$BOOTC_JSON" | jq -r '.status.booted.image.image.image // "unknown"' 2>/dev/null)
        BOOTED_DIGEST=$(echo "$BOOTC_JSON" | jq -r '.status.booted.image.imageDigest // "unknown"' 2>/dev/null)
        echo ""
        info "Booted image:  $BOOTED_IMAGE"
        info "Image digest:  $BOOTED_DIGEST"
    fi
else
    info "bootc not available; skipping image status"
fi

# ── Section 3: Staged Update ────────────────────────────────────────────────
section "3. Staged Update"

if [[ "$BOOTC_AVAILABLE" == "true" ]] && command -v jq &>/dev/null; then
    BOOTC_JSON=$(bootc status --format json 2>/dev/null || echo '{}')
    STAGED=$(echo "$BOOTC_JSON" | jq -r '.status.staged // null' 2>/dev/null)
    if [[ "$STAGED" != "null" && -n "$STAGED" ]]; then
        STAGED_IMAGE=$(echo "$BOOTC_JSON" | jq -r '.status.staged.image.image.image // "unknown"')
        STAGED_DIGEST=$(echo "$BOOTC_JSON" | jq -r '.status.staged.image.imageDigest // "unknown"')
        warn "Staged update pending:"
        info "  Image:  $STAGED_IMAGE"
        info "  Digest: $STAGED_DIGEST"
        info "  Apply:  reboot (or 'systemctl soft-reboot' for userspace-only)"
    else
        ok "No staged update -- system is current"
    fi
else
    info "Skipping staged update check (jq or bootc unavailable)"
fi

# ── Section 4: Rollback Target ──────────────────────────────────────────────
section "4. Rollback Target"

if [[ "$BOOTC_AVAILABLE" == "true" ]] && command -v jq &>/dev/null; then
    BOOTC_JSON=$(bootc status --format json 2>/dev/null || echo '{}')
    ROLLBACK=$(echo "$BOOTC_JSON" | jq -r '.status.rollback // null' 2>/dev/null)
    if [[ "$ROLLBACK" != "null" && -n "$ROLLBACK" ]]; then
        ROLLBACK_IMAGE=$(echo "$BOOTC_JSON" | jq -r '.status.rollback.image.image.image // "unknown"')
        ok "Rollback target available:"
        info "  Image:  $ROLLBACK_IMAGE"
        info "  Rollback: bootc rollback && reboot"
    else
        warn "No rollback target -- cannot revert if update fails"
    fi
else
    info "Skipping rollback check"
fi

# ── Section 5: Container Registry Config ────────────────────────────────────
section "5. Container Registry Config"

if [[ -f /etc/containers/registries.conf ]]; then
    ok "Container registries config: /etc/containers/registries.conf"
    info "Unqualified search registries:"
    grep -E 'unqualified-search-registries' /etc/containers/registries.conf 2>/dev/null | head -3 | sed 's/^/    /'
else
    warn "/etc/containers/registries.conf not found"
fi

# Auth config
AUTH_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/containers/auth.json"
if [[ -f "$AUTH_FILE" ]]; then
    ok "Registry auth config found: $AUTH_FILE"
    if command -v jq &>/dev/null; then
        info "Configured registries: $(jq -r '.auths | keys[]' "$AUTH_FILE" 2>/dev/null | tr '\n' ' ')"
    fi
elif [[ -f /etc/containers/auth.json ]]; then
    ok "System-wide registry auth: /etc/containers/auth.json"
else
    warn "No registry auth config found -- pulls from private registries will fail"
fi

# ── Section 6: Soft Reboot Readiness ────────────────────────────────────────
section "6. Soft Reboot Readiness"

SYSTEMD_VER=$(systemctl --version 2>/dev/null | head -1 | awk '{print $2}')
if [[ -n "$SYSTEMD_VER" ]] && (( SYSTEMD_VER >= 254 )); then
    ok "systemd $SYSTEMD_VER supports soft-reboot"
    info "Command: systemctl soft-reboot"
else
    warn "systemd ${SYSTEMD_VER:-unknown} -- soft-reboot requires v254+"
fi

# ── Section 7: Auto-Update Configuration ────────────────────────────────────
section "7. Auto-Update Configuration"

if systemctl is-enabled bootc-fetch-apply-updates.timer &>/dev/null 2>&1; then
    ok "bootc auto-update timer is enabled"
    systemctl status bootc-fetch-apply-updates.timer --no-pager -l 2>/dev/null | grep -E 'Active|Trigger' | sed 's/^/    /'
elif systemctl list-timers 2>/dev/null | grep -q bootc; then
    warn "bootc timer exists but is not enabled"
else
    info "No bootc auto-update timer configured (manual updates only)"
fi

echo ""
echo "$SEP"
echo "  Summary"
echo "$SEP"
if [[ "$BOOTC_AVAILABLE" == "true" ]]; then
    echo "  System is running in Image Mode (bootc)."
    echo "  Use 'bootc upgrade' to stage updates."
else
    echo "  System is in traditional package mode. Image Mode not applicable."
fi
echo ""
echo "$SEP"
echo "  bootc Status Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
