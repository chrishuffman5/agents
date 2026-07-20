# Platform SSO Architecture Reference

## Protocol Overview

Platform SSO (PSSO) is Apple's enterprise SSO framework for macOS, introduced in macOS 13 Ventura. It extends the SSO Extension framework to integrate with enterprise IdPs at the macOS login window -- not just within browser sessions.

PSSO delivers IdP-issued tokens to the device at login, enabling:
- Single sign-on across all native and web apps without re-authentication
- macOS local account password sync with IdP password
- FileVault decryption using IdP credentials (Sequoia+)
- Kerberos TGT acquisition via PKINIT using the device identity certificate

---

## Architecture Components

### 1. SSO Extension Host

`AuthenticationServicesAgent` runs in user space and hosts the SSO extension. This is the macOS daemon responsible for brokering authentication requests between applications and the IdP extension.

### 2. com.apple.extensiblesso Payload

MDM-delivered configuration profile that specifies:
- Which IdP extension handles SSO (`ExtensionIdentifier`)
- The vendor's Team Identifier (`TeamIdentifier`)
- Extension type (`Credential` for PSSO; `Redirect` for web-only SSO)
- URL patterns the extension handles (`URLs` array)
- Authentication method (`UserSecureEnclaveKey` or `Password`)

Minimum required keys:
- `ExtensionIdentifier` -- Bundle ID of the SSO extension app
- `TeamIdentifier` -- Apple Developer Team ID of the extension vendor
- `Type` -- `Credential` (for PSSO)
- `URLs` -- List of URLs for which the extension handles SSO

### 3. IdP Extension

A macOS app from the IdP vendor that implements the `ASAuthorizationSingleSignOnProvider` API:

| IdP | Extension Bundle ID | App Required |
|---|---|---|
| Microsoft Entra ID | `com.microsoft.CompanyPortalMac.ssoextension` | Company Portal |
| Okta | `com.okta.mobile.auth-client` | Okta Verify |
| Jamf Connect | `com.jamf.connect.login` | Jamf Connect |
| Ping Identity | PingFederate Extension | PingFederate app |

### 4. Token Broker

macOS subsystem that stores and vends IdP tokens (OAuth 2.0 access tokens, refresh tokens, Kerberos TGTs) to requesting applications. Applications that use `ASAuthorizationSingleSignOnProvider` get tokens silently without user interaction.

---

## Token Types

| Token | Protocol | Use | Lifetime |
|---|---|---|---|
| OAuth 2.0 Access Token | OAuth 2.0 / OIDC | Web app SSO, Microsoft 365 | Minutes to hours |
| Refresh Token | OAuth 2.0 | Silent token renewal | Hours to days |
| Kerberos TGT | Kerberos via PKINIT | On-premises AD resources | Typically 10 hours |
| JWT (ID Token) | OIDC | Identity assertion | Minutes |

The token broker manages token lifecycle automatically. When an access token expires, the broker uses the refresh token to obtain a new one without user interaction. When the refresh token expires, the user may be prompted to re-authenticate.

---

## Authentication Flow at Login Window

1. User enters username and password (or uses Touch ID / NFC in Tahoe)
2. PSSO extension intercepts the authentication event
3. Extension exchanges credentials with the IdP (OIDC/SAML flow, often with MFA)
4. IdP returns tokens; tokens stored in macOS Keychain / token broker
5. Local macOS account unlocked (password synced or mapped to IdP credential)
6. User session starts with valid IdP tokens
7. All apps using `ASAuthorizationSingleSignOnProvider` get tokens silently

### Secure Enclave Key Binding

When `AuthenticationMethod` is set to `UserSecureEnclaveKey`:
- A device-bound key pair is generated in the Secure Enclave during registration
- The public key is registered with the IdP
- Subsequent authentications use the Secure Enclave key for proof-of-possession
- The key is non-exportable, tying SSO to the specific hardware

---

## Authentication Policies (Sequoia+)

macOS 15 Sequoia introduced granular authentication policies for PSSO.

### FileVaultPolicy

Controls what credentials are accepted to unlock FileVault at pre-boot:
- `password` -- Local password only
- `sso` -- IdP credential (allows FileVault unlock with corporate password)
- `smartcard` -- Smart card / PKINIT

### LoginPolicy

Controls what credentials are accepted at the macOS login window:
- `password` -- Local password
- `sso` -- IdP credential (forces IdP authentication for every login)
- `smartcard` -- Smart card

### UnlockPolicy

Controls what credentials unlock the screen after lock/sleep:
- `password` -- Local password
- `sso` -- IdP credential
- `smartcard` -- Smart card
- Grace period: window (in seconds) after lock during which `password` is still accepted

### Grace Periods

Grace periods prevent lockout when IdP connectivity is unavailable:
- `LoginGracePeriod` -- Time after first login during which offline password login is allowed
- `UnlockGracePeriod` -- Time after lock during which local password unlock is allowed

### MDM Profile Keys

```xml
<key>AuthenticationMethod</key>
<string>UserSecureEnclaveKey</string>

<key>FileVaultPolicy</key>
<dict>
  <key>Enable</key>
  <true/>
</dict>

<key>LoginPolicy</key>
<dict>
  <key>Enable</key>
  <true/>
  <key>GracePeriod</key>
  <integer>900</integer>  <!-- 15 minutes -->
</dict>

<key>UnlockPolicy</key>
<dict>
  <key>Enable</key>
  <true/>
  <key>GracePeriod</key>
  <integer>300</integer>  <!-- 5 minutes -->
</dict>
```

---

## NFC Tap-to-Login (Tahoe)

macOS 26 Tahoe introduces NFC authentication for PSSO:
- Supported IdPs provide NFC-enabled hardware security keys or passkey-on-phone via NFC
- User taps NFC device at login window
- PSSO extension handles the NFC assertion and exchanges with IdP
- FileVault, login, and unlock policies can be set to accept NFC authentication
- Requires IdP extension version with NFC support

---

## ADE Simplified Setup (Tahoe)

macOS 26 Tahoe allows PSSO registration during Setup Assistant:
- MDM delivers PSSO profile as part of ADE prestage
- Setup Assistant includes an "Organization Sign In" step
- User authenticates with IdP credentials during setup
- Desktop is reached with PSSO already registered -- no post-setup registration step
- Eliminates the common user friction of a separate registration prompt

---

## ABM IdP Federation

Federation links ABM to the corporate IdP so that:
- Employees use corporate credentials for Managed Apple IDs
- SCIM provisioning automatically creates/updates/deactivates Managed Apple IDs
- ABM does not store passwords -- authentication delegated entirely to IdP

**Important distinction:** PSSO and Managed Apple IDs are separate mechanisms. PSSO provides SSO tokens for app authentication. Managed Apple IDs are needed for iCloud for Work. A user can have PSSO without signing in with a Managed Apple ID.

---

## macOS PSSO Feature Timeline

| Feature | macOS Version | Notes |
|---|---|---|
| Platform SSO | 13 Ventura | Basic PSSO with Okta, Entra ID, Jamf |
| PSSO expanded | 14 Sonoma | Improved registration flow, stability |
| Authentication Policies | 15 Sequoia | FileVaultPolicy, LoginPolicy, UnlockPolicy |
| PSSO at Setup Assistant | 26 Tahoe | ADE + PSSO registration in one step |
| NFC Tap-to-Login | 26 Tahoe | IdP extension must support NFC |
| MDM migration + PSSO | 26 Tahoe | PSSO re-registration after migration |
