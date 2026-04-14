#!/usr/bin/env bash
# ============================================================================
# Ubuntu 24.04 - TPM-Backed FDE Status
#
# Purpose : Check TPM presence, LUKS token enrollment, PCR policy, recovery
#           key status, and Secure Boot for TPM-backed Full Disk Encryption.
# Version : 24.1.0
# Targets : Ubuntu 24.04 LTS (Noble Numbat)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. TPM Hardware
#   2. LUKS Encryption
#   3. TPM2 Token Enrollment
#   4. Recovery Key
#   5. Secure Boot
#   6. Tool Versions
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

echo "=== TPM-Backed FDE Status (Ubuntu 24.04) ==="
echo "Host: $(hostname) | Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# -- 1. TPM 2.0 presence ---------------------------------------------------
echo "--- TPM Hardware ---"
if ls /dev/tpm0 &>/dev/null || ls /dev/tpmrm0 &>/dev/null; then
    result PASS "TPM 2.0 device present"
    echo "       Device: $(ls /dev/tpm* 2>/dev/null | head -1)"
    tpm2_getcap properties-fixed 2>/dev/null | head -5 | sed 's/^/       /' || true
else
    result FAIL "No TPM device found -- FDE requires TPM 2.0"
fi

# -- 2. LUKS2 encrypted root -----------------------------------------------
echo ""
echo "--- LUKS Encryption ---"
ROOT_DEV=$(findmnt -no SOURCE / | sed 's|/dev/mapper/||')
LUKS_DEV=""
for dev in $(lsblk -ln -o NAME,TYPE | awk '$2=="crypt"{print $1}'); do
    LUKS_DEV="/dev/${dev}"
    break
done

if [[ -z "$LUKS_DEV" ]]; then
    result WARN "No active LUKS device found -- system may not use FDE"
else
    result PASS "LUKS device active: $LUKS_DEV"

    # -- 3. TPM2 token enrolled ---------------------------------------------
    echo ""
    echo "--- TPM2 Token Enrollment ---"
    BACKING_DEV=$(lsblk -ln -o NAME,TYPE | awk '$2=="part"{print "/dev/"$1}' | while read d; do
        cryptsetup isLuks "$d" 2>/dev/null && echo "$d" && break
    done || true)

    if [[ -n "$BACKING_DEV" ]]; then
        TOKEN_OUT=$(systemd-cryptenroll "$BACKING_DEV" --list 2>&1 || true)
        if echo "$TOKEN_OUT" | grep -qi "tpm2"; then
            result PASS "TPM2 token enrolled on $BACKING_DEV"
            PCR_LIST=$(cryptsetup luksDump "$BACKING_DEV" 2>/dev/null | grep -A20 "tpm2" | grep "tpm2-pcrs" | awk '{print $2}' || echo "unknown")
            echo "       PCRs bound: ${PCR_LIST:-run 'systemd-cryptenroll $BACKING_DEV --list'}"
        else
            result WARN "No TPM2 token found -- passphrase-only or not enrolled"
            echo "       Hint: systemd-cryptenroll $BACKING_DEV --tpm2-device=auto --tpm2-pcrs=7"
        fi

        # -- 4. Recovery key ------------------------------------------------
        echo ""
        echo "--- Recovery Key ---"
        if echo "$TOKEN_OUT" | grep -qi "recovery"; then
            result PASS "Recovery key token present"
        else
            result WARN "No recovery key -- add with: systemd-cryptenroll $BACKING_DEV --recovery-key"
        fi

        # -- 5. Secure Boot -------------------------------------------------
        echo ""
        echo "--- Secure Boot (Required for PCR 7 Binding) ---"
        SB_STATUS=$(mokutil --sb-state 2>/dev/null || echo "unknown")
        if echo "$SB_STATUS" | grep -qi "enabled"; then
            result PASS "Secure Boot enabled -- PCR 7 binding is valid"
        elif echo "$SB_STATUS" | grep -qi "disabled"; then
            result WARN "Secure Boot disabled -- PCR 7 binding may fail"
        else
            result WARN "Secure Boot status unknown: $SB_STATUS"
        fi
    else
        result WARN "Could not identify LUKS backing device"
        echo "       Manual check: cryptsetup luksDump /dev/<device>"
    fi
fi

# -- 6. Tool versions ------------------------------------------------------
echo ""
echo "--- Tool Versions ---"
ENROLL_VER=$(systemd-cryptenroll --version 2>/dev/null | head -1 || echo "not installed")
echo "       systemd-cryptenroll: $ENROLL_VER"
LUKS_VER=$(cryptsetup --version 2>/dev/null || echo "not installed")
echo "       cryptsetup: $LUKS_VER"

echo ""
echo "=== Summary: PASS=$PASS  WARN=$WARN  FAIL=$FAIL ==="
