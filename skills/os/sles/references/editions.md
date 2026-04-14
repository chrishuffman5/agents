# SLES Editions Reference

Edition comparison, module/extension details, lifecycle, and LTSS information for SUSE Linux Enterprise.

---

## SLES vs SLED

| Feature | SLES (Server) | SLED (Desktop) |
|---|---|---|
| Full name | SUSE Linux Enterprise Server | SUSE Linux Enterprise Desktop |
| Default network daemon | Wicked | NetworkManager |
| Desktop environment | None (optional) | GNOME (default) |
| Target workload | Server, virtualization, cloud | Developer workstations |
| GUI admin tool | YaST (ncurses primary) | YaST (GUI primary) |
| Available modules | All server modules | Workstation-oriented subset |
| SAP support | Yes (with extension) | No |
| HA support | Yes (with extension) | No |

---

## SLE Micro

SLE Micro is SUSE's immutable/minimal OS for containers and edge deployments:

- Uses transactional updates (read-only root filesystem)
- Minimal footprint -- no YaST GUI, minimal package set
- `transactional-update` replaces zypper for OS changes
- Based on SLES package base but different deployment model
- Cockpit for web-based management (no YaST)
- Designed for Kubernetes nodes, edge computing, and containerized workloads

---

## SLES for SAP Applications

Separate product bundling SLES with SAP-specific capabilities:

- Pre-configured with saptune for SAP HANA and NetWeaver tuning
- SAP-certified kernel configuration
- Includes SUSE HA Extension for SAP system replication
- Extended support lifecycle aligned with SAP product lifecycle
- SAP-specific YaST modules
- Resource agents for SAP HANA (SAPHana, SAPHanaTopology)
- Separate product SKU -- not a module/extension of base SLES

---

## Modules and Extensions Detail

### Modules (Included in Base Subscription)

| Module | Identifier | Purpose |
|---|---|---|
| Basesystem | sle-module-basesystem | Core RPMs, kernel, glibc, systemd (required) |
| Server Applications | sle-module-server-applications | Apache, nginx, MariaDB, PostgreSQL, BIND |
| Desktop Applications | sle-module-desktop-applications | GNOME, Qt libraries, desktop tools |
| Development Tools | sle-module-development-tools | GCC, GDB, make, cmake, git, perf |
| Containers | sle-module-containers | Podman, Buildah, Skopeo |
| Python 3 | sle-module-python3 | Current Python 3 with pip, virtualenv |
| Web and Scripting | sle-module-web-scripting | PHP, Node.js, Ruby |
| Legacy | sle-module-legacy | Older libraries for compatibility |
| Public Cloud | sle-module-public-cloud | cloud-init, provider agents |
| HPC | sle-module-hpc | MPI, Slurm (moved from separate product in SP6) |
| Systems Management (SP5+) | sle-module-systems-management | Salt, Ansible |

### Extensions (Separate License Required)

| Extension | Identifier | Purpose |
|---|---|---|
| HA Extension | sle-ha | Pacemaker, Corosync, HAWK, SBD |
| Live Patching | sle-module-live-patching | kGraft rebootless kernel patches |
| Workstation Extension | sle-we | Additional desktop tools for SLES |
| SUSE Manager Client | suse-manager-client | SUSE Manager integration |
| Confidential Computing (SP6) | sle-module-confidential-computing | Intel TDX, AMD SEV (tech preview) |

---

## Lifecycle

### Support Lifecycle Structure

```
SLES 15 General Availability: July 2018
│
├── SP1: Jun 2019
├── SP2: Dec 2019
├── SP3: Jun 2021
├── SP4: Dec 2022
├── SP5: Jun 2023
└── SP6: Dec 2024

General Support: 10 years from GA (until July 2028 for SLES 15)
LTSS: +3 years after end of General Support
Each SP supported 6 months after successor SP release
```

### Lifecycle Rules

- **General Support**: 10 years from initial GA (SLES 15 = July 2028)
- **Service Pack Overlap**: Each SP receives updates for 6 months after the next SP releases
- **LTSS (Long Term Service Pack Support)**: Additional 3 years of security patches for specific SPs, separately licensed
- **Module Lifecycle**: Modules may EOL before the base -- check `SUSEConnect --list-extensions` for per-module dates

### Lifecycle Commands

```bash
# Check current SLES release and SP
cat /etc/os-release

# Check SUSE Support status
SUSEConnect --status

# Check subscription expiry
SUSEConnect --status | grep -i expir
```

---

## LTSS (Long Term Service Pack Support)

LTSS extends security patch support for a specific SP beyond the standard overlap window. It is separately licensed and intended for systems that cannot migrate to the latest SP.

LTSS covers:
- Critical and important security patches
- No new feature development
- No recommended (non-security) bug fixes

When to use LTSS:
- Application certification tied to a specific SP
- Regulatory requirements preventing SP upgrades
- Large fleet where SP migration is staged over extended periods

---

## Content Delivery Architecture

### SUSE Customer Center (SCC)

SCC is the cloud-hosted registration and content delivery service. All SLES systems register with SCC (or a local proxy) to receive updates.

### RMT (Repository Mirroring Tool)

For air-gapped or bandwidth-limited environments. RMT syncs content from SCC and serves it locally.

### SUSE Manager

Enterprise-scale systems management platform providing:
- Centralized patch management across large fleets
- Configuration management
- Monitoring and compliance reporting
- Salt-based infrastructure automation
- Content lifecycle management (staging, testing, production channels)

---

## Migration Paths

### SP Migration

Within SLES 15: SP4 -> SP5 -> SP6 using `zypper dup` after re-registering modules.

### Cross-Version Migration

SLES 12 to SLES 15 requires a fresh installation or the SUSE-supported migration tool. In-place upgrades from SLES 12 are complex and require careful planning.

### Convert2SLES

For migrating from CentOS, Oracle Linux, or other RHEL-compatible distributions. Available as a SUSE-supported tool with documented conversion procedures.
