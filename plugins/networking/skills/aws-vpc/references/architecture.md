# AWS VPC Architecture Reference

## VPC Internals

### VPC Data Plane

- VPC is a software-defined network overlay running on AWS's physical infrastructure
- Each VPC has an implicit router that handles all routing decisions
- The implicit router is not visible or configurable -- it executes route table rules
- All traffic within a VPC is encrypted in transit at the physical layer (AWS Nitro)

### ENI (Elastic Network Interface)

Every instance, Lambda VPC, and AWS managed service uses ENIs:
- ENI has a primary private IP, optional secondary IPs, and optional Elastic IP
- Security Groups are attached to ENIs (not instances)
- ENIs are AZ-scoped (cannot move cross-AZ)
- An instance can have multiple ENIs (multi-homed)
- ENI source/destination check: enabled by default, must be disabled for NAT/NVA instances

### Elastic IP (EIP)

- Static public IPv4 address that can be associated with an ENI
- Persists across instance stop/start (unlike auto-assigned public IPs)
- AWS charges for EIPs not associated with a running instance
- Limited to 5 per region by default (request increase)

## Transit Gateway Architecture

### TGW Internals

- TGW creates an ENI in each AZ of each attached VPC (in the TGW attachment subnet)
- Traffic from a VPC enters TGW via the TGW ENI in the same AZ
- TGW route lookup determines the destination attachment
- Traffic exits via the TGW ENI in the destination VPC's AZ

### TGW Route Table Processing

```
1. Packet arrives at TGW from source attachment
2. TGW identifies the associated route table for the source attachment
3. Longest-prefix match on destination IP in the route table
4. Forward to the target attachment
5. If no match, packet is dropped (no default route unless explicitly configured)
```

### TGW Multicast

- TGW supports IGMPv2 multicast
- Multicast domain: group of TGW attachments that can exchange multicast traffic
- Static source configuration or IGMP-based dynamic membership
- Use case: financial data feeds, live video distribution

### TGW Connect

- Attach SD-WAN or third-party NVAs to TGW via GRE tunnels
- Higher bandwidth than VPN (up to 20 Gbps per Connect attachment)
- BGP peering between NVA and TGW over GRE tunnel
- Use case: integrate Cisco SD-WAN, Palo Alto Prisma, or similar with TGW

## Direct Connect Architecture

### Physical Layer

```
Customer Router <--Cross-Connect--> DX Partner/Location Router <--AWS Backbone--> AWS Region
```

- Dedicated connection: customer owns the port (1/10/100 Gbps)
- Hosted connection: partner provisions a sub-rate connection (50 Mbps - 10 Gbps)
- LAG: Link Aggregation Group of up to 4 connections at a single DX location

### Virtual Interface Details

**Private VIF:**
- Connects to a VGW (Virtual Private Gateway) in a single VPC, or DX Gateway for multi-VPC
- BGP peering: customer AS <-> AWS AS (default 64512)
- Advertises VPC CIDR to customer; customer advertises on-prem routes to AWS
- Supports jumbo frames (9001 MTU) for private VIFs

**Transit VIF:**
- Connects to TGW via DX Gateway
- Supports up to 3 TGW attachments per DX Gateway
- Enables transitive routing to all TGW-attached VPCs
- BGP communities for route prioritization across multiple DX connections

**Public VIF:**
- Access AWS public endpoints (S3, DynamoDB, etc.) over private connection
- Customer must advertise public IP prefixes (verified by AWS)
- AWS advertises its public IP ranges to customer

### DX Gateway

- Global resource (not region-specific)
- Associates with VGWs in multiple regions (Private VIF) or TGWs (Transit VIF)
- Does NOT provide transitive routing between attached VGWs/TGWs
- Single DX connection -> DX Gateway -> VPCs in multiple regions

### Failover Design

**Two-connection HA (99.99% SLA):**
```
Connection-1 (DX Location A) -> DX Gateway -> TGW
Connection-2 (DX Location B) -> DX Gateway -> TGW
BGP: Primary path via Connection-1 (shorter AS-path)
     Backup path via Connection-2 (AS-path prepend)
```

**DX + VPN backup:**
```
Primary: DX Connection -> DX Gateway -> TGW
Backup:  IPsec VPN -> TGW
BGP: DX path preferred (lower MED/AS-path)
     VPN path used only when DX is down
```

## PrivateLink Implementation

### Interface Endpoint Internals

```
Consumer VPC                              AWS Service / Provider VPC
  [App Instance]                            [NLB -> Service Instances]
       |                                          |
  [SG] -> [ENI (pvt IP: 10.0.1.50)]  ====  [Endpoint Service]
       |
  [Private DNS: svc.us-east-1.vpce.amazonaws.com -> 10.0.1.50]
```

- ENI placed in consumer's subnet with a private IP from the subnet CIDR
- Security Group on the ENI controls who can access the endpoint
- Private DNS: AWS creates a Route 53 private hosted zone mapping the service FQDN to the ENI IP
- Traffic never leaves the AWS network

### Gateway Endpoint Internals

- No ENI -- implemented as a route in the route table
- Route points to a prefix list (AWS-managed IP ranges for S3 or DynamoDB)
- VPC endpoint policy controls which S3 buckets/DynamoDB tables are accessible
- Free -- no hourly or data processing charges

## VPN Architecture

### Site-to-Site VPN

```
Customer Gateway (on-prem) <-- 2 IPsec tunnels --> VPN Gateway (AWS)
                                                     |
                                                   VGW or TGW
```

- Two tunnels per VPN connection for HA (each tunnel terminates on a different AWS endpoint)
- IKEv1 or IKEv2 with AES-256 encryption
- BGP (dynamic routing) or static routing
- ~1.25 Gbps per tunnel; use ECMP across multiple tunnels for higher throughput
- Accelerated Site-to-Site VPN: uses AWS Global Accelerator for optimized internet path

### VPN + TGW

- VPN attachment to TGW enables transitive routing
- ECMP across multiple VPN connections to TGW (up to 50 Gbps aggregate)
- BGP route propagation from VPN to TGW route tables

## AWS Network Firewall

### Architecture

```
VPC (Inspection)
  Firewall Subnet AZ-a: Network Firewall endpoint
  Firewall Subnet AZ-b: Network Firewall endpoint

TGW -> Inspection VPC -> Network Firewall -> TGW -> Destination VPC
```

### Rule Groups

- **Stateless rules**: Evaluated on every packet (5-tuple match). Actions: pass, drop, forward to stateful engine.
- **Stateful rules**: Connection-tracked inspection. Supports Suricata-compatible rules.
  - Domain filtering (allow/deny by FQDN)
  - TLS SNI inspection (filter HTTPS by server name without decryption)
  - IPS signatures (Suricata format)

### Deployment Patterns

**Centralized inspection (TGW):**
- All inter-VPC and internet-bound traffic routes through Inspection VPC
- TGW appliance mode enabled for symmetric routing
- Network Firewall in Inspection VPC inspects all traffic

**Distributed inspection (per-VPC):**
- Network Firewall deployed in each VPC
- Internet-bound traffic routed through local firewall
- No TGW required for inspection (but higher cost -- per-VPC firewall)

## VPC Peering

### Implementation

- Direct private connectivity using AWS backbone
- No bandwidth limit, no single point of failure
- Both VPCs must add routes pointing to the peering connection
- Security Groups can reference peered VPC SGs (same region only)
- No transitive routing: A<->B and B<->C does not allow A<->C

### Peering vs TGW

| Aspect | VPC Peering | Transit Gateway |
|---|---|---|
| Transitive routing | No | Yes |
| Max connections | 125 per VPC | 5,000 per TGW |
| Cost | Free (data transfer only) | Per-attachment + data processing |
| Bandwidth | No limit | 50 Gbps burst per attachment |
| Complexity | O(n^2) for full mesh | O(n) hub-and-spoke |
| Best for | Few VPCs, low cost | Many VPCs, centralized control |

## Service Limits (Key Defaults)

| Resource | Default Limit | Adjustable |
|---|---|---|
| VPCs per region | 5 | Yes (up to 100+) |
| Subnets per VPC | 200 | Yes |
| Route tables per VPC | 200 | Yes |
| Routes per route table | 50 | Yes (up to 1000) |
| Security Groups per VPC | 2500 | Yes |
| Rules per Security Group | 60 inbound + 60 outbound | Yes |
| SGs per ENI | 5 | Yes |
| NACLs per VPC | 200 | Yes |
| Rules per NACL | 20 | Yes |
| TGW attachments | 5000 | No |
| VPC peering per VPC | 125 | Yes |
| Elastic IPs per region | 5 | Yes |
| NAT Gateways per AZ | 5 | Yes |
| Interface Endpoints per VPC | 50 | Yes |
