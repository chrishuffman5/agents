# Azure Networking Reference

> Prices are US East, pay-as-you-go unless noted. Verify at https://azure.microsoft.com/pricing/.

## 1. VNet Architecture

### Hub-Spoke Topology

The recommended enterprise network topology on Azure:

```
                    Hub VNet
          ┌─────────────────────────┐
 On-prem  │  Azure Firewall / NVA   │
 ←VPN/ER→ │  Shared Services        │
          │  (DNS, Bastion, ADDS)   │
          └────┬───────┬───────┬────┘
          Peer │  Peer │  Peer │
        ┌──────┘       │       └──────┐
        ▼              ▼              ▼
   Spoke 1 (Prod) Spoke 2 (Dev) Spoke 3 (DMZ)
```

- **Hub:** Centralized firewall, VPN/ExpressRoute gateway, Bastion, shared DNS. Azure Firewall Standard ~$912/mo + $0.016/GB; Premium ~$1,825/mo (TLS inspection, IDPS).
- **Spokes:** Workload VNets peered to hub. Inter-spoke and outbound traffic routes through hub firewall via UDRs.
- **Alternative:** Azure Virtual WAN for >30 spokes or multi-region automated routing (~$547/mo per hub + $0.02/GB transit).

### VNet Peering

| Type | Data Transfer Cost | Latency |
|------|-------------------|---------|
| Same-region | Free | Sub-ms |
| Cross-region (global) | $0.01/GB each direction | 1-10ms |

Peering is non-transitive: Spoke A <-> Hub <-> Spoke B requires hub firewall/NVA or explicit Spoke A <-> Spoke B peering. Cross-region peering adds up for chatty workloads -- co-locate dependent services.

### Private Endpoints

Project Azure PaaS services (Storage, SQL, Key Vault) into your VNet with a private IP:

- **Cost:** $0.01/hr per endpoint (~$7.30/mo) + data processing rates.
- **Security:** Eliminates public internet exposure. Traffic stays on Microsoft backbone.
- **DNS:** Requires Private DNS Zones for `*.privatelink.<service>.net`. Centralize in hub VNet linked to all spokes.
- **When to use:** Any PaaS service accessed from VNet resources in production. Non-negotiable for compliance.

### Service Endpoints vs Private Endpoints

| Aspect | Service Endpoints | Private Endpoints |
|--------|------------------|-------------------|
| Cost | Free | $7.30/mo per endpoint |
| Traffic path | Optimized but public IP space | Fully private within VNet |
| On-prem access | Not accessible | Yes, via VPN/ExpressRoute |
| DNS changes | None | Requires Private DNS Zones |

Use Private Endpoints for production and on-prem connectivity. Service Endpoints acceptable for dev/test.

### Network Security Groups (NSGs)

Stateful packet filters at subnet or NIC level:

- Rules evaluated by priority (100-4096, lower = higher priority).
- Default: allow VNet-to-VNet, allow outbound internet, deny all inbound from internet.
- **Best practice:** Apply at subnet level. Use Application Security Groups (ASGs) for role-based rules without tracking IPs.
- **Cost:** Free. No per-rule or per-evaluation charge.

### Subnet Design

- `/24` (256 addresses) is common. Azure reserves 5 per subnet.
- Dedicate subnets for: AKS, App Service VNet integration, Firewall, Gateway, Bastion, Private Endpoints.
- AKS with Azure CNI (non-overlay) needs substantial IP space.
- Never use subnets smaller than `/27`.

---

## 2. Application Gateway vs Front Door vs Traffic Manager

### Comparison

| Feature | App Gateway v2 | Azure Front Door | Traffic Manager |
|---------|---------------|------------------|-----------------|
| Scope | Regional | Global | Global |
| Layer | L7 (HTTP/S) | L7 (HTTP/S) | DNS-based |
| WAF | Yes | Yes | No |
| CDN | No | Yes (integrated) | No |
| Failover speed | N/A (regional) | Seconds (anycast) | DNS TTL (30-300s) |
| Private backends | Yes (VNet) | Yes (Private Link) | No |

### Cost

| Service | Fixed Cost/mo | Variable |
|---------|-------------|----------|
| App Gateway v2 Standard | ~$175 | $6/CU/month |
| App Gateway v2 WAF | ~$262 | $9/CU/month |
| Front Door Standard | ~$35 | $0.01-$0.065/GB |
| Front Door Premium | ~$330 | Higher per-GB + Private Link |
| Traffic Manager | $0.54/endpoint/mo | $0.75/M DNS queries |

### When to Use Each

- **App Gateway:** Regional L7 load balancing, WAF, or SSL offload within a single region.
- **Front Door:** Multi-region web apps needing global routing, CDN, WAF, instant failover. Default for multi-region.
- **Traffic Manager:** Non-HTTP multi-region services, or DNS-level routing. Cheapest but slowest failover.
- **Common pattern:** Front Door (global) -> App Gateway per region (regional WAF/routing) -> backends. Most resilient but most expensive.

---

## 3. ExpressRoute

Dedicated private connectivity from on-premises to Azure:

### Cost Structure

| Component | Cost (approx) |
|-----------|---------------|
| Circuit (1 Gbps, metered) | ~$436/mo |
| Circuit (1 Gbps, unlimited data) | ~$1,700/mo |
| VNet Gateway (ErGw1Az) | ~$219/mo |
| VNet Gateway (ErGw3Az, high perf) | ~$1,314/mo |
| Outbound data (metered) | $0.025/GB |
| **Total minimum** | **~$655/mo + carrier charges** |

### ExpressRoute vs Site-to-Site VPN

| Aspect | ExpressRoute | VPN |
|--------|-------------|-----|
| Path | Private carrier network | Encrypted over internet |
| Bandwidth | 50 Mbps - 100 Gbps | Up to 10 Gbps |
| Latency | Predictable, low | Variable |
| Reliability | SLA 99.95% | Best-effort |
| Cost | $655+/mo + carrier | ~$140/mo (VpnGw1AZ) |

VPN is 5-10x cheaper and sufficient for most small/medium workloads. ExpressRoute justified for:
- Latency-sensitive apps (SAP, real-time databases).
- Bandwidth >10 Gbps.
- Compliance prohibiting public internet transit.
- M365 traffic optimization for large enterprises.

### ExpressRoute Global Reach

Connect two on-prem sites via Microsoft backbone. ~$0.05/GB additional.

---

## 4. DDoS Protection

| Tier | Cost | Protection |
|------|------|------------|
| Infrastructure (default) | Free | Basic L3/L4 for all public IPs |
| Network Protection | ~$2,944/mo per VNet (100 public IPs) | Adaptive tuning, metrics, DDoS response team, cost guarantee |
| IP Protection | ~$199/mo per public IP | Same as Network but per-IP. No response team or cost guarantee |

- Free tier handles most volumetric attacks.
- IP Protection for 1-14 public IPs. Beyond ~15 IPs, Network Protection is cheaper.
- Network Protection reimburses scale-out costs during verified attacks.

---

## 5. Azure DNS

### Public Zones
- $0.50/month per zone + $0.40 per million queries.
- Alias records for Azure resources (auto-updates, no dangling DNS).

### Private DNS Zones
- $0.25/month per zone + $0.40 per million queries.
- Essential for Private Endpoint resolution.
- **Pattern:** Host in hub VNet, link to all spokes. Centralizes management.
- With custom DNS servers: configure conditional forwarders for `*.privatelink.*` to 168.63.129.16 or use Azure DNS Private Resolver ($0.18/hr inbound + $0.09/hr outbound).
