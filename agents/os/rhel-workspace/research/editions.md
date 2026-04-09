# RHEL Editions, Subscriptions, and Variants — Research Reference

## 1. Subscription Tiers

Red Hat offers three primary subscription tiers for RHEL. Pricing is per-system per-year and varies by physical/virtual socket count and market segment (public sector, OEM, resellers).

| Feature | Self-Support | Standard | Premium |
|---|---|---|---|
| Red Hat Customer Portal | Yes | Yes | Yes |
| Knowledge Base & Documentation | Yes | Yes | Yes |
| Software Downloads & Updates | Yes | Yes | Yes |
| Errata & Security Advisories | Yes | Yes | Yes |
| Phone / Web Case Support | No | Business hours | 24x7 |
| Support SLA — Urgent (Sev 1) | None | Next business day | 1 hour |
| Support SLA — High (Sev 2) | None | 2 business days | 4 business hours |
| Support SLA — Normal (Sev 3) | None | 5 business days | Next business day |
| Number of Cases | Unlimited (self-serve) | Unlimited | Unlimited |
| Approximate Price (1 socket pair/yr) | ~$179 | ~$349–$799 | ~$1,299–$2,500 |

**Self-Support** is intended for dev/test or low-priority workloads where team has internal expertise. No Red Hat engineer contact; portal and KB access only.

**Standard** covers normal business-hours support (Monday–Friday). Suitable for non-critical production workloads that can tolerate next-business-day response.

**Premium** provides round-the-clock support with strict SLAs. Required for mission-critical production systems where downtime has significant business impact.

---

## 2. Product Variants

RHEL ships as a base platform plus purpose-optimized variants. Most variants are the same RPM tree with different default package sets, tuning profiles, or certification requirements.

| Variant | Primary Use Case | Key Differentiators |
|---|---|---|
| RHEL Server | General-purpose server workloads | Baseline variant; broadest hardware cert |
| RHEL Workstation | Developer / CAD / graphics workstations | X11/Wayland desktop, OpenGL, 3D drivers |
| RHEL for SAP Solutions | SAP NetWeaver & S/4HANA | E4S lifecycle, RHEL_SAP repo, HANA-optimized kernel tunables |
| RHEL for SAP HANA | In-memory SAP HANA databases | Huge-page pre-configuration, certified memory configs |
| RHEL for Edge | IoT and edge computing | rpm-ostree (image-based updates), minimal footprint, Zero Touch Provisioning |
| RHEL for HPC | High-performance computing clusters | MPI tuning, Mellanox/InfiniBand support, cluster-optimized scheduler |
| RHEL for ARM (aarch64) | ARM64 cloud/edge workloads | AArch64 architecture, Graviton/Ampere certified |
| RHEL for IBM Z (s390x) | IBM Z mainframe | s390x architecture, z15+ certified, FIPS by default |
| RHEL for IBM Power (ppc64le) | IBM Power Systems | POWER9/POWER10, IBM PowerVM LPAR support |

**RHEL for Edge** uses `rpm-ostree` as its package manager instead of `dnf`, making the OS image-based and atomic. Updates are applied as whole-image transactions.

---

## 3. Add-Ons

Add-ons are separately entitled content sets that extend RHEL capabilities. They appear as separate subscriptions in the Customer Portal and as additional repositories.

| Add-On | Repo / Package | Purpose |
|---|---|---|
| High Availability (HA) | `rhel-ha-for-rhel-*-server-rpms` | Pacemaker + Corosync cluster stack, `fence-agents`, `resource-agents` |
| Resilient Storage | `rhel-rs-for-rhel-*-server-rpms` | GFS2 shared filesystem, Cluster LVM (clvmd), DLM |
| Smart Management | Satellite RPMs + manifest | On-premises content management, patch orchestration, provisioning |
| Extended Life Cycle Support (ELS) | Separate ELS repo | Extends security patches 1–3 years beyond EOM for end-of-life minors |
| Extended Update Support (EUS) | `rhel-*-eus-*` repos | Locks a minor release (e.g., 9.2) to receive z-stream backports for 24 months |
| Update Services for SAP Solutions (E4S) | `rhel-*-e4s-*` repos | EUS + HA + SAP repos bundled; up to 48-month minor version stability for SAP |

**High Availability vs Resilient Storage:** HA provides the cluster framework (resource management, fencing). Resilient Storage adds shared-disk filesystems that require a running cluster. Both are often deployed together.

**EUS vs E4S:** EUS applies to any RHEL workload; E4S is specifically for SAP and includes additional SAP-certified update streams. E4S extends the support window further (up to 4 years per minor).

---

## 4. Developer Program

### Individual Developer Subscription (No-Cost)
- Provides up to **16 systems** registered under a single Red Hat account
- Full access to RHEL content (all repos, errata, security updates)
- Access to Red Hat Customer Portal and documentation
- **No production SLA** — self-support only
- Requires annual renewal (free) at developers.redhat.com
- Includes access to many other Red Hat products (OpenShift Local, Quarkus, etc.)

### RHEL for Business Developers (Paid tier)
- Supports up to **25 registered instances**
- Intended for small teams or internal developer environments
- Includes Standard-tier support
- Access to full RHEL portfolio including beta channels

### Registration Process
```bash
# Register system with developer account
subscription-manager register --username=<rhn_username> --password=<password>

# With activation key (preferred for automation)
subscription-manager register --org=<org_id> --activationkey=<key_name>

# Attach subscription (classic entitlement mode, pre-SCA)
subscription-manager attach --auto

# Verify
subscription-manager status
```

### What Is Not Included
- No guaranteed response times or phone support
- No eligibility for production deployment under Red Hat's terms of service
- No access to RHEL for SAP or specialized hardware variants under developer terms

---

## 5. Simple Content Access (SCA)

Simple Content Access (SCA) removes the requirement to attach specific subscription certificates to individual systems. Enabled at the organization level in the Customer Portal.

### Key Changes Under SCA

| Aspect | Classic (Certificate) Mode | SCA Mode |
|---|---|---|
| Subscription attachment | Required per-system via `--auto` or `--pool` | Not required |
| Repo access | Gated by attached subscription certs | All purchased content available org-wide |
| Compliance reporting | Per-system subscription compliance tracked | Compliance tracked at org/account level |
| `subscription-manager attach` | Required | No-op (ignored) |
| Activation keys | Can specify pools | Specify repos/content; no pool attachment |

### SCA Behavior with subscription-manager
```bash
# SCA-enabled systems show this status:
subscription-manager status
# Overall Status: Disabled
# Reason: Simple Content Access is enabled...

# Repositories are managed directly
subscription-manager repos --list
subscription-manager repos --enable=rhel-9-for-x86_64-baseos-rpms

# Organization SCA status
subscription-manager identity
```

### Satellite and SCA
When using Red Hat Satellite, SCA must also be enabled in the Satellite manifest. Content Views and Lifecycle Environments continue to work as normal; subscription filtering within Satellite is replaced by content access controls.

---

## 6. RHEL Lifecycle

### Phase Definitions

| Phase | Duration | What's Provided |
|---|---|---|
| Full Support | Years 1–5 from GA | New features, hardware enablement, security patches, bug fixes |
| Maintenance Support 1 | Years 6–7 | Critical/Important security fixes, selected urgent bug fixes |
| Maintenance Support 2 | Years 8–10 | Critical security fixes only (CVE rated Critical) |
| Extended Life Cycle Support (ELS) | Up to 3 years beyond EOM (add-on) | Selected Critical security patches only; limited scope |

**RHEL major versions** (e.g., RHEL 8, RHEL 9) receive a **10-year standard lifecycle**.

### Minor Version and EUS

- Minor versions release approximately every 6 months (e.g., 9.0 → 9.2 → 9.4)
- **Without EUS:** `dnf update` tracks the latest minor version (rolling within major)
- **With EUS:** System pinned to a specific minor (e.g., 9.2) for up to 24 months, receiving only z-stream backport patches

```bash
# Pin to EUS stream (example for 9.2)
subscription-manager repos --disable=rhel-9-for-x86_64-baseos-rpms
subscription-manager repos --enable=rhel-9-2-eus-for-x86_64-baseos-rpms
```

### E4S Lifecycle for SAP
- Supported minors: typically every other minor release
- Support window per minor: up to 48 months (4 years)
- Includes: RHEL BaseOS + AppStream + SAP repos + HA add-on repos

### Version Numbering
```
RHEL 9.4.0-1 (kernel: 5.14.0-427.el9.x86_64)
      ^ ^         ^ Major kernel version
      | Minor release
      Major release
```

---

## 7. Content Delivery

### CDN (Direct from Red Hat)

| Repository | Content |
|---|---|
| BaseOS | Core OS packages (RPMs in traditional format) |
| AppStream | Application streams (modules + RPMs), replaces SCL |
| CodeReady Builder (CRB) | Developer tools, build dependencies; not supported for production |
| Supplementary | Proprietary/third-party components (e.g., IBM Java) |
| HA, RS | High Availability and Resilient Storage packages |
| SAP | SAP-specific patches and tools |

### Red Hat Satellite (On-Premises CDN Mirror)

Satellite provides:
- **Content Views** — snapshots of repos at a point in time, allowing staged promotion
- **Lifecycle Environments** — Dev → QA → Prod promotion pipeline
- **Activation Keys** — bind a system to an org, lifecycle env, content view, and host group at registration
- **Synchronization Scheduling** — control when CDN content is mirrored locally

```bash
# Register to Satellite
subscription-manager register \
  --org="MyOrg" \
  --activationkey="rhel9-prod-key" \
  --serverurl=https://satellite.example.com/rhsm

# Verify content source
subscription-manager config | grep hostname
```

### Repository Management Commands
```bash
dnf repolist                          # List enabled repos
subscription-manager repos --list-enabled
subscription-manager repos --enable=codeready-builder-for-rhel-9-x86_64-rpms
dnf module list                       # List AppStream modules
dnf module enable php:8.2             # Enable specific stream
```

---

## 8. Convert2RHEL

Convert2RHEL is a Red Hat-supported tool for converting EL-compatible distributions to genuine RHEL subscriptions in-place, without reinstallation.

### Supported Source Distributions

| Source OS | Supported Versions | Notes |
|---|---|---|
| CentOS Linux | 7, 8 | CentOS 8 EOL means convert to RHEL 8 then EUS |
| CentOS Stream | 8, 9 | Stream is upstream; conversion supported |
| Oracle Linux | 7, 8 | OL-specific packages replaced |
| Rocky Linux | 8, 9 | Community build; fully convertible |
| AlmaLinux | 8, 9 | Community build; fully convertible |

### Conversion Process Overview
```bash
# 1. Install convert2rhel (available from Red Hat CDN or EPEL)
curl -o /etc/yum.repos.d/convert2rhel.repo \
  https://ftp.redhat.com/redhat/convert2rhel/8/convert2rhel.repo
dnf install convert2rhel

# 2. Run pre-conversion analysis
convert2rhel analyze --username=<rhn_user> --password=<password>

# 3. Execute conversion
convert2rhel --username=<rhn_user> --password=<password>

# 4. Reboot into RHEL kernel
reboot
```

### What Changes
- Kernel replaced with Red Hat-signed kernel
- All OS packages replaced with Red Hat RPMs
- Package signing keys updated to Red Hat GPG keys
- `redhat-release` package installed; source OS release package removed
- System registered with subscription-manager

### What Stays the Same
- Filesystem layout, data, user accounts, services
- Application packages (not provided by the OS)
- Network configuration
- Boot loader configuration (updated for RHEL kernel)

---

## 9. RHEL Image Builder

Image Builder creates customized RHEL images for various deployment targets without requiring manual OS installation.

### Interfaces
- **Composer CLI** (`composer-cli`) — command-line interface to `osbuild-composer` service
- **Cockpit Plugin** (`cockpit-composer`) — web UI via Cockpit on port 9090
- **API** — REST API at `/api/composer/v1` (used by both interfaces)

### Supported Output Formats

| Format | Use Case |
|---|---|
| `qcow2` | KVM/QEMU virtual machines, OpenStack |
| `vmdk` | VMware vSphere / ESXi |
| `ami` | AWS EC2 (uploaded directly via `--upload` or manually) |
| `iso` / `live-iso` | Bootable ISO for bare metal or DVD |
| `raw` | Generic raw disk image |
| `vhd` | Microsoft Azure, Hyper-V |
| `gce` | Google Compute Engine |
| `tar` | Generic container or archive |
| `container` | OCI container image |
| `edge-commit` | OSTree commit for RHEL for Edge |
| `edge-installer` | Bootable edge installer ISO |

### Blueprint Format (TOML)
```toml
name = "my-custom-rhel9"
description = "Custom RHEL 9 image with base tooling"
version = "1.0.0"
modules = []
groups = []

[[packages]]
name = "vim-enhanced"
version = "*"

[[packages]]
name = "bash-completion"
version = "*"

[customizations]
hostname = "custom-host"

[customizations.kernel]
append = "net.ifnames=0"

[[customizations.user]]
name = "ops"
password = "$6$..."
groups = ["wheel", "sudo"]
key = "ssh-rsa AAAA..."

[[customizations.firewall.services]]
enabled = ["ssh", "https"]
```

### Composer CLI Workflow
```bash
# Start and enable services
systemctl enable --now osbuild-composer.socket

# Push blueprint
composer-cli blueprints push my-image.toml

# List blueprints
composer-cli blueprints list

# Start a build
composer-cli compose start my-custom-rhel9 qcow2

# Check status
composer-cli compose status

# Download finished image
composer-cli compose image <UUID>
```

---

## 10. Comparison and Identification Commands

### System Identity and Registration
```bash
# Show registration status, org, and system identity UUID
subscription-manager identity

# Show overall subscription compliance
subscription-manager status

# List all consumed/attached subscriptions
subscription-manager list --consumed

# List available subscriptions (classic mode)
subscription-manager list --available
```

### OS Version Identification
```bash
# Human-readable release string
cat /etc/redhat-release
# Red Hat Enterprise Linux release 9.4 (Plow)

# RPM query for release package
rpm -q redhat-release
# redhat-release-9.4-0.5.el9.x86_64

# Structured version data (machine-parseable)
cat /etc/os-release
# NAME="Red Hat Enterprise Linux"
# VERSION="9.4 (Plow)"
# ID="rhel"
# VERSION_ID="9.4"
# PLATFORM_ID="platform:el9"

# Running kernel version
uname -r
# 5.14.0-427.13.1.el9_4.x86_64

# System architecture
uname -m
# x86_64
```

### Repository and Content Status
```bash
# List enabled repos
dnf repolist

# List all repos (enabled + disabled)
dnf repolist --all

# Check which repo a package came from
dnf info <package>

# Verify subscription-manager repo config
cat /etc/rhsm/rhsm.conf

# Check for EUS or E4S pin
subscription-manager repos --list-enabled | grep -E 'eus|e4s'
```

### Subscription Manager Quick Reference

| Command | Purpose |
|---|---|
| `subscription-manager register` | Register system to RHSM or Satellite |
| `subscription-manager unregister` | Remove system from RHSM |
| `subscription-manager refresh` | Pull latest entitlement data from server |
| `subscription-manager repos --list` | Show all available repositories |
| `subscription-manager repos --enable=<repo>` | Enable a repository |
| `subscription-manager config` | Show current rhsm configuration |
| `subscription-manager facts` | Show system facts reported to RHSM |

---

## Quick Reference: Choosing the Right Subscription

```
Is this a development/learning environment?
  → Individual Developer Subscription (free, up to 16 systems)

Is this non-critical production with internal expertise?
  → Self-Support (cheapest, portal-only)

Is this standard production requiring business-hours support?
  → Standard Subscription

Is this mission-critical requiring 24x7 rapid response?
  → Premium Subscription

Running SAP workloads requiring long-term minor version stability?
  → RHEL for SAP Solutions with E4S

Need to stay on a specific minor release for certifications?
  → Add Extended Update Support (EUS)

Near end-of-life with no migration path yet?
  → Extended Life Cycle Support (ELS) add-on
```
