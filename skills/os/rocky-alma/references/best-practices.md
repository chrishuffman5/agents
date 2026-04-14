# Rocky Linux / AlmaLinux Best Practices Reference

## CentOS Migration

### Migration Tool Comparison

| Tool | Maintained by | Targets | Status (2026) |
|---|---|---|---|
| ELevate | AlmaLinux | Alma, CentOS Stream, Oracle (not Rocky) | Active |
| migrate2rocky | Rocky Linux | Rocky 8, 9 from EL8/9 sources | Active |
| almalinux-deploy | AlmaLinux | AlmaLinux from RHEL/CentOS/Rocky | Active |
| convert2rhel | Red Hat | RHEL (requires subscription) | Active |

**Important:** ELevate dropped Rocky Linux as a target in November 2025.

### migrate2rocky.sh

Converts CentOS 8, RHEL 8, AlmaLinux 8, Oracle Linux 8/9 to Rocky (same EL version):

```bash
curl -O https://raw.githubusercontent.com/rocky-linux/rocky-tools/main/migrate2rocky/migrate2rocky.sh
chmod +x migrate2rocky.sh
./migrate2rocky.sh -r

# Post-migration verification
cat /etc/rocky-release
rpm -qa | grep centos  # should be empty
```

The script: validates disk space, swaps repos, removes distro branding, imports GPG keys, runs `dnf distro-sync`.

### almalinux-deploy.sh

Converts CentOS/RHEL/Rocky to AlmaLinux (same EL version):

```bash
curl -O https://raw.githubusercontent.com/AlmaLinux/almalinux-deploy/master/almalinux-deploy.sh
chmod +x almalinux-deploy.sh
bash almalinux-deploy.sh

cat /etc/almalinux-release
```

### ELevate (Major Version Upgrades)

AlmaLinux's leapp-based framework for in-place major upgrades:

```bash
# CentOS 7 -> AlmaLinux 8
dnf install -y http://repo.almalinux.org/elevate/elevate-release-latest-el7.noarch.rpm
dnf install -y leapp-upgrade leapp-data-almalinux
leapp preupgrade                     # dry-run; review report
leapp upgrade
reboot

# AlmaLinux 8 -> AlmaLinux 9
curl -O https://repo.almalinux.org/elevate/elevate-release-latest-el8.noarch.rpm
rpm -ivh elevate-release-latest-el8.noarch.rpm
dnf install -y leapp-upgrade leapp-data-almalinux
leapp preupgrade
leapp upgrade
reboot
```

Full CentOS 7 to AlmaLinux 10 path: `CentOS 7 -> AL8 -> AL9 -> AL10` (three sequential runs).

### Pre-Migration Checklist

```bash
# 1. Check current release
cat /etc/os-release

# 2. Verify disk space
df -h /usr /var /boot /

# 3. Check for problematic packages
rpm -qa | grep -E 'plesk|cpanel|directadmin|cloudlinux'

# 4. Snapshot or backup (mandatory)

# 5. Check for third-party kernels
rpm -qa kernel\*

# 6. Review installed repo list
dnf repolist all
```

## Repository Management

### Enabling CRB and EPEL

```bash
# CRB (required before EPEL)
dnf config-manager --set-enabled crb       # EL9+
dnf config-manager --set-enabled powertools # EL8

# EPEL
dnf install -y epel-release
dnf install -y epel-next-release           # EPEL Next (EL9+)

# Verify
dnf repolist | grep -E 'epel|crb|powertools'
```

### AlmaLinux Synergy Repository

Community-requested packages not in RHEL or EPEL. Acts as pre-EPEL staging:

```bash
dnf install almalinux-release-synergy
```

### Rocky Linux SIGs

```bash
# Enable SIG repos via release packages
dnf install rocky-release-nfv       # NFV SIG
dnf install rocky-release-rt        # Real-Time kernel SIG
dnf config-manager --enable rocky-plus  # Plus repo
```

### Third-Party Repo Best Practices

- Use `dnf config-manager --setopt="repo.priority=N"` to prevent overrides
- Check `dnf module list` for stream conflicts before adding repos
- Never disable `gpgcheck=1` in production

## Choosing Between Rocky and AlmaLinux

### Choose Rocky Linux if:
- Strict RHEL binary clone required (ISV certification, regulatory)
- HPC, AI/ML, scientific computing (CIQ support, SIG/HPC)
- Running modern hardware (x86_64-v3, 2013+ CPUs)
- Need RISC-V support (Rocky 10 only)

### Choose AlmaLinux if:
- Web hosting with cPanel or Plesk (cPanel dropped Rocky v134+)
- Running older x86_64-v2 hardware upgrading to EL10
- Want security patches ahead of RHEL
- Need Synergy repo for pre-EPEL packages
- Prefer 501(c)(6) nonprofit governance

### Either works for:
- General-purpose servers (web, database, application)
- Container base images
- Virtualization hosts (KVM/libvirt)
- CentOS 7/8 migrations where you have not chosen yet

## GPG Key Management

```bash
# Import distro keys
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial   # Rocky
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9     # AlmaLinux

# Verify package signatures
rpm -K /path/to/package.rpm
rpm -qa gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n'

# Check for unsigned packages
rpm -qa --qf '%{NAME} %{SIGPGP:pgpsig}\n' | grep '(none)'
```
