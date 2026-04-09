# Cloud Networking Deep Dive: AWS VPC, Azure VNet, GCP VPC

## Overview

All three major cloud providers implement Software-Defined Networking (SDN) with virtual network constructs that abstract physical infrastructure. While conceptually similar (virtual networks, subnets, routing, firewall rules), each provider has distinct terminology, architectural constraints, and feature sets that require specific knowledge to design and operate effectively.

---

## AWS VPC (Virtual Private Cloud)

### VPC Design Fundamentals

A VPC is a logically isolated virtual network within an AWS region:
- **CIDR block**: IPv4 (RFC 1918 recommended) and optionally IPv6 (/56 prefix assigned by AWS)
- Multiple CIDRs can be associated with a single VPC (secondary CIDRs)
- VPCs are regional — they span all Availability Zones (AZs) in the region

**Subnets:**
- Subnets are AZ-scoped (each subnet lives in exactly one AZ)
- Public subnets: have a route to an Internet Gateway (IGW)
- Private subnets: no direct internet route; egress via NAT Gateway or Transit Gateway
- AWS reserves 5 IP addresses per subnet (.0 network, .1 router, .2 DNS, .3 future use, .255 broadcast)

### Route Tables

Each subnet is associated with a route table:
- **Main route table**: default for subnets without explicit association
- **Custom route tables**: assigned to specific subnets
- Routes: destination CIDR → target (igw-xxx, nat-xxx, tgw-xxx, vgw-xxx, local)
- `local` route always present — covers all traffic within the VPC CIDR

```
Destination     Target
10.0.0.0/16     local
0.0.0.0/0       igw-0abc123     (public subnet)
0.0.0.0/0       nat-0def456     (private subnet)
10.1.0.0/16     tgw-0ghi789     (route to Transit Gateway)
```

### Internet Gateway (IGW)

- Horizontally scaled, redundant, HA managed gateway
- Attached 1:1 to a VPC
- Provides NAT for instances with public IPs (Elastic IPs or auto-assigned public IPs)
- Required for public subnet internet access

### NAT Gateway

- Managed NAT service in a public subnet
- Provides outbound-only internet access for private subnet instances
- AZ-scoped: deploy one per AZ for high availability
- Pricing: per-hour + per-GB data processed
- Does not support inbound connections from internet

### Security Groups vs NACLs

**Security Groups:**
- Stateful packet filtering at the instance/ENI level
- Rules are "allow" only — implicit deny for anything not matched
- Inbound and outbound rules evaluated independently (but statefully — return traffic auto-allowed)
- Can reference other security groups as sources/destinations
- Applied per ENI — up to 5 security groups per ENI

**Network ACLs (NACLs):**
- Stateless packet filtering at the subnet level
- Rules are numbered and evaluated in order (lowest first); first match wins
- Both allow and deny rules supported
- Must explicitly allow return traffic (stateless)
- Applied to all traffic in/out of the subnet
- Default NACL: allows all inbound and outbound traffic

**Best practice**: Use Security Groups as primary access control; use NACLs for coarse subnet-level blocking (e.g., deny specific source CIDRs).

### Transit Gateway (TGW)

Transit Gateway is a regional network transit hub that interconnects VPCs, VPNs, and Direct Connect gateways:
- Supports up to 5,000 attachments
- Up to 100 Gbps per AZ
- **Route tables**: TGW has its own route tables; attachments are associated and can propagate routes
- **Hub-and-spoke**: Spoke VPCs connect to TGW; TGW routes between them
- **Full mesh**: all VPCs can communicate (route table allows)
- **Segmentation**: separate TGW route tables for isolated domains (Dev/Prod separation)
- **Inter-region peering**: TGWs in different regions can peer; non-transitive, static routes

```
TGW Route Table (Production):
Destination     Attachment
10.0.0.0/8      VPC-A, VPC-B, VPC-C
0.0.0.0/0       DX-Gateway
```

### VPC Peering

Direct, private connectivity between two VPCs:
- Non-transitive: A<->B and B<->C does not allow A<->C (use TGW for transitive)
- Works within a region or across regions (inter-region peering)
- No bandwidth limit (uses AWS backbone)
- Must add routes to both VPC route tables; Security Groups can reference peered VPC SGs (same region)
- Cannot peer VPCs with overlapping CIDR blocks

### PrivateLink and Interface Endpoints

**VPC Endpoints (Gateway type):**
- For S3 and DynamoDB only
- Free; routes to S3/DynamoDB remain within AWS network
- Added as route in route table

**Interface Endpoints (PrivateLink):**
- ENI with private IP in your subnet
- Enables private connectivity to AWS services (EC2 API, Secrets Manager, SSM, etc.) or third-party SaaS
- Traffic never leaves VPC or AWS network
- Supports DNS resolution: VPC-local DNS resolves the service endpoint to the ENI's private IP

**VPC Endpoint Services (PrivateLink for your own services):**
- Expose your NLB-backed service to other VPCs without VPC peering
- Consumer creates an Interface Endpoint; traffic goes to your NLB
- Cross-account and cross-region supported

### VPC Flow Logs

Capture metadata for all IP traffic through VPC, subnet, or ENI:
- Fields: srcaddr, dstaddr, srcport, dstport, protocol, packets, bytes, action (ACCEPT/REJECT), log-status
- Destinations: CloudWatch Logs, S3, Kinesis Data Firehose
- Not real-time (10-minute aggregation windows by default)
- Use for: security forensics, traffic analysis, cost optimization

### Direct Connect

Dedicated private network connection from on-premises to AWS:
- **Connection**: physical layer (1/10/100 Gbps)
- **Virtual Interface (VIF)**: logical connection (private VIF for VPC, public VIF for AWS services, transit VIF for TGW)
- **Direct Connect Gateway**: connect to VPCs in multiple regions from one Direct Connect connection
- **Hosted connection**: ordered through AWS Direct Connect partners (sub-1Gbps)
- SLA: 99.9% (single connection) / 99.99% (redundant connections in separate locations)

### VPN Gateway

- AWS-managed IPsec VPN endpoint
- Site-to-site VPN: connects on-premises to a VPC or TGW
- Supports IKEv1/v2, static routing or BGP (Dynamic)
- Bandwidth: ~1.25 Gbps per VPN tunnel (two tunnels per connection for HA)
- For higher throughput, use Direct Connect or TGW with multiple VPN attachments

### VPC Encryption Controls

All traffic on the AWS backbone is encrypted in transit at the physical layer. Additional controls:
- **TLS in transit**: standard practice; enforce via Security Groups (block port 80 if needed)
- **MACsec**: available on Direct Connect (10/100G dedicated connections); Layer 2 encryption over the dedicated link
- **VPN encryption**: AES-256 for site-to-site IPsec tunnels

---

## Azure VNet (Virtual Network)

### VNet Design

VNets are the fundamental network construct in Azure:
- Regional resource (spans all AZs in a region)
- Address space: one or more IPv4/IPv6 CIDR blocks
- Subnets: subdivide the VNet address space; AZ-aware subnet pinning not required but supported with zone-redundant resources

**Subnet considerations:**
- Azure reserves 5 IPs per subnet (.0 network, .1 default gateway, .2-.3 DNS, .255 broadcast)
- Dedicated subnets required for some services: AzureFirewallSubnet, GatewaySubnet, AzureBastionSubnet

### NSGs (Network Security Groups)

Stateful packet filtering at subnet and NIC level:
- Inbound and outbound security rules: Priority (100-4096), Source/Dest (IP, CIDR, Service Tag, ASG), Protocol, Port, Action (Allow/Deny)
- **Service Tags**: pre-defined IP ranges for Azure services (AzureCloud, Internet, VirtualNetwork, etc.) — updated automatically
- **Default rules**: allow VNet-to-VNet and Azure Load Balancer traffic; deny all internet inbound
- NSGs can be associated with subnets and NICs independently

### ASGs (Application Security Groups)

ASGs allow grouping of VMs into logical application roles and using those groups in NSG rules:
- Define ASGs: WebServers, AppServers, DBServers
- Apply NSG rules: Allow WebServers → AppServers:8080, Allow AppServers → DBServers:1433
- VMs are assigned to ASGs via their NIC configuration
- Eliminates the need to manage IP addresses in security rules

### Azure Firewall

Azure Firewall is a managed, stateful firewall service:
- Deployed in a dedicated subnet (AzureFirewallSubnet /26 minimum)
- Force-tunnel outbound traffic from all subnets via User Defined Routes (UDRs)

**Azure Firewall Premium features:**
- **TLS inspection**: decrypt/inspect/re-encrypt HTTPS traffic (requires CA certificate deployment)
- **IDPS (Intrusion Detection and Prevention)**: signature-based threat detection with Alert+Deny modes; 58,000+ signatures
- **URL filtering**: full URL path filtering (not just FQDN) for HTTPS
- **Web categories**: block/allow web traffic by category (social, gambling, productivity)
- **Threat intelligence**: Deny known malicious IPs/FQDNs (Microsoft Threat Intelligence feed)
- Standard vs Premium: Premium adds TLS inspection, IDPS, URL filtering, web categories

### Virtual WAN (vWAN)

Azure Virtual WAN provides a managed hub-and-spoke network architecture at scale:

**Hub types:**
- **Basic hub**: S2S VPN only
- **Standard hub**: VPN + ExpressRoute + P2S + Azure Firewall (Secured Hub)

**Features:**
- Any-to-any connectivity: Branch-to-VNet, VNet-to-VNet, Branch-to-Branch (via hub)
- Routing policies: push traffic through Azure Firewall or third-party NVA
- **Secured Virtual Hub**: Standard hub + Azure Firewall integrated in hub
- **BGP route propagation**: automatic route exchange between connections
- Scale: multiple hubs per vWAN across regions; hub-to-hub peering for inter-region

**Note on Azure Firewall Premium in vWAN:** Secured Virtual Hubs support Azure Firewall Standard; for Firewall Premium, deploy in a spoke VNet connected to the hub.

### ExpressRoute

Dedicated private connectivity from on-premises to Azure:
- **Circuit**: ordered through connectivity providers (AT&T, Equinix, etc.); 50 Mbps to 100 Gbps
- **Peering types**: Azure Private (VNet), Azure Microsoft (public endpoints), (deprecated: Azure Public)
- **ExpressRoute Gateway**: deployed in GatewaySubnet; connects VNet to ExpressRoute circuit
- **Global Reach**: connect two on-premises sites via Azure ExpressRoute backbone
- **FastPath**: bypasses ExpressRoute Gateway for data plane traffic (lower latency, higher throughput) — requires Ultra Performance or ErGw3AZ gateway SKU

### VPN Gateway

Azure VPN Gateway supports:
- **Site-to-site (S2S)**: IPsec/IKE to on-premises VPN devices
- **Point-to-site (P2S)**: remote user VPN (OpenVPN, IKEv2, SSTP)
- **VNet-to-VNet**: VPN-encrypted cross-region connectivity
- Gateway SKUs: Basic (deprecated) → VpnGw1-5 (1-10 Gbps aggregate); VpnGw1-5AZ for zone-redundancy

### VNet Peering

Direct, private connectivity between VNets:
- **Local peering**: same region, low latency
- **Global peering**: cross-region over Microsoft backbone
- Non-transitive by default; use Route Server or Network Virtual Appliance for transitivity
- Allow forwarded traffic / gateway transit options for spoke VNets sharing hub gateway

### Azure Route Server

Enables dynamic route exchange between NVAs and Azure network:
- NVA establishes BGP session with Route Server
- Routes learned from NVA propagated to all peered VNets
- Enables transit routing through NVAs without UDR maintenance
- Supports branch-to-branch via NVA with ECMP

### Private Link

Azure Private Link provides private connectivity to PaaS services and customer-owned services:
- **Private Endpoint**: NIC with private IP in your VNet pointing to a PaaS service (Storage, SQL, Key Vault, etc.)
- DNS override: Private DNS zone maps service FQDN to private endpoint IP
- **Private Link Service**: expose your Standard Load Balancer-backed service to other VNets

### Front Door and Application Gateway

- **Azure Front Door**: global layer 7 load balancer + CDN + WAF; routes users to nearest regional backend
- **Application Gateway**: regional layer 7 load balancer with WAF; SSL termination, URL routing, autoscaling

---

## GCP VPC (Virtual Private Cloud)

### Global VPC Architecture

GCP's VPC is fundamentally different from AWS and Azure — it is **global by default**:
- A single VPC spans all GCP regions simultaneously
- Subnets are regional resources (not AZ-scoped)
- VMs in different regions within the same VPC can communicate privately without peering or additional configuration
- This simplifies multi-region architectures significantly

### Subnets

Regional subnets with IPv4 (and optional IPv6 /64) CIDR:
- Primary IP range: for VM instances
- Secondary IP ranges: for Kubernetes pods and services (alias IPs)
- Auto-mode VPC: creates subnets automatically in every region (10.128.0.0/9 space); good for simple deployments
- Custom mode VPC: administrator controls all subnet creation; recommended for production

### Firewall Rules

GCP VPC has two tiers of firewall rules:

**VPC Firewall Rules:**
- Applied to instances based on target (all instances, tags, service account)
- Stateful (like AWS Security Groups)
- Priority (0-65535); lower number = higher priority
- Direction: ingress or egress
- Default VPC has default-allow-internal and default-allow-ssh/rdp/icmp rules

**Hierarchical Firewall Policies (Organization/Folder level):**
- Evaluated before VPC firewall rules
- Consistent policies across projects
- Actions: allow, deny, goto-next (delegate to VPC rules)
- Enables centralized security governance for multi-project organizations

### Cloud NAT

Managed NAT service for private instances:
- Regional; one per region per VPC (or per subnet)
- Does not require a dedicated NAT VM — fully managed
- Scales automatically
- Supports logging for NAT translation events
- Configure minimum/maximum ports per VM instance

### Cloud Armor

GCP's WAF and DDoS protection service:
- **Layer 7 DDoS protection**: absorbs large-scale volumetric attacks (Google's global infrastructure)
- **WAF rules**: OWASP Core Rule Set (CRS), pre-configured rule groups (SQLi, XSS, LFI, RFI)
- **Custom rules**: CEL (Common Expression Language) for flexible matching
- **Adaptive Protection**: ML-based detection of L7 DDoS attacks; auto-generates mitigation rules
- **Edge security policy**: applied at global load balancer (Cloud CDN, External HTTP(S) LB)
- **Rate limiting**: per-IP or per-region request rate limiting with configurable throttle/ban actions

### Cloud Interconnect

Dedicated connectivity from on-premises to GCP:
- **Dedicated Interconnect**: 10/100 Gbps physical connections at colocation facilities
- **Partner Interconnect**: 50 Mbps to 10 Gbps via connectivity partner
- VLAN attachments connect to Cloud Routers in specific regions
- SLA: 99.9% (single interconnect) / 99.99% (redundant interconnects in separate metro areas)

### Cloud VPN

IPsec-based VPN connectivity:
- **Classic VPN**: single interface; 3 Gbps max; static or dynamic routing
- **HA VPN**: two interfaces for 99.99% SLA; dynamic routing (BGP required); each tunnel up to 3 Gbps
- HA VPN to AWS: requires two customer gateways + two VPN connections (4 tunnels total for full redundancy)

### Shared VPC

Shared VPC allows a single host project VPC to be shared with service projects:
- **Host project**: owns the VPC; controls subnets
- **Service projects**: VMs deployed in shared subnets; billed to service project
- Centralizes network administration while distributing compute resource ownership
- Ideal for: centralized network team with distributed application teams in separate projects

### VPC Service Controls

VPC Service Controls create security perimeters around GCP APIs:
- Define a perimeter: which projects, which services (Cloud Storage, BigQuery, etc.) are inside
- Traffic inside the perimeter can access protected services
- Traffic from outside (including internet, even with valid credentials) is blocked
- Bridges: allow controlled access between perimeters
- Audit mode: log violations without blocking (for testing)
- Use case: prevent data exfiltration from sensitive projects

### Network Connectivity Center (NCC)

NCC is GCP's managed hub-and-spoke connectivity solution:
- **Hub**: central network resource; owns the topology
- **Spokes**: VPN tunnels, Dedicated Interconnect VLANs, SD-WAN appliances, or VPC networks
- Spoke VPCs can communicate transitively via the NCC hub
- **PSC propagation (2025)**: Private Service Connect endpoints in spoke VPCs are accessible from all other spokes via the NCC hub — eliminates per-spoke PSC endpoint duplication
- **Export filters**: control which routes are exported from each spoke

### Private Service Connect (PSC)

PSC enables private access to Google-managed services and producer services:
- **Consumer endpoint**: forwarding rule with private IP in consumer VPC
- **Producer service attachment**: NLB backend in producer VPC
- **PSC for Google APIs**: access Google APIs (Storage, BigQuery, etc.) via private IP without public IPs
- **PSC via NCC (2025)**: PSC connections propagate through NCC hub to all connected spokes — single endpoint accessible from multiple VPCs

### Cloud Router and BGP

Cloud Router manages dynamic routing:
- Regional resource; manages BGP sessions for Interconnect VLANs and HA VPN tunnels
- Learns routes from on-premises and advertises GCP subnet ranges
- **Custom route advertisements**: advertise summary routes or specific prefixes to on-premises
- **Route policies**: filter routes learned from and advertised to BGP peers
- Integrates with NCC for centralized routing

---

## Cross-Cloud Patterns

### Multi-Cloud Connectivity

| Connection Type | AWS | Azure | GCP |
|---|---|---|---|
| Dedicated line | Direct Connect | ExpressRoute | Cloud Interconnect |
| IPsec VPN | VPN Gateway | VPN Gateway | HA VPN / Classic VPN |
| Transit hub | Transit Gateway | Virtual WAN | Network Connectivity Center |
| Private service access | PrivateLink | Private Link | Private Service Connect |
| WAF/DDoS | AWS Shield + WAF | Azure Firewall + DDoS Protection | Cloud Armor |

### Design Principles

1. **CIDR planning**: allocate non-overlapping address spaces across all cloud environments — overlapping CIDRs prevent VPC peering and complicate routing
2. **Hub-and-spoke**: use TGW (AWS), vWAN (Azure), or NCC (GCP) as central transit hubs for multi-VPC environments
3. **Private service access**: prefer PrivateLink/Private Link/PSC over VPC peering for service exposure — reduces blast radius
4. **Egress control**: centralize internet egress through NAT Gateways (AWS), Azure Firewall (Azure), or Cloud NAT (GCP) for consistent logging and filtering
5. **Security group / NSG hygiene**: avoid overly permissive rules; use service tags and ASGs for maintainability
