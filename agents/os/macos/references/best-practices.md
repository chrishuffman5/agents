# macOS Best Practices Reference

Cross-version coverage: macOS 14 Sonoma through macOS 26 Tahoe.

---

## 1. CIS Hardening

The Center for Internet Security (CIS) macOS benchmark provides a prioritized set of controls. Key areas:

### FileVault (Full-Disk Encryption)
```bash
fdesetup status                       # Check encryption status
sudo fdesetup enable                  # Enable FileVault
sudo fdesetup enable -defer /tmp/fv   # Defer until next login
fdesetup list                         # List enabled users
```

### Gatekeeper (Application Trust)
```bash
spctl --status                        # Check Gatekeeper status
sudo spctl --master-enable            # Enable Gatekeeper
spctl --assess --type exec /Applications/App.app
```

### Application Firewall
```bash
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
/usr/libexec/ApplicationFirewall/socketfilterfw --listapps
```

### System Integrity Protection (SIP)
```bash
csrutil status                        # Check SIP status
# Enable/disable requires booting into Recovery Mode
```

### Automatic Updates
```bash
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool true
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool true
```

### Screen Lock
```bash
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
sudo defaults write /Library/Preferences/com.apple.screensaver loginWindowIdleTime -int 300
```

### Remote Login (SSH)
```bash
sudo systemsetup -getremotelogin
sudo systemsetup -setremotelogin off
```

### AirDrop and Guest Account
```bash
defaults write com.apple.NetworkBrowser DisableAirDrop -bool true
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false
sudo defaults write /Library/Preferences/com.apple.AppleFileServer guestAccess -bool false
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server AllowGuestAccess -bool false
```

**CIS Benchmark Levels:**
- **Level 1**: Basic security, minimal operational impact (recommended for all)
- **Level 2**: Higher security, may affect usability (enterprise/high-security environments)

---

## 2. Homebrew Package Management

### Installation Paths

| Architecture | Homebrew Prefix | Notes |
|-------------|----------------|-------|
| Apple Silicon | `/opt/homebrew` | arm64-native binaries |
| Intel | `/usr/local` | x86_64 binaries |
| Rosetta 2 | `/usr/local` | Intel Homebrew under Rosetta |

### PATH Configuration (Apple Silicon -- add to ~/.zprofile)
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Core Commands
```bash
brew install <formula>          # Install CLI package
brew install --cask <app>       # Install GUI application
brew upgrade                    # Upgrade all
brew cleanup                    # Remove old versions and cache
brew cleanup --prune=all        # Remove everything
brew list                       # List installed formulae
brew list --cask                # List installed casks
brew outdated                   # Show available updates
brew doctor                     # Diagnose common issues
brew info <formula>             # Package details
```

### Tap Management
```bash
brew tap                        # List active taps
brew tap <user/repo>            # Add third-party tap
brew untap <user/repo>          # Remove tap
```

### Brewfile for Reproducible Setups
```bash
brew bundle dump --file=~/Brewfile --force    # Export
brew bundle install --file=~/Brewfile          # Restore
brew bundle check --file=~/Brewfile            # Verify
brew bundle cleanup --file=~/Brewfile --force  # Remove extras
```

Sample Brewfile:
```ruby
tap "homebrew/bundle"
brew "git"
brew "wget"
brew "jq"
cask "visual-studio-code"
mas "Xcode", id: 497799835
```

---

## 3. Time Machine Backup

### Backup Format Evolution
- **Pre-Ventura**: HFS+ sparse bundles on network, directory-based on local
- **Ventura+**: APFS sparse bundles for all destinations
- **Sequoia+**: AFP deprecated; SMB required for network destinations

### tmutil Commands
```bash
sudo tmutil startbackup                      # Start immediate backup
sudo tmutil startbackup --auto               # Background (low priority)
tmutil status                                # Backup status
tmutil latestbackup                          # Most recent backup
tmutil listbackups                           # All snapshots
tmutil listdestinations                      # Configured destinations
sudo tmutil setdestination /Volumes/Backup   # Set local destination
sudo tmutil setdestination -a smb://nas/Backups  # Add network
sudo tmutil removedestination <dest-id>      # Remove destination
```

### Excluding Directories
```bash
sudo tmutil addexclusion /path/to/dir
sudo tmutil removeexclusion /path/to/dir
tmutil isexcluded /path/to/dir
# Common exclusions: node_modules, .git large repos, VM images, caches
```

### Local Snapshots (APFS)
```bash
tmutil listlocalsnapshots /
tmutil listlocalsnapshotdates /
sudo tmutil deletelocalsnapshots <date>
sudo tmutil thinlocalsnapshots / 1000000000 4
```

---

## 4. FileVault Encryption

FileVault 2 provides full-disk encryption using XTS-AES-128 with a 256-bit key on APFS volumes.

### Architecture Differences

| Platform | Key Storage | Unlock Method |
|----------|------------|---------------|
| Apple Silicon | Secure Enclave | Touch ID, password, recovery key |
| Intel (T2) | T2 Security Chip | Password, recovery key |
| Intel (No T2) | Software (EFI) | Password, recovery key |

### fdesetup Commands
```bash
fdesetup status                             # On or off?
sudo fdesetup enable                        # Enable
sudo fdesetup enable -defer /tmp/fv_users   # Enable at next login
sudo fdesetup disable                       # Disable (requires restart)
fdesetup list                               # Enabled users
sudo fdesetup add -usertoadd username       # Add user
sudo fdesetup remove -user username         # Remove user
sudo fdesetup changerecovery -personal      # New recovery key
```

### Recovery Key Management
- **Personal Recovery Key**: 24-character alphanumeric key
- **Institutional Recovery Key**: Certificate-based, managed via MDM
- **MDM Escrow**: Recovery keys escrowed to MDM server (Jamf, Mosyle, etc.)

### Performance Impact
- **Apple Silicon**: Negligible -- hardware-accelerated AES in Secure Enclave
- **Intel T2**: Minimal -- T2 handles encryption inline
- **Intel (no T2)**: Small overhead (~5-10%)

---

## 5. Software Updates

### softwareupdate CLI
```bash
softwareupdate --list                       # Available updates
softwareupdate --install --all              # Install all
softwareupdate --install --all --restart    # Install and restart
softwareupdate --download --all             # Download only
softwareupdate --ignore "Update Name"       # Ignore update
softwareupdate --reset-ignored              # Clear ignores
```

### MDM-Managed Updates
- **Sonoma (14)+**: DDM software update declarations (preferred)
- **Earlier versions**: Legacy MDM commands `ScheduleOSUpdate`
- DDM specifies `targetOSVersion`, `targetLocalDateTime`, enforcement deadlines
- macOS 26 Tahoe removes legacy `SoftwareUpdateSettings` profile -- DDM only

### OS Upgrade vs Security Updates
- Major upgrades (14 to 15) require explicit user action or MDM enforcement
- Security Response updates (RSR): rapid patches applied in minutes
- `softwareupdate --list-full-installers`: list full macOS installers

---

## 6. Security Best Practices

### Gatekeeper Deep Dive
```bash
spctl --status                              # Global state
spctl --list --type execute                 # Execution rules
spctl --assess --type exec --verbose /path/to/app
```

### XProtect
```bash
defaults read /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist CFBundleShortVersionString
```

### TCC (Transparency Consent and Control)
```bash
tccutil reset All                           # Reset ALL permissions (destructive)
tccutil reset Camera                        # Reset camera access
tccutil reset Microphone com.bundle.id      # Reset for specific app
# TCC databases:
# ~/Library/Application Support/com.apple.TCC/TCC.db (user)
# /Library/Application Support/com.apple.TCC/TCC.db (system)
```

### Login Items and Background Tasks
```bash
sfltool dump                                # Service management database
# System Settings > General > Login Items & Extensions
```

### Keychain Security
```bash
security list-keychains
security find-generic-password -s "Service" -w
security add-generic-password -s "Service" -a "account" -w "password"
security lock-keychain ~/Library/Keychains/login.keychain-db
```

### Firmware and Recovery Security
```bash
# Apple Silicon: Recovery Lock (replaces Intel firmware password)
# Intel Firmware Password: set in Recovery Mode
# Check secure boot: bputil -g (Apple Silicon)
```

---

## 7. Shell and Terminal Best Practices

### zsh Configuration
Key files (in load order):
- `~/.zshenv` -- Always loaded (environment variables)
- `~/.zprofile` -- Login shells (PATH setup, Homebrew init)
- `~/.zshrc` -- Interactive shells (aliases, functions, prompt)
- `~/.zlogin` -- After zshrc for login shells

### Homebrew PATH Setup (~/.zprofile)
```bash
# Universal (auto-detect)
if [[ $(uname -m) == 'arm64' ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv)"
fi
```

### SSH Key Management
```bash
ssh-keygen -t ed25519 -C "user@host" -f ~/.ssh/id_ed25519
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# ~/.ssh/config for Keychain integration
# Host *
#   UseKeychain yes
#   AddKeysToAgent yes
#   IdentityFile ~/.ssh/id_ed25519
```

### Developer Tools
```bash
xcode-select --install              # Install Command Line Tools
xcode-select -p                     # Active developer directory
xcode-select --switch /Applications/Xcode.app
xcrun --show-sdk-path               # Current SDK path
```

---

*Coverage: macOS 14 Sonoma, 15 Sequoia, 26 Tahoe. Commands are consistent across these versions unless noted.*
