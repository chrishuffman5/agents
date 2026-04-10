# Dynatrace Architecture Reference

> OneAgent, ActiveGate, Smartscape, Davis AI, Grail, dashboards, and DQL.

---

## Core Components

### OneAgent

Single agent installed per host. Automatically instruments the full stack: OS metrics, processes, services, distributed traces, user experience. No code changes required.

**Deployment methods:**
- Direct download from Dynatrace UI (`dynatrace-oneagent.rpm`, `.deb`, `.exe`, `.sh`)
- Ansible playbook (official Dynatrace role)
- Terraform (cloud VMs at provisioning time)
- Kubernetes Operator (DynaKube CRD) -- recommended for K8s

**Automatic instrumentation mechanisms:**
- Bytecode instrumentation (Java, .NET) -- injects at class load time
- Dynamic linking hooks (Node.js, Python, PHP, Ruby) -- wraps framework entry points
- eBPF (Go, infrastructure layer) -- kernel-level instrumentation

Supported languages: Java, .NET/.NET Core, Node.js, PHP, Go, Python, Ruby. Auto-instruments Spring, .NET MVC, Express, Django, Flask, Laravel, and hundreds of frameworks.

### Process and Service Detection

OneAgent detects:
- Running processes and their technology (JVM, CLR, Node process)
- Services within processes (HTTP endpoints, gRPC services, messaging consumers)
- Database calls (JDBC, ADO.NET, pymysql)
- External HTTP calls

Detected services appear in Smartscape automatically. No configuration required for standard frameworks.

### Host Monitoring

OneAgent collects at 1-minute granularity (configurable):
- CPU (per-core, system vs user, steal)
- Memory (used, available, swap, buffer/cache)
- Disk (reads/writes per second, queue length, latency)
- Network (bytes in/out, packet loss, TCP retransmits per interface)
- Process-level resource usage

### PurePath (Distributed Tracing)

Proprietary trace format capturing every transaction end-to-end:
- Method timings contributing to latency (threshold default 1ms)
- SQL query text, parameters, row counts
- External HTTP calls with full URL and response codes
- Exception stack traces at point of occurrence

No sampling by default -- every request captured. Overhead typically < 2% CPU.

OpenTelemetry integration: Dynatrace ingests OTLP traces, metrics, and logs. OneAgent enriches OTel spans with Dynatrace metadata.

---

### ActiveGate

Proxy/cluster agent with two roles:
- **Environment ActiveGate:** Routes OneAgent traffic to Dynatrace cluster. Required for network-isolated environments. Runs synthetic monitoring, AWS/Azure/GCP integrations.
- **Cluster ActiveGate** (Managed only): Cluster-level operations.

---

### Smartscape

Real-time topology map automatically discovering and mapping relationships between hosts, processes, services, applications, and cloud resources. Updated continuously. Feeds the Davis AI causation engine.

Smartscape levels: Host > Process > Service > Application. Each entity linked to its dependencies.

---

### Davis AI

Deterministic AI engine (not probabilistic ML). Uses Smartscape topology to determine causation, not just correlation.

**How Davis works:**
1. Detects anomaly using learned baselines (no threshold config needed)
2. Identifies root cause from topology graph
3. Groups related problems into single Problem card
4. Suppresses downstream symptoms (only root cause shown)
5. Continuously updates as new evidence arrives
6. Auto-closes when metrics return to baseline

Davis monitors: response time deviation, error rate spikes, throughput drops, infrastructure saturation, availability failures.

---

### Grail

Data lakehouse (introduced 2022+). Stores all observability data (metrics, logs, traces, events, security) in unified, schema-less store. Enables DQL queries across all data types without pre-indexing. Replaces legacy ElasticSearch-based log storage.

---

## DQL (Dynatrace Query Language)

Pipeline query language for Grail. Commands piped with `|`.

### Core Commands

| Command | Purpose |
|---------|---------|
| `fetch` | Select data source (logs, metrics, events, entities, traces) |
| `filter` | Boolean filter (`==`, `!=`, `in`, `contains`, `matchesPhrase`) |
| `summarize` | Aggregate: `count()`, `sum()`, `avg()`, `min()`, `max()`, `percentile()` |
| `sort` | Order results ascending/descending |
| `limit` | Restrict row count |
| `fieldsAdd` | Compute new fields: `fieldsAdd response_ms = value / 1000000` |
| `fieldsRemove` | Drop fields from result |
| `makeTimeseries` | Convert to time-series for charting |
| `parse` | Extract fields from text using pattern language |
| `join` | Join two result sets on key field |
| `lookup` | Enrich from reference table |

### DQL Examples

**Error logs for a service:**
```dql
fetch logs
| filter dt.entity.service == "SERVICE-ABC123"
| filter loglevel == "ERROR"
| sort timestamp desc
| limit 100
```

**Service response time:**
```dql
fetch dt.entity.service, metrics.builtin:service.response.time
| filter dt.entity.service.name == "payment-api"
| makeTimeseries avg(value), by: {dt.entity.service.name}, interval: 5m
```

**Log field extraction:**
```dql
fetch logs
| parse content, "TEXT 'status=' INT:status_code"
| summarize count(), by: {status_code}
```

---

## Notebooks

Interactive analysis environment (similar to Jupyter):
- DQL query cells with live results
- Markdown documentation cells
- Charts, tables, heatmaps inline
- Share and collaborate
- Schedule notebook execution

---

## Dashboards

Drag-and-drop dashboard builder. Tile types:
- Time-series charts (metric or DQL)
- Single-value KPI tiles
- Data tables
- Service flow / Smartscape embed
- SLO status
- Log viewer

Variables (dropdown filters) parameterize DQL across tiles. JSON export for version control.
