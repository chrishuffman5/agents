# Debian Diagnostics Reference

## reportbug

Formats and submits bug reports to the Debian BTS. Automatically gathers system info.

```bash
apt-get install reportbug
reportbug nginx                      # interactive bug submission
reportbug --no-check-available nginx # skip version check (useful offline)
reportbug --severity serious nginx   # pre-set severity
```

### Bug Tracking System (BTS)

Debian's BTS (https://bugs.debian.org) is public and email-driven.

Severity levels: `critical`, `grave`, `serious`, `important`, `normal`, `minor`, `wishlist`

- **RC bugs** (release-critical): `critical`, `grave`, `serious` -- must be resolved before stable release
- Packages with open RC bugs are auto-removed from testing after a grace period

```bash
# CLI query via bts tool (devscripts package)
bts show nginx

# Browse package bugs
xdg-open "https://bugs.debian.org/nginx"
```

## dpkg Diagnostic Tools

```bash
# Package status and queries
dpkg -l nginx                        # package status
dpkg -L nginx                        # files installed by package
dpkg -S /usr/sbin/nginx              # which package owns a file
dpkg --audit                         # report broken installs
dpkg --verify nginx                  # verify files against md5sums
dpkg --get-selections                # all installed packages

# Repair operations
dpkg --configure -a                  # configure partially installed
apt --fix-broken install             # resolve broken dependencies

# Config file management
dpkg -l | grep '^rc'                 # removed but config remains
find /etc -name "*.dpkg-new" -o -name "*.dpkg-old" 2>/dev/null
```

## apt Diagnostics

```bash
# Version and source queries
apt-cache policy nginx               # installed vs candidate, sources + priorities
apt-cache madison nginx              # all versions across repos
apt-cache rdepends nginx             # what depends on nginx (reverse deps)
apt-cache depends nginx              # what nginx depends on
apt-cache search "web server"        # search descriptions
apt-cache show nginx                 # package metadata
apt-cache showsrc nginx              # source package info

# Repair
apt --fix-broken install             # resolve broken dependencies
apt-get install -f                   # fix broken installs

# Simulate operations (dry-run)
apt-get -s upgrade                   # simulate upgrade
apt-get --just-print full-upgrade    # show what would change
```

## debsecan -- CVE Tracking

```bash
apt-get install debsecan
debsecan                             # all CVEs affecting installed packages
debsecan --suite bookworm            # specify suite
debsecan --only-fixed                # CVEs with available fixes
debsecan --format detail             # verbose with descriptions
debsecan --update                    # update CVE database
```

## Security Tracking

### Debian Security Tracker

Web-based CVE tracker at https://security-tracker.debian.org/tracker/

- Search by CVE number or package name
- Shows fix status per release (open, fixed, not-affected, ignored)

```bash
# CLI via debsecan
debsecan --suite bookworm --only-fixed --format detail | head -50

# Check specific CVE
curl -s "https://security-tracker.debian.org/tracker/data/json/CVE-2024-1234" | \
  python3 -m json.tool
```

### DSA Monitoring

```bash
# RSS feed monitoring
curl -s "https://www.debian.org/security/dsa-long" | grep -oP 'DSA-\d+-\d+[^<"]*'

# debian-security-announce mailing list
# https://lists.debian.org/debian-security-announce/
```

### Security Repository

Always ensure the security repo is configured separately:

```
# Legacy format
deb http://security.debian.org/debian-security bookworm-security main

# deb822 format
Types: deb
URIs: http://security.debian.org/debian-security
Suites: bookworm-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

The security repo is NOT mirrored. Always use `security.debian.org` directly (CDN-backed).

## check-support-status

Reports packages with limited security support:

```bash
apt-get install debian-security-support
check-support-status
```

## debootstrap

Creates minimal Debian base systems in a directory. Used for chroots, containers, custom installs:

```bash
debootstrap bookworm /srv/chroot http://deb.debian.org/debian
chroot /srv/chroot /bin/bash

# Cross-arch bootstrap
debootstrap --arch=arm64 bookworm /srv/arm64-chroot
```

## deborphan

Finds packages with no reverse dependencies (potential orphans):

```bash
apt-get install deborphan
deborphan                            # orphaned libraries
deborphan --all-packages             # all orphaned packages
deborphan --guess-data               # include data packages
```

## dpkg-reconfigure and debconf-show

```bash
dpkg-reconfigure tzdata              # reconfigure timezone
dpkg-reconfigure locales             # regenerate locales
dpkg-reconfigure keyboard-configuration
debconf-show sshd                    # show debconf state for ssh
```

## needrestart

```bash
needrestart -r l                     # list services needing restart
needrestart -r a                     # auto-restart all
needrestart -k                       # check if kernel needs update
```

## Journal Analysis

```bash
journalctl --disk-usage              # journal disk usage
journalctl --list-boots              # boot history
journalctl --since "24 hours ago" -p err  # recent errors
journalctl -k --since "24 hours ago"     # kernel messages
systemctl list-units --state=failed       # failed units
systemd-analyze                           # boot time analysis
systemd-analyze blame                     # slowest units at boot
```
