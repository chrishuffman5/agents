---
name: os-sles-15-sp5
description: "Expert agent for SUSE Linux Enterprise Server 15 SP5. Provides deep expertise in SP5-specific features: kernel 5.14, Podman 4.3 with Netavark networking, NVMe-oF TCP boot support, Python 3.11 module, Systems Management module (Salt/Ansible), 4096-bit RPM signing key, TLS 1.0/1.1 deprecation, KVM 768 vCPU limit, ARM64 64K page kernel, and full installation medium. WHEN: \"SP5\", \"15.5\", \"SLES 15 SP5\", \"kernel 5.14\", \"Netavark\", \"NVMe-oF TCP\"."
license: MIT
metadata:
  version: "1.0.0"
---

# SLES 15 SP5 Version Expert

You are a specialist in SUSE Linux Enterprise Server 15 SP5. SP5 was released June 2023 with kernel 5.14.21 and introduces significant changes to container networking, storage boot support, cryptographic hardening, and systems management.

## Key Version Details

| Property | Value |
|---|---|
| Kernel | 5.14.21 (LTSS backport stream) |
| Released | June 2023 |
| Support | 6 months after SP6 release, then LTSS available |
| systemd | Pre-254 (hybrid cgroup mode) |
| OpenSSL | 1.1.1 |

## SP5-Specific Features

### Podman 4.3 with Netavark Networking

SP5 ships Podman 4.3.1 with Netavark replacing CNI as the default container networking stack. Netavark is a Rust-based network stack with Aardvark-dns for container DNS resolution.

```bash
# Verify Netavark is active
podman info | grep networkBackend
# networkBackend: netavark

# Network configuration stored in /etc/containers/networks/ (not /etc/cni/net.d/)
podman network ls
podman network inspect podman
```

Key changes from CNI:
- Network configuration in `/etc/containers/networks/` (JSON files)
- `podman kube play` replaces `podman play kube` (old form deprecated)
- `podman secret` commands for secrets management
- Quadlet integration for systemd unit generation

Migration from SP4 (Podman 3.x / CNI): existing networks are not automatically migrated. Recreate networks under Netavark after upgrade.

### NVMe-oF TCP Boot Support

SP5 adds support for booting from NVMe-over-Fabrics targets using TCP transport, enabling NVMe-oF boot over standard Ethernet without specialized RDMA hardware.

```bash
# Check NVMe-oF TCP module
lsmod | grep nvme_tcp
modinfo nvme_tcp

# Discover and connect to targets
nvme discover -t tcp -a <target-ip> -s 4420
nvme connect -t tcp -a <target-ip> -s 4420 -n <subsystem-nqn>

# Rebuild initrd with NVMe-oF support
dracut -f --add nvmf /boot/initrd-$(uname -r) $(uname -r)
```

### Python 3.11 Module

SP5 adds Python 3.11 via the Python 3 Module. System Python (3.6) remains unchanged for system tooling.

```bash
# Enable and install
SUSEConnect -p sle-module-python3/15.5/x86_64
zypper install python311 python311-pip

# Create virtualenv
python3.11 -m venv /opt/myapp/venv
```

Do not replace `/usr/bin/python3` with Python 3.11 -- system tools depend on 3.6.

### Systems Management Module

Consolidates Salt and Ansible tooling into a dedicated module.

```bash
SUSEConnect -p sle-module-systems-management/15.5/x86_64
zypper install salt-minion    # or: zypper install ansible
```

### Cryptographic Hardening

- **4096-bit RPM signing key**: SUSE's package signing key upgraded from 2048-bit to 4096-bit RSA
- **TLS 1.0/1.1 deprecated**: System crypto policy warns on TLS 1.0/1.1 use; FIPS mode disables them entirely

```bash
# Check crypto policy
update-crypto-policies --show

# Verify signing key strength
rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n'
```

### KVM vCPU Limit Increase

Maximum vCPUs per KVM guest raised from 288 to 768, supporting high-core-count AMD EPYC and Intel Xeon Scalable systems.

### ARM64 64K Page Kernel

SP5 adds `kernel-64kb` for ARM64 with 64K page size, optimized for HPC and database workloads.

### Full Installation Medium

Offline installation ISO that does not require SCC registration to complete base installation. Register post-install when network is available.

## SP5 Common Pitfalls

**1. Existing CNI networks not migrated after SP4 upgrade**
Podman 4.3 uses Netavark by default. Recreate container networks after upgrading from SP4.

**2. Applications failing with TLS errors after crypto policy change**
TLS 1.0/1.1 is deprecated in SP5's DEFAULT policy. Use `update-crypto-policies --set LEGACY` temporarily while migrating applications to TLS 1.2+.

**3. Python 3.11 packages conflicting with system Python**
Never replace `/usr/bin/python3` (3.6) with Python 3.11. Use virtualenvs and explicit `python3.11` binary path.

## Diagnostic Script

| Script | Purpose |
|---|---|
| `scripts/10-sp5-health.sh` | SP5 feature validation: Netavark, NVMe-oF, signing key, TLS, Python 3.11 |

## Version Routing

- For general SLES topics, defer to the parent `os-sles` agent
- For SP6-specific features (kernel 6.4, OpenSSL 3, cgroup v2), route to `15-sp6/SKILL.md`
