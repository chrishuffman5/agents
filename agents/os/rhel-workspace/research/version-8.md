# RHEL 8 — Version-Specific Research

**Support Status:** Full Support ended May 2024. Maintenance Support until May 2029. RHEL 8.10 is the final minor release.
**Kernel:** 4.18 (heavily backported across 8.0–8.10)
**Baseline:** RHEL 7; this file covers only NEW or CHANGED features in RHEL 8
**Consumed by:** Opus writer agent producing the version-specific agent file

---

## 1. Application Streams (AppStreams)

### Dual-Repository Model
RHEL 8 replaces the single package repository of RHEL 7 with two distinct repos:
- **BaseOS** — Core OS packages with traditional RPM lifecycle (tied to RHEL 8 lifecycle). Provides the foundational OS layer.
- **AppStream** — User-space applications, runtimes, and tools. Packages here ship as traditional RPMs or as **modules** (streams), enabling multiple versions to coexist in the repo.

### Module Streams Concept
A module is a set of RPM packages that belong to a specific component at a specific version. Each module has:
- **Name** — e.g., `postgresql`
- **Stream** — version track, e.g., `10`, `12`, `13`, `15`. Only one stream per module can be active at a time.
- **Profile** — installation subset (e.g., `server`, `client`, `default`). Profiles define which packages get installed.
- **Context** — build context; usually not user-facing.

Default streams are installed when no stream is specified. Non-default streams must be explicitly enabled.

### DNF Module Commands
```bash
# List all available modules and their streams
dnf module list

# List enabled/disabled state for a specific module
dnf module list postgresql

# Enable a specific stream (does not install)
dnf module enable postgresql:15

# Install a module with a specific stream and profile
dnf module install postgresql:15/server

# Install using the active/default stream
dnf module install postgresql

# Reset a module to no-stream-selected state
dnf module reset postgresql

# Switch active stream (disables old, enables new)
dnf module switch-to postgresql:15

# Disable a module entirely
dnf module disable nodejs

# Show detailed module info
dnf module info postgresql:15

# Remove a module profile's packages
dnf module remove postgresql:15/server
```

### Common Module Streams and Lifecycles

| Module     | Streams Available        | Notes                                  |
|------------|--------------------------|----------------------------------------|
| php        | 7.2, 7.3, 7.4, 8.0      | 7.2 default in RHEL 8.0; EOL varies per stream |
| python38   | 3.8                      | Parallel to system python3 (3.6)       |
| python39   | 3.9                      | Available from RHEL 8.4+               |
| nodejs     | 10, 12, 14, 16, 18, 20  | Stream lifecycle ~2 years per version  |
| ruby       | 2.5, 2.6, 2.7, 3.0, 3.1 |                                        |
| postgresql | 10, 12, 13, 15           | 10 default in 8.0; 15 via AppStream    |
| nginx      | 1.14, 1.16, 1.18, 1.20  | 1.14 default                          |
| httpd      | 2.4                      | Single stream; updated via RPM         |
| perl       | 5.26, 5.30, 5.32         |                                        |
| maven      | 3.5, 3.6                 |                                        |

### Impact on Package Management Workflows
- `yum` is now a symbolic link to `dnf`; all `yum` commands work unchanged.
- Installing a package that belongs to a disabled module will fail with a module conflict error — the stream must be enabled first.
- `dnf update` does NOT automatically switch module streams; explicit `switch-to` is required.
- Stream selections are recorded in `/etc/dnf/modules.d/`.

---

## 2. Podman Replaces Docker

### Architecture Change
Docker is not available in RHEL 8 repositories. The container toolchain is:
- **Podman** — Runtime (drop-in Docker CLI replacement, daemonless)
- **Buildah** — Image building (OCI-compliant, also used internally by Podman)
- **Skopeo** — Image inspection and transfer between registries

### Installation
```bash
# All three tools in one module group
dnf install podman buildah skopeo

# Podman 4.x available via module stream
dnf module enable container-tools:rhel8
dnf install @container-tools
```

### Daemonless and Rootless Architecture
Podman runs containers as direct children of the calling process — no daemon. Rootless containers run entirely within the user's namespace:
```bash
# Run as non-root user — no sudo required
podman run -d --name myapp nginx:latest

# Rootless container storage lives in user home
# ~/.local/share/containers/storage/

# Generate systemd unit for rootless container (user scope)
podman generate systemd --new --name myapp > ~/.config/systemd/user/myapp.service
systemctl --user enable --now myapp.service
```

### Docker CLI Compatibility
```bash
# Alias for teams migrating from Docker
alias docker=podman

# Docker Compose equivalent
dnf install podman-compose
# or use docker-compose with DOCKER_HOST pointing to Podman socket

# Enable Podman socket for Docker API compatibility
systemctl enable --now podman.socket
export DOCKER_HOST=unix:///run/podman/podman.sock
```

### Registry Configuration
`/etc/containers/registries.conf` controls search order and blocked registries:
```toml
[registries.search]
registries = ["registry.access.redhat.com", "registry.redhat.io", "docker.io"]

[registries.insecure]
registries = []

[registries.block]
registries = []
```

### Container Networking
- RHEL 8.0–8.6: CNI (Container Network Interface) plugins — `cni-plugins` package
- RHEL 8.7+: Netavark replaces CNI as default network backend for new installs
- `podman network ls`, `podman network create`, `podman network inspect` manage networks

### Buildah for Image Building
```bash
# Build from Containerfile/Dockerfile
buildah bud -t myimage:latest .

# Inspect image layers
buildah inspect myimage:latest

# Push to registry
buildah push myimage:latest docker://registry.example.com/myimage:latest
```

### Skopeo for Image Transfer
```bash
# Copy image between registries without pulling locally
skopeo copy docker://docker.io/nginx:latest docker://registry.example.com/nginx:latest

# Inspect remote image without pulling
skopeo inspect docker://registry.access.redhat.com/ubi8/ubi

# Copy to local OCI directory
skopeo copy docker://nginx:latest oci:/tmp/nginx-oci
```

---

## 3. Cockpit Web Console

### Default Installation
Cockpit is installed and enabled by default in RHEL 8 minimal and server installs:
```bash
# Verify and start if needed
systemctl enable --now cockpit.socket

# Cockpit listens on port 9090 (TCP)
firewall-cmd --permanent --add-service=cockpit
firewall-cmd --reload
```
Access: `https://<hostname>:9090`

### Modules Available
```bash
dnf install cockpit-storaged       # Storage management (LVM, Stratis, RAID)
dnf install cockpit-networkmanager # Network interface management
dnf install cockpit-machines       # Virtual machine management (libvirt)
dnf install cockpit-podman         # Container management via Podman
dnf install cockpit-composer       # Image Builder GUI
dnf install cockpit-session-recording  # tlog session recording
```

### Key Capabilities
- **Storage** — Create/manage LVM volumes, RAID, Stratis pools, NFS mounts
- **Networking** — Configure bonds, bridges, VLANs, firewall zones
- **Services** — Start/stop/enable systemd units, view logs
- **Firewall** — Manage firewalld zones and services graphically
- **Accounts** — Create users, manage SSH keys, sudo privileges
- **Virtual Machines** — Create/start/stop/migrate VMs (cockpit-machines)
- **Certificate Auth** — Configure smart card / certificate authentication for Cockpit login

---

## 4. Stratis Storage

### Overview
Stratis is a local storage management solution introduced in RHEL 8. It provides:
- Pool-based management over block devices
- XFS filesystem layer (automatically formatted)
- Thin provisioning (filesystems are thinly provisioned within a pool)
- Snapshots
- Optional cache tier (NVMe/SSD as cache for HDD pools)

### Installation and Setup
```bash
dnf install stratisd stratis-cli
systemctl enable --now stratisd

# Create a pool from one or more block devices
stratis pool create mypool /dev/sdb /dev/sdc

# Create a filesystem within the pool
stratis filesystem create mypool myfs

# Mount the filesystem (device path is symlink under /dev/stratis/)
mkdir /mnt/myfs
mount /dev/stratis/mypool/myfs /mnt/myfs

# Persistent mount — use UUID in /etc/fstab with x-systemd.requires=stratisd.service
UUID=$(lsblk -o UUID /dev/stratis/mypool/myfs -n)
echo "UUID=$UUID /mnt/myfs xfs defaults,x-systemd.requires=stratisd.service 0 0" >> /etc/fstab
```

### Snapshots
```bash
# Create a snapshot of a filesystem
stratis filesystem snapshot mypool myfs myfs-snap-$(date +%Y%m%d)

# List all filesystems and snapshots
stratis filesystem list mypool
```

### Cache Tier
```bash
# Add a fast device as cache to an existing pool
stratis pool init-cache mypool /dev/nvme0n1

# Add more cache devices later
stratis pool add-cache mypool /dev/nvme1n1
```

### Monitoring
```bash
stratis pool list          # Pool usage and health
stratis filesystem list    # Filesystem sizes and usage
stratis blockdev list      # Block devices in pools
stratis daemon version     # stratisd version
```

---

## 5. firewalld with nftables

### nftables as Default Backend
RHEL 8 switches firewalld's backend from iptables to nftables. The `iptables` command is provided by `iptables-legacy` for compatibility but is no longer the active kernel subsystem.

Key impact: Rules written directly with `iptables` commands do not interact with nftables rules — they use a separate legacy table. Use `firewall-cmd` or `nft` for all rule management.

### firewall-cmd Reference
```bash
# Zone management
firewall-cmd --get-default-zone
firewall-cmd --set-default-zone=public
firewall-cmd --list-all
firewall-cmd --list-all-zones

# Open a service (permanent and reload)
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Open a port
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

# Remove a service
firewall-cmd --permanent --remove-service=ftp

# Rich rules — fine-grained control
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept'

# Direct nftables rule passthrough (use sparingly)
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -s 10.0.0.0/8 -j ACCEPT
```

### Backward Compatibility
```bash
# Check if iptables-legacy is providing the iptables command
update-alternatives --display iptables

# Applications expecting /sbin/iptables still work via legacy mode
# but those rules are isolated from nftables firewalld rules
```

---

## 6. System-Wide Crypto Policies

### Overview
RHEL 8 introduces system-wide cryptographic policies that apply uniformly across all crypto libraries (OpenSSL, GnuTLS, NSS, Kerberos, libssh). A single command changes TLS minimums, cipher suites, and key sizes everywhere.

### Policy Levels
| Policy  | Description                                                              |
|---------|--------------------------------------------------------------------------|
| DEFAULT | TLS 1.2+, RSA ≥ 2048, SHA-1 deprecated. Balances security and compat.   |
| LEGACY  | Enables older protocols (TLS 1.0/1.1, SHA-1 signatures, weaker ciphers) |
| FUTURE  | TLS 1.3 only, RSA ≥ 3072, stricter requirements                         |
| FIPS    | FIPS 140-2 compliant. Requires `fips-mode-setup --enable` + reboot       |

### Commands
```bash
# Show current policy
update-crypto-policies --show

# Set a policy
update-crypto-policies --set DEFAULT
update-crypto-policies --set LEGACY
update-crypto-policies --set FUTURE

# Enable FIPS mode (requires reboot)
fips-mode-setup --enable
reboot

# Check FIPS mode status
fips-mode-setup --check

# Apply a sub-policy on top of a base policy
update-crypto-policies --set DEFAULT:NO-SHA1
update-crypto-policies --set DEFAULT:SHA1   # re-enable SHA1 if needed
```

### Custom Sub-Policies
Sub-policies are stored in `/etc/crypto-policies/policies/modules/`. Create a `.pmod` file:
```
# /etc/crypto-policies/policies/modules/NO-CAMELLIA.pmod
cipher@gnutls = -CAMELLIA-128-CBC -CAMELLIA-256-CBC
```
Apply: `update-crypto-policies --set DEFAULT:NO-CAMELLIA`

---

## 7. Image Builder (Composer)

### Overview
Image Builder (osbuild-composer) creates customized OS images for deployment across clouds, VMs, and bare metal. It replaces manual kickstart-based image creation for many use cases.

### Installation
```bash
dnf install osbuild-composer composer-cli cockpit-composer
systemctl enable --now osbuild-composer.socket
```

### Blueprint Format (TOML)
```toml
name = "base-webserver"
description = "RHEL 8 base image with nginx"
version = "0.0.1"
modules = []
groups = []

[[packages]]
name = "nginx"
version = "*"

[[packages]]
name = "firewalld"
version = "*"

[customizations]
hostname = "webserver01"

[[customizations.user]]
name = "admin"
password = "$6$..."
groups = ["wheel"]
```

### composer-cli Commands
```bash
# Push a blueprint
composer-cli blueprints push blueprint.toml

# List blueprints
composer-cli blueprints list

# Show blueprint details
composer-cli blueprints show base-webserver

# Start a compose (build)
composer-cli compose start base-webserver qcow2

# List composes and status
composer-cli compose list
composer-cli compose status

# Download finished image
composer-cli compose image <compose-UUID>

# Delete a compose
composer-cli compose delete <compose-UUID>
```

### Output Formats

| Format     | Use Case                        |
|------------|---------------------------------|
| qcow2      | KVM/QEMU virtual machines       |
| ami        | AWS EC2                         |
| vmdk       | VMware vSphere                  |
| vhd        | Azure / Hyper-V                 |
| iso        | Bootable ISO (bare metal)       |
| tar        | Generic container/import        |
| oci        | OCI container image             |
| edge-commit | RHEL for Edge (OSTree)         |

---

## 8. RHEL Insights (Insights Client)

### Registration
```bash
dnf install insights-client
insights-client --register

# Check registration status
insights-client --status

# Run an immediate upload
insights-client --analyze-container  # for container analysis
insights-client                       # for system analysis
```

### Capabilities in Red Hat Insights
- **Advisor** — Rule-based recommendations; highlights misconfigurations and known issues
- **Vulnerability** — CVE exposure based on installed packages; integrates with Red Hat Security Advisories
- **Compliance** — OpenSCAP-based compliance reporting (PCI-DSS, HIPAA, CIS)
- **Malware Detection** — YARA-based scanning for known malware signatures
- **Patch** — Patch planning and scheduling
- **Drift** — Configuration drift detection across systems

### Scheduling
```bash
# insights-client runs via systemd timer by default
systemctl status insights-client.timer

# Manual schedule override
insights-client --analyze-container
```

---

## 9. SELinux Improvements for Containers

### udica Tool
`udica` generates custom SELinux policies for containers based on container inspection output:
```bash
dnf install udica

# Inspect running container
podman inspect mycontainer > mycontainer.json

# Generate policy
udica -j mycontainer.json my_container_policy

# Load and apply the policy
semodule -i my_container_policy.cil /usr/share/udica/templates/{base_container.cil,net_container.cil}

# Run container with new policy
podman run --security-opt label=type:my_container_policy.process -d myimage
```

### Container-SELinux Package
```bash
dnf install container-selinux

# Provides the container_t and container_file_t types
# All Podman-managed containers run under container_t by default

# Check container SELinux context
ps -eZ | grep container
ls -Z /var/lib/containers/
```

### Key SELinux Policy Improvements in RHEL 8
- `container_t` domain for all OCI containers (rootful and rootless)
- `container_var_lib_t` for container storage
- MCS (Multi-Category Security) separation between containers — each container gets unique MCS labels
- `spc_t` (super privileged container) for containers that need `--privileged`

---

## 10. Migration from RHEL 7

### Key Differences

| Area                     | RHEL 7                          | RHEL 8                              |
|--------------------------|---------------------------------|-------------------------------------|
| Package manager          | yum                             | dnf (yum is an alias)               |
| Firewall backend         | iptables                        | nftables (via firewalld)            |
| Network scripts          | /etc/sysconfig/network-scripts/ | NetworkManager (nmcli/nmtui)        |
| Default Python           | Python 2.7                      | Python 3.6 (python3); no `python`   |
| Init system              | systemd (same)                  | systemd (same)                      |
| NTP client               | ntpd / chrony                   | chrony only (ntpd removed)          |
| Container runtime        | Docker                          | Podman/Buildah/Skopeo               |
| Kernel                   | 3.10                            | 4.18                                |
| Storage management       | LVM + ext4/XFS                  | LVM + XFS + Stratis                 |

### Removed/Changed Packages
- `docker` — removed; use Podman
- `python` → no unversioned `python` binary; use `python3` or set `alternatives --set python /usr/bin/python3`
- `ntpd` (ntp package) — removed; chrony is the only NTP implementation
- `ifconfig`, `netstat` — deprecated; use `ip` and `ss`
- `iptables` — superseded by nftables; `iptables-legacy` available for transition

### Leapp Upgrade Tool (RHEL 7 → 8)
```bash
# On RHEL 7 system — install Leapp
subscription-manager repos --enable rhel-7-server-extras-rpms
yum install leapp leapp-repository

# Run pre-upgrade assessment (read-only analysis)
leapp preupgrade

# Review the report
cat /var/log/leapp/leapp-report.txt

# Address all inhibitors before proceeding

# Execute the upgrade (offline reboot-based)
leapp upgrade
reboot

# Post-upgrade: verify and clean up
cat /var/log/leapp/leapp-report.txt
rpm -qa | grep el7   # check for leftover RHEL 7 packages
```

### Pre-Upgrade Assessment Checklist
- Subscription active and attached to RHEL 8 content
- No third-party kernel modules without RHEL 8 equivalents
- No deprecated network script dependencies (verify via leapp preupgrade report)
- Python 2 scripts identified and flagged for rewriting
- Custom iptables rules documented for migration to nftables/firewalld
- VDO volumes noted (VDO moved to device-mapper-vdo in RHEL 8)

---

## 11. Bash Diagnostic Scripts

### Script 10: AppStream Status Inventory

```bash
#!/usr/bin/env bash
# ============================================================================
# RHEL 8 - AppStream Module Stream Inventory
#
# Version : 8.1.0
# Targets : RHEL 8.x
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. System and Subscription Context
#   2. Enabled Module Streams
#   3. Disabled Module Streams
#   4. Installed Module Profiles
#   5. Default Stream Summary
#   6. AppStream Repository Health
# ============================================================================
set -euo pipefail

# ── Formatting ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

section() { echo -e "\n${BOLD}${CYAN}══ $1 ══${RESET}"; }
ok()      { echo -e "  ${GREEN}[OK]${RESET}  $1"; }
warn()    { echo -e "  ${YELLOW}[WARN]${RESET} $1"; }
info()    { echo -e "  ${CYAN}[INFO]${RESET} $1"; }

# ── Guard: RHEL 8 only ───────────────────────────────────────────────────────
if [[ ! -f /etc/redhat-release ]]; then
    echo "ERROR: Not a Red Hat system." >&2; exit 1
fi
rhel_ver=$(rpm -E '%{rhel}' 2>/dev/null || echo "unknown")
if [[ "$rhel_ver" != "8" ]]; then
    warn "This script targets RHEL 8. Detected: RHEL ${rhel_ver}"
fi

echo -e "${BOLD}RHEL 8 AppStream Module Inventory${RESET}"
echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Host: $(hostname -f 2>/dev/null || hostname)"

# ── Section 1: System Context ────────────────────────────────────────────────
section "1. System and Subscription Context"
cat /etc/redhat-release 2>/dev/null || echo "  /etc/redhat-release not found"
uname -r | xargs -I{} echo "  Kernel: {}"

if command -v subscription-manager &>/dev/null; then
    sub_status=$(subscription-manager status 2>/dev/null | grep -i "overall status" || echo "  Unable to query")
    echo "  Subscription: $sub_status"
else
    warn "subscription-manager not found"
fi

# ── Section 2: Enabled Module Streams ────────────────────────────────────────
section "2. Enabled Module Streams"
enabled_modules=$(dnf module list --enabled 2>/dev/null | grep -v "^$\|^Hint\|^Name\|^Red Hat\|^Extra\|^Last\|^\-" || true)
if [[ -z "$enabled_modules" ]]; then
    info "No module streams currently enabled"
else
    echo "$enabled_modules" | while IFS= read -r line; do
        echo "  $line"
    done
fi

# ── Section 3: Disabled Module Streams ───────────────────────────────────────
section "3. Disabled Module Streams"
disabled_modules=$(dnf module list --disabled 2>/dev/null | grep -v "^$\|^Hint\|^Name\|^Red Hat\|^Extra\|^Last\|^\-" || true)
if [[ -z "$disabled_modules" ]]; then
    info "No module streams explicitly disabled"
else
    echo "$disabled_modules" | while IFS= read -r line; do
        echo "  $line"
    done
fi

# ── Section 4: Installed Module Profiles ─────────────────────────────────────
section "4. Installed Module Profiles"
installed_modules=$(dnf module list --installed 2>/dev/null | grep -v "^$\|^Hint\|^Name\|^Red Hat\|^Extra\|^Last\|^\-" || true)
if [[ -z "$installed_modules" ]]; then
    info "No module profiles currently installed"
else
    echo "$installed_modules" | while IFS= read -r line; do
        echo "  $line"
    done
fi

# ── Section 5: Key Stream Defaults Check ─────────────────────────────────────
section "5. Key Stream Status for Common Modules"
key_modules=("php" "python38" "python39" "nodejs" "ruby" "postgresql" "nginx" "perl" "maven")
for mod in "${key_modules[@]}"; do
    mod_info=$(dnf module list "$mod" 2>/dev/null | grep -v "^$\|^Hint\|^Red Hat\|^Extra\|^Last\|^\-" | tail -n +2 || true)
    if [[ -n "$mod_info" ]]; then
        active_stream=$(echo "$mod_info" | awk '$4 == "[e]" || $4 == "[i]" {print $2}' | head -1)
        default_stream=$(echo "$mod_info" | awk '$4 == "[d]" || $5 == "[d]" {print $2}' | head -1)
        if [[ -n "$active_stream" ]]; then
            ok "$mod — active stream: $active_stream"
        elif [[ -n "$default_stream" ]]; then
            info "$mod — default stream: $default_stream (not enabled)"
        else
            info "$mod — available (no default stream set)"
        fi
    else
        info "$mod — not found in enabled repositories"
    fi
done

# ── Section 6: AppStream Repository Health ───────────────────────────────────
section "6. AppStream Repository Health"
repo_list=$(dnf repolist 2>/dev/null || true)
if echo "$repo_list" | grep -qi "appstream"; then
    ok "AppStream repository is enabled"
    echo "$repo_list" | grep -i "appstream" | while IFS= read -r line; do
        echo "  $line"
    done
else
    warn "AppStream repository not found in enabled repos"
fi

if echo "$repo_list" | grep -qi "baseos"; then
    ok "BaseOS repository is enabled"
else
    warn "BaseOS repository not found in enabled repos"
fi

# Module metadata directory
if [[ -d /etc/dnf/modules.d ]]; then
    mod_files=$(ls /etc/dnf/modules.d/*.module 2>/dev/null | wc -l || echo 0)
    info "Module configuration files in /etc/dnf/modules.d/: $mod_files"
fi

echo -e "\n${BOLD}Inventory complete.${RESET}"
```

---

### Script 11: Migration Readiness for RHEL 9

```bash
#!/usr/bin/env bash
# ============================================================================
# RHEL 8 - Migration Readiness Assessment (RHEL 8 → RHEL 9)
#
# Version : 8.1.0
# Targets : RHEL 8.x
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Subscription and Content Access
#   2. Kernel and Hardware Compatibility
#   3. Deprecated Features in Active Use
#   4. Key Package and Service Inventory
#   5. Leapp Prerequisites
#   6. Readiness Summary
# ============================================================================
set -euo pipefail

# ── Formatting ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

section() { echo -e "\n${BOLD}${CYAN}══ $1 ══${RESET}"; }
ok()      { echo -e "  ${GREEN}[OK]${RESET}  $1"; }
warn()    { echo -e "  ${YELLOW}[WARN]${RESET} $1"; }
fail()    { echo -e "  ${RED}[FAIL]${RESET} $1"; }
info()    { echo -e "  ${CYAN}[INFO]${RESET} $1"; }

ISSUES=0
WARNINGS=0

flag_fail() { fail "$1"; ((ISSUES++)) || true; }
flag_warn() { warn "$1"; ((WARNINGS++)) || true; }

# ── Guard ────────────────────────────────────────────────────────────────────
if [[ ! -f /etc/redhat-release ]]; then
    echo "ERROR: Not a Red Hat system." >&2; exit 1
fi
rhel_ver=$(rpm -E '%{rhel}' 2>/dev/null || echo "unknown")
if [[ "$rhel_ver" != "8" ]]; then
    flag_warn "Expected RHEL 8; detected RHEL ${rhel_ver}. Results may be inaccurate."
fi

echo -e "${BOLD}RHEL 8 → RHEL 9 Migration Readiness Assessment${RESET}"
echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Host: $(hostname -f 2>/dev/null || hostname)"
echo "Release: $(cat /etc/redhat-release 2>/dev/null)"

# ── Section 1: Subscription and Content Access ───────────────────────────────
section "1. Subscription and Content Access"
if command -v subscription-manager &>/dev/null; then
    overall=$(subscription-manager status 2>/dev/null | grep -i "overall status" | awk -F: '{print $2}' | xargs || echo "unknown")
    if echo "$overall" | grep -qi "current"; then
        ok "Subscription status: $overall"
    else
        flag_fail "Subscription status: $overall — Leapp requires active subscription"
    fi

    # Check for RHEL 9 content available
    rhel9_repos=$(subscription-manager repos --list 2>/dev/null | grep -c "rhel-9" || echo 0)
    if [[ "$rhel9_repos" -gt 0 ]]; then
        ok "RHEL 9 repository entitlements found ($rhel9_repos repos available)"
    else
        flag_warn "No RHEL 9 repositories found in subscription — may need to add RHEL 9 entitlement"
    fi
else
    flag_fail "subscription-manager not found — cannot verify subscription"
fi

# ── Section 2: Kernel and Hardware Compatibility ─────────────────────────────
section "2. Kernel and Hardware Compatibility"
kernel_ver=$(uname -r)
info "Running kernel: $kernel_ver"

# Check architecture
arch=$(uname -m)
if [[ "$arch" == "x86_64" || "$arch" == "aarch64" || "$arch" == "ppc64le" || "$arch" == "s390x" ]]; then
    ok "Architecture $arch is supported for RHEL 9"
else
    flag_fail "Architecture $arch may not be supported for RHEL 9"
fi

# Check for third-party kernel modules (potential blockers)
third_party_mods=$(lsmod | awk 'NR>1 {print $1}' | while read -r mod; do
    modinfo "$mod" 2>/dev/null | grep -l "^signer" /dev/stdin &>/dev/null || \
    modinfo "$mod" 2>/dev/null | grep "^signer" | grep -v "Red Hat\|Fedora" | awk '{print mod}' mod="$mod"
done 2>/dev/null || true)
if [[ -n "$third_party_mods" ]]; then
    flag_warn "Possible third-party kernel modules detected — verify RHEL 9 compatibility:"
    echo "$third_party_mods" | while IFS= read -r m; do echo "    $m"; done
else
    ok "No obvious third-party kernel modules detected"
fi

# Minimum disk space for Leapp upgrade (~1-2 GB free in /)
root_free_kb=$(df / | awk 'NR==2 {print $4}')
root_free_gb=$(echo "scale=1; $root_free_kb / 1048576" | bc 2>/dev/null || echo "unknown")
if [[ "$root_free_kb" -gt 2097152 ]]; then
    ok "Root filesystem free space: ~${root_free_gb} GB"
else
    flag_warn "Root filesystem free space may be insufficient for upgrade: ~${root_free_gb} GB (recommend ≥ 2 GB)"
fi

# ── Section 3: Deprecated Features in Active Use ─────────────────────────────
section "3. Deprecated Features in Active Use"

# Python 2 usage
if command -v python2 &>/dev/null || rpm -q python2 &>/dev/null 2>/dev/null; then
    flag_warn "python2 is installed — RHEL 9 does not ship Python 2; scripts must be ported to Python 3"
fi

# Unversioned python
if [[ -f /usr/bin/python ]]; then
    py_target=$(readlink -f /usr/bin/python 2>/dev/null || echo "unknown")
    if echo "$py_target" | grep -q "python2"; then
        flag_fail "/usr/bin/python points to python2 — must update to python3 before upgrade"
    else
        ok "/usr/bin/python → $py_target"
    fi
else
    info "No /usr/bin/python symlink (expected on default RHEL 8)"
fi

# Network scripts (deprecated in RHEL 8, removed in RHEL 9)
if [[ -d /etc/sysconfig/network-scripts ]] && ls /etc/sysconfig/network-scripts/ifcfg-* &>/dev/null 2>/dev/null; then
    ifcfg_count=$(ls /etc/sysconfig/network-scripts/ifcfg-* 2>/dev/null | grep -v "ifcfg-lo" | wc -l)
    if [[ "$ifcfg_count" -gt 0 ]]; then
        flag_warn "$ifcfg_count ifcfg network script(s) found — NetworkManager keyfiles are preferred; ifcfg support removed in RHEL 9"
    fi
else
    ok "No legacy ifcfg network scripts found"
fi

# iptables direct usage (rules not managed by firewalld)
if command -v iptables &>/dev/null; then
    ipt_rules=$(iptables -S 2>/dev/null | grep -v "^-P" | wc -l || echo 0)
    if [[ "$ipt_rules" -gt 0 ]]; then
        flag_warn "$ipt_rules iptables rule(s) found outside firewalld — review before upgrade"
    else
        ok "No direct iptables rules detected"
    fi
fi

# ntpd check (removed in RHEL 8, should not exist, but guard for non-standard installs)
if rpm -q ntp &>/dev/null 2>/dev/null; then
    flag_warn "ntp (ntpd) package is installed — ntpd was removed in RHEL 8; ensure chrony is active"
fi

# VDO volumes (storage layout changes in RHEL 9)
if command -v vdo &>/dev/null || lsblk -t 2>/dev/null | grep -q vdo; then
    flag_warn "VDO volumes detected — verify DM-VDO compatibility in RHEL 9"
fi

# ── Section 4: Key Package and Service Inventory ─────────────────────────────
section "4. Key Package and Service Inventory"
check_pkg() {
    local pkg=$1 label=${2:-$1}
    if rpm -q "$pkg" &>/dev/null 2>/dev/null; then
        ver=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null)
        ok "$label installed: $ver"
    else
        info "$label not installed"
    fi
}
check_pkg leapp "Leapp upgrade tool"
check_pkg leapp-repository "Leapp repository"
check_pkg python3 "Python 3"
check_pkg chrony "chrony (NTP)"
check_pkg NetworkManager "NetworkManager"
check_pkg podman "Podman"
check_pkg cockpit "Cockpit"

# Active services that need migration attention
critical_services=("docker" "ntpd" "network")
for svc in "${critical_services[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        flag_warn "Service '$svc' is active — this service is deprecated/removed in RHEL 9"
    fi
done

# ── Section 5: Leapp Prerequisites ───────────────────────────────────────────
section "5. Leapp Prerequisites"

if rpm -q leapp &>/dev/null 2>/dev/null; then
    leapp_ver=$(rpm -q --queryformat '%{VERSION}' leapp 2>/dev/null)
    ok "Leapp installed: $leapp_ver"

    # Check for previous preupgrade report
    if [[ -f /var/log/leapp/leapp-report.txt ]]; then
        report_date=$(stat -c '%y' /var/log/leapp/leapp-report.txt 2>/dev/null | cut -d' ' -f1)
        inhibitors=$(grep -c "inhibitor" /var/log/leapp/leapp-report.txt 2>/dev/null || echo 0)
        info "Previous leapp preupgrade report found (dated $report_date)"
        if [[ "$inhibitors" -gt 0 ]]; then
            flag_fail "$inhibitors inhibitor(s) found in leapp report — must be resolved before upgrade"
        else
            ok "No inhibitors in last leapp report"
        fi
    else
        info "No leapp preupgrade report found — run: leapp preupgrade"
    fi
else
    flag_warn "Leapp not installed — install with: dnf install leapp leapp-repository"
    info "Enable extras repo first: subscription-manager repos --enable rhel-8-for-x86_64-appstream-rpms"
fi

# RHSM (Red Hat Subscription Manager) connectivity
if curl -s --max-time 5 https://subscription.rhsm.redhat.com/subscription &>/dev/null; then
    ok "RHSM connectivity: reachable"
else
    flag_warn "RHSM endpoint not reachable — Leapp requires network access to Red Hat CDN"
fi

# /boot space (Leapp needs space for new kernel)
boot_free_kb=$(df /boot | awk 'NR==2 {print $4}')
if [[ "$boot_free_kb" -gt 51200 ]]; then
    ok "/boot free space: $((boot_free_kb/1024)) MB"
else
    flag_fail "/boot free space too low: $((boot_free_kb/1024)) MB — Leapp needs ~50 MB minimum"
fi

# ── Section 6: Readiness Summary ─────────────────────────────────────────────
section "6. Readiness Summary"
echo ""
echo "  Issues (blockers) : $ISSUES"
echo "  Warnings          : $WARNINGS"
echo ""
if [[ "$ISSUES" -eq 0 && "$WARNINGS" -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}System appears ready for Leapp preupgrade assessment.${RESET}"
    echo "  Next step: leapp preupgrade"
elif [[ "$ISSUES" -eq 0 ]]; then
    echo -e "  ${YELLOW}${BOLD}$WARNINGS warning(s) require review before upgrade.${RESET}"
    echo "  Next step: Address warnings, then run: leapp preupgrade"
else
    echo -e "  ${RED}${BOLD}$ISSUES blocker(s) must be resolved before upgrade can proceed.${RESET}"
    echo "  Next step: Resolve all [FAIL] items, then run: leapp preupgrade"
fi
echo ""
echo "  Reference: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/upgrading_from_rhel_8_to_rhel_9"
```
