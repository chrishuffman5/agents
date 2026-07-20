# QRadar Architecture Reference

## Ariel Database

Ariel is QRadar's proprietary time-series database engine optimized for security event storage and search.

### Storage Architecture

```
Events/Flows arrive
    |
    v
Write to current time slice (5-minute intervals)
    |
    v
Columnar compression (per-field)
    |
    v
Time-partitioned storage on disk
    |
    v
Aging: current --> retention --> purge
```

**Key characteristics:**
- **Columnar storage** -- Each field stored separately for efficient aggregation
- **Time-partitioned** -- Data organized by 5-minute time slices
- **Compressed** -- Columnar compression reduces storage by 10-20x
- **Two databases** -- Events database and Flows database (separate storage and search)

### Data Types

| Store | Content | Typical Volume |
|---|---|---|
| **Events** | Parsed log events from all log sources | Primary data store |
| **Flows** | Network flow records (NetFlow, sFlow, IPFIX, QFlow) | Can be very high volume |
| **Payloads** | Raw log payloads (optional storage) | Disk-intensive; disable for cost savings |
| **Offense data** | Offense metadata, contributing events | Relatively small |
| **Asset data** | Discovered assets and vulnerability information | Relatively small |

### Retention Management

```
Retention Policy
    |
    ├── Events: configured per log source or globally
    │   Default: 30 days
    │   Range: 1 day to years (disk-dependent)
    │
    ├── Flows: configured separately
    │   Default: 30 days
    │   Typically shorter retention than events
    │
    └── Payloads: raw log storage
        Default: 30 days
        Can be disabled to save disk
```

**Disk management:**
```bash
# Check Ariel disk usage
/opt/qradar/support/arielDiskMonitor.sh

# List data partitions
ls -la /store/ariel/events/
ls -la /store/ariel/flows/
```

## Event Pipeline Deep Dive

### Collection Phase

**Log source protocols:**

| Protocol | Port | Use Case |
|---|---|---|
| Syslog (UDP) | 514 | Simple log forwarding (unreliable) |
| Syslog (TCP) | 514/6514 | Reliable syslog with TLS option |
| JDBC | Varies | Database log collection (SQL query-based) |
| WinCollect | 8413 | Windows Event Log collection (agent-based) |
| REST API | HTTPS | Cloud service log collection |
| Log File | N/A | File-based log ingestion (local or SMB/NFS) |
| SNMP | 162 | Network device trap collection |

### Parsing Phase (DSM)

**DSM processing order:**
1. **Protocol header parsing** -- Extract syslog header (facility, severity, timestamp)
2. **Log source identification** -- Match to known log source by IP, hostname, or pattern
3. **DSM event mapping** -- Map raw event to QRadar QID (normalized event)
4. **Property extraction** -- Extract fields using:
   - DSM Editor regex patterns
   - CEF (Common Event Format) parsing
   - LEEF (Log Event Extended Format) parsing
   - JSON/XML structured parsing
   - Custom regex overrides

**QID (QRadar Identifier) mapping:**
```
Raw event: "Failed password for root from 10.0.0.1 port 22 ssh2"
    |
    v
QID: 28100019 (Authentication Failed)
Category: Authentication > Login Failure
Severity: 5 (Medium)
```

The QID determines how QRadar categorizes and scores the event. Custom QID mappings override default behavior.

### Normalization Phase

Normalized fields available after parsing:

| Field | Description | Example |
|---|---|---|
| `sourceip` | Event source IP | 10.0.0.50 |
| `destinationip` | Event destination IP | 192.168.1.100 |
| `username` | Associated username | jsmith |
| `qid` | QRadar event ID | 28100019 |
| `category` | Event category (high/low level) | Authentication / Login Failure |
| `severity` | Event severity (1-10) | 5 |
| `credibility` | Log source trustworthiness (1-10) | 8 |
| `relevance` | Target asset relevance (1-10) | 7 |
| `magnitude` | Combined score | 6.7 |
| `logsourceid` | Source log source | 42 |
| `starttime` | Event timestamp | 1712563200000 |
| `devicetime` | Device-reported timestamp | 1712563199000 |

### Coalescing Phase

QRadar coalesces identical events to reduce storage and processing:

**Coalescing criteria (all must match):**
- Same QID
- Same source IP
- Same destination IP
- Same destination port
- Same username
- Within the coalescing interval (default: 10 seconds)

**Result:** Single event stored with `eventcount` reflecting the number of coalesced events.

**Impact on detection:**
- Rules that count events should reference `eventcount`, not the number of stored events
- AQL `SUM(eventcount)` gives true event volume
- Increasing coalescing interval reduces storage but loses temporal granularity

### Rule Evaluation Phase

```
Event passes through rule groups in order:
    |
    ├── Building Blocks (evaluate, flag, but no offense)
    ├── Anomaly Detection Rules (statistical deviation)
    ├── Common Rules (most custom rules)
    └── Default IBM Rules (out-of-box detections)
    |
    v
Rule match?
    |
    ├── Yes: Execute actions
    │   ├── Create/update offense
    │   ├── Add to reference set
    │   ├── Send notification
    │   ├── Execute custom action
    │   └── Generate event/offense correlation
    │
    └── No: Event stored, no offense
```

**Rule test types:**
- **Event property test** -- Match on specific field values
- **Building block test** -- Reference a building block result
- **Counter test** -- "When X events occur in Y minutes"
- **Anomaly test** -- Statistical deviation from baseline
- **Reference data test** -- Check membership in reference set/map
- **Host profile test** -- Match against discovered asset properties
- **Offense property test** -- Test against existing offense attributes

## Distributed Architecture

### Component Communication

```
Event Collectors (remote sites)
    |
    | (Encrypted tunnel, TCP)
    v
Event Processors
    |
    | (Internal event channel)
    v
Console (Central management + Ariel primary)
    |
    ├── Data Nodes (additional Ariel storage/search)
    ├── Flow Processors (network flow analysis)
    └── App Host (containerized QRadar apps)
```

### Event Processor Architecture

Event Processors handle the heavy lifting of parsing and correlation:

```
Incoming events (syslog, JDBC, API)
    |
    v
Parsing pipeline (ECS - Event Collection Service)
    |
    v
Coalescing engine
    |
    v
Rule evaluation engine (CRE - Custom Rule Engine)
    |
    v
Forwarding to Console (for offense management and Ariel storage)
    |
    v
Local Ariel storage (if distributed search enabled)
```

### High Availability

QRadar HA provides failover for the Console component:

- **Active/Passive** -- Primary Console and standby Console
- **Shared IP** -- Virtual IP address fails over with the Console
- **Data replication** -- Ariel data, configuration, and offense state replicated
- **Automatic failover** -- Detects primary failure and promotes standby
- **Manual failback** -- Requires admin intervention to restore primary

**HA does NOT cover:**
- Event Processors (deploy multiple EPs for redundancy)
- Flow Processors (deploy multiple FPs)
- Data Nodes (use Ariel distributed search for redundancy)

## Capacity Planning

### EPS Sizing

| Component | Max EPS (approximate) |
|---|---|
| **All-in-one 3105** | 5,000 EPS |
| **All-in-one 3128** | 12,500 EPS |
| **All-in-one 3148** | 25,000 EPS |
| **Event Processor 1628** | 10,000 EPS per EP |
| **Event Processor 1748** | 20,000 EPS per EP |
| **Event Collector** | 5,000-10,000 EPS (collection only) |

### Storage Estimation

```
Daily storage = (EPS) x 86400 x (avg event size in bytes) / (compression ratio) / (1024^3)
Compression ratio: ~10-20x for columnar storage

Example: 10,000 EPS x 86400 x 500 bytes / 15 / 1073741824 = ~27 GB/day compressed
30-day retention: ~810 GB
```

### Performance Tuning

- **Accumulator settings** -- Controls how events are batched for Ariel writes (Admin > System Settings)
- **Rule evaluation timeout** -- Rules that take too long are logged to CRE performance log
- **Coalescing interval** -- Increase to reduce EPS (at cost of granularity)
- **Payload storage** -- Disable if not needed to reduce disk I/O
- **Data Node offload** -- Move historical Ariel data to Data Nodes for distributed search
