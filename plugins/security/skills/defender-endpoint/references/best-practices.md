# Microsoft Defender for Endpoint Best Practices Reference

## ASR Rule Tuning Best Practices

### Pre-Deployment Audit Analysis (KQL)

Before enabling any ASR rule in Block mode, run these queries against Audit mode data:

```kql
// Most triggered ASR rules by volume (identify high-FP candidates)
DeviceEvents
| where Timestamp > ago(7d)
| where ActionType startswith "Asr"
| summarize EventCount = count(), DeviceCount = dcount(DeviceName) by ActionType, FileName, FolderPath, InitiatingProcessFileName
| order by EventCount desc
| take 50

// Identify specific ASR rule audit hits (replace GUID with target rule)
DeviceEvents
| where Timestamp > ago(7d)
| where ActionType == "AsrOfficeMacrosWin32ApiCallsAudited"  // example rule
| project Timestamp, DeviceName, AccountName, FileName, FolderPath, InitiatingProcessFileName, InitiatingProcessCommandLine
| order by Timestamp desc

// Find unique processes triggering an ASR rule (for exclusion identification)
DeviceEvents
| where Timestamp > ago(14d)
| where ActionType startswith "Asr"
| summarize HitCount = count() by InitiatingProcessFileName, FolderPath, ActionType
| where HitCount > 5
| order by HitCount desc
```

### ASR Rule Priority Recommendations

**Enable in Block mode immediately (very low FP in most environments):**
- Block credential stealing from LSASS (GUID: 9E6C4E1F...)
- Block executable content from email (GUID: BE9BA2D9...)
- Block Win32 API calls from Office macros (GUID: 92E97FA1...)

**Enable with moderate testing (2 weeks audit first):**
- Block Office from creating child processes (GUID: D4F940AB...)
- Block Office from creating executable content (GUID: 3B576869...)
- Block JavaScript/VBScript from launching executables (GUID: D3E037E1...)
- Use advanced ransomware protection (GUID: C1DB55AB...)

**Enable with extended testing (4+ weeks audit, complex environments):**
- Block obfuscated scripts (GUID: 5BEB7EFE...) — IT automation triggers frequently
- Block process creations from PSExec/WMI (GUID: D1E49AAC...) — SCCM, RMM tools affected
- Block untrusted unsigned processes from USB (GUID: B2B3F03D...) — Test hardware

### Common ASR False Positive Sources

| Rule | Common FP Source | Exclusion Strategy |
|---|---|---|
| Block Office child processes | SCCM deployment scripts run from Office macro | Exclude SCCM process path |
| Block obfuscated scripts | Vendor-provided PowerShell scripts (Base64 encoded) | Exclude vendor script directory |
| Block PSExec/WMI process creation | SCCM, Tanium, remote management tools | Exclude management tool process path |
| Block credential stealing (LSASS) | EDR vendors themselves accessing LSASS | Exclude specific EDR process path |
| Block low-prevalence executables | Internal custom applications not in Microsoft cloud | Add app to organization's software catalog |

---

## Advanced Hunting KQL Query Library

### Threat Hunting Playbooks

**Playbook: Web Shell Detection**
```kql
// Web shells — script execution from web server processes
DeviceProcessEvents
| where Timestamp > ago(7d)
| where InitiatingProcessFileName in~ ("w3wp.exe", "httpd.exe", "nginx.exe", "apache.exe", "tomcat.exe", "java.exe")
| where FileName in~ ("cmd.exe", "powershell.exe", "cscript.exe", "wscript.exe", "sh", "bash")
| project Timestamp, DeviceName, AccountName, InitiatingProcessFileName, FileName, ProcessCommandLine
| order by Timestamp desc
```

**Playbook: Living-off-the-Land (LOLBin) Abuse**
```kql
// LOLBin execution via regsvr32, mshta, certutil, etc.
DeviceProcessEvents
| where Timestamp > ago(24h)
| where FileName in~ ("mshta.exe", "regsvr32.exe", "certutil.exe", "bitsadmin.exe", "regasm.exe", "regsvcs.exe", "installutil.exe", "cmstp.exe", "wmic.exe", "msiexec.exe")
| where ProcessCommandLine has_any ("http", "https", "ftp", "\\\\")  // Network references = suspicious
| project Timestamp, DeviceName, AccountName, FileName, ProcessCommandLine, InitiatingProcessFileName
| order by Timestamp desc
```

**Playbook: Domain Reconnaissance**
```kql
// Enumeration commands typical of post-exploitation reconnaissance
DeviceProcessEvents
| where Timestamp > ago(24h)
| where FileName in~ ("net.exe", "net1.exe", "nltest.exe", "whoami.exe", "ipconfig.exe", "arp.exe", "route.exe", "nslookup.exe", "ping.exe")
| where InitiatingProcessFileName !in~ ("services.exe", "svchost.exe")
| summarize count() by DeviceName, AccountName, FileName, ProcessCommandLine, bin(Timestamp, 5m)
| where count_ > 5  // Multiple recon commands in 5 min = suspicious
| order by count_ desc
```

**Playbook: Kerberoasting Detection**
```kql
// Kerberoasting — requesting TGS tickets for service accounts
IdentityDirectoryEvents
| where Timestamp > ago(24h)
| where ActionType == "Kerberos service ticket request"
| where TargetAccountUpn !endswith "$"  // Exclude computer accounts
| summarize RequestCount = count(), Services = make_set(TargetAccountDisplayName, 10) by AccountUpn, IPAddress
| where RequestCount > 5  // Multiple service ticket requests
| order by RequestCount desc

// Cross-correlate with endpoint
DeviceProcessEvents
| where Timestamp > ago(24h)
| where ProcessCommandLine has_any ("Request-SPNTicket", "Invoke-Kerberoast", "Rubeus", "GetUserSPNs")
| project Timestamp, DeviceName, AccountName, ProcessCommandLine
```

**Playbook: Data Exfiltration Indicators**
```kql
// Large outbound data transfers to external IPs
DeviceNetworkEvents
| where Timestamp > ago(24h)
| where ActionType == "ConnectionSuccess"
| where isnotempty(RemoteIP)
| where RemoteIPType == "Public"
| where SentBytes > 50000000  // 50MB threshold
| project Timestamp, DeviceName, AccountName, RemoteIP, RemotePort, SentBytes, InitiatingProcessFileName, InitiatingProcessCommandLine
| order by SentBytes desc

// Archive tool creation (staging for exfiltration)
DeviceProcessEvents
| where Timestamp > ago(24h)
| where FileName in~ ("7z.exe", "winrar.exe", "rar.exe", "tar.exe", "compress-archive")
   or ProcessCommandLine has_any ("zip", "archive", "compress")
| where FolderPath !startswith @"C:\Program Files"
| project Timestamp, DeviceName, AccountName, FileName, ProcessCommandLine, FolderPath
| order by Timestamp desc
```

### Alert Investigation Queries

**Get all evidence for a specific alert:**
```kql
let AlertId = "da637XXXXX";  // Replace with actual alert ID

AlertEvidence
| where AlertId == AlertId
| project EntityType, EvidenceRole, FileName, FolderPath, ProcessCommandLine, RemoteIP, RegistryKey, RegistryValueData, AccountName

// Get device timeline around alert time
let AlertTime = datetime(2024-01-15 14:30:00);
DeviceProcessEvents
| where DeviceName == "WORKSTATION001"
| where Timestamp between ((AlertTime - 30m) .. (AlertTime + 30m))
| project Timestamp, FileName, ProcessCommandLine, InitiatingProcessFileName, AccountName
| order by Timestamp asc
```

**Find all activity from a suspicious process:**
```kql
let SuspiciousPID = 4872;
let SuspiciousDevice = "WORKSTATION001";
let EventTime = datetime(2024-01-15 14:00:00);

// All network connections from process
DeviceNetworkEvents
| where DeviceName == SuspiciousDevice
| where InitiatingProcessId == SuspiciousPID
| where Timestamp between ((EventTime - 1h) .. (EventTime + 2h))
| project Timestamp, RemoteIP, RemotePort, RemoteUrl, SentBytes, ReceivedBytes

// All file writes from process
DeviceFileEvents
| where DeviceName == SuspiciousDevice
| where InitiatingProcessId == SuspiciousPID
| where Timestamp between ((EventTime - 1h) .. (EventTime + 2h))
| project Timestamp, ActionType, FileName, FolderPath, FileSize, SHA256

// All child processes
DeviceProcessEvents
| where DeviceName == SuspiciousDevice
| where InitiatingProcessId == SuspiciousPID
| project Timestamp, FileName, ProcessCommandLine, ProcessId
```

---

## Automated Investigation and Remediation (AIR) Best Practices

### Automation Level Configuration

```
Conservative start (for first 90 days of AIR deployment):
- Servers (Critical): Semi - require approval for core folders
- Servers (Application): Semi - require approval for non-temp folders
- Workstations: Semi - require approval for non-temp folders

After tuning (stable environment):
- Workstations: Full - remediate threats automatically
- Servers (Application): Semi - require approval for core folders
- Servers (Critical): Semi - require approval for core folders (keep manual review)
```

### AIR Action Center Review Process

Daily AIR review procedure (aim to process within 24 hours of action creation):

```
Action Center review flow:
1. Filter by Status = Pending
2. For each pending action:
   a. Click action to view investigation details
   b. Review investigation graph (scope of investigation)
   c. Check affected entities (files, processes, users)
   d. Review evidence classification (malicious, suspicious, clean)
   e. Decision:
      - Approve: Remediation proceeds
      - Approve (selected actions): Approve subset if some are uncertain
      - Reject: No action; document reason
3. For rejected actions — escalate to SOC for manual investigation
```

### Tuning AIR False Positives

When AIR incorrectly classifies legitimate software:

1. **Identify the alert** in Incidents view
2. **Classify as False Positive**: Alert > Manage alert > Classification: False positive
3. **Create suppression rule**: Alert > Create suppression rule
   - Scope: This device only (for unique false positive)
   - Scope: Any device in organization (if the same FP affects all devices)
   - Define suppression criteria precisely (process name + parent + file path)
4. **Submit false positive to Microsoft** (improves cloud ML model): File > Submit to Microsoft

**Suppression rule best practices:**
- Never suppress by title alone — always add process path context
- Include expiry date (6 months max; review regularly)
- Document justification for each suppression in comments field

---

## Vulnerability Management Workflows

### Prioritization Model

MDE Vulnerability Management uses an exposure-based risk score:

```
Risk Factors:
1. CVSS score (severity of the CVE)
2. Exploit availability in the wild (public exploit = higher priority)
3. Active exploitation in threat campaigns (Threat Analytics correlation)
4. Asset criticality (device group assignment affects weight)
5. Exposure (internet-facing vs. internal)
```

**Triage priority order:**
1. Critical CVSS + active exploitation + internet-facing asset → Emergency patch (24-48 hours)
2. Critical CVSS + public exploit available → Urgent patch (7 days)
3. High CVSS + no public exploit → Standard patch (30 days)
4. Medium/Low CVSS → Scheduled patching cycle

### Remediation Workflow

1. Navigate to: Vulnerability management > Recommendations
2. Filter by: Highest exposure score
3. For top recommendations:
   - Review "Remediation request" — Create a ticket (integrates with Jira/ServiceNow if configured)
   - Or export CSV for manual ticketing
4. Track remediation in: Vulnerability management > Remediation
5. Verify after patching: Recommendation should clear after next vulnerability scan (24-48 hours)

### Exception Management

For vulnerabilities that cannot be immediately remediated:

1. Navigate to the vulnerability
2. Click "Request exception"
3. Exception types:
   - **Remediation** — Tracking a planned fix (with due date)
   - **Accepted risk** — No fix planned; business decision
   - **Third-party** — Remediation is vendor's responsibility
4. Document justification and set review date
5. Exceptions visible in: Vulnerability management > Exception management

### KQL for Vulnerability Management

```kql
// Devices with vulnerabilities actively exploited in current campaigns
DeviceTvmSoftwareVulnerabilities
| where VulnerabilitySeverityLevel in ("Critical", "High")
| join kind=inner (
    DeviceTvmSoftwareVulnerabilitiesKB
    | where IsExploitAvailable == "1"
    | where CvssScore >= 7.0
) on CveId
| join kind=inner (
    DeviceTvmSecureConfigurationAssessment
    | where IsApplicable == 1
) on DeviceId
| summarize UnpatchedDevices = dcount(DeviceId), DeviceList = make_set(DeviceName, 20) by CveId, SoftwareName, SoftwareVersion
| order by UnpatchedDevices desc

// Software inventory — find all devices running a specific version
DeviceTvmSoftwareInventory
| where SoftwareName =~ "log4j"  // Replace with software of interest
| project DeviceName, SoftwareName, SoftwareVersion, OSPlatform
| order by SoftwareVersion asc
```

---

## Threat Analytics Usage

### Operationalizing Threat Analytics

Use Threat Analytics proactively for threat-informed defense:

**Weekly threat review workflow:**
1. Navigate to: Threat analytics
2. Filter: "Analyst reports" with "Impacted" status for your environment
3. For each impacted threat:
   - Note the ATT&CK techniques used by this actor
   - Cross-reference with your current detection coverage
   - Review "Mitigations" — are the recommended ASR rules enabled?
   - Check if related CVEs are in your vulnerability management queue
4. Create detection rules for technique gaps identified

**Creating detections from Threat Analytics:**
```kql
// Example: Creating custom detection based on Threat Analytics report for [Actor X]
// who uses PowerShell with -WindowStyle Hidden and -ExecutionPolicy Bypass

DeviceProcessEvents
| where Timestamp > ago(1d)
| where FileName =~ "powershell.exe"
| where ProcessCommandLine has "WindowStyle" and ProcessCommandLine has "Hidden"
| where ProcessCommandLine has "ExecutionPolicy" and ProcessCommandLine has "Bypass"
| project Timestamp, DeviceName, AccountName, ProcessCommandLine, InitiatingProcessFileName, ReportId, DeviceId
// Save as custom detection rule with Daily schedule, High severity
```

---

## MDE Performance Impact and Optimization

### High CPU Scenarios

When MDE causes high CPU on endpoints:

```powershell
# Check exclusions (missing exclusions are common cause)
Get-MpPreference | Select ExclusionPath, ExclusionExtension, ExclusionProcess

# Common high-CPU scenarios and exclusions:
# 1. Build servers (compilers triggering intensive scanning)
Add-MpPreference -ExclusionProcess "cl.exe"  # MSVC compiler
Add-MpPreference -ExclusionProcess "link.exe"  # MSVC linker
Add-MpPreference -ExclusionPath "C:\BuildOutput\"

# 2. Database servers (constant file access)
Add-MpPreference -ExclusionExtension "mdf", "ldf", "ndf"  # SQL Server data files
Add-MpPreference -ExclusionPath "D:\SQLData\"

# 3. Virtual machine hosts (constant disk I/O on VHD files)
Add-MpPreference -ExclusionExtension "vhd", "vhdx", "vmdk", "vdi"
```

**Exclusion best practices:**
- Prefer process exclusions over path exclusions when possible
- Never exclude entire drives or C:\Windows\
- Document every exclusion with business justification
- Review exclusions in Microsoft 365 Defender: Settings > Endpoints > Exclusions
- Microsoft 365 Defender shows "attack surface" risk for broad exclusions

### Scan Schedule Optimization

```powershell
# Configure scheduled scan to off-hours
Set-MpPreference -ScanScheduleDay 0  # 0 = everyday
Set-MpPreference -ScanScheduleTime "02:00:00"  # 2 AM

# Disable quick scan during business hours if CPU is an issue
Set-MpPreference -DisableScanningNetworkFiles $true  # For network-heavy servers
Set-MpPreference -DisableArchiveScanning $false  # Keep archive scanning on

# Randomize scan start time (for VDI environments — prevents all VMs scanning simultaneously)
Set-MpPreference -RandomizeScheduleTaskTimes $true
Set-MpPreference -ScanOnlyIfIdleEnabled $true  # Only scan when CPU is idle
```
