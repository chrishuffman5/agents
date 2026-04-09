# PAN-OS Key Features: Deep Technical Reference

## App-ID

App-ID is PAN-OS's application identification engine — the foundational feature that enables application-based policy rather than port-based policy.

### How App-ID Works: The Classification Pipeline

App-ID applies multiple classification mechanisms in sequence to identify the true application regardless of port, protocol, or evasion technique:

**Step 1: Initial Protocol Detection**
- The firewall examines the first few packets to determine the underlying protocol (TCP/UDP, specific well-known protocol signatures).
- IP protocol number, destination port, and initial packet content all inform this step.

**Step 2: Protocol Decoders**
- Decoders are applied for well-known protocols (HTTP, SSL/TLS, DNS, SMTP, FTP, SIP, RTSP, etc.).
- Decoders **validate protocol conformance** — they verify traffic actually follows the claimed protocol's spec.
- Decoders handle protocol complexity: NAT traversal, dynamic port allocation (FTP data channels, SIP media), multi-connection protocols.
- Example: HTTP decoder validates that traffic on port 80 actually uses valid HTTP request/response structure before applying HTTP-based App-IDs.
- Decoders also enable **tunneling detection** — e.g., detecting Yahoo Messenger running over HTTP, or Tor using SSL tunneling.

**Step 3: Application Signatures**
- After protocol identification, application-specific signatures are applied to the traffic stream.
- Signatures match on payload patterns, header fields, behavioral characteristics, and session metadata.
- Signatures are regularly updated via content updates (Applications and Threats content package, typically weekly).
- A single application may have multiple signatures matching different behaviors or versions.

**Step 4: Heuristics (Behavioral Analysis)**
- For applications that are evasive, encrypted, or otherwise resist signature-based classification, heuristic analysis is used.
- Heuristics analyze traffic patterns (session length, packet size distribution, timing, connection behavior) to infer application type.
- Used for: peer-to-peer applications, anonymizers, custom encrypted applications.

**Step 5: Continuous Re-classification**
- App-ID does not stop after the initial classification. As more data is observed in a session, App-ID may **update the application** mid-session.
- Example: a session initially classified as `web-browsing` may be reclassified to `facebook-base` after Facebook-specific patterns are observed, then to `facebook-posting` if posting behavior is detected.
- When an application is reclassified, PAN-OS re-evaluates the security policy against the new application. If the new application would be denied by a later policy, the session is terminated.

### Application Characteristics and Metadata
Each App-ID entry contains:
- **Category / Sub-category**: (e.g., business-systems > database; networking > encrypted-tunnel)
- **Technology**: (client-server, peer-to-peer, browser-based, network-protocol)
- **Risk level**: 1–5
- **Port dependence**: does the application require specific ports?
- **Evasive / Tunnels other apps / Transfers files / Has known vulnerabilities** — behavioral flags
- **Default ports**: the ports the application normally uses (relevant for `application-default` service in policy)
- **Timeouts**: TCP, UDP, and application-specific idle timeouts

### Application Override
Application Override tells PAN-OS to **skip App-ID** for matching traffic and label it with a specified application:
- Configuration: `Policies > Application Override` — match criteria (zones, IPs, ports) + override application assignment.
- **Impact**: the firewall treats the session as the specified application from the start; App-ID engine does NOT run for these sessions.
- **Loss of visibility**: no real Layer 7 inspection for overridden sessions. Threat prevention, Content-ID, and WildFire analysis are also effectively bypassed or severely limited because the application context is synthetic.
- **Use case**: primarily for proprietary/internal applications with unusual behavior that causes App-ID to misidentify them.
- **Preferred alternative**: create a Custom App-ID signature that correctly identifies the proprietary application — this preserves full security inspection while achieving correct identification.

### Custom App-IDs
When an internal or niche application isn't in the Palo Alto database:
1. Create a new application entry with category, sub-category, technology, risk, ports, timeouts.
2. Add custom signatures based on observed traffic patterns (pattern matching, context, protocol specification).
3. Optionally specify which parent decoder to use (HTTP-based, SSL-based, custom TCP).
4. The custom App-ID is included in App-ID lookups alongside built-in signatures.
- `Management > Develop > Application Signatures` in the GUI.
- App-ID PCAPs can be used to capture traffic and build signatures.

### App-ID Content Updates
- Delivered as part of the **Applications and Threats** content package.
- Updates add new App-IDs, modify existing ones, and retire obsolete ones.
- **App-ID impact analysis**: before installing a content update, PAN-OS can show which security policy rules would be affected by changed App-IDs. Run: `request content upgrade download-and-install` with review, or use Panorama's App-ID impact report.
- App-ID Cloud Engine (PAN-OS 11.1+): near-real-time App-ID updates from the cloud, bypassing the weekly release cycle for new application definitions.

---

## Content-ID

Content-ID is the suite of threat inspection engines applied after App-ID identification. Content-ID engines are configured via **Security Profiles** and attached to security policy rules.

### Threat Prevention Profiles

**Antivirus Profile**
- Scans file transfers (HTTP, SMTP, FTP, SMB, IMAP, POP3) for known malware signatures.
- Default action for viruses: alert or drop.
- WildFire Antivirus profile: extends antivirus signatures with WildFire-generated signatures (delivered within minutes of WildFire verdict vs. daily antivirus updates).
- Best practice: use the predefined "default" antivirus profile as a starting point and customize.

**Anti-Spyware Profile**
- Detects and blocks command-and-control (C2) communications, data exfiltration, and spyware activity.
- Matches DNS sinkholing: PAN-OS resolves DNS queries for known C2 domains to a sinkhole IP you control.
- DNS-based C2 detection and blocking.
- Threat severity levels: critical, high, medium, low, informational.
- Best practice: enable DNS sinkholing in the anti-spyware profile; configure DNS Security if using Advanced Threat Prevention.
- Exception lists: specific threat IDs can be excluded or have their action overridden.

**Vulnerability Protection Profile**
- IPS (Intrusion Prevention System) function — detects and blocks exploitation of known vulnerabilities in protocols and applications.
- Rules organized by CVE, threat ID, severity, attack type, and affected vendor/software.
- **Brute Force** detection: identify and block credential-stuffing and brute-force login attempts.
- **Protocol Anomaly**: block malformed packets that violate protocol specifications.
- Best practice: use the "strict" predefined profile or create a profile based on strict with exceptions for known-false-positive threat IDs.
- Advanced Threat Prevention (10.2+): adds inline cloud analysis for zero-day exploits not yet covered by signatures.

**URL Filtering Profile**
- Controls web access based on URL category (gambling, malware, phishing, social-media, etc.).
- PAN-DB: Palo Alto Networks' cloud-based URL categorization database. Queries happen in real-time; unknown URLs are submitted for categorization.
- Actions per category: allow, alert, block, continue (user override with acknowledgment), override (require password).
- **Safe Search Enforcement**: force safe search on Google, Bing, YouTube.
- **HTTP Header Logging**: capture HTTP headers (User-Agent, Referer, X-Forwarded-For) in URL logs.
- Advanced URL Filtering (10.2+): inline ML-based categorization for unknown/zero-day phishing and malicious URLs — catches URLs that PAN-DB hasn't seen yet.
- Custom URL categories: create allow/block lists that override PAN-DB categorization.

**File Blocking Profile**
- Controls file transfers by file type (PE executables, scripts, PDFs, archives, etc.) and direction (upload/download).
- Actions: allow, alert, block, continue, forward (to WildFire).
- Block specific file types in all directions as a baseline hardening measure.

**WildFire Analysis Profile**
- Defines which file types and protocols should be forwarded to WildFire for sandbox analysis.
- Analysis destination: WildFire public cloud, private cloud (WF-500 appliance), or regional cloud.
- File types: PE, ELF, APK, PDF, Office documents (DOC/XLS/PPT), scripts (PowerShell, JS, VBScript), archives.
- Email links (from SMTP/IMAP/POP3) can also be forwarded for URL reputation analysis.

### Best Practice Security Profiles
Palo Alto provides predefined profiles:
- **default**: moderate security, suitable for many deployments.
- **strict**: maximum protection, may require exception tuning to avoid false positives.
- **Outbound** / **Inbound** / **Internal**: context-appropriate profiles from iron-skillet.
Best practice: start with strict, then add exceptions for specific threat IDs that cause false positives in your environment rather than downgrading the entire profile.

### Security Profile Groups
Multiple profiles (AV + Anti-Spyware + Vuln + URL) can be combined into a **Security Profile Group** for easier policy assignment. Attach a Profile Group to security policy rules instead of individual profiles.

---

## User-ID

User-ID maps IP addresses to usernames, enabling user-and-group-based security policy.

### Integration Methods

**1. PAN User-ID Agent (Windows Service)**
- Installed on a Windows server (typically a DC or member server).
- Monitors Windows Security Event Log for logon events (Event IDs 4768, 4769, 4770, 4624, 4634).
- Also monitors Exchange, Citrix, Terminal Server events.
- The agent builds an IP-to-user mapping table and sends it to the firewall via XML API.
- Supports up to 50 monitored Domain Controllers.
- Use case: large enterprise environments; distributed DC monitoring.

**2. PAN-OS Integrated User-ID Agent (Agentless)**
- The firewall itself acts as the User-ID agent — directly monitors Windows Security Event Logs on domain controllers via WMI or Windows Eventing.
- No separate Windows agent installation required.
- Recommended for: ≤10 domain controllers, or if you want to share User-ID mappings with other PA devices (up to 255 devices can subscribe to one source).
- Limitation: higher firewall management plane CPU usage compared to dedicated Windows agent.

**3. Captive Portal**
- Fallback method for unauthenticated users.
- When traffic from an unknown IP hits the firewall, the user is redirected to a web page requiring authentication.
- Authentication methods: NTLM (transparent browser challenge), web form (RADIUS, LDAP, SAML, Kerberos, local).
- After authentication, the IP is mapped to the authenticated username.
- Use case: guest networks, BYOD users not joined to the domain, Linux/Mac machines not processed by the PAN agent.

**4. GlobalProtect (VPN/Endpoint)**
- The GlobalProtect agent on the endpoint passes the authenticated username directly to the firewall during VPN connection establishment.
- Provides the most reliable IP-to-user mapping because it's directly tied to VPN session state.
- Supports both external VPN users and internal users when GlobalProtect is deployed as an always-on solution.

**5. SAML IdP Integration**
- Authentication via a SAML 2.0 Identity Provider (Azure AD, Okta, Ping, etc.).
- User identity and group attributes are extracted from the SAML assertion.
- Group attribute must be explicitly mapped in the Authentication Profile (User Group Attribute field).
- Limitation: SAML alone does not automatically populate group mapping for policy — Cloud Identity Engine or LDAP is needed for dynamic group membership lookups.

**6. Cloud Identity Engine (CIE)**
- Cloud-based User-ID service — the modern replacement for on-premises agent methods in cloud/hybrid environments.
- Connects directly to Azure AD, Okta, Google Workspace, and other IdPs via cloud connector.
- Provides: User-to-IP mapping, group membership data, device compliance attributes.
- No on-premises agent or LDAP connectivity required.
- Recommended as the **primary User-ID method** for organizations using cloud identity providers.
- Available from PAN-OS 10.1; expanded in 11.0/11.1 to become feature-complete.

### Group Mapping
- After User-ID maps IP → username, the firewall needs to know group membership for group-based policy.
- Sources for group mapping: LDAP (Active Directory), CIE, SAML group attributes.
- Group mapping is configured separately from user mapping: `Device > User Identification > Group Mapping Settings`.
- Policy rules can reference AD groups, CIE groups, or custom local groups.
- Nested group support: the firewall can traverse nested group memberships (configurable depth).

### Syslog-Based User Mapping
- The User-ID agent (or integrated agent) can parse syslog messages from: wireless controllers, 802.1X NAC devices, proxy servers, Apple Open Directory, VPN concentrators.
- Syslog parse profiles define patterns to extract username and IP from log messages.

---

## Decryption

PAN-OS can decrypt SSL/TLS and SSH traffic for full inspection.

### SSL Forward Proxy (Outbound Decryption)
- **Use case**: decrypt and inspect outbound HTTPS traffic from internal users to the internet.
- **Mechanism**: the firewall acts as a man-in-the-middle proxy. It terminates the SSL session from the client (presenting a re-signed server certificate) and establishes a new SSL session to the server.
- **Certificate requirement**: a trusted CA certificate must be imported into the firewall. This certificate is used to re-sign server certificates on the fly. The CA cert must be trusted by all client browsers/applications — typically deployed via GPO (Active Directory).
- **Forward Trust Certificate**: used when the original server's certificate is trusted (valid, not expired, valid CA).
- **Forward Untrust Certificate**: used when the original server's certificate is untrusted (self-signed, expired, unknown CA) — typically configured to present an untrusted certificate to the client, generating a browser warning.
- **No-decrypt rules**: certain traffic should NOT be decrypted (banking, healthcare, HR applications, certificate-pinned apps). No-decrypt rules are evaluated before decrypt rules — matching traffic is explicitly excluded.

### SSL Inbound Inspection
- **Use case**: decrypt inbound HTTPS traffic to internal servers for inspection.
- **Mechanism**: the original server's private key and certificate are imported into the firewall. The firewall uses these to decrypt inbound TLS sessions without re-signing certificates — clients don't need to trust a custom CA.
- **Requirement**: access to the private key of the server being protected. Not feasible for cloud-hosted services or servers where private key access isn't available.
- Perfect Forward Secrecy (PFS) with DHE/ECDHE key exchanges cannot be decrypted via inbound inspection because the session key cannot be derived from the server's static private key alone.

### SSH Proxy
- Decrypts SSH sessions (port 22) to inspect SSH tunneling and data transfers.
- Generates its own SSH host key pair for the proxy.
- Applied via Decryption policy rules with a SSH Proxy decryption profile.
- Does NOT require importing server SSH host keys.

### Decryption Profiles
Attached to Decryption policy rules to control TLS/SSL parameters:
- **Protocol version restrictions**: enforce minimum TLS version (e.g., require TLS 1.2+, block TLS 1.0/1.1).
- **Key exchange algorithm restrictions**: require DHE/ECDHE; block RSA key exchange (no PFS).
- **Encryption algorithm requirements**: require AES-128-GCM or AES-256-GCM; block RC4, 3DES.
- **Authentication algorithm requirements**: require SHA-256+; block MD5 and SHA-1.
- **Certificate checks**: check server certificate validity, revocation (OCSP/CRL), and expiration.
- **Failure behavior**: block-if-resource-unavailable (block if OCSP/CRL check fails) vs. allow.

### Certificate Management for Decryption
- Certificates and keys can be stored in the firewall's software store or in an HSM (Hardware Security Module).
- HSM integration (SafeNet, nCipher, AWS CloudHSM) provides hardware-protected key storage — the private key for the forward proxy CA never leaves the HSM.
- Certificate lifecycle: forward proxy CA certificates should be rotated before expiration; clients must be updated with the new CA trust anchor simultaneously.

### No-Decrypt Rules
Critical for correct decryption policy design:
- Certificate-pinned applications (many mobile apps, some desktop clients) will fail if intercepted by SSL forward proxy — must be excluded.
- Applications where decryption violates compliance or legal requirements (banking, HR, health).
- No-decrypt rules are placed **above** decrypt rules in the Decryption policy rulebase (they are evaluated top-down, first-match just like security policy).

---

## WildFire

WildFire is Palo Alto's cloud-based malware analysis service.

### Analysis Mechanism
1. Files matching the WildFire Analysis Profile are extracted from sessions.
2. Files are submitted to WildFire (cloud or local WF-500 appliance).
3. WildFire detonates the file in instrumented virtual machines (Windows, Linux, Android environments).
4. Behavioral analysis records file system changes, registry changes, network connections, process spawning, anti-analysis technique detection.
5. A verdict is returned; a signature is generated.

### Verdict Types
- **Benign**: no malicious behavior observed; safe.
- **Grayware**: not directly harmful but potentially unwanted — adware, spyware, browser hijackers. Does not pose direct security threat but may violate acceptable use policies.
- **Malicious**: confirmed malware — ransomware, trojans, backdoors, exploits, etc.
- **Phishing**: URL analysis determined the content is a phishing page designed to harvest credentials.

**Important**: the WF-500 local appliance **does NOT support the phishing verdict**. Links submitted to a WF-500 are classified as malicious if they are phishing pages (no separate phishing classification).

### Cloud vs. Local (WF-500)
| Feature | WildFire Cloud | WF-500 Appliance |
|---------|----------------|------------------|
| Verdict types | Benign, Grayware, Malicious, Phishing | Benign, Grayware, Malicious (no Phishing) |
| Analysis environment | Multi-tenant cloud | On-premises, air-gapped capable |
| File retention | Files may be retained for threat intel | Files never leave your network |
| Signature distribution | Global — shared with all WildFire subscribers | Local only — signatures stay on-prem |
| Scalability | Unlimited | Limited by appliance capacity |
| Compliance | Not suitable for strict data residency requirements | Required for air-gapped or classified environments |

### Verdict Actions
After a verdict is returned:
- If the file is malicious, the firewall can be configured to block further downloads of the same file (via WildFire Antivirus signature auto-distribution).
- WildFire signatures are distributed to all firewalls with Threat Prevention licenses within minutes of a new malware verdict (vs. daily antivirus updates).

### Supported File Types
PE executables, ELF/Linux executables, APK (Android), macOS Mach-O, Office documents (DOC/DOCX, XLS/XLSX, PPT/PPTX), PDF, JavaScript, PowerShell scripts, VBScript, shell scripts, archives (ZIP, RAR, 7z — decompressed for analysis), email links.

### WildFire API
- REST API for direct file submission and verdict retrieval outside of firewall integration.
- Used for: security tools integration, SOAR playbooks, threat hunting.
- Endpoint: `https://wildfire.paloaltonetworks.com/publicapi/`
- Operations: submit file, get verdict, get report, get sample, submit URL.
- Verdict codes: 0=benign, 1=malicious, 2=grayware, 4=phishing, -100=pending, -101=error, -102=not found.
- Authentication: API key tied to WildFire subscription.

### WildFire Best Practices
- Use a WildFire Analysis profile that forwards all supported file types.
- Configure the WildFire action in the Antivirus profile to block files with malicious verdicts.
- Enable WildFire real-time signatures (requires Threat Prevention license): `Device > Setup > WildFire > Real-time WildFire Notifications`.
- Set the WildFire analysis preference: public cloud for internet-facing traffic; WF-500 for internal/confidential file analysis.
