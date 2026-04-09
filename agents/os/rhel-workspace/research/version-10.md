# RHEL 10 — Version-Specific Research

**Release:** May 2025 (GA)
**Codename:** Coughlan
**Kernel:** 6.12
**Support:** Full support through ~2030 | Maintenance through ~2035
**Scope:** Features NEW or significantly changed in RHEL 10 only. Cross-version fundamentals live in references/.

---

## 1. Image Mode (bootc) — Flagship Feature

### Description

RHEL 10 introduces Image Mode as a first-class deployment paradigm. Instead of installing packages onto a running OS, Image Mode treats the entire operating system as an immutable OCI container image delivered from a container registry. The system is defined by a `Containerfile`, built into a bootable container image, and deployed or updated atomically with rollback capability.

The underlying technology is `bootc` (bootable containers), which replaced the older `rpm-ostree` workflow. bootc is an image-based update client that manages the OS image lifecycle — pulling, staging, applying, and rolling back immutable system images.

### Core Concepts

- **Immutable root:** `/usr` is read-only. `/etc` and `/var` remain mutable for local config and runtime state.
- **Atomic updates:** An update stages the new image, then a reboot switches to it. The old image is retained as the rollback target.
- **Container registry as OS delivery:** The OS update pipeline becomes a container push/pull workflow. Teams use the same CI/CD tooling for OS images as for application containers.
- **Soft reboot:** systemd's `systemctl soft-reboot` restarts only userspace, not firmware/kernel, enabling near-zero-downtime image transitions when only userspace components changed.

### Building a Bootable Container Image

```dockerfile
# Containerfile — bootable RHEL 10 image
FROM registry.redhat.io/rhel10/rhel-bootc:10

# Install packages at image build time (not at deploy time)
RUN dnf install -y nginx python3-gunicorn && dnf clean all

# Drop configuration files into the image
COPY etc/nginx/nginx.conf /etc/nginx/nginx.conf

# Enable services declaratively
RUN systemctl enable nginx

# The image is the complete OS definition
```

```bash
# Build the bootable container image
podman build -t registry.example.com/myos/rhel10:v1.2 .

# Push to registry (this is your OS update artifact)
podman push registry.example.com/myos/rhel10:v1.2

# Convert container image to a disk image for bare-metal/VM provisioning
podman run --rm --privileged \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v $(pwd)/output:/output \
  registry.redhat.io/rhel10/bootc-image-builder:latest \
  --type qcow2 \
  registry.example.com/myos/rhel10:v1.2
```

### bootc Lifecycle Commands

```bash
# Check current image mode status
bootc status

# Pull and stage an update (does not apply yet)
bootc upgrade --check   # check if update available
bootc upgrade           # pull staged update

# Apply staged update on next reboot
systemctl reboot

# Soft reboot (userspace only, much faster)
systemctl soft-reboot

# Roll back to the previous image
bootc rollback

# Switch to a completely different image
bootc switch registry.example.com/myos/rhel10-hardened:v2.0

# Pin the current deployment (prevent auto-updates from replacing it)
bootc status --format json | jq '.status.booted.image'
```

### bootc vs rpm-ostree

| Aspect | rpm-ostree (RHEL 9 OSTree) | bootc (RHEL 10 Image Mode) |
|---|---|---|
| Image format | OSTree commit | OCI container image |
| Registry | OSTree repo | Standard container registry |
| Toolchain | rpm-ostree CLI | bootc CLI + standard container tools |
| Base image source | Fedora CoreOS / RHCOS | rhel-bootc OCI image |
| Layering | rpm-ostree install (client-side) | Containerfile (build-time) |
| Kubernetes/GitOps fit | Limited | Native (same registry, same tools) |

### Traditional vs Image Mode Comparison

| Aspect | Traditional RHEL (package mode) | Image Mode (bootc) |
|---|---|---|
| Package installation | `dnf install` on running system | `RUN dnf install` in Containerfile |
| OS update mechanism | `dnf upgrade` + reboot | `bootc upgrade` + reboot |
| Rollback | Snapshot (if configured) | Atomic: previous image always retained |
| Config management | Ansible/Puppet push to live system | Baked into image; immutable |
| Fleet consistency | Drift accumulates over time | Every node runs identical image |
| Audit | Package history logs | Container image SHA digest |

### Use Cases

- **Cloud fleets:** Provision hundreds of identical VMs from a single bootable image; upgrade by rotating the registry tag.
- **Edge devices:** Ship OS + application as one artifact; near-zero-downtime updates via soft reboot.
- **Security-hardened baselines:** STIG/CIS hardening baked into image at build time; no post-deploy drift.
- **Immutable infrastructure:** Replace mutable configuration management with image promotion pipelines.

### Impact Notes

- Packages cannot be installed with `dnf` on a running Image Mode system (the `rpm-ostree` overlay approach is gone).
- SSH access for debugging is still available; `toolbox` or `distrobox` provides a mutable container overlay for developer tools.
- SELinux contexts are embedded in the image; transitions are automatic on bootc switch.

---

## 2. x86-64-v3 Baseline

### Description

RHEL 10 drops support for x86-64-v2 (the baseline used by RHEL 7–9) and requires the x86-64-v3 microarchitecture level. This eliminates support for processors older than Intel Haswell (2013) and AMD Excavator (2015).

### x86-64 Microarchitecture Levels

| Level | Required ISA extensions | Example CPUs |
|---|---|---|
| v1 | Baseline x86-64 | Any x86-64 CPU |
| v2 | SSE3, SSE4.1/4.2, SSSE3, POPCNT | Sandy Bridge (2011), Bulldozer (2011) |
| **v3** | **AVX, AVX2, BMI1/2, FMA, MOVBE, XSAVE** | **Haswell (2013), Excavator (2015)** |
| v4 | AVX-512 | Skylake-X, Ice Lake (data center) |

### Checking CPU Compatibility

```bash
# Check if current CPU meets x86-64-v3 requirements
# All of these flags must be present in /proc/cpuinfo
grep -m1 'flags' /proc/cpuinfo | tr ' ' '\n' | grep -E '^(avx|avx2|bmi1|bmi2|fma|movbe|xsave)$'

# One-liner: returns "CPU supports x86-64-v3" or lists missing flags
python3 -c "
required = {'avx', 'avx2', 'bmi1', 'bmi2', 'fma', 'movbe', 'xsave'}
flags = set(open('/proc/cpuinfo').read().split())
missing = required - flags
print('x86-64-v3 supported' if not missing else f'Missing: {missing}')
"

# Alternatively, use ld.so self-check (on a RHEL 10 system)
/lib64/ld-linux-x86-64.so.2 --help | grep 'x86-64-v3'
```

### Performance Benefits

The v3 baseline allows the compiler and libraries to use AVX2 and FMA unconditionally, without runtime dispatching. Key gains:

- **Crypto:** AES-NI + CLMUL + AVX2 vectorized SHA accelerates TLS, disk encryption, RPM verification
- **Compression:** zstd, zlib, lz4 leverage AVX2 for ~30–50% throughput gain over scalar paths
- **glibc:** string operations (memcpy, strlen, strcmp) use 256-bit AVX2 paths by default
- **OpenSSL:** AES-GCM and SHA-256 run full-width vectorized on all supported hardware

### Impact on Older Hardware

Systems running CPUs older than Haswell/Excavator cannot run RHEL 10 at all. The installer will abort. Use RHEL 9 (extended support through 2032) for legacy hardware.

---

## 3. Post-Quantum Cryptography (PQC)

### Description

RHEL 10 is the first RHEL release with FIPS-validated post-quantum cryptographic algorithms. The threat model driving this is "harvest now, decrypt later" — adversaries store encrypted traffic today to decrypt when quantum computers become capable. Long-lived secrets (government, financial, PKI roots) must be protected now.

RHEL 10 ships NIST-standardized PQC algorithms in OpenSSL 3.x and OpenSSH:

- **ML-KEM** (Module Lattice Key Encapsulation Mechanism) — formerly Kyber. Used for key exchange in TLS and SSH.
- **ML-DSA** (Module Lattice Digital Signature Algorithm) — formerly Dilithium. Used for digital signatures.
- **SLH-DSA** (Stateless Hash-based Digital Signature Algorithm) — formerly SPHINCS+. Backup signature scheme.

### OpenSSL PQC Configuration

```bash
# Check OpenSSL version and PQC provider support
openssl version -a
openssl list -providers
openssl list -kem-algorithms | grep -i 'kyber\|mlkem\|ML-KEM'
openssl list -signature-algorithms | grep -i 'dilithium\|mldsa\|ML-DSA'

# Test ML-KEM key generation
openssl genpkey -algorithm ML-KEM-768 -out mlkem-private.pem
openssl pkey -in mlkem-private.pem -pubout -out mlkem-public.pem

# Test ML-DSA key generation and signing
openssl genpkey -algorithm ML-DSA-65 -out mldsa-private.pem
openssl dgst -sign mldsa-private.pem -out sig.bin /etc/os-release
openssl dgst -verify mldsa-public.pem -signature sig.bin /etc/os-release

# Check FIPS mode (PQC algorithms have conditional FIPS approval)
fips-mode-setup --check
openssl list -providers | grep -i fips
```

### OpenSSH PQC Key Exchange

```bash
# Check SSH PQC KEX algorithms available
ssh -Q kex | grep -i 'kyber\|mlkem'

# Configure sshd for hybrid PQC key exchange (PQC + classical)
# /etc/ssh/sshd_config
# KexAlgorithms mlkem768x25519-sha256,ecdh-sha2-nistp256,diffie-hellman-group14-sha256

# Generate SSH keypair using ML-DSA (if host key type supported)
ssh-keygen -t ecdsa -b 256    # Classical (still valid)
# PQC SSH host keys: check OpenSSH version in RHEL 10 for exact support

# Verify active KEX on a connection
ssh -vv user@host 2>&1 | grep 'kex:'
```

### FIPS and PQC Interaction

FIPS 140-3 validation for PQC is in progress through NIST's CMVP as of RHEL 10 GA. Some PQC algorithms may be available without FIPS mode initially; check Red Hat security advisories for current FIPS validation status. The system crypto policy sub-policy `PQ` enables PQC preferences:

```bash
# Set crypto policy with PQC sub-policy
update-crypto-policies --set DEFAULT:PQ

# Verify active policy
update-crypto-policies --show

# Check if PQC sub-policy is available
ls /usr/share/crypto-policies/policies/modules/ | grep -i pq
```

---

## 4. RHEL Lightspeed

### Description

RHEL Lightspeed is an AI-powered assistant for Linux administration, integrated into the RHEL 10 experience via CLI and Cockpit. It accepts natural language questions and returns explanations, commands, and runbooks relevant to RHEL administration tasks.

### CLI Integration

```bash
# Install the Lightspeed CLI plugin (requires subscription)
dnf install rhel-lightspeed-cli

# Ask a question in natural language
rhel-lightspeed "how do I check which SELinux booleans are enabled for httpd"

# Get a suggested command with explanation
rhel-lightspeed "find all files modified in the last 24 hours larger than 100MB"

# Pipe command output for analysis
journalctl -u nginx --since "1 hour ago" | rhel-lightspeed "explain these errors"
```

### Cockpit Integration

Lightspeed appears as a chat panel in the Cockpit web console. Administrators can ask questions in context — for example, on the Storage page, Lightspeed understands the current disk layout and can suggest specific commands.

### Capabilities and Limitations

**Capabilities:**
- Explains unfamiliar log messages in plain English
- Suggests dnf, nmcli, systemctl, firewalld, SELinux commands
- Generates Ansible playbooks for described tasks
- Provides runbooks for common RHEL troubleshooting scenarios

**Limitations:**
- Requires Red Hat subscription and internet connectivity to the Lightspeed service
- Not a replacement for documentation; verify suggested commands before execution
- Does not have access to your specific system state unless you pipe output to it
- Answers are non-deterministic; the same question may yield different phrasings

### Privacy and Data Handling

- Queries and piped content are sent to Red Hat's Lightspeed service (hosted on AWS/Azure)
- Red Hat's data handling policy: query content used to improve the model; review the subscription agreement for data retention specifics
- Air-gapped environments: Lightspeed requires connectivity; not available offline without a private model deployment (enterprise option)

---

## 5. DNS over HTTPS (DoH) and DNS over TLS (DoT)

### Description

RHEL 10 enables encrypted DNS resolution by default using `systemd-resolved` as the primary DNS resolver. DoH (port 443) and DoT (port 853) encrypt DNS queries, preventing eavesdropping and tampering on the network path between client and resolver.

### Configuration

```bash
# Check systemd-resolved status
systemctl status systemd-resolved
resolvectl status

# Configure DoT in /etc/systemd/resolved.conf
# [Resolve]
# DNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
# DNSOverTLS=yes
# DNSSEC=yes

systemctl restart systemd-resolved

# Verify encrypted DNS is active
resolvectl query --legend=no redhat.com
resolvectl statistics | grep -i 'dnsovertls\|DoT'

# Test DoH via stub resolver
dig @127.0.0.53 redhat.com    # Goes through systemd-resolved stub

# Check current DNS protocol in use
resolvectl log-level debug
journalctl -u systemd-resolved -f | grep -i 'tls\|https'
```

### Enterprise DNS Impact

Encrypted DNS bypasses traditional DNS inspection appliances (firewalls, DLP, split-horizon DNS servers) that rely on plaintext DNS traffic. Enterprise deployments typically override the default encrypted resolver with an internal DNS server:

```bash
# Override DNS for a specific connection (nmcli)
nmcli con mod "eth0" ipv4.dns "10.10.1.53"
nmcli con mod "eth0" ipv4.ignore-auto-dns yes
nmcli con up "eth0"

# Disable DoT globally (if using internal resolver without TLS support)
# /etc/systemd/resolved.conf
# [Resolve]
# DNSOverTLS=no

# NetworkManager controls resolved settings per-interface
# /etc/NetworkManager/conf.d/dns.conf
# [main]
# dns=systemd-resolved
```

---

## 6. Module Streams Removed (DNF Modularity Dropped)

### Description

RHEL 10 completely removes DNF modularity — the `dnf module` command and the module stream concept are gone. AppStreams continue to exist but are delivered as traditional RPM packages with standard versioned package names, not as module streams requiring `dnf module enable`.

### What Changed

| RHEL 9 (Modularity) | RHEL 10 (No Modularity) |
|---|---|
| `dnf module enable nodejs:18` | `dnf install nodejs18` (or `nodejs`) |
| `dnf module list` | No equivalent; use `dnf list` |
| `dnf module install postgresql:15/server` | `dnf install postgresql15-server` |
| Stream profiles (default, devel, minimal) | Install specific package names |
| Module metadata in repo | Standard RPM metadata only |

### Migration Guidance

```bash
# RHEL 9: List enabled modules
dnf module list --enabled    # Not available in RHEL 10

# RHEL 10: Equivalent — list installed AppStream packages
dnf list installed | grep -E 'nodejs|postgresql|php|ruby'

# RHEL 9 pattern → RHEL 10 equivalent
# dnf module enable nodejs:20 && dnf install nodejs
# → dnf install nodejs20   (or whatever RHEL 10 ships)

# Check available versions of a package
dnf list available 'nodejs*'
dnf provides nodejs

# No dnf module commands exist; scripts using them will error
# Audit automation scripts for 'dnf module' before upgrading
grep -r 'dnf module' /etc/cron* /etc/ansible /usr/local/bin/ 2>/dev/null
```

### Impact on Automation and Scripts

Any Ansible playbooks, shell scripts, Kickstart files, or Puppet manifests that use `dnf module enable/install/reset` will break on RHEL 10. Audit all automation before migrating:

- Replace `dnf module enable X:Y` + `dnf install pkg` with `dnf install pkgversion`
- Replace `community.general.dnf_module` Ansible tasks with `ansible.builtin.dnf`
- Kickstart `module --enable` syntax is not supported in RHEL 10 Anaconda

---

## 7. VNC Replaced by RDP for Graphical Remote Access

### Description

RHEL 10 removes the VNC server (`tigervnc-server`) from the default graphical remote access stack and replaces it with RDP (Remote Desktop Protocol) via GNOME Remote Desktop (backed by Mutter's RDP implementation). The system still supports VNC as a compatibility option but RDP is the preferred and supported path.

### RDP Configuration

```bash
# Enable GNOME Remote Desktop (RDP)
systemctl enable --now gnome-remote-desktop

# Configure RDP via gsettings (per-user, run as the desktop user)
gsettings set org.gnome.desktop.remote-desktop.rdp enable true
gsettings set org.gnome.desktop.remote-desktop.rdp tls-cert '/etc/gnome-remote-desktop/server.crt'
gsettings set org.gnome.desktop.remote-desktop.rdp tls-key '/etc/gnome-remote-desktop/server.key'

# Generate TLS certificate for RDP (self-signed for testing)
openssl req -newkey rsa:4096 -x509 -days 365 -nodes \
  -out /etc/gnome-remote-desktop/server.crt \
  -keyout /etc/gnome-remote-desktop/server.key

# Open RDP port in firewalld
firewall-cmd --permanent --add-service=rdp    # port 3389/tcp
firewall-cmd --reload
firewall-cmd --list-services | grep rdp

# Verify RDP is listening
ss -tlnp | grep 3389
```

### Client Compatibility

Any standards-compliant RDP client works:
- **Windows:** Built-in Remote Desktop Connection (`mstsc.exe`)
- **macOS:** Microsoft Remote Desktop (App Store)
- **Linux:** Remmina with RDP plugin, FreeRDP (`xfreerdp`)
- **Web:** Apache Guacamole with RDP backend

### headless / Server Environments

For servers without a running GNOME session, RDP requires a pre-existing graphical session or virtual framebuffer. Cockpit remains the preferred headless web-based management interface.

---

## 8. NetworkManager Required — Legacy Network Scripts Removed

### Description

RHEL 10 removes `network-scripts` entirely. The `ifcfg-*` configuration format (historically in `/etc/sysconfig/network-scripts/`) is gone. All network configuration is done through NetworkManager using the `keyfile` format stored in `/etc/NetworkManager/system-connections/`.

### ifcfg to keyfile Migration

```bash
# Check for legacy ifcfg files before upgrading
ls /etc/sysconfig/network-scripts/ifcfg-* 2>/dev/null

# RHEL 9: Convert existing ifcfg connections to keyfile format
nmcli connection migrate

# After migration, verify connections in new location
ls /etc/NetworkManager/system-connections/
cat /etc/NetworkManager/system-connections/eth0.nmconnection

# Example keyfile format (RHEL 10 native)
# [connection]
# id=eth0
# type=ethernet
# interface-name=eth0
#
# [ethernet]
#
# [ipv4]
# method=manual
# address1=192.168.1.100/24,192.168.1.1
# dns=8.8.8.8;8.8.4.4;
#
# [ipv6]
# method=auto

# Common NetworkManager operations
nmcli connection show                      # List all connections
nmcli connection show --active             # Active connections only
nmcli con add type ethernet ifname eth0 con-name eth0-static \
  ip4 192.168.1.100/24 gw4 192.168.1.1   # Add static connection
nmcli con mod eth0-static ipv4.dns "8.8.8.8 8.8.4.4"
nmcli con up eth0-static
nmtui                                      # Terminal UI for non-CLI users
```

### Scripts and Automation Impact

- Kickstart files using `network --bootproto=static --device=eth0` still work (Anaconda translates to NM)
- Ansible `ansible.builtin.network_cli` and `community.general.nmcli` module work correctly
- Scripts sourcing `/etc/sysconfig/network-scripts/ifcfg-*` files will fail — rewrite to use `nmcli`
- `ifup` / `ifdown` commands are gone; use `nmcli con up / con down`

---

## 9. Podman 5.x

### Description

RHEL 10 ships Podman 5.x, a major version jump from the Podman 4.x in RHEL 9. Key improvements relevant to production deployments:

### Quadlet (systemd Integration)

Quadlet replaces the older `podman generate systemd` workflow. Unit files are defined as `.container`, `.pod`, `.volume`, or `.network` files and processed by `podman-systemd-generator` into native systemd units.

```bash
# Create a Quadlet container unit
mkdir -p ~/.config/containers/systemd/
cat > ~/.config/containers/systemd/myapp.container << 'EOF'
[Unit]
Description=My Application Container
After=network-online.target

[Container]
Image=registry.example.com/myapp:latest
PublishPort=8080:8080
Volume=/data/myapp:/app/data:Z
Environment=APP_ENV=production
AutoUpdate=registry

[Service]
Restart=always

[Install]
WantedBy=default.target
EOF

# Reload and start
systemctl --user daemon-reload
systemctl --user enable --now myapp.container

# Check status
systemctl --user status myapp.container
```

### Kubernetes YAML Support Improvements

```bash
# Run a Kubernetes Pod YAML directly with Podman
podman kube play deployment.yaml

# Generate Kubernetes YAML from running containers/pods
podman kube generate mypod > pod.yaml

# Tear down Kubernetes workload
podman kube down deployment.yaml
```

### Podman Machine (Desktop/WSL)

```bash
# Podman Machine improvements (for macOS/Windows dev environments)
podman machine init --cpus 4 --memory 8192 --disk-size 50
podman machine start
podman machine list
podman machine ssh
```

### Compose v2 Support

```bash
# Podman Compose v2 (docker-compose compatibility)
dnf install podman-compose

# docker-compose.yml files run unmodified
podman compose up -d
podman compose ps
podman compose logs -f
```

---

## 10. RISC-V Developer Preview

### Description

RHEL 10 includes a RISC-V Developer Preview — the first RHEL release with any RISC-V support. This is not a production-supported architecture; it is a technology preview aimed at developers building software for RISC-V hardware.

### Scope and Limitations

- **Target hardware:** SiFive HiFive boards, StarFive VisionFive 2, QEMU RISC-V emulation
- **Architecture profile:** RV64GC (64-bit, G=general-purpose ISA, C=compressed instructions)
- **Not FIPS certified** on RISC-V in RHEL 10
- **No live migration, limited HA support** — tech preview only
- Package set is smaller than x86-64; some packages not yet ported

### Developer Use

```bash
# Cross-compile for RISC-V from x86-64 RHEL 10
dnf install gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu

# Or use QEMU for emulation
dnf install qemu-system-riscv
qemu-system-riscv64 -machine virt -cpu rv64 -m 2G \
  -bios /usr/share/qemu/opensbi-riscv64-generic-fw_dynamic.bin \
  -drive file=rhel10-riscv.qcow2,format=qcow2
```

---

## 11. WSL Support (Windows Subsystem for Linux)

### Description

RHEL 10 provides official WSL (Windows Subsystem for Linux) images, allowing developers on Windows to run a RHEL 10 environment without a VM. This is distinct from enterprise server deployments but useful for developer consistency (same OS as production).

### Setup

```powershell
# Windows PowerShell — register RHEL 10 WSL image
# Download the WSL image from Red Hat's customer portal or access.redhat.com
wsl --import RHEL10 C:\WSL\RHEL10 rhel10-wsl.tar.gz

# Launch
wsl -d RHEL10

# Set as default distribution
wsl --set-default RHEL10
```

```bash
# Inside WSL RHEL 10 — register subscription
subscription-manager register --username <rhn-user>
dnf update -y

# WSL-specific: systemd support (WSL2 with systemd enabled)
# /etc/wsl.conf
# [boot]
# systemd=true

# Verify
systemctl status    # Works with systemd in WSL2
```

### Use Cases

- Developer environments matching RHEL 10 production servers
- Testing RPM packages and systemd units locally before deployment
- Running RHEL container builds (`podman build`) in a RHEL-native environment on Windows

---

## 12. Removed and Deprecated Features

### 32-bit Package Support Dropped

RHEL 10 no longer ships 32-bit (i686) userspace packages. Only 64-bit (x86-64-v3) packages are supported. Impact:

- 32-bit application binaries will not run without compatibility layers not provided by RHEL 10
- Wine and similar compatibility tools must ship their own 32-bit runtime
- `dnf install glibc.i686` will fail — no i686 packages in repos

### SysV Init Scripts Removed

- `/etc/init.d/` scripts are no longer supported
- `service <name> start` (legacy SysV wrapper) is removed
- All services must use systemd unit files
- Audit: `ls /etc/init.d/` on migrating systems; convert to `.service` units

### Python 2 Completely Removed

- No `python2` package, no `/usr/bin/python2` symlink
- `python` command points to Python 3 only
- Scripts with `#!/usr/bin/python` shebangs get Python 3 (check for incompatibilities)
- `dnf install python2` will fail

### Other Notable Removals

| Removed | Replacement |
|---|---|
| `ifcfg-*` network scripts | NetworkManager keyfile format |
| `tigervnc-server` (default) | GNOME Remote Desktop (RDP) |
| `dnf module` commands | Standard RPM versioned package names |
| `rpm-ostree` (for Image Mode) | `bootc` |
| NTP `ntpd` service | `chronyd` (already default since RHEL 7, now only option) |
| `iptables` legacy tables | `nftables` only (firewalld backend) |
| PHP 7.x | PHP 8.x |
| Python 3.9 as default | Python 3.12 |

---

## 13. Diagnostic Scripts

### Script 10: bootc-status.sh

```bash
#!/usr/bin/env bash
# ============================================================
# RHEL 10 Image Mode (bootc) Status Diagnostic
# ============================================================
# Version:  10.1.0
# Targets:  RHEL 10.x (Image Mode / bootc deployments)
# Purpose:  Detect image mode, report current/staged/rollback
#           images, container registry config, soft-reboot state
# Usage:    sudo bash 10-bootc-status.sh
# ============================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}=== $* ===${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}  $*"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET} $*"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET} $*"; }
info()   { echo -e "  [INFO] $*"; }

echo -e "${BOLD}RHEL 10 Image Mode (bootc) Status Report${RESET}"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f)"

# ---- 1. Detect Image Mode ----
header "1. Image Mode Detection"

if command -v bootc &>/dev/null; then
    ok "bootc binary found: $(bootc --version 2>/dev/null || echo 'version unknown')"
    BOOTC_AVAILABLE=true
else
    warn "bootc not installed — this system may be in traditional package mode"
    BOOTC_AVAILABLE=false
fi

# Check for ostree (would indicate older rpm-ostree based deployment)
if command -v rpm-ostree &>/dev/null; then
    warn "rpm-ostree found — this may be an older OSTree deployment, not bootc"
fi

# Detect if running from an OCI/bootc image vs traditional rootfs
if [[ -f /run/ostree-booted ]]; then
    ok "System is booted from an immutable image (ostree/bootc)"
elif [[ "$BOOTC_AVAILABLE" == "true" ]]; then
    warn "bootc available but /run/ostree-booted not present — verify image mode"
else
    info "Traditional (package-based) RHEL installation detected"
fi

# ---- 2. Current Image Status ----
header "2. Current Booted Image"

if [[ "$BOOTC_AVAILABLE" == "true" ]]; then
    echo ""
    if bootc status 2>/dev/null; then
        echo ""
        # Parse JSON for structured output
        if command -v jq &>/dev/null; then
            BOOTC_JSON=$(bootc status --format json 2>/dev/null || echo '{}')
            BOOTED_IMAGE=$(echo "$BOOTC_JSON" | jq -r '.status.booted.image.image.image // "unknown"' 2>/dev/null)
            BOOTED_DIGEST=$(echo "$BOOTC_JSON" | jq -r '.status.booted.image.imageDigest // "unknown"' 2>/dev/null)
            info "Booted image:  $BOOTED_IMAGE"
            info "Image digest:  $BOOTED_DIGEST"
        fi
    else
        warn "bootc status returned non-zero — system may not be in image mode"
    fi
else
    info "bootc not available; skipping image status check"
fi

# ---- 3. Staged Update ----
header "3. Staged Update"

if [[ "$BOOTC_AVAILABLE" == "true" ]] && command -v jq &>/dev/null; then
    BOOTC_JSON=$(bootc status --format json 2>/dev/null || echo '{}')
    STAGED=$(echo "$BOOTC_JSON" | jq -r '.status.staged // null' 2>/dev/null)
    if [[ "$STAGED" != "null" && -n "$STAGED" ]]; then
        STAGED_IMAGE=$(echo "$BOOTC_JSON" | jq -r '.status.staged.image.image.image // "unknown"')
        STAGED_DIGEST=$(echo "$BOOTC_JSON" | jq -r '.status.staged.image.imageDigest // "unknown"')
        warn "Staged update pending:"
        info "  Image:  $STAGED_IMAGE"
        info "  Digest: $STAGED_DIGEST"
        info "  Apply:  reboot  (or 'systemctl soft-reboot' for userspace-only updates)"
    else
        ok "No staged update — system is current"
    fi
else
    info "jq not available or bootc absent; skipping staged update check"
fi

# ---- 4. Rollback Target ----
header "4. Rollback Target"

if [[ "$BOOTC_AVAILABLE" == "true" ]] && command -v jq &>/dev/null; then
    BOOTC_JSON=$(bootc status --format json 2>/dev/null || echo '{}')
    ROLLBACK=$(echo "$BOOTC_JSON" | jq -r '.status.rollback // null' 2>/dev/null)
    if [[ "$ROLLBACK" != "null" && -n "$ROLLBACK" ]]; then
        ROLLBACK_IMAGE=$(echo "$BOOTC_JSON" | jq -r '.status.rollback.image.image.image // "unknown"')
        ROLLBACK_DIGEST=$(echo "$BOOTC_JSON" | jq -r '.status.rollback.image.imageDigest // "unknown"')
        ok "Rollback target available:"
        info "  Image:  $ROLLBACK_IMAGE"
        info "  Digest: $ROLLBACK_DIGEST"
        info "  Rollback: bootc rollback && reboot"
    else
        warn "No rollback target — cannot revert if update fails"
    fi
else
    info "Skipping rollback check"
fi

# ---- 5. Container Registry Configuration ----
header "5. Container Registry Config"

# Check for registries.conf
if [[ -f /etc/containers/registries.conf ]]; then
    ok "Container registries config: /etc/containers/registries.conf"
    info "Unqualified search registries:"
    grep -E 'unqualified-search-registries' /etc/containers/registries.conf | head -5 | sed 's/^/    /'
else
    warn "/etc/containers/registries.conf not found"
fi

# Check for auth config (registry credentials)
AUTH_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/containers/auth.json"
if [[ -f "$AUTH_FILE" ]]; then
    ok "Registry auth config found: $AUTH_FILE"
    info "Configured registries: $(jq -r '.auths | keys[]' "$AUTH_FILE" 2>/dev/null | tr '\n' ' ')"
elif [[ -f /etc/containers/auth.json ]]; then
    ok "System-wide registry auth: /etc/containers/auth.json"
else
    warn "No registry auth config found — pull from private registries will fail"
fi

# ---- 6. Soft Reboot Readiness ----
header "6. Soft Reboot Readiness"

# Check systemd version (soft-reboot added in systemd 254)
SYSTEMD_VER=$(systemctl --version | head -1 | awk '{print $2}')
if (( SYSTEMD_VER >= 254 )); then
    ok "systemd $SYSTEMD_VER supports soft-reboot"
    info "Command: systemctl soft-reboot"
else
    warn "systemd $SYSTEMD_VER — soft-reboot requires v254+; update systemd"
fi

# Check if a staged image is present (soft-reboot only useful if update is staged)
if [[ "$BOOTC_AVAILABLE" == "true" ]] && command -v jq &>/dev/null; then
    STAGED_CHECK=$(bootc status --format json 2>/dev/null | jq -r '.status.staged // "null"')
    if [[ "$STAGED_CHECK" != "null" ]]; then
        ok "Staged update present — soft-reboot will apply userspace changes"
        info "Use 'systemctl soft-reboot' for near-zero downtime update"
    fi
fi

# ---- 7. Auto-Update Configuration ----
header "7. Auto-Update (bootc-fetch-apply-updates)"

if systemctl is-enabled bootc-fetch-apply-updates.timer &>/dev/null; then
    ok "bootc auto-update timer is enabled"
    systemctl status bootc-fetch-apply-updates.timer --no-pager -l | grep -E 'Active|Trigger' | sed 's/^/    /'
elif systemctl list-timers 2>/dev/null | grep -q bootc; then
    warn "bootc timer exists but is not enabled"
else
    info "No bootc auto-update timer configured (manual updates only)"
fi

echo ""
echo -e "${BOLD}--- Summary ---${RESET}"
if [[ "$BOOTC_AVAILABLE" == "true" ]]; then
    echo "System is running in Image Mode (bootc). Use 'bootc upgrade' to stage updates."
else
    echo "System is in traditional package mode. Image Mode not applicable."
fi
echo ""
```

---

### Script 11: pqc-crypto-audit.sh

```bash
#!/usr/bin/env bash
# ============================================================
# RHEL 10 Post-Quantum Cryptography (PQC) Audit
# ============================================================
# Version:  10.1.0
# Targets:  RHEL 10.x
# Purpose:  Audit PQC availability in OpenSSL and OpenSSH,
#           FIPS mode with PQC, and crypto policy PQC sub-policy
# Usage:    bash 11-pqc-crypto-audit.sh
# ============================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}=== $* ===${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}  $*"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET} $*"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET} $*"; }
info()   { echo -e "  [INFO] $*"; }

echo -e "${BOLD}RHEL 10 Post-Quantum Cryptography Audit${RESET}"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f)"

# ---- 1. OpenSSL Version and Providers ----
header "1. OpenSSL Version and Providers"

if command -v openssl &>/dev/null; then
    OPENSSL_VER=$(openssl version)
    ok "OpenSSL: $OPENSSL_VER"

    echo ""
    info "Loaded providers:"
    openssl list -providers 2>/dev/null | grep -E 'name:|status:' | sed 's/^/    /' || \
        warn "Could not list providers"

    # Check for OQS provider (Open Quantum Safe)
    if openssl list -providers 2>/dev/null | grep -qi 'oqs\|quantum'; then
        ok "OQS (Open Quantum Safe) provider detected"
    else
        info "OQS provider not detected — PQC may be in the default provider (OpenSSL 3.x)"
    fi
else
    fail "OpenSSL not found"
fi

# ---- 2. PQC Key Encapsulation (ML-KEM / Kyber) ----
header "2. ML-KEM (Kyber) Key Encapsulation Availability"

PQC_KEM_FOUND=false
for alg in ML-KEM-512 ML-KEM-768 ML-KEM-1024; do
    if openssl list -kem-algorithms 2>/dev/null | grep -qi "$alg"; then
        ok "$alg available"
        PQC_KEM_FOUND=true
    else
        warn "$alg NOT available"
    fi
done

if [[ "$PQC_KEM_FOUND" == "true" ]]; then
    echo ""
    info "Test ML-KEM-768 key generation:"
    if openssl genpkey -algorithm ML-KEM-768 -out /tmp/mlkem-test.pem 2>/dev/null; then
        ok "ML-KEM-768 key generation: SUCCESS"
        openssl pkey -in /tmp/mlkem-test.pem -noout -text 2>/dev/null | grep -i 'key\|type\|level' | head -5 | sed 's/^/    /'
        rm -f /tmp/mlkem-test.pem
    else
        fail "ML-KEM-768 key generation FAILED"
    fi
else
    warn "No ML-KEM algorithms found in this OpenSSL installation"
    info "Ensure openssl-oqs-provider or equivalent is installed"
fi

# ---- 3. PQC Digital Signatures (ML-DSA / Dilithium) ----
header "3. ML-DSA (Dilithium) Signature Availability"

PQC_SIG_FOUND=false
for alg in ML-DSA-44 ML-DSA-65 ML-DSA-87; do
    if openssl list -signature-algorithms 2>/dev/null | grep -qi "$alg"; then
        ok "$alg available"
        PQC_SIG_FOUND=true
    else
        warn "$alg NOT available"
    fi
done

if [[ "$PQC_SIG_FOUND" == "true" ]]; then
    echo ""
    info "Test ML-DSA-65 sign/verify:"
    if openssl genpkey -algorithm ML-DSA-65 -out /tmp/mldsa-test.pem 2>/dev/null; then
        openssl pkey -in /tmp/mldsa-test.pem -pubout -out /tmp/mldsa-pub.pem 2>/dev/null
        echo "test data" > /tmp/pqc-test.txt
        if openssl dgst -sign /tmp/mldsa-test.pem -out /tmp/pqc-sig.bin /tmp/pqc-test.txt 2>/dev/null && \
           openssl dgst -verify /tmp/mldsa-pub.pem -signature /tmp/pqc-sig.bin /tmp/pqc-test.txt 2>/dev/null; then
            ok "ML-DSA-65 sign + verify: SUCCESS"
        else
            fail "ML-DSA-65 sign/verify FAILED"
        fi
        rm -f /tmp/mldsa-test.pem /tmp/mldsa-pub.pem /tmp/pqc-test.txt /tmp/pqc-sig.bin
    else
        fail "ML-DSA-65 key generation FAILED"
    fi
fi

# SLH-DSA check
for alg in SLH-DSA-SHA2-128s SLH-DSA-SHA2-256s; do
    if openssl list -signature-algorithms 2>/dev/null | grep -qi "$alg"; then
        ok "$alg (SLH-DSA/SPHINCS+) available"
    else
        info "$alg not available (optional)"
    fi
done

# ---- 4. OpenSSH PQC Key Exchange ----
header "4. OpenSSH PQC Key Exchange Algorithms"

if command -v ssh &>/dev/null; then
    SSH_VER=$(ssh -V 2>&1)
    ok "SSH: $SSH_VER"
    echo ""

    # List PQC-related KEX algorithms
    info "Available PQC key exchange algorithms:"
    ssh -Q kex 2>/dev/null | grep -iE 'kyber|mlkem|ntru|sntrup' | sed 's/^/    /' || \
        warn "No PQC KEX algorithms found in ssh -Q kex"

    # Check for hybrid PQC+classical KEX (most common deployment)
    if ssh -Q kex 2>/dev/null | grep -qi 'mlkem\|kyber'; then
        ok "Hybrid PQC KEX (ML-KEM/Kyber) available for SSH"
    else
        warn "Hybrid PQC KEX not found — SSH connections use classical key exchange only"
    fi

    # sshd_config KEX setting
    echo ""
    info "Current sshd KexAlgorithms setting:"
    if [[ -f /etc/ssh/sshd_config ]]; then
        grep -E '^KexAlgorithms' /etc/ssh/sshd_config | sed 's/^/    /' || \
            info "    KexAlgorithms not explicitly set (using OpenSSH defaults)"
        grep -r 'KexAlgorithms' /etc/ssh/sshd_config.d/ 2>/dev/null | sed 's/^/    /' || true
    fi
else
    fail "ssh binary not found"
fi

# ---- 5. FIPS Mode Status ----
header "5. FIPS Mode and PQC Interaction"

# Check FIPS mode
if [[ -f /proc/sys/crypto/fips_enabled ]]; then
    FIPS_VAL=$(cat /proc/sys/crypto/fips_enabled)
    if [[ "$FIPS_VAL" == "1" ]]; then
        ok "FIPS mode: ENABLED"
        warn "PQC FIPS validation status: CMVP validation for ML-KEM/ML-DSA may be pending"
        info "Check Red Hat security advisories for current FIPS 140-3 certification status of PQC"
        info "Some PQC algorithms may be restricted or unavailable in FIPS mode until validated"
    else
        info "FIPS mode: DISABLED"
        info "PQC algorithms available without FIPS restriction"
    fi
else
    warn "/proc/sys/crypto/fips_enabled not found — cannot determine FIPS state"
fi

# fips-mode-setup tool
if command -v fips-mode-setup &>/dev/null; then
    info "fips-mode-setup status:"
    fips-mode-setup --check 2>&1 | sed 's/^/    /' || true
fi

# ---- 6. Crypto Policy PQC Sub-Policy ----
header "6. System Crypto Policy with PQC Sub-Policy"

if command -v update-crypto-policies &>/dev/null; then
    CURRENT_POLICY=$(update-crypto-policies --show 2>/dev/null || echo "unknown")
    ok "Current crypto policy: $CURRENT_POLICY"

    echo ""
    info "Available policies and modules:"
    update-crypto-policies --list 2>/dev/null | sed 's/^/    /' || true

    # Check for PQ sub-policy
    if ls /usr/share/crypto-policies/policies/modules/ 2>/dev/null | grep -qi 'pq\|postquantum\|quantum'; then
        ok "PQ crypto policy module available"
        info "Available PQ-related modules:"
        ls /usr/share/crypto-policies/policies/modules/ | grep -iE 'pq|quantum' | sed 's/^/    /'
        echo ""
        info "To enable PQC sub-policy: update-crypto-policies --set DEFAULT:PQ"
        info "To apply without reboot:  update-crypto-policies --apply"
    else
        warn "PQ crypto policy module not found in /usr/share/crypto-policies/policies/modules/"
        info "Install crypto-policies-pqc package if available, or check RHEL 10 errata"
    fi

    # Show current policy details
    echo ""
    info "Active policy file:"
    if [[ -f /etc/crypto-policies/state/CURRENT.pol ]]; then
        head -20 /etc/crypto-policies/state/CURRENT.pol 2>/dev/null | sed 's/^/    /' || true
    fi
else
    warn "update-crypto-policies not found"
fi

# ---- 7. PQC Package Inventory ----
header "7. PQC-Related Package Inventory"

PQC_PKGS=(openssl oqs-provider liboqs openssh openssh-server crypto-policies)
for pkg in "${PQC_PKGS[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
        VER=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null)
        ok "$pkg: $VER"
    else
        info "$pkg: not installed"
    fi
done

# ---- Summary ----
echo ""
header "Summary"

if [[ "$PQC_KEM_FOUND" == "true" ]] && [[ "$PQC_SIG_FOUND" == "true" ]]; then
    ok "PQC algorithms (ML-KEM + ML-DSA) are available on this system"
    info "Recommended next steps:"
    info "  1. Enable PQC crypto sub-policy: update-crypto-policies --set DEFAULT:PQ"
    info "  2. Configure SSH KexAlgorithms to prefer hybrid PQC+classical"
    info "  3. Monitor Red Hat advisories for FIPS 140-3 PQC certification updates"
    info "  4. Evaluate long-lived TLS certificates for PQC migration timeline"
elif [[ "$PQC_KEM_FOUND" == "true" ]] || [[ "$PQC_SIG_FOUND" == "true" ]]; then
    warn "Partial PQC support detected — some algorithms available, others missing"
    info "Check OpenSSL provider configuration and oqs-provider package"
else
    fail "No PQC algorithms detected"
    info "Ensure openssl >= 3.x and oqs-provider are installed on RHEL 10"
    info "Check: dnf install openssl oqs-provider liboqs"
fi
echo ""
```

---

## References

- Red Hat: [RHEL 10 Release Notes](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/10.0_release_notes/)
- Red Hat: [Image Mode for RHEL](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/using_image_mode_for_rhel/)
- Red Hat: [bootc Documentation](https://bootc-dev.github.io/bootc/)
- NIST: [Post-Quantum Cryptography Standards](https://csrc.nist.gov/projects/post-quantum-cryptography)
- Red Hat: [Security Guide - PQC](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/security_hardening/)
- Red Hat: [Configuring and Managing Networking](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/configuring_and_managing_networking/)
- Red Hat: [Container Tools Guide](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/building_running_and_managing_containers/)
- RHEL Lightspeed: [Product Page](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux/lightspeed)
