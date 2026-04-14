# MDM Deployment Architecture Reference

## MDM Protocol Stack

### Legacy MDM Commands

macOS MDM is built on an Apple-defined HTTP/2-based command-response protocol. The MDM server sends commands; the device executes them and returns results. All communication is authenticated via client certificates (the MDM identity certificate installed at enrollment).

**Protocol elements:**
- **MDM Profile** -- Configuration profile with `com.apple.mdm` payload delivered during enrollment. Contains the MDM server URL, check-in URL, APNs topic, identity certificate, and server capabilities.
- **APNs Push** -- Server sends a lightweight push notification via Apple Push Notification Service to wake the device. The device then polls the MDM server for pending commands. The server does NOT maintain persistent connections.
- **Check-in Protocol** -- Device authenticates to `/checkin` endpoint with Authenticate, TokenUpdate, and CheckOut messages. Separate from the command channel.
- **Command Channel** -- Device polls `/mdm` endpoint, receives XML plist commands, executes, and responds.

### HTTP/2 Protocol Details

- All MDM traffic is HTTPS (TLS 1.2 minimum, TLS 1.3 preferred)
- Device presents its MDM identity certificate for mutual TLS on the command channel
- Commands are base64-encoded plists in the HTTP body
- Response: 200 with plist body for command results; 401 if device cert not accepted

### Certificate-Based Device Identity

- MDM identity certificate issued at enrollment (via SCEP or manual delivery)
- Certificate ties the device's hardware UUID to an enrollment record
- On Apple Silicon, the Secure Enclave backs the private key (non-exportable)
- Bootstrap Token (escrowed to MDM) allows MDM-authorized actions for volume ownership and FileVault recovery key rotation

### APNs Push Flow

```
MDM Server -> APNs -> Device (lightweight nudge, no payload)
Device -> MDM Server /mdm (polls for commands)
MDM Server -> Device (XML plist command)
Device -> MDM Server (command result plist)
```

The push notification contains only the APNs topic -- no MDM command data traverses the push channel. This ensures command confidentiality.

---

## Declarative Device Management (DDM)

### Philosophy: Pull vs Push

| Dimension | Legacy MDM | DDM |
|---|---|---|
| Initiation | Server-initiated (push then poll) | Device-initiated (self-checks state) |
| Model | Imperative commands | Declarative desired state |
| Status | Server must query device | Device reports proactively |
| Efficiency | High APNs/command volume | Low: device self-regulates |
| Scalability | O(n) polls | Event-driven |

### DDM Building Blocks

1. **Declarations** -- JSON documents describing desired state. Four subtypes:
   - `configuration` -- Desired configuration analogous to a profile payload. Example: `com.apple.configuration.passcode.settings`.
   - `activation` -- Binds a configuration to a predicate (always-on or conditional on a Status Item).
   - `asset` -- Data assets referenced by configurations (e.g., a certificate blob).
   - `management` -- Organization metadata (organization name, support info).

2. **Status Channel** -- Persistent or long-poll channel from device to server. Device sends structured JSON status reports. Status items include: MDM enrollment state, installed configurations, software update state, battery, storage.

3. **Declaration Delivery** -- Server sends a `DeclarativeManagement` MDM command to bootstrap DDM. Subsequent changes are delivered via a synchronization protocol: device fetches a manifest, then individual declarations by token.

4. **Predicates** -- Activations can be conditional. Example: apply a Wi-Fi configuration only when status item `device.operating-system.version` meets a version constraint.

### DDM vs Legacy -- When to Use Which

- **DDM preferred for:** software update enforcement, configuration desired state, status monitoring
- **Legacy MDM still required for:** app installation (VPP), certificate deployment (non-DDM), wipe, lock, profile removal commands
- **In practice:** modern MDM vendors (Jamf, Mosyle, Kandji, Intune) use DDM for supported payloads and fall back to legacy commands for the rest

### macOS DDM Timeline

| macOS Version | DDM Support Level |
|---|---|
| 13 Ventura | DDM introduced for macOS (subset of declarations) |
| 14 Sonoma | Expanded declaration support, software update declarations GA |
| 15 Sequoia | Authentication policy declarations, PSSO declarations |
| 26 Tahoe | MDM migration, PSSO at Setup Assistant via DDM activation, DDM restrictions |

---

## Automated Device Enrollment (ADE)

### Overview

ADE (formerly DEP) links Apple devices purchased from Apple or authorized resellers to an organization's Apple Business Manager (ABM) account. When the device boots for the first time (or after a wipe), it contacts `iprofiles.apple.com` and receives an MDM enrollment profile automatically -- before Setup Assistant completes.

### Zero-Touch Enrollment Flow

```
Device powers on
  -> contacts albert.apple.com (activation)
  -> contacts iprofiles.apple.com (ADE profile lookup by serial number)
  -> receives MDM enrollment profile
  -> contacts MDM server check-in endpoint
  -> MDM server delivers configuration profiles and DDM declarations
  -> Setup Assistant completes (customized steps skipped)
```

### Setup Assistant Customization

MDM servers can skip Setup Assistant panes via the `skip_setup_items` array:
- `Accessibility`, `Appearance`, `AppleID`, `Biometric`, `FileVault`
- `iCloudDiagnostics`, `iCloudStorage`, `Location`, `Privacy`
- `Registration`, `Restore`, `ScreenTime`, `Siri`, `TOS`

In macOS 26 Tahoe, PSSO registration can occur at Setup Assistant so the user gets a fully configured SSO session before reaching the desktop.

### Supervision

ADE-enrolled devices are supervised by default. Supervision unlocks:
- App installation without user prompt (VPP silent install)
- Content filtering and global HTTP proxy
- Always-on VPN
- Restricting iCloud features
- Managed open-in (per-app data isolation)
- Activation Lock bypass

Non-ADE enrollment results in User Approved MDM (UAMDM) -- some restrictions available but supervision-level controls are not.

### Bootstrap Token Escrow

During ADE enrollment, the device generates a Bootstrap Token and escrows it to the MDM server:
- Allows MDM to authorize secure token grant for new users (critical for FileVault unlock)
- Enables MDM-initiated FileVault recovery key rotation
- Required for Apple Silicon firmware password management
- Required for authenticated softwareupdate downloads

---

## Apple Business Manager (ABM)

### Core Functions

ABM (business.apple.com) is Apple's web portal for enterprise device and content management.

**Device Enrollment:**
- Devices purchased from Apple or resellers automatically appear in ABM linked to the organization's Apple Customer Number (ACN)
- Devices can be manually added via Apple Configurator 2 (adds to ABM over USB)
- Each device is assigned to an MDM server within ABM; the device contacts that server at first boot

**Apps & Books (VPP):**
- Volume Purchase Program allows buying app licenses in bulk
- Apps assigned to devices (not users) via MDM -- no Apple ID required on device
- Apps assigned to Managed Apple IDs allow user-based app portability

**Managed Apple IDs:**
- Organization-controlled Apple IDs (format: `user@appleid.org-domain.com`)
- Federated from IdP (Okta, Microsoft Entra ID) -- users authenticate with corporate credentials
- Required for iCloud for Work (iCloud Drive, iCloud Mail scoped to org)
- Provisioned automatically via SCIM federation

### IdP Federation

ABM supports federation with:
- **Microsoft Entra ID** -- Native federation; Managed Apple IDs auto-provisioned via SCIM
- **Okta** -- OAuth 2.0 / OIDC federation; Managed Apple IDs provisioned via SCIM
- **Google Workspace** -- Supported for education (ASM)

Federation delegates authentication to the IdP: users log into ABM-linked services with their corporate password.

---

## Configuration Profile Format

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <!-- one dict per payload -->
  </array>
  <key>PayloadDisplayName</key>
  <string>Profile Name</string>
  <key>PayloadIdentifier</key>
  <string>com.example.profile.identifier</string>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string><!-- UUID --></string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>
```

MDM-delivered profiles are signed by the MDM server's signing certificate. MDM-installed profiles are only removable by MDM command or device wipe.

---

## Recovery Lock (Apple Silicon)

On Apple Silicon Macs (M1 and later), MDM can set a Recovery Lock password preventing unauthorized access to macOS Recovery. Analogous to the EFI firmware password on Intel Macs.

**MDM Commands:**
- `SetRecoveryLock` -- Sets the password (supervised devices only)
- `VerifyRecoveryLock` -- Checks if the correct password is set (returns true/false)
- `ClearRecoveryLock` -- Removes the lock (requires current password in payload)

**Key Behaviors:**
- Requires supervision
- Lost password without MDM access requires DFU restore via Apple Configurator (destructive)
- Best practice: store password in MDM device record and rotate periodically
- If FileVault is enabled and Bootstrap Token is escrowed, MDM has additional firmware authorization paths

---

## MDM Migration (macOS 26 Tahoe)

Tahoe introduces native vendor-to-vendor MDM migration without device wipe:

1. New MDM server sends migration command (or ABM device reassignment triggers it)
2. Device receives migration declaration, contacts new MDM server
3. Device re-enrolls: new identity cert, push cert topic, profile set
4. Old MDM profiles removed; new MDM profiles installed
5. User data, applications, and FileVault remain intact

**Considerations:**
- Apps installed by old MDM may be orphaned unless new MDM reassigns them
- Bootstrap Token must be re-escrowed to new server
- PSSO registration may need re-triggering
- All DDM declarations from old MDM are removed
