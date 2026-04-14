# Rocky Linux / AlmaLinux Diagnostics Reference

## Distro Detection

```bash
# Most reliable detection
grep -E '^ID=' /etc/os-release
# Rocky:  ID=rocky
# Alma:   ID=almalinux
# RHEL:   ID=rhel

# Full identification
source /etc/os-release
echo "Distro: $NAME $VERSION_ID (${PLATFORM_ID})"

# Release file check
[[ -f /etc/rocky-release ]]     && echo "Rocky: $(cat /etc/rocky-release)"
[[ -f /etc/almalinux-release ]] && echo "Alma:  $(cat /etc/almalinux-release)"

# RPM-based check
rpm -q rocky-release 2>/dev/null && echo "Rocky"
rpm -q almalinux-release 2>/dev/null && echo "AlmaLinux"
```

## RHEL Compatibility Verification

```bash
# Platform ID (matches RHEL platform)
grep PLATFORM_ID /etc/os-release
# Expected: platform:el8, platform:el9, or platform:el10

# Verify package signatures are from the distro
rpm -qa --qf '%{NAME} %{SIGPGP:pgpsig}\n' | head -20

# Subscription-manager should be absent
rpm -q subscription-manager && echo "WARNING: sub-mgr present" || echo "OK: no sub-mgr"

# Confirm repos are community, not CDN
dnf repolist -v | grep -E 'baseurl|mirrorlist' | head -10
```

## Repo Health Check

```bash
# List all repos with status
dnf repolist all

# Refresh metadata
dnf makecache --refresh

# Test mirror connectivity
dnf repoinfo baseos | grep -E 'Repo-baseurl|Repo-mirrors'

# Fastest mirror
dnf config-manager --setopt fastestmirror=1
```

## Migration Verification

### Post-Migration Checks

```bash
# Verify distro identity
cat /etc/os-release
cat /etc/rocky-release 2>/dev/null || cat /etc/almalinux-release 2>/dev/null

# Check for residual CentOS packages
rpm -qa | grep -iE 'centos'

# Check for CentOS-signed packages
rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE} %{SIGPGP:pgpsig}\n' | grep -i "8483c65d"

# Check for leftover CentOS repo files
ls /etc/yum.repos.d/*centos* /etc/yum.repos.d/*CentOS* 2>/dev/null

# Check for .centos. in release strings
rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}\n' | grep '\.centos\.'

# Check for orphaned packages
dnf list extras
```

### Migration Log Review

```bash
# migrate2rocky log
[[ -f /var/log/migrate2rocky.log ]] && tail -20 /var/log/migrate2rocky.log

# AlmaLinux deploy log
[[ -f /var/log/almalinux-deploy.log ]] && tail -20 /var/log/almalinux-deploy.log

# ELevate/Leapp logs
ls /var/log/leapp/ 2>/dev/null
cat /var/log/leapp/leapp-report.txt 2>/dev/null | head -50
```

## Package Signature Audit

```bash
# Check for unsigned packages
UNSIGNED=$(rpm -qa --qf '%{NAME} %{SIGPGP:pgpsig}\n' | grep '(none)' | awk '{print $1}')
echo "Unsigned packages: $(echo "$UNSIGNED" | wc -w)"

# Check for packages not signed by distro key
source /etc/os-release
case "$ID" in
    rocky)     rpm -qa --qf '%{NAME}\t%{PACKAGER}\n' | grep -v "Rocky" | head -20 ;;
    almalinux) rpm -qa --qf '%{NAME}\t%{PACKAGER}\n' | grep -v "AlmaLinux" | head -20 ;;
esac
```

## Kernel and Module Compatibility

```bash
# Installed kernels
rpm -qa 'kernel' --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort

# Kernel variant
uname -r | grep -q 'rt\.' && echo "Real-time" || echo "Standard"

# Out-of-tree modules
cat /proc/modules | awk '$NF ~ /\(OE\)/ || $NF ~ /\(O\)/{print $1}'

# kABI stability list
rpm -q kernel-abi-stablelists 2>/dev/null || rpm -q kernel-abi-whitelists 2>/dev/null

# Third-party driver modules
rpm -qa 'kmod-*' | sort
```

## Third-Party Repo Conflict Detection

```bash
# Repos with priority set
grep -l 'priority=' /etc/yum.repos.d/*.repo

# Module stream conflicts
dnf module list 2>/dev/null | head -30

# Packages not from any enabled repo
dnf list extras

# DNF configuration
grep -E '^(best|skip_if_unavailable|fastestmirror)' /etc/dnf/dnf.conf
```

## x86_64 ISA Level Check

```bash
# Check CPU microarchitecture level
/lib64/ld-linux-x86-64.so.2 --help 2>&1 | grep "x86-64-v"

# Check for AVX2 (key v3 marker)
grep -o 'avx2' /proc/cpuinfo | head -1

# Check for BMI2 (another v3 marker)
grep -o 'bmi2' /proc/cpuinfo | head -1
```
