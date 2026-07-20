# Rocky Linux / AlmaLinux Architecture Reference

## RHEL Rebuild Process

### Source Acquisition (Post-June 2023)

Red Hat restricted public RHEL source code access in June 2023. Both projects adapted:

**Rocky Linux:**
- UBI container images (publicly available, RHEL-based)
- Public cloud RHEL instances (pay-per-use, legal access to SRPMs)
- CentOS Stream as supplementary upstream signal
- Tool: `srpmproc` (github.com/rocky-linux/srpmproc) -- auto-imports and debrands

**AlmaLinux:**
- Similar channels (UBI, cloud instances)
- CentOS Stream as forward-looking indicator for RHEL package timing
- Community partnerships for additional source verification

### Build Systems

| Attribute | Rocky Linux | AlmaLinux |
|---|---|---|
| Build system | Peridot (open-source, RESF) | ALBS (AlmaLinux Build System) |
| Architecture | Kubernetes/Helm cloud-native | Distributed build nodes |
| Release lag | Within one week of RHEL | Within one business day of RHEL |
| Architectures | x86_64, aarch64, ppc64le, s390x | x86_64, aarch64, ppc64le, s390x |

### Binary Clone vs ABI Compatible

**Rocky Linux -- Binary Clone (1:1)**
- Byte-for-byte drop-in replacement for RHEL
- Bug-for-bug compatibility
- No fixes outside RHEL's release cycle
- Ideal for ISV certification and regulatory compliance

**AlmaLinux -- ABI Compatible**
- Applications built for RHEL run without recompilation
- May fix bugs independently
- Can ship security patches ahead of RHEL
- Greater flexibility; potential edge-case divergence

## Governance

### Rocky Linux -- RESF

- Rocky Enterprise Software Foundation (RESF), a Public Benefit Corporation
- Founder: Gregory Kurtzer (co-founder of CentOS)
- Commercial backer: CIQ ($26M invested)
- HPC focus: NVIDIA GPU integration, RLC-AI images

### AlmaLinux -- AlmaLinux OS Foundation

- 501(c)(6) nonprofit foundation
- Primary backer: CloudLinux Inc. ($1M/year, no ownership stake)
- Community-governed board; no single company controls decisions
- Web hosting focus: cPanel/Plesk compatibility priority

## Key Differences from RHEL

### What RHEL Has That Rocky/Alma Do Not

| Feature | RHEL | Rocky / Alma |
|---|---|---|
| Subscription Manager | Required | Not present |
| Red Hat CDN | cdn.redhat.com | Community mirrors |
| Red Hat Insights | Pre-installed | Not available |
| Red Hat Satellite | Lifecycle management | Not supported |
| Official SLA | 1/2/4-hour options | Community support only |
| Certified hardware | Red Hat Catalog | No formal certification |
| Live patching service | kpatch subscription | kpatch works; no managed service |

### What Rocky/Alma Have That RHEL Does Not

- Free repos -- no subscription key; `dnf update` works immediately
- Easy EPEL enablement without subscription workarounds
- SIG packages beyond RHEL's scope
- Community forums and IRC without portal requirements

### Release File Differences

```bash
# Rocky Linux
/etc/rocky-release         # "Rocky Linux release 9.x (Blue Onyx)"
/etc/redhat-release        # Symlink -> rocky-release
/etc/os-release            # ID=rocky, ID_LIKE="rhel centos fedora"

# AlmaLinux
/etc/almalinux-release     # "AlmaLinux release 9.x (Seafoam Ocelot)"
/etc/redhat-release        # Symlink -> almalinux-release
/etc/os-release            # ID=almalinux, ID_LIKE="rhel centos fedora"
```

## Rocky vs Alma Comparison

| Attribute | Rocky Linux | AlmaLinux |
|---|---|---|
| Compatibility model | Binary clone (1:1) | ABI compatible |
| Bug philosophy | Reproduce RHEL bugs | Fix bugs independently |
| Security patches | Follow RHEL release | May ship ahead of RHEL |
| x86_64 baseline (v10) | x86_64-v3 only | x86_64-v3 default + v2 build |
| cPanel support (v134+) | Dropped | Officially supported |
| HPC/AI ecosystem | CIQ, NVIDIA GPU images | Standard |
| Extra repo | Plus and Devel repos | Synergy repo |
| RISC-V support (v10) | Yes | Not in initial v10 |
| Foundation type | PBC | 501(c)(6) nonprofit |
| Commercial backer | CIQ ($26M) | CloudLinux ($1M/yr) |

## Secure Boot

Both maintain independent Microsoft-signed shims:

- **Rocky:** Own shim for x86_64 and aarch64; certificate refresh April 2024
- **AlmaLinux:** Own CA certificates and shim; ARM64 key rotated 2026

GPG key locations:
- Rocky: `/etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial`
- AlmaLinux: `/etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9` (version-specific)

## Repository Structure

| Repo | Purpose | Default |
|---|---|---|
| `baseos` | Core OS packages | Enabled |
| `appstream` | Application streams | Enabled |
| `extras` | Distro-specific packages | Enabled |
| `plus` | Rocky: rebuilt packages with extras | Disabled |
| `crb` | Code Ready Builder (PowerTools in EL8) | Disabled |
| `devel` | Rocky: development tools | Disabled |
| `synergy` | AlmaLinux: community pre-EPEL | Disabled |

### EPEL and CRB

```bash
# Enable CRB (required before EPEL on EL9+)
dnf config-manager --set-enabled crb
dnf install -y epel-release
```

### ELRepo

```bash
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
dnf install -y https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm
dnf --enablerepo=elrepo-kernel install -y kernel-ml
```
