# SentinelOne Singularity Architecture Reference

## Agent Architecture

### Agent Components

The SentinelOne agent operates at multiple levels of the OS stack:

**Windows components:**
- `SentinelAgent.exe` — Primary user-space agent process managing policy, communication, and response actions
- `SentinelHelper.exe` — Auxiliary helper process for elevated operations
- `SentinelStaticEngine.exe` — Static analysis engine for pre-execution file scanning
- `SentinelUI.exe` — System tray interface (if enabled)
- Kernel driver (`SentinelMonitor.sys`) — Kernel-level process, file, registry, and network event interception

**macOS components:**
- System Extension (replaced deprecated kernel extension as of Catalina)
- Full Disk Access required via MDM or manual approval
- Network Extension for network monitoring

**Linux components:**
- Kernel module (inserted into running kernel)
- Compatible with RHEL, CentOS, Ubuntu, Debian, SUSE, Amazon Linux
- eBPF-based monitoring where kernel module installation is restricted (newer kernels)

### Kernel-Level Monitoring Points

**Windows monitoring hooks:**
- Process create/terminate callbacks (PsSetCreateProcessNotifyRoutineEx)
- Image load callbacks (PsSetLoadImageNotifyRoutine)
- Thread creation callbacks
- File system minifilter (IRP monitoring for reads/writes/deletes/renames)
- Registry callbacks (CmRegisterCallback)
- Network monitoring via WFP (Windows Filtering Platform)
- Memory operations monitoring (NtAllocateVirtualMemory, NtWriteVirtualMemory, etc.)

### Static AI Engine

Pre-execution static analysis engine evaluates files before they are allowed to run:

**Analysis dimensions:**
- PE header structure and anomalies
- Import/export tables (API calls the file makes)
- Entropy analysis (high entropy = possibly packed/encrypted)
- Section characteristics (executable sections in unusual places)
- String analysis (known malicious patterns, URLs, registry keys)
- ML model trained on millions of malicious and benign PE files

**Scoring:**
- Score 0-100 (higher = more suspicious)
- Configurable thresholds in policy:
  - Block threshold (e.g., score > 90 = block automatically)
  - Alert threshold (e.g., score 60-90 = alert for review)
- Works entirely offline — no cloud connectivity required for static decisions

### Behavioral AI Engine (Storyline)

The behavioral engine monitors process execution in real-time and builds Storylines:

**Event collection pipeline:**
```
Kernel events (process, file, network, registry, memory)
        |
        v
Kernel driver → User-space agent
        |
        v
Storyline Construction Engine
        |
        v
Behavioral AI Analysis
        |
        v
Decision: Benign / Suspicious / Malicious
        |
        v
Action: Alert / Kill+Quarantine / Remediate / Rollback
```

---

## Storyline Technology Deep Dive

### What Makes Storyline Unique

Traditional EDR platforms generate individual alerts for individual events. An analyst must manually correlate:
- Process A spawned Process B
- Process B wrote File C
- Process B connected to IP D
- File C was executed later as Process E

SentinelOne's Storyline automatically correlates all of these events into a single attack narrative identified by a Storyline ID (STID). The STID is propagated through the process tree — all descendant processes inherit the parent's STID.

### STID Assignment Logic

```
ProcessA (new execution, assigned STID = "ABC123")
  └── ProcessB (child of A, inherits STID = "ABC123")
        ├── ProcessC (child of B, inherits STID = "ABC123")
        └── ProcessD (child of B, inherits STID = "ABC123")
              └── ProcessE (child of D, inherits STID = "ABC123")

File written by ProcessC → tagged with STID = "ABC123"
Network connection from ProcessD → tagged with STID = "ABC123"
Registry change by ProcessE → tagged with STID = "ABC123"

Result: Single Storyline "ABC123" contains ALL related events
```

### Storyline Attack Indicators

The Storyline engine evaluates sequences of behavior, not individual events:

**High-confidence attack sequences:**
1. Office app → ScriptInterpreter → NetworkConnection = likely malicious macro
2. ProcessCreation(from USB) → RegWrite(Run key) = USB persistence
3. ProcessInjection → CredentialAccess = post-exploitation credential theft
4. MassFileRename(>100 files, 60s) → ShadowCopyDelete = ransomware

**Storyline severity assignment:**
- `MALICIOUS` — High confidence behavioral match; auto-response triggered in Protect mode
- `SUSPICIOUS` — Pattern match but not definitive; alert generated
- `PUA` — Potentially unwanted application
- `BENIGN_SUSPICIOUS` — Known-good file behaving oddly (e.g., signed Microsoft binary doing unexpected things)

---

## Autonomous Response Engine

### Response Action Levels

SentinelOne supports three autonomous response levels configurable per policy:

| Level | Configuration | Behavior |
|---|---|---|
| Detect | Policy mode = "Detect" | Events collected, alerts generated. No autonomous action. |
| Protect | Policy mode = "Protect" | Full autonomous response: Kill, Quarantine, Remediate |
| Detect + Protect per category | Mixed per engine | Static AI in Protect, Behavioral in Detect (or vice versa) |

### What Autonomous Response Does

When a Storyline is classified as MALICIOUS in Protect mode:

**1. Kill phase:**
- All processes in the malicious Storyline (current and future) are terminated
- Process termination is via kernel-level signal (cannot be ignored by the process)
- The entire process tree is killed, not just the root process

**2. Quarantine phase:**
- Files created by any process in the Storyline are moved to the quarantine vault
- Quarantine vault: `C:\ProgramData\Sentinel\Quarantine\` (Windows)
- Quarantined files renamed with `.s1q` extension
- File metadata preserved (original path, timestamps, hash)

**3. Remediation phase:**
- Registry changes made by Storyline processes are reversed
- Scheduled tasks created by Storyline processes are removed
- Services installed by Storyline processes are disabled
- Modified file timestamps / attributes are restored where possible

**4. Rollback phase (ransomware):**
- Triggered automatically if Anti-Ransomware engine fires (mass encryption pattern)
- Or manually via console for any Storyline
- Uses Windows VSS shadow copies

### Network Quarantine (Isolation)

Full network isolation severs all network connections except:
- SentinelOne cloud communication (agent maintains connectivity for remote management)
- DNS to configured trusted DNS resolver (optional)

**Isolation methods:**
- Via console: Threat > Actions > Network Quarantine
- Via API: `POST /web/api/v2.1/agents/{id}/actions/disconnect_from_network`
- Via STAR rule: Auto-quarantine on detection trigger

**Isolation does NOT block:**
- SentinelOne agent communication to management console
- Configured trusted IPs (add critical IPs like SIEM/ITSM to trusted list)

---

## Deep Visibility Data Pipeline

### Telemetry Collection

Deep Visibility captures raw telemetry regardless of whether a threat is detected:

**Captured event types:**
- Process create/terminate (with full command line, hash, parent, user)
- File create/read/write/delete/rename
- Network connections (DNS queries, TCP/UDP connections)
- Registry reads and writes
- Module loads (DLL injection detection)
- Login/logout events
- Scheduled task create/modify/delete
- Service install/start/stop
- Driver load events

### Retention and Storage

| Tier | Deep Visibility Retention | Storage |
|---|---|---|
| Core | 14 days | S1 cloud (limited) |
| Control | 14 days | S1 cloud |
| Complete | 90 days | S1 cloud |
| Enterprise | 90 days + | Singularity Data Lake |

**Singularity Data Lake (Enterprise):**
- Extended retention beyond 90 days
- Unified lake for endpoint + third-party log sources
- Queryable via Deep Visibility interface and API
- Used as SIEM/XDR data backend

### Deep Visibility Query Performance

- Query engine is optimized for the Deep Visibility query language
- Queries against large time ranges or without indexed filters can be slow
- **Indexed fields** (fast queries): AgentName, ProcessName, FilePath, RemoteIP, DNS, StorylineId
- **Non-indexed fields** (slower, full scan): CommandLine (use CONTAINS judiciously)
- Limit queries: Add `| limit 1000` to avoid timeouts on broad queries
- Use time ranges to constrain queries: Apply date filter in UI before running

---

## 1-Click Rollback Mechanism

### VSS Integration

SentinelOne rollback uses Windows Volume Shadow Copy Service (VSS):

**How it works:**
1. When ransomware is detected, SentinelOne records the Storyline start time
2. VSS shadow copies that existed before the Storyline start time are identified
3. For each file modified/encrypted by the malicious Storyline, the pre-modification version is retrieved from the shadow copy
4. Files are restored in-place; encrypted versions overwritten with clean versions

**Prerequisites for rollback success:**
- VSS must be enabled on the affected volume
- Shadow copies must exist from before the infection time
- Minimum 1 shadow copy (Windows creates these automatically on system restore points and before Windows Update)

**Check VSS availability:**
```powershell
# Check VSS service
Get-Service VSS | Select Status

# List available shadow copies
vssadmin list shadows

# Check VSS storage allocated per volume
vssadmin list shadowstorage
```

**Ensuring rollback will work (proactive):**
```powershell
# Enable system protection (VSS) on C: drive
Enable-ComputerRestore -Drive "C:\"

# Set VSS storage quota (increase if disk space allows)
vssadmin resize shadowstorage /For=C: /On=C: /MaxSize=10GB

# Verify protection status
Get-ComputerRestorePoint | Select Description, CreationTime | Sort CreationTime | Select -Last 5
```

### Rollback Scope and Limitations

**What rollback restores:**
- All files modified by processes with the malicious Storyline STID
- Files encrypted by ransomware (primary use case)
- Files renamed by the ransomware process

**What rollback does NOT restore:**
- Files deleted (not modified) before SentinelOne began tracking the Storyline
- Files on volumes without VSS enabled
- Files where VSS shadow copies predate the available shadow copies
- Database files in active use (SQL Server, Exchange data files — locked by application)
- Files on Linux/macOS (VSS is Windows-only)

---

## Cloud Architecture

### Management Console (Singularity Platform)

SentinelOne offers two deployment models:

**Cloud-hosted (SaaS):**
- Console at `<tenant>.sentinelone.net`
- Managed by SentinelOne; no customer-managed infrastructure
- Automatic updates and scaling

**On-premises (S1 On-Prem):**
- Customer-deployed Kubernetes cluster
- Requires significant infrastructure (CPU, memory, storage for telemetry)
- Customer manages updates
- Use case: Air-gapped environments, strict data residency requirements

### Agent Communication

Agents communicate to management console via:
- HTTPS (TLS 1.2+) on port 443
- Bidirectional: Agent sends telemetry, receives policy updates and response commands
- Polling interval: Configurable (default: continuous connection / near real-time)
- Offline behavior: Agent continues enforcement based on cached policy; queues telemetry for upload on reconnection

### Multi-Tenant Architecture

**Sites and groups:**
```
Account (top level)
  └── Site (e.g., "EMEA", "North America", or per-customer for MSSPs)
        └── Group (e.g., "Servers", "Workstations", "Developers")
              └── Individual agents
```

- Policies apply at Group or Site level
- RBAC scoped per Site (MSSP can limit customer admins to their site)
- API tokens scoped per account or site

### API Architecture

SentinelOne provides a comprehensive REST API:

**Authentication:**
```python
import requests

# Get API token from: Settings > Users > your user > API Token
headers = {"Authorization": "ApiToken <YOUR_API_TOKEN>"}
base_url = "https://<tenant>.sentinelone.net/web/api/v2.1"

# Example: List endpoints
response = requests.get(f"{base_url}/agents", headers=headers)
agents = response.json()["data"]
```

**Key API endpoints:**
```
GET  /agents              — List agents with filters
GET  /agents/{id}         — Get single agent details
POST /agents/{id}/actions/disconnect_from_network  — Network quarantine
POST /agents/{id}/actions/reconnect_network         — Remove network quarantine
POST /threats/{id}/actions/kill_and_quarantine_threat
POST /threats/{id}/actions/rollback-remediation
GET  /threats             — List threats
GET  /activities          — Audit log / events
POST /dv/init-query       — Initialize Deep Visibility query
POST /dv/events           — Poll Deep Visibility query results
```

**Rate limits:** 3,600 requests/hour per API token (varies by endpoint)
