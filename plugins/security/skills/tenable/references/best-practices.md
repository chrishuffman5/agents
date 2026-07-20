# Tenable Best Practices Reference

## Scan Policy Best Practices

### Policy Design Principles

1. **Separate scan policies by asset type** -- Servers vs. workstations vs. network devices vs. databases. Each requires different credentials, plugins, and performance settings.

2. **Always use credentialed scanning for internal assets** -- Uncredentialed scans are for external/perimeter only. Credentialed scans detect 2-3x more vulnerabilities.

3. **Enable "Safe Checks" by default** -- Disable only in isolated test environments. Unsafe plugins can crash fragile systems.

4. **Do not enable all plugin families** -- Select families relevant to your environment. Enabling unused families wastes scan time and introduces noise.

5. **Set appropriate scan windows** -- Production systems: scan during off-hours. Critical servers: coordinate with change management.

### Recommended Policy Settings by Asset Type

**Windows Servers:**
```
Discovery: Ping host + TCP SYN scan, ports 1-65535
Authentication: Windows / Kerberos preferred
Plugin families: Windows, Windows: Microsoft Bulletins, 
                 Service Detection, SSL/TLS, Misc
Checks: Safe checks enabled
Simultaneous hosts: 50-75
Simultaneous checks: 4-5
```

**Linux/Unix Servers:**
```
Discovery: Ping host + TCP SYN scan
Authentication: SSH (key-based preferred over password)
Plugin families: Red Hat/Ubuntu/SUSE/etc. LSC, 
                 Service Detection, SSL/TLS, Databases (if applicable)
SSH privilege escalation: sudo (configure NOPASSWD for nessus user)
```

**Network Devices (Cisco, Palo Alto, Juniper):**
```
Discovery: ICMP ping + targeted port scan
Authentication: SSH + SNMP v3
Plugin families: Firewalls, Network Infrastructure, SNMP
Safe checks: Required -- network device crashes from scans are serious
Simultaneous hosts: 25 max (network devices are sensitive)
Scan delay: 50-100ms between packets
```

**Databases:**
```
Authentication: Database-specific credentials (separate from OS)
Plugin families: Databases (and OS family for the host)
Port scan: Include database ports (1433, 1521, 3306, 5432, 27017)
```

### Credential Management Best Practices

**Create dedicated scan accounts:**
- Windows: Create `svc-nessus-scan` domain or local account
  - Add to "Local Administrators" group (or use least-privilege approach)
  - Enable "Log on as a service" right
  - Disable interactive logon
  - Set complex, rotating password stored in PAM (CyberArk, Vault)

- Linux: Create `nessus` service account
  ```bash
  useradd -r -s /bin/bash -m nessus
  echo "nessus ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/nessus
  chmod 440 /etc/sudoers.d/nessus
  ```
  - SSH public key authentication (no passwords)
  - Store private key in Tenable as SSH credential

**Credential rotation:**
- Rotate scan credentials quarterly or per policy
- Use Tenable's PAM integration (CyberArk, Delinea, HashiCorp Vault) for automatic rotation
- PAM integration: Tenable checks out credentials at scan time, returns them after

**Credentials in Tenable.io:**
- Create shared credentials (usable across multiple scan policies)
- Scope credentials to specific scan targets or subnets
- Never use domain admin or root for scanning -- create dedicated accounts

### Scan Scheduling and Performance

**Scan frequency recommendations:**

| Asset Type | Frequency | Method |
|---|---|---|
| Internet-facing systems | Daily | Network scan (external scanner) |
| Production servers (Tier 1) | Weekly | Credentialed network scan |
| Internal servers (Tier 2-3) | Weekly-Monthly | Network scan or agent |
| Workstations/desktops | Continuous | Nessus Agent |
| Remote/cloud systems | Continuous | Nessus Agent |
| Network devices | Monthly | Credentialed network scan |

**Performance tuning:**

```
# Conservative settings (fragile systems, slow networks)
max_hosts_per_scan = 50
max_simult_tcp_sessions_per_host = 3
network_receive_timeout = 10
scan_delay = 50

# Aggressive settings (robust systems, fast networks)
max_hosts_per_scan = 150
max_simult_tcp_sessions_per_host = 8
network_receive_timeout = 3
scan_delay = 0
```

**Distributed scanner deployment:**
- Place scanners in each network segment (no scanner-to-target traversal across firewalls)
- Size: 1 scanner per ~2,000-5,000 assets (depending on scan frequency and depth)
- Scanner hardware: 4+ vCPU, 8GB+ RAM, 100GB+ disk
- Dedicated scanner VMs, not shared with other workloads

## Credentialed Scan Setup

### Windows Credential Configuration

**Required Windows configuration on scan targets:**
1. Enable Remote Registry service
2. Enable File and Printer Sharing (for SMB access)
3. Enable WMI (Windows Management Instrumentation)
4. Allow through Windows Firewall:
   - File and Printer Sharing
   - Windows Management Instrumentation (WMI)

**Group Policy for scan accounts (domain):**
```
Computer Configuration > Windows Settings > Security Settings > Local Policies > 
User Rights Assignment:
  - "Access this computer from the network": Add scan account
  - "Log on locally": Deny for scan account (security hardening)

Computer Configuration > Windows Settings > Security Settings > Windows Firewall:
  - Inbound: File and Printer Sharing (all profiles)
  - Inbound: Windows Management Instrumentation (all profiles)
```

**Verify credentials work:**
Run Nessus "Credentialed Checks" plugin (Plugin ID 19506) in scan results.
- Authenticated: Confirms OS patch level detected
- Not Authenticated: Shows what prevented auth (WMI error, auth failure, etc.)

### Linux Credential Configuration

**SSH key setup for Tenable:**
```bash
# On scanner/management system
ssh-keygen -t ed25519 -C "tenable-scan" -f ~/.ssh/tenable_scan

# On each scan target
mkdir -p /home/nessus/.ssh
cat tenable_scan.pub >> /home/nessus/.ssh/authorized_keys
chmod 700 /home/nessus/.ssh
chmod 600 /home/nessus/.ssh/authorized_keys
chown -R nessus:nessus /home/nessus/.ssh
```

**Sudo configuration (least privilege approach):**
```bash
# /etc/sudoers.d/nessus
# Allow only specific commands needed for vulnerability scanning
nessus ALL=(ALL) NOPASSWD: /bin/cat, /usr/bin/cat, /bin/ls, /usr/bin/dpkg, \
  /usr/bin/rpm, /bin/netstat, /usr/bin/netstat, /sbin/ifconfig, \
  /usr/sbin/lspci, /usr/bin/find, /usr/sbin/dmidecode
```
Note: Full sudo NOPASSWD is simpler but less secure. Use the minimal set for compliance-sensitive environments.

## Compliance Auditing

### CIS Benchmark Scans

**Setup:**
1. In scan policy: Compliance tab > Add > Select CIS benchmark for target OS
2. Use separate scan policy for compliance (don't mix with vuln scans)
3. Provide admin credentials (compliance checks require deep OS access)

**CIS benchmark levels:**
- **Level 1:** Low-risk, basic hygiene. Should be implemented universally.
- **Level 2:** Higher security, potential usability tradeoffs. For sensitive systems.

**CIS compliance workflow:**
1. Run initial scan -- establish baseline pass/fail
2. Export results (PDF or CSV)
3. Map failures to remediation tasks
4. Implement configuration changes
5. Rescan to verify -- close findings
6. Track over time with Tenable dashboards

**Key benchmarks available in Tenable:**
- CIS Windows Server 2016/2019/2022
- CIS Ubuntu Linux 20.04/22.04
- CIS Red Hat Enterprise Linux 7/8/9
- CIS Microsoft SQL Server 2016/2017/2019
- CIS AWS Foundations
- CIS Docker
- CIS Kubernetes

### DISA STIG Scanning

STIGs (Security Technical Implementation Guides) are DoD configuration standards.

**STIG scan setup:**
- Tenable provides DISA STIG .audit files for supported platforms
- Requires admin credentials
- STIG IDs map to CAT I (Critical), CAT II (High), CAT III (Low)

**STIG vs. CIS:**
- STIGs are DoD requirements -- mandatory for US government systems
- CIS Benchmarks are generally more practical for commercial environments
- Significant overlap; some organizations align to both

### Custom .audit Files

Write custom compliance checks for organization-specific requirements:

**Audit file structure:**
```
# check_type options: CHECK_EQUAL, CHECK_NOT_EQUAL, CHECK_GREATER_THAN,
#                     CHECK_LESS_THAN, CHECK_REGEX, CHECK_NOT_REGEX

<custom_item>
  type          : REGISTRY_SETTING
  description   : "Custom Policy: Require NLA for RDP"
  info          : "Network Level Authentication prevents pre-auth attacks"
  value_type    : POLICY_DWORD
  value_data    : 1
  reg_key       : "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
  reg_item      : "UserAuthentication"
  check_type    : CHECK_EQUAL
</custom_item>

<custom_item>
  type          : CMD_EXEC
  description   : "Check SSH PermitRootLogin is disabled"
  cmd           : "grep -i '^PermitRootLogin' /etc/ssh/sshd_config"
  expect        : "PermitRootLogin no"
</custom_item>
```

## Tenable One Exposure Management Workflows

### Exposure Score Management

**Understanding AES (Asset Exposure Score):**
- AES = f(VPR scores × ACR × coverage × threat context)
- Lower AES = better security posture
- Track AES trend: Should decrease over time with active remediation
- Compare AES against industry benchmark (Tenable provides peer comparison)

**ACR tuning:**
- Assign business context tags to assets in Tenable.io
- Tag: `internet-facing`, `critical-data`, `tier-1`, `pci-scope`
- Tenable uses tags to adjust ACR automatically
- Manual ACR override available for assets where auto-detection is wrong

**Lowering AES fastest:**
1. Fix KEV findings on high-ACR assets first
2. Fix VPR 9-10 findings on internet-facing assets
3. Address credential failures (improving scan coverage improves score)
4. Decomission/isolate unused high-ACR assets

### Attack Path Analysis

Tenable One maps how an attacker could compromise an asset:

**Workflow:**
1. Define "target" assets (crown jewels: production DB servers, domain controllers)
2. Tenable models attack paths from internet-accessible entry points to targets
3. Review chained vulnerabilities -- single exploits rarely lead to critical assets
4. Prioritize "path-breaking" fixes: finding that, if remediated, eliminates the attack path

**Attack path elements:**
- Entry points: Internet-exposed services with vulns
- Lateral movement: Internal vulns enabling host-to-host movement
- Privilege escalation: Local vulns enabling admin access
- Target: Crown jewel asset reached

### Integration with ITSM (ServiceNow)

**Tenable + ServiceNow Vulnerability Response:**
1. Install Tenable plugin in ServiceNow App Store
2. Configure Tenable.io API credentials in ServiceNow
3. Map Tenable asset tags to ServiceNow CI attributes
4. Configure sync schedule and severity filters
5. Findings automatically create Vulnerability Items in ServiceNow VR module
6. Remediation status syncs back: when patch applied in SCCM, ServiceNow closes ticket, Tenable re-scans verify

**Key ServiceNow VR fields populated by Tenable:**
- CVE ID, CVSS score, VPR score
- Affected CIs (from CMDB correlation)
- Due date (calculated from SLA policy)
- Solution text (vendor remediation advice from Tenable)

## Reporting

### Built-in Tenable.io Reports

- **Executive Report** -- High-level risk posture, trend analysis
- **Vulnerability Report** -- Detailed findings with remediation guidance
- **Compliance Report** -- Pass/fail by compliance control
- **Asset Report** -- Per-asset vulnerability inventory

### Custom Dashboards

Tenable.io dashboard builder:
- Drag-and-drop widget library
- Filters by asset tag, severity, plugin family, scan policy
- Share dashboards with stakeholders (read-only access)

**Key dashboard widgets:**
- Vulnerability counts by severity (trend over time)
- EPSS distribution of open findings
- SLA compliance rate by business unit
- Critical assets with unpatched KEV entries
- Coverage gaps (assets not scanned in 30+ days)

### API-Based Reporting

Export findings to external platforms:
```python
from tenable.io import TenableIO

tio = TenableIO('ACCESS_KEY', 'SECRET_KEY')

# Export vulnerabilities with filters
vulns = tio.exports.vulns(
    severity=['critical', 'high'],
    state=['open', 'reopened'],
    last_found=datetime.now() - timedelta(days=7)
)

for vuln in vulns:
    print(f"{vuln['asset']['hostname']}: {vuln['plugin']['name']} "
          f"(CVSS: {vuln['plugin']['cvss_base_score']}, "
          f"VPR: {vuln['plugin']['vpr']['score']})")
```
