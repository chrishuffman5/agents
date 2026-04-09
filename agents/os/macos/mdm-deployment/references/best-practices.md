# MDM Deployment Best Practices Reference

## Zero-Touch Deployment Workflow

### End-to-End Process

1. **Purchase devices** -- Ensure linked to ABM Apple Customer Number (ACN) at purchase
2. **Assign to MDM server** in ABM (or configure auto-assign rule by device type)
3. **Configure MDM Prestage Enrollment:**
   - MDM server URL, authentication (SCEP or manual cert)
   - Skip Setup Assistant items
   - Enable supervision
   - Assign static or dynamic group for profile assignment
4. **Device arrives at end user** -- Powers on, auto-enrolls
5. **MDM delivers** configuration profiles, DDM declarations, VPP apps
6. **User authenticates** with Managed Apple ID (federated from IdP)
7. **PSSO registers** (macOS 13+) -- User has IdP SSO session

### Bootstrap Token Escrow Verification

Always verify the bootstrap token escrows successfully during first enrollment. Failure is common when the device is enrolled via profile (non-ADE) and the MDM server is not trusted for secure token grant.

```bash
sudo profiles status -type bootstraptoken
# Expected: "Bootstrap Token supported on server: YES"
#           "Bootstrap Token escrowed to server: YES"
```

### Device Naming Conventions

MDM can set the computer name and local hostname. Consistent naming aids inventory and log correlation:
- Pattern examples: `{OrgCode}-{DeviceType}-{SerialLast6}` e.g., `ACME-MBP-X3KP9Q`
- Set via MDM `Settings` command with `DeviceName` key
- Use Jamf Extension Attributes or similar for dynamic name enforcement

---

## Configuration Profile Best Practices

### Profile Organization

- **One profile per purpose** -- Avoid monolithic profiles with dozens of payloads. Separate Wi-Fi, VPN, restrictions, certificates into individual profiles for independent management.
- **Use descriptive PayloadDisplayName** -- End users see this in System Settings > Privacy & Security > Profiles.
- **Generate unique PayloadUUIDs** -- Duplicate UUIDs cause installation failures.
- **Sign profiles** -- MDM-delivered profiles are signed automatically. Manually distributed profiles should be signed with an Apple-trusted certificate.

### Key Payload Types

| Payload | MDM Key | Notes |
|---|---|---|
| Wi-Fi | `com.apple.wifi.managed` | Per-SSID, supports EAP |
| VPN | `com.apple.vpn.managed` | IKEv2, L2TP, per-app VPN |
| Certificate | `com.apple.security.pkcs1` | DER or PEM cert |
| SCEP | `com.apple.security.scep` | Auto-renew capable |
| Restrictions | `com.apple.applicationaccess` | See restrictions table |
| Password | `com.apple.mobiledevice.passwordpolicy` | Complexity, length, history |
| Platform SSO | `com.apple.extensiblesso` | Requires SSO extension app |
| FileVault | `com.apple.FDE` | FV2 enablement |
| DNS | `com.apple.dnsSettings.managed` | DoH/DoT |
| Firewall | `com.apple.security.firewall` | ALF rules |
| Login Window | `com.apple.loginwindow` | Banner, options |
| Smart Card | `com.apple.security.smartcard` | Enforcement, token removal |

### Profile Removal Behavior

- MDM-installed: only removable by MDM command (or device wipe)
- User-installed with removal password: require the password
- User-installed without password: removable by user

---

## MDM Restrictions

### Key Restriction Keys (com.apple.applicationaccess)

| Key | Type | Effect |
|---|---|---|
| `allowAppInstallation` | Bool | Block App Store installs |
| `allowCamera` | Bool | Disable FaceTime camera |
| `allowAirDrop` | Bool | Disable AirDrop |
| `allowiCloudDocumentSync` | Bool | Block iCloud Drive sync |
| `allowBluetoothModification` | Bool | Prevent Bluetooth changes |
| `allowScreenShot` | Bool | Block screenshots and screen recording |
| `forceEncryptedBackup` | Bool | Force encrypted local backups |
| `allowEraseContentAndSettings` | Bool | Block erase in System Settings |
| `allowManagedAppsCloudSync` | Bool | Control managed app iCloud sync |
| `allowPasswordAutoFill` | Bool | Disable credential autofill |
| `allowPasswordSharing` | Bool | Disable AirDrop password sharing |

### Supervised-Only Restrictions

Many restrictions only take effect on supervised (ADE-enrolled) devices:
- Blocking App Store entirely (`allowAppInstallation = false`)
- Always-on VPN
- Content filtering
- Blocking kernel extension installation
- Restricting login to specific local user accounts

### Tahoe Migration Note

In macOS 26 Tahoe, Apple deprecated several `com.apple.applicationaccess` keys in favor of DDM `com.apple.configuration.restrictions.*` declarations. MDM vendors must update payload delivery to use DDM for these features on Tahoe+ devices.

---

## Supervised Mode

### UAMDM vs Supervised Comparison

| Feature | UAMDM | Supervised (ADE) |
|---|---|---|
| Enrollment method | OTA profile, manual | ADE/DEP, Apple Configurator |
| User consent at install | Required | Optional (skipped) |
| Remove MDM profile | User can remove | Cannot remove without MDM command |
| Supervision-level restrictions | Not available | Available |
| Activation Lock bypass | No | Yes (with ABM) |
| App install (VPP) | User prompted | Silent |

### Apple Configurator for Supervision

Devices not purchased through Apple can be supervised using Apple Configurator 2:
- Connect via USB
- Apply a "Supervision Identity" and enroll into an MDM server
- Device is wiped and re-enrolled as supervised (not zero-touch; requires physical access)

Alternatively, Apple Configurator 2 can add unsupervised devices to ABM without wiping via the "Add to Organization" workflow, after which they can be ADE-enrolled.

---

## MDM Migration (Tahoe)

### Migration Workflow

1. Coordinate with both old and new MDM vendors
2. Reassign device in ABM to new MDM server (triggers migration on next check-in)
3. Device contacts new MDM server and re-enrolls
4. Old profiles removed; new profiles installed
5. Verify: Bootstrap Token re-escrowed, PSSO re-registered, VPP apps reassigned

### Pre-Migration Checklist

- [ ] New MDM server configured with matching profile set
- [ ] VPP app licenses available in new MDM
- [ ] ABM IdP federation verified for new MDM
- [ ] PSSO profile ready in new MDM
- [ ] Communication plan for end users (apps may briefly disappear)
- [ ] Rollback plan if migration fails

### Post-Migration Validation

```bash
# Verify enrollment to new MDM
sudo profiles status -type enrollment

# Verify bootstrap token
sudo profiles status -type bootstraptoken

# Verify profiles installed
sudo profiles show -all

# Verify DDM activity
log show --predicate 'subsystem == "com.apple.ManagedClient" AND message CONTAINS "declaration"' --last 1h
```

---

## ABM IdP Federation

### Microsoft Entra ID Federation

1. In ABM: Settings > Identity Provider > Configure (Microsoft Azure AD)
2. In Entra: Register ABM as an enterprise app with SAML 2.0
3. Configure SCIM provisioning in Entra to push users to ABM
4. Map Entra attributes to Managed Apple ID fields (email, first name, last name)
5. Set domain verification in ABM for your email domain

### Okta Federation

1. In ABM: Settings > Identity Provider > Configure (Okta)
2. In Okta: Add "Apple Business Manager" application from Okta Integration Network
3. Assign users/groups to the app
4. Configure SCIM (Okta to ABM) for Managed Apple ID provisioning
5. Verify domain in ABM

### SCIM Provisioning Considerations

- SCIM creates Managed Apple IDs in ABM, but users must still activate on device (System Settings > Apple ID)
- PSSO does not require Managed Apple ID sign-in -- it is a separate credential mechanism. Managed Apple IDs are needed for iCloud for Work.
- Deprovisioning: SCIM deactivates Managed Apple IDs. MDM should also wipe/unenroll the device on offboarding.

---

## Common Enrollment Failure Patterns

| Pattern | Cause | Resolution |
|---|---|---|
| APNs push cert expired | Device never wakes to poll MDM | Renew cert in MDM console via ABM/Apple Developer |
| Clock skew | TLS errors from certificate validity windows | Ensure NTP configured; >5 min skew causes failures |
| SCEP failure | Identity cert not issued | Check SCEP server logs and CA template configuration |
| ADE profile not assigned | Device not in ABM or not assigned to MDM | Verify in ABM > Devices |
| DuplicatePayload | Profile with same UUID already installed | Generate new PayloadUUIDs |
| UnsupportedPayload | Payload not supported on this OS or supervision state | Verify OS version and supervision |
