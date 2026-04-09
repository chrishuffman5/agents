# Ubuntu Editions, Variants, and Ubuntu Pro

## Overview

Ubuntu is published by Canonical in multiple editions targeting different use cases: Desktop, Server, Cloud, and Core (IoT). Each release is either an LTS (Long-Term Support) or an interim release, and many editions have "flavours" that swap the default desktop environment.

---

## 1. Ubuntu Variants

### Official Canonical Editions

| Edition | Target Use Case | Default UI | Installer | Key Packages |
|---------|----------------|------------|-----------|--------------|
| **Desktop** | Personal computing | GNOME (42+) | Ubiquity / Flutter (24.04+) | LibreOffice, Firefox (snap), Thunderbird |
| **Server** | Headless servers | None | Subiquity | OpenSSH, cloud-init, LVM by default |
| **Cloud** | AWS / Azure / GCP / OpenStack | None | cloud-init | Minimal base, cloud-guest-utils |
| **Core** | IoT / embedded | None (optional kiosk) | Snap-based provisioning | Snap-only packages |

### Ubuntu Flavours (Community-Maintained, Canonical-Endorsed)

| Flavour | Desktop Environment | Notes |
|---------|-------------------|-------|
| **Kubuntu** | KDE Plasma | Qt-based; popular on older/high-power hardware alike |
| **Xubuntu** | Xfce | Lightweight; GTK-based; good for older hardware |
| **Lubuntu** | LXQt | Lightest footprint; replaced LXDE after 18.10 |
| **Ubuntu MATE** | MATE | Continuation of GNOME 2; traditional layout |
| **Ubuntu Budgie** | Budgie | Modern, clean desktop from the Solus project |
| **Ubuntu Studio** | Xfce (since 21.10) | Low-latency kernel; audio/video production tools |
| **Ubuntu Cinnamon** | Cinnamon | Windows-like layout; official flavour since 23.04 |
| **Edubuntu** | GNOME | Education-focused; revived as official flavour in 23.04 |

> Flavours use the same base packages and release cadence as Ubuntu but maintain their own ISOs, defaults, and artwork. They receive the same security updates.

---

## 2. Ubuntu Support Lifecycle

### LTS vs Interim Releases

| Release Type | Cadence | Standard Support | Pro / ESM Support | Example |
|-------------|---------|-----------------|-------------------|---------|
| **LTS** | Every 2 years (April, even years) | 5 years | +5 years ESM (10 total) + optional 5yr Legacy | 22.04, 24.04 |
| **Interim** | Every 6 months | 9 months | No ESM extension | 23.10, 24.10 |

### Extended Support Breakdown (LTS Only)

```
Year 0-5:  Standard Security Maintenance (free, main repo only)
Year 5-10: ESM-infra via Ubuntu Pro (main repo, extended)
Year 5-10: ESM-apps via Ubuntu Pro (universe repo, 23,000+ packages)
Year 10-15: Ubuntu Pro Legacy Support (paid add-on, Canonical agreement)
```

### Point Releases and ISO Refresh

- LTS ISOs are periodically refreshed: `20.04.1`, `20.04.2`, `20.04.3`, etc.
- Point releases bundle all updates released since the prior point release.
- A new point release triggers a new downloadable ISO — the underlying version number does not change.
- Cadence: roughly every 6 months after the initial LTS release.

### Kernel Lifecycle Within LTS

| Kernel Track | Description | When to Use |
|-------------|-------------|-------------|
| **GA (General Availability)** | Kernel shipped at LTS release | Stable, tested; minimal churn |
| **HWE (Hardware Enablement)** | Rolling kernel from newer Ubuntu releases | New hardware support on older LTS |
| **Pro Real-Time** | `linux-image-realtime`; PREEMPT_RT patches | Deterministic latency; industrial/telecom |

HWE kernels follow a support cliff — each HWE kernel is supported until the next point release ships a newer HWE. The final HWE of an LTS cycle becomes the permanent HWE and has full LTS lifetime support.

---

## 3. Ubuntu Pro vs Free Tier

### Feature Comparison

| Feature | Free (Community) | Ubuntu Pro |
|---------|-----------------|-----------|
| Main repo security updates | 5 years | 10 years (ESM-infra) |
| Universe repo security updates | Best-effort | 10 years (ESM-apps, 23,000+ pkgs) |
| Kernel Livepatch | No | Yes (rebootless kernel patches) |
| FIPS 140-2/140-3 packages | No | Yes (`fips` / `fips-updates` streams) |
| CIS hardening (USG) | No | Yes |
| DISA-STIG profiles | No | Yes |
| Landscape fleet management | No | Yes |
| Real-time kernel | No | Yes |
| Support SLA | Community forums | Canonical engineering (paid tiers) |

### Pricing Model

| Tier | Cost | Machine Limit |
|------|------|---------------|
| Personal | Free | 5 machines |
| Infrastructure (self-managed) | Paid per node | Unlimited |
| Desktop (workstation) | Paid per seat | Unlimited |
| Public cloud (AWS/Azure/GCP) | Per-hour billed via marketplace | Unlimited |

### Ubuntu Pro CLI Reference

```bash
# Attach a machine to an Ubuntu Pro subscription
sudo pro attach <TOKEN>

# Show current Pro status and enabled services
pro status

# Enable a specific Pro service
sudo pro enable esm-infra
sudo pro enable esm-apps
sudo pro enable livepatch
sudo pro enable fips
sudo pro enable fips-updates
sudo pro enable usg
sudo pro enable realtime-kernel

# Disable a Pro service
sudo pro disable livepatch

# View available services
pro status --format json | jq '.services[]'
```

### ESM-Apps Coverage

Universe repo contains packages not maintained by Canonical in the free tier. With Pro ESM-apps:
- Over 23,000 packages receive CVE patching
- Includes popular OSS: Ansible, Redis, RabbitMQ, Nginx, many Python/Ruby/Node packages
- Coverage tracked at `ubuntu.com/security/esm`

### Kernel Livepatch

- Service: `canonical-livepatch`
- Patches running kernel in memory without reboot
- Only covers high/critical CVEs in the kernel
- Enabled via `pro enable livepatch`
- Check status: `canonical-livepatch status --verbose`

### FIPS Compliance

- `fips` stream: FIPS 140-2 certified packages (point-in-time freeze)
- `fips-updates` stream: FIPS 140-3 certified with ongoing security patches
- Enables certified OpenSSL, OpenSSH, kernel crypto modules
- Required for FedRAMP, FISMA, and DoD environments

### CIS / DISA-STIG via Ubuntu Security Guide (USG)

```bash
# Install USG
sudo apt install usg

# Apply CIS Level 1 hardening
sudo usg fix cis_level1_server

# Apply DISA-STIG profile
sudo usg fix disa_stig

# Audit compliance
sudo usg audit cis_level1_server
```

---

## 4. Desktop vs Server Differences

### Key Differences

| Aspect | Desktop | Server |
|--------|---------|--------|
| Installer | Ubiquity (legacy) / Flutter (24.04+) | Subiquity (curtin backend) |
| Default GUI | GNOME Shell | None |
| Init system | systemd | systemd |
| Firewall (UFW) | Available, not enabled by default | Available, not enabled by default |
| cloud-init | Not included | Included by default |
| SSH server | Not installed | OpenSSH installed and enabled |
| Default storage | Ext4, single partition | LVM with encrypted option in Subiquity |
| Snap packages | Firefox, Thunderbird, GNOME apps | Minimal snaps |
| Default apps | LibreOffice, GIMP (flavour-dep.) | None |
| Target audience | End users, developers | Sysadmins, cloud workloads |

### Installer Notes

- **Subiquity** (Server): Supports autoinstall via YAML (`autoinstall:` key in cloud-init), enabling fully unattended provisioning.
- **Flutter installer** (Desktop, 24.04+): Replaces the aging Ubiquity (GTK) installer; supports minimal install and third-party codec selection.

---

## 5. Cloud Images

### Image Types

| Image Type | Description | Format |
|-----------|-------------|--------|
| **Minimal** | Stripped-down base; cloud-init included | qcow2, vmdk, vhd |
| **OVA** | For VMware/VirtualBox import | .ova |
| **AWS AMI** | EC2 optimized; ena network, nvme storage | AMI |
| **Azure VHD** | Azure-optimized; Hyper-V Gen 1/Gen 2 | VHD/VHDX |
| **GCP Image** | GCP-optimized | GCE image |
| **Daily Builds** | Untested, latest trunk | All formats |

### cloud-init Basics

```bash
# Check cloud-init status
cloud-init status --wait

# View merged cloud-init config
cloud-init query --all

# Re-run cloud-init (for testing)
sudo cloud-init clean --logs
sudo cloud-init init
```

### Ubuntu Pro on Cloud Marketplaces

- **AWS**: Ubuntu Pro AMIs available in EC2 Marketplace; billing through AWS account
- **Azure**: Ubuntu Pro VMs available in Azure Marketplace; billing through Azure account
- **GCP**: Ubuntu Pro images available in Google Cloud Marketplace
- Cloud Pro instances do not require `pro attach` — entitlements activate automatically via IMDS

### Image Feeds

| Source | URL Pattern |
|--------|------------|
| Official cloud images | `cloud-images.ubuntu.com` |
| AWS AMI finder | `ubuntu.com/aws/finder` |
| Daily images | `cloud-images.ubuntu.com/daily` |
| Release images | `cloud-images.ubuntu.com/releases` |

---

## 6. Ubuntu Core (IoT)

### Architecture

Ubuntu Core is a minimal, snap-only OS designed for IoT and embedded devices. The entire system is composed of snaps, making it fully transactional and atomic.

| Component | Snap Role | Description |
|-----------|-----------|-------------|
| **Core snap** | base | Minimal Ubuntu runtime (libc, etc.) |
| **Kernel snap** | kernel | Kernel + initrd; device-specific |
| **Gadget snap** | gadget | Boot assets, partition layout, device config |
| **App snaps** | app | All user-facing applications |

### Release Versions

| UC Version | Base | Ubuntu Base | Notes |
|-----------|------|------------|-------|
| UC20 | core20 | Ubuntu 20.04 | Secure boot support introduced |
| UC22 | core22 | Ubuntu 22.04 | Full disk encryption (FDE) improvements |
| UC24 | core24 | Ubuntu 24.04 | Latest; improved factory reset |

### Key Features

- **Transactional updates**: Snaps update atomically; automatic rollback on failure
- **Secure Boot**: Measured boot chain from firmware to application
- **Brand stores**: Enterprise operators can run private snap stores
- **Recovery mode**: Factory reset and recovery partition built-in
- **Over-the-air (OTA) updates**: Managed via Snap Store or brand store

### Ubuntu Core Commands

```bash
# List installed snaps (kernel, gadget, base, apps)
snap list

# Show system information
snap version
snap debug state /var/lib/snapd/state.json

# Update all snaps
sudo snap refresh

# Revert a snap update
sudo snap revert <snap-name>
```

---

## 7. Identification and Diagnostic Commands

### System Identification

```bash
# Full release information
lsb_release -a

# OS release details (machine-readable)
cat /etc/os-release

# Kernel version
uname -r

# Check HWE vs GA kernel
apt-cache policy linux-image-generic linux-image-generic-hwe-22.04
```

### Ubuntu Pro Status

```bash
# Overall Pro status
pro status

# JSON output for scripting
pro status --format json

# Check specific service
pro status | grep livepatch

# Version of pro client
pro --version
```

### Package and Snap Inventory

```bash
# List all installed apt packages
apt list --installed 2>/dev/null

# List installed packages (dpkg format)
dpkg --list

# List installed snaps
snap list

# Check ESM-specific packages
apt-cache policy <package> | grep -i esm
```

### Distribution Information

```bash
# List all Ubuntu releases and support dates
ubuntu-distro-info --all --supported

# Check current release LTS status
ubuntu-distro-info --lts

# Days until EOL
ubuntu-distro-info --series=$(lsb_release -cs) --eol -d
```

---

## 8. Edition Selection Guide

| Scenario | Recommended Edition |
|---------|-------------------|
| Home desktop / workstation | Ubuntu Desktop (or a flavour matching hardware) |
| Web/app server | Ubuntu Server LTS |
| Kubernetes node | Ubuntu Server LTS + HWE kernel |
| Public cloud VM | Ubuntu Cloud Image (or Ubuntu Pro for compliance) |
| IoT device / kiosk | Ubuntu Core |
| Low-latency workload (telecom, industrial) | Ubuntu Server + Pro Real-Time kernel |
| FIPS/FedRAMP environment | Ubuntu Server + Ubuntu Pro (fips-updates stream) |
| Long-running legacy app (10+ yr) | Ubuntu Server LTS + Pro ESM |
| Creative / media production | Ubuntu Studio |
| Education lab | Edubuntu |

---

## 9. Release Calendar Reference

| Release | Version | Type | EOL (Free) | EOL (Pro ESM) |
|---------|---------|------|-----------|--------------|
| Focal Fossa | 20.04 | LTS | Apr 2025 | Apr 2030 |
| Hirsute Hippo | 21.04 | Interim | Jan 2022 | N/A |
| Impish Indri | 21.10 | Interim | Jul 2022 | N/A |
| Jammy Jellyfish | 22.04 | LTS | Apr 2027 | Apr 2032 |
| Kinetic Kudu | 22.10 | Interim | Jul 2023 | N/A |
| Lunar Lobster | 23.04 | Interim | Jan 2024 | N/A |
| Mantic Minotaur | 23.10 | Interim | Jul 2024 | N/A |
| Noble Numbat | 24.04 | LTS | Apr 2029 | Apr 2034 |
| Oracular Oriole | 24.10 | Interim | Jul 2025 | N/A |
| Plucky Puffin | 25.04 | Interim | Jan 2026 | N/A |

---

## 10. Key Repositories and Components

### Repository Structure (LTS Example: 22.04)

| Repo Component | Description | Pro Required? |
|---------------|-------------|--------------|
| `main` | Canonical-supported; free 5yr | No |
| `restricted` | Proprietary drivers (Broadcom, NVIDIA) | No |
| `universe` | Community-maintained OSS | No (updates only) |
| `multiverse` | Non-free; use-restricted software | No |
| `esm-infra` | Extended `main` coverage | Yes (Pro) |
| `esm-apps` | Extended `universe` coverage | Yes (Pro) |
| `fips` | FIPS 140-2 certified packages | Yes (Pro) |
| `fips-updates` | FIPS 140-3 with security patches | Yes (Pro) |
| `realtime` | Real-time kernel packages | Yes (Pro) |
