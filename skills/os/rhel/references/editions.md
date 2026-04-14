# RHEL Editions, Subscriptions, and Variants

## 1. Subscription Tiers

| Feature | Self-Support | Standard | Premium |
|---------|-------------|----------|---------|
| Customer Portal / KB | Yes | Yes | Yes |
| Software Downloads / Updates | Yes | Yes | Yes |
| Phone / Web Case Support | No | Business hours | 24x7 |
| SLA -- Sev 1 (Urgent) | None | Next business day | 1 hour |
| SLA -- Sev 2 (High) | None | 2 business days | 4 hours |
| Approx. Price (1 socket pair/yr) | ~$179 | ~$349-$799 | ~$1,299-$2,500 |

**Self-Support**: dev/test or low-priority workloads with internal expertise. Portal and KB only.
**Standard**: business-hours support for non-critical production.
**Premium**: 24x7 support with strict SLAs for mission-critical systems.

---

## 2. Product Variants

| Variant | Use Case | Differentiators |
|---------|----------|-----------------|
| RHEL Server | General-purpose | Broadest hardware certification |
| RHEL Workstation | Developer / CAD / graphics | Desktop with OpenGL, 3D drivers |
| RHEL for SAP Solutions | SAP NetWeaver / S/4HANA | E4S lifecycle, HANA-optimized tunables |
| RHEL for Edge | IoT and edge computing | rpm-ostree image-based updates, minimal footprint |
| RHEL for HPC | Clusters | MPI tuning, InfiniBand support |
| RHEL for ARM (aarch64) | ARM64 cloud/edge | Graviton/Ampere certified |
| RHEL for IBM Z (s390x) | IBM Z mainframe | z15+ certified |
| RHEL for IBM Power (ppc64le) | IBM Power Systems | POWER9/POWER10 support |

RHEL for Edge uses `rpm-ostree` instead of `dnf`, making updates image-based and atomic.

---

## 3. Add-Ons

| Add-On | Purpose |
|--------|---------|
| High Availability (HA) | Pacemaker + Corosync cluster stack, fence-agents |
| Resilient Storage | GFS2 shared filesystem, Cluster LVM, DLM |
| Smart Management | Satellite for on-premises content management |
| Extended Life Cycle Support (ELS) | Security patches 1-3 years beyond end of maintenance |
| Extended Update Support (EUS) | Locks minor release for 24-month z-stream backports |
| Update Services for SAP (E4S) | EUS + HA + SAP repos; up to 48-month stability |

---

## 4. Developer Program

### Individual Developer Subscription (No-Cost)

- Up to 16 systems registered per Red Hat account
- Full access to all RHEL repos, errata, and security updates
- Self-support only -- no production SLA
- Annual renewal (free) at developers.redhat.com

### What Is Not Included

- No guaranteed response times or phone support
- Not eligible for production deployment under Red Hat terms
- No access to RHEL for SAP or specialized variants

---

## 5. Simple Content Access (SCA)

SCA removes per-system subscription attachment. Enabled at the organization level.

| Aspect | Classic Mode | SCA Mode |
|--------|-------------|----------|
| Attachment | Required per-system | Not required |
| Repo access | Gated by certs | All purchased content org-wide |
| `subscription-manager attach` | Required | No-op |

Systems still must be registered. SCA is the default for new accounts since 2022.

---

## 6. RHEL Lifecycle

| Phase | Duration | Scope |
|-------|----------|-------|
| Full Support | Years 1-5 | Features, hardware enablement, security, bugs |
| Maintenance Support 1 | Years 6-7 | Critical/Important security, urgent bugs |
| Maintenance Support 2 | Years 8-10 | Critical security only |
| ELS (add-on) | Up to 3 years beyond | Selected Critical patches |

Major versions receive a 10-year standard lifecycle. Minor versions release approximately every 6 months. EUS pins to a specific minor for 24 months.

---

## 7. Content Delivery

### Repositories

| Repository | Content |
|------------|---------|
| BaseOS | Core OS packages (full lifecycle) |
| AppStream | Applications and runtimes (shorter lifecycle) |
| CodeReady Builder (CRB) | Developer tools and build deps (not for production) |
| Supplementary | Proprietary / third-party components |

### Red Hat Satellite

On-premises content mirror providing Content Views (repo snapshots), Lifecycle Environments (Dev/QA/Prod), activation keys, and synchronization scheduling.

---

## 8. Convert2RHEL

In-place conversion from EL-compatible distributions to RHEL.

| Source OS | Supported Versions |
|-----------|-------------------|
| CentOS Linux | 7, 8 |
| CentOS Stream | 8, 9 |
| Oracle Linux | 7, 8 |
| Rocky Linux | 8, 9 |
| AlmaLinux | 8, 9 |

Replaces kernel, OS packages, and signing keys with Red Hat originals. Preserves filesystem layout, data, user accounts, and application packages.

---

## 9. Image Builder

Creates customized RHEL images for various deployment targets.

### Output Formats

| Format | Use Case |
|--------|----------|
| qcow2 | KVM/QEMU, OpenStack |
| vmdk | VMware vSphere |
| ami | AWS EC2 |
| vhd | Azure, Hyper-V |
| iso | Bare metal |
| container | OCI container image |
| edge-commit | RHEL for Edge (OSTree) |

### Workflow

```bash
systemctl enable --now osbuild-composer.socket
composer-cli blueprints push blueprint.toml
composer-cli compose start my-image qcow2
composer-cli compose status
composer-cli compose image <UUID>
```

---

## Choosing the Right Subscription

```
Development/learning environment?
  -> Individual Developer Subscription (free, up to 16 systems)

Non-critical production with internal expertise?
  -> Self-Support

Standard production, business-hours support?
  -> Standard Subscription

Mission-critical, 24x7 rapid response?
  -> Premium Subscription

SAP workloads needing long-term minor version stability?
  -> RHEL for SAP Solutions with E4S

Need to stay on a specific minor release?
  -> Add Extended Update Support (EUS)

Near end-of-life with no migration path yet?
  -> Extended Life Cycle Support (ELS) add-on
```
