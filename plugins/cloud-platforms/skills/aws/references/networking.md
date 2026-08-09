# AWS Networking Reference

> VPC layout, NAT economics, endpoints, multi-VPC and hybrid connectivity, CloudFront, Route 53, load balancing. Prices are US East (N. Virginia) and PRICE-VOLATILE; quotas and mechanics are structural facts.
>
> Configuration procedures (building TGW route tables, creating peering connections, provisioning Direct Connect) belong to the `aws-vpc` skill in `networking`. This file is the selection layer.

---

## VPC Architecture

> Source: https://aws.amazon.com/vpc/pricing/ (official)

**Multi-AZ is mandatory.** Deploy across 2+ AZs (3 preferred). Cross-AZ data transfer within a Region is **$0.01/GB in each direction ($0.02/GB round trip)** — trivial next to the risk of a single-AZ outage.

### Standard subnet architecture

```
VPC (e.g. 10.0.0.0/16)
  Public subnets (one per AZ)        -- IGW route; ALB/NLB, NAT Gateway, bastion. Small CIDR (/24).
  Private app subnets (one per AZ)   -- NAT route for egress; EC2, ECS tasks, VPC-attached Lambda. Large CIDR (/20).
  Private data subnets (one per AZ)  -- no internet route; RDS, ElastiCache, OpenSearch. Medium CIDR (/22).
  Isolated subnets (optional)        -- local routes only.
```

### CIDR planning

Plan CIDRs before deployment: overlapping ranges permanently block VPC peering and Transit Gateway attachment, and are the single most expensive layout mistake to correct later. Use RFC 1918 space, allocate a master range and carve per-VPC blocks from it, leave room for secondary CIDRs (up to 5 per VPC), and record allocations in AWS VPC IPAM. Avoid 172.17.0.0/16, which Docker uses by default — this is practitioner guidance, not an AWS-published rule.

---

## NAT Gateway Economics

> Source: https://aws.amazon.com/vpc/pricing/ (official)

- **Hourly: $0.045/hour x 730 = $32.85/month per NAT Gateway.**
- **Data processing: $0.045/GB.**
- **HA pattern (one per AZ, three AZs): 3 x $32.85 = $98.55/month** before a single byte of data processing.

| Strategy | Effect | Tradeoff |
|---|---|---|
| Single NAT Gateway (dev/staging only) | ~66% of the hourly cost | Single point of failure |
| VPC endpoints for AWS services | Removes that traffic from NAT data processing entirely | Small hourly cost for interface endpoints |
| NAT instance on a small Graviton type | Order-of-magnitude lower hourly cost | Lower throughput, you own HA and patching |
| IPv6 with egress-only internet gateway | No NAT charge for IPv6 egress | Requires IPv6 adoption end to end |

**Key insight:** if private subnets mostly talk to AWS services, endpoints eliminate most NAT data processing. Compare the monthly NAT data charge per service against the endpoint cost below and create the endpoint whenever it wins.

---

## VPC Endpoints

> Source: https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html and https://aws.amazon.com/privatelink/pricing/ (official)

### Gateway endpoints (free)

**S3 and DynamoDB only.** No hourly charge and no data-processing charge; implemented as route-table entries. Create them in every VPC — there is no cost argument against it.

### Interface endpoints (PrivateLink)

- Available for 100+ services (ECR, CloudWatch, SQS, SNS, KMS, Secrets Manager, SSM, STS, and more).
- **$0.01/hour per endpoint ENI** — one ENI per subnet/AZ the endpoint is deployed into, so roughly **$7.30/month per AZ**.
- Data processing is **tiered**: $0.01/GB for the first 1 PB per month per Region, $0.006/GB for the next 4 PB, $0.004/GB beyond 5 PB.

Prioritize by traffic volume: ECR image pulls, CloudWatch logs and metrics, and SSM are usually the top three.

### Other endpoint types worth knowing

- **Gateway Load Balancer endpoints** — how consumers attach to a provider's GWLB for inline appliance inspection. Billed separately from the GWLB itself ($0.01/hour plus $0.0035/GB).
- **Resource endpoints** — privately reach a specific shared resource (a database, an EC2 instance, an IP, or a domain-name target) in another VPC **without a load balancer**. A meaningfully simpler cross-account access pattern than standing up an NLB-backed endpoint service.
- **Service network endpoints** — one endpoint reaching many resources and services associated with a Resource Access Manager service network.

---

## Multi-VPC Connectivity

### VPC peering is non-transitive — the founding constraint

> Source: https://docs.aws.amazon.com/vpc/latest/peering/invalid-peering-configurations.html and https://docs.aws.amazon.com/vpc/latest/peering/vpc-peering-connection-quotas.html (official)

Verbatim: "A VPC peering connection is a **one to one relationship** between two VPCs... **transitive peering relationships are not supported**. You do not have any peering relationship with VPCs that your VPC is not directly peered with."

Concretely: if VPC A peers with both B and C, **A cannot be a transit point between B and C**. Full mesh across *n* VPCs needs *n(n-1)/2* connections. **Edge-to-edge routing is also prohibited** — resources in a peered VPC B cannot use VPC A's internet gateway, NAT device, VPN connection, Direct Connect connection, or S3 gateway endpoint. Non-transitivity applies to gateways, not just VPC-to-VPC traffic.

Quotas: **active peering connections per VPC default to 50 and are adjustable to a maximum of 125.** Quoting 125 without the default is misleading — most accounts hit 50 first. Peered VPCs must not have overlapping CIDRs, and only one peering connection is permitted between a given pair.

### Transit Gateway as the hub

> Source: https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html, https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-quotas.html, https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-transit-gateway.html (official)

"AWS Transit Gateway is a **network transit hub** used to interconnect virtual private clouds (VPCs) and on-premises networks." Each VPC attaches once to reach every other permitted VPC — the transitivity peering lacks.

- **Attachment types:** VPCs, Connect (SD-WAN appliances), Direct Connect gateway, TGW peering, VPN, VPN Concentrator, Client VPN, network function.
- **Attachments per TGW: 5,000** default (adjustable).
- **Route propagation differs by attachment type** — a frequent design error: **VPC attachments require static routes** (no auto-propagation); **VPN connections propagate via BGP**; **Direct Connect gateway attachments** originate allowed-prefix advertisements via BGP; **peering attachments require a static route.**
- **Segmentation** comes from multiple route tables: each attachment associates with exactly one route table, and separate tables create isolated routing domains (prod versus non-prod) "from a single point of management."
- **Cost:** billed **per attachment-hour plus per-GB processed**, with data-processing charges allocated by default to the source attachment's owning account. This is the legitimate reason small topologies stay on peering, where cross-VPC traffic is billed as ordinary data transfer.

**Decision rule:** 1-5 VPCs -> peering. 5-10 with mesh needs -> evaluate TGW. 10+ or hub-and-spoke, or you need centralized inspection/shared services -> TGW.

### PrivateLink — the third shape

> Source: https://docs.aws.amazon.com/vpc/latest/privatelink/what-is-privatelink.html and https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-privatelink.html (official)

PrivateLink connects a VPC "to services and resources **as if they were in your VPC**" with no internet gateway, NAT device, public IP, Direct Connect, or VPN required, and you "control the specific API endpoints, sites, services, and resources that are reachable."

Two decisive selection triggers, one of them unique:

1. You want to expose **one specific service to many consumer VPCs** (including across organizations) without granting network-level reachability. PrivateLink is **unidirectional and service-oriented**; peering and TGW give bidirectional full-network reachability.
2. **"AWS PrivateLink is a good solution when the VPCs have overlapped IP addresses."** Peering and TGW both categorically require non-overlapping CIDRs — PrivateLink is the only one of the three that works when that constraint cannot be met.

Access control differs too: interface endpoints are ENIs in the consumer's own subnets, so **security groups govern access**, and an endpoint policy further scopes which principals may use it.

### AWS Cloud WAN

> Source: https://docs.aws.amazon.com/network-manager/latest/cloudwan/what-is-cloudwan.html (official)

A managed global WAN driven by a single declarative **core network policy** defining **segments** (routing domains — "by default, only attachments within the same segment can communicate"), per-Region routing, and tag-based attachment policies. Each named Region gets a **core network edge**, and "all core network edges in your core network create full-mesh peering with each other" automatically. AWS describes the edge as inheriting Transit Gateway properties — Cloud WAN is a policy-driven orchestration layer over a global mesh of TGW-like edges, not a replacement primitive.

**Selection signal:** reach for Cloud WAN when coordinating routing and segmentation policy across many Regions and a mesh of branch/data-centre/VPC attachments has itself become the operational burden. For single-Region or few-Region hub-and-spoke, plain Transit Gateway is simpler. Caveats to check: PrivateLink support through Cloud WAN is limited to us-west-2 and us-gov-west-1 and is IPv6-dual-stack-only as documented, and Cloud WAN's home Region is fixed to US West (Oregon) and cannot be changed after establishment.

---

## Hybrid Connectivity

### Hybrid DNS with Route 53 Resolver

> Source: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html and https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-rules-managing.html (official)

The VPC Resolver is available by default in every VPC at the **VPC+2 address** and answers recursively for public records, VPC DNS names, and private hosted zones. Two endpoint types bridge to on-premises:

- **Outbound Resolver endpoint** — a VPC resolving an on-premises name. An instance queries VPC+2, a **forwarding rule** matches the domain, the query leaves via the outbound endpoint to the on-premises resolver "through a private connection between AWS and the data center" — Direct Connect or Site-to-Site VPN — and the answer returns the same way.
- **Inbound Resolver endpoint** — an on-premises client resolving an AWS-hosted name. The on-premises resolver forwards the domain to the inbound endpoint over the same private connection.

Resolver endpoints ride on top of existing hybrid connectivity; they do not provide it.

**Forwarding-rule governance at org scale:** one rule per domain, effective only once **associated with a VPC**. Rules are shared cross-account through **AWS Resource Access Manager** — to accounts, an OU, or the whole organization; recipients associate shared rules with their own VPCs but cannot modify, delete, or re-tag them. Quota nuance for multi-account design: the **rule-count quota bills to the creating account, the rule-to-VPC-association quota to the consuming account.** If a rule is shared to an OU and an account later moves OUs, its existing associations to that rule are deleted.

**Centralized DNS account pattern:** private hosted zones can be associated with VPCs in other accounts, but only via an explicit two-party handshake — the zone owner calls `CreateVPCAssociationAuthorization` (**CLI/SDK/API only, not available in the console**), the VPC owner calls `AssociateVPCWithHostedZone`, and the zone owner then deletes the authorization. Combined with RAM-shared forwarding rules, this is the standard hub-and-spoke hybrid DNS design: one account owns canonical internal zones and forwarding rules, every spoke associates in.

### Direct Connect vs Site-to-Site VPN

> Source: https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-direct-connect.html, https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-gateways-intro.html, https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_ha_conn_private_networks.html, https://aws.amazon.com/directconnect/resiliency-recommendation/ (official)

| | Direct Connect | Site-to-Site VPN |
|---|---|---|
| Transport | Dedicated circuit, 802.1Q VLANs over private IP | IPsec over the public internet |
| Bandwidth | Dedicated 1/10/100 Gbps ports; hosted 50 Mbps-10 Gbps; up to 4x1/10 Gbps or 2x100 Gbps in a LAG | **1.25 Gbps per tunnel**, aggregable to ~50 Gbps via ECMP across a Transit Gateway |
| Latency | Consistent | Variable (internet path) |
| Encryption | **Not encrypted by default** — MACsec on 10/100 Gbps dedicated connections, or a VPN over the connection at 1 Gbps or below | IPsec by default |
| Provisioning | Physical lead time | Minutes |

Virtual interface types: **public** (AWS public endpoints), **transit** (to a Transit Gateway), **private** (directly to a VPC). A **Direct Connect gateway** is a globally available fan-out primitive letting one connection/VIF reach multiple VPCs or Transit Gateways across Regions and accounts; it is explicitly **not in the data path** — "a virtual component of Direct Connect designed to act as a distributed set of BGP route reflectors... it avoids creating a single point of failure."

**Resiliency tiers, with the SLA figures AWS publishes:**

- **Maximum resiliency, 99.99% SLA** — separate connections terminating on distinct devices in **more than one on-premises location and more than one Direct Connect location**.
- **High resiliency, 99.9% SLA** — two connections to multiple Direct Connect locations, each on-premises location connected to a single Direct Connect location.
- **Single-location redundancy is a documented anti-pattern for production**: two connections on different devices at one location protects only against device failure. "For production workloads, AWS does not recommend using any Deployment other than a Multi-Site Redundant Deployment or a Multi-Site Non-Redundant Deployment."
- Not running BGP is listed as its own anti-pattern — physical redundancy without dynamic routing does not deliver automatic reroute.

**VPN as a DX backup** is AWS's explicitly recommended cost-effective pattern: Site-to-Site VPN terminating on a Transit Gateway, with ECMP across tunnels, while "AWS Direct Connect is still the most effective choice for minimizing network disruptions and providing stable connectivity." For VPN HA on its own, use **two tunnels per connection terminating in different AZs**, redundant customer-gateway hardware, and ideally physically diverse ISP paths.

**DX + VPN combined** answers the "dedicated bandwidth *and* hard encryption-in-transit requirement" case at port speeds where MACsec is unavailable: a public VIF reaches the Site-to-Site VPN endpoint, and the IPsec tunnel runs over the dedicated connection.

---

## Route 53

> Source: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html and https://aws.amazon.com/route53/pricing/ (official)

### Routing policies — eight, not seven

| Policy | Use |
|---|---|
| Simple | One resource, no special routing |
| Weighted | Canary and blue/green traffic shifting; weight 0 removes a target |
| Latency-based | Multi-Region active-active by lowest resolver latency |
| Failover | Active-passive DR — primary while healthy, secondary otherwise |
| Geolocation | Compliance and localization by continent/country |
| Geoproximity | Geographic routing with a bias adjustment |
| **IP-based** | Route by the client's originating IP range (CIDR-to-endpoint mapping) — more precise than inferred geolocation |
| Multivalue answer | Up to **eight** healthy records returned at random |

### Pricing

- Hosted zones: **$0.50/month for the first 25, $0.10/month after.**
- Queries: **$0.40 per million standard**; **$0.60 per million latency-based**; **$0.70 per million geolocation and geoproximity** (those two share a tier — do not group geolocation with latency). Standard queries drop to $0.20/M above 1 billion per month.
- **Alias records to AWS resources are free.** Always use Alias over CNAME — no query charge and it works at the zone apex.
- Health checks: **$0.50/month for AWS endpoints, $0.75/month for non-AWS**, plus **$1.00/month per optional feature** on AWS endpoints ($2.00 non-AWS) covering HTTPS, string matching, fast interval, and latency measurement. **Up to 50 health checks for AWS endpoints are free** — small deployments often pay nothing.

---

## CloudFront

> Source: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/PayingForInvalidation.html, https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/flat-rate-pricing-plan.html, https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_cloudfront.PriceClass.html (official)

### Price classes

| Class | Coverage |
|---|---|
| PriceClass_100 | USA, Canada, Europe, Israel |
| PriceClass_200 | PriceClass_100 plus South Africa, Kenya, Middle East, Japan, Singapore, South Korea, Taiwan, Hong Kong, Philippines |
| PriceClass_All | All edge locations |

Start at PriceClass_100 unless you have measurable traffic from excluded Regions.

### Flat-rate pricing plans

CloudFront now offers **flat-rate monthly plans (Free / Pro / Business / Premium)** bundling CDN, AWS WAF, DDoS protection, bot management, Route 53 DNS, CloudWatch Logs ingestion, a TLS certificate, serverless edge compute, and monthly S3 storage credits into one no-overage price. For smaller workloads or teams that value billing predictability over marginal optimization, evaluate a flat-rate plan before itemized pay-as-you-go.

### Invalidation and caching

- **First 1,000 invalidation paths per month are free per account**, then $0.005 per path. **Tag invalidation paths count against the same 1,000-path allowance** — CloudFront supports cache-tag-based invalidation as well as URL paths, and the two share one free-tier pool.
- Prefer **versioned filenames** (`app.v2.3.js`) to invalidation: instant and free.
- Minimize cache-key components for hit ratio; use cache policies rather than legacy forwarding settings.
- **Origin Shield** adds a mid-tier cache that reduces origin load when edge traffic is geographically diverse.
- Use **Origin Access Control** for S3 origins to block direct bucket URLs.

---

## Load Balancing

> Source: https://aws.amazon.com/elasticloadbalancing/pricing/, https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html, https://docs.aws.amazon.com/elasticloadbalancing/latest/network/network-load-balancers.html (official)

| Factor | ALB | NLB | GWLB |
|---|---|---|---|
| Layer | 7 (HTTP/HTTPS) | 4 (TCP/UDP/TLS) | 3 (IP) |
| Routing | Path, host, header, query | Port-based | Transparent |
| Static IP | No (use Global Accelerator) | Yes (one per AZ) | N/A |
| Lambda targets | Yes | No | No |
| PrivateLink provider | No | **Yes** | N/A |
| Cost | $0.0225/hour + $0.008/LCU-hour | $0.0225/hour + $0.006/NLCU-hour | $0.0125/hour per AZ + $0.004/GLCU-hour |

GWLB consumers additionally pay for the **GWLB endpoint** ($0.01/hour plus $0.0035/GB) — a distinct line item from the GWLB itself.

### Cross-zone load balancing

- **ALB:** on by default, no extra charge, and **cannot be disabled at the load-balancer level** (only per target group).
- **NLB:** `load_balancing.cross_zone.enabled` defaults to **false**. Enabling it incurs standard cross-AZ data transfer at $0.01/GB, which is usually worth paying for even distribution.

### Tuning

- Consolidate services behind one ALB with host-based routing (up to 100 rules per listener).
- Reduce deregistration delay from the 300 s default to 30-60 s for most applications.
- Health checks: the 30 s / 5 healthy / 2 unhealthy default takes 60 s to detect and 150 s to recover; a 10 s / 2 / 2 configuration detects and recovers in ~20 s. Point checks at a lightweight `/health` endpoint that verifies critical dependencies, and set the ASG `HealthCheckGracePeriod` longer than application initialization.
- Choose NLB for static IPs, extreme connection counts, non-HTTP protocols, or when acting as a PrivateLink service provider. For HTTP workloads needing static IPs, chain NLB in front of ALB, or use Global Accelerator with the ALB directly.

## Sources

- https://aws.amazon.com/vpc/pricing/
- https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html
- https://aws.amazon.com/privatelink/pricing/
- https://docs.aws.amazon.com/vpc/latest/privatelink/what-is-privatelink.html
- https://docs.aws.amazon.com/vpc/latest/peering/invalid-peering-configurations.html
- https://docs.aws.amazon.com/vpc/latest/peering/vpc-peering-connection-quotas.html
- https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html
- https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-quotas.html
- https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-transit-gateway.html
- https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-privatelink.html
- https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-direct-connect.html
- https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-site-to-site-vpn.html
- https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-direct-connect-site-to-site-vpn.html
- https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-gateways-intro.html
- https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_ha_conn_private_networks.html
- https://aws.amazon.com/directconnect/resiliency-recommendation/
- https://docs.aws.amazon.com/network-manager/latest/cloudwan/what-is-cloudwan.html
- https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html
- https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-rules-managing.html
- https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-associate-vpcs-different-accounts.html
- https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html
- https://aws.amazon.com/route53/pricing/
- https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_cloudfront.PriceClass.html
- https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/PayingForInvalidation.html
- https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/flat-rate-pricing-plan.html
- https://aws.amazon.com/elasticloadbalancing/pricing/
- https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html
- https://docs.aws.amazon.com/elasticloadbalancing/latest/network/network-load-balancers.html

Fetched: 2026-08-08
