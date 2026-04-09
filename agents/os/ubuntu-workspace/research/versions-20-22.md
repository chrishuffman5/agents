# Ubuntu Version Research: 20.04 LTS & 22.04 LTS

Two-version research file covering features NEW in each release. Each section covers only what was introduced in that version, not inherited baseline behaviors.

---

## Ubuntu 20.04 LTS (Focal Fossa)

**Codename:** Focal Fossa
**Released:** April 23, 2020
**Standard Support:** Ended April 2025
**ESM (Ubuntu Pro):** Until April 2030
**Kernel:** 5.4 LTS (HWE track: 5.15)
**Python Default:** Python 3.8 (Python 2 removed from default install)

---

### 1. ZFS Root Filesystem Support

Ubuntu 20.04 was the first LTS release to offer ZFS as a root filesystem option directly from the installer (ubiquity). Previous LTS releases required manual configuration or third-party tooling.

**Key components introduced:**

- **Ubiquity installer integration** — "Erase disk and use ZFS" option in the guided installer flow. Sets up a ZFS pool named `rpool` with datasets for `/`, `/home`, and other mount points.
- **zsys** — A new Ubuntu-specific ZFS system manager (`com.ubuntu.zsys` D-Bus service). Hooks into APT to take automatic ZFS snapshots before and after package operations. Snapshots are named by timestamp and listed in GRUB for boot-time rollback.
- **GRUB ZFS boot support** — GRUB 2.04 with ZFS support allows booting from ZFS datasets, selecting snapshots at boot time via the GRUB menu.
- **Snapshot management commands:**
  - `zsysctl state list` — list system states (snapshots + datasets)
  - `zsysctl state save` — manually create a state snapshot
  - `zsysctl state remove <state>` — remove a specific state
  - `zsysctl boot commit` — finalize a boot (called automatically by systemd unit)

**Deprecation note:** zsys was deprecated in Ubuntu 22.04 and removed in 24.04. The snapshot-on-APT behavior is not present in later releases. Agents targeting 22.04+ should not reference zsys commands.

**Relevant paths:**
- `/etc/zfs/` — ZFS configuration
- `/etc/zsys.conf` — zsys configuration (20.04 only)
- Pool layout: `rpool/ROOT/ubuntu_<uid>` for root, `rpool/USERDATA/<user>_<uid>` for home directories

**Diagnostic commands:**
```bash
zpool status                    # Pool health
zfs list -t snapshot            # All snapshots
zsysctl state list              # zsys state list (20.04 only)
zpool get all rpool             # Pool properties
```

---

### 2. WireGuard in the Kernel

Ubuntu 20.04 was the first Ubuntu LTS to ship WireGuard built into the kernel (backported into the 5.4 kernel). Previous releases required a DKMS module from the wireguard PPA.

**What changed:**
- `wireguard` kernel module ships with linux-image-5.4 — no DKMS or PPA required
- `wireguard-tools` package provides userspace utilities (`wg`, `wg-quick`)
- `linux-modules-extra-*` no longer required for WireGuard

**Setup workflow (new in 20.04):**

```bash
# Install userspace tools only (kernel module already present)
apt install wireguard-tools

# Generate keypair
wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey

# Create interface config
cat > /etc/wireguard/wg0.conf << 'EOF'
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <server-private-key>

[Peer]
PublicKey = <peer-public-key>
AllowedIPs = 10.0.0.2/32
EOF

# Bring up and enable on boot
wg-quick up wg0
systemctl enable wg-quick@wg0
```

**NetworkManager integration (20.04):**
- `network-manager-wireguard` plugin added, allowing WireGuard connections via `nmcli` and GNOME Settings
- `nmcli connection import type wireguard file /etc/wireguard/wg0.conf`

**Kernel module verification:**
```bash
modinfo wireguard          # Confirm built-in, no DKMS
lsmod | grep wireguard
wg show                    # Active interfaces
```

---

### 3. Snap Matured: snapd as Core Service

Ubuntu 20.04 solidified snap as a first-class packaging mechanism with significant infrastructure changes.

**New in 20.04:**
- **snapd as a system service** — `snapd.service` and `snapd.socket` are active by default, even on server installs
- **`core20` base snap** — Ubuntu Core 20 became the default base for new snaps (replaced `core18`), providing Ubuntu 20.04 userland inside snaps
- **Improved confinement** — AppArmor profile improvements, new `strict` confinement interfaces for DBus, audio, and display
- **Parallel snap installs** — Multiple versions of the same snap can coexist (used for developer testing)
- **Snap Store Proxy** — Enterprise feature for air-gapped environments to host an internal snap mirror

**Key snap commands introduced/stabilized:**
```bash
snap refresh --hold <snap>          # Hold specific snap from updates
snap set system refresh.hold=...    # System-wide hold
snap connections <snap>             # Show interface connections
snap run --shell <snap>             # Debug snap environment
```

**Snap-related paths:**
- `/var/lib/snapd/` — snapd data directory
- `/snap/` — Mounted snap content
- `/etc/systemd/system/snap-*.mount` — Auto-generated mount units

---

### 4. LXD 4.0 LTS

LXD 4.0 LTS was released alongside Ubuntu 20.04 and delivered major new capabilities for container and VM management.

**New in LXD 4.0 (shipped with 20.04):**
- **Clustering** — Production-grade LXD clustering across multiple hosts, with a distributed database (dqlite) replacing SQLite
- **Virtual Machines** — Full VM support via QEMU/KVM alongside containers. `lxc launch --vm` syntax.
- **Storage pools** — ZFS, Btrfs, LVM, and directory-backed storage pools with per-profile defaults
- **RBAC (Role-Based Access Control)** — Integration with Canonical RBAC for multi-tenant access control
- **Projects** — Namespace isolation for containers/images/profiles within a single LXD instance
- **Network acceleration** — SR-IOV and macvlan improvements

**Commands new or stabilized in 4.0:**
```bash
lxd init --preseed < preseed.yaml   # Automated cluster init
lxc cluster list                     # Show cluster members
lxc storage list                     # Storage pools
lxc launch ubuntu:20.04 c1 --vm     # Launch a VM
lxc project create dev              # Create a project
lxc project switch dev              # Switch active project
```

**Migration note:** LXD 4.0 snapshots and cluster state are forward-compatible with LXD 5.0 (22.04), but the migration must be performed explicitly.

---

### 5. Multipass: Lightweight Ubuntu VM Launcher

Multipass was introduced as a first-class tool for quickly spinning up Ubuntu VMs on Linux, macOS, and Windows, with deep integration on Ubuntu 20.04.

**What it provides:**
- One-command Ubuntu VM launch using QEMU (Linux), Hyper-V (Windows), or HyperKit (macOS)
- Cloud-init support for VM initialization
- `mount` command for host-to-guest filesystem sharing
- Blueprint support for pre-configured environments

**Core commands:**
```bash
snap install multipass               # Install via snap
multipass launch 20.04 --name dev   # Launch named VM
multipass shell dev                  # SSH into VM
multipass list                       # List all VMs
multipass info dev                   # VM details (IP, state, resources)
multipass mount /host/path dev:/vm/path  # Share directory
multipass stop dev                   # Stop VM
multipass delete dev && multipass purge  # Remove VM
```

**Cloud-init with Multipass:**
```bash
multipass launch --cloud-init cloud-config.yaml --name myvm
```

---

### 6. cloud-init: Network Config v2 (Netplan Passthrough)

Ubuntu 20.04 upgraded cloud-init's network configuration to support Netplan's full v2 YAML schema natively, replacing the older ENI-style network config.

**What changed in 20.04:**
- `network-config` in cloud-init datasources now supports `version: 2` (Netplan YAML) directly
- cloud-init writes Netplan config to `/etc/netplan/50-cloud-init.yaml` instead of legacy `/etc/network/interfaces`
- Full Netplan features available in cloud-init: bonds, bridges, VLANs, routes, DNS search domains

**Example cloud-init network config v2:**
```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
  vlans:
    vlan10:
      id: 10
      link: eth0
      addresses: [192.168.10.5/24]
```

**Relevant paths:**
- `/etc/netplan/50-cloud-init.yaml` — Written by cloud-init
- `/var/lib/cloud/instance/` — cloud-init instance data
- `cloud-init status --long` — Detailed init status

---

### 7. Migration Focus: ESM-Only Status

As of April 2025, Ubuntu 20.04 has exited standard support. Agents targeting 20.04 environments MUST emphasize the upgrade path.

**Current support posture:**
- Standard updates: ENDED April 2025
- Security patches: Available only via Ubuntu Pro (ESM) until April 2030
- Without Ubuntu Pro, systems receive NO security updates

**Upgrade paths:**
- **Recommended:** Upgrade to 24.04 LTS (via 22.04 intermediate step)
- **Interim:** Upgrade to 22.04 LTS as first hop
- **Minimum:** Enroll in Ubuntu Pro for ESM coverage if upgrade is not yet possible

**Ubuntu Pro enrollment:**
```bash
pro attach <token>          # Attach Ubuntu Pro subscription
pro status                  # Show ESM and service status
pro enable esm-infra        # Enable ESM infrastructure packages
pro enable esm-apps         # Enable ESM application packages
```

---

### Version Script: 10-eol-readiness.sh

```bash
#!/bin/bash
# Ubuntu 20.04 EOL Readiness Assessment
# Version: 20.1.0
# Targets: Ubuntu 20.04 LTS (Focal Fossa)
# Purpose: Assess ESM status, Pro enrollment, upgrade readiness, and migration blockers

set -euo pipefail

SCRIPT_VERSION="20.1.0"
TARGET_VERSION="20.04"
REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}  Ubuntu 20.04 EOL Readiness Assessment v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}  ${REPORT_DATE}${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
}

check_os_version() {
    echo -e "${BLUE}[1/7] OS Version Check${NC}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "  OS: ${PRETTY_NAME}"
        echo "  Version ID: ${VERSION_ID}"
        if [ "${VERSION_ID}" != "20.04" ]; then
            echo -e "  ${YELLOW}WARNING: This script targets Ubuntu 20.04, detected ${VERSION_ID}${NC}"
        else
            echo -e "  ${GREEN}OK: Running on target version 20.04${NC}"
        fi
    else
        echo -e "  ${RED}ERROR: Cannot determine OS version${NC}"
    fi
    echo ""
}

check_ubuntu_pro_status() {
    echo -e "${BLUE}[2/7] Ubuntu Pro / ESM Status${NC}"
    if command -v pro &>/dev/null; then
        PRO_STATUS=$(pro status 2>/dev/null || echo "error")
        if echo "${PRO_STATUS}" | grep -q "attached: yes" 2>/dev/null; then
            echo -e "  ${GREEN}OK: System is attached to Ubuntu Pro${NC}"
            # Check ESM services
            if echo "${PRO_STATUS}" | grep -q "esm-infra.*enabled"; then
                echo -e "  ${GREEN}OK: ESM Infrastructure enabled${NC}"
            else
                echo -e "  ${YELLOW}WARNING: ESM Infrastructure not enabled — run: pro enable esm-infra${NC}"
            fi
            if echo "${PRO_STATUS}" | grep -q "esm-apps.*enabled"; then
                echo -e "  ${GREEN}OK: ESM Apps enabled${NC}"
            else
                echo -e "  ${YELLOW}WARNING: ESM Apps not enabled — run: pro enable esm-apps${NC}"
            fi
        else
            echo -e "  ${RED}CRITICAL: System is NOT attached to Ubuntu Pro${NC}"
            echo -e "  ${RED}  Ubuntu 20.04 standard support ended April 2025${NC}"
            echo -e "  ${RED}  No security updates without ESM enrollment${NC}"
            echo "  Action: Visit https://ubuntu.com/pro to obtain a token"
            echo "  Action: Run: pro attach <token>"
        fi
        # Show token/account info if attached
        pro status --format json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
acct = data.get('account', {})
if acct:
    print(f'  Account: {acct.get(\"name\", \"unknown\")}')
    print(f'  Contract: {acct.get(\"id\", \"unknown\")}')
" 2>/dev/null || true
    else
        echo -e "  ${RED}CRITICAL: ubuntu-advantage-tools (pro) not installed${NC}"
        echo "  Install: apt install ubuntu-advantage-tools"
    fi
    echo ""
}

check_kernel_status() {
    echo -e "${BLUE}[3/7] Kernel Version & HWE Status${NC}"
    CURRENT_KERNEL=$(uname -r)
    echo "  Running kernel: ${CURRENT_KERNEL}"

    # Check if HWE kernel
    if echo "${CURRENT_KERNEL}" | grep -q "generic-hwe"; then
        echo -e "  ${GREEN}OK: Using HWE kernel (Hardware Enablement Stack)${NC}"
        echo "  HWE provides kernel 5.15 on Ubuntu 20.04"
    elif echo "${CURRENT_KERNEL}" | grep -q "^5\.4"; then
        echo -e "  ${YELLOW}INFO: Using GA kernel 5.4${NC}"
        echo "  Consider HWE for newer hardware support: apt install linux-generic-hwe-20.04"
    fi

    # Check for available kernel updates
    AVAILABLE=$(apt-cache policy linux-image-generic 2>/dev/null | grep Candidate | awk '{print $2}')
    INSTALLED=$(apt-cache policy linux-image-generic 2>/dev/null | grep Installed | awk '{print $2}')
    if [ "${AVAILABLE}" != "${INSTALLED}" ] && [ -n "${AVAILABLE}" ]; then
        echo -e "  ${YELLOW}WARNING: Kernel update available: ${AVAILABLE} (installed: ${INSTALLED})${NC}"
    else
        echo -e "  ${GREEN}OK: Kernel packages up to date${NC}"
    fi
    echo ""
}

check_package_holds() {
    echo -e "${BLUE}[4/7] Package Holds (Potential Upgrade Blockers)${NC}"
    HELD=$(apt-mark showhold 2>/dev/null)
    if [ -z "${HELD}" ]; then
        echo -e "  ${GREEN}OK: No packages on hold${NC}"
    else
        echo -e "  ${YELLOW}WARNING: Held packages may block upgrade:${NC}"
        echo "${HELD}" | while read -r pkg; do
            echo "    - ${pkg}"
        done
        echo "  To release: apt-mark unhold <package>"
    fi
    echo ""
}

check_ppa_compatibility() {
    echo -e "${BLUE}[5/7] PPA Compatibility${NC}"
    PPA_LIST=$(find /etc/apt/sources.list.d/ -name "*.list" -o -name "*.sources" 2>/dev/null | head -20)
    if [ -z "${PPA_LIST}" ]; then
        echo -e "  ${GREEN}OK: No additional PPAs found${NC}"
    else
        echo -e "  ${YELLOW}INFO: PPAs found — verify compatibility before upgrading:${NC}"
        echo "${PPA_LIST}" | while read -r ppa_file; do
            echo "    - ${ppa_file}"
            # Show enabled repos
            grep -v "^#" "${ppa_file}" 2>/dev/null | grep -v "^$" | head -2 | while read -r line; do
                echo "      ${line}"
            done
        done
        echo "  PPAs may not have 22.04 packages and can block do-release-upgrade"
        echo "  Consider disabling PPAs before upgrade: add-apt-repository --remove ppa:..."
    fi
    echo ""
}

check_upgrade_readiness() {
    echo -e "${BLUE}[6/7] Upgrade Readiness Check${NC}"
    # Check if update-manager-core is installed (required for do-release-upgrade)
    if ! dpkg -l update-manager-core &>/dev/null; then
        echo -e "  ${YELLOW}WARNING: update-manager-core not installed${NC}"
        echo "  Install: apt install update-manager-core"
    fi

    # Simulate upgrade check
    echo "  Checking upgrade path (this may take a moment)..."
    UPGRADE_CHECK=$(do-release-upgrade --check-dist-upgrade-only 2>&1 || true)
    if echo "${UPGRADE_CHECK}" | grep -qi "new release.*22.04"; then
        echo -e "  ${GREEN}OK: Upgrade path to 22.04 available${NC}"
    elif echo "${UPGRADE_CHECK}" | grep -qi "no new release"; then
        echo -e "  ${YELLOW}INFO: No upgrade available via default channel${NC}"
        echo "  Try: do-release-upgrade -d (development/next release)"
    else
        echo "  Upgrade check output:"
        echo "${UPGRADE_CHECK}" | head -5 | while read -r line; do
            echo "    ${line}"
        done
    fi

    # Check disk space
    ROOT_FREE=$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')
    echo "  Free disk space on /: ${ROOT_FREE}GB"
    if [ "${ROOT_FREE:-0}" -lt 5 ]; then
        echo -e "  ${RED}CRITICAL: Insufficient disk space for upgrade (need 5GB+)${NC}"
    else
        echo -e "  ${GREEN}OK: Sufficient disk space for upgrade${NC}"
    fi
    echo ""
}

check_zsys_status() {
    echo -e "${BLUE}[7/7] ZFS / zsys Status (20.04 Feature)${NC}"
    # Check if ZFS root
    if df -T / 2>/dev/null | grep -q zfs; then
        echo -e "  ${YELLOW}INFO: System uses ZFS root filesystem${NC}"
        echo "  ZFS pool status:"
        zpool status 2>/dev/null | grep -E "(pool:|state:|status:)" | while read -r line; do
            echo "    ${line}"
        done

        # zsys status
        if command -v zsysctl &>/dev/null; then
            echo "  zsys states:"
            zsysctl state list 2>/dev/null | head -10 || echo "    Unable to list zsys states"
            echo -e "  ${YELLOW}NOTE: zsys is deprecated. Not available on 22.04+${NC}"
        fi

        # Snapshot count
        SNAP_COUNT=$(zfs list -t snapshot 2>/dev/null | wc -l)
        echo "  ZFS snapshots: ${SNAP_COUNT}"
    else
        echo "  Root filesystem: $(df -T / | tail -1 | awk '{print $2}') (not ZFS)"
        echo -e "  ${GREEN}OK: No ZFS-specific migration considerations${NC}"
    fi
    echo ""
}

print_summary() {
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}  EOL Readiness Summary${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
    echo "  Ubuntu 20.04 LTS standard support: ENDED (April 2025)"
    echo ""
    echo "  Recommended actions (priority order):"
    echo "  1. Enroll in Ubuntu Pro for ESM: pro attach <token>"
    echo "  2. Enable ESM services: pro enable esm-infra && pro enable esm-apps"
    echo "  3. Plan upgrade to 22.04 LTS (then optionally 24.04 LTS)"
    echo "  4. Release any held packages: apt-mark unhold <pkg>"
    echo "  5. Disable incompatible PPAs before upgrade"
    echo "  6. Run: do-release-upgrade"
    echo ""
    echo "  Ubuntu Pro free tier: up to 5 machines (personal)"
    echo "  https://ubuntu.com/pro"
    echo ""
}

# Main execution
print_header
check_os_version
check_ubuntu_pro_status
check_kernel_status
check_package_holds
check_ppa_compatibility
check_upgrade_readiness
check_zsys_status
print_summary
```

---
---

## Ubuntu 22.04 LTS (Jammy Jellyfish)

**Codename:** Jammy Jellyfish
**Released:** April 21, 2022
**Standard Support:** Until April 2027
**ESM (Ubuntu Pro):** Until April 2032
**Kernel:** 5.15 LTS (HWE track: 6.5+)
**Python Default:** Python 3.10
**OpenSSL:** 3.0

---

### 1. Wayland Default Session

Ubuntu 22.04 was the first Ubuntu LTS release to ship Wayland as the default display protocol for GNOME sessions. Previously, Ubuntu 20.04 offered Wayland as an option but defaulted to X.org.

**What changed:**
- GDM now defaults to `gnome-shell` on Wayland (`/usr/share/wayland-sessions/ubuntu.desktop`)
- X.org session available as a fallback at the login screen via gear icon ("Ubuntu on Xorg")
- **Automatic X.org fallback for NVIDIA proprietary drivers** — GDM detects non-Wayland-capable NVIDIA drivers and reverts to X.org automatically (changed in later point releases as NVIDIA improved Wayland support)
- **Xwayland** — Legacy X11 applications run inside Xwayland without requiring a full X.org session

**Session detection:**
```bash
echo $XDG_SESSION_TYPE          # "wayland" or "x11"
loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type
```

**Force X.org system-wide:**
```bash
# Edit GDM configuration
echo 'WaylandEnable=false' >> /etc/gdm3/custom.conf
systemctl restart gdm3
```

**Wayland-specific behavior notes:**
- Screen capture APIs changed — apps must use PipeWire/xdg-desktop-portal
- Some remote desktop tools (VNC, older RDP clients) require X.org or Xwayland
- `DISPLAY` variable not set in pure Wayland sessions; `WAYLAND_DISPLAY=wayland-0` is set instead

---

### 2. GNOME 42

Ubuntu 22.04 ships GNOME 42, a significant desktop update from GNOME 40/41 (Ubuntu 20.04 shipped GNOME 3.36).

**New in GNOME 42 (first LTS exposure):**
- **libadwaita** — New GTK4 UI toolkit, provides consistent "Adwaita" style across apps. Many core apps ported: Files (Nautilus), Text Editor, Calendar.
- **System-wide dark mode** — Settings > Appearance > Dark. Apps using libadwaita respect this preference automatically. Exposed via `gsettings`:
  ```bash
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark
  gsettings set org.gnome.desktop.interface color-scheme default
  ```
- **Redesigned system Settings** — New layout for the GNOME Control Center, reorganized panels
- **Horizontal workspaces** — Workspaces now scroll horizontally by default (changed from vertical in GNOME 40)
- **Screenshot UI** — New built-in screenshot/screencast tool replacing the old gnome-screenshot
  - Triggered by Print Screen key
  - Supports area, window, and full-screen capture
  - Integrated with Wayland screen capture APIs

**Ubuntu-specific GNOME modifications retained:**
- Dock on left (Ubuntu Dock, based on Dash to Dock)
- AppIndicator tray icon support via extension
- Ubuntu orange accent color in Yaru theme

---

### 3. Real-Time Kernel (Ubuntu Pro Feature)

Ubuntu 22.04 introduced the `linux-image-realtime` kernel as an Ubuntu Pro feature, making a PREEMPT_RT real-time kernel available via `pro enable`.

**What it provides:**
- Full PREEMPT_RT patch set applied to the 5.15 kernel
- Deterministic latency for time-sensitive workloads
- Targeted at: industrial control systems, financial trading infrastructure, telco (O-RAN), audio production

**Use cases:**
- **Industrial automation** — PLC-like control loops requiring microsecond-level determinism
- **Financial trading** — Low-latency order execution systems
- **Telco / O-RAN** — 5G RAN software requiring hard real-time guarantees
- **Professional audio** — JACK audio server with minimal xrun rates

**Installation (requires Ubuntu Pro):**
```bash
pro attach <token>
pro enable realtime-kernel
# Reboot into RT kernel
reboot
uname -r    # Should show: 5.15.x-xx-realtime
```

**Verification and tuning:**
```bash
# Check RT kernel
uname -v | grep PREEMPT_RT

# Check scheduling latency
cyclictest -l 100000 -m -n -i 200 -p 98 -q

# CPU isolation for RT tasks (add to GRUB_CMDLINE_LINUX)
# isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3
```

**Note:** The real-time kernel is not available without Ubuntu Pro. It is separate from the standard kernel and must be explicitly enabled.

---

### 4. Active Directory Integration (adsys)

Ubuntu 22.04 introduced `adsys`, a new Active Directory integration daemon developed by Canonical that goes significantly beyond basic `realm join` / SSSD functionality.

**What adsys provides (new in 22.04):**
- **GPO-like policy application** — AD Group Policy Objects applied to Ubuntu clients (computer and user policies)
  - Manages: sudoers, scripts (logon/logoff/startup/shutdown), proxy settings, privilege escalation, certificate trust
- **Computer and user policy support** — GPOs can target machine accounts or individual AD users
- **ADMX templates** — Ubuntu-specific ADMX templates for managing Ubuntu-specific settings from AD Group Policy Management Console
- **Centralized logging** — `adsysctl` commands for policy status and debugging

**Components:**
- `adsysd` — Daemon running on the Ubuntu client
- `adsysctl` — CLI tool for managing and debugging AD integration
- `nss-adsys` — NSS module for name resolution
- Integration with `sssd` for Kerberos authentication

**Setup workflow:**
```bash
# Install
apt install adsys

# Join domain (realm still used for the actual join)
apt install realmd sssd-ad oddjob-mkhomedir adcli
realm join --user=Administrator example.com

# Enable adsys
systemctl enable --now adsysd

# Check status
adsysctl policy show              # Applied policies
adsysctl policy update            # Force policy refresh
adsysctl service status           # Daemon status
```

**SSSD improvements in 22.04:**
- SSSD 2.6: Improved caching, offline login reliability, KCM credential cache by default
- `/etc/sssd/sssd.conf` manages Kerberos ticket caching via `krb5_ccachedir`

**realm commands:**
```bash
realm list                        # Show joined domains
realm discover example.com        # Probe domain info
realm permit --all                # Allow all AD users to log in
realm deny --all && realm permit user@example.com  # Restrict to specific user
```

---

### 5. nftables Default

Ubuntu 22.04 switched to nftables as the default firewall backend on server installs, replacing the legacy iptables kernel framework.

**What changed:**
- `iptables` commands on 22.04 server are symlinked to `iptables-nft` (nftables compatibility layer)
- UFW (Uncomplicated Firewall) uses nftables backend by default
- `nftables.service` enabled by default on server installs
- Ruleset stored in `/etc/nftables.conf`

**Practical implications:**
- Scripts using `iptables` still function via the compatibility shim
- Direct `nft` commands for new ruleset management
- `iptables-legacy` package available if true legacy iptables is needed

**nftables basics (new to 22.04 default):**
```bash
# View current ruleset
nft list ruleset

# UFW still works as before
ufw allow 22/tcp
ufw enable
ufw status verbose

# Native nftables example
nft add table inet filter
nft add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
nft add rule inet filter input ct state established,related accept
nft add rule inet filter input iif lo accept
nft add rule inet filter input tcp dport 22 accept

# Save ruleset
nft list ruleset > /etc/nftables.conf
```

**Check which backend iptables is using:**
```bash
update-alternatives --query iptables
# Should show: /usr/sbin/iptables-nft

iptables --version
# Shows: iptables v1.8.x (nf_tables)
```

---

### 6. LXD 5.0 LTS

LXD 5.0 LTS shipped with Ubuntu 22.04, bringing major architectural improvements over LXD 4.0.

**New in LXD 5.0 (over 4.0):**
- **Projects as first-class feature** — Full project isolation including networks, storage pools, and images per project
- **Improved clustering** — Cluster-aware evacuation (`lxc cluster evacuate <member>`), member roles (database, database-standby)
- **OVN networking** — Integrated Open Virtual Network for software-defined networking between instances
- **Instance types** — `t1.micro`, `c2.medium`-style instance type presets for resource allocation
- **Forward migration** — State and config from LXD 4.0 migrates forward; not backward-compatible

**Migration from LXD 4.0 (20.04 → 22.04):**
```bash
# On source (20.04) system
lxd migrate                        # Initiates migration wizard

# Or via snap channel upgrade
snap refresh lxd --channel=5.0/stable
```

**New commands in 5.0:**
```bash
lxc cluster evacuate <member>      # Migrate all instances off a member
lxc cluster restore <member>       # Bring member back into service
lxc network list-allocations       # Show IP allocations across networks
lxc project info                   # Project resource usage summary
lxc config trust add --name ci-bot # Named trust certificates
```

---

### 7. OpenStack Yoga / Ceph Quincy

Ubuntu 22.04 ships updated cloud infrastructure packages targeting enterprise OpenStack and Ceph deployments.

**OpenStack Yoga (22.04):**
- Full OpenStack Yoga release packages via `cloud-archive:yoga` (also available as default in 22.04)
- Upgrade path: Victoria (20.04) → Wallaby → Xena → Yoga
- Key Yoga features: improved Metal-as-a-Service (Ironic), Neutron OVN improvements, Placement API stabilization

**Ceph Quincy (22.04):**
- Ceph 17.x (Quincy) available in 22.04 repos
- New in Quincy: improved balancer, telemetry, RGW S3 Select, mclock scheduler
- `apt install ceph` on 22.04 installs Quincy by default

**Deployment tooling:**
- **Juju** — Canonical's application modeling tool, integrates with OpenStack charms
- **MAAS** — Metal-as-a-Service for bare-metal provisioning in OpenStack environments
- **Charmed OpenStack** — Production deployment reference

---

### 8. MicroK8s HA (Stable High Availability)

MicroK8s reached stable HA (High Availability) mode in Ubuntu 22.04, with additional enterprise-grade add-ons.

**New in MicroK8s on 22.04:**
- **Stable HA mode** — 3-node HA with dqlite-backed etcd replacement (previously experimental in 20.04)
- **GPU Operator add-on** — `microk8s enable gpu` deploys NVIDIA GPU operator for GPU workloads in Kubernetes
- **Kata Containers add-on** — `microk8s enable kata` for VM-isolated container workloads
- **Observability stack** — `microk8s enable observability` deploys Prometheus, Grafana, Loki stack

**HA cluster setup:**
```bash
snap install microk8s --classic
microk8s status --wait-ready

# On first node
microk8s add-node              # Generates join token

# On second and third nodes
microk8s join <ip>:<port>/<token>

# Verify HA
microk8s kubectl get nodes
microk8s status | grep high-availability
```

**Add-ons (22.04 stable):**
```bash
microk8s enable gpu            # NVIDIA GPU operator
microk8s enable kata           # Kata Containers isolation
microk8s enable observability  # Prometheus + Grafana + Loki
microk8s enable ingress        # NGINX ingress controller
microk8s enable cert-manager   # Cert-manager for TLS
```

---

### Version Script: 10-ad-integration.sh

```bash
#!/bin/bash
# Ubuntu 22.04 Active Directory Integration Assessment
# Version: 22.1.0
# Targets: Ubuntu 22.04 LTS (Jammy Jellyfish)
# Purpose: Assess adsys status, SSSD configuration, realm connectivity,
#          AD domain membership, and GPO application status

set -euo pipefail

SCRIPT_VERSION="22.1.0"
TARGET_VERSION="22.04"
REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}  Ubuntu 22.04 Active Directory Integration v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}  ${REPORT_DATE}${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
}

check_os_version() {
    echo -e "${BLUE}[1/7] OS Version Check${NC}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "  OS: ${PRETTY_NAME}"
        echo "  Version ID: ${VERSION_ID}"
        if [ "${VERSION_ID}" != "22.04" ]; then
            echo -e "  ${YELLOW}WARNING: This script targets Ubuntu 22.04, detected ${VERSION_ID}${NC}"
        else
            echo -e "  ${GREEN}OK: Running on target version 22.04${NC}"
        fi
    else
        echo -e "  ${RED}ERROR: Cannot determine OS version${NC}"
    fi
    echo ""
}

check_adsys_status() {
    echo -e "${BLUE}[2/7] adsys Service Status${NC}"
    if command -v adsysctl &>/dev/null; then
        echo -e "  ${GREEN}OK: adsys is installed${NC}"
        ADSYS_VERSION=$(dpkg -l adsys 2>/dev/null | grep "^ii" | awk '{print $3}')
        echo "  Version: ${ADSYS_VERSION:-unknown}"

        # Check daemon status
        if systemctl is-active --quiet adsysd 2>/dev/null; then
            echo -e "  ${GREEN}OK: adsysd daemon is running${NC}"
        else
            ADSYS_STATE=$(systemctl is-active adsysd 2>/dev/null || echo "unknown")
            echo -e "  ${RED}ERROR: adsysd is ${ADSYS_STATE}${NC}"
            echo "  Start: systemctl start adsysd"
            echo "  Enable: systemctl enable adsysd"
        fi

        # Service status details
        echo "  Service details:"
        systemctl status adsysd 2>/dev/null | grep -E "(Active:|Main PID:)" | while read -r line; do
            echo "    ${line}"
        done

    else
        echo -e "  ${YELLOW}INFO: adsys not installed${NC}"
        echo "  Install: apt install adsys"
        echo "  Note: adsys provides GPO-like AD policy management (22.04 feature)"
    fi
    echo ""
}

check_sssd_configuration() {
    echo -e "${BLUE}[3/7] SSSD Configuration${NC}"
    if command -v sssd &>/dev/null; then
        SSSD_VERSION=$(sssd --version 2>/dev/null | head -1 || dpkg -l sssd 2>/dev/null | grep "^ii" | awk '{print $3}')
        echo "  SSSD version: ${SSSD_VERSION:-unknown}"

        # Check service state
        if systemctl is-active --quiet sssd 2>/dev/null; then
            echo -e "  ${GREEN}OK: SSSD is running${NC}"
        else
            SSSD_STATE=$(systemctl is-active sssd 2>/dev/null || echo "not running")
            echo -e "  ${RED}ERROR: SSSD is ${SSSD_STATE}${NC}"
        fi

        # Config file check
        if [ -f /etc/sssd/sssd.conf ]; then
            echo -e "  ${GREEN}OK: /etc/sssd/sssd.conf present${NC}"
            # Extract domain names
            DOMAINS=$(grep "^\[domain/" /etc/sssd/sssd.conf 2>/dev/null | sed 's/\[domain\///;s/\]//' || true)
            if [ -n "${DOMAINS}" ]; then
                echo "  Configured domains:"
                echo "${DOMAINS}" | while read -r domain; do
                    echo "    - ${domain}"
                done
            fi
            # Check id_provider
            ID_PROVIDER=$(grep "id_provider" /etc/sssd/sssd.conf 2>/dev/null | head -1 | awk -F= '{print $2}' | tr -d ' ' || echo "unknown")
            echo "  ID provider: ${ID_PROVIDER}"

            # KCM cache check (22.04 default)
            if grep -q "ccache_storage.*KCM\|KCM" /etc/sssd/sssd.conf 2>/dev/null; then
                echo -e "  ${GREEN}OK: KCM credential cache configured (22.04 default)${NC}"
            fi
        else
            echo -e "  ${YELLOW}WARNING: /etc/sssd/sssd.conf not found${NC}"
            echo "  SSSD may not be configured for AD integration"
        fi
    else
        echo -e "  ${YELLOW}INFO: SSSD not installed${NC}"
        echo "  Install: apt install sssd sssd-ad"
    fi
    echo ""
}

check_realm_status() {
    echo -e "${BLUE}[4/7] Realm / Domain Membership${NC}"
    if command -v realm &>/dev/null; then
        echo -e "  ${GREEN}OK: realmd is installed${NC}"
        REALM_LIST=$(realm list 2>/dev/null)
        if [ -n "${REALM_LIST}" ]; then
            echo -e "  ${GREEN}OK: Joined to domain(s):${NC}"
            echo "${REALM_LIST}" | while read -r line; do
                echo "    ${line}"
            done
        else
            echo -e "  ${YELLOW}WARNING: Not joined to any domain${NC}"
            echo "  To join: realm join --user=Administrator example.com"
            echo "  Prerequisites: apt install realmd sssd-ad oddjob-mkhomedir adcli"
        fi

        # Check permitted logins
        PERMITTED=$(realm list 2>/dev/null | grep "permitted-logins\|permitted-groups" || true)
        if [ -n "${PERMITTED}" ]; then
            echo "  Login permissions:"
            echo "${PERMITTED}" | while read -r line; do
                echo "    ${line}"
            done
        fi
    else
        echo -e "  ${YELLOW}INFO: realmd not installed${NC}"
        echo "  Install: apt install realmd"
    fi

    # Also check via hostname and Kerberos
    if command -v klist &>/dev/null; then
        echo ""
        echo "  Kerberos ticket cache:"
        klist 2>/dev/null | head -5 || echo "    No tickets (not authenticated)"
    fi
    echo ""
}

check_ad_connectivity() {
    echo -e "${BLUE}[5/7] AD Connectivity${NC}"
    # Try to determine the domain from sssd.conf or realm
    DOMAIN=""
    if [ -f /etc/sssd/sssd.conf ]; then
        DOMAIN=$(grep "^\[domain/" /etc/sssd/sssd.conf | head -1 | sed 's/\[domain\///;s/\]//' || true)
    fi
    if [ -z "${DOMAIN}" ] && command -v realm &>/dev/null; then
        DOMAIN=$(realm list 2>/dev/null | grep "realm-name\|domain-name" | head -1 | awk '{print $NF}' || true)
    fi

    if [ -n "${DOMAIN}" ]; then
        echo "  Testing connectivity to domain: ${DOMAIN}"
        # DNS SRV record lookup
        if command -v host &>/dev/null; then
            SRV=$(host -t SRV "_ldap._tcp.${DOMAIN}" 2>/dev/null | head -3 || echo "DNS lookup failed")
            echo "  LDAP SRV records:"
            echo "${SRV}" | while read -r line; do
                echo "    ${line}"
            done
        fi

        # Try to reach a DC via LDAP port
        DC=$(host -t SRV "_ldap._tcp.${DOMAIN}" 2>/dev/null | awk '{print $NF}' | head -1 | tr -d '.' || true)
        if [ -n "${DC}" ]; then
            if timeout 3 bash -c "echo > /dev/tcp/${DC}/389" 2>/dev/null; then
                echo -e "  ${GREEN}OK: LDAP port 389 reachable on ${DC}${NC}"
            else
                echo -e "  ${RED}ERROR: Cannot reach LDAP port 389 on ${DC}${NC}"
            fi
            if timeout 3 bash -c "echo > /dev/tcp/${DC}/88" 2>/dev/null; then
                echo -e "  ${GREEN}OK: Kerberos port 88 reachable on ${DC}${NC}"
            else
                echo -e "  ${RED}ERROR: Cannot reach Kerberos port 88 on ${DC}${NC}"
            fi
        fi
    else
        echo -e "  ${YELLOW}INFO: No domain detected — skipping connectivity tests${NC}"
        echo "  Join a domain first: realm join --user=Administrator example.com"
    fi
    echo ""
}

check_gpo_status() {
    echo -e "${BLUE}[6/7] GPO / adsys Policy Status${NC}"
    if command -v adsysctl &>/dev/null && systemctl is-active --quiet adsysd 2>/dev/null; then
        echo "  Applied policies (computer):"
        adsysctl policy show 2>/dev/null || echo "    Unable to retrieve policy status"

        echo ""
        echo "  Last policy update:"
        adsysctl service cat 2>/dev/null | grep -i "policy\|updated\|applied" | tail -5 || \
            journalctl -u adsysd --since "24 hours ago" 2>/dev/null | \
            grep -i "policy\|applied\|updated" | tail -5 || \
            echo "    No recent policy events found"

        # Check for policy errors
        POLICY_ERRORS=$(journalctl -u adsysd --since "24 hours ago" 2>/dev/null | grep -i "error\|fail" | wc -l || echo "0")
        if [ "${POLICY_ERRORS}" -gt 0 ]; then
            echo -e "  ${YELLOW}WARNING: ${POLICY_ERRORS} policy-related errors in last 24h${NC}"
            echo "  View: journalctl -u adsysd --since '24 hours ago' | grep -i error"
        else
            echo -e "  ${GREEN}OK: No policy errors in last 24 hours${NC}"
        fi

        # Force policy update
        echo ""
        echo "  To force policy refresh: adsysctl policy update"
        echo "  To update for specific user: adsysctl policy update --all"
    else
        echo -e "  ${YELLOW}INFO: adsys not running — GPO policy check skipped${NC}"
        echo "  Install and start adsys for GPO-like policy management"
        echo "  This is a key 22.04 feature: apt install adsys && systemctl enable --now adsysd"
    fi
    echo ""
}

check_wayland_nftables() {
    echo -e "${BLUE}[7/7] 22.04 Feature Status (Wayland & nftables)${NC}"

    # Wayland check (desktop systems only)
    if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
        echo "  Display session type: ${SESSION_TYPE}"
        if [ "${SESSION_TYPE}" = "wayland" ]; then
            echo -e "  ${GREEN}OK: Running Wayland session (22.04 default)${NC}"
        else
            echo -e "  ${YELLOW}INFO: Running X11 session (fallback or NVIDIA)${NC}"
        fi
    else
        echo "  Display session: server/headless (no display)"
    fi

    # nftables check
    echo ""
    if command -v nft &>/dev/null; then
        echo -e "  ${GREEN}OK: nftables installed${NC}"
        NFT_VERSION=$(nft --version 2>/dev/null | head -1)
        echo "  Version: ${NFT_VERSION}"
        if systemctl is-active --quiet nftables 2>/dev/null; then
            echo -e "  ${GREEN}OK: nftables.service is active${NC}"
        else
            echo "  nftables.service: $(systemctl is-active nftables 2>/dev/null || echo 'inactive')"
        fi
        # Confirm iptables → nft shim
        IPTABLES_BACKEND=$(update-alternatives --query iptables 2>/dev/null | grep "Value:" | awk '{print $2}' || echo "unknown")
        echo "  iptables backend: ${IPTABLES_BACKEND}"
        if echo "${IPTABLES_BACKEND}" | grep -q "nft"; then
            echo -e "  ${GREEN}OK: iptables using nftables backend (22.04 default)${NC}"
        else
            echo -e "  ${YELLOW}INFO: iptables using legacy backend${NC}"
        fi
    fi
    echo ""
}

print_summary() {
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}  Active Directory Integration Summary${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
    echo "  Ubuntu 22.04 LTS support: Standard until April 2027"
    echo "  ESM (Ubuntu Pro): Until April 2032"
    echo ""
    echo "  AD Integration components:"
    echo "  - realmd: Domain join/leave"
    echo "  - sssd: Authentication and identity"
    echo "  - adsys: GPO-like policy application (22.04 feature)"
    echo "  - krb5-user: Kerberos client tools"
    echo ""
    echo "  Quick setup (if not yet configured):"
    echo "  apt install realmd sssd sssd-ad adsys oddjob-mkhomedir adcli krb5-user"
    echo "  realm join --user=Administrator example.com"
    echo "  systemctl enable --now adsysd"
    echo "  adsysctl policy update"
    echo ""
    echo "  ADMX templates for Ubuntu GPOs:"
    echo "  /usr/share/adsys/ubuntu.admx (copy to AD SYSVOL)"
    echo ""
    echo "  Documentation: https://canonical-adsys.readthedocs.io"
    echo ""
}

# Main execution
print_header
check_os_version
check_adsys_status
check_sssd_configuration
check_realm_status
check_ad_connectivity
check_gpo_status
check_wayland_nftables
print_summary
```
