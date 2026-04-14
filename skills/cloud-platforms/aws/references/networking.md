# AWS Networking Reference

> VPC, NAT Gateway, VPC Endpoints, CloudFront, Route 53, ALB/NLB. Prices are US East (N. Virginia) on-demand.

---

## VPC Architecture

### Foundational Design

**Multi-AZ is mandatory.** Always deploy across 2+ AZs (3 preferred). Cross-AZ data transfer ($0.01/GB each direction) is minor compared to single-AZ outage risk.

### Standard Subnet Architecture

```
VPC (e.g., 10.0.0.0/16 -- 65,536 IPs)
  Public subnets (one per AZ)
    Internet Gateway route
    ALB/NLB, NAT Gateway, bastion hosts
    Small CIDR (e.g., /24 = 251 usable IPs)
  Private app subnets (one per AZ)
    Route to NAT Gateway for outbound internet
    EC2, ECS tasks, Lambda (VPC-attached)
    Larger CIDR (e.g., /20 = 4,091 IPs)
  Private data subnets (one per AZ)
    No internet route
    RDS, ElastiCache, OpenSearch
    Medium CIDR (e.g., /22 = 1,019 IPs)
  (Optional) Isolated subnets -- no route table entries except local
```

### CIDR Planning

**Critical: plan CIDRs before deployment.** Overlapping CIDRs prevent peering and Transit Gateway.

- Use RFC 1918: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
- Allocate a master range and carve sub-ranges per VPC
- /16 per VPC for production, /20 or /22 for dev/staging
- Document in IPAM tool (AWS VPC IPAM or spreadsheet)
- Leave room for secondary CIDRs (up to 5 per VPC)
- **Never use 172.17.0.0/16** -- Docker uses it by default, causing container routing conflicts

---

## NAT Gateway -- Cost Awareness

NAT Gateway is one of the most surprisingly expensive AWS services.

- **Hourly charge:** $0.045/hr x 730 = **$32.40/month per NAT Gateway**
- **Data processing:** $0.045/GB processed
- **HA pattern:** One per AZ (recommended) = 3 x $32.40 = **$97.20/month** before data transfer

### Cost Reduction Strategies

| Strategy | Savings | Tradeoff |
|----------|---------|----------|
| Single NAT Gateway (dev/staging only) | 66% hourly | Single point of failure |
| VPC Endpoints for AWS services | Eliminate NAT data charges for S3, DynamoDB, ECR, CW | Small hourly cost for Interface endpoints |
| NAT Instance (t4g.nano) | ~$3/mo vs $32/mo | Lower throughput, you manage HA, patching |
| IPv6 with egress-only IGW | Free outbound | Requires IPv6 adoption |

**Key insight:** If private subnets mainly access AWS services (S3, DynamoDB, SQS, ECR, CloudWatch), VPC Endpoints eliminate most NAT Gateway data charges. A single Interface endpoint costs ~$7.20/month per AZ -- cheaper than NAT data charges for moderate traffic.

---

## VPC Endpoints

### Gateway Endpoints (FREE)

Available for **S3** and **DynamoDB** only. No hourly charge, no data processing charge. Implemented as route table entries. **Always create these. Zero reason not to.**

### Interface Endpoints (PrivateLink)

- Available for 100+ AWS services (ECR, CloudWatch, SQS, SNS, KMS, Secrets Manager, SSM, STS)
- Cost: ~$0.01/hr per AZ (~$7.20/month per AZ) + $0.01/GB processed
- Prioritize by traffic volume: ECR (image pulls), CloudWatch (logs/metrics), SSM

**Decision framework:** Calculate monthly NAT Gateway data charge for each AWS service. If charge > Interface endpoint cost ($7.20/month/AZ), create the endpoint. Added security benefit: traffic stays on AWS network.

---

## Transit Gateway vs VPC Peering

| Factor | VPC Peering | Transit Gateway |
|--------|------------|-----------------|
| Cost | Free (data transfer only: $0.01/GB cross-AZ) | $0.05/hr attachment + $0.02/GB processed |
| Topology | 1:1, non-transitive | Hub-and-spoke, transitive routing |
| Scale | Max 125 peering per VPC | Up to 5,000 attachments |
| Cross-region | Supported | Supported |

**Decision rule:**
- **1-5 VPCs:** VPC Peering. Simple and cost-effective.
- **5-10 VPCs with mesh needs:** Evaluate Transit Gateway.
- **10+ VPCs or hub-spoke:** Transit Gateway. Centralized management outweighs cost.

---

## Route 53

### Routing Policies

| Policy | Use Case |
|--------|----------|
| **Simple** | Single resource, no special routing |
| **Weighted** | Canary deployments, A/B testing (e.g., 90/10 split) |
| **Latency-based** | Multi-region active-active (lowest latency from resolver) |
| **Failover** | Active-passive DR (switch on health check failure) |
| **Geolocation** | Compliance, content localization (by continent/country) |
| **Geoproximity** | Fine-grained geographic routing with bias |
| **Multi-value** | Multiple healthy endpoints (up to 8 records) |

**Common patterns:**
- Multi-region active-active: Latency-based + health checks + auto failover
- Blue-green: Weighted routing 100/0 -> 90/10 -> 50/50 -> 0/100
- DR with RTO <1 min: Failover routing, health check interval=10s, threshold=1

### Health Checks

| Type | Cost |
|------|------|
| Endpoint (HTTP/HTTPS/TCP) | $0.50/month (AWS) or $0.75/month (non-AWS) |
| Calculated (composite) | $1.00/month |
| CloudWatch alarm-based | $1.00/month + alarm cost |

Use string matching to verify response body (not just 200 OK).

### Cost Model

- Hosted zones: $0.50/month (first 25), $0.10/month after
- Queries: $0.40/M standard, $0.60/M latency/geo, $0.70/M geoproximity
- **Alias records for AWS resources are FREE** -- always use Alias instead of CNAME (zero query cost, works at zone apex)

---

## CloudFront

### Origin Types

| Origin | Key Configuration |
|--------|-------------------|
| S3 bucket | Origin Access Control (OAC) -- always use. Block direct S3 access. |
| ALB | Custom origin, keep-alive, forward only necessary headers |
| API Gateway | Custom origin or native integration |
| Custom origin | Origin failover group for HA |

### Price Classes

| Class | Edge Locations | Use Case |
|-------|---------------|----------|
| PriceClass_100 | US, Canada, Europe, Israel | US/EU-focused (cheapest) |
| PriceClass_200 | + Asia, Middle East, Africa, Japan | Global minus S. America/Australia |
| PriceClass_All | All locations | True global reach |

**Tip:** Start with PriceClass_100 unless you have measurable traffic from excluded regions.

### Caching Strategy

- Minimize cache key components for higher hit ratio
- Use Cache Policies (not legacy forwarding settings)
- Versioned file names (`app.v2.3.js`) instead of invalidation (instant, free)
- First 1,000 invalidation paths/month free; $0.005/path after
- **Origin Shield:** Additional caching layer (~$0.0090/10K requests). Reduces origin load with diverse edge traffic.

### Security Integration

- AWS WAF: attach web ACL to distribution
- Signed URLs/Cookies for private content
- Origin Access Control (OAC) for S3 origins -- prevents direct S3 URL access

---

## Load Balancing

### ALB vs NLB vs GLB

| Factor | ALB (Application) | NLB (Network) | GLB (Gateway) |
|--------|-------------------|----------------|----------------|
| Layer | 7 (HTTP/HTTPS) | 4 (TCP/UDP/TLS) | 3 (IP) |
| Routing | Path, host, header, query | Port-based | Transparent |
| Use case | Web apps, APIs, gRPC | Extreme perf, static IP, non-HTTP | Security appliances |
| Static IP | No (use Global Accelerator) | Yes (one per AZ / Elastic IP) | N/A |
| Lambda targets | Yes | No | No |
| Cost | $0.0225/hr + LCU | $0.0225/hr + NLCU | $0.0125/hr + GLCU |

### ALB Cost Optimization

- Consolidate ALBs: host-based routing for multiple services (up to 100 rules)
- Set deregistration delay to 30-60s (default 300s is too high for most apps)
- Enable HTTP/2 for fewer connections and lower LCU

### NLB Strategic Use

Choose NLB when you need: static IP addresses (firewall allowlisting), extreme performance (millions of req/s, ultra-low latency), non-HTTP protocols (TCP/UDP), or VPC PrivateLink provider (only NLB supports this).

**NLB + ALB pattern:** For HTTP workloads needing static IPs, chain NLB -> ALB. Or use AWS Global Accelerator for static IPs with ALB directly.

### Cross-Zone Load Balancing

- **ALB:** Enabled by default, no extra charge
- **NLB:** Disabled by default. When enabled, incurs $0.01/GB inter-AZ. Usually worth it for even distribution.

### Health Check Tuning

- Default: 30s interval, 5 healthy / 2 unhealthy = 60s to detect, 150s to recover
- Aggressive: 10s interval, 2/2 = 20s detection, 20s recovery
- Use lightweight `/health` endpoint checking critical dependencies
- ASG `HealthCheckGracePeriod`: set long enough for app initialization (default 300s)
