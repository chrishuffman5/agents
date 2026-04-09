# AWS Route 53 — Deep Dive Research

**Sources:** AWS Documentation (docs.aws.amazon.com), AWS Blogs, AWS re:Post  
**Last updated:** April 2026  
**Service:** Amazon Route 53 (DNS and Health Checking)

---

## Architecture Overview

Amazon Route 53 is AWS's highly available, scalable cloud DNS service. It operates across hundreds of AWS edge locations and provides three core capabilities:

1. **Domain registration** — Register and manage domain names
2. **DNS routing (hosted zones)** — Authoritative DNS service for your domains
3. **Health checking** — Monitor resource health and enable DNS failover

Route 53 uses anycast routing to serve DNS queries from the nearest edge location. Each hosted zone is served by four Route 53 nameservers assigned at zone creation (e.g., `ns-123.awsdns-45.com`, `ns-456.awsdns-12.net`).

---

## Hosted Zones

### Public Hosted Zones

- Route internet traffic to public resources
- Accessible from anywhere on the internet
- Assigned four Route 53 name servers automatically
- Support all Route 53 record types and routing policies
- Support DNSSEC signing

### Private Hosted Zones

- Route traffic within one or more Amazon VPCs
- Accessible only from associated VPCs
- Requires `enableDnsHostNames` and `enableDnsSupport` enabled on the VPC
- Cross-account VPC association: `aws route53 associate-vpc-with-hosted-zone`
- VPC peering does not automatically share private hosted zone DNS — must explicitly associate

```bash
# Create public hosted zone
aws route53 create-hosted-zone \
    --name example.com \
    --caller-reference $(date +%s)

# Create private hosted zone associated with a VPC
aws route53 create-hosted-zone \
    --name internal.example.com \
    --caller-reference $(date +%s) \
    --vpc VPCRegion=us-east-1,VPCId=vpc-12345678
```

---

## Record Types

Route 53 supports all standard DNS record types:

| Type | Use |
|---|---|
| A | IPv4 address |
| AAAA | IPv6 address |
| CNAME | Canonical name (cannot be at zone apex) |
| MX | Mail exchange |
| NS | Name server |
| TXT | Text records (SPF, DKIM, domain verification) |
| SRV | Service locator |
| PTR | Reverse lookup (in reverse zones) |
| SOA | Start of authority (auto-managed by Route 53) |
| CAA | Certificate Authority Authorization |
| DS | DNSSEC delegation signer |
| NAPTR | Name Authority Pointer (SIP, telephony) |

### Alias Records (Route 53 Extension)

Alias records are a Route 53-specific extension that function like CNAME but with key differences:

- **Can be used at the zone apex** (e.g., `example.com` directly) — unlike CNAME
- **Free queries** — no charge for DNS queries to AWS resource aliases
- **Auto-updates** — automatically reflects IP changes for the target AWS resource
- **Cannot set custom TTL** — TTL is inherited from the target

Supported alias targets:
- Elastic Load Balancers (ALB, NLB, CLB)
- CloudFront distributions
- API Gateway endpoints
- S3 static website endpoints
- Elastic Beanstalk environments
- VPC Interface Endpoints
- Global Accelerator
- Other Route 53 records in the same hosted zone

```bash
# Create alias record pointing to an ALB
aws route53 change-resource-record-sets \
    --hosted-zone-id Z1234567890 \
    --change-batch '{
        "Changes": [{
            "Action": "CREATE",
            "ResourceRecordSet": {
                "Name": "example.com",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "Z35SXDOTRQ7X7K",
                    "DNSName": "my-alb-123456.us-east-1.elb.amazonaws.com",
                    "EvaluateTargetHealth": true
                }
            }
        }]
    }'
```

---

## Routing Policies

### Simple Routing

- Returns all values in the record set
- No health check integration (single record set can have multiple IPs, returned in random order)
- Use for: single resource, no need for routing logic

### Weighted Routing

- Distributes traffic proportionally across multiple records
- Weight values: 0-255; traffic proportion = (record weight) / (sum of all weights)
- Weight 0 = no traffic (but still present); all zeros = equal distribution
- Use for: A/B testing, canary deployments, gradual traffic shifts

```bash
# 90% to v1, 10% to v2
aws route53 change-resource-record-sets --hosted-zone-id Z123 \
    --change-batch '{
        "Changes": [
            {"Action":"CREATE","ResourceRecordSet":{"Name":"api.example.com","Type":"A","SetIdentifier":"v1","Weight":90,"TTL":60,"ResourceRecords":[{"Value":"1.2.3.4"}]}},
            {"Action":"CREATE","ResourceRecordSet":{"Name":"api.example.com","Type":"A","SetIdentifier":"v2","Weight":10,"TTL":60,"ResourceRecords":[{"Value":"1.2.3.5"}]}}
        ]
    }'
```

### Latency-Based Routing

- Routes to the AWS region with the lowest measured latency for the client
- Latency measurements are maintained by AWS based on historical data
- Requires specifying an AWS region per record
- Use for: multi-region deployments where you want lowest-latency routing

### Failover Routing (Active/Passive)

- Primary record served when healthy; secondary served when primary fails
- Requires health checks on at least the primary record
- `PRIMARY` and `SECONDARY` designations per failover record set
- Use for: disaster recovery, active/passive DR architectures

```bash
# Primary record with health check
aws route53 change-resource-record-sets --hosted-zone-id Z123 \
    --change-batch '{
        "Changes": [{
            "Action": "CREATE",
            "ResourceRecordSet": {
                "Name": "app.example.com",
                "Type": "A",
                "SetIdentifier": "primary",
                "Failover": "PRIMARY",
                "HealthCheckId": "abc12345",
                "TTL": 60,
                "ResourceRecords": [{"Value": "1.2.3.4"}]
            }
        }]
    }'
```

### Geolocation Routing

- Routes based on the geographic origin of the DNS query (country, continent, or US state)
- Granularity: Continent → Country → US State
- Default record required as fallback for unmatched locations
- Use for: content localization, compliance (data sovereignty), language-specific routing

Supported geographic identifiers: Continent codes (AF, AN, AS, EU, OC, NA, SA), ISO country codes, US state codes.

### Geoproximity Routing

- Routes based on geographic location of resources and optionally users
- Can specify AWS regions OR custom latitude/longitude coordinates for non-AWS resources
- **Bias** value (-99 to +99): positive bias expands the effective "pull" area of a resource; negative shrinks it
  - Bias +50 → halves the measured distance (routes more traffic to this resource)
  - Bias -50 → doubles the measured distance (routes less traffic)
- Requires Route 53 Traffic Flow to configure
- Use for: nuanced geographic distribution beyond simple closest-resource

### Multivalue Answer Routing

- Returns up to 8 healthy records selected randomly per DNS query
- Each record can have an associated health check
- Unhealthy records are excluded from responses
- Not a true load balancer — clients choose from returned values
- Use for: simple client-side load balancing with health awareness

### IP-Based Routing (CIDR-based)

Introduced to Route 53, IP-based routing routes traffic based on the client's IP address using CIDR blocks.

- Create CIDR collections with named CIDR location groups
- Map CIDR blocks to locations (IPv4: /1 to /24, IPv6: /1 to /48)
- Create records with `CidrRoutingConfig` referencing the CIDR collection and location
- Use for: routing ISP traffic to specific endpoints, region-aware routing without relying on geolocation databases

```bash
# Create a CIDR collection
aws route53 create-cidr-collection --name "my-cidrs" --caller-reference $(date +%s)

# Change CIDR blocks in the collection
aws route53 change-cidr-collection --id <collection-id> \
    --changes '[{"Location":{"LocationName":"us-east-users"},"CidrList":["1.2.3.0/24","1.2.4.0/24"]}]'
```

---

## Health Checks

Route 53 health checkers are distributed globally. Checks are sent periodically (every 10 or 30 seconds); Route 53 does NOT check health at query time.

### Health Check Types

**Endpoint monitoring:**
- HTTP (port 80), HTTPS (port 443), TCP
- Checks IP address or domain name
- For HTTP/HTTPS: can validate response body contains a specific string (up to 5120 bytes)
- `Request interval`: Standard (30s) or Fast (10s)
- `Failure threshold`: 1-10 consecutive failures before marking unhealthy

**Calculated health checks:**
- Combines multiple health checks using AND, OR, or NOT logic
- Up to 256 child health checks
- Use for: complex health logic (e.g., "at least 2 of 3 endpoints healthy")

**CloudWatch alarm-based:**
- Monitors a CloudWatch alarm state (OK, ALARM, INSUFFICIENT_DATA)
- Enables health checking for private endpoints (which Route 53 health checkers cannot access directly)
- Use for: RDS, private EC2, or any resource not publicly accessible

**Routing control health checks (Application Recovery Controller):**
- Health check state is controlled manually or via ARC automation
- Enables precise traffic control for DR failover scenarios
- Integrates with ARC recovery clusters

### Private Endpoint Health Checks

Route 53 health checkers cannot reach private endpoints. Solution:
1. Create a CloudWatch metric/alarm that monitors the private endpoint
2. Create a Route 53 health check that monitors the CloudWatch alarm state
3. Associate this health check with your Route 53 record

### Health Check Monitoring and Notifications

- View health status in Route 53 console or via API
- CloudWatch metrics available for each health check: `HealthCheckStatus`, `HealthCheckPercentageHealthy`
- Set CloudWatch alarms on these metrics for notifications

---

## DNSSEC

### Architecture

Route 53 uses a split KSK/ZSK model:
- **KSK (Key Signing Key)** — customer-managed, based on AWS KMS asymmetric key
- **ZSK (Zone Signing Key)** — automatically managed and rotated by Route 53 (~every 7 days)

### KMS Key Requirements

The KMS key for KSK must:
- Be in **us-east-1 (N. Virginia)** region regardless of hosted zone region
- Be an asymmetric key with **ECC_NIST_P256** key spec
- Have appropriate key policy granting Route 53 signing permissions

### Enabling DNSSEC Signing

```bash
# Step 1: Create the KSK (linked to KMS key)
aws route53 create-key-signing-key \
    --hosted-zone-id Z1234567890 \
    --key-management-service-arn arn:aws:kms:us-east-1:123456789:key/12345-abcd \
    --name my-ksk \
    --status ACTIVE \
    --caller-reference $(date +%s) \
    --region us-east-1

# Step 2: Enable DNSSEC signing on the hosted zone
aws route53 enable-hosted-zone-dnssec \
    --hosted-zone-id Z1234567890 \
    --region us-east-1

# Step 3: Get DS record to add at registrar
aws route53 get-dnssec \
    --hosted-zone-id Z1234567890
```

### Establishing Chain of Trust

After enabling signing, publish the DS record at the domain registrar:
- If registered with Route 53: Route 53 console provides one-click DS record publication
- If registered elsewhere: copy DS record values from `get-dnssec` output and add manually at registrar

### Important Constraints

- TTL maximum is automatically limited to **1 week** when DNSSEC is enabled
- Multi-provider configurations (white-label nameservers from multiple providers) not supported
- Verify TLD supports DNSSEC before enabling
- Set up CloudWatch alarms for `DNSSECInternalFailure` and `DNSSECKeySigningKeysNeedingAction`

### KSK Rotation

KSK does NOT automatically rotate. Manual rotation process:
1. Create a new KSK (status INACTIVE)
2. Activate the new KSK
3. Wait for new DNSKEY to propagate (per DNSKEY TTL)
4. Update DS record at registrar with new KSK's DS record
5. Wait for old DS to expire from caches
6. Deactivate old KSK
7. Delete old KSK

### Terraform

```hcl
resource "aws_kms_key" "dnssec" {
  description              = "Route 53 DNSSEC KSK"
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  deletion_window_in_days  = 7
  provider                 = aws.us_east_1  # Must be us-east-1
}

resource "aws_route53_key_signing_key" "example" {
  hosted_zone_id             = aws_route53_zone.example.id
  key_management_service_arn = aws_kms_key.dnssec.arn
  name                       = "example-ksk"
}

resource "aws_route53_hosted_zone_dnssec" "example" {
  hosted_zone_id = aws_route53_key_signing_key.example.hosted_zone_id
  depends_on     = [aws_route53_key_signing_key.example]
}
```

---

## Route 53 Resolver

### Overview

Route 53 Resolver is the regional recursive DNS service in AWS. It automatically answers DNS queries for:
- EC2 instance names
- Private hosted zones associated with the VPC
- Public internet names (via recursive resolution)

Resolver endpoint capacity: 10,000 queries per second per IP endpoint.

### Inbound Endpoints (On-Premises → AWS)

Allow on-premises DNS resolvers to forward queries to AWS:
- Creates ENIs in specified VPC subnets
- On-premises DNS server forwards specific domains to the inbound endpoint IP
- Resolves AWS resources (EC2, RDS, private hosted zones)

```bash
aws route53resolver create-resolver-endpoint \
    --creator-request-id $(date +%s) \
    --security-group-ids sg-12345678 \
    --direction INBOUND \
    --ip-addresses SubnetId=subnet-111,Ip=10.0.1.10 SubnetId=subnet-222,Ip=10.0.2.10
```

### Outbound Endpoints (AWS → On-Premises)

Allow VPC DNS to forward queries to on-premises resolvers:
- Creates ENIs in specified VPC subnets
- Forward rules specify which domains go to which on-premises IPs
- Useful for Active Directory, on-premises resources

```bash
aws route53resolver create-resolver-endpoint \
    --creator-request-id $(date +%s) \
    --security-group-ids sg-12345678 \
    --direction OUTBOUND \
    --ip-addresses SubnetId=subnet-111 SubnetId=subnet-222
```

### Resolver Rules

Three types:
- **Forward rules** — Forward specified domain queries to specified IPs
- **System rules** — Auto-defined rules for private hosted zones and AWS endpoints
- **Auto-defined system rules** — Catch-all for everything else

Rule priority: Most specific match wins.

```bash
aws route53resolver create-resolver-rule \
    --creator-request-id $(date +%s) \
    --rule-type FORWARD \
    --domain-name corp.example.com \
    --resolver-endpoint-id rslvr-out-12345 \
    --target-ips Ip=10.0.1.53,Port=53 Ip=10.0.2.53,Port=53
```

---

## DNS Firewall

Route 53 Resolver DNS Firewall filters outbound DNS queries from VPCs. Primary use: prevent DNS exfiltration (data exfiltration via DNS lookups from compromised instances).

### Components

**Domain Lists:**
- Managed domain lists (AWS-maintained threat intelligence)
- Custom domain lists (admin-defined)
- Supports wildcard patterns (`*.example.com`)

**Rule Groups:**
- Contain ordered rules, each referencing a domain list with an action
- Rule groups are reusable across multiple VPCs
- Priority determines evaluation order

**Actions:**
- `ALLOW` — Allow query to proceed
- `ALERT` — Allow but log the match
- `BLOCK` — Block the query; return NXDOMAIN, NODATA, or override DNS response

**Filtering strategies:**
- Deny-known-bad: Block malicious domains; allow everything else (default approach)
- Allow-list: Block everything except explicitly trusted domains (high-security environments)

### Configuration

```bash
# Create a custom domain list
aws route53resolver create-firewall-domain-list \
    --creator-request-id $(date +%s) \
    --name "malicious-domains"

# Add domains to the list
aws route53resolver update-firewall-domains \
    --firewall-domain-list-id rslvr-fdl-12345 \
    --operation ADD \
    --domains "malicious-c2.com" "*.evil-domain.net"

# Create a rule group
aws route53resolver create-firewall-rule-group \
    --creator-request-id $(date +%s) \
    --name "my-dns-firewall"

# Add rule to the rule group
aws route53resolver create-firewall-rule \
    --creator-request-id $(date +%s) \
    --firewall-rule-group-id rslvr-frg-12345 \
    --firewall-domain-list-id rslvr-fdl-12345 \
    --priority 100 \
    --action BLOCK \
    --block-response NXDOMAIN \
    --name "block-malicious"

# Associate rule group with a VPC
aws route53resolver associate-firewall-rule-group \
    --creator-request-id $(date +%s) \
    --firewall-rule-group-id rslvr-frg-12345 \
    --vpc-id vpc-12345678 \
    --priority 101 \
    --name "my-vpc-dns-firewall"
```

### Integration with AWS Services

- **AWS Firewall Manager** — Centrally manage DNS Firewall rule groups across AWS Organizations accounts
- **AWS Network Firewall** — Complementary layer for network/application traffic (different path than DNS)
- **Security Hub** — DNS Firewall findings can be surfaced in Security Hub
- **CloudWatch Logs** — Log DNS Firewall match events for analysis

---

## Route 53 Profiles

Route 53 Profiles allow sharing of Route 53 configurations (hosted zone associations, Resolver rules, DNS Firewall associations) across multiple VPCs and AWS accounts.

- Create a Profile containing configurations
- Associate Profile with VPCs in same or different accounts (via RAM — Resource Access Manager)
- Simplifies multi-VPC, multi-account DNS standardization
- Useful for Landing Zone / Control Tower environments

---

## Application Recovery Controller (ARC)

ARC provides fine-grained DNS-based traffic control for multi-region disaster recovery.

### Components

**Readiness Checks** — Continuously validate that recovery environments are properly scaled and configured.

**Routing Controls** — Binary on/off switches that update Route 53 health check states:
- Backed by Route 53 ARC routing control health checks
- State changes routed through highly available ARC control plane (5-region cluster)
- Supports safety rules (minimum number of controls in ON state)

**Recovery Clusters** — Distributed control plane for routing control state changes.

```bash
# Toggle a routing control (shift traffic)
aws route53-recovery-cluster update-routing-control-state \
    --routing-control-arn arn:aws:route53-recovery-control::123:routingcontrol/abc \
    --routing-control-state On
```

**2026 ARC updates:**
- Region Switch capability with post-recovery workflows
- Native RDS orchestration blocks in Region Switch
- Terraform AWS provider support for ARC resources

---

## CLI and Terraform Reference

### Key AWS CLI Commands

```bash
# List hosted zones
aws route53 list-hosted-zones

# List records in a zone
aws route53 list-resource-record-sets --hosted-zone-id Z123

# Create/update/delete records
aws route53 change-resource-record-sets --hosted-zone-id Z123 --change-batch file://changes.json

# Check DNSSEC status
aws route53 get-dnssec --hosted-zone-id Z123

# List health checks
aws route53 list-health-checks

# Create health check
aws route53 create-health-check --caller-reference $(date +%s) \
    --health-check-config file://health-check.json

# List Resolver endpoints
aws route53resolver list-resolver-endpoints

# List Resolver rules
aws route53resolver list-resolver-rules

# List DNS Firewall rule groups
aws route53resolver list-firewall-rule-groups
```

### Terraform Resources

```hcl
# Hosted zone
resource "aws_route53_zone" "example" {
  name = "example.com"
}

# Private hosted zone
resource "aws_route53_zone" "internal" {
  name = "internal.example.com"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}

# A record
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.example.zone_id
  name    = "www"
  type    = "A"
  ttl     = 300
  records = ["1.2.3.4"]
}

# Alias record (zone apex)
resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.example.zone_id
  name    = ""
  type    = "A"
  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Weighted routing
resource "aws_route53_record" "weighted_primary" {
  zone_id        = aws_route53_zone.example.zone_id
  name           = "api.example.com"
  type           = "A"
  set_identifier = "primary"
  ttl            = 60
  records        = ["1.2.3.4"]
  weighted_routing_policy {
    weight = 90
  }
}

# Failover routing
resource "aws_route53_record" "failover_primary" {
  zone_id        = aws_route53_zone.example.zone_id
  name           = "app.example.com"
  type           = "A"
  set_identifier = "primary"
  ttl            = 60
  records        = ["1.2.3.4"]
  health_check_id = aws_route53_health_check.primary.id
  failover_routing_policy {
    type = "PRIMARY"
  }
}

# Geoproximity (requires Traffic Flow)
resource "aws_route53_traffic_policy" "geo" {
  name    = "geo-proximity"
  comment = "Geoproximity routing"
  document = jsonencode({
    AWSPolicyFormatVersion = "2015-10-01"
    RecordType = "A"
    Endpoints = {
      us-east = { Type = "value", Value = "1.2.3.4" }
      eu-west = { Type = "value", Value = "5.6.7.8" }
    }
    Rules = {
      main = {
        RuleType = "geo proximity"
        GeoproximityLocations = [
          { Region = "us-east-1", EndpointReference = "us-east", Bias = 0 },
          { Region = "eu-west-1", EndpointReference = "eu-west", Bias = 0 }
        ]
      }
    }
    StartRule = "main"
  })
}

# Health check
resource "aws_route53_health_check" "primary" {
  fqdn              = "www.example.com"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "primary-health-check"
  }
}

# Resolver inbound endpoint
resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "inbound"
  direction = "INBOUND"
  security_group_ids = [aws_security_group.dns.id]
  ip_address {
    subnet_id = aws_subnet.a.id
  }
  ip_address {
    subnet_id = aws_subnet.b.id
  }
}

# DNS Firewall rule group
resource "aws_route53_resolver_firewall_rule_group" "example" {
  name = "example-dns-firewall"
}

resource "aws_route53_resolver_firewall_rule_group_association" "vpc" {
  name                   = "example-association"
  firewall_rule_group_id = aws_route53_resolver_firewall_rule_group.example.id
  priority               = 101
  vpc_id                 = aws_vpc.main.id
}
```

---

## References

- [Amazon Route 53 Developer Guide](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/)
- [Choosing a Routing Policy — Route 53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html)
- [DNS Firewall — Route 53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-dns-firewall.html)
- [Configuring DNSSEC Signing — Route 53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec.html)
- [KMS Key and ZSK Management — Route 53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-zsk-management.html)
- [IP-Based Routing — Route 53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-ipbased.html)
- [ARC Region Switch February 2026 Update](https://aws.amazon.com/about-aws/whats-new/2026/02/arc-region-switch-post-recovery-rdsblock/)
- [Introducing IP-Based Routing — AWS Blog](https://aws.amazon.com/blogs/networking-and-content-delivery/introducing-ip-based-routing-for-amazon-route-53/)
