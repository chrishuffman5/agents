# RHEL 9 — Version-Specific Research

**Scope:** Features NEW or CHANGED in RHEL 9 only. Cross-version content (systemd, SELinux fundamentals, subscription management, tuned profiles, etc.) lives in references/.
**Support:** Full Support until May 2027. Maintenance Support until May 2032.
**Kernel:** 5.14 (base release), backported through minor releases (9.1 → 9.2 → 9.3 → 9.4 → 9.5)
**Based on:** CentOS Stream 9 (upstream development model — see Section 12)

---

## 1. OpenSSL 3.0

### Overview

RHEL 9 ships OpenSSL 3.0, a major version jump from OpenSSL 1.1.1 used in RHEL 8. This is not a drop-in replacement — the provider model is architecturally different, and several APIs were removed or deprecated.

### Provider Model (New in 3.0)

OpenSSL 3.0 replaces the ENGINE API with a **provider** architecture. Providers are loadable modules that implement cryptographic algorithms. Default providers shipped with RHEL 9:

- **default** — Standard algorithms (AES, RSA, ECDSA, SHA-2/3, ChaCha20)
- **legacy** — Older algorithms (Blowfish, CAST, DES, MD2, MD4, RC2, RC4, RC5, SEED, WHIRLPOOL) — must be explicitly loaded
- **fips** — FIPS 140-2/140-3 validated algorithms only — replaces the old FIPS_mode() API
- **base** — Common infrastructure (encoding/decoding, no crypto)
- **null** — Empty provider for testing

Provider configuration in `/etc/pki/tls/openssl.cnf`:

```ini
[provider_sect]
default = default_sect
fips = fips_sect

[default_sect]
activate = 1

[fips_sect]
activate = 1
```

### Deprecated / Removed Algorithms in RHEL 9 Default Policy

The following are disabled by default at the system crypto policy level (separate from OpenSSL 3.0 itself):

| Algorithm | Status | Reason |
|-----------|--------|--------|
| SHA-1 (signatures) | Deprecated | Collision attacks (see Section 2) |
| TLS 1.0 / 1.1 | Disabled | Protocol weaknesses |
| DES / 3DES | Disabled | Key length / Sweet32 attack |
| RC4 | Disabled | Statistical biases |
| DSA | Disabled | FIPS 186-5 removed it |
| MD5 (signatures) | Disabled | Collision attacks |
| Export-grade ciphers | Removed | FREAK/LOGJAM |

### Migration from OpenSSL 1.1.1 (RHEL 8)

Breaking changes affecting application code:

- `ENGINE_*` API functions removed — replace with `OSSL_PROVIDER_load()` and provider-aware APIs
- `EVP_MD_CTX_init()` removed — use `EVP_MD_CTX_new()` and `EVP_MD_CTX_free()`
- Low-level API functions (e.g., `RSA_public_encrypt()`) deprecated — use `EVP_PKEY_*` APIs
- `PKCS12_parse()` behavior changed for empty passwords vs. NULL
- DH parameter generation defaults changed (2048-bit minimum)

### FIPS Module Validation

RHEL 9 uses the **OpenSSL FIPS Provider** (a separate validated module), replacing the old FIPS kernel flag approach:

```bash
# Enable FIPS mode system-wide (requires reboot)
fips-mode-setup --enable

# Check FIPS status after reboot
fips-mode-setup --check

# Check OpenSSL FIPS provider directly
openssl list -providers
# Should show: fips (active)

# Verify FIPS module integrity
openssl fipsinstall -verify -in /etc/pki/tls/fips_enabled

# Check kernel FIPS flag
cat /proc/sys/crypto/fips_enabled
# 1 = FIPS enabled
```

### Certificate and Key Compatibility

```bash
# Check certificate signature algorithm
openssl x509 -in /path/to/cert.pem -noout -text | grep "Signature Algorithm"

# Test TLS connection with specific protocol/cipher
openssl s_client -connect host:443 -tls1_2 -cipher AES256-GCM-SHA384

# List supported ciphers under current policy
openssl ciphers -v 'DEFAULT'

# Verify a certificate chain
openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt /path/to/cert.pem
```

---

## 2. SHA-1 Deprecated System-Wide

### Overview

RHEL 9 sets SHA-1 signature verification to **disabled by default** at the system crypto policy level. This is broader than just OpenSSL — it affects all system components that use the crypto policy framework.

### What Is Blocked

- SSH public key authentication using `ssh-rsa` (RSA with SHA-1) — replaced by `rsa-sha2-256` and `rsa-sha2-512`
- TLS certificates signed with SHA-1 — rejected by default
- RPM package signatures using SHA-1 — blocked
- GPG signatures using SHA-1 — blocked
- DNSSEC signatures using RSASHA1 — not validated
- S/MIME email signed with SHA-1 — rejected

### Impact on SSH Keys

Existing `ssh-rsa` keys continue to work because the key type is RSA but the signature hash algorithm used in the SSH handshake is negotiated separately. OpenSSH in RHEL 9 uses `rsa-sha2-256` by default even with `ssh-rsa` keys. The legacy `ssh-rsa` signature algorithm (SHA-1 hash) is what is disabled.

```bash
# Check current SSH server accepted algorithms
sshd -T | grep -i pubkeyacceptedalgorithms

# Check current crypto policy
update-crypto-policies --show

# Show what SHA-1 restrictions are in effect
update-crypto-policies --show | grep -i sha

# Check which crypto policy modules are active
ls /etc/crypto-policies/policies/modules/
```

### Workarounds

If legacy SHA-1 use is required for compatibility (not recommended in production):

```bash
# Apply LEGACY sub-policy (re-enables SHA-1 and older algorithms)
update-crypto-policies --set DEFAULT:SHA1

# Or switch fully to LEGACY policy (enables TLS 1.0/1.1, SHA-1, etc.)
update-crypto-policies --set LEGACY

# Verify the change
update-crypto-policies --show

# Apply without reboot (services using crypto will need restart)
update-crypto-policies --set DEFAULT:SHA1
systemctl restart sshd
```

For individual SSH keys, migrate to Ed25519 or ECDSA:

```bash
# Generate Ed25519 key (preferred in RHEL 9)
ssh-keygen -t ed25519 -C "user@host"

# Generate RSA 4096 key (also acceptable)
ssh-keygen -t rsa -b 4096 -C "user@host"

# Check key type of existing keys
ssh-keygen -l -f ~/.ssh/id_rsa.pub
```

---

## 3. nftables Only (iptables Removed)

### Overview

RHEL 9 ships **without iptables**. The `iptables`, `ip6tables`, `arptables`, and `ebtables` commands are not available by default. Firewalld uses the nftables backend exclusively. This completes the transition started in RHEL 8 where nftables was the preferred backend.

### Key Commands

```bash
# List all nftables rules
nft list ruleset

# List a specific table
nft list table inet firewalld

# Add a rule directly
nft add rule inet filter input tcp dport 8080 accept

# Delete a rule (by handle)
nft list ruleset -a   # show handles
nft delete rule inet filter input handle 7

# Flush a chain
nft flush chain inet filter input

# Save ruleset to file
nft list ruleset > /etc/nftables/custom-rules.nft

# Load ruleset from file
nft -f /etc/nftables/custom-rules.nft
```

### Firewalld on nftables

```bash
# Verify firewalld backend
firewall-cmd --info-zone=public

# Check backend in config
grep -i backend /etc/firewalld/firewalld.conf
# Backend=nftables

# View firewalld-generated nft rules
nft list ruleset | grep -A5 firewalld

# Standard firewalld operations (unchanged from RHEL 8)
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

# Rich rules (firewalld layer on top of nftables)
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" accept'
```

### Migration from iptables Rules

```bash
# Install iptables-nft compatibility shim (NOT the same as native iptables)
# This translates iptables syntax to nftables — for migration only
dnf install iptables-nft

# Use iptables-restore-translate to convert existing rules
iptables-restore-translate -f /path/to/iptables.rules > /etc/nftables/migrated.nft

# Verify translated rules before applying
nft -c -f /etc/nftables/migrated.nft   # dry run / check only

# Apply migrated rules
nft -f /etc/nftables/migrated.nft
```

### Direct Rules Deprecated in Firewalld

Firewalld's `--direct` rule interface (which passed raw iptables syntax) is deprecated in RHEL 9 and will be removed in a future release. Use `--add-rich-rule` or native `nft` commands instead.

---

## 4. Root SSH Password Login Disabled

### Overview

In RHEL 9, the default SSH server configuration sets `PermitRootLogin prohibit-password`. This means root login via password is blocked; root login with SSH keys is still permitted by this setting, but is often further restricted by cloud-init or kickstart configurations that set `PermitRootLogin no`.

### Default Behavior

```bash
# Check current PermitRootLogin value
sshd -T | grep permitrootlogin

# RHEL 9 default in /etc/ssh/sshd_config.d/
# File: /etc/ssh/sshd_config.d/01-permitrootlogin.conf
# PermitRootLogin prohibit-password
```

### Cloud and Automation Impact

- **cloud-init** sets `PermitRootLogin no` on most cloud providers — root login completely blocked
- **Kickstart** deployments that relied on `rootpw` + SSH password login must migrate
- **Ansible** playbooks using `ansible_user=root` with password authentication fail unless changed

### Recommended Alternatives

```bash
# Create a dedicated admin user with sudo access
useradd -m -G wheel adminuser
passwd adminuser

# Verify wheel group has sudo access (default in RHEL 9)
grep wheel /etc/sudoers

# For Ansible: configure user in inventory
# [defaults]
# remote_user = adminuser
# become = true
# become_method = sudo

# If root SSH with key is absolutely required, edit drop-in config
cat > /etc/ssh/sshd_config.d/10-root-login.conf << 'EOF'
PermitRootLogin without-password
EOF
systemctl reload sshd
```

### Verification

```bash
# Test SSH config without restarting
sshd -t

# Show all effective sshd settings (including drop-in files)
sshd -T

# Check all drop-in config files
ls /etc/ssh/sshd_config.d/
```

---

## 5. Kernel Live Patching (kpatch)

### Overview

RHEL 9 provides kernel live patching via **kpatch**, allowing critical security patches to be applied to a running kernel without rebooting. Live patches are cumulative — each patch includes all previous fixes for that kernel.

### Installation and Setup

```bash
# Install the kpatch DNF plugin (manages live patch subscriptions)
dnf install kpatch-dnf

# Enable automatic live patching
dnf kpatch auto

# Install a specific live patch (if managing manually)
dnf install kpatch-patch-$(uname -r | tr '-' '_')
```

### kpatch Commands

```bash
# List loaded live patches
kpatch list

# Show detailed info about patches
kpatch info

# Check if a patch is active
kpatch status

# Load a patch manually
kpatch load /path/to/patch.ko

# Unload a patch (use carefully)
kpatch unload kpatch_patch_name
```

### Cockpit UI Integration

Cockpit in RHEL 9 shows live patch status under **System → Software Updates**. The panel displays:
- Current kernel version
- Available live patches
- Applied patches and their CVE coverage
- Whether a reboot is pending for non-live-patchable fixes

### Limitations

- **Not all CVEs** are live-patchable — some kernel changes affect data structures in ways that require a full reboot
- **Supported kernels only**: kpatch is available for kernels within the current minor RHEL version stream; older minor-version kernels may not have live patches available
- Live patches are **cumulative but not permanent** — they live in kernel memory and are lost on reboot (the new booted kernel should have the patch baked in via RPM)
- **FIPS environments**: live patches are subject to the same FIPS restrictions; patching a FIPS-validated kernel requires re-validation consideration

```bash
# Check current kernel and available patches
uname -r
dnf check-update kpatch-patch-*

# Verify live patch is active (check /sys interface)
ls /sys/kernel/livepatch/
```

---

## 6. Podman 4.x Improvements

### Overview

RHEL 9 ships Podman 4.x with two major infrastructure changes: the Netavark network stack replaces CNI, and Aardvark provides DNS resolution for container networks. These changes significantly improve rootless container networking.

### Netavark Network Stack

Netavark replaces the Container Network Interface (CNI) plugins as the default network stack. Written in Rust, it provides:
- Better rootless networking performance
- Proper IPv6 support without workarounds
- Consistent behavior between rootful and rootless containers

```bash
# Check Podman version and network backend
podman version
podman info | grep -i network

# List networks (now uses Netavark)
podman network ls

# Create a network
podman network create mynet

# Inspect network (shows Netavark driver)
podman network inspect mynet

# Container with custom network
podman run --network mynet --name app1 myimage
```

### Aardvark DNS Resolver

Aardvark-dns replaces the dnsname CNI plugin. Containers on the same network can resolve each other by name automatically.

```bash
# Containers on same network resolve by name
podman run -d --network mynet --name db postgres:15
podman run -d --network mynet --name app myapp
# 'app' can now reach 'db' by hostname 'db'

# Verify DNS resolution inside container
podman exec app getent hosts db

# Check aardvark-dns is running
systemctl status aardvark-dns@mynet 2>/dev/null || \
  ls /run/aardvark-dns/
```

### Rootless Networking Improvements

```bash
# Rootless containers no longer require slirp4netns for basic networking
# (Netavark handles it via pasta or slirp4netns depending on kernel support)
podman info | grep -i rootless

# Check network mode for rootless user
podman run --rm alpine ip addr

# Port mapping in rootless (no privileges needed for ports >1024)
podman run -p 8080:80 nginx
```

### Systemd Integration

```bash
# Generate systemd unit for a container
podman generate systemd --new --name mycontainer > ~/.config/systemd/user/mycontainer.service

# Enable and start via systemd (rootless)
systemctl --user enable --now mycontainer.service

# For rootful containers (system-wide)
podman generate systemd --new --name mycontainer > /etc/systemd/system/mycontainer.service
systemctl enable --now mycontainer.service

# Quadlet (RHEL 9.3+) — declarative systemd integration
# Place .container files in /etc/containers/systemd/
# systemd-generator creates units automatically
```

---

## 7. Keylime (Remote Attestation)

### Overview

Keylime is a TPM-based remote attestation framework included in RHEL 9. It verifies the integrity of remote systems by comparing TPM measurements against known-good values, detecting unauthorized changes to firmware, bootloader, kernel, or runtime files.

### Architecture Components

| Component | Role |
|-----------|------|
| `keylime_registrar` | Central registry of trusted agents; stores TPM public keys and expected measurements |
| `keylime_verifier` | Continuously challenges agents to prove integrity; triggers alerts on mismatch |
| `keylime_agent` | Runs on the attested system; responds to challenges using TPM |
| `keylime_tenant` | CLI/API client for registering agents, setting policies, retrieving results |

### Installation

```bash
# Install Keylime
dnf install keylime

# On verifier/registrar server
systemctl enable --now keylime_verifier
systemctl enable --now keylime_registrar

# On attested node
systemctl enable --now keylime_agent
```

### Configuration

Main config: `/etc/keylime.conf` (or `/etc/keylime/` directory in newer versions)

Key settings:
```ini
[general]
registrar_ip = 192.168.1.10
verifier_ip = 192.168.1.10

[agent]
tpm_ownerpassword = 
tpm_hash_alg = sha256
```

### Tenant Operations

```bash
# Register an agent for attestation
keylime_tenant -c add \
  --uuid <agent-uuid> \
  --ip <agent-ip> \
  --tpm_policy '{"22": ["0000000000000000000000000000000000000000"]}' \
  --allowlist /path/to/allowlist.txt

# Check agent status
keylime_tenant -c status --uuid <agent-uuid>

# List all registered agents
keylime_tenant -c reglist

# Delete/unregister an agent
keylime_tenant -c delete --uuid <agent-uuid>
```

### TPM Status Verification

```bash
# Check TPM presence and version
ls /dev/tpm* /dev/tpmrm*

# Read TPM event log (measured boot)
tpm2_eventlog /sys/kernel/security/tpm0/binary_bios_measurements

# Check PCR values (Platform Configuration Registers)
tpm2_pcrread sha256

# Verify tpm2-tools available
rpm -q tpm2-tools tpm2-tss
```

### Use Cases

- **Measured boot verification**: Confirm firmware, bootloader, and kernel match expected values
- **Runtime integrity**: Detect modifications to critical files (IMA integration)
- **Zero-trust node enrollment**: Only attest-passing nodes receive secrets/certificates

---

## 8. WireGuard VPN

### Overview

WireGuard is included in the RHEL 9 kernel (5.14), providing a modern, high-performance VPN with a minimal attack surface (~4,000 lines of code vs. OpenVPN's ~150,000). It uses fixed modern cryptography: ChaCha20, Poly1305, Curve25519, BLAKE2, SipHash24.

### Installation and Key Generation

```bash
# Install WireGuard tools
dnf install wireguard-tools

# Generate server keypair
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key

# Generate client keypair
wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key
```

### wg-quick Configuration

Server config `/etc/wireguard/wg0.conf`:

```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <server_private_key>
PostUp = firewall-cmd --add-interface=wg0 --zone=trusted
PostDown = firewall-cmd --remove-interface=wg0 --zone=trusted

[Peer]
PublicKey = <client_public_key>
AllowedIPs = 10.0.0.2/32
```

```bash
# Start WireGuard interface
wg-quick up wg0

# Enable at boot
systemctl enable --now wg-quick@wg0

# Check status
wg show
wg show wg0 latest-handshakes
```

### NetworkManager Integration

```bash
# Add WireGuard connection via nmcli
nmcli connection add type wireguard \
  con-name wg-vpn \
  ifname wg0 \
  wireguard.private-key "$(cat /etc/wireguard/client_private.key)" \
  wireguard.listen-port 51820

# Add peer to NM connection
nmcli connection modify wg-vpn \
  wireguard.peers "public-key=<server_pubkey>,endpoint=vpn.example.com:51820,allowed-ips=0.0.0.0/0"

# Bring up connection
nmcli connection up wg-vpn
```

### Firewalld Configuration

```bash
# Allow WireGuard port through firewall
firewall-cmd --permanent --add-port=51820/udp
firewall-cmd --permanent --add-masquerade
firewall-cmd --reload

# Assign WireGuard interface to trusted zone
firewall-cmd --permanent --zone=trusted --add-interface=wg0
firewall-cmd --reload
```

---

## 9. RHEL for Edge / Image Builder

### Overview

RHEL 9 significantly enhances the edge computing story with **Image Builder** producing ostree-based images and **greenboot** providing health-check-driven rollback.

### Image Builder (osbuild)

```bash
# Install Image Builder
dnf install osbuild-composer composer-cli

# Start services
systemctl enable --now osbuild-composer.socket

# List available image types
composer-cli compose types

# Create a blueprint (TOML format)
cat > edge-server.toml << 'EOF'
name = "edge-server"
description = "RHEL 9 Edge Server"
version = "1.0.0"

[[packages]]
name = "podman"
version = "*"

[[packages]]
name = "greenboot"
version = "*"

[customizations.services]
enabled = ["podman"]
EOF

# Push blueprint
composer-cli blueprints push edge-server.toml

# Start an edge-commit compose
composer-cli compose start edge-server edge-commit
```

### ostree-Based Immutable Deployments

```bash
# Check ostree status on an edge device
rpm-ostree status

# Show pending updates
rpm-ostree upgrade --check

# Apply update (staged, takes effect on next boot)
rpm-ostree upgrade

# Rollback to previous deployment
rpm-ostree rollback

# List deployment history
rpm-ostree db list
```

### Greenboot Health Checking

Greenboot runs health-check scripts after boot. If checks fail, the system rolls back to the previous ostree deployment.

```bash
# Required health checks (must pass or trigger rollback)
# Place scripts in:
ls /etc/greenboot/check/required.d/

# Wanted health checks (informational, no rollback)
ls /etc/greenboot/check/wanted.d/

# Post-boot success actions
ls /etc/greenboot/green.d/

# Post-rollback actions
ls /etc/greenboot/red.d/

# Check greenboot status
systemctl status greenboot-healthcheck
journalctl -u greenboot-healthcheck

# Example health check script
cat > /etc/greenboot/check/required.d/01-check-app.sh << 'EOF'
#!/bin/bash
systemctl is-active --quiet myapp.service
EOF
chmod +x /etc/greenboot/check/required.d/01-check-app.sh
```

---

## 10. Reduced Module Streams

### Overview

RHEL 9 drastically reduces AppStream module streams. Many applications that were modularized in RHEL 8 (with complex module enable/disable workflow) are now distributed as traditional RPM packages in the AppStream repository.

### What Changed

| RHEL 8 (modular) | RHEL 9 (traditional RPM) |
|------------------|--------------------------|
| `dnf module enable nodejs:14` | `dnf install nodejs` (default version in AppStream) |
| `dnf module enable python36:3.6` | `dnf install python3.11` (direct package name) |
| `dnf module enable postgresql:13` | `dnf install postgresql` |
| `dnf module enable nginx:1.18` | `dnf install nginx` |

### Remaining Modules in RHEL 9

Modules still present (where multiple streams are needed):
- `ruby` (3.1, 3.3)
- `maven` (3.8)
- `nodejs` (18, 20, 22 — newer stream versions)

```bash
# List available modules
dnf module list

# Enable a specific module stream
dnf module enable ruby:3.3
dnf install ruby

# Check enabled modules
dnf module list --enabled

# Reset a module (disable stream selection)
dnf module reset ruby
```

### Impact on Package Management

```bash
# In RHEL 9, version-specific packages are often named directly
dnf install python3.11
dnf install python3.12

# No module enable needed for most packages
dnf install nodejs   # Gets current AppStream version

# Check what version is in AppStream
dnf info nodejs | grep Version
```

---

## 11. IMA (Integrity Measurement Architecture)

### Overview

IMA in RHEL 9 provides kernel-level file integrity measurement. The kernel measures (hashes) files before access and records measurements in the TPM. Extended attributes (IMA-EVM) allow signature verification.

### IMA Modes

- **measure**: Record file hashes in the IMA measurement list (without blocking access)
- **appraise**: Verify file hash against stored extended attribute; block access if mismatch
- **audit**: Log file access to the audit log
- **fix**: Write current hash to extended attribute (used to initialize)

### Configuration

```bash
# Check if IMA is active
cat /sys/kernel/security/ima/active

# View IMA measurement list
cat /sys/kernel/security/ima/ascii_runtime_measurements | head -20

# View IMA policy
cat /sys/kernel/security/ima/policy

# Install IMA tools
dnf install ima-evm-utils

# Set extended attribute on a file (fix mode / initialization)
evmctl ima_hash /path/to/binary

# Verify file integrity
evmctl ima_verify /path/to/binary
```

### Boot-Time IMA Policy

Kernel cmdline options for IMA:
```
# In /etc/default/grub, GRUB_CMDLINE_LINUX:
ima_policy=tcb          # measure all files
ima_appraise=enforce    # enforce appraisal (blocks tampered files)
ima_hash=sha256         # hash algorithm
```

### Integration with Keylime

Keylime's verifier can use IMA measurement logs to detect file modifications at runtime, providing continuous integrity assurance beyond just boot-time attestation.

---

## 12. CentOS Stream Relationship

### Overview

RHEL 9 is built **from** CentOS Stream 9, reversing the historical relationship where CentOS was a rebuild of RHEL. CentOS Stream 9 is now the **upstream** development branch for RHEL 9.x minor releases.

### Development Flow

```
Fedora (cutting edge, ~6 month releases)
    ↓  (selected features, ~2 years)
CentOS Stream 9 (rolling, continuous)
    ↓  (stabilized, tested, released as minor versions)
RHEL 9.x (stable, supported, subscribed)
```

### What This Means Operationally

- CentOS Stream 9 receives changes **before** they appear in RHEL 9.x point releases
- CentOS Stream 9 is **not** a downstream rebuild — it is slightly ahead of RHEL 9
- CentOS Stream 9 is suitable for testing RHEL 9 compatibility but is **not** a supported substitute for production
- RHEL 9.x point releases (9.1, 9.2, 9.3, 9.4, 9.5) pull from the Stream and add QE/testing gates

### Contributing to RHEL 9

Red Hat partners and the community can contribute to RHEL 9 via CentOS Stream 9 through the [CentOS GitLab](https://gitlab.com/redhat/centos-stream). Patches accepted into Stream 9 are eligible for inclusion in future RHEL 9 minor releases.

---

## 13. Diagnostic Scripts

### Script: 10-keylime-status.sh

```bash
#!/usr/bin/env bash
# =============================================================================
# 10-keylime-status.sh
# RHEL 9 — Keylime Remote Attestation Status
#
# Version:  9.1.0
# Targets:  RHEL 9.x
# Purpose:  Reports Keylime service status, registered agents, attestation
#           results, and TPM hardware status.
# Safe:     Read-only. No configuration changes made.
# =============================================================================

set -euo pipefail

SEPARATOR="$(printf '%0.s-' {1..72})"
SECTION() { echo; echo "$SEPARATOR"; echo "  $1"; echo "$SEPARATOR"; }

# Color output (suppress if not a terminal)
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }
info() { echo "  [INFO] $1"; }

echo "Keylime Remote Attestation Status"
echo "Host: $(hostname -f)  |  Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Kernel: $(uname -r)"

# =============================================================================
SECTION "1. Keylime Package Installation"
# =============================================================================

if rpm -q keylime &>/dev/null; then
  pass "keylime installed: $(rpm -q keylime)"
else
  fail "keylime package not installed"
  info "Install with: dnf install keylime"
fi

if rpm -q tpm2-tools &>/dev/null; then
  pass "tpm2-tools installed: $(rpm -q tpm2-tools)"
else
  warn "tpm2-tools not installed (required for TPM operations)"
fi

# =============================================================================
SECTION "2. Keylime Service Status"
# =============================================================================

SERVICES=("keylime_verifier" "keylime_registrar" "keylime_agent")

for svc in "${SERVICES[@]}"; do
  state=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
  enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "disabled")

  if [ "$state" = "active" ]; then
    pass "$svc: $state ($enabled)"
  elif systemctl list-unit-files "$svc.service" &>/dev/null 2>&1; then
    warn "$svc: $state ($enabled)"
  else
    info "$svc: not installed on this node"
  fi
done

# Show last 10 lines of agent log if active
if systemctl is-active keylime_agent &>/dev/null; then
  SECTION "2a. Keylime Agent Recent Logs"
  journalctl -u keylime_agent --no-pager -n 15 --output=short-iso 2>/dev/null || \
    warn "Could not retrieve agent logs"
fi

# =============================================================================
SECTION "3. TPM Hardware Status"
# =============================================================================

# Check TPM device nodes
if ls /dev/tpm0 &>/dev/null || ls /dev/tpmrm0 &>/dev/null; then
  pass "TPM device present"
  ls -la /dev/tpm* /dev/tpmrm* 2>/dev/null | while read -r line; do
    info "$line"
  done
else
  fail "No TPM device found (/dev/tpm0 or /dev/tpmrm0)"
  info "Check BIOS/UEFI TPM settings"
fi

# Check tpm2-abrmd (resource manager daemon)
if systemctl is-active tpm2-abrmd &>/dev/null; then
  pass "tpm2-abrmd resource manager: active"
else
  info "tpm2-abrmd not active (may use /dev/tpmrm0 directly)"
fi

# Check kernel TPM modules
if command -v tpm2_pcrread &>/dev/null; then
  SECTION "3a. TPM PCR Values (SHA-256)"
  tpm2_pcrread sha256:0,1,2,3,4,5,6,7 2>/dev/null && \
    info "PCRs 0-7 (firmware/bootloader measurements)" || \
    warn "Could not read PCR values"
fi

# Check IMA event log
if [ -r /sys/kernel/security/tpm0/binary_bios_measurements ]; then
  pass "TPM event log (BIOS measurements) readable"
  entry_count=$(wc -l < /sys/kernel/security/ima/ascii_runtime_measurements 2>/dev/null || echo "N/A")
  info "IMA measurement entries: $entry_count"
else
  warn "TPM event log not accessible (may require root or TPM device)"
fi

# =============================================================================
SECTION "4. Keylime Agent Configuration"
# =============================================================================

CONFIG_LOCATIONS=(
  "/etc/keylime/agent.conf"
  "/etc/keylime.conf"
)

for cfg in "${CONFIG_LOCATIONS[@]}"; do
  if [ -f "$cfg" ]; then
    pass "Config found: $cfg"
    info "registrar_ip: $(grep -E '^\s*registrar_ip' "$cfg" 2>/dev/null | head -1 | awk -F= '{print $2}' | tr -d ' ' || echo 'not set')"
    info "agent uuid:   $(grep -E '^\s*agent_uuid' "$cfg" 2>/dev/null | head -1 | awk -F= '{print $2}' | tr -d ' ' || echo 'auto-generated')"
    break
  fi
done

# =============================================================================
SECTION "5. Keylime Agent UUID"
# =============================================================================

KEYLIME_UUID_FILE="/var/lib/keylime/uuid"
if [ -f "$KEYLIME_UUID_FILE" ]; then
  pass "Agent UUID: $(cat "$KEYLIME_UUID_FILE")"
else
  info "Agent UUID file not found (agent may not have registered yet)"
fi

# =============================================================================
SECTION "6. IMA Runtime Integrity Status"
# =============================================================================

if [ -r /sys/kernel/security/ima/active ]; then
  ima_active=$(cat /sys/kernel/security/ima/active)
  if [ "$ima_active" = "1" ]; then
    pass "IMA is active"
  else
    warn "IMA is not active"
  fi

  if [ -r /sys/kernel/security/ima/ascii_runtime_measurements ]; then
    meas_count=$(wc -l < /sys/kernel/security/ima/ascii_runtime_measurements)
    info "Total IMA measurements recorded: $meas_count"
  fi

  # Check current IMA policy
  if [ -r /sys/kernel/security/ima/policy ]; then
    info "IMA policy rules active: $(wc -l < /sys/kernel/security/ima/policy)"
  fi
else
  warn "IMA securityfs not accessible (run as root for full output)"
fi

echo
echo "Keylime status check complete: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
```

---

### Script: 11-crypto-audit.sh

```bash
#!/usr/bin/env bash
# =============================================================================
# 11-crypto-audit.sh
# RHEL 9 — Cryptography and Deprecated Algorithm Audit
#
# Version:  9.1.0
# Targets:  RHEL 9.x
# Purpose:  Audits system crypto policy, OpenSSL 3.0 / FIPS status, SSH key
#           types in use, deprecated algorithm detection, and SHA-1 certificate
#           usage across the system trust store.
# Safe:     Read-only. No configuration changes made.
# =============================================================================

set -euo pipefail

SEPARATOR="$(printf '%0.s-' {1..72})"
SECTION() { echo; echo "$SEPARATOR"; echo "  $1"; echo "$SEPARATOR"; }

if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }
info() { echo "  [INFO] $1"; }

echo "RHEL 9 Cryptography Audit"
echo "Host: $(hostname -f)  |  Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Kernel: $(uname -r)"

# =============================================================================
SECTION "1. System Crypto Policy"
# =============================================================================

if command -v update-crypto-policies &>/dev/null; then
  current_policy=$(update-crypto-policies --show 2>/dev/null)
  pass "Current crypto policy: $current_policy"

  case "$current_policy" in
    DEFAULT*)  info "DEFAULT: SHA-1 disabled, TLS 1.0/1.1 disabled, DES/RC4 disabled" ;;
    FIPS*)     pass "FIPS policy active — strong algorithm enforcement" ;;
    LEGACY*)   warn "LEGACY policy: SHA-1, TLS 1.0/1.1, DES enabled — insecure" ;;
    FUTURE*)   pass "FUTURE policy: stricter than DEFAULT (RSA >= 3072, etc.)" ;;
    *)         info "Custom or unknown policy: $current_policy" ;;
  esac

  # Check for sub-policies (e.g., DEFAULT:SHA1)
  if echo "$current_policy" | grep -q ":"; then
    sub=$(echo "$current_policy" | cut -d: -f2-)
    warn "Sub-policy active: $sub — review for security implications"
  fi
else
  fail "update-crypto-policies command not found"
fi

# List active policy modules
if ls /etc/crypto-policies/policies/modules/ &>/dev/null; then
  mods=$(ls /etc/crypto-policies/policies/modules/ 2>/dev/null | tr '\n' ' ')
  [ -n "$mods" ] && info "Active policy modules: $mods" || info "No custom policy modules"
fi

# =============================================================================
SECTION "2. OpenSSL Version and FIPS Status"
# =============================================================================

if command -v openssl &>/dev/null; then
  openssl_version=$(openssl version)
  pass "OpenSSL: $openssl_version"

  # Check for OpenSSL 3.x
  if echo "$openssl_version" | grep -q "OpenSSL 3\."; then
    pass "OpenSSL 3.x detected (expected for RHEL 9)"
  else
    warn "OpenSSL version may not be 3.x — check package installation"
  fi

  # List active providers
  SECTION "2a. OpenSSL Providers"
  openssl list -providers 2>/dev/null | while read -r line; do
    if echo "$line" | grep -q "fips"; then
      pass "Provider: $line"
    else
      info "Provider: $line"
    fi
  done

  # Check FIPS provider specifically
  if openssl list -providers 2>/dev/null | grep -qi "fips.*active\|name: fips"; then
    pass "FIPS provider is active"
  else
    info "FIPS provider not active (expected unless FIPS mode enabled)"
  fi
else
  fail "openssl command not found"
fi

# =============================================================================
SECTION "3. System FIPS Mode"
# =============================================================================

if [ -r /proc/sys/crypto/fips_enabled ]; then
  fips_val=$(cat /proc/sys/crypto/fips_enabled)
  if [ "$fips_val" = "1" ]; then
    pass "FIPS mode ENABLED (kernel fips_enabled=1)"
  else
    info "FIPS mode not enabled (fips_enabled=$fips_val)"
  fi
fi

if command -v fips-mode-setup &>/dev/null; then
  fips_status=$(fips-mode-setup --check 2>&1 || true)
  info "fips-mode-setup: $fips_status"
fi

# =============================================================================
SECTION "4. SSH Key Types in Use"
# =============================================================================

DEPRECATED_KEY_TYPES=("dsa" "ecdsa-sk" "ssh-rsa")   # ssh-rsa = SHA-1 legacy
PREFERRED_KEY_TYPES=("ed25519" "ecdsa" "rsa-sha2-256" "rsa-sha2-512")

# Check host keys
echo "  --- SSH Host Keys ---"
for keyfile in /etc/ssh/ssh_host_*_key.pub; do
  [ -f "$keyfile" ] || continue
  keytype=$(ssh-keygen -l -f "$keyfile" 2>/dev/null | awk '{print $4}' | tr -d '()')
  keybits=$(ssh-keygen -l -f "$keyfile" 2>/dev/null | awk '{print $1}')
  keyfile_base=$(basename "$keyfile")

  if echo "$keytype" | grep -qi "dsa"; then
    fail "Host key $keyfile_base: $keytype ($keybits bits) — DSA is deprecated"
  elif echo "$keytype" | grep -qi "rsa" && [ "${keybits:-0}" -lt 2048 ] 2>/dev/null; then
    warn "Host key $keyfile_base: RSA $keybits bits — should be >= 2048"
  elif echo "$keytype" | grep -qi "ed25519\|ecdsa"; then
    pass "Host key $keyfile_base: $keytype ($keybits bits)"
  else
    info "Host key $keyfile_base: $keytype ($keybits bits)"
  fi
done

# Check effective sshd algorithm settings
echo
echo "  --- SSHD Effective Algorithm Configuration ---"
if command -v sshd &>/dev/null; then
  sshd -T 2>/dev/null | grep -E "^(hostkeyalgorithms|pubkeyacceptedalgorithms|kexalgorithms|ciphers|macs)" | while read -r line; do
    key=$(echo "$line" | cut -d' ' -f1)
    val=$(echo "$line" | cut -d' ' -f2-)
    info "$key: $val"

    # Check for deprecated algorithms in the list
    if echo "$val" | grep -qi "ssh-rsa[^-]"; then
      warn "  -> ssh-rsa (SHA-1) present in $key — consider removing"
    fi
    if echo "$val" | grep -qi "diffie-hellman-group1\|diffie-hellman-group14-sha1"; then
      warn "  -> Weak DH algorithm in $key"
    fi
  done
fi

# Scan user authorized_keys for key types
echo
echo "  --- User Authorized Key Types ---"
LEGACY_FOUND=0
while IFS=: read -r username _ _ _ _ homedir _; do
  auth_keys="$homedir/.ssh/authorized_keys"
  [ -f "$auth_keys" ] || continue
  while read -r keytype rest; do
    [[ "$keytype" =~ ^# ]] && continue
    [ -z "$keytype" ] && continue
    if [ "$keytype" = "ssh-dss" ]; then
      warn "User $username: DSA key in authorized_keys (deprecated)"
      LEGACY_FOUND=1
    elif [ "$keytype" = "ssh-rsa" ]; then
      info "User $username: RSA key in authorized_keys (verify hash alg is sha2)"
    fi
  done < "$auth_keys" 2>/dev/null
done < /etc/passwd

[ "$LEGACY_FOUND" -eq 0 ] && pass "No DSA keys found in authorized_keys files"

# =============================================================================
SECTION "5. Deprecated Algorithm Detection"
# =============================================================================

# Check for weak cipher configurations in common config files
CONFIGS_TO_CHECK=(
  "/etc/ssh/sshd_config"
  "/etc/ssh/ssh_config"
  /etc/ssh/sshd_config.d/*.conf
  /etc/ssh/ssh_config.d/*.conf
)

echo "  --- SSH Config Deprecated Algorithm Check ---"
for cfg in "${CONFIGS_TO_CHECK[@]}"; do
  [ -f "$cfg" ] || continue

  if grep -qiE "ciphers.*3des|ciphers.*rc4|ciphers.*des-cbc" "$cfg" 2>/dev/null; then
    warn "$cfg: contains weak cipher (3DES/RC4/DES)"
  fi
  if grep -qiE "macs.*md5|macs.*sha1[^2]" "$cfg" 2>/dev/null; then
    warn "$cfg: contains MD5 or SHA-1 MAC"
  fi
  if grep -qiE "KexAlgorithms.*diffie-hellman-group1\b" "$cfg" 2>/dev/null; then
    warn "$cfg: DH Group 1 (768-bit) key exchange present"
  fi
  if grep -qiE "PermitRootLogin\s+yes" "$cfg" 2>/dev/null; then
    fail "$cfg: PermitRootLogin yes — root password login enabled"
  fi
done
pass "SSH config deprecated algorithm scan complete"

# TLS certificate check on common service ports
echo
echo "  --- TLS Protocol / Cipher Quick Check (localhost) ---"
for port in 443 8443 636 993 995; do
  if ss -tlnp | grep -q ":$port "; then
    tls_info=$(timeout 3 openssl s_client -connect "localhost:$port" \
      -brief 2>/dev/null | head -5 || true)
    if [ -n "$tls_info" ]; then
      info "Port $port TLS: $tls_info"
    fi
  fi
done

# =============================================================================
SECTION "6. SHA-1 Certificate Check (System Trust Store)"
# =============================================================================

SHA1_COUNT=0
TOTAL_COUNT=0
CA_BUNDLE="/etc/pki/tls/certs/ca-bundle.crt"

if [ -r "$CA_BUNDLE" ]; then
  info "Scanning $CA_BUNDLE for SHA-1 signed certificates..."

  # Split bundle and check each cert
  csplit -z -f /tmp/rhel9_cert_audit_ "$CA_BUNDLE" \
    '/-----BEGIN CERTIFICATE-----/' '{*}' 2>/dev/null

  for cert_file in /tmp/rhel9_cert_audit_*; do
    [ -f "$cert_file" ] || continue
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    sig_alg=$(openssl x509 -in "$cert_file" -noout -text 2>/dev/null | \
      grep "Signature Algorithm" | head -1 | awk '{print $NF}')

    if echo "$sig_alg" | grep -qi "sha1\|sha-1"; then
      subj=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | \
        sed 's/subject=//')
      warn "SHA-1 cert: $sig_alg — $subj"
      SHA1_COUNT=$((SHA1_COUNT + 1))
    fi
    rm -f "$cert_file"
  done

  if [ "$SHA1_COUNT" -eq 0 ]; then
    pass "No SHA-1 signed certificates found in system trust store ($TOTAL_COUNT certs checked)"
  else
    fail "$SHA1_COUNT SHA-1 signed certificate(s) found out of $TOTAL_COUNT total"
    info "These will be rejected by applications under DEFAULT crypto policy"
  fi
else
  warn "CA bundle not found at $CA_BUNDLE"
fi

# Check RPM database for SHA-1 signed packages
SECTION "6a. RPM Package Signature Algorithm Check"
if command -v rpm &>/dev/null; then
  info "Checking recently installed packages for weak signatures..."
  rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}: %{SIGPGP:pgpsig}\n' 2>/dev/null | \
    grep -i "sha1\b" | head -10 | while read -r line; do
      warn "Weak RPM signature: $line"
    done
  pass "RPM signature check complete"
fi

# =============================================================================
SECTION "7. PermitRootLogin Status"
# =============================================================================

root_login_setting=$(sshd -T 2>/dev/null | grep "^permitrootlogin" | awk '{print $2}')
case "$root_login_setting" in
  "no")            pass "PermitRootLogin: no (most secure)" ;;
  "prohibit-password") pass "PermitRootLogin: prohibit-password (RHEL 9 default — key auth only)" ;;
  "yes")           fail "PermitRootLogin: yes — root password login permitted (insecure)" ;;
  "without-password") info "PermitRootLogin: without-password (key auth only, alias for prohibit-password)" ;;
  *)               info "PermitRootLogin: $root_login_setting" ;;
esac

echo
echo "Crypto audit complete: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Review all [WARN] and [FAIL] items for remediation."
```

---

## Summary Reference

| Feature | RHEL 8 | RHEL 9 |
|---------|--------|--------|
| OpenSSL | 1.1.1 | 3.0 (provider model) |
| SHA-1 signatures | Allowed | Disabled by default |
| Firewall backend | iptables or nftables | nftables only |
| PermitRootLogin default | yes | prohibit-password |
| Container network stack | CNI | Netavark + Aardvark DNS |
| Remote attestation | Not included | Keylime (TPM-based) |
| WireGuard | KMOD (external) | In-kernel |
| Module streams | Extensive | Minimized (most to RPM) |
| Live patching | kpatch (manual) | kpatch-dnf (automatic) |
| Edge updates | Basic | ostree + greenboot rollback |
