# MDM Deployment Diagnostics Reference

## Enrollment Diagnostics

### Key Commands

```bash
# Show enrollment status and MDM server URL
sudo profiles show -type enrollment

# Show MDM enrollment record detail
sudo profiles status -type enrollment

# Bootstrap token escrow status
sudo profiles status -type bootstraptoken

# MDM client daemon interaction (use carefully)
sudo mdmclient QueryDeviceInformation

# Show push certificate status
sudo mdmclient PushCertificate
```

### MDM Log Stream

```bash
# Stream MDM subsystem logs in real time
log stream --predicate 'subsystem == "com.apple.ManagedClient"' --level debug

# Historical MDM logs (last 1 hour)
log show --predicate 'subsystem == "com.apple.ManagedClient"' --last 1h --level debug

# MDM command execution logs
log show --predicate 'subsystem == "com.apple.ManagedClient" AND category == "CommandManager"' --last 2h

# DDM declaration activity
log show --predicate 'subsystem == "com.apple.ManagedClient" AND message CONTAINS "declaration"' --last 2h

# DDM status reports
log show --predicate 'subsystem == "com.apple.ManagedClient" AND message CONTAINS "StatusReport"' --last 4h
```

### Key Filesystem Paths

| Path | Contents |
|---|---|
| `/var/db/ConfigurationProfiles/` | Installed profiles database |
| `/var/db/ConfigurationProfiles/Store/Principals/` | Per-profile data |
| `/Library/Managed Preferences/` | MDM-enforced preference files |
| `/private/var/db/MDMClientEnrollment.plist` | Enrollment record |
| `/Library/Application Support/com.apple.ManagedClient/` | MDM client support files |
| `/Library/Keychains/System.keychain` | System certificates and MDM identity |

---

## Profile Debugging

### Profile Inspection Commands

```bash
# List all installed profiles
sudo profiles show -all

# Show profiles by type
sudo profiles show -type configuration
sudo profiles show -type enrollment

# Validate a .mobileconfig file before deployment
sudo profiles validate -path /path/to/profile.mobileconfig

# Show effective managed preferences
sudo defaults read "/Library/Managed Preferences/com.apple.applicationaccess"

# Check if a specific key is managed
sudo profiles -P

# List profiles (user context)
profiles -L

# List profiles (system context)
sudo profiles -P
```

### Profile Installation Errors

Common errors in `/var/log/install.log` and MDM client log:

| Error | Cause | Resolution |
|---|---|---|
| `ProfileInstallFailed` | Payload validation error | Check payload type and key names |
| `DuplicatePayload` | Profile with same PayloadUUID already installed | Generate new UUIDs |
| `UnsupportedPayload` | Payload not supported on this OS version or supervision state | Verify compatibility |
| `CertificateRequired` | Payload requires a certificate not yet installed | Fix installation order; deploy cert first |

---

## Common Enrollment Failure Patterns

### APNs Push Certificate Expired
**Symptom:** Device never receives MDM commands; no check-ins in MDM console.
**Diagnosis:**
```bash
sudo profiles show -type enrollment | grep -i "Topic\|Push"
# Check MDM console for push cert expiry date
```
**Resolution:** Renew push certificate via ABM or Apple Developer account. Push cert must be renewed annually.

### Clock Skew
**Symptom:** TLS handshake failures; enrollment profile rejected.
**Diagnosis:**
```bash
date                          # Check local time
sntp time.apple.com           # Compare with NTP
```
**Resolution:** Ensure NTP is configured. Certificate validity windows reject connections with >5 min skew.

### SCEP Failure
**Symptom:** Device enrolled but no identity certificate; command channel auth fails.
**Diagnosis:**
```bash
log show --predicate 'subsystem == "com.apple.ManagedClient" AND message CONTAINS "SCEP"' --last 2h
security find-certificate -a -c "MDM" /Library/Keychains/System.keychain
```
**Resolution:** Check SCEP server logs, CA template configuration, and SCEP challenge password.

### ADE Profile Not Assigned
**Symptom:** Device boots to normal Setup Assistant with no MDM enrollment.
**Diagnosis:** Check ABM > Devices for the serial number. Verify device is assigned to the correct MDM server.
**Resolution:** Assign device to MDM server in ABM. Device will enroll on next wipe/reset.

### Bootstrap Token Not Escrowed
**Symptom:** FileVault recovery key rotation fails; new users cannot get secure tokens.
**Diagnosis:**
```bash
sudo profiles status -type bootstraptoken
```
**Resolution:** Re-enroll via ADE if non-ADE. Verify MDM server supports bootstrap token. Check MDM vendor documentation for token escrow requirements.

---

## Useful Log Predicates

```bash
# MDM command execution
'subsystem == "com.apple.ManagedClient" AND category == "CommandManager"'

# DDM declarations
'subsystem == "com.apple.ManagedClient" AND message CONTAINS "declaration"'

# DDM status reports
'subsystem == "com.apple.ManagedClient" AND message CONTAINS "StatusReport"'

# Profile installation
'subsystem == "com.apple.ManagedClient" AND message CONTAINS "profile"'

# SCEP enrollment
'subsystem == "com.apple.ManagedClient" AND message CONTAINS "SCEP"'

# FileVault
'subsystem == "com.apple.fdesetup"'

# Software Update (MDM-managed)
'subsystem == "com.apple.SoftwareUpdate"'
```

---

## Recovery Lock Diagnostics

Recovery Lock status is not directly exposed via CLI on the device. Verification must be done through the MDM server using the `VerifyRecoveryLock` command.

If Recovery Lock password is lost and MDM access is unavailable:
1. Device must be placed in DFU mode (Apple Silicon: long press power + volume down)
2. Use Apple Configurator to restore (destructive -- all data lost)
3. After restore, re-enroll via ADE

---

## DDM Troubleshooting

### Verifying DDM Support

```bash
# Check macOS version (DDM requires 13+ for basic, 14+ for full)
sw_vers -productVersion

# Check enrollment profile for DDM capability
sudo profiles show -type enrollment | grep -i "Declarative\|DDM"

# Check DDM log activity
log show --predicate 'subsystem == "com.apple.ManagedClient" AND message CONTAINS "declaration"' --last 2h
```

### DDM Declarations Not Activating

1. Verify MDM server supports DDM (check vendor documentation)
2. Confirm macOS version supports the specific declaration type
3. Check if the `DeclarativeManagement` bootstrap command was sent
4. Review activation predicates -- conditional activations may not match current device state
5. Check status channel for error reports

### DDM vs Legacy Command Activity

```bash
# Count legacy MDM commands (last 24h)
log show --predicate 'subsystem == "com.apple.ManagedClient" AND message CONTAINS "MDMCommand"' --last 24h | grep -c "MDMCommand"

# Count DDM declaration events (last 24h)
log show --predicate 'subsystem == "com.apple.ManagedClient" AND message CONTAINS "declaration"' --last 24h | grep -c "declaration"
```

---

## Quick Diagnostic Checklist

```
1. Is the device enrolled?
   sudo profiles status -type enrollment

2. Is it supervised?
   sudo profiles status -type enrollment | grep -i supervised

3. Is Bootstrap Token escrowed?
   sudo profiles status -type bootstraptoken

4. Are profiles installed?
   sudo profiles show -all

5. Are restrictions applied?
   sudo defaults read "/Library/Managed Preferences/com.apple.applicationaccess"

6. Is DDM active?
   log show --predicate 'subsystem == "com.apple.ManagedClient" AND message CONTAINS "declaration"' --last 2h | tail -5

7. Any MDM errors?
   log show --predicate 'subsystem == "com.apple.ManagedClient" AND level == "error"' --last 2h

8. FileVault status?
   fdesetup status
```
