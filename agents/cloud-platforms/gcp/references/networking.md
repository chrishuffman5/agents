# GCP Networking Reference

> Prices are us-central1 unless noted. Verify at https://cloud.google.com/pricing.

## 1. VPC Architecture

### Global VPC Model (Unique to GCP)

VPCs are global resources; subnets are regional. One VPC spans all regions without peering.
- **Auto mode:** Subnets auto-created in each region. **Custom mode:** You define subnets. Always use custom for production.
- Internal IP ranges: RFC 1918. Alias IP ranges for multiple IPs per VM.

### Shared VPC (Critical for Enterprise)

- **Host project** owns the VPC. **Service projects** use subnets from the host.
- Centralized network administration, decentralized resource deployment.
- IAM controls which service projects use which subnets.
- vs VPC Peering: Shared VPC = centralized control. Peering = independent networks that communicate.
- **Shared VPC is free.**

### Private Service Connect (PSC)

Private endpoints for Google APIs and services:
- Consumer-side forwarding rule to Google service.
- Published services: expose your services privately to other VPCs without peering.
- Similar to AWS PrivateLink but cleaner implementation.

### Cloud NAT

Managed NAT gateway for outbound internet from private VMs:
- No VM to manage (unlike AWS NAT Gateway).
- $0.0045/hr per VM using NAT + $0.045/GB processed.
- Auto-scales, no bandwidth limits.

### Firewall Rules

- Hierarchical policies: Organization -> Folder -> VPC (inherit down).
- VPC rules: allow/deny by IP, port, protocol, service account, tag.
- Firewall Insights: analyze usage, detect overly permissive rules.
- Implied defaults: deny all ingress, allow all egress.

---

## 2. Load Balancing

**GCP load balancing is software-defined and globally distributed. No pre-provisioning, no warm-up.**

| Type | Scope | Layer | Use Case |
|------|-------|-------|----------|
| External HTTP(S) | Global | L7 | Web apps, APIs, CDN |
| Internal HTTP(S) | Regional | L7 | Internal microservices |
| External TCP/UDP | Regional | L4 | Non-HTTP, gaming, IoT |
| External TCP Proxy | Global | L4 | TCP with SSL offload |
| Internal TCP/UDP | Regional | L4 | Internal non-HTTP |
| Cross-region Internal | Global | L7 | Multi-region internal |

### Global External HTTP(S) LB

- Single anycast IP serves traffic worldwide. Traffic enters Google's network at nearest edge POP.
- Automatic multi-region failover.
- URL maps for content-based routing (path, host, headers).
- Integrated: Cloud CDN, Cloud Armor, Identity-Aware Proxy.
- Supports HTTP/2, gRPC, WebSocket, QUIC (HTTP/3).

### Pricing

- Forwarding rules: first 5 free, $0.025/hr additional.
- Data processing: $0.008-$0.012/GB.
- No separate per-hour LB charge (unlike AWS ALB/NLB).

---

## 3. Cloud CDN

- Integrated with external HTTP(S) LB (enable with one checkbox).
- Cache modes: USE_ORIGIN_HEADERS, FORCE_CACHE_ALL, CACHE_ALL_STATIC.
- Signed URLs and signed cookies for access control.
- Media CDN: separate product for large-scale media delivery.
- Pricing: $0.02-0.08/GB cache egress, $0.0075/10K lookups.

---

## 4. Cloud Armor (WAF + DDoS)

Edge security at Cloud Load Balancing:
- Preconfigured WAF rules (OWASP Top 10), custom rules (CEL).
- Adaptive Protection: ML-based L7 DDoS auto-detection.
- Rate limiting, bot management, geo-blocking.
- Pricing: $0.75/policy/month + $0.60/M requests + $1.00/M requests (Adaptive).
- **Managed Protection Plus:** $3,000/month for DDoS response team and financial guarantee.

---

## 5. Cloud DNS

- 100% uptime SLA (anycast, globally distributed).
- Public and private zones. DNSSEC support.
- DNS policies: inbound/outbound forwarding, response policies (DNS firewall).
- Pricing: $0.20/zone/month + $0.40/M queries (first 1B), $0.20/M after.

---

## 6. Connectivity

### Cloud Interconnect

| Type | Bandwidth | Cost |
|------|-----------|------|
| Dedicated | 10/100 Gbps physical | $1,700/mo (10G) + VLAN $0.05/hr |
| Partner | 50 Mbps-50 Gbps via provider | Provider pricing + VLAN $0.05/hr |

Reduced egress: ~$0.02/GB vs $0.08-0.12/GB for internet egress.

### Cloud VPN

- **HA VPN:** 99.99% SLA, 2 tunnels (active-active), BGP. Up to 3 Gbps/tunnel.
- Classic VPN: deprecated, 99.9% SLA.
- Pricing: $0.025/hr per tunnel + standard egress.
- HA VPN over Interconnect: encrypted traffic on dedicated connection.

### Network Service Tiers

- **Premium (default):** Google's global backbone, nearest edge POP, lowest latency.
- **Standard:** Public internet, regional POP, ~$0.01-0.02/GB cheaper egress.
- Choose Standard only for cost-sensitive, latency-tolerant workloads.

---

## 7. Egress Pricing (Critical Cost Factor)

GCP egress is generally the most expensive of the big 3 clouds:

| Path | Cost/GB |
|------|---------|
| Intra-region, same zone | Free |
| Intra-region, cross-zone | $0.01 |
| Inter-region, same continent | $0.01 |
| Inter-region, cross-continent | $0.02-0.08 |
| Internet (Premium Tier) | $0.08-0.23 |
| Internet (Standard Tier) | $0.04-0.08 |
| Interconnect egress | $0.02-0.05 |

Mitigation: Cloud CDN for static content, Standard Tier for tolerant workloads, Interconnect for high-volume, keep traffic in same zone when possible.
