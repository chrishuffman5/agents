# Platform SSO Best Practices Reference

## MDM Profile Delivery

PSSO is configured entirely via the `com.apple.extensiblesso` MDM payload. Never manually install PSSO; always deliver via MDM.

### Minimum Required Keys

| Key | Value | Purpose |
|---|---|---|
| `ExtensionIdentifier` | Bundle ID of SSO extension | Identifies which app handles SSO |
| `TeamIdentifier` | Apple Developer Team ID | Vendor verification |
| `Type` | `Credential` | PSSO type (vs `Redirect` for web-only SSO) |
| `URLs` | Array of URL strings | Domains the extension handles |

### Recommended Additional Keys

| Key | Value | Purpose |
|---|---|---|
| `AuthenticationMethod` | `UserSecureEnclaveKey` or `Password` | Key binding method |
| `ScreenLockedBehavior` | String | Behavior when token expires during lock |
| `FileVaultPolicy` | Dict (Sequoia+) | FileVault credential policy |
| `LoginPolicy` | Dict (Sequoia+) | Login window credential policy |
| `UnlockPolicy` | Dict (Sequoia+) | Screen unlock credential policy |

---

## User Registration Flow

After the MDM profile is installed, PSSO is not immediately active. The user must register:

1. User receives a notification or banner: "Register with [Organization]"
2. User clicks the registration prompt (or it triggers at next login for some IdPs)
3. PSSO extension opens a browser/webview for IdP authentication (MFA may be required)
4. On success, the device receives a registration credential (often a Secure Enclave key)
5. Subsequent logins use the registered credential without MFA prompts (unless IdP policy requires step-up)

### Monitoring Registration

```bash
# Check PSSO registration state
app-sso platform -s

# List SSO extensions
app-sso -l

# Trigger re-registration (user context)
app-sso platform --register
```

### Common Registration Issues

- **Registration prompt dismissed** -- User must be prompted again or trigger manually
- **MFA timeout** -- IdP MFA session expired during registration flow
- **Network connectivity** -- IdP must be reachable during registration
- **Extension app not installed** -- Deploy SSO extension app via VPP before profile

---

## Authentication Policy Configuration (Sequoia+)

### FileVaultPolicy

Allows FileVault pre-boot unlock using the IdP credential:

```xml
<key>FileVaultPolicy</key>
<dict>
  <key>Enable</key>
  <true/>
</dict>
```

**Prerequisites:**
- FileVault must be enabled on the device
- PSSO must be registered
- macOS 15 Sequoia or later

### LoginPolicy

Forces IdP authentication at the login window:

```xml
<key>LoginPolicy</key>
<dict>
  <key>Enable</key>
  <true/>
  <key>GracePeriod</key>
  <integer>900</integer>
</dict>
```

**Grace period** (in seconds): Time after first login during which offline password login is allowed. Set to at least 900 seconds (15 minutes) to handle IdP outages.

### UnlockPolicy

Controls screen unlock after lock/sleep:

```xml
<key>UnlockPolicy</key>
<dict>
  <key>Enable</key>
  <true/>
  <key>GracePeriod</key>
  <integer>300</integer>
</dict>
```

**Grace period** (in seconds): Time after lock during which local password unlock is still accepted. Set to at least 300 seconds (5 minutes).

### Grace Period Recommendations

| Policy | Minimum Grace | Recommended | Notes |
|---|---|---|---|
| LoginGracePeriod | 300s (5 min) | 900s (15 min) | Covers brief IdP outages |
| UnlockGracePeriod | 60s (1 min) | 300s (5 min) | Prevents lockout on Wi-Fi reconnect |

**Critical:** Without grace periods, users are locked out if the IdP is unreachable. Always configure grace periods when enabling LoginPolicy or UnlockPolicy.

---

## ADE Simplified Setup (Tahoe)

macOS 26 Tahoe enables PSSO registration at Setup Assistant:

### Configuration

1. MDM delivers PSSO profile as part of ADE prestage enrollment
2. Setup Assistant includes "Organization Sign In" step automatically
3. User authenticates with IdP credentials during setup
4. Desktop reached with PSSO already registered

### Benefits

- Eliminates post-setup registration prompt (major UX improvement)
- User has SSO tokens from first login
- Zero-touch: no IT intervention needed after device ships

### Requirements

- macOS 26 Tahoe or later
- ADE-enrolled (supervised) device
- PSSO profile in ADE prestage configuration
- IdP extension app deployed via VPP (installed during setup)

---

## NFC Tap-to-Login (Tahoe)

macOS 26 Tahoe supports NFC authentication for PSSO:

### Supported Methods

- NFC-enabled hardware security keys (FIDO2/WebAuthn)
- Passkey-on-phone via NFC (phone tapped to Mac)

### Configuration

- FileVault, login, and unlock policies can accept NFC authentication
- IdP extension must support NFC (verify with vendor)
- PSSO profile must include NFC-specific keys (vendor-dependent)

### Deployment Considerations

- Not all Macs have NFC readers (check hardware compatibility)
- NFC is supplementary -- configure password/SSO as fallback
- Test NFC authentication with specific hardware key models before fleet deployment

---

## IdP-Specific Setup

### Microsoft Entra ID

**Extension:** `com.microsoft.CompanyPortalMac.ssoextension`
**App:** Microsoft Company Portal (deploy via VPP)

1. Deploy Company Portal app via VPP (silent install on supervised devices)
2. Create PSSO profile in MDM with Entra-specific `URLs` array:
   - `https://login.microsoftonline.com`
   - `https://login.microsoft.com`
   - `https://sts.windows.net`
3. Deploy profile to device group
4. User registers at next login

### Okta

**Extension:** `com.okta.mobile.auth-client`
**App:** Okta Verify (deploy via VPP)

1. Deploy Okta Verify via VPP
2. Configure Okta FastPass device trust in Okta admin console
3. Create PSSO profile with Okta-specific `URLs` array
4. Deploy profile to device group
5. User registers via Okta Verify prompt

### Jamf Connect

**Extension:** `com.jamf.connect.login`
**App:** Jamf Connect (deploy via Jamf Pro)

Jamf Connect bridges the login window to multiple IdPs (Okta, Entra ID, PingFederate). It provides additional features like local account creation and password sync beyond standard PSSO.

---

## SCIM Provisioning for Managed Apple IDs

### Key Points

- SCIM creates Managed Apple IDs in ABM but the user must still activate on device
- PSSO does NOT require Managed Apple ID sign-in -- separate mechanisms
- Managed Apple IDs are needed for iCloud for Work
- Deprovisioning: SCIM deactivates Managed Apple IDs; MDM should also wipe/unenroll

### Microsoft Entra ID SCIM

1. In ABM: Settings > Identity Provider > Configure (Microsoft Azure AD)
2. In Entra: Register ABM as enterprise app with SAML 2.0
3. Configure SCIM provisioning to push users
4. Map attributes: email, first name, last name
5. Set domain verification in ABM

### Okta SCIM

1. In ABM: Settings > Identity Provider > Configure (Okta)
2. In Okta: Add "Apple Business Manager" from Okta Integration Network
3. Assign users/groups
4. Configure SCIM provisioning
5. Verify domain in ABM

---

## Troubleshooting Quick Reference

### app-sso Command Reference

```bash
# List all SSO extension configurations
app-sso -l

# Show verbose state for a specific extension
app-sso -v -b com.microsoft.CompanyPortalMac.ssoextension

# Show PSSO platform state (macOS 13+)
app-sso platform -s

# Trigger re-registration (user context, prompts user)
app-sso platform --register

# Show IdP token cache state
app-sso -t
```

### Log Sources

```bash
# SSO extension subsystem
log stream --predicate 'subsystem == "com.apple.AppSSO"' --level debug

# Authentication Services (token broker)
log stream --predicate 'subsystem == "com.apple.AuthenticationServices"' --level debug

# Login window authentication
log stream --predicate 'subsystem == "com.apple.loginwindow"' --level debug

# Historical PSSO logs
log show --predicate 'subsystem == "com.apple.AppSSO"' --last 2h --level info
```

### Common Issues

| Symptom | Likely Cause | Resolution |
|---|---|---|
| Registration persists after completing | Extension crash or keychain corruption | `app-sso platform --register` |
| Tokens not delivered to apps | URL patterns not matching | Verify `URLs` in PSSO profile |
| Login window still prompts password | LoginPolicy not enabled | Check profile; verify macOS 15+ |
| FileVault rejects IdP password | FileVaultPolicy not configured | Verify profile; re-register PSSO |
| IdP connectivity errors | DNS/VPN not active at login | Ensure DNS works before login |
| NFC not working (Tahoe) | Extension lacks NFC support | Verify extension version |
