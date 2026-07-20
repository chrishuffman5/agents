# Wazuh Architecture Reference

## Core Component Architecture

Wazuh is a distributed security monitoring platform with four primary components:

```
                    ┌─────────────────────────────────────────────┐
                    │                  Wazuh Stack                 │
                    │                                              │
  Endpoints         │  ┌──────────────┐     ┌────────────────┐   │
  ─────────         │  │ Wazuh Manager│────►│ Wazuh Indexer  │   │
  Windows Agents──►─│  │              │     │ (OpenSearch)   │   │
  Linux Agents───►──│  │  Detection   │     │                │   │
  macOS Agents───►──│  │  Rules       │◄────│  Event Storage │   │
  Agentless──────►──│  │  Active Resp.│     │  Full-Text     │   │
                    │  └──────┬───────┘     │  Search        │   │
                    │         │             └────────┬───────┘   │
                    │         │ Filebeat              │           │
                    │         └──────────────────────┘           │
                    │                                             │
                    │         ┌──────────────────┐               │
                    │         │  Wazuh Dashboard │               │
                    │         │  (OpenSearch DB) │               │
                    │         │                  │               │
                    │         │  Alerts View     │               │
                    │         │  Compliance      │               │
                    │         │  FIM / SCA       │               │
                    │         └──────────────────┘               │
                    └─────────────────────────────────────────────┘
```

---

## Wazuh Manager

### Role

The Manager is the central brain of Wazuh:
- Receives and processes events from all agents
- Runs the ruleset against decoded events
- Generates alerts (stored in `alerts.log` and `alerts.json`)
- Manages agent registration and authentication
- Sends active response commands to agents
- Coordinates SCA policy distribution

### File Locations (Linux)

```
/var/ossec/
├── bin/               # Wazuh binaries (wazuh-control, wazuh-logtest, etc.)
├── etc/
│   ├── ossec.conf     # Primary manager configuration
│   ├── rules/         # Custom rules (local_rules.xml, custom_rules/*.xml)
│   ├── decoders/      # Custom decoders (local_decoder.xml)
│   ├── shared/        # Agent groups configuration and SCA policies
│   │   ├── default/   # Default group files
│   │   └── <group>/   # Per-group configurations
│   └── client.keys    # Agent registration keys
├── logs/
│   ├── alerts/
│   │   ├── alerts.log    # Human-readable alert log
│   │   └── alerts.json   # JSON-format alerts (for Filebeat → Indexer)
│   └── ossec.log         # Manager operational log
├── queue/             # Agent event queue
│   └── agents-info/   # Agent state files
├── ruleset/           # Default Wazuh ruleset (DO NOT EDIT)
│   ├── rules/
│   └── decoders/
└── active-response/
    └── bin/           # Active response scripts
```

### Manager Services

```bash
# Start/stop/status of all Wazuh components
/var/ossec/bin/wazuh-control start
/var/ossec/bin/wazuh-control stop
/var/ossec/bin/wazuh-control status

# Or via systemd (Wazuh 4.x)
systemctl start wazuh-manager
systemctl status wazuh-manager

# Check operational logs
tail -f /var/ossec/logs/ossec.log

# Check alert output
tail -f /var/ossec/logs/alerts/alerts.json | python3 -m json.tool
```

---

## Wazuh Agent

### Agent Architecture

The agent is a lightweight process running on monitored endpoints:
- Collects logs from OS, applications, and security tools
- Monitors file system integrity (FIM)
- Runs SCA checks
- Executes active response commands from manager
- Communicates with manager via TCP port 1514 (encrypted with pre-shared keys)

### Agent Communication Protocol

```
Agent → Manager communication:
- Port: 1514 (TCP, default) or UDP
- Encryption: Pre-shared key (generated during registration)
- Heartbeat: Every 30 seconds (configurable)
- Data format: OSSEC log format → decoded server-side

Agent registration (enrollment):
- Method 1: Manager-side (manual key generation via manage_agents)
- Method 2: Auto-enrollment via enrollment service (port 1515, recommended)
- Method 3: Agent-auth tool (password-protected enrollment)
```

### Agent Enrollment (Recommended: Auto-enrollment)

```xml
<!-- Manager ossec.conf: Enable enrollment service -->
<auth>
  <disabled>no</disabled>
  <port>1515</port>
  <use_source_ip>no</use_source_ip>
  <force>
    <enabled>yes</enabled>
    <key_mismatch>yes</key_mismatch>
    <disconnected_time enabled="yes">1h</disconnected_time>
    <after_registration_time>1h</after_registration_time>
  </force>
</auth>
```

```xml
<!-- Agent ossec.conf: Configure enrollment -->
<client>
  <server>
    <address>wazuh-manager.corp.com</address>
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
  <enrollment>
    <enabled>yes</enabled>
    <manager_address>wazuh-manager.corp.com</manager_address>
    <port>1515</port>
    <agent_name>server001</agent_name>
    <groups>linux-servers</groups>
    <authorization_pass_path>/var/ossec/etc/authd.pass</authorization_pass_path>
  </enrollment>
</client>
```

### Agent Groups

Agent groups allow distributing different configurations to different endpoint types.

```bash
# Manager-side: Create group
/var/ossec/bin/agent_groups -a -g linux-servers

# Assign agent to group
/var/ossec/bin/agent_groups -a -i 003 -g linux-servers

# View agent group assignment
/var/ossec/bin/agent_groups -l -g linux-servers

# Group configuration files
# Place shared configuration in /var/ossec/etc/shared/<group_name>/agent.conf
```

**agent.conf (group-specific configuration):**
```xml
<!-- /var/ossec/etc/shared/linux-servers/agent.conf -->
<agent_config>
  <!-- Additional FIM paths for servers -->
  <syscheck>
    <directories check_all="yes" realtime="yes">
      /opt/application
    </directories>
  </syscheck>
  
  <!-- Collect application-specific logs -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/application/*.log</location>
  </localfile>
</agent_config>
```

### Agentless Monitoring

For devices where an agent cannot be installed (network devices, legacy systems):

```xml
<!-- Manager ossec.conf -->
<agentless>
  <type>ssh_integrity_check_linux</type>
  <frequency>43200</frequency>
  <host>user@network-device.corp.com</host>
  <state>periodic_diff</state>
  <arguments>/etc /usr/bin /usr/sbin</arguments>
</agentless>
```

Supported agentless types: `ssh_integrity_check_linux`, `ssh_integrity_check_bsd`, `ssh_generic_diff`, `ciscat` (network device config auditing)

---

## Wazuh Indexer (OpenSearch)

### Architecture

Wazuh Indexer is a customized OpenSearch distribution:
- Stores all Wazuh events and alerts (indices)
- Provides full-text search for Dashboard
- Scales horizontally via clustering

### Index Structure

```
Wazuh creates daily rotating indices:
wazuh-alerts-4.x-YYYY.MM.DD       # Alert events (filtered by level threshold)
wazuh-archives-4.x-YYYY.MM.DD     # All events (if logall=yes, very large)
wazuh-monitoring-4.x-YYYY.MM.DD   # Agent connectivity monitoring
wazuh-statistics-4.x-YYYY.MM.DD   # Wazuh performance statistics
```

### Index Lifecycle Management

Configure ILM to control data retention and storage:

```
Navigate to: Dashboard > Indexer management > Index Policies

Example policy:
- Hot phase (0-7 days): Full shard, fast SSD
- Warm phase (7-30 days): Fewer replicas, standard disk
- Delete phase (30 days): Remove index

Alternatively configure in OpenSearch via REST API:
PUT _plugins/_ism/policies/wazuh-alerts-policy
{
  "policy": {
    "states": [
      {
        "name": "hot",
        "transitions": [{"state_name": "delete", "conditions": {"min_index_age": "30d"}}]
      },
      {
        "name": "delete",
        "actions": [{"delete": {}}]
      }
    ]
  }
}
```

### Storage Capacity Planning

Rough estimates for index storage requirements:

| Agents | Events/Day | Storage/Day | 30-Day Storage |
|---|---|---|---|
| 50 | ~500K | ~2 GB | ~60 GB |
| 200 | ~2M | ~8 GB | ~240 GB |
| 500 | ~5M | ~20 GB | ~600 GB |
| 1000 | ~10M | ~40 GB | ~1.2 TB |

Note: Enabling `logall=yes` multiplies storage 5-10x. Only enable for specific investigation needs.

---

## Wazuh Dashboard

### Architecture

Built on OpenSearch Dashboards (fork of Kibana):
- Provides web console at HTTPS port 443 (default after 4.x install)
- Connects to Wazuh Indexer for data
- Wazuh plugin adds security-specific views

### Key Dashboard Sections

```
Wazuh Dashboard
├── Overview — Summary metrics across all agents
├── Security Events — Alert browser with filtering
├── Integrity Monitoring — FIM events and baseline changes
├── Security Configuration Assessment — SCA results per agent
├── Vulnerability Detection — CVE findings per agent
├── MITRE ATT&CK — Events mapped to ATT&CK framework
├── Compliance
│   ├── PCI DSS — PCI DSS requirement coverage
│   ├── HIPAA — HIPAA requirement coverage
│   ├── GDPR — GDPR requirement coverage
│   ├── NIST 800-53 — Control coverage
│   └── TSC — SOC2 coverage
├── Management
│   ├── Agents — Agent list, health, groups
│   ├── Rules — Rule browser and testing
│   ├── Decoders — Decoder browser
│   ├── Configuration — Manager config viewer
│   └── Statistics — Manager and agent statistics
└── Dev Tools — Direct OpenSearch/Wazuh API queries
```

---

## Cluster Deployment

For deployments with >100 agents, use a distributed cluster architecture.

### Cluster Components

**Wazuh Manager cluster:**
- **Master node** — Handles agent registration, rule distribution, configuration management
- **Worker nodes** — Handle agent connections and event processing (horizontal scaling)
- Agents automatically distributed across worker nodes

```xml
<!-- Master node: /var/ossec/etc/ossec.conf -->
<cluster>
  <name>wazuh</name>
  <node_name>master-node</node_name>
  <node_type>master</node_type>
  <key>c98b62a9b6169ac5f67dae55ae4a9088</key>  <!-- Cluster pre-shared key -->
  <port>1516</port>
  <bind_addr>0.0.0.0</bind_addr>
  <nodes>
    <node>wazuh-master.corp.com</node>
  </nodes>
  <hidden>no</hidden>
  <disabled>no</disabled>
</cluster>
```

```xml
<!-- Worker node: /var/ossec/etc/ossec.conf -->
<cluster>
  <name>wazuh</name>
  <node_name>worker-node-01</node_name>
  <node_type>worker</node_type>
  <key>c98b62a9b6169ac5f67dae55ae4a9088</key>  <!-- Same key as master -->
  <port>1516</port>
  <bind_addr>0.0.0.0</bind_addr>
  <nodes>
    <node>wazuh-master.corp.com</node>  <!-- Point to master -->
  </nodes>
  <hidden>no</hidden>
  <disabled>no</disabled>
</cluster>
```

### Wazuh Indexer Cluster (OpenSearch)

For high-availability indexer:

```yaml
# /etc/wazuh-indexer/opensearch.yml (on each indexer node)
cluster.name: wazuh-cluster
node.name: indexer-node-01
network.host: 0.0.0.0
http.port: 9200
discovery.seed_hosts:
  - "indexer-01.corp.com"
  - "indexer-02.corp.com"
  - "indexer-03.corp.com"
cluster.initial_master_nodes:
  - "indexer-01.corp.com"
  - "indexer-02.corp.com"
  - "indexer-03.corp.com"
plugins.security.ssl.transport.pemcert_filepath: /etc/wazuh-indexer/certs/indexer-01.pem
```

**Minimum cluster sizing for HA:**
- Wazuh Manager: 1 master + 2 workers (or more based on agent count)
- Wazuh Indexer: 3 nodes minimum (quorum for split-brain prevention)
- Wazuh Dashboard: 1-2 nodes (stateless, can be load balanced)
- Load balancer in front of worker nodes for agent connections

---

## Filebeat (Event Forwarding)

Filebeat forwards Wazuh Manager output (alerts.json) to Wazuh Indexer.

### Filebeat Configuration

```yaml
# /etc/filebeat/filebeat.yml (on Wazuh Manager node)
filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: false  # Set true only if logall=yes and you need raw event ingestion

setup.template.json.enabled: true
setup.template.json.path: "/etc/filebeat/wazuh-template.json"
setup.template.json.name: "wazuh"
setup.ilm.overwrite: true
setup.ilm.enabled: false

output.elasticsearch:
  hosts: ["https://wazuh-indexer:9200"]
  protocol: https
  ssl.certificate_authorities:
    - /etc/filebeat/certs/root-ca.pem
  ssl.certificate: "/etc/filebeat/certs/filebeat.pem"
  ssl.key: "/etc/filebeat/certs/filebeat-key.pem"
  username: admin
  password: SecurePassword
```

---

## Wazuh API

The Wazuh Manager exposes a REST API for automation and integration.

### Authentication

```bash
# Get JWT token (default credentials: admin/SecurePassword)
TOKEN=$(curl -su admin:SecurePassword \
  -X GET https://wazuh-manager:55000/security/user/authenticate?raw=true \
  -k)

# Use token in subsequent requests
curl -H "Authorization: Bearer $TOKEN" \
  https://wazuh-manager:55000/agents?pretty=true -k
```

### Key API Endpoints

```bash
# List all agents
GET /agents
GET /agents?status=active
GET /agents?group=linux-servers

# Get agent details
GET /agents/{agent_id}

# Agent groups
GET /groups
PUT /agents/{agent_id}/group/{group_id}

# Restart agents
PUT /agents/restart

# Get alerts (via indexer, not manager API directly)
# Use Wazuh Indexer API / OpenSearch API for alert queries

# SCA results
GET /sca/{agent_id}/checks/{policy_id}

# Vulnerability findings
GET /vulnerability/{agent_id}

# Active response (run command on agent)
PUT /active-response
Body: {
  "command": "firewall-drop",
  "alert": {"data": {"srcip": "192.168.1.100"}},
  "arguments": ["add", "-", "192.168.1.100"],
  "agents_list": ["003"]
}
```

### SIEM Integration via Indexer API

Query events directly from Wazuh Indexer (OpenSearch):

```python
from opensearchpy import OpenSearch

client = OpenSearch(
    hosts=[{"host": "wazuh-indexer", "port": 9200}],
    http_auth=("admin", "SecurePassword"),
    use_ssl=True,
    verify_certs=False  # Use proper certs in production
)

# Search for high-severity alerts in last 24 hours
query = {
    "query": {
        "bool": {
            "must": [
                {"range": {"@timestamp": {"gte": "now-24h"}}},
                {"range": {"rule.level": {"gte": 10}}}
            ]
        }
    },
    "sort": [{"@timestamp": {"order": "desc"}}],
    "size": 100
}

result = client.search(
    index="wazuh-alerts-*",
    body=query
)

for hit in result["hits"]["hits"]:
    print(hit["_source"]["rule"]["description"],
          hit["_source"]["rule"]["level"],
          hit["_source"]["agent"]["name"])
```

---

## Performance Tuning

### Manager Performance

For high-event-volume environments:

```xml
<!-- /var/ossec/etc/ossec.conf: Manager tuning -->
<global>
  <logall>no</logall>          <!-- Disable if not needed; major I/O reduction -->
  <logall_json>no</logall_json>
  <agents_disconnection_time>3m</agents_disconnection_time>
  <agents_disconnection_alert_time>60s</agents_disconnection_alert_time>
</global>

<!-- Analysis threads (default: 4; increase for high-volume) -->
<analysis>
  <max_output_size>2M</max_output_size>
  <event_threads>8</event_threads>  <!-- Match CPU core count -->
  <rule_threads>8</rule_threads>
</analysis>
```

### Agent Performance

Reduce agent CPU/memory impact:

```xml
<!-- Reduce FIM scan frequency -->
<syscheck>
  <frequency>86400</frequency>  <!-- Daily instead of 12-hourly -->
  <scan_on_start>no</scan_on_start>  <!-- Disable startup scan on servers -->
</syscheck>

<!-- Limit log collection rate -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/syslog</location>
  <max_size_mb>10</max_size_mb>  <!-- Max log size per rotation -->
</localfile>
```

### Indexer Performance (OpenSearch)

```yaml
# /etc/wazuh-indexer/jvm.options
# Set heap to 50% of available RAM (max 32GB due to compressed oops)
-Xms8g
-Xmx8g

# opensearch.yml tuning
indices.memory.index_buffer_size: 20%
thread_pool.write.queue_size: 10000
```
