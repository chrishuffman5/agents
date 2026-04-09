# FortiOS Operational Best Practices

## 1. Firewall Policy Design

### Deny-by-Default Architecture
- Last rule is always an implicit deny; do NOT add an explicit deny-all unless logging is needed from that rule
- Add an explicit deny rule before the implicit deny if you need to log denied traffic:
  ```
  Policy: Action=Deny, srcaddr=all, dstaddr=all, logtraffic=all
  ```
- Start with least-privilege: define what IS allowed, not what is blocked

### Policy Organization
- **Order matters**: Policies evaluated top-to-bottom; place more specific rules above general rules
- Group related policies with policy blocks or naming conventions (tags in 7.x)
- Avoid policy sprawl: consolidate overlapping policies using address groups and service groups
- Use `policy-id` for tracking; keep IDs consistent across FortiManager templates
- Separate inbound (internet → internal) and outbound (internal → internet) policies clearly
- Use named policies (not just IDs) for readability

### Address and Service Objects
- Never use raw IPs/ports in policies; always create named address objects and service objects
- Use address groups for logical aggregation (e.g., `grp-web-servers`, `grp-finance-users`)
- Prefer FQDN address objects for cloud services (dynamically resolves DNS)
- Use ISDB (Internet Service Database) objects for well-known cloud services (Microsoft 365, AWS, etc.) — more accurate than manual IP lists
- Use `application-list` for application-based traffic identification rather than port-based

### UTM Profile Design
- Create purpose-specific UTM profiles rather than one monolithic profile
- Examples: `utm-outbound-web`, `utm-inbound-dmz`, `utm-internal-strict`
- Apply only what is needed per policy (don't enable AV on internal routing-only policies)
- Profile-based NGFW: keeps security profiles reusable across policies
- Policy-based NGFW: use when you need application/URL category as match criterion in the policy itself

### SSL Inspection Strategy
- Deploy deep inspection for untrusted internet-bound traffic
- Use certificate inspection for trusted internal server traffic (less overhead)
- Build exemption list for certificate-pinned applications (banking apps, OS updates, developer tools)
- Push the FortiGate CA cert via GPO/MDM before enabling deep inspection to avoid user browser warnings
- Log SSL bypass events to track exemption effectiveness

---

## 2. Firmware Lifecycle Management

### Version Selection Guidelines
- **Production environments**: Use latest patch of a supported major version (e.g., 7.4.11+, 7.6.x)
- **New deployments**: Use 7.6 (current recommended, longest support window)
- **Stability-first environments**: 7.4 is mature with extensive bug fixes; appropriate for conservative orgs
- **Avoid**: 7.2 for new projects (past EOES); 7.0 (near or past EOS)

### Patch Cadence
- Subscribe to FortiGuard security advisories and PSIRT bulletins
- Apply patches within 30 days for high/critical PSIRT findings
- Test patches in lab/staging before production rollout
- Use FortiManager federated upgrade for controlled fleet-wide patching

### Pre-Upgrade Validation
1. Check Fortinet Upgrade Path Tool: `https://docs.fortinet.com/upgrade-tool`
2. Read release notes for target version (deprecated features, behavior changes, resolved CVEs)
3. Back up current config (full encrypted backup)
4. Document current state: `get system status`, HA status, license status, active VPN count
5. For HA clusters: upgrade secondary first, verify, then promote secondary and upgrade original primary
6. Verify FortiGuard license renewal dates — some licenses expire independently of firmware

### HA Cluster Upgrade Procedure
```bash
# 1. Verify HA health
diagnose sys ha status
get system ha status

# 2. Upgrade secondary (non-disruptive)
# (On secondary unit or via FortiManager)
execute restore image tftp <firmware.out> <tftp-server>

# 3. After secondary rejoins cluster, force failover to secondary
# (On primary unit)
execute ha failover set 1   # Demote current primary

# 4. Upgrade original primary (now secondary)
execute restore image tftp <firmware.out> <tftp-server>

# 5. Restore preferred primary (if desired)
execute ha failover unset 1
```

---

## 3. High Availability Design

### HA Architecture Recommendations
- Use dedicated physical links for HA heartbeat (not mgmt port, not production traffic ports)
- Two heartbeat links on different physical cards for redundancy
- Heartbeat interface should not carry production traffic (set `heartbeat-interface` appropriately)
- Active-Passive for most deployments: simpler, deterministic; no asymmetric routing issues
- Active-Active only when UTM throughput is CPU-constrained and both units must process inspection

### FGCP Cluster Design
- Match hardware models exactly (same FortiGate model for HA cluster)
- Match firmware versions before forming cluster
- Set meaningful cluster hostnames for identification: `set ha-override enable` + priority difference
- Configure monitored interfaces: `config ha monitor` to track uplinks for failover triggers
- Management IP on dedicated interface (not a cluster virtual IP): allows independent access to each unit
- Enable `session-pickup` for UDP/ICMP if stateful failover is required for those protocols

### FGSP Design (for scale-out active-active)
- Use FGSP with ECMP routing (e.g., two ISP routers doing ECMP to each FortiGate)
- FGSP does not use virtual MAC/IP; each unit has its own addresses
- Peer IP configuration: `config system ha → set session-sync-dev <interface>`
- Synchronize what you need: TCP always; add UDP/ICMP only if required
- FGSP pairs can themselves be FGCP clusters (nested HA)

---

## 4. Logging Strategy

### What to Log
- Log all allowed traffic on policies with security profiles (UTM events)
- Log all denied traffic for security visibility (use an explicit deny rule with logging)
- Log IPS events: at minimum high/critical severity
- Log authentication events (VPN logins, admin logins)
- Do NOT log every allowed policy without UTM (creates log volume without value)
- Enable traffic logging selectively: `set logtraffic all` only where needed

### Log Destinations
| Destination | Use Case |
|-------------|----------|
| FortiAnalyzer | Centralized log management; SOC operations; compliance reports |
| FortiCloud (Logging) | SMB/branch; cloud-hosted log storage |
| Local disk | Appliances with SSD; short-term local review |
| Syslog | Third-party SIEM integration (Splunk, QRadar, etc.) |

- FortiAnalyzer preferred for enterprise: indexing, correlation, FortiSOC, playbooks
- Always encrypt log transmission (TLS/SSL between FortiGate and FortiAnalyzer)

### Log Optimization
- Use `logtraffic-start enable` sparingly (logs session start AND end = double log entries)
- Set appropriate retention policies on FortiAnalyzer to manage storage
- Archive older logs to NAS/S3 from FortiAnalyzer for long-term compliance
- Use log rate monitoring: `diagnose fortilogd lograte` to detect log storms

### FortiAnalyzer ADOM Design for Logs
- Create separate FortiAnalyzer ADOMs per organizational unit or security tier
- Assign FortiGates to appropriate ADOMs for segmented log visibility
- Set retention per ADOM based on compliance requirements (90 days, 1 year, etc.)

---

## 5. FortiManager ADOM Design

### ADOM Segmentation Principles
- **By customer/tenant**: MSP deployments; strict isolation between customers
- **By FortiOS version**: Separate ADOMs for 7.4 and 7.6 devices (prevent schema mismatch)
- **By geography/team**: Allow regional teams admin access to their own ADOM
- **By criticality**: Separate prod and non-prod for change control

### Policy Package Management
- One policy package per FortiGate (or per VDOM) unless policies are truly identical
- Never share a policy package between different device types/versions
- Use Global ADOM for policies that apply across all ADOMs (global header/footer policies)
- Enable ADOM revision history: set auto-revision; default may have too few revisions saved
- Review Install Preview before every install; confirm diff with previous version

### Object Management
- Run periodic unused object cleanup (FortiManager identifies unused objects)
- Use normalized interfaces for interface abstraction in policy packages
- Define meta-variables at ADOM level for per-device customization (gateway IPs, hostnames)

---

## 6. Backup and Restore

### FortiGate Backup
```bash
# GUI: System > Config > Backup
# CLI:
execute backup config tftp backup-$(date).conf 192.168.1.100
execute backup config scp backup.conf 192.168.1.100 scp-user /backups/

# For encrypted backup (recommended):
# GUI: Check "Encrypt configuration file" with passphrase
```

**Best practice:**
- Back up before every change (especially firmware upgrades)
- Store backups off-device (TFTP server, NAS, FortiManager config revision)
- FortiManager maintains auto-revisions per device; set sufficient revision count
- Test restore procedure in lab periodically

### FortiManager Backup
- `diagnose cgi /cli/system/backup/db/management_extension_application` (full DB backup)
- Schedule automated backups via GUI: System Settings > Advanced > Backup
- Verify backup integrity using checksum logged in FortiManager
- FortiManager HA also serves as backup; primary DB replicated to secondary
- Restoring FortiManager backup requires **identical firmware version** on the target

### Configuration Integrity
- After restore, verify: admin accounts, interfaces, routing, HA state, VPN tunnels
- Re-validate FortiGuard license activation post-restore
- Check if dynamic objects (ZTNA tags, ISDB objects) have re-synced

---

## 7. Performance Tuning

### NP Hardware Offloading
**Maximize NP offloading:**
- Use NP-capable interfaces (not software switches for high-volume traffic)
- Set `intra-switch-policy = explicit` if using software switches (enables session creation for NP offloading)
- Avoid session helpers for high-volume protocols; disable unnecessary ALGs:
  ```
  config system session-helper
      # Review and disable unused helpers (SIP, FTP, etc.)
  end
  ```
- Remove PPPoE interfaces from high-throughput paths (NP cannot accelerate PPPoE)
- Check offload status: `diagnose npu np7 session list | grep offloaded`

**Traffic that cannot be NP-offloaded:**
- Proxy-based UTM inspection traffic
- Sessions using session helpers (FTP, DNS, SIP, H.323, PPTP)
- IPsec with non-offloadable ciphers
- Traffic on PPPoE interfaces
- IPv6 with certain extension headers
- Fragmented packets (NP7Lite only; NP7 handles fragmentation)

### Session Helper (ALG) Management
Session helpers intercept control-plane protocols to track related data connections:
- `sip`: SIP VoIP; creates pinholes for RTP media — disable if using SBC or passing raw SIP
- `ftp`: FTP active mode; pinholes for data connections — disable if passive FTP is sufficient
- `dns`: DNS ALG — usually safe to disable if not using NAT DNS hairpinning
- `h323`: H.323 video conferencing — disable if not using legacy video systems
- `tftp`: TFTP pinhole

To disable:
```
config system session-helper
    # edit the helper and set status to disable, or delete entries
end
```

### CPU and Memory Optimization
- Monitor: `diagnose sys top` for high-CPU processes
- `newcli` process: CLI/management; spikes during large config operations
- `scanunitd`: AV scanning; high during file scanning events
- `ipsengine`: IPS/flow inspection; scale by reducing IPS sensor scope or using NP
- Memory: ensure at least 30% free RAM headroom; lower on 2GB models requires selective feature use
- `set memory-use-threshold-extreme 95` — default; adjust if getting false memory alerts
- In 7.6.5+: improved memory optimization for 2GB/4GB RAM platforms

### Routing Optimization
- Use ECMP for multi-path routing (configure equal-cost static routes or BGP ECMP)
- SD-WAN supersedes policy routes for WAN traffic; avoid mixing SD-WAN with `config router policy` for same traffic
- For large BGP tables: increase BGP table size limits if needed; limit received prefixes with route-filters

---

## 8. Common Misconfigurations

### Policy Misconfigurations
- **Overly permissive policies**: `srcaddr=all, dstaddr=all, service=ALL` with no UTM is a flat network with FortiGate as a router
- **Shadow policies**: A more general policy matching before a more specific one; use policy reorder
- **UTM profiles on policies without inspection**: Logging overhead with no security value
- **Missing NAT on outbound**: Traffic sourced from private IP reaches internet-facing interface without SNAT
- **Firewall policy using interface-specific IP when interface changes**: Always use named address objects

### SSL Inspection Issues
- **Missing CA cert deployment**: Deep inspection causes browser certificate warnings for all HTTPS sites
- **No exemptions for pinned certificates**: Banking apps, enterprise software, OS updates fail
- **Wrong profile applied**: Certificate inspection profile used where deep inspection needed
- **Flow-based without inspect-all-ports**: SSL deep inspection misses traffic on non-443 ports

### HA Misconfigurations
- **Heartbeat on same switch as production traffic**: Single point of failure for heartbeat
- **No monitored interfaces**: HA won't failover on uplink failure if no interfaces are monitored
- **Primary election priority tie**: Ensure primary has higher priority (`set priority 200` vs default 128)
- **Mismatched firmware in cluster**: Will prevent cluster formation; upgrade secondary first

### SD-WAN Misconfigurations
- **Health check server unreachable**: Links falsely marked down; use reliable, always-up probe targets
- **No SLA targets in rules**: Using `best-quality` strategy without SLA means no failover threshold
- **Overlapping SD-WAN rules**: Earlier rules match unintended traffic; review rule order and selectors
- **Forgetting SD-WAN zone in firewall policy**: Policy must reference the SD-WAN zone, not individual member interfaces

### VPN Misconfigurations
- **Phase2 selector mismatch**: IKE negotiates but traffic never flows; check local/remote subnet selectors
- **PFS mismatch**: Phase1 has PFS enabled, Phase2 does not (or vice versa) causes renegotiation failures
- **IKEv2 with legacy vendor**: Some older peers require IKEv1; verify compatibility
- **Route-based VPN missing static route**: IPsec tunnel up but no route pointing traffic into tunnel interface

### FortiManager/FortiAnalyzer
- **Making config changes directly on FortiGate when managed by FortiManager**: Config gets overwritten on next install; use FortiManager or explicitly enable "Backup mode"
- **ADOM version mismatch**: Managing 7.6 FortiGate in a 7.4 ADOM causes schema errors
- **Not reviewing Install Preview**: Unexpected policy changes pushed to production
- **Forgetting to lock ADOM workspace**: Multiple admin simultaneous edits cause conflicts

---

## 9. Security Hardening

### Admin Access Hardening
```bash
# Restrict admin access to specific IPs
config system admin
    edit admin
        set trusthost1 192.168.10.0 255.255.255.0
    next
end

# Change default HTTPS/SSH ports
config system global
    set admin-port 8443
    set admin-ssh-port 2222
end

# Enforce strong password policy
config system password-policy
    set status enable
    set minimum-length 12
    set must-contain upper-case-letter lower-case-letter number non-alphanumeric
end

# Enable two-factor authentication for admin
config system admin
    edit admin
        set two-factor fortitoken
        set fortitoken <token-serial>
    next
end
```

### Local-in Policy for Management Restriction
```bash
config firewall local-in-policy
    edit 1
        set intf mgmt
        set srcaddr admin-hosts-grp
        set dstaddr all
        set action accept
        set service HTTPS SSH
        set schedule always
    next
    edit 2
        set intf mgmt
        set srcaddr all
        set dstaddr all
        set action deny
        set schedule always
    next
end
```

### General Hardening Checklist
- Disable unused admin protocols (Telnet, HTTP, SNMP v1/v2 if not needed)
- Use SNMPv3 with authentication and encryption if SNMP is required
- Enable logging for admin logins and config changes
- Set `set admin-lockout-threshold 5` and `set admin-lockout-duration 300`
- Disable FortiCloud management if not in use
- Review and remove unused VPN configurations, admin accounts, and unused interfaces
- Enable FortiGuard Security Rating and address high/critical findings
- Apply Fortinet Security Fabric best practice recommendations from Security Rating dashboard
