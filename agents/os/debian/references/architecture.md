# Debian Architecture Reference

## Debian Philosophy

### The Debian Social Contract

Five pillars (1997, revised 2004):
1. Debian will remain 100% free software
2. Debian will give back to the free software community
3. Debian will not hide problems (public Bug Tracking System)
4. Debian's priorities are users and free software
5. Programs not meeting the DFSG will not prevent work on those that do

### Debian Free Software Guidelines (DFSG)

Criteria for packages to enter `main`:
- Free redistribution (no royalties)
- Source code included or freely available
- Derived works and modifications must be allowed
- No discrimination against persons, groups, or fields of endeavor
- License must not be specific to Debian
- License must not contaminate other software

The DFSG became the basis for the Open Source Definition (OSI, 1998).

### Archive Sections

| Section | DFSG Free | Notes |
|---|---|---|
| `main` | Yes | Fully free; only section Debian officially supports |
| `contrib` | Yes | Free software that depends on non-free packages |
| `non-free` | No | Non-free licenses; no Debian support obligation |
| `non-free-firmware` | No | Split from `non-free` in Debian 12; hardware firmware |

As of Debian 12 (Bookworm), official install ISOs include `non-free-firmware` by default.

### Governance: Debian Constitution

- **Debian Project Leader (DPL)** -- Elected annually by Developers (Condorcet/STV vote)
- **Technical Committee (TC)** -- Resolves technical disputes; rare but authoritative
- **Debian Developers (DDs)** -- Full membership, upload rights, voting rights
- **Debian Maintainers (DMs)** -- Limited upload rights for their own packages
- **General Resolutions (GRs)** -- Any DD can propose; 5 DD sponsors required

### Package Maintainer Model

Each package has named maintainers in `debian/control`. Maintainers:
- Monitor upstream releases
- Apply Debian-specific patches
- Respond to BTS bugs
- Ensure DFSG compliance
- Coordinate via `debian-devel` mailing list

Teams handle complex packages: `pkg-perl`, `pkg-python`, `debian-med`, `debian-science`. Collab-maint on Salsa (salsa.debian.org, Debian's GitLab) is the canonical hosting.

## Release Process

### Three-Suite Pipeline

```
unstable (Sid) -> testing (next release) -> stable (current release)
```

| Suite | Codename | Description |
|---|---|---|
| `unstable` | Sid | Always "Sid". Packages enter here first. No guaranteed stability. |
| `testing` | Next release name | Packages migrate from unstable after 10 days with no RC bugs. |
| `stable` | Current release name | Frozen, then released. Security updates only. |
| `oldstable` | Previous release | Supported ~1 year after next stable (then LTS). |

### Release Codenames (Toy Story)

| Release | Codename | Release Date | EOL (LTS) |
|---|---|---|---|
| Debian 11 | Bullseye | Aug 2021 | Jun 2026 |
| Debian 12 | Bookworm | Jun 2023 | ~Jun 2028 |
| Debian 13 | Trixie | Aug 2025 | TBD |

### Freeze and Release Cycle

1. **Soft freeze** -- New transitions blocked
2. **Hard freeze** -- No new upstream versions; only RC bug fixes
3. **Release** -- Stable tag applied; security team takes over
4. **Point releases** -- `X.Y` every 2-3 months with accumulated security and critical fixes

### Support Lifecycle

```
Stable release -> ~3 years standard support (Debian Security Team)
              -> +2 years LTS (volunteer, ~230 packages)
              -> +2 years ELTS (Freexian commercial, smaller subset)
```

Debian LTS is a community effort funded by Freexian. ELTS is a commercial Freexian product requiring a paid contract.

### Security Team (DSA)

- Issues Debian Security Advisories (DSAs): `DSA-NNNN-N`
- Fixes delivered via `security.debian.org` (CDN-backed, not mirrored)
- Backports minimal security patches -- does NOT ship new upstream versions
- DLA (Debian LTS Advisories) issued by the LTS team for oldstable

```
deb http://security.debian.org/debian-security bookworm-security main
```

## Package Management Internals

### dpkg vs apt

`dpkg` is the low-level package tool. `apt` (and `apt-get`) are high-level resolvers that call `dpkg`.

```bash
# dpkg fundamentals
dpkg -l nginx                        # package status
dpkg -L nginx                        # files installed by package
dpkg -S /usr/sbin/nginx              # which package owns a file
dpkg -i package.deb                  # install local .deb
dpkg --get-selections                # all installed packages
dpkg --audit                         # report broken installs
dpkg --verify nginx                  # verify installed files against md5sums
```

### apt Pinning (/etc/apt/preferences.d/)

| Priority | Meaning |
|---|---|
| < 0 | Never install |
| 0-99 | Install only if no other version available |
| 100 | Installed packages (default for dpkg) |
| 500 | Default for enabled repos |
| 990 | Default for target release (`-t` flag) |
| > 1000 | Install even if downgrading |

### apt-listbugs and apt-listchanges

Two Debian-specific apt hooks:

- **apt-listbugs** -- Queries BTS for RC bugs in packages about to be installed
- **apt-listchanges** -- Shows NEWS and changelog entries for packages being upgraded

### debconf

Package configuration database for automated installs and reconfiguration:

```bash
debconf-show postfix                 # show current answers
dpkg-reconfigure postfix             # re-run configuration dialog
debconf-get-selections               # dump all answers
debconf-set-selections < answers.txt # restore answers for automation
```

### sources.list: Legacy vs deb822

**Legacy format** (`/etc/apt/sources.list`):
```
deb http://deb.debian.org/debian bookworm main contrib non-free-firmware
deb-src http://deb.debian.org/debian bookworm main
deb http://security.debian.org/debian-security bookworm-security main
deb http://deb.debian.org/debian bookworm-updates main
```

**deb822 format** (`/etc/apt/sources.list.d/*.sources`):
```
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: bookworm bookworm-updates
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

deb822 is the modern preferred format (Debian 12+). Supports `Signed-By` per-repo, `Architectures`, `Languages`, and `Enabled: no` toggles.

### Reproducible Builds

Over 90% of Debian packages are reproducible as of Debian 12. Uses `SOURCE_DATE_EPOCH` environment variable and `debrebuild` tool.

## Installer

### Variants

| ISO Type | Size | Notes |
|---|---|---|
| netinst | ~400MB | Minimal; downloads packages during install |
| DVD | ~4GB | Full offline install |
| live | ~1-3GB | Desktop tryout + graphical installer |

### Preseed Automation

Debian's automated install mechanism -- uses a different syntax from Ubuntu's autoinstall/Subiquity.

```
d-i debian-installer/locale string en_US
d-i netcfg/get_hostname string debian-node
d-i passwd/root-login boolean false
d-i partman-auto/method string lvm
d-i grub-installer/only_debian boolean true
```

Load via boot parameter: `preseed/url=http://server/preseed.cfg`

### tasksel

```bash
tasksel --list-tasks                 # show available tasks
tasksel install ssh-server           # install SSH server task
# Tasks: desktop, gnome-desktop, kde-desktop, web-server, ssh-server, standard
```

## No Commercial Editions

Debian has no paid tiers, subscription variants, or commercial distributions. There is one Debian.

| Layer | Provider | Cost | Scope |
|---|---|---|---|
| Stable support | Debian Security Team | Free | All of main (~60k packages) |
| LTS | Debian LTS volunteers | Free | ~230 packages |
| ELTS | Freexian (commercial) | Paid | Smaller subset; older releases |

Debian does not ship snapd, Snap packages, Ubuntu Pro, or ESM. Flatpak is available via apt but not installed by default.
