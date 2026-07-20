# EDR Fundamentals Reference

## Behavioral Detection vs. Signature-Based Detection

### Signature-Based Detection (IOC-driven)

Indicators of Compromise (IOC) are artifacts observed on a network or endpoint that indicate a breach with high confidence. They are retrospective — they document what was used in a known attack.

**Types of IOCs:**
- File hashes (MD5, SHA1, SHA256) — exact file identity
- IP addresses — known C2 servers, scanners
- Domain names — malicious domains, DGAs
- URLs — phishing pages, payload delivery endpoints
- Registry keys — persistence mechanisms
- Mutex names — malware-specific synchronization objects
- YARA rules — byte-pattern matching within file content

**Strengths:**
- Deterministic: match = known bad
- Low false positive rate when IOCs are high-quality
- Computationally inexpensive at scale
- Easy to share via STIX/TAXII, MISP, threat intel feeds

**Weaknesses:**
- Evaded by trivial changes: recompile, repack, rename
- Does not detect living-off-the-land (LOLBin) attacks
- Rapidly goes stale; C2 infrastructure rotates frequently
- No detection of novel (zero-day) threats
- Hash-based detection fails against polymorphic/metamorphic malware

### Behavioral Detection (IOA-driven)

Indicators of Attack (IOA) focus on the intent and behavior of an adversary, not the specific tools or files used. IOAs detect what an attacker is trying to do regardless of what they use to do it.

**Behavioral detection primitives:**
- Process lineage analysis (parent/child process relationships)
- Command-line argument inspection
- Memory injection patterns (process hollowing, DLL injection, reflective loading)
- API call sequences (OpenProcess + WriteProcessMemory + CreateRemoteThread = injection)
- File system access patterns (mass encryption = ransomware)
- Network behavior (beaconing intervals, encoded traffic, unusual ports)
- Registry modification patterns (Run key, scheduled task creation)
- Credential access patterns (LSASS reads, SAM database access, DCSync)

**Strengths:**
- Detects novel attacks using known techniques
- Resistant to simple obfuscation (same behavior, different tool)
- Detects LOLBin abuse (mshta.exe, regsvr32.exe, certutil.exe)
- Catches fileless attacks (scripts, in-memory payloads)

**Weaknesses:**
- Requires tuning to reduce false positives
- More computationally expensive (context tracking required)
- Platform-specific sensor depth affects coverage
- Evasion possible via technique variation (e.g., userland injection vs. kernel injection)

### Detection Hierarchy (from most reliable to most noisy)

1. IOC match on high-confidence feed (low FP, low coverage)
2. Behavioral IOA with corroborating context (medium FP, high coverage)
3. ML model anomaly score above threshold (varies by model quality)
4. Heuristic rule match (depends on rule quality)
5. Telemetry anomaly / outlier (requires baselining, high FP possible)

---

## MITRE ATT&CK Framework for EDR

### Framework Structure

The MITRE ATT&CK framework documents adversary tactics, techniques, and sub-techniques observed in real-world attacks. It provides a common language for describing adversary behavior.

**Enterprise ATT&CK Matrix (major tactics):**

| Tactic | ID | Description |
|---|---|---|
| Reconnaissance | TA0043 | Gathering information before attack |
| Resource Development | TA0042 | Establishing attack infrastructure |
| Initial Access | TA0001 | Getting into the target environment |
| Execution | TA0002 | Running malicious code |
| Persistence | TA0003 | Maintaining foothold across reboots |
| Privilege Escalation | TA0004 | Gaining higher permissions |
| Defense Evasion | TA0005 | Avoiding detection |
| Credential Access | TA0006 | Stealing account credentials |
| Discovery | TA0007 | Mapping the environment |
| Lateral Movement | TA0008 | Moving through the network |
| Collection | TA0009 | Gathering data of interest |
| Command & Control | TA0011 | Communicating with compromised systems |
| Exfiltration | TA0010 | Stealing data |
| Impact | TA0040 | Disrupting operations (ransomware, wiper) |

### High-Value ATT&CK Techniques for EDR Coverage

**Execution (TA0002) — highest detection priority:**
- T1059.001 — PowerShell: `powershell.exe -enc`, `Invoke-Expression`, `-nop -w hidden`
- T1059.003 — Windows Command Shell: `cmd.exe /c`, unusual parent processes
- T1059.005 — Visual Basic: mshta.exe executing VBS
- T1059.007 — JavaScript: wscript.exe, cscript.exe
- T1047 — WMI: `wmic process call create`
- T1053 — Scheduled Tasks: `schtasks /create`

**Defense Evasion (TA0005) — hardest to detect:**
- T1055 — Process Injection: all sub-techniques
- T1036 — Masquerading: process names mimicking system binaries
- T1070.001 — Clear Windows Event Logs
- T1562.001 — Impair Defenses: disabling AV/EDR
- T1218 — Signed Binary Proxy Execution (LOLBins)
- T1027 — Obfuscated Files: encoding, packing, encryption

**Credential Access (TA0006) — high impact:**
- T1003.001 — OS Credential Dumping: LSASS Memory
- T1003.002 — SAM database
- T1558 — Steal or Forge Kerberos Tickets (Pass-the-Ticket, Kerberoasting)
- T1552 — Unsecured Credentials: searching files/registry

### ATT&CK Coverage Evaluation Process

1. Define your threat model: Which threat actors target your industry?
2. Map those actors' known TTPs using ATT&CK Navigator
3. Run MITRE ATT&CK evaluations results for candidate platforms
4. Conduct purple team exercises to validate actual coverage
5. Prioritize detection gaps by impact (technique criticality × frequency)
6. Note: Vendor ATT&CK coverage claims are marketing — validate independently

---

## Telemetry Architecture

### Event Types Collected by EDR Sensors

**Process telemetry:**
- Process creation (image path, command line, parent PID, user context, hash)
- Process termination
- Process injection events
- Thread creation in remote process

**File system telemetry:**
- File create / modify / delete / rename
- Executable writes (new PE files on disk)
- Script file creation (.ps1, .vbs, .js, .bat)
- ADS (Alternate Data Stream) creation

**Network telemetry:**
- DNS queries and responses
- Network connections (source/dest IP, port, protocol, process)
- HTTP/HTTPS metadata (where available — requires TLS inspection or process-level hooks)

**Registry telemetry:**
- Registry key create / modify / delete
- Persistence-relevant key writes (Run, RunOnce, Services, Scheduled Tasks)

**Authentication telemetry:**
- Logon events (type, source, user)
- Privilege use events
- Token manipulation

**Memory telemetry (deep EDR platforms):**
- Memory allocation in remote process
- Executable memory mapped outside of known modules
- Reflective PE loading

### Telemetry Pipeline Architecture

```
Endpoint Sensor
      |
      | (kernel-level hooks, ETW, eBPF)
      v
Event Collection & Filtering
      |
      | (TLS / encrypted channel)
      v
Cloud Backend / SIEM Ingest
      |
      +---> Detection Engine (real-time rules + ML)
      |           |
      |           v
      |        Alerts / Incidents
      |
      +---> Telemetry Store (raw events, queryable)
                  |
                  v
             Threat Hunting Interface
```

**Key architectural considerations:**
- **Sensor-side filtering**: Reduces bandwidth but may miss telemetry needed for hunting. Some platforms allow adjusting verbosity.
- **Cloud-native vs. on-prem**: Cloud-native platforms (CrowdStrike, MDE) offload processing to the cloud. On-prem platforms (Wazuh) require local infrastructure.
- **Streaming vs. batch**: Real-time detections require low-latency streaming. Hunting queries run against stored telemetry.

---

## Detection Engineering Lifecycle

### Phase 1: Detection Hypothesis

Start with a threat model question: "How would an attacker achieve technique X in our environment?"

Sources for detection hypotheses:
- MITRE ATT&CK technique descriptions
- Threat intelligence reports (TA-specific TTPs)
- Red team/purple team findings
- Incident post-mortems
- Security research (blogs, conference talks)

### Phase 2: Data Availability Assessment

Before writing a detection:
1. Is the required telemetry being collected?
2. Are relevant fields populated and reliable?
3. What is the baseline frequency of this event type?
4. What is the signal-to-noise ratio for this behavior?

### Phase 3: Detection Logic Development

**Rule types by platform:**
- CrowdStrike: Custom IOA rules (behavioral), Custom IOC indicators
- MDE: Custom detection rules (KQL-based), Custom indicators
- SentinelOne: STAR rules (Storyline Active Response), custom IOC watchlists
- Elastic: Detection rules (EQL, KQL, threshold, ML)
- Wazuh: XML-based rules with decoders

**Rule quality checklist:**
- [ ] Does it catch the threat technique reliably?
- [ ] What is the expected false positive rate in production?
- [ ] Is the logic SARG-able (uses indexed fields where possible)?
- [ ] Has it been tested against real-world malware samples?
- [ ] Is the severity/priority calibrated correctly?
- [ ] Is there runbook / response guidance attached?

### Phase 4: Testing and Validation

**Testing approaches:**
- **Atomic testing**: Use Atomic Red Team (Red Canary) for individual technique simulation
- **Adversary simulation**: Full attack chain with a red team or tools like Cobalt Strike
- **Purple team exercises**: Collaborative red/blue with real-time detection feedback
- **Replay testing**: Replay historical attack telemetry against new detection rules

### Phase 5: Tuning and Maintenance

Common false positive sources:
- IT automation tools mimicking attacker behavior (PSExec, scheduled tasks)
- Software updates triggering file write detections
- Security tools themselves triggering injection detections
- Legacy applications using insecure but legitimate patterns

Tuning strategies:
- Exclusions by process path + parent (be specific, avoid broad path exclusions)
- Exclusions by signed hash / certificate
- Context-based suppression (IT_ADMIN group running process X is expected)
- Threshold-based suppression (N occurrences within T seconds = alert)

**Exclusion hygiene:**
- Document every exclusion with justification and owner
- Review exclusions quarterly; remove stale ones
- Never create exclusions that cover entire system directories
- Prefer signed certificate exclusions over path exclusions (paths can be abused)

---

## EDR vs. XDR Architecture

### EDR Scope Limitations

Traditional EDR is endpoint-centric. Blind spots:
- Network-based lateral movement (no agent on network devices)
- Cloud workload attacks (if no agent deployed)
- Identity-based attacks (Kerberos abuse in AD — no endpoint artifact)
- Email-delivered threats (phishing link clicked in browser — minimal endpoint signal)

### XDR Data Sources

XDR platforms correlate across:
- Endpoint (EDR data)
- Network (NDR — firewall logs, proxy, DNS)
- Cloud (CSPM, CWPP — cloud workload telemetry)
- Identity (Azure AD sign-in logs, AD event logs)
- Email (phishing, malicious attachments)
- SIEM (third-party log sources)

### Cross-Domain Detection Examples

**Phishing-to-ransomware kill chain (XDR advantage):**
1. Email gateway: Phishing email with Office doc attachment delivered (email telemetry)
2. Endpoint: Word.exe spawns PowerShell (endpoint telemetry — EDR catches this)
3. Network: Outbound connection to C2 IP (network telemetry)
4. Identity: Lateral movement via stolen credentials (identity telemetry)
5. Endpoint: Mass file encryption (endpoint telemetry — EDR catches this)

XDR correlates steps 1-5 into one incident. EDR alone only sees steps 2 and 5, requiring manual correlation.

---

## Key EDR Metrics and Performance Indicators

### Detection Quality Metrics

| Metric | Description | Target |
|---|---|---|
| Mean Time to Detect (MTTD) | Time from attack start to alert | < 1 hour for critical techniques |
| Mean Time to Respond (MTTR) | Time from alert to containment | < 4 hours for critical incidents |
| False Positive Rate | Alerts that are not real threats | < 5% for tuned deployments |
| Detection Coverage | % of ATT&CK techniques with detection | > 70% for Enterprise techniques |
| Sensor Deployment Rate | % of endpoints with active, healthy sensor | > 99% target |
| Alert-to-Incident Ratio | Alerts that escalate to incidents | Varies; track for trend |

### Sensor Health Monitoring

Key sensor health indicators:
- Sensor version (ensure patching current)
- Last checkin time (identify offline/disconnected endpoints)
- Policy assignment (correct policy applied per endpoint type)
- Prevention mode (ensure not in detection-only when prevention is intended)
- Exclusion count per endpoint (outliers may indicate misconfiguration)

### EDR Performance Impact

Typical endpoint performance overhead:
- CrowdStrike: ~1-3% CPU, ~25MB disk
- MDE: ~1-5% CPU (varies by scan configuration), built-in on Windows
- SentinelOne: ~1-3% CPU, ~100MB disk
- Wazuh: ~1-3% CPU, ~200MB disk (depends on rules/FIM scope)

Performance tuning levers:
- Reduce FIM (File Integrity Monitoring) scope to critical directories only
- Adjust scan schedules for resource-intensive operations
- Configure event filtering at the sensor to reduce telemetry volume
- Exclude known-good high-volume processes from deep inspection
