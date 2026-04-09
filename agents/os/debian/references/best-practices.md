# Debian Best Practices Reference

## Hardening

### AppArmor (Default Since Debian 10)

AppArmor is enabled by default but ships fewer application profiles than Ubuntu.

```bash
aa-status                            # show loaded profiles
aa-enforce /etc/apparmor.d/profile   # enforce mode
aa-complain /etc/apparmor.d/profile  # complain mode (log only)
aa-genprof /usr/sbin/myapp           # generate new profile
aa-logprof                           # update profiles from audit log
```

Additional profiles available in the `apparmor-profiles` package.

### debsecan -- CVE Tracking

```bash
apt-get install debsecan
debsecan --suite bookworm            # all CVEs affecting installed packages
debsecan --only-fixed                # only CVEs with available fixes
debsecan --format detail             # verbose with CVE descriptions
debsecan --update                    # update CVE database
```

### Firewall: nftables

Debian uses nftables natively (not UFW by default):

```bash
nft list ruleset                     # view all rules
systemctl enable --now nftables      # enable persistent rules
cat /etc/nftables.conf               # permanent configuration

# UFW is available but not default
apt-get install ufw && ufw enable
```

### CIS Hardening Notes

- CIS Benchmark for Debian is maintained separately from Ubuntu
- Key differences: no snap considerations, no UFW assumption, auditd rules differ
- `debian-security-support` package provides `check-support-status`

```bash
apt-get install debian-security-support
check-support-status                 # report packages with limited security support
```

### needrestart

Checks which services need restarting after library upgrades:

```bash
needrestart -r l                     # list only
needrestart -r a                     # auto-restart all
needrestart -r i                     # interactive (default)
needrestart -k                       # check if kernel needs update
```

Configure in `/etc/needrestart/needrestart.conf` for automatic restart behavior.

### SSH Hardening

```bash
# /etc/ssh/sshd_config recommendations
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
AllowTcpForwarding no
MaxAuthTries 3
```

### User and Password Security

Debian 11+ uses yescrypt as the default password hashing algorithm (stronger against GPU attacks than sha512crypt). Both hash formats are forward-compatible.

## Backports Strategy

### When to Use Backports

`bookworm-backports` provides newer package versions built for stable. Use when:
- Software stack needs features not in stable
- Security fix exists in upstream but stable version is too old
- Development toolchain needs newer versions

Never use backports for: libc6, systemd, or kernel unless specifically required and tested.

### Safe Backports Usage

```bash
# Enable backports
echo "deb http://deb.debian.org/debian bookworm-backports main" \
  > /etc/apt/sources.list.d/backports.list
apt-get update

# Install from backports (explicit)
apt-get install -t bookworm-backports nginx

# Pin only specific packages to backports
# /etc/apt/preferences.d/backports
Package: *
Pin: release a=bookworm-backports
Pin-Priority: 100

Package: nginx nginx-common
Pin: release a=bookworm-backports
Pin-Priority: 600
```

### Holding Packages

```bash
apt-mark hold nginx                  # prevent upgrades
apt-mark unhold nginx                # re-allow upgrades
apt-mark showhold                    # list held packages
```

## Release Upgrades

### Upgrade Process (Stable to Next Stable)

Debian supports in-place upgrades between releases:

```bash
# Step 1: Fully update current release
apt-get update && apt-get upgrade && apt-get dist-upgrade

# Step 2: Update sources.list to new release codename
sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list
sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list.d/*.list 2>/dev/null

# Step 3: Minimal upgrade (less risky first pass)
apt-get update
apt-get upgrade --without-new-pkgs

# Step 4: Full upgrade
apt-get full-upgrade

# Step 5: Clean up
apt-get autoremove --purge
apt-get autoclean
```

### Known Upgrade Gotchas

- **Held packages** block dist-upgrade. Always check `apt-mark showhold`.
- **Third-party repos** must be disabled or updated before upgrading.
- **debconf prompts** may ask about config file conflicts.
- **Config file diffs:** Use `dpkg -l | grep ^rc` and `find /etc -name "*.dpkg-new"`.

### Unattended Upgrades

```bash
apt-get install unattended-upgrades apt-listchanges
dpkg-reconfigure unattended-upgrades

# /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
```

## Backup and Recovery

### debootstrap

Creates a minimal Debian base system in a directory:

```bash
debootstrap bookworm /srv/chroot http://deb.debian.org/debian
chroot /srv/chroot /bin/bash

# Cross-arch bootstrap
debootstrap --arch=arm64 bookworm /srv/arm64-chroot
```

### debconf State Backup

```bash
# Save all debconf answers
debconf-get-selections > /backup/debconf-selections.txt

# Restore on new system
debconf-set-selections < /backup/debconf-selections.txt
```

### Package List Backup

```bash
# Save installed package list
dpkg --get-selections > /backup/pkg-selections.txt

# Restore on new system
dpkg --set-selections < /backup/pkg-selections.txt
apt-get dselect-upgrade
```

## Orphan Management

```bash
apt-get install deborphan
deborphan                            # list orphaned libraries
deborphan --all-packages             # all orphaned packages
apt-get purge $(deborphan)           # remove orphans (review first)
```

## popularity-contest (popcon)

Opt-in package usage survey feeding into package prioritization:

```bash
apt-get install popularity-contest
dpkg-reconfigure popularity-contest  # enable/disable
```
