# Infoblox Architecture Reference

## NIOS (Network Identity Operating System)

NIOS is Infoblox's on-premises DDI operating system. Current major version: **NIOS 9.0** (9.0.1 through 9.0.6 as of April 2025). Runs on dedicated Infoblox hardware appliances, virtual appliances (VMware, KVM, Hyper-V, AWS, Azure, GCP), or cloud-based deployments.

---

## Grid Architecture Deep Dive

### Grid Master (GM)

The Grid Master is the single authoritative management node for the entire Infoblox Grid:

- Holds the **master copy** of all configuration data; distributes to all Grid Members
- Hosts the **Grid Manager GUI** (web-based management console)
- Hosts the **WAPI** (REST API) endpoint for automation
- All configuration changes must be made on the GM (or via WAPI on GM)
- Maintains the authoritative database for all DNS zones, DHCP scopes, IPAM records, and Grid configuration

### Grid Master Candidate (GMC)

- **Hot standby** for the Grid Master
- Receives continuous database replication from GM
- **Automatic promotion**: If GM becomes unreachable, GMC promotes to GM automatically (configurable failover threshold)
- After promotion, the former GM must be manually reset and re-joined as a Member or new GMC
- **Recommendation**: Always deploy at least one GMC in production; place it in a different physical location than the GM

### Grid Members

Grid Members are distributed service nodes deployed at branch offices, data centers, and cloud environments:

- Run DNS, DHCP, and/or IPAM services locally
- Receive configuration from GM via encrypted Grid replication protocol
- Service DNS and DHCP queries locally with low latency
- Upload lease data, DNS query logs, and health metrics to GM
- Can be assigned specific roles: DNS only, DHCP only, or combined
- **Physical appliance models**: IB-810 (branch), IB-1410 (medium), IB-2210 (large), IB-4030 (data center)
- **Virtual**: vNIOS on VMware, KVM, Hyper-V, AWS, Azure, GCP

### Reporting Members

- Dedicated Grid Member nodes for analytics, reporting, and log aggregation
- Offload reporting workload from service Members and GM
- Generate compliance reports, DNS activity reports, DHCP utilization trends
- Collect and index DNS query logs for forensic analysis
- Can run Infoblox reporting engine for custom dashboards

### Grid Replication Protocol

| Aspect | Detail |
|---|---|
| **Transport** | Proprietary protocol over TCP; encrypted |
| **Replication type** | Database-level (not DNS zone transfer) |
| **Incremental** | Delta replication for configuration changes |
| **Full sync** | On Member join or after extended disconnection |
| **Direction** | GM -> Members (configuration); Members -> GM (lease data, logs) |
| **Consistency** | All Members receive identical configuration within replication interval |

### Grid Deployment Topologies

**Single-site Grid:**
```
[GM] -- [GMC]
  |
  +-- [Member: DNS+DHCP]
  +-- [Member: DNS+DHCP]
```

**Multi-site Grid:**
```
HQ Site                    Branch Site A              Branch Site B
[GM] -- [GMC]              [Member: DNS+DHCP]         [Member: DNS+DHCP]
  |                              |                          |
  +-- [Member: DNS+DHCP]   Connected via WAN          Connected via WAN
  +-- [Reporting Member]
```

**Large Enterprise Grid:**
```
Primary DC                 Secondary DC               100+ Branch Sites
[GM]                       [GMC]                      [Member] x 100+
  |                          |
  +-- [Member] x 10         +-- [Member] x 10
  +-- [Reporting] x 2       +-- [Reporting] x 1
```

---

## WAPI (Web API) Deep Dive

### Authentication

| Method | Description |
|---|---|
| **HTTP Basic Auth** | Username:password per request; simplest but sends credentials each time |
| **Session cookie** | POST to `/wapi/v2.12/login` to get `ibapauth` cookie; reuse for subsequent calls |
| **Certificate auth** | Client certificate for service accounts; requires NIOS cert configuration |

### URL Structure

```
https://<grid-master>/wapi/v<version>/<object_type>[/<object_ref>][?<parameters>]
```

- **version**: 2.12, 2.13, etc. (tied to NIOS version)
- **object_type**: `network`, `record:host`, `zone_auth`, `lease`, etc.
- **object_ref**: Base64-encoded reference string (returned by WAPI on creation)

### Search Parameters

| Parameter | Description | Example |
|---|---|---|
| `field=value` | Exact match | `name=server01.corp.example.com` |
| `field~=regex` | Regex match | `name~=server.*corp` |
| `field<=value` | Less than or equal | `network<=10.0.0.0/16` (subnets within container) |
| `field>=value` | Greater than or equal | Used for range queries |
| `*field=value` | Case-insensitive match | `*name=SERVER01.CORP.EXAMPLE.COM` |

### Pagination

```bash
# First page
curl -k -u admin:pass "https://gm/wapi/v2.12/record:host?_max_results=100&_paging=1&_return_as_object=1"
# Response includes: "next_page_id": "abc123..."

# Subsequent pages
curl -k -u admin:pass "https://gm/wapi/v2.12/record:host?_page_id=abc123..."
```

### Advanced Operations

**Function calls (next available IP):**
```bash
# Next available IP from a network
POST /wapi/v2.12/network/ZG5z.../next_available_ip
{"num": 5, "exclude": ["10.1.1.1", "10.1.1.2"]}
```

**Scheduled tasks:**
```bash
# Schedule a CSV import
POST /wapi/v2.12/fileop?_function=uploadinit
# Upload CSV file
POST /wapi/v2.12/fileop?_function=csv_import
```

**Multi-object operations:**
```bash
# Request with _return_fields to get specific attributes
GET /wapi/v2.12/network?_return_fields=network,comment,extattrs&network=10.1.0.0/16
```

---

## BloxOne DDI Architecture

### Cloud-Native DDI

BloxOne DDI delivers DNS, DHCP, and IPAM as a SaaS service:

```
Infoblox Cloud (SaaS)
  -> BloxOne DDI Service (DNS, DHCP, IPAM)
  -> Cloud Services Portal (CSP) management UI
  -> BloxOne API (REST, OAuth2)
       |
       |  (Secure tunnel)
       v
On-Premises Data Connectors (OPDC)
  -> Lightweight agents on Linux VM or container
  -> Proxy DNS/DHCP traffic to cloud service
  -> Local caching for resilience
```

### Universal DDI (2025+)

Universal DDI is Infoblox's unified management strategy:

- **Single portal** for both NIOS Grid and BloxOne DDI
- Manage NIOS Grid Members directly from Infoblox Portal
- **Single API surface** for both on-prem and cloud DDI
- Migration path: existing NIOS customers can manage both platforms without rip-and-replace
- Gradual cloud transition: move workloads from Grid to BloxOne at your own pace

### BloxOne API

| Aspect | Detail |
|---|---|
| **Base URL** | `https://csp.infoblox.com/api/ddi/v1/` |
| **Auth** | API key (header: `Authorization: Token <key>`) |
| **Format** | JSON |
| **SDK** | Python SDK available (`bloxone` package) |
| **Rate limits** | Per-tenant; consult Infoblox documentation |

---

## BloxOne Threat Defense

### DNS Security Architecture

```
Client DNS query
  -> OPDC or BloxOne DNS resolver
  -> RPZ evaluation (threat feeds)
       |
       +-- Match: Block (NXDOMAIN) / Redirect (sinkhole) / Log
       +-- No match: Resolve normally
  -> DGA detection (ML model)
  -> DNS tunneling analysis (statistical)
  -> Response to client
```

### Threat Feed Categories

| Feed | Description |
|---|---|
| **Malware** | Known malware distribution domains |
| **Ransomware C2** | Command-and-control domains for ransomware variants |
| **Phishing** | Credential harvesting and social engineering domains |
| **DGA** | Algorithmically generated domains (ML detection) |
| **Data exfiltration** | Domains used for DNS tunneling exfiltration |
| **Suspicious** | Newly observed or low-reputation domains |

### PDNS (Passive DNS)

- Historical record of DNS resolutions observed across all BloxOne customers (anonymized)
- Query by domain or IP to see resolution history
- **Use cases**: Threat hunting, incident investigation, brand protection
- Retention: 12+ months of resolution history

---

## NetMRI Architecture

### Components

| Component | Role |
|---|---|
| **NetMRI Appliance** | Discovery, configuration backup, compliance engine |
| **Collectors** | Distributed probes for SNMP discovery and config collection |
| **Script Engine** | Perl/Python/CCS script execution against device fleet |
| **Policy Engine** | Rule-based compliance checking against device configurations |

### Capabilities

- **Device discovery** -- SNMP v2c/v3 polling; discovers routers, switches, firewalls, load balancers
- **Configuration backup** -- Scheduled config capture via SSH/SNMP; stores in version-controlled repository
- **Configuration diff** -- Compare current config against baseline; identify unauthorized changes
- **Compliance rules** -- Define policy rules (e.g., "NTP server must be 10.1.1.1"); evaluate against all devices
- **Automated remediation** -- Execute scripts to fix non-compliant configurations
- **Change approval** -- Workflow for configuration change authorization

---

## Performance and Scaling

### DNS Performance (NIOS)

| Appliance | Authoritative QPS | Recursive QPS |
|---|---|---|
| IB-810 | ~10,000 | ~5,000 |
| IB-1410 | ~50,000 | ~25,000 |
| IB-2210 | ~100,000 | ~50,000 |
| IB-4030 | ~200,000+ | ~100,000+ |
| vNIOS (8 vCPU) | ~50,000 | ~25,000 |

### Grid Scaling Limits

| Dimension | Guideline |
|---|---|
| **Grid Members** | Up to 2,000+ per Grid |
| **DNS zones** | 10,000+ zones per Grid |
| **DNS records** | Millions of records |
| **DHCP leases** | Millions of concurrent leases |
| **Networks (IPAM)** | 100,000+ managed networks |

### WAPI Performance

- Individual WAPI calls: 10-100ms typical latency
- Bulk operations: Use CSV import for 1,000+ objects
- Concurrent connections: Limit to 10-20 concurrent WAPI sessions per GM
- Rate limiting: NIOS may throttle at high request rates; implement exponential backoff

---

## Troubleshooting Quick Reference

### Grid Health

```bash
# Check Grid status (from GM CLI)
show status

# Check replication to members
show grid_replication

# Check DNS service status
show dns status

# Check DHCP service status
show dhcp status
```

### DNS Troubleshooting

```bash
# Test DNS resolution from NIOS
dig @<member-ip> server01.corp.example.com

# Check zone transfer status
show dns zone corp.example.com

# View RPZ hit log
show dns rpz-log
```

### DHCP Troubleshooting

```bash
# Check DHCP lease count
show dhcp lease_count

# Search lease by MAC
show dhcp lease hardware aa:bb:cc:dd:ee:ff

# Check failover status
show dhcp failover
```

### WAPI Troubleshooting

```bash
# Test WAPI connectivity
curl -k -u admin:password "https://gm.example.com/wapi/v2.12/?_schema"

# Get WAPI version
curl -k -u admin:password "https://gm.example.com/wapi/v2.12/?_schema&_schema_version=2"

# Check Grid member status via API
curl -k -u admin:password "https://gm.example.com/wapi/v2.12/member?_return_fields=host_name,service_status"
```
