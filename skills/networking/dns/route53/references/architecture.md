# Route 53 Architecture Reference

## Hosted Zones

**Public**: anycast-served from AWS edge locations; four nameservers per zone.
**Private**: accessible from associated VPCs only; requires enableDnsHostNames and enableDnsSupport.

## Alias Records

Zone-apex compatible, free queries, auto-updating. Targets: ALB, NLB, CLB, CloudFront, API Gateway, S3, Elastic Beanstalk, VPC Interface Endpoints, Global Accelerator.

## Routing Policies

### Weighted
Weight 0-255 per record. Proportion = weight / sum. Use for A/B testing, canary.

### Latency
Routes to lowest-latency AWS region. Specify region per record.

### Failover (Active/Passive)
PRIMARY + SECONDARY. Health check required on primary.

### Geolocation
Routes by country/continent/US state. Default record required.

### Geoproximity
Distance-based with bias (-99 to +99). Requires Traffic Flow. Positive bias = more traffic.

### IP-Based
CIDR collections with named locations. Routes by client IP CIDR blocks.

### Multivalue Answer
Up to 8 healthy records per query. Not a true load balancer.

## Health Checks

Endpoint: HTTP/HTTPS/TCP, 10s or 30s interval, 1-10 failure threshold, optional string match.
Calculated: AND/OR/NOT of up to 256 child checks.
CloudWatch alarm: for private endpoints. Monitors alarm state.
ARC routing controls: manual/automated DR switching.

## DNSSEC

KSK: customer-managed via KMS (us-east-1, ECC_NIST_P256). ZSK: auto-managed (~7 day rotation).

Enable: create KSK, enable zone DNSSEC, publish DS at registrar. KSK rotation is manual.

Alarms: `DNSSECInternalFailure`, `DNSSECKeySigningKeysNeedingAction`.

## Route 53 Resolver

Inbound endpoints: ENIs in VPC subnets for on-prem to query AWS. 10K QPS per IP.
Outbound endpoints: ENIs for AWS to forward to on-prem.
Rules: FORWARD (domain to IPs), SYSTEM (auto for private zones), auto-defined (catch-all).

## DNS Firewall

Domain lists (managed + custom), rule groups with priority, actions (ALLOW/ALERT/BLOCK).
Managed via Firewall Manager for multi-account. CloudWatch Logs for match events.

## ARC

Readiness checks, routing controls (binary on/off), safety rules, recovery clusters.

## CLI Reference

```bash
aws route53 list-hosted-zones
aws route53 list-resource-record-sets --hosted-zone-id Z123
aws route53 change-resource-record-sets --hosted-zone-id Z123 --change-batch file://changes.json
aws route53 get-dnssec --hosted-zone-id Z123
aws route53 list-health-checks
aws route53resolver list-resolver-endpoints
aws route53resolver list-resolver-rules
aws route53resolver list-firewall-rule-groups
```

## Terraform Resources

Zones: `aws_route53_zone`, Records: `aws_route53_record`, Health checks: `aws_route53_health_check`, DNSSEC: `aws_route53_key_signing_key` + `aws_route53_hosted_zone_dnssec`, Resolver: `aws_route53_resolver_endpoint` + `aws_route53_resolver_rule`, DNS Firewall: `aws_route53_resolver_firewall_rule_group` + association.
