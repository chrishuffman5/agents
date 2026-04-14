# Ubuntu Editions, Variants, and Ubuntu Pro

> Edition selection, lifecycle, Desktop vs Server differences, cloud images, Ubuntu Core,
> and Ubuntu Pro feature comparison.

---

## 1. Ubuntu Variants

### Official Canonical Editions

| Edition | Target | Default UI | Installer | Key Packages |
|---------|--------|-----------|-----------|--------------|
| **Desktop** | Personal computing | GNOME | Ubiquity / Flutter (24.04+) | LibreOffice, Firefox (snap) |
| **Server** | Headless servers | None | Subiquity | OpenSSH, cloud-init, LVM |
| **Cloud** | AWS / Azure / GCP | None | cloud-init | Minimal base, cloud-guest-utils |
| **Core** | IoT / embedded | None | Snap-based provisioning | Snap-only packages |

### Ubuntu Flavours (Community-Maintained)

| Flavour | Desktop | Notes |
|---------|---------|-------|
| **Kubuntu** | KDE Plasma | Qt-based |
| **Xubuntu** | Xfce | Lightweight; good for older hardware |
| **Lubuntu** | LXQt | Lightest footprint |
| **Ubuntu MATE** | MATE | Traditional GNOME 2 layout |
| **Ubuntu Budgie** | Budgie | Modern, clean desktop |
| **Ubuntu Studio** | Xfce | Low-latency kernel; media production |
| **Ubuntu Cinnamon** | Cinnamon | Windows-like layout; official since 23.04 |
| **Edubuntu** | GNOME | Education-focused; revived in 23.04 |

Flavours share the same base packages, release cadence, and security updates.

---

## 2. Ubuntu Support Lifecycle

### LTS vs Interim

| Release Type | Cadence | Standard Support | Pro / ESM |
|-------------|---------|-----------------|-----------|
| **LTS** | Every 2 years (April) | 5 years | +5 years ESM (10 total) |
| **Interim** | Every 6 months | 9 months | No ESM |

### Extended Support Breakdown (LTS)

```
Year 0-5:   Standard Security Maintenance (free, main repo)
Year 5-10:  ESM-infra via Ubuntu Pro (main, extended)
Year 5-10:  ESM-apps via Ubuntu Pro (universe, 23,000+ packages)
Year 10-15: Ubuntu Pro Legacy Support (paid add-on)
```

### Kernel Tracks

| Track | Description | When to Use |
|-------|-------------|-------------|
| **GA** | Kernel shipped at LTS release | Stable, minimal churn |
| **HWE** | Rolling kernel from newer releases | New hardware support |
| **Pro Real-Time** | PREEMPT_RT patches | Deterministic latency |

---

## 3. Ubuntu Pro vs Free Tier

| Feature | Free | Ubuntu Pro |
|---------|------|-----------|
| Main repo security updates | 5 years | 10 years (ESM-infra) |
| Universe security updates | Best-effort | 10 years (ESM-apps) |
| Kernel Livepatch | No | Yes |
| FIPS 140-2/140-3 | No | Yes |
| CIS hardening (USG) | No | Yes |
| DISA-STIG profiles | No | Yes |
| Landscape fleet management | No | Yes |
| Real-time kernel | No | Yes |
| Support SLA | Community forums | Canonical engineering |

### Pricing

| Tier | Cost | Limit |
|------|------|-------|
| Personal | Free | 5 machines |
| Infrastructure | Paid per node | Unlimited |
| Desktop | Paid per seat | Unlimited |
| Public cloud | Per-hour via marketplace | Unlimited |

### Ubuntu Pro CLI

```bash
sudo pro attach <TOKEN>
pro status
sudo pro enable esm-infra esm-apps livepatch
sudo pro disable livepatch
pro status --format json | jq '.services[]'
```

---

## 4. Desktop vs Server

| Aspect | Desktop | Server |
|--------|---------|--------|
| Installer | Ubiquity / Flutter (24.04+) | Subiquity |
| Default GUI | GNOME Shell | None |
| Firewall (UFW) | Available, not enabled | Available, not enabled |
| cloud-init | Not included | Included |
| SSH server | Not installed | OpenSSH enabled |
| Default storage | ext4, single partition | LVM with encryption option |
| Target | End users, developers | Sysadmins, cloud workloads |

---

## 5. Cloud Images

### Image Types

| Type | Description | Format |
|------|-------------|--------|
| Minimal | Stripped-down; cloud-init | qcow2, vmdk, vhd |
| AWS AMI | EC2 optimized | AMI |
| Azure VHD | Azure optimized | VHD/VHDX |
| GCP Image | GCP optimized | GCE image |

### Ubuntu Pro on Cloud

Cloud Pro instances auto-activate via IMDS -- no `pro attach` required.

| Source | URL |
|--------|-----|
| Official images | cloud-images.ubuntu.com |
| AWS finder | ubuntu.com/aws/finder |
| Daily images | cloud-images.ubuntu.com/daily |

---

## 6. Ubuntu Core (IoT)

### Architecture

Snap-only OS for IoT/embedded. Fully transactional and atomic.

| Component | Role |
|-----------|------|
| Core snap | Minimal Ubuntu runtime |
| Kernel snap | Kernel + initrd |
| Gadget snap | Boot assets, partition layout |
| App snaps | All user applications |

Features: transactional updates, Secure Boot, brand stores, factory reset, OTA updates.

---

## 7. Identification Commands

```bash
lsb_release -a                         # full release info
cat /etc/os-release                    # machine-readable
uname -r                              # kernel version
apt-cache policy linux-image-generic   # GA vs HWE
pro status                             # Pro subscription
snap list                              # installed snaps
ubuntu-distro-info --all --supported   # release dates
```

---

## 8. Edition Selection Guide

| Scenario | Recommended |
|---------|-------------|
| Home desktop | Ubuntu Desktop (or flavour) |
| Web/app server | Ubuntu Server LTS |
| Kubernetes node | Ubuntu Server LTS + HWE kernel |
| Public cloud VM | Ubuntu Cloud Image (Pro for compliance) |
| IoT device | Ubuntu Core |
| Low-latency (telecom) | Server + Pro Real-Time kernel |
| FIPS/FedRAMP | Server + Pro fips-updates |
| Long-running legacy (10+ yr) | Server LTS + Pro ESM |
| Media production | Ubuntu Studio |
| Education lab | Edubuntu |

---

## 9. Release Calendar

| Release | Version | Type | EOL (Free) | EOL (Pro) |
|---------|---------|------|-----------|----------|
| Focal Fossa | 20.04 | LTS | Apr 2025 | Apr 2030 |
| Jammy Jellyfish | 22.04 | LTS | Apr 2027 | Apr 2032 |
| Noble Numbat | 24.04 | LTS | Apr 2029 | Apr 2034 |
| Resolute Raccoon | 26.04 | LTS | Apr 2031 | Apr 2036 |

---

## 10. Repository Structure

| Component | Description | Pro Required? |
|-----------|-------------|--------------|
| main | Canonical-supported free | No |
| restricted | Proprietary drivers | No |
| universe | Community OSS | No |
| multiverse | Non-free software | No |
| esm-infra | Extended main | Yes |
| esm-apps | Extended universe | Yes |
| fips | FIPS certified | Yes |
| fips-updates | FIPS + security | Yes |
| realtime | RT kernel | Yes |
