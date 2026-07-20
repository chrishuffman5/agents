# Microsoft Defender for Endpoint Architecture Reference

## Platform Architecture Overview

MDE is a cloud-native EDR platform built on Microsoft's security graph. It operates as part of the Microsoft Defender XDR (extended detection and response) suite.

### Core Components

**Endpoint Sensor (Sense service):**
- Service name: `SenseNDR` / `WinDefend` (unified)
- On Windows: Built into Windows 10 1607+, Windows Server 2019+. Separate modern unified agent for 2012R2/2016.
- On macOS/Linux: Deployed via separate packages
- Kernel-level telemetry via ETW providers and Windows Filtering Platform (WFP)

**Microsoft 365 Defender Portal:**
- URL: `security.microsoft.com`
- Single pane for MDE + Defender for Office + Defender for Identity + Defender for Cloud Apps
- All EDR investigation, hunting, and response conducted here

**Microsoft Security Graph:**
- Cloud backend processing all telemetry
- Correlates endpoint events with identity (Entra ID), email, cloud apps
- Powers automated investigation (AIR) and threat analytics

**Defender Antivirus:**
- NGAV component (separate from EDR sensor in terms of capability model)
- Active in Windows Security Center
- On servers or when third-party AV is present: Can operate in passive mode (detection only, no blocking)

### Sensor Communication

MDE sensors communicate to Microsoft cloud endpoints:
```
Endpoints (HTTPS/TLS 1.2+):
- *.endpoint.security.microsoft.com
- *.oms.opinsights.azure.com (log analytics for some features)
- *.azure-automation.net
- *.blob.core.windows.net (malware sample submission)

Port: 443 (all communications)

Proxy: Configurable via:
- System proxy (WinHTTP)
- Sensor-specific proxy: netsh winhttp set proxy proxy.corp.com:8080
- AutoDiscover (WPAD)
```

---

## Onboarding Architecture Deep Dive

### Onboarding Packages

The onboarding package from the MDE portal contains:
1. **Onboarding script** (`.cmd` for Windows, `.py` for Linux) — Sets registry keys and starts the Sense service
2. **Configuration baseline** — Telemetry collection settings
3. **Organization identifier** — Links sensor to your tenant

What onboarding does on Windows:
```
Registry changes made:
HKLM\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\
  - OnboardingInfo (JSON blob with org ID and endpoint URLs)

Services affected:
- Sense (Windows Defender Advanced Threat Protection Service): Started and set to automatic
- WinDefend (Defender Antivirus): Running (or passive mode)
```

### Onboarding Health Verification

```powershell
# Check Sense service status
Get-Service Sense | Select Name, Status, StartType

# Check onboarding state
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status"
$status = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
Write-Output "OnboardingState: $($status.OnboardingState)"  # 1 = onboarded
Write-Output "SenseGuid: $($status.SenseGuid)"

# Check telemetry sending (Event Log)
Get-WinEvent -LogName "Microsoft-Windows-SENSE/Operational" -MaxEvents 20 |
    Select TimeCreated, Id, Message

# MDE connectivity test
# Run the MDE Client Analyzer: mdeclientanalyzer.cmd
# Download from: https://aka.ms/mdeclientanalyzer
```

### Offboarding

**When to offboard:** Device replacement, decommission, or migration to another EDR.
```powershell
# Run offboarding script from MDE portal (Settings > Onboarding > Offboarding)
.\WindowsDefenderATPOffboardingScript.cmd

# Verify offboarding
Get-Service Sense  # Should be stopped
```

---

## Integration Architecture

### Defender XDR Integration

MDE integrates natively with all Defender XDR products:

```
Defender XDR Suite
├── Defender for Endpoint (EDR)
│   └── Shares device entity, alerts, incidents
├── Defender for Identity (AD/Entra ID)
│   └── Correlates endpoint + identity events
├── Defender for Office 365
│   └── Links email threats to endpoint events
└── Defender for Cloud Apps (CASB)
    └── Links cloud app activity to endpoint behavior

Unified in security.microsoft.com:
- Single incident view (correlates alerts from all products)
- Unified entity pages (user, device, file, IP)
- Advanced Hunting covers all products in one KQL interface
```

### Microsoft Sentinel Integration

MDE can stream data to Microsoft Sentinel for long-term retention and SOAR integration:

**Method 1: Defender XDR Connector (recommended)**
- In Sentinel: Data connectors > Microsoft Defender XDR
- Streams: All incidents, all alert evidence
- Bidirectional: Sentinel incidents sync back to Defender portal

**Method 2: Raw event streaming (for custom analysis)**
```
Settings > Advanced features > Raw data streaming
→ Select event types to stream
→ Stream to Azure Event Hub or Storage Account
→ Consume from Sentinel via Event Hub connector
```

**Retention considerations:**
- MDE telemetry retention in Defender portal: 30 days (Advanced Hunting)
- Sentinel Log Analytics: Configurable (90 days hot + archive tier)
- Compliance requirement often drives longer retention via Sentinel

### Intune Integration

MDE integrates with Intune for device compliance and conditional access:

**Enable integration:**
1. MDE portal: Settings > Advanced features > Microsoft Intune connection: On
2. Intune: Endpoint security > Microsoft Defender for Endpoint > Connect

**Capabilities once integrated:**
- Device risk level (Low/Medium/High/Clear) exposed as Intune compliance attribute
- Intune compliance policy can require MDE risk level ≤ Medium for access
- Conditional Access policy can block high-risk endpoints from corporate resources
- Intune can trigger MDE vulnerability remediation actions

**Compliance policy example:**
```
Intune Compliance Policy: "MDE Risk Level"
Rule: Microsoft Defender ATP > Require device to be at or under machine risk score: Medium
Effect: Devices with High/Critical MDE risk fail compliance
Combined with Conditional Access: Blocks access to M365 apps
```

### Microsoft Entra ID (Azure AD) Integration

MDE uses Entra ID for:
- RBAC (MDE roles mapped to Entra security groups)
- Device registration (Entra-joined devices report device identity)
- Conditional Access risk signals (MDE risk → CA policy)
- Identity-based advanced hunting (IdentityLogonEvents table)

---

## ASR Rules Architecture

### How ASR Rules Work

ASR rules operate at the kernel level through Defender Antivirus's attack surface reduction engine:

1. **Audit phase**: Rule matches activity; event written to Windows Event Log (Event ID 1121 = blocked, 1122 = audited)
2. **Enforcement phase**: When in Block mode, the rule prevents the action before execution completes

**ASR events in Windows Event Log:**
```
Log: Microsoft-Windows-Windows Defender/Operational
Event ID 1121: ASR rule triggered (Block mode)
Event ID 1122: ASR rule triggered (Audit mode)

Fields:
- Rule ID (GUID)
- Path (file that triggered the rule)
- Process name (process that violated the rule)
```

**ASR events in MDE portal:**
- Navigate to: Reports > Security reports > Rules
- Filter by rule, time range, device
- View device timeline for context around ASR events

### ASR Rule Exclusions Architecture

Exclusions for ASR rules are separate from Windows Defender AV exclusions:
```powershell
# View current ASR exclusions
Get-MpPreference | Select AttackSurfaceReductionOnlyExclusions

# Add exclusion (file path or folder)
Add-MpPreference -AttackSurfaceReductionOnlyExclusions "C:\Program Files\LegacyApp\legacy.exe"

# Via Intune: Endpoint security > Attack surface reduction policy
# Exclusions field: Add paths
```

**Important:** ASR exclusions apply across ALL ASR rules — there is no per-rule exclusion granularity. A path excluded from ASR is excluded from all rules. This makes exclusion hygiene critical.

---

## Device Timeline Architecture

The device timeline provides a chronological view of all events on an endpoint (Plan 2).

### What's in the Timeline

- Process create/terminate
- Network connections
- File create/modify/delete
- Registry changes
- Sign-in events
- PowerShell script execution
- Scheduled task events
- Service events
- Alert events (highlighted)

### Timeline Filtering

```
Filter options:
- Time range (custom or preset: 1h, 24h, 7d, 30d)
- Event category (Process, Network, File, etc.)
- Alert severity
- MITRE ATT&CK technique
- Free text search on process name, command line, file path
```

### Timeline Export

For external analysis or DFIR reporting:
1. Apply time range filter
2. Select events (up to 1000 events per export)
3. Export as CSV: Download > Export events

---

## Live Response Architecture

Live Response provides an interactive shell session to any onboarded endpoint (Plan 2).

### Access Requirements

- Role: Live Response (read-only) or Live Response (advanced — allows script upload and execution)
- Configure roles: Settings > Endpoints > Roles

### Live Response Capabilities

**Read-only capabilities:**
```
cd, dir, ls, ps, connections, trace, getfile
```

**Advanced capabilities (require advanced role):**
```
putfile, run (execute uploaded scripts)
remediate (quarantine, kill, undo-remediation)
```

### Live Response Example Session

```bash
# Get process list
processes

# Get network connections
connections

# Collect a file
getfile C:\Windows\Temp\suspicious.exe

# Run a PowerShell collection script (must upload first)
putfile investigation.ps1
run investigation.ps1

# Quarantine a file
remediate file "C:\Windows\Temp\malware.exe"

# Kill a process
remediate process 1234
```

**File library:** Pre-upload scripts to the Live Response file library (Settings > Endpoints > Automation uploads) to have them available in any session without re-uploading.

---

## Threat Analytics Architecture

Threat Analytics provides curated threat intelligence reports for active threats (Plan 2).

### Report Structure

Each Threat Analytics report contains:
- **Overview** — Threat actor profile, attack summary, recent activity
- **Impacted assets** — Which of your devices/users are potentially affected
- **Related incidents** — Alerts and incidents matching the threat
- **Analyst insights** — Defender research team commentary
- **Mitigations** — Specific actions to reduce exposure
- **Detection coverage** — Which MDE detection rules cover this threat

### Using Threat Analytics Operationally

1. Navigate to: Threat analytics
2. Filter by "Active threats" with impact on your organization
3. For each impacted threat:
   - Review "Impacted assets" for affected endpoints
   - Review "Mitigations" — cross-reference with your ASR/policy state
   - Open related incidents for investigation

**Integration with exposure management:**
- Threat Analytics reports link to Defender Vulnerability Management
- Shows CVEs exploited by the threat actor
- Links to affected devices in your environment
