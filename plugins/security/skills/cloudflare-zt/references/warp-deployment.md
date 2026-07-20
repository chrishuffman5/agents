# WARP Client Deployment, Enrollment, and Posture Checks

### Deployment and Enrollment

**MDM enrollment:**
WARP can be mass-deployed via MDM with pre-configured organization enrollment:

**Intune deployment (Windows):**
```
# WARP MSI installer with organization enrollment
INSTALL_SERVICE=1 ORGANIZATION=your-org-name.cloudflareaccess.com
```

**Jamf deployment (macOS):**
```xml
<!-- Managed preferences for WARP enrollment -->
<key>organization</key>
<string>your-org-name.cloudflareaccess.com</string>
<key>auto_connect</key>
<integer>1</integer>
```

**Split tunneling:**
Configure traffic to bypass WARP (route directly):
- Private IP ranges that should go to VPN/direct
- M365 Optimize category endpoints (Microsoft's recommended bypass list)
- Applications that break with proxying

### Posture Checks via WARP

WARP collects and reports device posture for Access policy enforcement:

```
Zero Trust Dashboard → Settings → WARP Client → Device Posture
Available checks:
- OS Version (min version required)
- Disk Encryption (BitLocker/FileVault)
- Firewall enabled
- Antivirus present + up-to-date
- Specific serial numbers (allowlist)
- Domain joined
- Running process (verify EDR agent)
- File present (custom agent check)
- Certificate check (client cert on device)
- CrowdStrike ZTA score
- Intune compliance status
- Tanium score
```
