# Code Signing and Notarization Reference

## Code Signing Overview

Code signing is Apple's mechanism to cryptographically assert the identity of software and detect tampering. The kernel enforces signing policies via Gatekeeper and System Integrity Protection (SIP).

---

## Certificate Types

| Certificate Type | Issued By | Used For | Expiry |
|---|---|---|---|
| Apple Development | Apple (via team) | Development builds, device testing | 1 year |
| Apple Distribution | Apple (via team) | TestFlight, App Store submission | 1 year |
| Developer ID Application | Apple | Mac apps distributed outside App Store | 5 years |
| Developer ID Installer | Apple | .pkg installers outside App Store | 5 years |
| Mac Installer Distribution | Apple | Mac App Store .pkg | 1 year |

**Developer ID** is the critical certificate type for enterprise/independent Mac software. Without it, Gatekeeper blocks execution by default.

---

## Keychain and Identity Storage

Certificates and private keys live in Keychain. The `codesign` tool resolves identities from:
1. Login keychain (`~/Library/Keychains/login.keychain-db`)
2. System keychain (`/Library/Keychains/System.keychain`)
3. Custom keychains (common in CI environments)

```bash
# List valid signing identities
security find-identity -v -p codesigning

# List all identities including expired
security find-identity -v

# Import a certificate from .p12 (CI deployment)
security import certificate.p12 -k ~/Library/Keychains/login.keychain-db \
  -P "$P12_PASSWORD" -T /usr/bin/codesign

# Create a temporary keychain (CI best practice)
security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
security list-keychains -s build.keychain
security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
security set-keychain-settings -t 3600 -u build.keychain
security import certificate.p12 -k build.keychain -P "$P12_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple: -s \
  -k "$KEYCHAIN_PASSWORD" build.keychain
```

The `set-key-partition-list` step is required on macOS 10.12+ to allow codesign to access imported keys without UI prompts.

---

## codesign Command

```bash
# Sign an application bundle
codesign --sign "Developer ID Application: My Company (TEAMID)" \
  --options runtime \
  --entitlements MyApp.entitlements \
  --timestamp \
  --force \
  MyApp.app

# Sign a binary (non-bundle)
codesign --sign "Developer ID Application: My Company (TEAMID)" \
  --options runtime --timestamp /usr/local/bin/mytool

# Verify signature
codesign --verify --verbose MyApp.app

# Display signature details
codesign --display --verbose=4 MyApp.app

# Deep verification (nested bundles)
codesign --verify --deep --strict --verbose=2 MyApp.app
```

**Key flags:**
| Flag | Purpose |
|---|---|
| `--options runtime` | Enables Hardened Runtime (required for notarization) |
| `--timestamp` | Embeds secure timestamp from Apple's timestamp authority |
| `--force` | Replace existing signature |
| `--deep` | Sign nested bundles (frameworks, plugins) |
| `--entitlements` | Embed entitlements plist |

---

## Entitlements

Entitlements declare capabilities the signed binary is granted:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>  <true/>
  <key>com.apple.security.network.client</key>  <true/>
  <key>com.apple.security.files.user-selected.read-write</key>  <true/>
  <!-- Hardened Runtime exceptions (minimize these): -->
  <key>com.apple.security.cs.allow-jit</key>  <false/>
  <key>com.apple.security.cs.disable-library-validation</key>  <false/>
</dict>
</plist>
```

**Inspect entitlements:**
```bash
codesign --display --entitlements :- MyApp.app
```

---

## Hardened Runtime

Hardened Runtime is a security policy that:
- Prevents code injection and dynamic code loading from external sources
- Blocks loading of unsigned dynamic libraries
- Restricts DYLD environment variables
- Required for notarization (since 2019)

Enable with `--options runtime` in codesign. Exceptions declared via entitlements (e.g., `com.apple.security.cs.allow-jit` for JavaScript engines).

---

## Provisioning Profiles

Provisioning profiles (`.mobileprovision`, `.provisionprofile`) bind:
- App Bundle ID
- Team ID and certificates
- Enabled capabilities/entitlements
- Device UDIDs (development profiles) or distribution channel

```bash
# Inspect provisioning profile
security cms -D -i MyApp.provisionprofile

# Installed profiles location
ls ~/Library/MobileDevice/Provisioning\ Profiles/

# Show profile details (with jq)
security cms -D -i profile.provisionprofile | plutil -convert json -o - - | jq .
```

---

## Notarization

### notarytool (Xcode 13+)

`notarytool` replaced the deprecated `altool`. Uses App Store Connect API keys (JWT) rather than Apple ID + app-specific password.

**API Key Setup:**
1. Create key at https://appstoreconnect.apple.com/access/integrations/api
2. Download the `.p8` key file (one-time download)
3. Note: Key ID and Issuer ID

**Store credentials in Keychain:**
```bash
xcrun notarytool store-credentials "AC_PASSWORD" \
  --key /path/to/AuthKey_XXXX.p8 \
  --key-id XXXXXXXXXX \
  --issuer "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Notarization Workflow

```bash
# Step 1: Build and sign
xcodebuild archive -scheme MyApp \
  -archivePath MyApp.xcarchive \
  CODE_SIGN_IDENTITY="Developer ID Application: My Company (TEAMID)"

# Step 2: Export from archive
xcodebuild -exportArchive \
  -archivePath MyApp.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath ./export/

# Step 3: Create .zip for notarization
ditto -c -k --keepParent export/MyApp.app MyApp.zip

# Step 4: Submit (blocks until complete)
xcrun notarytool submit MyApp.zip \
  --keychain-profile "AC_PASSWORD" --wait

# Step 5: Staple the ticket
xcrun stapler staple export/MyApp.app

# Step 6: Validate
xcrun stapler validate export/MyApp.app
```

### Async Submit

```bash
# Non-blocking submit
xcrun notarytool submit MyApp.zip \
  --keychain-profile "AC_PASSWORD" --output-format json > submission.json

# Check status
xcrun notarytool info "$(jq -r .id submission.json)" \
  --keychain-profile "AC_PASSWORD"

# Retrieve rejection log
xcrun notarytool log "$(jq -r .id submission.json)" \
  --keychain-profile "AC_PASSWORD" notarization.log
```

### What Apple Checks

- Hardened Runtime enabled on all binaries
- No known malware signatures
- No private entitlements (reserved Apple-only)
- Secure timestamp present
- All binaries and frameworks are signed

### Stapler

`stapler` attaches the notarization ticket to the binary so Gatekeeper can verify offline:

```bash
xcrun stapler staple MyApp.app
xcrun stapler staple MyInstaller.pkg
xcrun stapler validate MyApp.app
```

After stapling, air-gapped users can launch the app without Gatekeeper needing network access.

---

## Certificate Lifecycle Management

### Certificate Creation

**Via Apple Developer Portal:**
- developer.apple.com > Certificates, IDs & Profiles
- Create Certificate > choose type > upload CSR

**Via Keychain Access (interactive):**
1. Keychain Access > Certificate Assistant > Request Certificate from CA
2. Generate CSR -- private key stays in Keychain
3. Upload CSR at developer.apple.com > Download certificate
4. Double-click to import

**Via Xcode (Automatic Signing):**
Xcode creates and manages certificates automatically when `Automatically manage signing` is checked. Best for individual developers; problematic for CI.

### Expiry Monitoring

```bash
# Check expiry of all signing identities
security find-identity -v -p codesigning

# Check specific certificate
security find-certificate -c "Developer ID Application" -p | \
  openssl x509 -noout -enddate
```

### Automatic vs Manual Signing

| Mode | Description | Best For |
|---|---|---|
| Automatic | Xcode creates/manages cert + profile | Individual devs, small teams |
| Manual | Admin controls exact cert + profile | CI/CD, enterprise, shared certs |

Manual signing in CI: set `CODE_SIGN_IDENTITY`, `PROVISIONING_PROFILE_SPECIFIER`, and `DEVELOPMENT_TEAM` as xcodebuild arguments or in xcconfig files.

---

## CI/CD Signing Best Practices

### GitHub Actions Example

```yaml
jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select --switch /Applications/Xcode_16.app
      - name: Import signing certificate
        env:
          P12_BASE64: ${{ secrets.CERT_P12_BASE64 }}
          P12_PASSWORD: ${{ secrets.CERT_P12_PASSWORD }}
          KEYCHAIN_PASSWORD: temppass123
        run: |
          echo "$P12_BASE64" | base64 --decode > cert.p12
          security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security list-keychains -s build.keychain
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security import cert.p12 -k build.keychain \
            -P "$P12_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: \
            -s -k "$KEYCHAIN_PASSWORD" build.keychain
      - name: Build and archive
        run: xcodebuild archive -scheme MyApp -archivePath MyApp.xcarchive
```

### Key CI Principles

- Use temporary keychains; never pollute system keychain
- `set-key-partition-list` is mandatory for headless signing
- Store P12 and API keys as CI secrets (base64-encoded)
- Clean up temporary keychains after build
- Pin Xcode version; avoid App Store auto-updates

---

## Diagnostics

```bash
# Deep signature verification
codesign --verify --deep --strict --verbose=4 MyApp.app

# Gatekeeper assessment
spctl --assess --type execute --verbose MyApp.app

# Validate notarization staple
xcrun stapler validate MyApp.app

# List all signing identities
security find-identity -v

# Gatekeeper global status
spctl --status

# Notarization history
xcrun notarytool history --keychain-profile "AC_PASSWORD" --page-size 10

# Rejection log for a submission
xcrun notarytool log <submission-uuid> --keychain-profile "AC_PASSWORD"
```
