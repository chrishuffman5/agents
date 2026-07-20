# CrowdStrike Falcon Architecture Reference

## Sensor Architecture

### Sensor Components

The CrowdStrike Falcon sensor is a kernel-level agent that operates at multiple layers of the OS:

**Windows sensor components:**
- `csagent.sys` — Kernel driver: intercepts process creation, network connections, file system events, registry operations at kernel level. Uses Microsoft-approved kernel hooks and ETW (Event Tracing for Windows).
- `csfalconservice.exe` — User-space service: manages communication with Falcon cloud, policy enforcement, RTR communication.
- `CSFalconContainer.exe` — Container monitoring component (when container support enabled).

**Kernel-level interception points:**
- Process create/terminate callbacks (PsSetCreateProcessNotifyRoutineEx)
- Image load callbacks (PsSetLoadImageNotifyRoutine)
- File system minifilter (IRP-based file event monitoring)
- Network transport layer (WFP — Windows Filtering Platform for network events)
- Registry callbacks (CmRegisterCallback)
- ETW providers for additional telemetry

**Why kernel-level matters:**
- Kernel-level detection cannot be hidden from by user-space rootkits
- Rootkit detection requires visibility at or below the rootkit's privilege level
- Trade-off: Kernel driver stability (BSoD risk on kernel panics)
- CrowdStrike publishes strict QA process for driver releases (post-July 2024 channel file incident, additional staged rollout controls added)

### Sensor Communication

The sensor communicates exclusively with CrowdStrike cloud (no on-premises server):

**Communication model:**
- Outbound TLS 1.2+ to `ts01-b.cloudsink.net` and related endpoints on port 443
- Bidirectional: Sensor sends telemetry, receives policy updates and detection content
- No inbound connections required on the endpoint
- Sensor queues events locally if connectivity is lost; retransmits when connectivity restored
- Maximum local queue size: 1GB (default) before oldest events are dropped

**Required network connectivity (firewall rules):**
```
Destination: *.cloudsink.net, *.crowdstrike.com
Port: 443 (HTTPS/TLS)
Direction: Outbound from endpoints
Protocol: TCP
```

**Proxy support:**
- Sensor supports authenticated proxy
- Configure via installation parameter: `APP_PROXYNAME=proxy.corp.com APP_PROXYPORT=8080`
- Or via falconctl: `sudo /opt/CrowdStrike/falconctl -s --aph=proxy.corp.com --app=8080`

### Sensor Self-Protection

CrowdStrike sensors include anti-tampering protections:
- Sensor process and driver are protected against termination by non-privileged processes
- Uninstall requires maintenance token (console-generated) or CrowdStrike-provided uninstall tool
- Protected by Windows PPL (Protected Process Light) on supported Windows versions
- Linux: Sensor resists `kill` signals from user-space processes

**Maintenance token for uninstall:**
1. Navigate to Hosts > Host Management
2. Find the host
3. Actions > Enable Uninstall Protection / Get Maintenance Token
4. Use token with uninstaller: `msiexec /x WindowsSensor.msi MAINTENANCE_TOKEN=<token>`

---

## Threat Graph

### Architecture

Threat Graph is CrowdStrike's cloud-based AI correlation and threat intelligence platform. It is the core of what differentiates CrowdStrike from traditional AV.

**Scale:**
- Processes ~1 trillion events per week across all CrowdStrike customers
- Graph database tracking relationships between files, processes, users, network connections
- Real-time enrichment of events with threat intelligence context

**Threat Graph components:**
- **Indicatorsof Attack (IOA) engine** — Evaluates event sequences against behavioral patterns
- **Threat intelligence enrichment** — Tags events with known actor, campaign, and malware family context
- **Machine learning models** — Both on-sensor (offline-capable) and cloud-based (requires connectivity)
- **Crowdsourced intelligence** — Threat patterns discovered on one customer's environment become detection coverage for all customers

### On-Sensor ML vs. Cloud ML

| Model | Location | Works Offline | Latency | Coverage |
|---|---|---|---|---|
| On-sensor ML | Endpoint | Yes | Milliseconds | File-based malware (PE analysis) |
| Cloud ML | Threat Graph | No | <1 second | More sophisticated, larger model |
| Behavioral IOA | Endpoint | Yes (local rules) + Cloud (complex sequences) | Variable | Process behaviors, sequences |

**On-sensor ML file scoring:**
- Evaluates PE (Portable Executable) file attributes before execution
- Uses static analysis features (import table, entropy, section characteristics, strings)
- Produces a score 0-100; threshold for block/detect configurable in prevention policy
- Works entirely without internet connectivity — critical for air-gapped or intermittently connected endpoints

---

## Multi-Tenant Architecture (MSSP / Large Enterprise)

### Parent/Child CID Structure

CrowdStrike supports hierarchical multi-tenancy:
- **Parent CID** — Top-level account (MSSP or enterprise parent)
- **Child CIDs** — Customer or business unit tenants
- Parent can view child CID data (with appropriate permissions)
- Policy inheritance from parent to child is configurable

### Flight Control (MSSP Portal)

CrowdStrike Flight Control allows MSSPs to manage multiple customer tenants from a single pane:
- Centralized sensor deployment tracking
- Policy template management across customers
- Aggregated detection view
- Bulk RTR operations across customers (with appropriate permissions)

---

## Cloud Workload and Container Support

### Falcon for Cloud Workloads (CWP)

For cloud-native environments:
- Supports AWS EC2, Azure VMs, GCP Compute
- Container-aware: Tracks process trees within container context
- Kubernetes operator available for DaemonSet deployment
- Serverless visibility via API-based monitoring (limited telemetry vs. agent)

### Container Security Architecture

**DaemonSet deployment (Kubernetes):**
```yaml
# Falcon sensor deployed as DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falcon-sensor
spec:
  selector:
    matchLabels:
      name: falcon-sensor
  template:
    spec:
      containers:
      - name: falcon-sensor
        image: falcon-sensor:latest
        env:
        - name: FALCONCTL_OPT_CID
          valueFrom:
            secretKeyRef:
              name: falcon-cid
              key: cid
        securityContext:
          privileged: true  # Required for kernel-level monitoring
```

**Container telemetry captured:**
- Container image metadata (image ID, registry, tag)
- Container runtime (Docker, containerd, CRI-O)
- Process events within container namespace
- Network connections with container context

---

## VDI (Virtual Desktop Infrastructure) Considerations

### Persistent VDI

- Standard deployment; each persistent VM has its own unique sensor (AID)
- Manage as physical endpoints

### Non-Persistent VDI (Clones)

Each clone generates a unique AID (Agent ID) — ensures each session is tracked independently:

**Deployment for Citrix/VMware Horizon non-persistent:**
1. Install sensor in master/gold image WITHOUT registering with CID
2. Sensor registrations happen on first boot of each clone
3. Use sysprep-equivalent to clear the sensor's stored AID before image capture:
```powershell
# Clear AID before capturing image
sc stop csagent
Remove-Item "C:\Windows\System32\drivers\CrowdStrike\*.sys" -ErrorAction SilentlyContinue
# Or use official CrowdStrike VDI preparation guide
```

**Stale sensor management:**
- Non-persistent VDI generates stale sensor records in Falcon as clones cycle
- Use the Falcon API or "Inactive Sensor Management" to automatically delete sensors not checked in for X days
- Recommended: Delete sensors not seen for 7 days in non-persistent VDI environments

---

## Falcon API Architecture

The Falcon API enables programmatic access to all Falcon platform capabilities.

### Authentication

```python
# OAuth2 client credentials flow
import falconpy

falcon = falconpy.Hosts(
    client_id="CLIENT_ID_FROM_CONSOLE",
    client_secret="CLIENT_SECRET_FROM_CONSOLE"
)
```

**API key scopes** — Least privilege principle: API keys should have only the scopes required for their purpose. Available scopes include:
- Hosts Read/Write
- Detections Read/Write
- Incidents Read/Write
- IOC Management Read/Write
- RTR (Responder, Active Responder, Admin)
- Event Streams (real-time event consumption)
- Threat Intelligence

### Key API Endpoints (FalconPy SDK)

```python
# Get all online hosts
hosts = falconpy.Hosts(client_id=cid, client_secret=secret)
devices = hosts.query_devices_by_filter(filter="status:'Online'")

# Get detections
detections = falconpy.Detects(client_id=cid, client_secret=secret)
recent = detections.query_detections(filter="status:!resolved+created_timestamp:>='2024-01-01'")

# Event streaming (real-time telemetry)
stream = falconpy.EventStreams(client_id=cid, client_secret=secret)
# Returns feed URL for subscribing to real-time event stream
```

### Streaming API (Real-Time Events)

For SIEM integration, CrowdStrike provides a streaming API:
- Subscribe to a partition and receive events in near real-time
- Events include: DetectionSummaryEvent, AuthActivityAuditEvent, UserActivityAuditEvent
- Requires token refresh every 25 minutes (or use long-polling)
- Output format: JSON events, one per line, in the CrowdStrike event schema

**SIEM integration pattern:**
```python
# Simplified streaming consumer
import falconpy, requests

stream_api = falconpy.EventStreams(client_id=cid, client_secret=secret)
result = stream_api.list_available_streams_o_auth2()
feed_url = result["body"]["resources"][0]["dataFeedURL"]

# Stream events
response = requests.get(feed_url, headers={"Authorization": f"Token {token}"}, stream=True)
for line in response.iter_lines():
    if line:
        event = json.loads(line)
        # Forward to SIEM
```

---

## Sensor Update Management

### Channel Files vs. Sensor Updates

CrowdStrike distinguishes between:
- **Sensor releases** — Full sensor software (CSP patches, new capabilities). Deployed via sensor update policies.
- **Channel files** — Rapid configuration updates (detection logic updates, IOA rule changes). Automatically pushed by Falcon cloud, not configurable per-customer.

**Sensor update policies:**
- Policies define which sensor version to pin or auto-update
- Options: "Sensor version updates" with N-1, N-2 lag for testing
- Best practice: Test new sensor versions on a representative group before broad deployment

### Sensor Version Pinning

1. Navigate to Hosts > Sensor Update Policies
2. Create policy for "Test" group with latest sensor
3. Create policy for "Production" group with N-1 version
4. After test validation, update production policy

**Important note on channel files (post-July 2024):**
Following the CrowdStrike channel file incident (July 19, 2024), CrowdStrike implemented:
- Staged rollout for channel file updates (not all customers simultaneously)
- Increased testing for channel files that use new template types
- New "Content Update Reliability" controls in the Sensor Update policy page
