# Cloud Networking Concepts Reference

## Shared Responsibility Model for Networking

### Provider Responsibility

The cloud provider manages:
- Physical network infrastructure (routers, switches, cables, data center interconnects)
- Global backbone and inter-region connectivity
- DDoS protection at the network edge
- Virtual network overlay infrastructure
- API availability and control plane

### Customer Responsibility

The customer manages:
- VPC/VNet design and CIDR allocation
- Subnet architecture and routing
- Security groups, NACLs, NSGs, firewall rules
- Hybrid connectivity (VPN, Direct Connect, ExpressRoute, Interconnect)
- DNS configuration and resolution
- Application-level encryption (TLS)
- Network monitoring and flow log analysis

### Shared Responsibility

Both parties share:
- Encryption in transit (provider encrypts backbone; customer configures TLS)
- DDoS mitigation (provider absorbs volumetric; customer configures WAF rules)
- Patch management (provider patches infrastructure; customer patches NVAs)

## VPC Design Patterns

### Single VPC (Simple)

```
VPC (10.0.0.0/16)
  Public Subnet AZ-a (10.0.1.0/24)   -- IGW route
  Public Subnet AZ-b (10.0.2.0/24)   -- IGW route
  Private Subnet AZ-a (10.0.10.0/24) -- NAT GW route
  Private Subnet AZ-b (10.0.11.0/24) -- NAT GW route
  Data Subnet AZ-a (10.0.20.0/24)    -- No internet route
  Data Subnet AZ-b (10.0.21.0/24)    -- No internet route
```

Use when: Single application, small team, limited blast radius requirements.

### Multi-VPC Hub-and-Spoke

```
Hub VPC (Shared Services)
  |- Transit Gateway / vWAN Hub / NCC Hub
  |- Firewall / NAT / DNS
  |- VPN / Direct Connect termination

Spoke VPC: Production
Spoke VPC: Staging
Spoke VPC: Development
Spoke VPC: Shared Services (monitoring, logging, CI/CD)
```

Use when: Multiple environments or teams need isolation with shared connectivity.

### Multi-Account Landing Zone

```
Management Account
  |- Organization-level policies
  |- Centralized logging (CloudTrail, Config)

Network Account
  |- Transit Gateway / vWAN
  |- Direct Connect / ExpressRoute
  |- Centralized DNS

Production Account(s)
  |- Production VPCs attached to TGW
  |- Workload subnets

Non-Production Account(s)
  |- Dev/Staging VPCs
  |- Isolated from production via TGW route tables
```

Use when: Enterprise-scale deployments with team isolation, billing separation, and security boundaries.

## Subnet Design

### Subnet Sizing Guidelines

| Subnet Purpose | Recommended Size | Available IPs (AWS/Azure) | Notes |
|---|---|---|---|
| Public (load balancers, NAT GW) | /24 | 251 | Keep small, minimize public exposure |
| Private (application servers) | /22 - /24 | 251 - 1019 | Size based on expected instances |
| Data (databases, caches) | /24 | 251 | Limited instances, high isolation |
| Container/K8s pods | /20 - /18 | 4091 - 16379 | Pods consume IPs rapidly |
| Management (bastion, monitoring) | /26 - /24 | 59 - 251 | Small, tightly controlled |

### Reserved IP Addresses

**AWS** (5 per subnet): .0 network, .1 router, .2 DNS, .3 future, .255 broadcast
**Azure** (5 per subnet): .0 network, .1 gateway, .2-.3 DNS, .255 broadcast
**GCP** (4 per subnet): .0 network, .1 gateway, broadcast, reserved

### AZ Distribution

**AWS**: Subnets are AZ-scoped. Create matching subnets in at least 2 AZs for HA.
**Azure**: Subnets span all AZs in a region. AZ redundancy is achieved via zone-redundant resources.
**GCP**: Subnets are regional. VMs in different zones within the same subnet communicate directly.

## Hybrid Connectivity Fundamentals

### VPN vs Dedicated Line

| Aspect | VPN (IPsec) | Dedicated Line |
|---|---|---|
| Setup time | Minutes | Weeks to months |
| Bandwidth | 1-10 Gbps | 1-100 Gbps |
| Latency | Variable (internet path) | Consistent (private path) |
| Encryption | Always (IPsec) | Optional (MACsec on DX/ER) |
| Cost | Low (pay per hour) | High (port + cross-connect fees) |
| Redundancy | Easy (multiple tunnels) | Requires redundant circuits |
| Use case | Dev/test, low-bandwidth, backup | Production, latency-sensitive, high-bandwidth |

### BGP Design for Hybrid

- Use BGP for dynamic route exchange between on-premises and cloud
- Advertise summary routes from cloud to on-premises (avoid advertising individual /24s)
- Use AS-path prepending to influence traffic path across redundant connections
- Set BGP hold timers and BFD for fast failover
- Document AS numbers: on-prem ASN, cloud provider ASNs, private ASN ranges

### DNS in Hybrid Environments

- **Split-horizon DNS**: Same domain resolves differently inside the cloud vs on-premises
- **DNS forwarding**: Cloud VPCs forward specific zones to on-premises DNS servers
- **Private DNS zones**: Cloud-managed zones (Route 53 Private, Azure Private DNS, Cloud DNS) for private resolution
- **Conditional forwarding**: On-premises DNS servers forward cloud-specific zones to cloud DNS endpoints

## Security Groups vs ACLs

### Stateful Security (Security Groups / NSGs / GCP Firewall Rules)

- Track connection state: if outbound traffic is allowed, return traffic is automatically allowed
- Rules are "allow" only (AWS SG, GCP) or "allow/deny" (Azure NSG)
- Applied per instance/NIC (not per subnet)
- Can reference other security groups (AWS) or ASGs (Azure) as source/destination
- Easier to manage but less granular than stateless controls

### Stateless Security (NACLs)

- Every packet evaluated independently -- both directions must be explicitly allowed
- Numbered rules evaluated in order (first match wins)
- Applied per subnet (AWS only -- Azure and GCP do not have a direct equivalent)
- Support both allow and deny rules
- Use case: coarse subnet-level blocking (block specific source CIDRs, deny specific ports)

### Security Control Layering

```
Organization-level:  AWS SCPs / Azure Policy / GCP Org Policies
  |
Network-level:       AWS Network Firewall / Azure Firewall / Cloud Armor
  |
Subnet-level:        AWS NACLs / Azure NSG on subnet / GCP Hierarchical FW
  |
Instance-level:      AWS Security Groups / Azure NSG on NIC / GCP FW Rules (tags)
  |
Application-level:   Host firewall (iptables/Windows FW) / WAF rules
```

**Best practice**: Implement security at multiple layers. Do not rely solely on security groups.

## Transit Architecture Deep Dive

### AWS Transit Gateway

- Regional hub connecting VPCs, VPNs, and Direct Connect
- Up to 5,000 attachments per TGW
- Route tables enable segmentation (Dev, Prod, Shared)
- Inter-region: TGW peering (non-transitive, static routes only)
- Pricing: per-attachment per-hour + per-GB data processed

### Azure Virtual WAN

- Managed hub-and-spoke at scale
- Hub types: Basic (S2S VPN only), Standard (VPN + ER + P2S + Azure FW)
- Secured Virtual Hub: Standard hub with integrated Azure Firewall
- Routing intent: force all traffic through Azure Firewall
- Multi-hub across regions with automatic hub-to-hub routing

### GCP Network Connectivity Center

- Hub-and-spoke model for GCP and hybrid connectivity
- Spoke types: VPN tunnels, Interconnect VLANs, SD-WAN appliances, VPC networks
- VPC spokes enable transitive routing between VPCs via NCC hub
- PSC propagation: Private Service Connect endpoints accessible from all spokes
- Export filters control route propagation between spokes

## Private Service Access Comparison

| Aspect | AWS PrivateLink | Azure Private Link | GCP PSC |
|---|---|---|---|
| **Consumer** | Interface Endpoint (ENI) | Private Endpoint (NIC) | Consumer Endpoint (forwarding rule) |
| **Producer** | NLB-backed service | Standard LB-backed service | ILB-backed service |
| **DNS** | VPC-local resolution to private IP | Private DNS Zone | Service Directory integration |
| **Cross-account** | Yes | Yes | Yes (cross-project) |
| **Cross-region** | Yes (since 2023) | Yes | Yes |
| **For cloud services** | Gateway endpoints (S3/DDB) + Interface endpoints | Private endpoints for PaaS | PSC for Google APIs |
| **Cost** | Per-hour + per-GB | Per-hour + per-GB | Per-hour + per-GB |

## Flow Logs

### Comparison

| Aspect | AWS VPC Flow Logs | Azure NSG Flow Logs | GCP VPC Flow Logs |
|---|---|---|---|
| **Scope** | VPC, subnet, or ENI | NSG (subnet or NIC) | VPC, subnet, or VM |
| **Fields** | src/dst IP, ports, protocol, action, bytes | Similar + tuple hash | Similar + RTT samples |
| **Destination** | CloudWatch, S3, Firehose | Storage Account, Log Analytics | Cloud Logging, BigQuery, Pub/Sub |
| **Aggregation** | 10-min windows (default) | 1-min windows | 5-sec to 15-min configurable |
| **Sampling** | No sampling (all flows) | No sampling | Configurable sampling rate |
| **Cost concern** | Storage + query costs at scale | Storage + Log Analytics costs | Logging ingestion costs |

### Flow Log Use Cases

1. **Security forensics**: Identify unauthorized access attempts and lateral movement
2. **Traffic analysis**: Understand traffic patterns for network design optimization
3. **Cost optimization**: Identify high-volume flows for data transfer cost reduction
4. **Compliance**: Demonstrate network access controls are enforced
5. **Troubleshooting**: Confirm whether traffic is reaching/leaving an instance
