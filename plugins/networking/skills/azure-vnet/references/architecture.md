# Azure VNet Architecture Reference

## VNet Internals

### Azure SDN Platform

Azure networking runs on a software-defined networking platform:
- Physical network abstracted by Azure host agent running on each physical server
- Virtual Filtering Platform (VFP) in the Hyper-V virtual switch enforces SDN policies
- NSG rules, UDRs, and load balancer rules programmed into VFP
- Customer traffic never shares physical resources with other tenants at the data plane level

### Effective Routes

Every NIC has an effective route table computed from:
1. **System routes**: Auto-generated for VNet address space, peered VNets, service endpoints
2. **User Defined Routes (UDRs)**: Custom routes in route tables associated with the subnet
3. **BGP routes**: Routes learned from VPN Gateway, ExpressRoute Gateway, or Route Server

**Route selection priority**: UDR > BGP > System route (for the same prefix)
**Within BGP**: Shortest AS-path, then ExpressRoute over VPN

### Address Resolution

- Azure uses a proxy ARP model -- the hypervisor intercepts all ARP requests
- ARP responses always return the hypervisor's MAC address
- The hypervisor then encapsulates and forwards the packet to the correct destination
- No broadcast domains exist in Azure VNets -- ARP is point-to-point

## vWAN Architecture Details

### Hub Router

Each vWAN hub contains a managed router (not visible to customers):
- Routes traffic between all hub connections (VPN, ER, VNet, P2S)
- Aggregated throughput: 50 Gbps for VNet-to-VNet and branch-to-VNet traffic
- Hub router scales automatically based on connected resources
- Two routing infrastructure units deployed by default (HA)

### Hub-to-Hub Routing

- Automatic full-mesh between all hubs in a vWAN
- Traffic between hubs traverses Microsoft's global backbone
- No manual route configuration needed for inter-hub connectivity
- Latency depends on physical distance between hub regions

### Routing Intent Implementation

When routing intent is configured:
1. All VNet default routes (0.0.0.0/0) point to Azure Firewall in the hub
2. All branch-originated traffic destined for VNets is force-tunneled through Azure Firewall
3. Azure Firewall evaluates network rules, then application rules
4. Routing intent replaces manual UDR configuration on spoke VNets

### NVA in vWAN Hub

- Third-party NVAs (Barracuda, Cisco, Fortinet, etc.) can be deployed directly in the vWAN hub
- NVA integrated with hub routing -- no UDR management needed
- BGP peering between NVA and hub router for dynamic route exchange
- Use case: SD-WAN appliances, third-party firewalls in the hub

## ExpressRoute Architecture

### Circuit Internals

```
Customer Edge (CE) Router
  |-- BGP peering (Private/Microsoft peering)
  |
Provider Edge (PE) Router (connectivity provider)
  |-- MPLS/Ethernet transport
  |
Microsoft Enterprise Edge (MSEE) Router
  |-- Azure Private peering -> VNet via ExpressRoute Gateway
  |-- Microsoft peering -> M365, Dynamics, Azure PaaS public endpoints
```

### Peering Configuration

**Private Peering (VNet access):**
- Customer provides: /30 primary + /30 secondary subnet, VLAN ID, peer ASN
- BGP session between CE and MSEE
- Customer advertises on-prem routes; Azure advertises VNet routes
- Supports up to 4000 routes from customer (default), 10000 with premium add-on

**Microsoft Peering (Public service access):**
- Requires public IP prefixes owned by customer (for NAT)
- Route filters: select which Microsoft services to receive routes for
- Used for M365, Dynamics 365, Azure PaaS public endpoints

### ExpressRoute Gateway SKUs

| SKU | Max Connections | Throughput | FastPath | Zone-Redundant |
|---|---|---|---|---|
| Standard | 4 circuits | 1 Gbps | No | No |
| HighPerformance | 4 circuits | 2 Gbps | No | No |
| UltraPerformance | 4 circuits | 10 Gbps | Yes | No |
| ErGw1AZ | 4 circuits | 1 Gbps | No | Yes |
| ErGw2AZ | 4 circuits | 2 Gbps | No | Yes |
| ErGw3AZ | 4 circuits | 10 Gbps | Yes | Yes |

### FastPath Implementation

- Data plane bypasses the ExpressRoute Gateway entirely
- Traffic flows directly from MSEE to VNet NIC
- Reduces latency by eliminating gateway hop
- Control plane still uses the gateway (route exchange, circuit management)
- Limitations: does not work with VNet peering in some configurations

## Azure Firewall Implementation

### Firewall Architecture

- Fully managed, auto-scaling firewall service
- Backend: multiple VM instances behind an internal load balancer
- Public IP(s) for SNAT (outbound) and DNAT (inbound)
- Private IP: first usable IP in AzureFirewallSubnet (typically .4)
- Auto-scales from 2 to 20+ instances based on throughput

### Rule Processing Order

```
1. DNAT Rules (inbound NAT)
   - Evaluated first for inbound traffic
   - If match: translate destination, then evaluate Network Rules

2. Network Rules (L3/L4)
   - Evaluated for all non-DNAT traffic
   - Source, destination, port, protocol matching
   - If match: Allow or Deny

3. Application Rules (L7)
   - Evaluated only if no Network Rule matched
   - FQDN, URL, web category matching
   - HTTP/HTTPS only (not arbitrary protocols)
   - If match: Allow or Deny

4. If no rule matches: Default deny (implicit)
```

### TLS Inspection (Premium)

- Azure Firewall acts as MITM proxy for HTTPS traffic
- Requires intermediate CA certificate (customer-provided or Azure Key Vault)
- Decrypts, inspects (IDPS + URL filtering), re-encrypts
- Certificate must be trusted by all clients (deploy via GPO, Intune, MDM)
- Bypass list for certificate-pinned applications (banking, healthcare)

### IDPS Implementation (Premium)

- Suricata-based signature engine
- 58,000+ signatures updated automatically
- Signature categories: malware, phishing, C2, exploit, policy violation
- Private IP ranges define what is considered internal traffic
- Custom signatures via Azure Firewall Policy API (Suricata format)

## Private Link DNS Architecture

### DNS Resolution Chain

```
Client -> VNet DNS (168.63.129.16) -> Private DNS Zone -> Private Endpoint IP

Without Private DNS Zone:
  mystorageaccount.blob.core.windows.net -> Public IP (no private access)

With Private DNS Zone (privatelink.blob.core.windows.net):
  mystorageaccount.blob.core.windows.net
    -> CNAME -> mystorageaccount.privatelink.blob.core.windows.net
    -> A record -> 10.1.20.10 (private endpoint IP)
```

### On-Premises DNS Integration

For on-premises clients to resolve private endpoints:
1. Deploy DNS forwarder/proxy VMs in Azure (or use Azure DNS Private Resolver)
2. Configure on-prem DNS to conditionally forward `privatelink.*` zones to the DNS proxy
3. DNS proxy forwards to Azure DNS (168.63.129.16)
4. Azure DNS resolves via Private DNS Zone

### Azure DNS Private Resolver

- Managed DNS forwarding service (no VM management)
- Inbound endpoint: on-prem DNS forwards to this IP for Azure name resolution
- Outbound endpoint: Azure DNS conditionally forwards to on-prem DNS servers
- Deployed in a dedicated subnet (/28 minimum)

## Route Server Architecture

### BGP Peering

```
NVA (BGP AS 65001) <-- eBGP --> Route Server (BGP AS 65515)
                                     |
                                Injects routes into VNet effective routes
                                     |
                        All NICs in VNet see NVA-advertised routes
```

### Route Server Behavior

- Always uses AS 65515 (not configurable)
- Peers with up to 8 NVAs per Route Server
- Supports ECMP across multiple NVAs (branch-to-branch via NVA)
- Does NOT sit in the data path -- only injects/learns routes
- Route Server routes have lower priority than UDRs (UDR always wins)

### Route Server + ExpressRoute

- Route Server can propagate NVA routes to on-premises via ExpressRoute
- Enable "Branch to Branch" on Route Server to allow this
- Use case: advertise SD-WAN summarized routes from NVA to on-premises over ExpressRoute

## Service Endpoints vs Private Endpoints

| Aspect | Service Endpoint | Private Endpoint |
|---|---|---|
| PaaS IP | Remains public | Gets private IP in VNet |
| Traffic path | Optimal (Azure backbone) | Via private endpoint NIC |
| DNS | No change | Requires Private DNS Zone |
| Firewall rules | Source IP = subnet range | Source IP = private endpoint IP |
| Cross-region | Same region only | Cross-region supported |
| VNet peering access | Not accessible from peered VNet | Accessible from peered VNet |
| Cost | Free | Per-hour + per-GB |
| Security | Restricts PaaS to VNet source | Full network isolation |

**Recommendation**: Use Private Endpoints for security-sensitive workloads. Use Service Endpoints for cost-sensitive, same-region access where full isolation is not required.
