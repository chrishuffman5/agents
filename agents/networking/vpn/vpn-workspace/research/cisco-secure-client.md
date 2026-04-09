# Cisco Secure Client (AnyConnect) Deep Dive

## Overview

Cisco Secure Client (formerly AnyConnect Secure Mobility Client) is Cisco's enterprise VPN and endpoint security client. It was rebranded from AnyConnect to Cisco Secure Client in 2022 with the release of version 5.0. The client is modular — the VPN module is the core, with optional security modules added depending on licensing and deployment requirements.

**Current version (as of February 2026):** 5.1.14.145 (MR 14, released January 15, 2026)

---

## Architecture: Secure Client 5.x

### Rebranding from AnyConnect
- AnyConnect 4.x → Cisco Secure Client 5.x (2022)
- Package names changed: `anyconnect-win-*.pkg` → `cisco-secure-client-win-*.pkg`
- Profile XML files still use AnyConnect schema for backward compatibility
- Headend (ASA/FTD) still uses `anyconnect` in many CLI commands

### Module Architecture

Cisco Secure Client is built as a modular platform where the core VPN module is supplemented by optional security modules:

| Module | Function | Licensing |
|--------|----------|-----------|
| **VPN** | Core remote access VPN (SSL/DTLS, IKEv2) | Included with base license |
| **Umbrella Roaming Security** | DNS-layer security via Cisco Umbrella; enforces DNS policy off-network | Requires Umbrella subscription |
| **AMP Enabler** | Deploys Cisco Secure Endpoint (formerly AMP for Endpoints) to the device | Requires Secure Endpoint license |
| **ISE Posture** | Endpoint compliance checks for ISE NAC (OS version, AV, disk encryption) | Requires ISE Premier License |
| **Secure Firewall Posture** | Formerly HostScan; posture assessment for ASA/FTD headends without ISE | Included with Secure Client Plus |
| **Network Visibility Module (NVM)** | Collects endpoint flow telemetry (IPFIX-based) for Cisco XDR/Stealthwatch | Requires NVM license |
| **Zero Trust Access (ZTA) Module** | Per-app zero trust access; auto-pause when on trusted network | Requires Cisco Secure Access subscription |
| **Start Before Login (SBL)** | Establishes VPN before Windows user login (Group Policy scripts, pre-logon) | Included; requires Windows setup |

Each module can be deployed selectively. Modules are distributed as separate package files and can be bundled in a web-deploy package on the headend or pre-deployed via MDM/SCCM.

---

## VPN Protocols

### SSL/TLS with DTLS

The primary VPN mode for remote access:

**TLS (TCP 443):**
- Used for initial connection establishment and fallback
- Full tunnel data transport when DTLS is unavailable
- Supported: TLSv1.2 (minimum), TLSv1.3 on modern ASA/FTD with ASA 9.10.1+ and ASDM 7.10.1+
- Performance: limited by TCP head-of-line blocking; suitable for control but not optimal for data

**DTLS (UDP 443):**
- Preferred data transport — avoids TCP-over-TCP retransmission issues
- DTLS 1.0 (RFC 4347) default; DTLSv1.2 supported with ASA 9.10.1+
- Negotiated after TLS control channel established
- Fall back to TLS if UDP/443 is blocked; client shows "DTLS not available" in logs
- Significant performance improvement over TLS-only mode (~30-50% throughput increase)

**Protocol selection flow:**
1. Client connects to headend on TCP/443 (TLS)
2. Headend sends DTLS parameters in TLS channel
3. Client opens UDP/443 DTLS session in parallel
4. Data flows over DTLS; control remains on TLS
5. If DTLS fails, data falls back to TLS automatically

### IPsec/IKEv2

Supported on FTD (Firepower Threat Defense) headends:
- IKEv2 for key exchange; ESP tunnel mode for data
- Provides better performance than SSL for high-throughput use cases
- Negotiated automatically or forced via profile setting
- On FTD: `IKEv2 enable outside` in Platform Settings
- Certificate or PSK authentication for IKEv2
- Useful when UDP traffic is less restricted (corporate WANs, managed devices)

**Protocol priority (FTD):** IKEv2 attempted first if configured; fall back to SSL if IKEv2 fails

---

## Deployment

### Headend Platforms

| Platform | VPN Protocols | Management |
|----------|--------------|-----------|
| **Cisco ASA** | SSL/DTLS, IKEv2 | ASDM, CLI, Cisco Defense Orchestrator (CDO) |
| **Cisco FTD** | SSL/DTLS, IKEv2 | FMC (Firepower Management Center), FDM, CDO |
| **Cisco Catalyst SD-WAN** | SSL (client VPN) | vManage |
| **Cisco Secure Access** | Cloud-delivered ZTNA + VPN | Secure Access dashboard |

### Web Deploy (On-Demand Installation)

The simplest deployment model — users browse to the headend and download the client:

1. User navigates to `https://vpn.example.com` in browser
2. Headend serves web page with download link or Java/ActiveX launcher
3. Client installer runs, installs Secure Client modules
4. After installation, VPN connects automatically

**ASA configuration:**
```
webvpn
  enable outside
  anyconnect image disk0:/cisco-secure-client-win-5.1.14.145-webdeploy-k9.pkg 1
  anyconnect enable
  tunnel-group-list enable
```

**Limitation:** Web deploy requires user to access the headend URL initially. Not suitable for always-on or pre-logon VPN. On Windows 11 ARM64, use Chrome or Edge (not Internet Explorer) for web launch.

### Pre-Deploy (MSI/PKG)

Distribute the full installer package via:
- **Microsoft Intune / Endpoint Manager:** Upload MSI, assign to device groups, silent install
- **SCCM (System Center Configuration Manager):** Traditional enterprise software deployment
- **Group Policy (GPO):** MSI deployment via Active Directory
- **macOS MDM (Jamf, Kandji):** PKG deployment

Pre-deploy package includes all selected modules. Profile XML files deployed via MDM as well.

**Silent install (Windows MSI):**
```
msiexec /package cisco-secure-client-win-5.1.14.145-core-vpn-predeploy-k9.msi /quiet /norestart
msiexec /package cisco-secure-client-win-5.1.14.145-isecposture-predeploy-k9.msi /quiet /norestart
```

### Always-On VPN

Prevents access to Internet resources when not on a trusted network and VPN is not connected:

**Behavior:**
- VPN connects automatically after user login
- If VPN disconnects, traffic is blocked (or fail-open depending on policy)
- Users cannot manually disconnect
- Exceptions: captive portal detection (redirects allowed temporarily)

**ASA group policy configuration:**
```
group-policy GP-ALWAYS-ON attributes
  vpn-tunnel-protocol ssl-client
  anyconnect keep-installer installed
  anyconnect modules value umbrella
  
webvpn
  anyconnect profiles value PROFILE-ALWAYS-ON type user
```

**VPN Profile XML (always-on settings):**
```xml
<AlwaysOn>true</AlwaysOn>
<AllowVPNDisconnect>false</AllowVPNDisconnect>
<CaptivePortalRemediationBrowserFailover>true</CaptivePortalRemediationBrowserFailover>
```

### Split Tunneling

**Include-list (exclusive split tunnel):**
Only specified subnets route through VPN; all other traffic goes to local network.
```
access-list SPLIT-INCLUDE permit ip 10.0.0.0 255.0.0.0 any
group-policy GP-SPLIT attributes
  split-tunnel-policy excludespecified
  split-tunnel-network-list value SPLIT-INCLUDE
```

**Exclude-list (inclusive with exceptions):**
All traffic goes through VPN except specified destinations.
```
access-list SPLIT-EXCLUDE permit ip any 192.168.1.0 255.255.255.0   ! Local network
group-policy GP-SPLIT attributes
  split-tunnel-policy tunnelspecified
  split-tunnel-network-list value SPLIT-EXCLUDE
```

**Dynamic Split Tunneling (FQDN-based):**
Allows specifying FQDNs (e.g., `*.microsoft.com`, `*.zoom.us`) to exclude from the VPN tunnel dynamically. The client resolves the FQDN and excludes the resulting IPs:
```
dynamic-access-policy-record DfltAccessPolicy
  anyconnect-custom-attr dynamic-split-exclude-domains value zoom.us,*.microsoft.com
```
Or via group policy:
```
group-policy GP-SPLIT attributes
  anyconnect-custom dynamic-split-exclude-domains value "office365-bypass"
```

**Per-App VPN (Mobile):**
iOS and Android support per-app VPN — only traffic from specified apps routes through VPN. Configured via MDM profile (e.g., Intune) with VPN profile specifying app bundle IDs.

---

## Authentication

### SAML (SAML 2.0)

Modern SSO authentication leveraging corporate identity providers (Azure AD/Entra ID, Okta, Ping, etc.):

**ASA configuration:**
```
! Import IdP certificate
crypto ca trustpoint AZURE-SAML
  revocation-check none
  no id-usage
  enrollment terminal
  no ca-check

crypto ca authenticate AZURE-SAML

! Configure SAML
webvpn
  saml idp https://sts.windows.net/<tenant-id>/
    url sign-in https://login.microsoftonline.com/<tenant-id>/saml2
    url sign-out https://login.microsoftonline.com/<tenant-id>/saml2
    trustpoint idp AZURE-SAML
    trustpoint sp SELF-SIGNED
    
! Bind SAML to tunnel group
tunnel-group CORP-VPN webvpn-attributes
  authentication saml
  saml identity-provider https://sts.windows.net/<tenant-id>/
  group-alias CORP-VPN enable
```

**Embedded browser vs. system browser:**
- Secure Client 5.x can use the **client's local/system browser** for SAML authentication
- Enables true SSO: if user is already signed into browser with corporate credentials, VPN auth is seamless
- Supports biometric authentication (Windows Hello, TouchID) and hardware tokens (Yubikey)
- Configured in VPN profile: `<UseExternalBrowser>true</UseExternalBrowser>`

### Certificate-Based Authentication

**Machine certificate (device auth):**
```
tunnel-group CORP-VPN webvpn-attributes
  authentication certificate
  
ssl certificate-authentication interface outside port 443

! Map certificate to connection profile
tunnel-group-map default-group CORP-VPN
```

**Certificate + SAML (dual auth):**
```
tunnel-group CORP-VPN webvpn-attributes
  authentication saml certificate    ! Certificate first, then SAML
```

**Double authentication:** Certificate for device identity + SAML for user identity — satisfies both device and user trust requirements.

### LDAP / Active Directory

```
aaa-server CORP-AD protocol ldap
  server-port 389
aaa-server CORP-AD (inside) host 10.1.0.10
  ldap-base-dn dc=corp,dc=example,dc=com
  ldap-scope subtree
  ldap-naming-attribute sAMAccountName
  ldap-login-dn cn=vpnbind,cn=Users,dc=corp,dc=example,dc=com
  ldap-login-password BINDPASSWORD

tunnel-group CORP-VPN general-attributes
  authentication-server-group CORP-AD
```

### RADIUS with MFA (Duo Integration)

```
aaa-server DUO-RADIUS protocol radius
aaa-server DUO-RADIUS (inside) host 10.1.0.20
  key RADIUSSECRET
  authentication-port 1812

tunnel-group CORP-VPN general-attributes
  authentication-server-group DUO-RADIUS
```

Duo Authentication Proxy intercepts RADIUS requests, performs primary auth against AD/LDAP, then calls Duo API for second factor (push notification, TOTP, SMS).

---

## DAP (Dynamic Access Policies)

DAP is an ASA feature that dynamically adjusts user access and attributes based on endpoint posture, group membership, and other attributes at connection time.

**DAP evaluation flow:**
1. User connects and authenticates
2. ASA evaluates all configured DAP records against user/endpoint attributes
3. Matching DAP records are merged (aggregated)
4. Final policy applied: ACLs, bookmarks, split tunnel lists, or connection terminate

**Key DAP attributes:**
- `endpoint.os.version` — Operating system version
- `endpoint.anyconnect.clientversion` — Secure Client version
- `endpoint.av.product-name` — Antivirus product name
- `endpoint.disk.encrypted` — Disk encryption status (Secure Firewall Posture)
- `aaa.ldap.memberOf` — AD group membership
- `aaa.radius.class` — RADIUS class attribute

**Example DAP record (require disk encryption):**
```
dynamic-access-policy-record REQUIRE-ENCRYPTION
  description "Require full disk encryption"
  
! In ASDM: DAP > Add Record > Endpoint Attributes > Disk Encryption
! CLI representation:
dynamic-access-policy-record REQUIRE-ENCRYPTION
  action terminate
  message "Disk encryption required to connect."
  
! Attribute: endpoint.disk.encrypted = false → terminate
```

**Group policy selection via DAP:**
DAP can assign a group policy dynamically, overriding the default tunnel-group assignment:
```
dynamic-access-policy-record ADMIN-USERS
  network-acl "ADMIN-ACL"
  group-policy GP-FULL-ACCESS
! Condition: aaa.ldap.memberOf contains "VPN-Admins"
```

---

## Posture

### Secure Firewall Posture (HostScan)

The Secure Firewall Posture module (formerly HostScan) runs on the endpoint before or during authentication and checks:
- Operating system version and patch level
- Antivirus/antimalware product presence and definition age
- Personal firewall status
- Disk encryption status
- Specific registry keys or file presence (Windows)
- Process presence

Results are sent to the ASA, which evaluates them in DAP policies.

**Configuration:**
```
webvpn
  anyconnect-custom-attr HostScan version 4.10.x
  hostscan enable
  
! In ASDM: Remote Access VPN > Posture > HostScan Image
```

### ISE Posture (Network Access Control)

Full ISE-based posture for more granular control:

1. User connects to VPN (or wired/wireless network)
2. ISE Posture module on client communicates with ISE Policy Service Node (PSN)
3. ISE evaluates posture policy (compliance checks)
4. ISE returns posture status: Compliant, Non-Compliant, or Unknown
5. RADIUS Change of Authorization (CoA) pushes new policy to network device based on compliance
6. Non-compliant endpoints redirected to remediation portal or quarantine VLAN

**Requirements:** Cisco ISE Premier License on ISE Administration Node

**Checks available:**
- OS version compliance (patch level)
- Antivirus/antispyware (product, version, definition currency) — via OPSWAT
- Disk encryption (BitLocker, FileVault, McAfee, Symantec)
- Firewall status
- Application presence/absence
- Registry/file conditions
- External process execution

---

## Trusted Network Detection (TND)

TND allows Secure Client to automatically connect or disconnect VPN based on whether the device is on a trusted (corporate) network.

**Detection methods:**
1. **DNS domain match:** If DHCP-assigned DNS suffix matches configured trusted domain(s)
2. **DNS server match:** If configured DNS server IPs are reachable
3. **Trusted server HTTPS:** If specified HTTPS URL returns expected certificate (server probe)

**VPN Profile XML configuration:**
```xml
<TrustedNetworkPolicy>Disconnect</TrustedNetworkPolicy>  <!-- Disconnect VPN when on trusted net -->
<UntrustedNetworkPolicy>Connect</UntrustedNetworkPolicy>  <!-- Connect VPN when off trusted net -->
<TrustedDNSDomains>corp.example.com</TrustedDNSDomains>
<TrustedDNSServers>10.1.0.1,10.1.0.2</TrustedDNSServers>
<TrustedHTTPSServerList>
  <ServerName>internal.corp.example.com</ServerName>
</TrustedHTTPSServerList>
```

**Important TND behavior:**
- TND is **client-side only** — no ASA/FTD configuration required
- TND does **not** disconnect manually initiated VPN sessions
- TND only triggers on network/interface change events
- `TrustedNetworkPolicy = Disconnect`: VPN auto-disconnects when trusted network detected
- `UntrustedNetworkPolicy = Connect`: VPN auto-initiates when on untrusted network (requires Always-On or similar)
- Zero Trust Access (ZTA) module TND: pauses ZTA configuration on trusted network, resumes on untrusted

---

## Management

### ASA Profile Editor (ASDM)

The VPN Client Profile is an XML file that controls client behavior. Configured in ASDM:
`Remote Access VPN > Network (Client) Access > AnyConnect Client Profile`

Critical profile settings:
```xml
<ServerList>
  <HostEntry>
    <HostName>Corporate VPN</HostName>
    <HostAddress>vpn.corp.example.com</HostAddress>
    <PrimaryProtocol>SSL</PrimaryProtocol>
  </HostEntry>
</ServerList>
<AutoReconnect>true</AutoReconnect>
<AutoUpdate>true</AutoUpdate>
<RetainVpnOnLogoff>false</RetainVpnOnLogoff>
<CaptivePortalRemediationBrowserFailover>true</CaptivePortalRemediationBrowserFailover>
<WindowsVPNEstablishment>LocalUsersOnly</WindowsVPNEstablishment>
```

### Cisco XDR / Secure Client Cloud Management

- Cisco Secure Client 5.x supports cloud-based management via Cisco XDR (Extended Detection and Response) platform
- Cloud Management enables remote deployment of module updates, profile updates, and policy changes without needing to update the headend
- Flexible deployment paths: Cisco Secure Access dashboard, Cisco software portal, Cloud Management
- Network Visibility Module (NVM) data feeds into XDR for endpoint visibility

### Cisco Defense Orchestrator (CDO)

- Cloud-based management for ASA and FTD headends
- Manage VPN configuration, certificate management, policy updates across multiple headends from single console
- Supports bulk changes to tunnel groups, group policies, and ACLs

---

## Troubleshooting

### DART (Diagnostic and Reporting Tool)

DART is the primary troubleshooting utility included with Secure Client:
- Collects logs from all installed Secure Client modules
- Captures system information (OS, network configuration, routes)
- Exports to zip archive for support ticket submission

**Running DART:**
- Windows: Start Menu > Cisco > DART or `%ProgramFiles%\Cisco\Cisco Secure Client\DART\dartui.exe`
- macOS: `/Applications/Cisco/DART.app`
- Can be run standalone without active VPN session
- Output: `DARTBundle_<timestamp>.zip` on desktop

**Key log files collected:**
```
vpn.log              — VPN module events
dart.log             — DART collection log
syslog.log           — System event log
AnyConnect VPN Statistics.log — Connection statistics
```

### Common Errors and Resolutions

**Certificate validation errors:**
- "The certificate from the secure gateway is invalid" — Headend certificate not trusted by client
- Check: CA certificate in Windows/macOS trust store; ASA using self-signed cert
- Fix: Deploy CA cert via GPO/MDM or use publicly trusted certificate on ASA
- Check clock sync: certificate validity time check fails if >5 minute skew

**DTLS issues:**
- "DTLS connection attempt failed, will use TLS" — UDP/443 blocked by firewall or NAT
- Check: UDP/443 open through firewall; NAT not mangling UDP 443
- Workaround: TLS-only mode (no DTLS) via profile: `<DTLSPort>0</DTLSPort>` — disables DTLS

**Split tunnel problems:**
- Traffic not routing through VPN after split tunnel config change
- Check: `show vpn-sessiondb detail anyconnect filter name <user>` — verify split tunnel list applied
- Debug: `debug webvpn anyconnect 255`
- Common cause: DAP overriding group policy split tunnel list

**Authentication failures:**
- SAML: check IdP metadata, certificate expiry, clock sync
- LDAP: verify bind DN, password, base DN, LDAP server reachability
- Certificate: verify EKU (clientAuth required), CRL/OCSP connectivity

**Connection stuck at "Connecting":**
- Check: TCP/443 and UDP/443 reachable from client to headend IP
- Check: DNS resolution of headend hostname
- `debug webvpn 255` on ASA for detailed SSL/TLS handshake debug
- DART bundle to examine `vpn.log` for phase indication

### ASA Debug Commands
```
debug webvpn anyconnect 255        ! AnyConnect/Secure Client protocol
debug webvpn saml 25               ! SAML authentication flow
debug aaa authentication 255       ! AAA authentication events
debug aaa authorization 255        ! Authorization/DAP evaluation
debug crypto ikev2 protocol 255    ! IKEv2 (for IKEv2 VPN connections)
debug crypto ipsec 255             ! IPsec SAs (IKEv2 connections)

show vpn-sessiondb anyconnect      ! Active Secure Client sessions
show vpn-sessiondb detail anyconnect filter name <username>
show webvpn group-policy           ! Group policy summary
show run tunnel-group <name>       ! Tunnel group configuration
show run group-policy <name>       ! Group policy configuration
show crypto ca certificates        ! Certificate details
show version                       ! Software version
```

---

## Platform Support (5.1.x)

| Platform | Notes |
|----------|-------|
| Windows 10 (x86/x64) | Fully supported |
| Windows 11 (x86/x64) | Fully supported |
| Windows 11 ARM64 | Supported; use Chrome/Edge for web launch; ARM64 native driver |
| Windows 11 ARM64 SBL | Start Before Login supported |
| macOS 12/13/14/15 | Network Extension framework (kernel ext. deprecated) |
| Linux (RHEL, Ubuntu, Debian) | Core VPN + select modules |
| iOS 16+ | Per-app VPN, IKEv2, SSL |
| Android 10+ | SSL/DTLS VPN |

**ARM64 Windows 11 notes:**
- Native ARM64 binaries in 5.1.x — significantly better performance than x64 emulation
- SBL (Start Before Login) supported on ARM64 with Microsoft-supported Windows 11 versions
- Known issue (resolved in 5.1.1+): Upgrading from 5.1.0.x via web deploy fails on ARM64; requires manual uninstall first

---

## Version Reference

| Version | Release Date | Key Changes |
|---------|--------------|-------------|
| 5.1.14.145 (MR 14) | January 2026 | Cloud management default; flexible deploy paths |
| 5.1.13.177 (MR 13) | 2025 | Device serial number for device ID calculation |
| 5.1.12.146 (MR 12) | 2025 | New probe type for protected network detection (macOS) |
| 5.1.9.113 (MR 9) | 2025 | Optimized protection restoration timing; region-specific resolver IPs |
| 5.0.x | 2022-2023 | Initial Cisco Secure Client rebrand from AnyConnect 4.x |
| 4.10.x | 2021-2022 | Final AnyConnect release series |

**Upgrade paths:** Users on 5.1.8 must upgrade to 5.1.13+ before November 20, 2025. Users on 5.1.9–5.1.10 must upgrade before January 14, 2026 (support end dates).

---

## Licensing Summary

| Tier | Included Modules | Notes |
|------|-----------------|-------|
| Secure Client Advantage | VPN, Umbrella (limited) | Entry level |
| Secure Client Premier | VPN, Secure Firewall Posture, NVM, AMP Enabler | Full enterprise |
| Cisco Secure Access | ZTA Module, full cloud-delivered SASE | Cloud-first model |
| ISE Premier (separate) | ISE Posture module activation | Required for ISE NAC posture |
