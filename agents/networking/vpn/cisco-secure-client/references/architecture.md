# Cisco Secure Client Architecture Reference

## Rebranding
- AnyConnect 4.x -> Cisco Secure Client 5.x (2022)
- Package names: `cisco-secure-client-*` (was `anyconnect-*`)
- Profile XML still uses AnyConnect schema for backward compatibility
- Headend CLI still uses `anyconnect` in many commands

## VPN Protocol Details

### SSL/TLS + DTLS
- TLS (TCP 443): Control channel and data fallback
- DTLS (UDP 443): Preferred data transport
- DTLS avoids TCP-over-TCP retransmission (~30-50% throughput gain)
- TLS 1.2 minimum; TLS 1.3 on ASA 9.10.1+
- DTLS 1.0 default; DTLS 1.2 on ASA 9.10.1+

### Protocol Flow
1. Client connects TCP/443 (TLS)
2. Headend sends DTLS parameters in TLS channel
3. Client opens UDP/443 DTLS session in parallel
4. Data flows over DTLS; control on TLS
5. If DTLS fails, data falls back to TLS automatically

### IPsec/IKEv2
- Supported on FTD headends
- IKEv2 for key exchange; ESP tunnel for data
- Better performance than SSL for high throughput
- On FTD: `IKEv2 enable outside` in Platform Settings

## Headend Platforms

| Platform | Protocols | Management |
|---|---|---|
| Cisco ASA | SSL/DTLS, IKEv2 | ASDM, CLI, CDO |
| Cisco FTD | SSL/DTLS, IKEv2 | FMC, FDM, CDO |
| Catalyst SD-WAN | SSL (client VPN) | vManage |
| Cisco Secure Access | Cloud ZTNA + VPN | Dashboard |

## Authentication Methods

### SAML 2.0
- Azure AD/Entra ID, Okta, Ping Identity
- System browser support: true SSO with biometric, hardware tokens
- Profile: `<UseExternalBrowser>true</UseExternalBrowser>`

### Certificate
- Machine cert for device trust
- Dual auth: cert + SAML for device AND user trust

### LDAP / Active Directory
```
aaa-server CORP-AD protocol ldap
aaa-server CORP-AD (inside) host 10.1.0.10
  ldap-base-dn dc=corp,dc=example,dc=com
  ldap-naming-attribute sAMAccountName
  ldap-login-dn cn=vpnbind,cn=Users,dc=corp,dc=example,dc=com
```

### RADIUS with MFA (Duo)
```
aaa-server DUO-RADIUS protocol radius
aaa-server DUO-RADIUS (inside) host 10.1.0.20
  key RADIUSSECRET
```

## DAP (Dynamic Access Policies)

### Evaluation Flow
1. User authenticates
2. ASA evaluates all DAP records against attributes
3. Matching records merged
4. Final policy: ACLs, bookmarks, group policy, or terminate

### Key Attributes
- `endpoint.os.version` -- OS version
- `endpoint.anyconnect.clientversion` -- Client version
- `endpoint.av.product-name` -- AV product
- `endpoint.disk.encrypted` -- Disk encryption
- `aaa.ldap.memberOf` -- AD group membership
- `aaa.radius.class` -- RADIUS class

## Split Tunneling

### Include (tunnel specified)
```
split-tunnel-policy tunnelspecified
split-tunnel-network-list value INCLUDE-ACL
```

### Exclude (exclude specified)
```
split-tunnel-policy excludespecified
split-tunnel-network-list value EXCLUDE-ACL
```

### Dynamic (FQDN-based)
```
anyconnect-custom dynamic-split-exclude-domains value "zoom.us,*.microsoft.com"
```

### Per-App VPN (Mobile)
iOS/Android: only specified app traffic through VPN. Configured via MDM.

## TND (Trusted Network Detection)

### Detection Methods
1. DNS domain match (DHCP DNS suffix)
2. DNS server match (configured DNS IPs reachable)
3. Trusted HTTPS server probe (URL returns expected certificate)

### Behavior
- Client-side only; no headend config needed
- Only triggers on network/interface change events
- Does NOT disconnect manually initiated VPN
- ZTA module: pauses ZTA on trusted network

## Posture

### Secure Firewall Posture (HostScan)
- Checks: OS version, AV, firewall, disk encryption, registry, processes
- Results evaluated in DAP on ASA
- `hostscan enable` on ASA

### ISE Posture
- Full compliance via ISE Policy Service Node
- RADIUS CoA for dynamic policy enforcement
- Compliant/Non-Compliant/Unknown status
- Requires ISE Premier license

## Deployment

### Web Deploy
```
webvpn
  enable outside
  anyconnect image disk0:/cisco-secure-client-*.pkg 1
  anyconnect enable
  tunnel-group-list enable
```

### Pre-Deploy
```
msiexec /package cisco-secure-client-*-core-vpn-predeploy-k9.msi /quiet /norestart
msiexec /package cisco-secure-client-*-isecposture-predeploy-k9.msi /quiet /norestart
```

## Platform Support (5.1.x)

| Platform | Notes |
|---|---|
| Windows 10/11 x64 | Fully supported |
| Windows 11 ARM64 | Native ARM64 binaries; SBL supported |
| macOS 12-15 | Network Extension framework |
| Linux (RHEL, Ubuntu) | Core VPN + select modules |
| iOS 16+ | Per-app VPN, IKEv2, SSL |
| Android 10+ | SSL/DTLS VPN |

## Version Reference

| Version | Key Changes |
|---|---|
| 5.1.14 (MR14, Jan 2026) | Cloud management default; flexible deploy |
| 5.1.13 (MR13) | Device serial for device ID |
| 5.0.x (2022-2023) | Initial rebrand from AnyConnect 4.x |

## Licensing

| Tier | Modules |
|---|---|
| Advantage | VPN, Umbrella (limited) |
| Premier | VPN, Posture, NVM, AMP Enabler |
| Secure Access | ZTA, cloud SASE |
| ISE Premier (separate) | ISE Posture activation |

## Troubleshooting Commands (ASA)

```
debug webvpn anyconnect 255        # Protocol debug
debug webvpn saml 25               # SAML flow
debug aaa authentication 255       # AAA events
debug aaa authorization 255        # Authorization/DAP
debug crypto ikev2 protocol 255    # IKEv2 (if used)
show vpn-sessiondb anyconnect      # Active sessions
show vpn-sessiondb detail anyconnect filter name <user>
show crypto ca certificates        # Certificate details
```
