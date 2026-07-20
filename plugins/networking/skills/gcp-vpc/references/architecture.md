# GCP VPC Architecture Reference

## Global VPC Internals

### Andromeda Virtual Network

GCP networking runs on Andromeda, Google's software-defined networking platform:
- Distributed across all physical hosts in all regions
- Implements virtual networking (VPC, firewall rules, load balancing) in the hypervisor
- No dedicated network appliances for L2/L3 forwarding -- all distributed
- Encryption in transit between data centers (always on, no configuration needed)

### VPC Network Object

- Global resource: spans all GCP regions
- Contains subnets (regional), firewall rules (global), routes (global)
- Each VPC has a default route to the internet gateway (0.0.0.0/0)
- VPC routing is fully distributed -- no centralized routing bottleneck

### Routing

GCP VPC has two types of routes:
- **Subnet routes**: Auto-created for each subnet CIDR. Non-deletable.
- **Custom routes**: Static routes or dynamic routes from Cloud Router (BGP)

Route selection: most-specific prefix match (longest prefix), then by priority.

### Internal DNS

- Each VM gets a hostname resolvable within the VPC: `<vm-name>.<zone>.c.<project>.internal`
- Zonal DNS: resolves to the VM's primary internal IP
- Private zones in Cloud DNS for custom internal domains
- DNS peering: forward DNS queries between VPCs without VPC peering

## Shared VPC Architecture

### Organization Structure

```
Organization
  |- Folder: Networking
  |    |- Host Project (owns the Shared VPC)
  |         |- Shared VPC network
  |         |- Subnets (regional)
  |         |- Firewall rules
  |         |- Cloud NAT, Cloud Router, Interconnect
  |
  |- Folder: Production
  |    |- Service Project A (uses Shared VPC subnets)
  |    |- Service Project B
  |
  |- Folder: Development
       |- Service Project C (uses Shared VPC subnets)
```

### Shared VPC Constraints

- One host project per Shared VPC network
- A service project can only be associated with one host project
- Max 100 service projects per host project (default, adjustable)
- Firewall rules are managed in the host project only
- Service project admins cannot create or modify firewall rules

### Cross-Project Networking

Resources in service projects use subnets from the host project:
- VMs: specify the Shared VPC subnet during creation
- GKE: node pools and pods use Shared VPC subnets (secondary ranges for pods/services)
- Cloud SQL: Private IP connects to Shared VPC via private service access
- Cloud Run: Serverless VPC Connector in Shared VPC subnet

## Network Connectivity Center (NCC) Architecture

### Hub-and-Spoke Model

```
NCC Hub
  |- Spoke: HA VPN to on-prem (us-central1)
  |- Spoke: Interconnect to DC-A (us-east1)
  |- Spoke: VPC-Prod (global)
  |- Spoke: VPC-Dev (global)
  |- Spoke: SD-WAN appliance (us-west1)
```

### Transitive Routing

- VPC spokes can communicate transitively through the NCC hub
- Before NCC: VPC peering was non-transitive (A<->Hub, B<->Hub does not allow A<->B)
- With NCC: all spokes can reach each other via the hub
- Export filters control which routes are propagated between spokes

### NCC Routing

- Routes from each spoke are imported into the NCC hub routing table
- Hub distributes routes to all other spokes (subject to export filters)
- BGP routes from VPN/Interconnect spokes propagated to VPC spokes
- VPC subnet routes propagated to VPN/Interconnect spokes (advertised to on-prem)

### PSC Propagation via NCC

- PSC endpoints in one spoke VPC accessible from all other spoke VPCs
- Single PSC endpoint serves the entire NCC topology
- Reduces management: no need to create PSC endpoints in every VPC
- Route to PSC endpoint injected into all spoke VPC routing tables

## Cloud Interconnect Architecture

### Dedicated Interconnect Internals

```
Customer Router (BGP AS 65001)
  |-- Physical Cross-Connect (10G/100G)
  |
Google Peering Edge Router
  |-- VLAN Attachment (802.1Q tagged)
  |
Cloud Router (BGP AS 16550 or custom)
  |-- Distributes routes to VPC subnets
```

### VLAN Attachment

- Logical connection over the physical Interconnect
- Each VLAN attachment connects to one Cloud Router in one region
- Multiple VLAN attachments per Interconnect for multi-region access
- Each attachment has its own BGP session with the Cloud Router
- Bandwidth: configurable from 50 Mbps to 50 Gbps per attachment

### Redundancy Models

**99.9% SLA (single metro):**
```
2 Interconnects in same metro, different edge availability domains
4 VLAN attachments (2 per Interconnect)
2 Cloud Routers (one per Interconnect)
```

**99.99% SLA (two metros):**
```
2 Interconnects in Metro-A (different EADs)
2 Interconnects in Metro-B (different EADs)
4 Cloud Routers (one per Interconnect)
8 VLAN attachments (2 per Interconnect)
```

### Cloud Router BGP

- Regional resource managing BGP sessions
- Learns routes from on-premises via Interconnect/VPN
- Advertises GCP subnet routes to on-premises
- Custom route advertisements: override default subnet advertisements with summary routes
- Route policies: filter and modify learned/advertised routes (AS-path prepend, community filtering)

```bash
# Custom route advertisement
gcloud compute routers update my-router \
  --region=us-central1 \
  --advertisement-mode=CUSTOM \
  --set-advertisement-groups=ALL_SUBNETS \
  --set-advertisement-ranges=10.0.0.0/8
```

## Cloud Armor Architecture

### Traffic Flow

```
Client -> Google Front End (GFE) -> Cloud Armor Policy -> Backend Service -> VM/GKE/Serverless
```

- Cloud Armor evaluates at the Google Front End (edge POP closest to client)
- DDoS traffic absorbed before reaching customer infrastructure
- WAF rules evaluated per HTTP request
- Allowed traffic forwarded to backend service

### Preconfigured WAF Rules

| Rule Set | Description |
|---|---|
| `sqli-v33-stable` | SQL injection protection (OWASP CRS 3.3) |
| `xss-v33-stable` | Cross-site scripting protection |
| `lfi-v33-stable` | Local file inclusion protection |
| `rfi-v33-stable` | Remote file inclusion protection |
| `rce-v33-stable` | Remote code execution protection |
| `methodenforcement-v33-stable` | HTTP method enforcement |
| `scannerdetection-v33-stable` | Scanner and probe detection |
| `protocolattack-v33-stable` | Protocol attack protection |
| `java-v33-stable` | Java-specific attack protection |
| `nodejs-v33-stable` | Node.js-specific attack protection |

### Custom Rules with CEL

Cloud Armor uses Common Expression Language (CEL) for custom rules:

```
# Block specific country
origin.region_code == "XX"

# Block user-agent pattern
request.headers['user-agent'].contains('BadBot')

# Rate limit by IP and path
request.path.startsWith('/api/') && origin.ip != '10.0.0.1'

# Geo-based allow
origin.region_code in ['US', 'CA', 'GB']
```

### Adaptive Protection

- ML model trained on baseline traffic patterns per backend service
- Detects anomalies: unusual request rates, geographic shifts, header patterns
- Generates mitigation rules with confidence scores
- Admin reviews and deploys suggested rules
- Alert-only mode available (monitor without auto-blocking)

## VPC Service Controls Architecture

### Perimeter Model

```
Outside Perimeter                    Inside Perimeter
  |- Developer laptop               |- Project-A (Storage, BigQuery)
  |- CI/CD pipeline                 |- Project-B (Cloud SQL)
  |- Partner API client             |- Project-C (GKE workloads)
                                    
  Blocked by default                Full access between projects
  (even with valid IAM credentials) inside the perimeter
```

### Access Levels

Define conditions under which outside entities can access perimeter resources:
- IP address ranges (corporate egress IPs)
- Device attributes (corporate-managed devices via BeyondCorp)
- Geographic location
- Combination of conditions (AND/OR logic)

### Ingress/Egress Policies

Fine-grained exceptions to the perimeter:
- **Ingress policy**: Allow specific identities from outside to access specific services inside
- **Egress policy**: Allow specific identities inside to access specific services outside
- Granularity: per-identity, per-service, per-method

```yaml
# Ingress policy: Allow CI/CD pipeline to deploy
ingressPolicies:
  - ingressFrom:
      identities:
        - serviceAccount:cicd-sa@cicd-project.iam.gserviceaccount.com
      sources:
        - accessLevel: accessPolicies/123/accessLevels/corporate-network
    ingressTo:
      operations:
        - serviceName: storage.googleapis.com
          methodSelectors:
            - method: google.storage.objects.create
      resources:
        - projects/prod-project
```

### Dry Run Mode

- Evaluate perimeter rules without enforcing
- Violations logged to Cloud Audit Logs
- Use for: testing new perimeters, validating access levels, identifying legitimate traffic that would be blocked
- Best practice: always run in dry-run mode for 2+ weeks before enforcing

## Private Service Connect Architecture

### PSC for Google APIs

```
VM (10.0.1.10)
  |-- Route to PSC endpoint IP (10.0.1.100)
  |
PSC Endpoint (10.0.1.100)
  |-- Forwarding rule -> Google APIs bundle
  |
Google API (storage.googleapis.com)
  |-- Request arrives from PSC endpoint IP, not VM IP
```

- VM traffic to Google APIs routed to the PSC endpoint IP (private, in-VPC)
- No external IP required on the VM
- DNS configuration: map `*.googleapis.com` to the PSC endpoint IP
- Supports `all-apis` (all Google APIs) or `vpc-sc` (VPC Service Controls compatible APIs)

### PSC for Published Services (Producer/Consumer)

```
Producer Project                    Consumer Project
  ILB (10.10.1.5)                    PSC Endpoint (10.0.1.200)
    |                                    |
  Service Attachment  <-- PSC -->  Forwarding Rule
    |                                    |
  Backend VMs                        Consumer VM uses 10.0.1.200
```

- Producer publishes a service attachment pointing to an ILB
- Consumer creates a PSC endpoint in their VPC
- Traffic flows privately over Google's network
- NAT applied: producer sees PSC NAT subnet IP, not consumer's IP
- Approval: automatic or manual per-project

### PSC vs VPC Peering

| Aspect | PSC | VPC Peering |
|---|---|---|
| Blast radius | Single service endpoint | Full network connectivity |
| Route exchange | No route exchange | Full subnet route exchange |
| Overlapping CIDRs | Supported | Not supported |
| Scalability | Per-service | Full mesh complexity |
| Security | Service-level isolation | Network-level connectivity |
| Best for | Service-to-service access | Trusted, full-network integration |

## VPC Flow Logs

### Configuration

```bash
gcloud compute networks subnets update app-subnet \
  --region=us-central1 \
  --enable-flow-logs \
  --logging-aggregation-interval=interval-5-sec \
  --logging-flow-sampling=1.0 \
  --logging-metadata=include-all
```

### Log Fields

| Field | Description |
|---|---|
| `connection.src_ip` | Source IP |
| `connection.dest_ip` | Destination IP |
| `connection.src_port` | Source port |
| `connection.dest_port` | Destination port |
| `connection.protocol` | Protocol number |
| `bytes_sent` | Bytes in the reported direction |
| `packets_sent` | Packets in the reported direction |
| `start_time` / `end_time` | Flow timing |
| `reporter` | SRC or DEST (which endpoint reported) |
| `src_instance` / `dest_instance` | VM name and project |
| `src_vpc` / `dest_vpc` | VPC network name |
| `rtt_msec` | Round-trip time sample (GCP-unique field) |

### Destinations

- Cloud Logging (default)
- BigQuery (recommended for large-scale analysis)
- Pub/Sub (for real-time streaming to SIEM/SOAR)
- Cloud Storage (for archival)

### Cost Management

Flow Logs can generate significant log volume:
- Use sampling rate < 1.0 for high-volume subnets (e.g., 0.5 = 50% sampling)
- Increase aggregation interval (5-sec to 15-min) to reduce log entries
- Use log exclusion filters to drop non-essential flows
- Route to BigQuery for cost-effective long-term analysis
