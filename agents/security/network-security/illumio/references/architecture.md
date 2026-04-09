# Illumio Architecture Reference

## Policy Compute Engine (PCE) Architecture

The PCE is the centralized brain of Illumio. It manages all policy, stores workload metadata, computes per-workload rules, and communicates with VEN agents.

### PCE Components

**PCE Core Services:**
- **Policy Engine** -- Resolves label-based rules into per-workload IP-based firewall rules
- **Workload Manager** -- Tracks all workloads, labels, and VEN agent state
- **Traffic Flow Engine** -- Ingests and stores traffic flow summaries from VEN agents
- **Explorer Service** -- Provides traffic analysis and query interface
- **REST API Server** -- External integration endpoint
- **Event Service** -- Audit log and event notification

**PCE Data Services:**
- **PostgreSQL** -- Primary data store (workloads, labels, policy, traffic flows)
- **Traffic Flow Store** -- Dedicated storage for network flow telemetry
- **Object Store** -- Blob storage for large objects (reports, exports)

### PCE Deployment Models

**Standalone (single node):**
```
[PCE Server]
  All services on one VM/physical server
  Used for: small deployments (< 500 workloads), POC, development
  
  Recommended: 8 vCPU, 32GB RAM, 500GB SSD
```

**Supercluster (HA, recommended for production):**
```
[PCE Node 1 - Leader]   [PCE Node 2 - Replica]   [PCE Node 3 - Replica]
  
  - Active/active for reads
  - Leader handles writes; replicated to all nodes
  - Automatic leader election (Raft consensus)
  - Any node can serve API requests
  - VEN agents connect to any PCE node via load balancer
  
  Recommended per node: 16 vCPU, 64GB RAM, 1TB SSD
  Load balancer: HAProxy, F5, or cloud LB in front of all nodes
```

**Distributed PCE (large enterprise, 100K+ workloads):**
```
[Global PCE]           -- Policy authoring, global coordination
     |
[Regional PCE 1]       -- Services regional VEN agents (data center A)
     |
[Regional PCE 2]       -- Services regional VEN agents (data center B)
```

### PCE HA Configuration

```yaml
# PCE cluster configuration (simplified)
cluster:
  nodes:
    - fqdn: pce-node1.corp.local
      role: leader
    - fqdn: pce-node2.corp.local
      role: replica
    - fqdn: pce-node3.corp.local
      role: replica
  
  virtual_ip: pce.corp.local  # DNS load balanced or VIP
  
  database:
    replication: synchronous   # All writes replicated before ACK
    failover_timeout: 30s
```

## VEN Architecture

### VEN Components

The Virtual Enforcement Node (VEN) is a lightweight agent with two primary functions:
1. **Enforcement** -- Manage OS-native firewall rules (iptables/WFP)
2. **Visibility** -- Report traffic flow summaries to PCE

**VEN processes (Linux):**

| Process | Function |
|---|---|
| `illumio-ven` | Main VEN process; manages firewall rules |
| `illumio-vend` | VEN daemon; persistent service manager |
| `ilnetdetect` | Network interface detection |

**VEN communication with PCE:**
- **Outbound HTTPS (TCP/8443 or 443)** -- VEN initiates all connections to PCE
- **No inbound connections required** -- VEN is a client; PCE is a server
- **Heartbeat** -- VEN sends heartbeat every 30 seconds; PCE detects offline VENs
- **Policy update** -- PCE pushes computed rules to VEN when policy changes

**VEN firewall management:**

*Linux (iptables):*
```bash
# Illumio creates chains in iptables
# Main Illumio chains:
#   ILLUMIO_INPUT      - Rules for incoming traffic
#   ILLUMIO_OUTPUT     - Rules for outgoing traffic  
#   ILLUMIO_FORWARD    - Rules for forwarded traffic (if gateway)

# View Illumio-managed iptables rules
iptables-save | grep -A 2 "ILLUMIO"

# Example output showing allow rule:
# -A ILLUMIO_INPUT -s 10.1.2.0/24 -p tcp --dport 8080 -m comment --comment "rule-id:abc123" -j ACCEPT
# -A ILLUMIO_INPUT -j DROP  (default drop at end of Illumio chain)
```

*Windows (WFP):*
- Illumio uses Windows Filtering Platform -- the same API used by Windows Firewall
- Illumio rules appear in `wf.msc` (Windows Firewall with Advanced Security)
- View: `Get-NetFirewallRule | Where-Object {$_.Group -like "*Illumio*"}`

### Policy Computation Engine

The PCE's policy engine translates label-based rules into per-workload firewall rules. This process runs whenever labels or rules change.

**Resolution process:**

```
Input:
  Rule: Consumer[App:OrdersApp|Role:Web] -> Provider[App:OrdersApp|Role:App] : TCP/8080

Step 1: Label resolution
  PCE queries workload database for all workloads matching label selectors
  Consumer match: [10.1.1.10, 10.1.1.11, 10.1.1.12]  (web servers)
  Provider match: [10.1.2.10, 10.1.2.11]              (app servers)

Step 2: Rule generation per workload
  For each provider workload (10.1.2.10, 10.1.2.11):
    Generate iptables INPUT ACCEPT rule:
      -A ILLUMIO_INPUT -s 10.1.1.10 -p tcp --dport 8080 -j ACCEPT
      -A ILLUMIO_INPUT -s 10.1.1.11 -p tcp --dport 8080 -j ACCEPT
      -A ILLUMIO_INPUT -s 10.1.1.12 -p tcp --dport 8080 -j ACCEPT

  For each consumer workload (10.1.1.10, 10.1.1.11, 10.1.1.12):
    Generate iptables OUTPUT ACCEPT rule (if bidirectional tracking):
      -A ILLUMIO_OUTPUT -d 10.1.2.10 -p tcp --dport 8080 -j ACCEPT
      -A ILLUMIO_OUTPUT -d 10.1.2.11 -p tcp --dport 8080 -j ACCEPT

Step 3: Push to VEN
  PCE sends computed rules to each affected VEN via HTTPS
  VEN atomically replaces existing Illumio chains with new rules
```

**Label-to-IP caching:**
- PCE maintains an in-memory cache of label-to-workload-IP mappings
- Cache invalidated when workload IP changes, labels change, or workloads go offline
- Policy recomputation triggered automatically on any change

### Traffic Flow Telemetry

VEN agents summarize network flows and report to PCE. This is not full PCAP -- it is flow-level metadata:

**Flow record fields:**
- Source IP, destination IP
- Protocol, destination port
- Bytes transmitted (aggregated)
- Packets transmitted (aggregated)
- Flow direction (inbound/outbound)
- Policy decision (allowed/blocked/potentially_blocked)
- Service resolution (mapped to label if workload is known)

**Flow aggregation:**
- VEN aggregates flows over a 10-minute window before reporting to PCE
- High-frequency connections (e.g., web server handling thousands of requests) are summarized, not per-connection
- Prevents PCE storage from being overwhelmed on high-throughput workloads

**Flow storage:**
- PCE stores flows for 30 days (default, configurable)
- Explorer queries draw from this flow store
- Flows older than retention period are purged

## REST API

The PCE exposes a comprehensive REST API for all operations (automation, SIEM integration, SOAR response):

**API authentication:**
```bash
# Use API Key (recommended) or username:password
# Create API key in PCE UI: User Profile > API Keys
curl -X GET "https://pce.corp.local:8443/api/v2/orgs/1/workloads" \
  -u "api-user-id:api-secret" \
  -H "Accept: application/json"
```

**Common API operations:**
```bash
# List all workloads
GET /api/v2/orgs/{org_id}/workloads

# Get specific workload
GET /api/v2/orgs/{org_id}/workloads/{workload_id}

# Update workload labels
PUT /api/v2/orgs/{org_id}/workloads/{workload_id}
Body: {"labels": [{"href": "/orgs/1/labels/123"}, {"href": "/orgs/1/labels/456"}]}

# Apply enforcement boundary (via API)
POST /api/v2/orgs/{org_id}/sec_rules
Body: {"enabled": true, "consumers": [...], "providers": [...], "resolve_labels_as": {...}}

# Trigger policy provisioning (apply pending changes)
POST /api/v2/orgs/{org_id}/sec_policy/draft/provision
Body: {"change_subset": {"workloads": [...]}}

# Query traffic flows (Explorer via API)
GET /api/v2/orgs/{org_id}/traffic_flows/async_queries
```

**SOAR integration example -- quarantine a workload:**
```python
import requests

PCE_URL = "https://pce.corp.local:8443"
ORG_ID = "1"
API_KEY = "api-user-id:api-secret"

def quarantine_workload(workload_href):
    """Move workload to quarantine by adding quarantine label"""
    
    # Get current labels
    workload = requests.get(
        f"{PCE_URL}{workload_href}",
        auth=tuple(API_KEY.split(":")),
        headers={"Accept": "application/json"}
    ).json()
    
    current_labels = workload.get("labels", [])
    quarantine_label_href = "/orgs/1/labels/quarantine-label-id"
    
    # Add quarantine label, remove existing environment label
    new_labels = [l for l in current_labels if "environment" not in l.get("key", "")]
    new_labels.append({"href": quarantine_label_href})
    
    # Update workload
    requests.put(
        f"{PCE_URL}{workload_href}",
        auth=tuple(API_KEY.split(":")),
        json={"labels": new_labels}
    )
    
    # Provision changes
    requests.post(
        f"{PCE_URL}/api/v2/orgs/{ORG_ID}/sec_policy/draft/provision",
        auth=tuple(API_KEY.split(":")),
        json={"change_subset": {"workloads": [{"href": workload_href}]}}
    )
```

## Illumio Endpoint

Illumio Endpoint extends micro-segmentation to user laptops and desktops, not just servers.

**Difference from server VEN:**
- Handles roaming/mobile users (IP changes frequently)
- Integrates with user identity (Active Directory, Azure AD)
- Policy follows the USER identity, not just the device IP
- Works on or off corporate network

**Use cases:**
- Prevent lateral movement from compromised user devices
- Enforce segmentation for remote workers (VPN-less or VPN scenarios)
- Extend zero trust to user endpoints

**Identity-based policy example:**
```
Rule: Developer Workstations -> Dev Servers
  Consumer: User Group: AD:Developers | Device Role: Workstation
  Provider: Application:DevApps | Environment:Development
  Service: TCP/22 (SSH), TCP/3389 (RDP)
  Comment: "Developers can SSH/RDP to dev servers from their workstations"
```

## Scalability Reference

| Deployment Size | Workloads | PCE Nodes | Recommended VEN/PCE Ratio |
|---|---|---|---|
| Small | < 500 | 1 (standalone) | 500:1 |
| Medium | 500-5,000 | 3 (supercluster) | 2,000:1 per node |
| Large | 5,000-100,000 | 3-5 (supercluster) | 20,000-30,000:1 per node |
| Enterprise | 100,000+ | Distributed PCE | Regional PCE per 50K workloads |
