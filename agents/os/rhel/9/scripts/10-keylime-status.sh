#!/usr/bin/env bash
# ============================================================================
# RHEL 9 - Keylime Remote Attestation Status
#
# Purpose : Report Keylime service status, TPM hardware presence, agent
#           configuration, IMA runtime integrity, and attestation readiness.
# Version : 1.0.0
# Targets : RHEL 9.x
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Keylime Package Installation
#   2. Keylime Service Status
#   3. TPM Hardware Status
#   4. Keylime Agent Configuration
#   5. Agent UUID
#   6. IMA Runtime Integrity Status
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }
ok()   { echo "  [OK]   $1"; }
warn() { echo "  [WARN] $1"; }
fail() { echo "  [FAIL] $1"; }
info() { echo "  [INFO] $1"; }

echo "RHEL 9 Keylime Remote Attestation Status"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"
echo "Kernel:    $(uname -r)"

# ── Section 1: Package Installation ─────────────────────────────────────────
section "1. Keylime Package Installation"

if rpm -q keylime &>/dev/null; then
    ok "keylime installed: $(rpm -q keylime)"
else
    fail "keylime package not installed"
    info "Install with: dnf install keylime"
fi

if rpm -q tpm2-tools &>/dev/null; then
    ok "tpm2-tools installed: $(rpm -q tpm2-tools)"
else
    warn "tpm2-tools not installed (required for TPM operations)"
fi

if rpm -q tpm2-tss &>/dev/null; then
    ok "tpm2-tss installed: $(rpm -q tpm2-tss)"
fi

# ── Section 2: Service Status ───────────────────────────────────────────────
section "2. Keylime Service Status"

SERVICES=("keylime_verifier" "keylime_registrar" "keylime_agent")

for svc in "${SERVICES[@]}"; do
    state=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "disabled")

    if [[ "$state" == "active" ]]; then
        ok "$svc: $state ($enabled)"
    elif systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1; then
        warn "$svc: $state ($enabled)"
    else
        info "$svc: not installed on this node"
    fi
done

# Agent log excerpt
if systemctl is-active keylime_agent &>/dev/null; then
    echo ""
    info "Keylime Agent Recent Logs:"
    journalctl -u keylime_agent --no-pager -n 10 --output=short-iso 2>/dev/null | sed 's/^/    /' || \
        warn "Could not retrieve agent logs"
fi

# ── Section 3: TPM Hardware Status ──────────────────────────────────────────
section "3. TPM Hardware Status"

if ls /dev/tpm0 &>/dev/null || ls /dev/tpmrm0 &>/dev/null; then
    ok "TPM device present"
    ls -la /dev/tpm* /dev/tpmrm* 2>/dev/null | sed 's/^/    /'
else
    fail "No TPM device found (/dev/tpm0 or /dev/tpmrm0)"
    info "Check BIOS/UEFI TPM settings"
fi

# tpm2-abrmd resource manager
if systemctl is-active tpm2-abrmd &>/dev/null; then
    ok "tpm2-abrmd resource manager: active"
else
    info "tpm2-abrmd not active (may use /dev/tpmrm0 directly)"
fi

# PCR values
if command -v tpm2_pcrread &>/dev/null; then
    echo ""
    info "TPM PCR Values (SHA-256, PCRs 0-7):"
    tpm2_pcrread sha256:0,1,2,3,4,5,6,7 2>/dev/null | sed 's/^/    /' || \
        warn "Could not read PCR values"
fi

# Event log
if [[ -r /sys/kernel/security/tpm0/binary_bios_measurements ]]; then
    ok "TPM event log (BIOS measurements) readable"
else
    warn "TPM event log not accessible (may require root)"
fi

# ── Section 4: Agent Configuration ──────────────────────────────────────────
section "4. Keylime Agent Configuration"

CONFIG_LOCATIONS=(
    "/etc/keylime/agent.conf"
    "/etc/keylime.conf"
)

config_found=false
for cfg in "${CONFIG_LOCATIONS[@]}"; do
    if [[ -f "$cfg" ]]; then
        ok "Config found: $cfg"
        info "registrar_ip: $(grep -E '^\s*registrar_ip' "$cfg" 2>/dev/null | head -1 | awk -F= '{print $2}' | tr -d ' ' || echo 'not set')"
        info "agent uuid:   $(grep -E '^\s*agent_uuid' "$cfg" 2>/dev/null | head -1 | awk -F= '{print $2}' | tr -d ' ' || echo 'auto-generated')"
        config_found=true
        break
    fi
done

if [[ "$config_found" == "false" ]]; then
    info "No Keylime configuration file found"
fi

# ── Section 5: Agent UUID ───────────────────────────────────────────────────
section "5. Agent UUID"

KEYLIME_UUID_FILE="/var/lib/keylime/uuid"
if [[ -f "$KEYLIME_UUID_FILE" ]]; then
    ok "Agent UUID: $(cat "$KEYLIME_UUID_FILE")"
else
    info "Agent UUID file not found (agent may not have registered)"
fi

# ── Section 6: IMA Runtime Integrity ────────────────────────────────────────
section "6. IMA Runtime Integrity Status"

if [[ -r /sys/kernel/security/ima/active ]]; then
    ima_active=$(cat /sys/kernel/security/ima/active)
    if [[ "$ima_active" == "1" ]]; then
        ok "IMA is active"
    else
        warn "IMA is not active"
    fi

    if [[ -r /sys/kernel/security/ima/ascii_runtime_measurements ]]; then
        meas_count=$(wc -l < /sys/kernel/security/ima/ascii_runtime_measurements)
        info "Total IMA measurements recorded: $meas_count"
    fi

    if [[ -r /sys/kernel/security/ima/policy ]]; then
        info "IMA policy rules active: $(wc -l < /sys/kernel/security/ima/policy)"
    fi
else
    warn "IMA securityfs not accessible (run as root for full output)"
fi

echo ""
echo "$SEP"
echo "  Keylime Status Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
