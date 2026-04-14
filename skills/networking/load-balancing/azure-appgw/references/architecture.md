# Azure Application Gateway V2 Architecture Reference

## Overview

Azure Application Gateway is Microsoft's managed L7 load balancer and WAF. **V2** is the current generation with autoscaling, zone-redundant deployment, and static VIP. **V1 reaches End of Life on April 28, 2026** -- all V1 gateways must be migrated to V2 before this date.

---

## V2 Internal Architecture

### Instance Model

```
Azure Application Gateway V2
    |
    +-- Frontend IP (static VIP)
    |     +-- Public IP (internet-facing)
    |     +-- Private IP (internal only)
    |     +-- Both (dual-frontend)
    |
    +-- Gateway Instances (auto-scaled)
    |     +-- Min instances: 0 (scale to zero)
    |     +-- Max instances: 125
    |     +-- Each instance handles traffic independently
    |     +-- Spread across configured AZs
    |
    +-- Backend Pools
          +-- VMs, VMSS, App Services, AKS, IPs, FQDNs
```

### Capacity Units (CU)

V2 pricing is based on Capacity Units consumed:

| CU Dimension | Measurement |
|---|---|
| **Compute** | ~50 connections/second with TLS (RSA 2048-bit) |
| **Persistent connections** | ~2,500 concurrent connections |
| **Throughput** | ~2.22 Mbps |

The CU count is the **maximum** of compute, persistent connections, and throughput. Billing is based on the higher of fixed CU (minimum instances) or consumed CU.

### Autoscaling

- Scales out when any CU dimension exceeds current capacity
- Scales in during low-traffic periods (down to minimum instance count)
- **Minimum instances**: Set to ensure baseline capacity (recommended: 2+ for production)
- **Maximum instances**: Cap to control costs (max 125)
- Scale-out takes 1-2 minutes; plan for traffic spikes with adequate minimum instances

### Zone Redundancy

- V2 can span **multiple Availability Zones** within a region
- Survives single AZ failure without service interruption
- Zone-redundant deployment requires public IP with Standard SKU and zone configuration
- **Zonal deployment**: Pin to specific AZ (less resilient but may reduce latency)

---

## Networking Architecture

### Subnet Requirements

```
Virtual Network
    |
    +-- Application Gateway Subnet (/24 minimum)
    |     +-- Must be dedicated (no other resources)
    |     +-- NSG must allow GatewayManager (65200-65535 inbound)
    |     +-- NSG must allow AzureLoadBalancer
    |     +-- NSG must allow inbound traffic (80, 443, etc.)
    |     +-- UDR supported (with limitations)
    |
    +-- Backend Subnet(s)
          +-- VMs, VMSS, AKS nodes
```

### NSG Rules Required

| Rule | Direction | Source | Destination | Ports |
|---|---|---|---|---|
| **GatewayManager** | Inbound | GatewayManager | Any | 65200-65535 |
| **AzureLoadBalancer** | Inbound | AzureLoadBalancer | Any | Any |
| **Client traffic** | Inbound | Internet / Custom | Any | 80, 443 (or custom) |
| **Backend probes** | Outbound | App GW subnet | Backend subnet | Backend ports |

### Private Link

- V2 supports Private Link for private frontend access
- Clients in peered VNets or on-premises access App Gateway via Private Endpoint
- Private frontend IP in App Gateway subnet
- Private Endpoint in client VNet

---

## Request Processing Pipeline

```
Client request arrives at Frontend IP
    |
    v
[Listener] -- Match by port + hostname (SNI)
    |
    v
[WAF Policy] -- If associated (Detection or Prevention mode)
    |
    +-- Custom rules evaluated first (priority-ordered)
    +-- Managed rule set evaluation (DRS 2.1/2.2)
    +-- Bot Manager evaluation (if enabled)
    +-- Exclusions applied (skip specific fields)
    |
    v
[Routing Rule] -- Match listener to backend
    |
    +-- Basic rule: Forward to backend pool
    +-- Path-based rule: Evaluate URL path map
    |     +-- /api/* -> api-pool
    |     +-- /web/* -> web-pool
    |     +-- default -> default-pool
    |
    v
[Rewrite Rules] -- Modify request before forwarding
    |
    +-- Header rewrites (add/remove/modify)
    +-- URL path rewrite
    +-- Query string rewrite
    |
    v
[Backend HTTP Settings] -- Configure backend connection
    |
    +-- Protocol (HTTP/HTTPS)
    +-- Port
    +-- Cookie-based affinity
    +-- Connection draining
    +-- Custom probe
    +-- Host name override
    +-- Backend path prefix
    |
    v
[Health Probe] -- Is target healthy?
    |
    +-- Skip unhealthy targets
    |
    v
[Backend Pool Member] -- Forward request
    |
    v
[Response Path]
    +-- Response rewrite rules
    +-- WAF response inspection
    +-- Return to client
```

---

## WAF v2 Deep Dive

### Rule Set Architecture

```
WAF Policy
    |
    +-- Custom Rules (priority-ordered, evaluated FIRST)
    |     +-- Rule 1: Block IP range
    |     +-- Rule 2: Rate limit by client IP
    |     +-- Rule 3: Geo-block specific countries
    |
    +-- Managed Rules (evaluated SECOND)
    |     +-- DRS 2.1 or DRS 2.2
    |     |     +-- REQUEST-911-METHOD-ENFORCEMENT
    |     |     +-- REQUEST-913-SCANNER-DETECTION
    |     |     +-- REQUEST-920-PROTOCOL-ENFORCEMENT
    |     |     +-- REQUEST-921-PROTOCOL-ATTACK
    |     |     +-- REQUEST-930-APPLICATION-ATTACK-LFI
    |     |     +-- REQUEST-931-APPLICATION-ATTACK-RFI
    |     |     +-- REQUEST-932-APPLICATION-ATTACK-RCE
    |     |     +-- REQUEST-933-APPLICATION-ATTACK-PHP
    |     |     +-- REQUEST-941-APPLICATION-ATTACK-XSS
    |     |     +-- REQUEST-942-APPLICATION-ATTACK-SQLI
    |     |     +-- REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION
    |     |     +-- REQUEST-944-APPLICATION-ATTACK-JAVA
    |     |
    |     +-- Bot Manager Rule Set (optional)
    |           +-- BadBots: Block
    |           +-- GoodBots: Allow
    |           +-- UnknownBots: Configurable
    |
    +-- Exclusion Lists
          +-- Per-rule or per-rule-group exclusions
          +-- Prevent false positives for known-safe patterns
```

### DRS 2.1 vs DRS 2.2

| Aspect | DRS 2.1 | DRS 2.2 |
|---|---|---|
| **Base** | OWASP CRS 3.3 | OWASP CRS 3.3.4 |
| **Microsoft additions** | Yes | Yes (refined) |
| **False positive rate** | Low | Lower (improved rules) |
| **New protections** | N/A | Additional patterns for modern attacks |
| **Recommendation** | Current default | Evaluate for new deployments |

### Per-Site WAF Policy

Different WAF policies for different hostnames on the same App Gateway:

```
App Gateway
    |
    +-- Listener: api.example.com
    |     +-- WAF Policy: strict-api-policy (block aggressive)
    |
    +-- Listener: marketing.example.com
    |     +-- WAF Policy: standard-web-policy (moderate)
    |
    +-- Listener: internal.example.com
          +-- WAF Policy: none (internal traffic, no WAF)
```

### Rate Limiting (Custom Rules)

```json
{
  "name": "RateLimitByIP",
  "priority": 10,
  "ruleType": "RateLimitRule",
  "rateLimitDuration": "OneMin",
  "rateLimitThreshold": 100,
  "matchConditions": [
    {
      "matchVariable": "RequestUri",
      "operator": "Contains",
      "matchValues": ["/api/"]
    }
  ],
  "groupByUserSession": [
    {
      "groupByVariables": [
        { "variableName": "ClientAddr" }
      ]
    }
  ],
  "action": "Block"
}
```

### WAF Logging

WAF logs are sent to Azure Diagnostics:

- **Log Analytics workspace** -- Query with KQL for investigation
- **Storage account** -- Long-term retention
- **Event Hub** -- Stream to SIEM (Sentinel, Splunk)

Key log fields:
```
resourceId, operationName, category,
properties.instanceId, properties.clientIp,
properties.requestUri, properties.ruleSetType,
properties.ruleSetVersion, properties.ruleId,
properties.message, properties.action,
properties.site, properties.details.message,
properties.details.data, properties.details.file,
properties.details.line
```

---

## SSL/TLS Architecture

### Certificate Sources

| Source | Management |
|---|---|
| **Key Vault** | Automatic rotation; recommended for production |
| **Direct upload** | Manual certificate management; PFX format |

### Key Vault Integration Details

```
App Gateway (Managed Identity)
    |
    +-- System-assigned or User-assigned managed identity
    +-- Key Vault access policy: Get + List on Secrets and Certificates
    +-- Polling interval: 4 hours
    +-- On new certificate version: automatic rotation
    +-- Certificate format: PFX (PKCS#12) stored as Key Vault secret
```

### SSL Policy Presets

| Preset | Min TLS | Key Features |
|---|---|---|
| **Predefined** (AppGwSslPolicy20220101) | 1.2 | ECDHE + AES-GCM ciphers |
| **PredefinedStrict** (AppGwSslPolicy20220101S) | 1.2 | No CBC ciphers |
| **Custom** | Configurable | Select individual ciphers and min TLS version |
| **CustomV2** | Configurable | TLS 1.3 support + custom cipher selection |

### mTLS Configuration

```
Client Certificate Authentication:
1. Upload trusted client root CA to App Gateway
2. Enable client certificate verification on listener
3. App Gateway validates client certificate against trusted CA
4. Certificate info forwarded to backend via headers:
   - X-Client-Cert-Subject
   - X-Client-Cert-Issuer
   - X-Client-Cert-Serial
   - X-Client-Cert-Fingerprint
```

---

## Rewrite Rules Deep Dive

### Rewrite Rule Sets

Rewrite rule sets are associated with routing rules:

```
Routing Rule -> Rewrite Rule Set
    |
    +-- Rewrite Rule 1 (conditions + actions)
    +-- Rewrite Rule 2 (conditions + actions)
    +-- Rewrite Rule 3 (conditions + actions)
```

### Server Variables

| Variable | Description |
|---|---|
| `var_host` | Request Host header |
| `var_uri` | Request URI (path + query) |
| `var_request_query` | Query string |
| `var_client_ip` | Client IP address |
| `var_client_port` | Client port |
| `var_server_port` | Server port |
| `var_http_status` | Response status code |
| `var_uri_path` | URI path (without query) |
| `add_x_forwarded_for_proxy` | Client IP + existing X-Forwarded-For |

### Rewrite Examples

**Add security headers:**
```
Action: Set response header
  Header: Strict-Transport-Security
  Value: max-age=31536000; includeSubDomains

Action: Set response header
  Header: X-Content-Type-Options
  Value: nosniff
```

**Remove server info:**
```
Action: Delete response header
  Header: Server

Action: Delete response header
  Header: X-Powered-By
```

**URL rewrite:**
```
Condition: var_uri_path matches /old-app/(.*)
Action: Set URL path to /new-app/{var_uri_path_1}
```

---

## Health Probe Deep Dive

### Default Probe Behavior

When no custom probe is configured:

- Protocol: Same as backend HTTP setting
- Host: IP of backend server (or FQDN if configured)
- Path: `/`
- Interval: 30 seconds
- Timeout: 30 seconds
- Unhealthy threshold: 3
- Match: HTTP 200-399

### Custom Probe Configuration

```json
{
  "name": "api-probe",
  "protocol": "Https",
  "host": "api.example.com",
  "path": "/healthz",
  "interval": 15,
  "timeout": 10,
  "unhealthyThreshold": 3,
  "pickHostNameFromBackendHttpSettings": false,
  "match": {
    "statusCodes": ["200"],
    "body": "healthy"
  }
}
```

### Probe Hostname Resolution

| Setting | Behavior |
|---|---|
| **Explicit host** | Probe uses specified hostname |
| **Pick from backend HTTP settings** | Uses hostname from HTTP settings |
| **Pick from backend address** | Uses backend pool member IP/FQDN |

### Backend Health API

```bash
# Check backend health via Azure CLI
az network application-gateway show-backend-health \
  --name my-appgw \
  --resource-group rg-network
```

---

## Integration Patterns

### App Gateway + Azure Front Door

```
Internet -> Azure Front Door (global CDN/WAF) -> App Gateway (regional LB/WAF) -> Backends
```
- Front Door provides global anycast, CDN caching, edge WAF
- App Gateway provides regional L7 routing, backend-specific WAF
- Lock App Gateway to accept traffic only from Front Door (X-Azure-FDID header validation)

### App Gateway Ingress Controller (AGIC)

```
AKS Cluster
    |
    +-- AGIC Pod (watches Ingress resources)
    |     +-- Translates K8s Ingress to App Gateway config
    |     +-- ARM API calls to update App Gateway
    |
    +-- App Gateway (external to cluster)
          +-- Routes traffic to AKS pod IPs
```

- Deployed as AKS add-on or standalone Helm chart
- Supports Ingress resources and custom annotations
- Single App Gateway shared across multiple AKS namespaces

### App Gateway + Application Insights

- Enable Application Insights integration for distributed tracing
- Correlate App Gateway latency with backend application performance
- Transaction search across App Gateway -> Backend -> Dependencies

---

## V1 to V2 Migration Details

### Migration Methods

| Method | Description |
|---|---|
| **AzAppGWMigration** | PowerShell module for automated migration |
| **Manual** | Create new V2, replicate config, switch traffic |
| **Blue-green** | Run V1 and V2 simultaneously; gradual traffic shift |

### AzAppGWMigration Steps

```
1. Test-AzAppGWMigration
   - Validates V1 configuration
   - Identifies unsupported features
   - Reports required manual steps

2. Start-AzAppGWMigration
   - Creates V2 App Gateway in specified subnet
   - Copies: listeners, rules, backend pools, HTTP settings, probes
   - Copies: SSL certificates, WAF configuration
   - Creates new static VIP

3. Post-migration manual steps:
   - Update DNS to new V2 VIP
   - Recreate unsupported features (if any)
   - Configure autoscaling parameters
   - Update NSG rules for V2 requirements
   - Test all routing paths
   - Decommission V1 after validation
```

### V1 Features Not in V2

Most V1 features are available in V2 with improved implementations. Key differences:

| V1 Feature | V2 Equivalent |
|---|---|
| WAF embedded config | Standalone WAF Policy (more flexible) |
| Fixed instance count | Autoscaling (set min/max) |
| Dynamic VIP | Static VIP (improvement) |
| Smaller subnet | /24 required (plan ahead) |

---

## Monitoring and Diagnostics

### Key Metrics (Azure Monitor)

| Metric | Description |
|---|---|
| `TotalRequests` | Total requests processed |
| `FailedRequests` | Requests resulting in error |
| `ResponseStatus` | Response status code distribution |
| `HealthyHostCount` | Healthy backend targets per pool |
| `UnhealthyHostCount` | Unhealthy backend targets per pool |
| `BackendConnectTime` | Time to establish backend connection |
| `BackendFirstByteResponseTime` | Time to first byte from backend |
| `BackendLastByteResponseTime` | Time to last byte from backend |
| `CurrentConnections` | Active connections |
| `CapacityUnits` | Consumed capacity units |
| `ComputeUnits` | Consumed compute units |
| `EstimatedBilledCapacityUnits` | Estimated billing CU |

### Diagnostic Logs

| Log Category | Contents |
|---|---|
| `ApplicationGatewayAccessLog` | Per-request access log (client IP, URI, status, latency) |
| `ApplicationGatewayPerformanceLog` | Performance metrics per instance |
| `ApplicationGatewayFirewallLog` | WAF rule match details |

### KQL Queries for Troubleshooting

```kql
// Top WAF blocked rules
AzureDiagnostics
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| summarize count() by ruleId_s, ruleGroup_s
| order by count_ desc
| take 10

// Backend health over time
AzureDiagnostics
| where Category == "ApplicationGatewayAccessLog"
| summarize avg(timeTaken_d) by bin(TimeGenerated, 5m), backendPool_s
| render timechart

// 5xx errors by backend
AzureDiagnostics
| where Category == "ApplicationGatewayAccessLog"
| where httpStatus_d >= 500
| summarize count() by serverRouted_s, httpStatus_d
| order by count_ desc
```
