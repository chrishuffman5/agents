# CrowdStrike Falcon Best Practices Reference

## Prevention Policy Best Practices

### Policy Structure Recommendations

Maintain separate prevention policies per endpoint type:

| Policy | Scope | Prevention Mode | Notes |
|---|---|---|---|
| Workstations - Standard | General user endpoints | Prevention + Alert | Fully hardened for typical users |
| Workstations - Developer | Developers, power users | Detection + limited Prevention | Allow script execution for legitimate dev work |
| Servers - Critical | Domain controllers, PAWs | Prevention + Alert (aggressive) | Maximum protection |
| Servers - Application | App servers | Detection (initially) | Tune carefully to avoid blocking app processes |
| Test / Pilot | 5-10% sample group | Prevention + Alert (latest sensor) | Validate new settings before broad rollout |

### Prevention Setting Rollout Sequence

Never enable all prevention settings simultaneously. Use this order to minimize disruption:

1. **Week 1-2:** Enable cloud ML (cloud-based file analysis) in Detection mode
2. **Week 2-3:** Move cloud ML to Prevention mode after reviewing detections
3. **Week 3-4:** Enable suspicious process prevention in Detection mode
4. **Week 4-5:** Review suspicious process detections; add exclusions for legitimate tools
5. **Week 5-6:** Move suspicious process prevention to Prevention mode
6. **Week 6+:** Enable script control and remaining behavioral prevention

### Script-Based Execution Monitoring

Script control is one of the highest-value prevention settings but requires careful tuning.

**Configuration approach:**
1. Enable "Script-Based Execution Monitoring" in Detection mode
2. Review alerts for 2-4 weeks
3. Identify legitimate script execution (IT automation, software deployment, admin tools)
4. Create IOA exclusions or process exclusions for legitimate scripts
5. Move to Prevention mode

**Common legitimate exclusions needed:**
- SCCM/Intune PowerShell scripts (run from `C:\Windows\CCM\` or `C:\Windows\Temp\`)
- Monitoring agent scripts (SolarWinds, PRTG, Dynatrace)
- Backup agent scripts
- IT automation tooling (Ansible, Chef, Puppet WinRM execution)

### Machine Learning Threshold Tuning

ML sensitivity has a direct relationship with false positive rate:

| Setting | Description | FP Risk | Use Case |
|---|---|---|---|
| Aggressive | Catches more novel variants | Higher | High-security environments |
| Moderate | Balanced | Medium | Standard enterprise |
| Cautious | Conservative blocking | Lower | Environments with many custom tools |

Monitor "Machine Learning Model" detections in Detections view. If legitimite software is being flagged:
1. Identify the file hash in the detection
2. Add hash to allowlist (IOC management, action = No Action)
3. Document the exclusion with business justification

---

## IOA Rule Writing Guidelines

### Rule Design Principles

1. **Be specific** — Overly broad IOA rules generate false positives and alert fatigue
2. **Use anchored regex** — `^` and `$` anchors reduce false matches; `.*` in the middle is fine
3. **Test in Detection mode first** — Never deploy a new IOA rule directly in Prevention mode
4. **Review field availability** — Not all fields are populated for all event types
5. **Layer detections** — Combine IOA with IOC for corroborating evidence

### IOA Rule Templates

**Template: Detecting LOLBin abuse (regsvr32 scriptlet loading)**
```
Rule Type: Windows Process Creation
ImageFileName: .*\\regsvr32\.exe
CommandLine: .*(http|https|/i:.*scrobj|\.sct).*
Action: Detect + Prevent
Severity: High
Description: Regsvr32 loading remote scriptlet (Squiblydoo technique T1218.010)
```

**Template: Suspicious base64 decode operation**
```
Rule Type: Windows Process Creation
ImageFileName: .*\\certutil\.exe
CommandLine: .*(-decode|-decodehex|-urlcache).*
Action: Detect + Prevent
Severity: High
Description: Certutil used for base64 decode or URL cache download (T1140, T1105)
```

**Template: WMIC spawning child process**
```
Rule Type: Windows Process Creation
ParentImageFileName: .*\\wmic\.exe
ImageFileName: .*(cmd\.exe|powershell\.exe|wscript\.exe|cscript\.exe)
Action: Detect
Severity: High
Description: WMIC launching shell — potential lateral movement or execution (T1047)
```

**Template: Detecting process running from temp or user directory (fileless staging)**
```
Rule Type: Windows Process Creation
ImageFileName: .*(\\AppData\\|\\Temp\\|\\Users\\Public\\).*\.(exe|com|scr)
CommandLine: .*
Action: Detect
Severity: Medium
Description: Executable running from non-standard user-writable location
```

### IOA Exclusion Best Practices

When creating IOA exclusions to reduce false positives:

**Good exclusion (specific):**
```
Image path: C:\Program Files\ManageEngine\UEMS_Agent\bin\monitoring.exe
Parent image path: C:\Windows\System32\services.exe
Field: ImageFileName
```

**Bad exclusion (too broad — avoid):**
```
Image path: C:\Program Files\*
```

**Exclusion documentation template:**
```
Exclusion Name: SCCM PowerShell Script Runner
Date Created: 2024-01-15
Created By: SOC Analyst Jane Smith
Justification: SCCM deployment scripts run PowerShell with -EncodedCommand from CCM path
Review Date: 2024-07-15
Affected Hosts: All workstations
Process Path: C:\Windows\CCM\CcmExec.exe
```

---

## RTR Operational Procedures

### Incident Response RTR Playbook

**Step 1: Initial host assessment**
```bash
# Get system overview
runscript -raw=```systeminfo | findstr /i "hostname os boot"```

# Check running processes
ps | sort by name

# Check network connections
netstat | filter_out state=ESTABLISHED  # Review ESTABLISHED for suspicious connections

# Check logged-in users
runscript -raw=```query user```
```

**Step 2: Suspicious process investigation**
```bash
# Get process details by PID
runscript -raw=```Get-Process -Id 1234 | Select-Object Name, Id, Path, StartTime, Company```

# Check parent/child relationships
runscript -raw=```Get-CimInstance Win32_Process | Where-Object {$_.ParentProcessId -eq 1234} | Select Name, ProcessId, CommandLine```

# Get process command line (if ps shows truncated)
runscript -raw=```Get-WmiObject Win32_Process | Where-Object {$_.ProcessId -eq 1234} | Select CommandLine```
```

**Step 3: File artifact collection**
```bash
# Search for recently modified files in suspicious locations
runscript -raw=```Get-ChildItem C:\Users -Recurse -Filter *.exe | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-24)} | Select FullName, LastWriteTime```

# Collect suspicious file
get C:\Users\Public\suspicious.exe

# Get file hash
runscript -raw=```Get-FileHash C:\Users\Public\suspicious.exe -Algorithm SHA256```

# Check digital signature
runscript -raw=```Get-AuthenticodeSignature C:\Users\Public\suspicious.exe | Select Status, SignerCertificate```
```

**Step 4: Persistence mechanism review**
```bash
# Check registry run keys
runscript -raw=```Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Run```
runscript -raw=```Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run```

# Check scheduled tasks
runscript -raw=```Get-ScheduledTask | Where-Object {$_.State -eq 'Ready'} | Select TaskName, TaskPath, @{n='Actions';e={$_.Actions.Execute}}```

# Check services
runscript -raw=```Get-Service | Where-Object {$_.StartType -eq 'Automatic' -and $_.Status -ne 'Running'} | Select Name, DisplayName, BinaryPathName```

# Check startup items
runscript -raw=```Get-CimInstance Win32_StartupCommand | Select Name, Command, Location, User```
```

**Step 5: Containment decision**
```
If confirmed malicious:
1. Initiate host containment via Detections view > Host actions > Contain Host
   OR via RTR: falcon-containment --host <device_id>
2. Document all evidence collected
3. Continue investigation in contained state (RTR still works through containment)
4. Remediate before lifting containment
```

### RTR Bulk Script Operations

For multi-host incident response (e.g., lateral movement investigation):

1. Create device group with affected hosts in Hosts > Groups
2. Navigate to Detections > Real Time Response
3. Select device group
4. Upload and run investigation script across all hosts simultaneously

**Sample bulk collection script:**
```powershell
# falcon_ir_collect.ps1
$output = @{
    hostname = $env:COMPUTERNAME
    processes = Get-Process | Select-Object Name, Id, Path, CPU
    connections = Get-NetTCPConnection | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess
    run_keys = @{
        HKLM = (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue)
        HKCU = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue)
    }
    scheduled_tasks = Get-ScheduledTask | Where-Object State -ne 'Disabled' | Select-Object TaskName, State
}
$output | ConvertTo-Json -Depth 3 | Out-File "C:\Temp\ir_collect_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
```

---

## CQL Hunting Playbooks

### Playbook: Ransomware Activity

```cql
# Phase 1: Identify mass file writes (encryption activity)
event_simpleName = "FileOpenInfo"
AND FileAttributes > 0
AND FileName ENDS WITH ".encrypted" OR FileName ENDS WITH ".locked" OR FileName ENDS WITH ".crypto"
| groupby([ComputerName, ProcessImageFileName])
| sort(count(), order=desc)
| head(25)

# Phase 2: Shadow copy deletion (ransomware pre-encryption step)
event_simpleName = "ProcessRollup2"
AND CommandLine = "*vssadmin*delete*shadows*"
OR CommandLine = "*wmic*shadowcopy*delete*"
OR CommandLine = "*bcdedit*/set*recoveryenabled*no*"
| groupby([ComputerName, CommandLine, UserName])

# Phase 3: Large-scale file modification
event_simpleName = "ProcessRollup2"
AND ParentBaseFileName = "explorer.exe"
AND FileName NOT IN ("notepad.exe", "calc.exe", "chrome.exe", "firefox.exe")
AND FileCount > 100  # Custom field if available
```

### Playbook: Credential Dumping Detection

```cql
# LSASS memory access
event_simpleName = "ProcessRollup2"
AND TargetFileName = "*lsass*"
AND ImageFileName NOT IN (
    "*\\MsMpEng.exe",
    "*\\csrss.exe",
    "*\\werfault.exe",
    "*\\taskmgr.exe"
)
| groupby([ComputerName, ImageFileName, CommandLine])

# SAM / NTDS access
event_simpleName = "FileOpenInfo"
AND (FileName = "*\\SAM" OR FileName = "*\\NTDS\\ntds.dit" OR FileName = "*\\SYSTEM")
AND ImageFileName NOT IN ("*\\services.exe", "*\\lsass.exe", "*\\svchost.exe")

# Mimikatz-like command patterns
event_simpleName = "ProcessRollup2"
AND (
    CommandLine = "*sekurlsa::*"
    OR CommandLine = "*lsadump::*"
    OR CommandLine = "*privilege::debug*"
    OR CommandLine = "*kerberos::list*"
)
```

### Playbook: Lateral Movement Detection

```cql
# PsExec activity
event_simpleName = "ProcessRollup2"
AND (FileName = "PsExec.exe" OR FileName = "PsExec64.exe" OR FileName = "psexesvc.exe")
| groupby([ComputerName, UserName, FileName])

# WMI lateral movement
event_simpleName = "ProcessRollup2"
AND (
    (ParentBaseFileName = "WmiPrvSE.exe" AND FileName IN ("cmd.exe", "powershell.exe"))
    OR CommandLine = "*invoke-wmimethod*"
    OR CommandLine = "*wmic*/node:*process*call*create*"
)

# RDP brute force indicators
event_simpleName = "UserLogon"
AND LogonType = "10"  # Remote Interactive (RDP)
| groupby([ComputerName, UserName, UID])
| where count() > 10
| sort(count(), order=desc)

# Pass-the-Hash indicators (logon with NTLM where Kerberos expected)
event_simpleName = "UserLogon"
AND AuthenticationPackageName = "NTLM"
AND LogonType = "3"  # Network logon
AND UserName NOT ENDS WITH "$"  # Exclude computer accounts
| groupby([ComputerName, UserName, RemoteAddress])
| sort(count(), order=desc)
```

---

## OverWatch Integration Workflow

### Responding to OverWatch Notifications

OverWatch notifications appear in Detections view with source = "OverWatch".

**OverWatch notification response procedure:**
1. **Read the OverWatch notification narrative** — Contains attack chain description, affected systems, actor attribution if available
2. **Identify scope** — Which hosts, accounts, timeframe?
3. **Initiate RTR sessions** on affected hosts within 15 minutes of notification
4. **Preserve evidence** before any remediation:
   - Memory dumps of suspicious processes
   - File collection of suspicious artifacts
   - Network connection state
5. **Execute containment** if confirmed malicious (host isolation via Falcon console)
6. **Notify stakeholders** per your IR plan
7. **Follow up with OverWatch** via the notification thread for ongoing investigation support

**SLA expectations:**
- OverWatch notifies within 1 minute of confirming malicious activity
- Customer response time to OverWatch notifications tracked; aim for < 15 minutes
- OverWatch will attempt to reach your emergency contact if critical activity is not acknowledged

### OverWatch Managed Threat Hunting Cadence

OverWatch provides:
- Monthly threat hunting reports (portal and email)
- Annual overwatch report (attack trends, industry patterns)
- Ad-hoc notifications for critical findings
- Vulnerability intelligence for newly disclosed CVEs affecting your hosts

---

## Alert Triage and Tuning Workflow

### Detection Triage Process

```
New Detection Alert
      |
      v
1. Is this an OverWatch detection?
   YES → Treat as high priority; follow OverWatch playbook
   NO  → Continue below
      |
      v
2. Severity assessment:
   Critical/High → Investigate immediately (< 30 min)
   Medium → Review within 2 hours
   Low → Daily batch review
      |
      v
3. Quick triage:
   - Review detection details (process tree, command line)
   - Check if host is known-sensitive (server, executive endpoint)
   - Check if user is privileged (admin, service account)
   - Review CrowdStrike Score (probability of malicious)
      |
      v
4. Decision:
   FALSE POSITIVE → Create IOA exclusion OR IOC allowlist; mark False Positive
   TRUE POSITIVE → Escalate to incident response
   UNCERTAIN → Initiate RTR investigation
```

### False Positive Management

Track false positive rates by detection category:
```
# Useful CQL to identify high-volume detection sources (for FP analysis)
event_simpleName = "DetectionSummaryEvent"
AND Status = "false_positive"
| groupby([DetectName, FileName])
| sort(count(), order=desc)
| head(20)
```

**Target false positive rate:** < 5% of all detections (by volume)

**Monthly tuning review checklist:**
- [ ] Review top 10 highest-volume detection types
- [ ] Review any IOA rules with > 20 alerts/day (likely need refinement)
- [ ] Review and cleanup IOA exclusions older than 6 months
- [ ] Review IOC allowlist for stale entries
- [ ] Check for any disabled prevention settings (should be documented if disabled)
