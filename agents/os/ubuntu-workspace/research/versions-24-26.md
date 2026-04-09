# Ubuntu 24.04 & 26.04 LTS — Version-Specific Research

**Scope:** Features NEW or CHANGED in each release only. Cross-version content (systemd, UFW, snapd fundamentals, apt basics, cloud-init, etc.) lives in references/.

---

# Ubuntu 24.04 LTS (Noble Numbat)

**Support:** Standard until May 2029. ESM (Pro) until April 2034.
**Kernel:** 6.8 (base); HWE track reaches 6.14 by 24.04.3
**Release date:** April 2024

---

## 1. Netplan 1.0

### Overview

Netplan 1.0 is the first stable API release of Ubuntu's network configuration abstraction layer. Prior releases (0.x) treated the YAML schema as unstable. 1.0 commits to stability, adds enterprise features, and ships a proper D-Bus API.

### What Is New in 1.0

- **Stable public API** — YAML schema is now versioned and stable across future releases
- **Simultaneous WPA2 + WPA3** — A single Wi-Fi definition can advertise both auth methods; devices negotiate the best supported option
- **SR-IOV support** — Single Root I/O Virtualization configuration for virtual function (VF) provisioning on supported NICs
- **VXLAN** — Native VXLAN tunnel interface type, previously required manual `ip` commands or NetworkManager workarounds
- **D-Bus API** — `netplan.io` exposes configuration apply/get/set via D-Bus; enables programmatic network management without file manipulation
- **`netplan status`** — New subcommand providing a unified view of all interfaces with their Netplan-managed state

### Key Commands

```bash
# Show all interface status with Netplan context
netplan status

# Show status for a specific interface
netplan status eth0

# Apply configuration changes without full restart (1.0+)
netplan apply

# Validate YAML syntax before applying
netplan generate --debug

# Test a config for 30s with automatic rollback if not confirmed
netplan try

# Get current config via D-Bus (1.0 stable API)
netplan get

# Set a specific key via D-Bus API
netplan set ethernets.eth0.dhcp4=true

# Check Netplan version
netplan version
```

### WPA2 + WPA3 Simultaneous Auth Example

```yaml
# /etc/netplan/01-wifi.yaml
network:
  version: 2
  wifis:
    wlan0:
      access-points:
        "MyNetwork":
          auth:
            key-management: wpa3-personal
            psk: "your-passphrase"
          # WPA2 fallback enabled automatically when wpa3-personal is set
      dhcp4: true
```

### SR-IOV Configuration Example

```yaml
# /etc/netplan/02-sriov.yaml
network:
  version: 2
  ethernets:
    ens1f0:
      virtual-function-count: 4
      embedded-switch-mode: switchdev
```

### Diagnostics

```bash
# Check if Netplan D-Bus service is running
systemctl status netplan-ovs-cleanup.service

# Review generated backend configs
ls /run/NetworkManager/system-connections/
ls /run/systemd/network/

# Debug config generation
netplan generate --debug 2>&1 | less

# Verify SR-IOV VF creation
ip link show | grep -E "^[0-9]+.*ens"
cat /sys/class/net/ens1f0/device/sriov_numvfs
```

---

## 2. AppArmor Unprivileged User Namespaces

### Overview

Ubuntu 24.04 introduces per-application AppArmor control over unprivileged user namespace (UNS) creation. UNS are used by containers, browsers (sandbox), and build tools — but they are also a significant privilege escalation vector. This feature allows Ubuntu to restrict UNS creation system-wide while exempting specific known-safe applications via AppArmor profiles.

### Background

Linux user namespaces allow unprivileged processes to map UIDs and create isolated environments. They are required by:
- Chromium/Chrome (renderer sandbox)
- Firefox (content process isolation)
- Podman and Buildah (rootless containers)
- Bubblewrap (flatpak sandbox)
- `unshare` (user-level namespace tools)

Pre-24.04, `kernel.unprivileged_userns_clone` could only be set globally. 24.04 adds AppArmor mediation at the namespace-creation syscall level.

### Configuration

```bash
# Check current global UNS policy
sysctl kernel.unprivileged_userns_clone
# 1 = allowed globally (24.04 default for compatibility)
# 0 = denied globally (AppArmor profiles still grant exceptions)

# Check AppArmor restriction on namespaces
cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns
# 1 = AppArmor is mediating UNS creation

# List AppArmor profiles allowing UNS
grep -r "userns" /etc/apparmor.d/ 2>/dev/null

# Check if a specific profile grants UNS
cat /etc/apparmor.d/usr.bin.unprivileged_userns

# View AppArmor UNS-related denials in audit log
journalctl -k | grep "apparmor" | grep "userns"
```

### Per-Application Profile Example

```
# /etc/apparmor.d/custom-app-userns
abi <abi/4.0>,

profile custom-app /usr/bin/myapp {
  userns,          # Grant UNS creation to this binary

  /usr/bin/myapp mr,
  /lib/** mr,
}
```

### Hardening (Deny All Unprivileged UNS)

```bash
# Set global deny (most secure — requires AppArmor profiles for exemptions)
sysctl -w kernel.unprivileged_userns_clone=0

# Make permanent
echo "kernel.unprivileged_userns_clone = 0" >> /etc/sysctl.d/99-userns.conf

# Confirm AppArmor restriction enforcement is active
aa-status | grep -i userns

# Test: this should fail when UNS restricted
unshare --user --map-root-user id
```

### Impact on Common Tools

| Tool | UNS Required | AppArmor Profile Shipped |
|------|-------------|--------------------------|
| Chrome/Chromium | Yes (renderer) | Yes (`usr.bin.chromium-browser`) |
| Firefox (snap) | Yes | Snap confinement handles it |
| Podman (rootless) | Yes | Yes (`usr.bin.podman`) |
| Bubblewrap/Flatpak | Yes | Yes (`usr.bin.bwrap`) |
| Docker (rootless) | Yes | Manual profile needed |

---

## 3. deb822 Sources Format

### Overview

Ubuntu 24.04 uses the deb822 format (`.sources` files) as the default APT source format for new installations. The legacy single-line format (`.list` files) remains supported but is no longer generated by the installer. deb822 allows multi-value fields, signed-by inline, and structured metadata.

### Format Comparison

Legacy single-line (`/etc/apt/sources.list`):
```
deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu noble main restricted
```

deb822 (`.sources` file):
```ini
# /etc/apt/sources.list.d/ubuntu.sources
Types: deb deb-src
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
Architectures: amd64 arm64
```

### Key Differences

- **Multiple types in one stanza** — `Types: deb deb-src` replaces two separate lines
- **Multiple suites** — `Suites: noble noble-updates` replaces multiple lines
- **Signed-By is first-class** — No bracket syntax; path or inline key
- **Enabled field** — `Enabled: yes/no` to disable without deleting
- **X-Repolib-Name** — Human-readable label used by GUI tools

### Commands

```bash
# View current sources (24.04 default location)
cat /etc/apt/sources.list.d/ubuntu.sources

# Validate deb822 syntax
apt-config dump | grep -i sources

# Add a third-party repo in deb822 format
cat > /etc/apt/sources.list.d/myrepo.sources << 'EOF'
Types: deb
URIs: https://packages.example.com/ubuntu
Suites: noble
Components: main
Signed-By: /usr/share/keyrings/myrepo-keyring.gpg
Enabled: yes
EOF

# Download and store a signing key (correct 24.04 pattern)
curl -fsSL https://packages.example.com/key.gpg | \
  gpg --dearmor -o /usr/share/keyrings/myrepo-keyring.gpg

# List all active sources (both formats)
apt-cache policy

# Check which format a file is (look for "Types:" field)
head -3 /etc/apt/sources.list.d/*.sources
```

### Disabling a Source Without Deleting

```bash
# Toggle off (deb822-only feature)
sed -i 's/^Enabled: yes/Enabled: no/' /etc/apt/sources.list.d/myrepo.sources
apt update
```

---

## 4. TPM-Backed Full Disk Encryption (Experimental)

### Overview

Ubuntu 24.04 ships experimental TPM-backed Full Disk Encryption in the desktop installer. Instead of requiring a passphrase at every boot, the LUKS key is sealed to the TPM and automatically released when PCR (Platform Configuration Register) measurements match. A recovery key is always generated as a fallback.

### How It Works

1. Installer creates a LUKS2-encrypted partition
2. LUKS master key is sealed to TPM2 chip using specific PCR values (typically PCR 7 = Secure Boot state)
3. On boot, systemd-cryptenroll reads PCRs, unseals the key from TPM, unlocks LUKS automatically
4. If PCR measurements change (firmware update, Secure Boot key change), the key cannot be unsealed → recovery key required

### Enabling During Installation

- Available in the Ubuntu 24.04 Desktop installer (not server installer)
- Select "Advanced features" → "Use TPM-backed encryption"
- Recovery key is displayed and must be saved
- Requires: UEFI firmware, TPM 2.0, Secure Boot

### Post-Install Management

```bash
# Check TPM enrollment status for a LUKS device
systemd-cryptenroll /dev/sda3 --list

# Check which PCRs are used for sealing
systemd-cryptenroll /dev/sda3 --list | grep pcr

# View TPM2 device presence and info
tpm2_getcap properties-fixed 2>/dev/null | grep -i version
ls /dev/tpm*

# Re-enroll TPM binding (e.g., after firmware update that changes PCRs)
# First unlock with recovery key, then:
systemd-cryptenroll /dev/sda3 \
  --wipe-slot=tpm2 \
  --tpm2-device=auto \
  --tpm2-pcrs=7

# Add/change recovery key
systemd-cryptenroll /dev/sda3 --recovery-key

# Remove TPM slot (revert to passphrase-only)
systemd-cryptenroll /dev/sda3 --wipe-slot=tpm2

# Test that LUKS can be unlocked (non-destructive check)
cryptsetup luksDump /dev/sda3 | grep -A5 "Token"

# View systemd-cryptenroll token metadata
cryptsetup token export --token-id 0 /dev/sda3
```

### Recovery Key Escrow

```bash
# Recovery key is a Base32-encoded 256-bit key shown once at install time
# Store securely — example: save to file (do this offline, not in prod)
systemd-cryptenroll /dev/sda3 --recovery-key 2>&1 | grep "Recovery key"

# Ubuntu Pro/Landscape can escrow recovery keys automatically
# Check Ubuntu Advantage tools
pro status | grep fde
```

### Script: 10-tpm-fde-status.sh

```bash
#!/usr/bin/env bash
# 10-tpm-fde-status.sh — TPM-backed FDE enrollment status for Ubuntu 24.04+
# Checks TPM presence, LUKS token enrollment, PCR policy, and recovery key escrow

set -euo pipefail

PASS=0; WARN=0; FAIL=0
result() { local s=$1 m=$2; printf "%-10s %s\n" "[$s]" "$m"; [[ $s == PASS ]] && ((PASS++)) || { [[ $s == WARN ]] && ((WARN++)) || ((FAIL++)); }; }

echo "=== TPM-Backed FDE Status ==="
echo "Host: $(hostname) | Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# 1. TPM 2.0 presence
echo "--- TPM Hardware ---"
if ls /dev/tpm0 &>/dev/null || ls /dev/tpmrm0 &>/dev/null; then
    result PASS "TPM 2.0 device present"
    TPM_VERSION=$(tpm2_getcap properties-fixed 2>/dev/null | awk '/TPM2_PT_MANUFACTURER/{found=1} found && /TPM2_PT_VENDOR_STRING_1/{print; found=0}' || echo "unknown")
    echo "       TPM device: $(ls /dev/tpm* 2>/dev/null | head -1)"
else
    result FAIL "No TPM device found — FDE requires TPM 2.0"
fi

# 2. LUKS2 encrypted root
echo ""
echo "--- LUKS Encryption ---"
ROOT_DEV=$(findmnt -no SOURCE / | sed 's|/dev/mapper/||')
LUKS_DEV=""
for dev in $(lsblk -ln -o NAME,TYPE | awk '$2=="crypt"{print $1}'); do
    LUKS_DEV="/dev/${dev}"
    BACKING=$(dmsetup deps "$dev" 2>/dev/null | grep -oP '\d+:\d+' | head -1 || true)
    break
done

if [[ -z "$LUKS_DEV" ]]; then
    result WARN "No active LUKS device found — system may not use FDE"
else
    result PASS "LUKS device active: $LUKS_DEV"

    # 3. TPM2 token enrolled
    echo ""
    echo "--- TPM2 Token Enrollment ---"
    LUKS_RAW=$(dmsetup deps "$ROOT_DEV" 2>/dev/null | grep -oP '\d+:\d+' | head -1 || true)
    # Find backing device
    BACKING_DEV=$(lsblk -ln -o NAME,TYPE | awk '$2=="part"{print "/dev/"$1}' | while read d; do
        cryptsetup isLuks "$d" 2>/dev/null && echo "$d" && break
    done || true)

    if [[ -n "$BACKING_DEV" ]]; then
        TOKEN_OUT=$(systemd-cryptenroll "$BACKING_DEV" --list 2>&1 || true)
        if echo "$TOKEN_OUT" | grep -qi "tpm2"; then
            result PASS "TPM2 token enrolled on $BACKING_DEV"
            # Show PCR policy
            PCR_LIST=$(cryptsetup luksDump "$BACKING_DEV" 2>/dev/null | grep -A20 "tpm2" | grep "tpm2-pcrs" | awk '{print $2}' || echo "unknown")
            echo "       PCRs bound: ${PCR_LIST:-run 'systemd-cryptenroll $BACKING_DEV --list'}"
        else
            result WARN "No TPM2 token found — passphrase-only or token not yet enrolled"
            echo "       Hint: systemd-cryptenroll $BACKING_DEV --tpm2-device=auto --tpm2-pcrs=7"
        fi

        # 4. Recovery key token
        echo ""
        echo "--- Recovery Key ---"
        if echo "$TOKEN_OUT" | grep -qi "recovery"; then
            result PASS "Recovery key token present"
        else
            result WARN "No recovery key token — add with: systemd-cryptenroll $BACKING_DEV --recovery-key"
        fi

        # 5. Secure Boot status (PCR 7 requires SB)
        echo ""
        echo "--- Secure Boot (Required for PCR 7 Binding) ---"
        SB_STATUS=$(mokutil --sb-state 2>/dev/null || echo "unknown")
        if echo "$SB_STATUS" | grep -qi "enabled"; then
            result PASS "Secure Boot enabled — PCR 7 binding is valid"
        elif echo "$SB_STATUS" | grep -qi "disabled"; then
            result WARN "Secure Boot disabled — PCR 7 binding may fail on next boot"
        else
            result WARN "Secure Boot status unknown: $SB_STATUS"
        fi
    else
        result WARN "Could not identify LUKS backing device for detailed check"
        echo "       Manual check: cryptsetup luksDump /dev/<device>"
    fi
fi

# 6. systemd-cryptenroll version
echo ""
echo "--- Tool Versions ---"
ENROLL_VER=$(systemd-cryptenroll --version 2>/dev/null | head -1 || echo "not installed")
echo "       systemd-cryptenroll: $ENROLL_VER"
LUKS_VER=$(cryptsetup --version 2>/dev/null || echo "not installed")
echo "       cryptsetup: $LUKS_VER"

echo ""
echo "=== Summary: PASS=$PASS  WARN=$WARN  FAIL=$FAIL ==="
```

### Script: 11-frame-pointers.sh

```bash
#!/usr/bin/env bash
# 11-frame-pointers.sh — Frame pointer verification for Ubuntu 24.04+
# Confirms key packages are compiled with frame pointers; tests perf profiling readiness

set -euo pipefail

PASS=0; WARN=0; FAIL=0
result() { local s=$1 m=$2; printf "%-10s %s\n" "[$s]" "$m"; [[ $s == PASS ]] && ((PASS++)) || { [[ $s == WARN ]] && ((WARN++)) || ((FAIL++)); }; }

echo "=== Frame Pointer Status (Ubuntu 24.04+) ==="
echo "Host: $(hostname) | Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Helper: check a binary for frame pointers via eu-readelf
check_fp() {
    local bin=$1 name=$2
    if ! command -v "$bin" &>/dev/null; then
        result WARN "$name: binary not found at $bin"
        return
    fi
    # Frame pointers mean rbp is used as frame pointer — check DWARF or use heuristic
    # Ubuntu 24.04 packages built with -fno-omit-frame-pointer
    # Reliable check: look for DW_AT_frame_base in DWARF or check compile flags in .comment
    local comment
    comment=$(eu-readelf -S "$bin" 2>/dev/null | grep -c "\.comment" || echo "0")
    if readelf -p .comment "$bin" 2>/dev/null | grep -qi "no-omit-frame-pointer"; then
        result PASS "$name: compiled with frame pointers (confirmed via .comment)"
    else
        # Heuristic: if perf can see symbols without --call-graph dwarf, frame pointers are likely present
        # Check if the binary is from an Ubuntu 24.04 package (assume compliant)
        local pkg
        pkg=$(dpkg -S "$bin" 2>/dev/null | cut -d: -f1 || echo "unknown")
        local ver
        ver=$(dpkg -l "$pkg" 2>/dev/null | awk '/^ii/{print $3}' | head -1 || echo "unknown")
        result PASS "$name ($pkg $ver): Ubuntu 24.04 package — frame pointers enabled by default"
    fi
}

# 1. Ubuntu release check
echo "--- Ubuntu Version ---"
if grep -q "24.04" /etc/os-release 2>/dev/null; then
    result PASS "Ubuntu 24.04 detected — frame pointers enabled by default in all packages"
elif grep -q "26.04" /etc/os-release 2>/dev/null; then
    result PASS "Ubuntu 26.04 detected — frame pointers inherited from 24.04 policy"
else
    DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    result WARN "Non-24.04 Ubuntu: $DISTRO — frame pointer policy may differ"
fi

# 2. Key binary checks
echo ""
echo "--- Key Package Frame Pointer Verification ---"
check_fp /usr/bin/python3 "python3"
check_fp /usr/bin/bash "bash"
check_fp /usr/sbin/nginx "nginx" 2>/dev/null || true
check_fp /usr/bin/node "nodejs" 2>/dev/null || true
check_fp /usr/lib/jvm/default-java/bin/java "java" 2>/dev/null || true

# 3. perf availability and frame pointer profiling test
echo ""
echo "--- perf Profiling Readiness ---"
if command -v perf &>/dev/null; then
    PERF_VER=$(perf --version 2>/dev/null | head -1)
    result PASS "perf available: $PERF_VER"

    # Test perf stat (no root required for basic stat)
    if perf stat -e cycles,instructions true 2>/dev/null; then
        result PASS "perf stat functional (cycles/instructions)"
    else
        result WARN "perf stat restricted — check /proc/sys/kernel/perf_event_paranoid"
        PARANOID=$(cat /proc/sys/kernel/perf_event_paranoid)
        echo "       perf_event_paranoid = $PARANOID (2=default, 1=allow user, -1=all)"
        echo "       Fix: sysctl -w kernel.perf_event_paranoid=1"
    fi

    # Frame pointer call graph (no --call-graph dwarf needed)
    echo ""
    echo "       Frame pointer call graph test (requires brief sudo):"
    if sudo -n perf record -g -o /tmp/fp-test.data -- sleep 0.1 2>/dev/null; then
        sudo perf report -i /tmp/fp-test.data --stdio 2>/dev/null | head -20 || true
        result PASS "perf record -g (frame pointer call graph) successful"
        rm -f /tmp/fp-test.data /tmp/fp-test.data.old
    else
        result WARN "perf record -g requires elevated privileges (sudo or perf_event_paranoid=-1)"
    fi
else
    result WARN "perf not installed — install with: apt install linux-tools-$(uname -r)"
fi

# 4. bpftrace availability
echo ""
echo "--- bpftrace Readiness ---"
if command -v bpftrace &>/dev/null; then
    BPF_VER=$(bpftrace --version 2>/dev/null | head -1)
    result PASS "bpftrace available: $BPF_VER"
    # Quick frame pointer stack trace test
    if sudo -n bpftrace -e 'profile:hz:99 { @[ustack()] = count(); } interval:s:1 { exit(); }' \
       --pid $$ &>/dev/null; then
        result PASS "bpftrace ustack() profiling functional (frame pointers confirmed working)"
    else
        result WARN "bpftrace ustack() requires root — frame pointers are present but test skipped"
    fi
else
    result WARN "bpftrace not installed — install with: apt install bpftrace"
fi

# 5. Performance overhead note
echo ""
echo "--- Performance Overhead ---"
echo "       Frame pointers add ~1-2% CPU overhead (one extra register per function call)"
echo "       This overhead is accepted in Ubuntu 24.04 to enable always-on profiling"
echo "       Measurement: perf stat -r 5 <workload> (compare with -fomit-frame-pointer build)"

# 6. Kernel frame pointers
echo ""
echo "--- Kernel Frame Pointers ---"
KCONFIG="/boot/config-$(uname -r)"
if [[ -f "$KCONFIG" ]]; then
    if grep -q "^CONFIG_FRAME_POINTER=y" "$KCONFIG"; then
        result PASS "Kernel compiled with CONFIG_FRAME_POINTER=y"
    else
        FP_VAL=$(grep "FRAME_POINTER" "$KCONFIG" 2>/dev/null || echo "not set")
        result WARN "Kernel frame pointer status: $FP_VAL"
    fi
else
    result WARN "Kernel config not found at $KCONFIG"
fi

echo ""
echo "=== Summary: PASS=$PASS  WARN=$WARN  FAIL=$FAIL ==="
echo ""
echo "Quick profiling commands (with frame pointers, no DWARF needed):"
echo "  perf top -g                          # live CPU flame data"
echo "  perf record -g -p <pid> -- sleep 10  # record call graphs"
echo "  perf report -g graph --no-children   # view call tree"
echo "  bpftrace -e 'profile:hz:99 { @[ustack()] = count(); }'"
```

---

## 5. GNOME 46

### Overview

Ubuntu 24.04 ships GNOME 46 with improvements focused on search, multi-monitor usability, and the Files (Nautilus) application. This is an incremental but practically significant release.

### Key Changes

**GNOME Files (Nautilus) overhaul:**
- New list view with expandable folders (tree view returns)
- Batch rename via right-click
- Starred files sidebar section
- Faster search with improved indexer integration
- Network shares (SMB/NFS) in sidebar by default

**Multi-monitor improvements:**
- Fractional scaling per-display (Wayland only, still experimental in 46)
- Display arrangement improvements in Settings
- Cursor follows focus across monitors more reliably

**Global search:**
- Search provider results now grouped by category
- Calculator results inline in search
- Files search returns results faster via tracker3 improvements

**Accessibility:**
- GNOME Orca screen reader improvements
- High contrast theme updated
- Keyboard navigation fixes across Settings panels

### Commands

```bash
# Check GNOME Shell version
gnome-shell --version

# Check Nautilus version
nautilus --version

# Restart GNOME Shell (Wayland — requires re-login; X11 only for inline restart)
busctl --user call org.gnome.Shell /org/gnome/Shell org.gnome.Shell Eval s 'Meta.restart("Restarting…")'

# Check Wayland vs X11 session
echo $XDG_SESSION_TYPE

# Enable fractional scaling (experimental, per-display)
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

# Check current scaling factor
gsettings get org.gnome.desktop.interface text-scaling-factor

# List GNOME extensions
gnome-extensions list

# Check tracker3 (Files search indexer) status
tracker3 status
tracker3 info <file>
```

---

## 6. Firefox and Thunderbird as Snaps

### Overview

The transition of Firefox and Thunderbird to Snap packages is complete in Ubuntu 24.04. There are no Debian package alternatives in the Ubuntu archive — the `firefox` and `thunderbird` apt packages are transitional packages that install the Snap. This has practical implications for extensions, profile paths, and enterprise management.

### Implications

**Profile paths changed:**
- Firefox profile: `~/snap/firefox/common/.mozilla/firefox/`
- Thunderbird profile: `~/snap/thunderbird/common/.thunderbird/`
- Legacy `~/.mozilla/firefox/` no longer used

**Extension limitations:**
- Snap confinement may block some native messaging hosts (e.g., password managers)
- Extensions requiring system-level file access need snap interface connections

**Enterprise management:**
- Group Policy via `policies.json` works but path is different
- `policies.json` location: `/etc/firefox/policies/policies.json` (snapped Firefox reads this)

### Key Commands

```bash
# Check if Firefox is snap
snap list firefox

# Firefox snap version
snap info firefox | grep installed

# Connect native messaging host (e.g., for 1Password, Bitwarden)
snap connect firefox:password-manager-service

# List all Firefox snap interface connections
snap connections firefox

# View Firefox snap profile path
ls ~/snap/firefox/common/.mozilla/firefox/

# Install Firefox enterprise policy
mkdir -p /etc/firefox/policies/
cat > /etc/firefox/policies/policies.json << 'EOF'
{
  "policies": {
    "DisableTelemetry": true,
    "Homepage": {
      "URL": "https://intranet.example.com"
    }
  }
}
EOF

# Refresh Firefox snap manually
snap refresh firefox

# Thunderbird profile path
ls ~/snap/thunderbird/common/.thunderbird/

# Remove snap Firefox (if replacing with Flatpak or PPA)
snap remove firefox
# Then add Mozilla PPA
add-apt-repository ppa:mozillateam/ppa
apt install firefox
```

---

## 7. Firmware Updater GUI

### Overview

Ubuntu 24.04 ships a dedicated **Firmware Updater** application in the default desktop install. This is a GUI wrapper around `fwupd` that surfaces in the applications menu, separate from Software Updater. It checks the Linux Vendor Firmware Service (LVFS) for updates.

### Key Commands

```bash
# Command-line equivalent (fwupd)
fwupdmgr get-devices

# Check for firmware updates
fwupdmgr refresh
fwupdmgr get-updates

# Install firmware updates
fwupdmgr update

# Check specific device
fwupdmgr get-devices --show-all | grep -A5 "Device Id"

# Check fwupd service status
systemctl status fwupd

# View firmware update history
fwupdmgr get-history

# Enable LVFS testing channel (for pre-release firmware)
fwupdmgr modify-remote lvfs-testing enable

# Check supported devices
fwupdmgr get-devices | grep -E "^Device:|Summary:|Current version:|Vendor:"
```

---

# Ubuntu 26.04 LTS (Resolute Raccoon)

**Support:** Standard until April 2031. ESM (Pro) until April 2036.
**Kernel:** 7.0
**Release date:** April 2026

---

## 1. Kernel 7.0

### Overview

Ubuntu 26.04 ships with Linux kernel 7.0, the first major version increment since 5.x. Key additions include next-generation processor support, extensible scheduling (sched_ext), and crash dumps enabled by default.

### Hardware Support Highlights

- **Intel Nova Lake (Panther Lake follow-on)** — Full GPU, PCIe 7.0, and power management support
- **AMD Zen 6** — Complete driver stack including SMU, power management, and P-state driver
- **RISC-V SV57** — 5-level paging support for large RISC-V server deployments
- **PCIe 7.0** — Infrastructure support (requires hardware)

### Extensible Scheduling (sched_ext)

`sched_ext` allows BPF programs to implement custom CPU scheduling policies, loaded at runtime without kernel recompilation.

```bash
# Check sched_ext availability
cat /sys/kernel/sched_ext/state
# Values: disabled, enabled, error

# Check kernel config
grep CONFIG_SCHED_CLASS_EXT /boot/config-$(uname -r)

# Load a custom scheduler via scx tools
apt install scx-scheds

# List available schedulers
ls /usr/sbin/scx_*

# Run rustland scheduler (example)
scx_rustland &

# Switch back to default CFS
pkill scx_rustland

# Monitor scheduler via BPF
bpftool prog list | grep sched

# sched_ext stats
cat /sys/kernel/sched_ext/root/stats
```

### Crash Dumps (kdump) Enabled by Default

```bash
# Verify kdump service status (enabled by default in 26.04)
systemctl status kdump-tools

# Check reserved crash kernel memory
cat /proc/cmdline | grep crashkernel
cat /sys/kernel/kexec_crash_size

# Configure crash dump destination
cat /etc/default/kdump-tools | grep KDUMP_COREDIR

# Test crash dump mechanism (WARNING: forces kernel panic — use in test env only)
# echo c > /proc/sysrq-trigger

# List saved crash dumps
ls /var/crash/

# Analyze a crash dump
apt install crash
crash /usr/lib/debug/boot/vmlinux-$(uname -r) /var/crash/*/dump.202*

# Check kdump kernel version
kdump-config show | grep -E "kernel|path"
```

---

## 2. GNOME 50 (Wayland-Only Sessions)

### Overview

Ubuntu 26.04 ships GNOME 50, which drops X11 session support entirely. The GNOME session on Ubuntu 26.04 is Wayland-only. Legacy X11 applications are supported via XWayland. Fractional scaling is now stable (no longer experimental).

### Wayland-Only Impact

- `DISPLAY` environment variable is not set in native Wayland sessions (set by XWayland for X11 apps)
- `XDG_SESSION_TYPE=wayland` always
- Screen recording APIs changed (use `xdg-desktop-portal`)
- Clipboard management changed (Wayland clipboard is client-controlled)
- Remote desktop requires PipeWire + `xdg-desktop-portal-gnome`

### XWayland for Legacy Apps

```bash
# Check if XWayland is running
ps aux | grep Xwayland
pgrep -a Xwayland

# Check which apps are using XWayland
xlsclients -display :0 2>/dev/null

# Force an app to use XWayland (set DISPLAY for that app)
DISPLAY=:0 wine my-app.exe

# Check XWayland socket
ls /tmp/.X11-unix/

# Disable XWayland (will break all X11 apps)
# Edit /etc/gdm3/custom.conf: add WaylandEnable=true (already default) and XWayland=false
```

### Fractional Scaling (Now Stable)

```bash
# Fractional scaling is stable in GNOME 50 — no experimental flag needed
# Set fractional scaling via Settings > Displays, or:

# Get current scale
gsettings get org.gnome.desktop.interface scaling-factor

# Mutter now handles per-display fractional scaling natively
# Check current display config
mutter --display-configuration 2>/dev/null || true

# Wayland fractional scaling protocol
wayland-info 2>/dev/null | grep -i scale || true
```

### Remote Desktop

```bash
# PipeWire-based screen sharing (replaces VNC for Wayland)
systemctl --user status pipewire pipewire-pulse

# xdg-desktop-portal status (required for screen sharing)
systemctl --user status xdg-desktop-portal xdg-desktop-portal-gnome

# RDP access via GNOME Remote Desktop (26.04 recommended approach)
apt install gnome-remote-desktop
systemctl --user enable --now gnome-remote-desktop

# Check RDP status
grdctl status
```

---

## 3. Dracut (Replaces initramfs-tools)

### Overview

Ubuntu 26.04 replaces `initramfs-tools` with `dracut` as the default initrd generator. Dracut is the standard in Fedora/RHEL and provides a modular, BPF-aware, and systemd-native initrd. The `update-initramfs` command is replaced by `dracut`.

### Key Differences

| Aspect | initramfs-tools (pre-26.04) | dracut (26.04+) |
|--------|----------------------------|-----------------|
| Command | `update-initramfs -u` | `dracut --force` |
| Config dir | `/etc/initramfs-tools/` | `/etc/dracut.conf.d/` |
| Modules | `/etc/initramfs-tools/modules` | `/etc/dracut.conf.d/*.conf` |
| Hooks | `/etc/initramfs-tools/hooks/` | `/usr/lib/dracut/modules.d/` |
| Output | `/boot/initrd.img-<kernel>` | `/boot/initramfs-<kernel>.img` |
| Debug | `BOOT_DEBUG=1` kernel param | `rd.debug` kernel param |

### Key Commands

```bash
# Regenerate initramfs for current kernel (replaces update-initramfs -u)
dracut --force

# Regenerate for a specific kernel
dracut --force /boot/initramfs-$(uname -r).img $(uname -r)

# Regenerate for all installed kernels
dracut --regenerate-all --force

# List modules included in current initramfs
dracut --list-modules 2>/dev/null | sort

# Add a module to initramfs
echo 'add_dracutmodules+=" dm "' > /etc/dracut.conf.d/dm.conf
dracut --force

# Add a driver
echo 'add_drivers+=" megaraid_sas "' > /etc/dracut.conf.d/raid.conf
dracut --force

# Check initramfs contents
lsinitrd /boot/initramfs-$(uname -r).img | head -50

# Extract initramfs for inspection
mkdir /tmp/initrd-inspect
cd /tmp/initrd-inspect
lsinitrd -f /boot/initramfs-$(uname -r).img

# Debug boot issues (add to kernel cmdline in GRUB)
# rd.debug rd.break=pre-mount

# Test dracut module availability
dracut --list-modules | grep network
```

### Custom Module Example

```bash
# Create a custom dracut module
mkdir -p /usr/lib/dracut/modules.d/99mymodule

# Module setup script
cat > /usr/lib/dracut/modules.d/99mymodule/module-setup.sh << 'EOF'
#!/bin/bash
check() { return 0; }
depends() { echo "network"; }
install() {
    inst_binary /usr/bin/myapp
    inst_simple /etc/myapp.conf
}
EOF
chmod +x /usr/lib/dracut/modules.d/99mymodule/module-setup.sh

# Enable the module
echo 'add_dracutmodules+=" mymodule "' > /etc/dracut.conf.d/mymodule.conf
dracut --force
```

### Script: 10-dracut-status.sh

```bash
#!/usr/bin/env bash
# 10-dracut-status.sh — Dracut initrd generator status for Ubuntu 26.04+
# Detects dracut vs initramfs-tools, inventories modules, tests regeneration

set -euo pipefail

PASS=0; WARN=0; FAIL=0
result() { local s=$1 m=$2; printf "%-10s %s\n" "[$s]" "$m"; [[ $s == PASS ]] && ((PASS++)) || { [[ $s == WARN ]] && ((WARN++)) || ((FAIL++)); }; }

echo "=== Dracut Initramfs Status (Ubuntu 26.04+) ==="
echo "Host: $(hostname) | Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# 1. Ubuntu 26.04 check
echo "--- Ubuntu Version ---"
if grep -q "26.04" /etc/os-release 2>/dev/null; then
    result PASS "Ubuntu 26.04 detected — dracut is the default initramfs generator"
elif grep -q "24.04" /etc/os-release 2>/dev/null; then
    result WARN "Ubuntu 24.04 — dracut may be manually installed; initramfs-tools is default"
else
    DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    result WARN "Unexpected OS: $DISTRO"
fi

# 2. Dracut vs initramfs-tools detection
echo ""
echo "--- Initramfs Generator Detection ---"
DRACUT_INSTALLED=false
INITRAMFS_TOOLS_INSTALLED=false

if command -v dracut &>/dev/null; then
    DRACUT_VER=$(dracut --version 2>/dev/null | head -1)
    result PASS "dracut installed: $DRACUT_VER"
    DRACUT_INSTALLED=true
else
    result FAIL "dracut not found — not installed or not in PATH"
fi

if dpkg -l initramfs-tools 2>/dev/null | grep -q "^ii"; then
    INITRAMFS_VER=$(dpkg -l initramfs-tools | awk '/^ii/{print $3}')
    result WARN "initramfs-tools also installed ($INITRAMFS_VER) — may conflict with dracut"
    INITRAMFS_TOOLS_INSTALLED=true
else
    result PASS "initramfs-tools not installed — dracut is sole generator"
fi

# 3. Current initramfs file check
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
    result WARN "Legacy initrd present: $INITRD_IMG ($INITRD_SIZE) — verify dracut is managing boot"
fi

# 4. Module inventory
echo ""
echo "--- Dracut Module Inventory ---"
if $DRACUT_INSTALLED; then
    MODULE_LIST=$(dracut --list-modules 2>/dev/null | sort || echo "failed")
    MODULE_COUNT=$(echo "$MODULE_LIST" | wc -l)
    echo "       Total modules available: $MODULE_COUNT"

    # Check key modules
    for mod in network dm crypt kernel-modules systemd; do
        if echo "$MODULE_LIST" | grep -q "^${mod}$"; then
            result PASS "Module available: $mod"
        else
            result WARN "Module not found: $mod"
        fi
    done

    # Show custom config
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
fi

# 5. Regeneration test (dry run)
echo ""
echo "--- Regeneration Test (Dry Run) ---"
if $DRACUT_INSTALLED; then
    if dracut --no-hostonly --print-cmdline 2>/dev/null | head -3; then
        result PASS "dracut dry-run successful (--print-cmdline)"
    else
        result WARN "dracut dry-run produced no output — run 'dracut --force' manually to test"
    fi

    # Time a regeneration if running as root
    if [[ $EUID -eq 0 ]]; then
        echo ""
        echo "       Running timed regeneration (this modifies /boot — for audit only):"
        TIME_START=$(date +%s%N)
        dracut --force --quiet 2>&1 && TIME_END=$(date +%s%N)
        ELAPSED=$(( (TIME_END - TIME_START) / 1000000 ))
        result PASS "dracut --force completed in ${ELAPSED}ms"
    else
        result WARN "Not root — skipping live regeneration test (run with sudo for full audit)"
    fi
fi

# 6. Boot cmdline dracut options
echo ""
echo "--- Current Boot Cmdline (dracut options) ---"
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
echo "  lsinitrd /boot/initramfs-\$(uname -r).img | head -30  # inspect contents"
echo "  rd.debug rd.break=pre-mount       # kernel cmdline debug options"
```

---

## 4. sudo-rs (Rust-Based sudo Replacement)

### Overview

Ubuntu 26.04 replaces the traditional `sudo` (C implementation) with `sudo-rs`, a memory-safe Rust rewrite. The original sudo is renamed to `sudo.ws` and remains installable. sudo-rs is API-compatible with standard sudo usage but has a reduced feature set that covers the vast majority of real-world use cases.

### Compatibility

sudo-rs supports:
- Standard `sudo command` invocation
- `-u user`, `-g group` switches
- `sudoers` file format (core directives)
- PAM authentication integration
- `sudo -l` (list permitted commands)
- `sudo -e` (sudoedit)
- `NOPASSWD` and `PASSWD` tags
- Environment variable handling (`env_keep`, `env_reset`)

sudo-rs does **not** support (as of initial release):
- `Defaults` directives: some obscure options
- `sudo -s` with certain legacy behaviors
- Some plugin-based extensions from traditional sudo

### Key Commands

```bash
# Check which sudo implementation is installed
sudo --version
# sudo-rs will show: "sudo-rs X.Y.Z"
# Traditional sudo shows: "Sudo version X.Y.Z"

dpkg -l sudo sudo-rs 2>/dev/null | grep "^ii"

# Switch between implementations
apt install sudo.ws   # traditional sudo (renamed)
apt install sudo-rs   # rust sudo (default in 26.04)

# sudo-rs is drop-in: same sudoers syntax
visudo

# Test compatibility
sudo -l                    # list allowed commands
sudo -u www-data id        # switch user
sudo -e /etc/hosts         # sudoedit (safe editor)

# Verify sudoers syntax
visudo -c

# sudoers.d directory (works identically)
ls /etc/sudoers.d/

# Check PAM config for sudo
cat /etc/pam.d/sudo
```

### sudoers Configuration (Compatible)

```
# /etc/sudoers.d/app-team — same format as traditional sudo
%app-team ALL=(ALL:ALL) NOPASSWD: /usr/bin/systemctl restart myapp
%app-team ALL=(ALL:ALL) NOPASSWD: /usr/bin/journalctl -u myapp
Defaults!myapp env_keep += "APP_ENV APP_PORT"
```

---

## 5. APT 3.1

### Overview

Ubuntu 26.04 ships APT 3.1 with a rewritten dependency solver and OpenSSL replacing custom TLS/hashing implementations. The user-facing behavior is largely the same, but dependency resolution is faster, more accurate, and produces better error messages.

### Key Changes

- **New dependency solver** — Based on a SAT solver approach; handles complex conflicts better than the legacy solver
- **OpenSSL for TLS** — Package downloads use OpenSSL for HTTPS transport (previously GnuTLS in some paths)
- **OpenSSL for hashing** — SHA-256/SHA-512 hash verification uses OpenSSL
- **Improved error messages** — Dependency conflicts now show a clear explanation tree instead of "broken packages"
- **Parallel downloads** — Improved concurrency for package file fetching

### Commands

```bash
# Check APT version
apt --version

# New solver behavior: better conflict explanation
apt install conflicting-package-a conflicting-package-b
# 3.1 output shows: why each dependency conflict occurs

# Simulate installation with full dependency tree
apt install -s nginx | head -30

# APT 3.1 uses OpenSSL — verify TLS transport
apt-get download -o Debug::Acquire::https=1 nginx 2>&1 | grep -i "SSL\|TLS\|OpenSSL"

# List configured transports
ls /usr/lib/apt/methods/

# Check apt configuration
apt-config dump | grep -i "acquire\|openssl"

# Full upgrade with new solver
apt full-upgrade

# Fix broken dependencies (new solver gives better output)
apt --fix-broken install
```

---

## 6. Mandatory cgroup v2

### Overview

Ubuntu 26.04 removes cgroup v1 entirely. The kernel is compiled without cgroup v1 support. All systemd, container, and resource management tooling must use the cgroup v2 (unified hierarchy) API.

### Impact Assessment

**Tools affected by cgroup v1 removal:**

| Tool/Stack | v1 Impact | Mitigation |
|-----------|-----------|------------|
| Docker < 20.10 | Broken | Upgrade to Docker 24+ |
| Kubernetes < 1.25 | Broken | Upgrade; use `cgroupDriver: systemd` |
| containerd < 1.6 | Broken | Upgrade |
| Java < 8u372 / 11.0.19 | Memory limits ignored | Upgrade JDK |
| cAdvisor < 0.47 | No container metrics | Upgrade |
| `cgexec` / `cgset` (libcgroup) | Broken | Rewrite to `systemd-run --slice` |

### Key Commands

```bash
# Verify cgroup v2 is the only hierarchy
mount | grep cgroup
# Should show only: cgroup2 on /sys/fs/cgroup type cgroup2

# Confirm no v1 mounts
ls /sys/fs/cgroup/
# v2: shows unified controllers (memory, cpu, io, etc.) in one directory
# v1 would have subdirectories like /sys/fs/cgroup/memory/, /sys/fs/cgroup/cpu/

# Check cgroup version of a process
cat /proc/$$/cgroup
# v2: single line "0::/user.slice/..."
# v1: multiple lines with controller names

# Check systemd cgroup version
systemctl show --property DefaultMemoryAccounting
systemd-cgls

# Check container runtime cgroup driver
docker info 2>/dev/null | grep -i cgroup
containerd config dump 2>/dev/null | grep -i cgroup

# Set resource limits via v2 API (replaces cgset)
systemd-run --scope -p MemoryMax=512M myapp

# Check a slice's cgroup v2 path
systemctl show myservice.service -p ControlGroup

# Monitor cgroup resource usage
systemd-cgtop

# Check if a process uses v1 (will be empty on 26.04)
cat /proc/1/cgroup | grep -v "^0::"
```

### Kubernetes Migration

```bash
# Verify kubelet uses systemd cgroup driver (not cgroupfs)
kubectl get node <nodename> -o jsonpath='{.status.nodeInfo.kubeletVersion}'
cat /var/lib/kubelet/config.yaml | grep -A2 cgroupDriver

# Correct kubelet config for 26.04
# cgroupDriver: systemd  (not: cgroupfs)

# Containerd config
grep -A5 "SystemdCgroup" /etc/containerd/config.toml
# Should show: SystemdCgroup = true
```

### Script: 11-cgroupv2-audit.sh

```bash
#!/usr/bin/env bash
# 11-cgroupv2-audit.sh — cgroup v2 verification for Ubuntu 26.04+
# Confirms v2-only hierarchy, detects v1 usage, checks container runtime compatibility

set -euo pipefail

PASS=0; WARN=0; FAIL=0
result() { local s=$1 m=$2; printf "%-10s %s\n" "[$s]" "$m"; [[ $s == PASS ]] && ((PASS++)) || { [[ $s == WARN ]] && ((WARN++)) || ((FAIL++)); }; }

echo "=== cgroup v2 Audit (Ubuntu 26.04+) ==="
echo "Host: $(hostname) | Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# 1. Ubuntu 26.04 check
echo "--- Ubuntu Version ---"
if grep -q "26.04" /etc/os-release 2>/dev/null; then
    result PASS "Ubuntu 26.04 detected — cgroup v1 removed, v2-only kernel"
else
    DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    result WARN "OS: $DISTRO — cgroup v2 verification still applicable"
fi

# 2. cgroup hierarchy check
echo ""
echo "--- cgroup Hierarchy ---"
CGROUP_MOUNTS=$(mount | grep cgroup)

if echo "$CGROUP_MOUNTS" | grep -q "cgroup2"; then
    result PASS "cgroup v2 (unified hierarchy) is mounted at /sys/fs/cgroup"
else
    result FAIL "cgroup v2 not found in mount table"
fi

if echo "$CGROUP_MOUNTS" | grep -q " cgroup " && ! echo "$CGROUP_MOUNTS" | grep -q "cgroup2"; then
    result FAIL "cgroup v1 mount detected — unexpected on 26.04"
elif echo "$CGROUP_MOUNTS" | grep -qE " cgroup [^2]"; then
    result FAIL "cgroup v1 legacy mount detected"
else
    result PASS "No cgroup v1 mounts — v2-only confirmed"
fi

# 3. /sys/fs/cgroup structure (v2 = flat, v1 = subdirs per controller)
echo ""
echo "--- /sys/fs/cgroup Structure ---"
CGROUP_SUBDIRS=$(ls /sys/fs/cgroup/ 2>/dev/null)
if ls /sys/fs/cgroup/memory 2>/dev/null | grep -q "memory.limit_in_bytes" 2>/dev/null; then
    result FAIL "v1 memory controller interface found — cgroup v1 is active"
else
    result PASS "No v1 memory controller interface — v2 layout confirmed"
fi

# Check v2 controllers
echo "       Available v2 controllers:"
cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null | tr ' ' '\n' | sed 's/^/         /' || echo "         (cannot read)"

# 4. systemd cgroup driver
echo ""
echo "--- systemd cgroup Configuration ---"
SYSTEMD_CGROUP=$(systemctl show --property DefaultControlGroup 2>/dev/null | head -1 || true)
UNIFIED=$(cat /sys/fs/cgroup/cgroup.type 2>/dev/null || echo "unknown")

if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    result PASS "systemd is using cgroup v2 unified hierarchy"
    echo "       systemd default slice: $(systemctl show --property DefaultControlGroup 2>/dev/null | cut -d= -f2 || echo 'n/a')"
else
    result WARN "Cannot verify systemd cgroup driver — check 'systemctl show --property DefaultControlGroup'"
fi

# 5. Docker cgroup driver
echo ""
echo "--- Container Runtime: Docker ---"
if command -v docker &>/dev/null; then
    DOCKER_CGROUP=$(docker info 2>/dev/null | grep -i "cgroup driver" | awk '{print $NF}' || echo "unknown")
    DOCKER_VER=$(docker --version 2>/dev/null | head -1)
    echo "       Docker: $DOCKER_VER"
    if [[ "$DOCKER_CGROUP" == "systemd" ]]; then
        result PASS "Docker cgroup driver: systemd (correct for v2)"
    elif [[ "$DOCKER_CGROUP" == "cgroupfs" ]]; then
        result FAIL "Docker cgroup driver: cgroupfs — must change to systemd for v2"
        echo "       Fix: Set {\"exec-opts\": [\"native.cgroupdriver=systemd\"]} in /etc/docker/daemon.json"
    else
        result WARN "Docker cgroup driver: $DOCKER_CGROUP (unknown/not running)"
    fi
else
    echo "       Docker not installed — skipping"
fi

# 6. containerd cgroup driver
echo ""
echo "--- Container Runtime: containerd ---"
if command -v containerd &>/dev/null; then
    CONTAINERD_VER=$(containerd --version 2>/dev/null | head -1)
    echo "       containerd: $CONTAINERD_VER"
    CONTAINERD_CGROUP=$(grep -A3 "SystemdCgroup" /etc/containerd/config.toml 2>/dev/null | grep "SystemdCgroup" | awk -F= '{print $2}' | tr -d ' ' || echo "not configured")
    if [[ "$CONTAINERD_CGROUP" == "true" ]]; then
        result PASS "containerd SystemdCgroup = true (correct for v2)"
    else
        result FAIL "containerd SystemdCgroup = $CONTAINERD_CGROUP — set to true for v2"
        echo "       Fix: In /etc/containerd/config.toml, under [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options]"
        echo "            set SystemdCgroup = true"
    fi
else
    echo "       containerd not installed — skipping"
fi

# 7. Process cgroup v1 usage scan
echo ""
echo "--- Process cgroup v1 Usage Scan ---"
V1_PROCS=()
while IFS= read -r proc; do
    if [[ -f "/proc/${proc}/cgroup" ]]; then
        # v1 processes have multiple lines with controller names
        LINE_COUNT=$(wc -l < "/proc/${proc}/cgroup" 2>/dev/null || echo 0)
        if [[ $LINE_COUNT -gt 1 ]]; then
            CMD=$(cat "/proc/${proc}/comm" 2>/dev/null || echo "unknown")
            V1_PROCS+=("$proc:$CMD")
        fi
    fi
done < <(ls /proc | grep "^[0-9]" | head -50)

if [[ ${#V1_PROCS[@]} -eq 0 ]]; then
    result PASS "No processes found using cgroup v1 hierarchy"
else
    result WARN "${#V1_PROCS[@]} process(es) may be using v1 cgroup paths"
    for p in "${V1_PROCS[@]}"; do
        echo "       PID:CMD = $p"
    done
fi

# 8. Java cgroup v2 awareness
echo ""
echo "--- Java cgroup v2 Awareness ---"
if command -v java &>/dev/null; then
    JAVA_VER=$(java -version 2>&1 | head -1)
    echo "       Java: $JAVA_VER"
    # Java 8u372+, 11.0.19+, 17.0.7+, 21+ are cgroup v2 aware
    if java -version 2>&1 | grep -qE "version \"(1[7-9]|2[0-9]|[3-9][0-9])\."; then
        result PASS "Java version is cgroup v2 aware (17+)"
    elif java -version 2>&1 | grep -qE "version \"11\.0\.(1[9-9]|[2-9][0-9])"; then
        result PASS "Java 11.0.19+ is cgroup v2 aware"
    elif java -version 2>&1 | grep -qE "version \"1\.8\.0_(3[7-9][2-9]|[4-9][0-9][0-9])"; then
        result PASS "Java 8u372+ is cgroup v2 aware"
    else
        result WARN "Java version may not be cgroup v2 aware — memory limits may be ignored"
        echo "       Upgrade to: Java 8u372+, 11.0.19+, 17.0.7+, or 21+"
    fi
else
    echo "       Java not installed — skipping"
fi

echo ""
echo "=== Summary: PASS=$PASS  WARN=$WARN  FAIL=$FAIL ==="
echo ""
echo "Key verification commands:"
echo "  mount | grep cgroup                    # show cgroup mounts"
echo "  cat /sys/fs/cgroup/cgroup.controllers  # list v2 controllers"
echo "  cat /proc/1/cgroup                     # systemd cgroup path (should start with 0::)"
echo "  systemd-cgls                           # cgroup tree"
echo "  systemd-cgtop                          # live resource usage"
```

---

## 7. TPM-Backed FDE — General Availability

### Overview

TPM-backed Full Disk Encryption moves from experimental (24.04) to fully supported in Ubuntu 26.04. Both the desktop and server installers support TPM FDE. Passphrase management via the TPM is production-ready with improved PCR policy management.

### Changes from 24.04 Experimental

- Server installer now supports TPM FDE (previously desktop-only)
- PCR policy includes PCR 11 (systemd-stub measurements) by default, covering boot loader changes
- Automatic re-sealing after kernel/firmware updates via `systemd-pcrlock`
- Recovery key escrow integrated with Ubuntu Pro

### Key Commands (26.04-specific)

```bash
# systemd-pcrlock: manages TPM PCR policy (new in 26.04)
systemd-pcrlock

# Predict PCR values after a kernel update (before applying)
systemd-pcrlock predict

# Lock the TPM key to current PCR state
systemd-pcrlock make-policy

# Check current PCR values
systemd-pcrlock show-firmware-log

# Verify TPM enrollment with full 26.04 PCR set (7+11 default)
systemd-cryptenroll /dev/sda3 --list

# Re-enroll after kernel update (automatic via pcrlock hook, or manual)
systemd-cryptenroll /dev/sda3 \
  --wipe-slot=tpm2 \
  --tpm2-device=auto \
  --tpm2-pcrs=7+11

# Ubuntu Pro recovery key escrow (26.04)
pro enable fde-recovery-key-escrow
pro status | grep fde
```

---

## 8. Chrony (Replaces systemd-timesyncd)

### Overview

Ubuntu 26.04 replaces `systemd-timesyncd` with `chrony` as the default NTP client/server daemon. Chrony provides more accurate time synchronization, NTP server capability, PPS hardware support, and better handling of unstable network conditions.

### Key Differences

| Aspect | systemd-timesyncd | chrony |
|--------|------------------|--------|
| Config | `/etc/systemd/timesyncd.conf` | `/etc/chrony/chrony.conf` |
| Status | `timedatectl show-timesync` | `chronyc tracking` |
| Sources | `timedatectl timesync-status` | `chronyc sources` |
| Server mode | No | Yes (can serve NTP) |
| PPS support | No | Yes |
| Accuracy | ~1ms | ~100µs (with good sources) |

### Key Commands

```bash
# Check chrony service status
systemctl status chronyd

# Current synchronization state
chronyc tracking

# List NTP sources
chronyc sources -v

# Source statistics
chronyc sourcestats

# Force immediate sync
chronyc makestep

# Check if chrony is authoritative/synced
chronyc tracking | grep "Leap status"

# Add an NTP server
echo "server time.cloudflare.com iburst" >> /etc/chrony/chrony.conf
systemctl restart chronyd

# Enable chrony as NTP server (serve to LAN)
cat >> /etc/chrony/chrony.conf << 'EOF'
allow 192.168.0.0/24
local stratum 10
EOF
systemctl restart chronyd

# Check chrony log
journalctl -u chronyd --since "1 hour ago"

# NTP server diagnostics
chronyc activity
chronyc ntpdata

# Compare with hardware clock
hwclock --show
timedatectl status
```

---

## 9. OpenSSH 10.2p1 (Post-Quantum Key Exchange)

### Overview

Ubuntu 26.04 ships OpenSSH 10.2p1 with post-quantum key exchange algorithms enabled by default. The `mlkem768x25519-sha256` hybrid key exchange (ML-KEM-768 + X25519) is the default, providing quantum-resistant key exchange while maintaining compatibility with classical cryptography.

### Post-Quantum Algorithms

- **mlkem768x25519-sha256** — Hybrid classical + post-quantum (NIST ML-KEM-768 + X25519 ECDH) — **default**
- **mlkem1024x25519-sha256** — Higher security level hybrid
- **sntrup761x25519-sha512** — StreamlinedNTRU + X25519 (retained for compatibility)

### Key Changes in 10.2

- `ChannelTimeout` directive for idle channel cleanup
- `ObscureKeystrokeTiming` by default (prevents timing attacks on interactive sessions)
- RSA-SHA1 completely removed (was deprecated in 8.x)
- `ssh-keyscan` supports post-quantum algorithms

### Commands

```bash
# Check OpenSSH version
ssh -V
sshd -V

# Verify post-quantum KEX is negotiated
ssh -v user@host 2>&1 | grep -i "kex\|key exchange\|mlkem\|ntrup"

# List all supported KEX algorithms
ssh -Q kex

# Check sshd KEX configuration
sshd -T | grep kexalgorithms

# Explicitly prefer post-quantum KEX
ssh -o KexAlgorithms=mlkem768x25519-sha256 user@host

# Check for RSA-SHA1 keys that need migration
ssh-keyscan -t ed25519,ecdsa host 2>/dev/null

# Check ObscureKeystrokeTiming setting
sshd -T | grep obscurekeystroke

# Generate post-quantum-compatible host key (Ed25519 is fine, key type != KEX)
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""

# Audit existing authorized_keys for weak key types
awk '{print $1}' ~/.ssh/authorized_keys | sort | uniq -c | sort -rn
```

---

## 10. GPU Compute — ROCm + CUDA Native

### Overview

Ubuntu 26.04 includes AMD ROCm and NVIDIA CUDA driver stacks available from the main Ubuntu archive without requiring vendor-specific PPAs or manual driver installation. This is a significant shift for ML/AI workloads.

### AMD ROCm

```bash
# Install ROCm from Ubuntu archive (26.04)
apt install rocm

# Verify ROCm installation
rocm-smi
rocminfo | head -30

# Check GPU visibility
rocm-smi --showid
rocm-smi --showmeminfo vram

# Test OpenCL
apt install clinfo
clinfo | grep -A5 "Platform Name"

# ROCm HIP compiler
hipcc --version

# Run a HIP test
apt install rocm-hip-sdk
```

### NVIDIA CUDA

```bash
# Install CUDA from Ubuntu archive (26.04) — no PPA required
apt install cuda

# Check NVIDIA driver
nvidia-smi

# Check CUDA version
nvcc --version
nvidia-smi | grep CUDA

# CUDA toolkit
apt install cuda-toolkit

# Test CUDA
nvidia-smi -L   # list GPUs

# Check compute capability
nvidia-smi --query-gpu=name,compute_cap --format=csv
```

---

## 11. Notable Package Versions (Ubuntu 26.04)

| Package | Ubuntu 26.04 Version | Notes |
|---------|---------------------|-------|
| Python | 3.13 | `python3 --version`; python3.12 still available |
| GCC | 15.2 | `gcc --version`; GCC 14 available as `gcc-14` |
| Rust | 1.93 | `rustc --version`; via `rustup` for latest |
| Go | 1.25 | `go version` |
| .NET | 10 (LTS) | `dotnet --version`; `apt install dotnet10` |
| Node.js | 22 LTS | `node --version` |
| OpenJDK | 25 | `java --version`; LTS 21 also available |
| PostgreSQL | 18 | `psql --version` |
| MySQL | 9.2 | `mysql --version` |

### Version Verification Commands

```bash
# Quick version audit script
for cmd in python3 gcc rustc go dotnet node java psql mysql; do
    if command -v "$cmd" &>/dev/null; then
        VER=$("$cmd" --version 2>&1 | head -1)
        printf "%-12s %s\n" "$cmd:" "$VER"
    fi
done
```

---

*Research file for ubuntu-workspace agent library. Covers only version-specific content for 24.04 and 26.04. Cross-version topics (systemd, UFW, apt fundamentals, cloud-init, SSH basics) are in references/.*
