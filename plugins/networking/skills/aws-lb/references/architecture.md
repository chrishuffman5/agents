# AWS Elastic Load Balancing Architecture Reference

## Overview

AWS Elastic Load Balancing (ELB) provides three distinct load balancer types, each optimized for different traffic patterns and use cases. All three are fully managed services with built-in HA, auto-scaling, and AWS integration.

---

## Application Load Balancer (ALB) Architecture

### Request Processing

```
Client HTTPS request
    |
    v
ALB Node (per-AZ)
    |
    +-- TLS termination (ACM certificate)
    +-- WAF evaluation (if attached)
    +-- Listener rule evaluation (priority-ordered)
    |     +-- Rule 1: path=/api/* -> forward to api-tg
    |     +-- Rule 2: host=admin.* -> authenticate(Cognito) + forward to admin-tg
    |     +-- Default: forward to web-tg
    +-- Target group selection
    +-- Load balancing algorithm (round robin or least outstanding requests)
    +-- Target health check (skip unhealthy)
    +-- Forward to target (EC2, IP, Lambda)
```

### ALB Internal Architecture

- ALB provisions **nodes** in each configured AZ
- Each node is an AWS-managed load balancer instance
- Nodes auto-scale based on traffic (transparent to customer)
- DNS name resolves to node IPs (changes as nodes scale)
- Cross-zone load balancing is always enabled (cannot disable on ALB)

### Listener Rules

Rules are evaluated in priority order (1-50000, lowest first):

| Rule Component | Options |
|---|---|
| **Conditions** | path-pattern, host-header, http-header, query-string, source-ip, http-request-method |
| **Actions** | forward, redirect, fixed-response, authenticate-cognito, authenticate-oidc |

Multiple conditions on a single rule use AND logic. Multiple values within a condition use OR logic.

### Sticky Sessions

| Type | Mechanism |
|---|---|
| **Duration-based** | ALB generates `AWSALB` cookie; configurable duration (1s to 7 days) |
| **Application-based** | ALB reads application-generated cookie; routes to same target |

### Connection Handling

- **Idle timeout**: Default 60 seconds; configurable 1-4000 seconds
- **Deregistration delay**: Default 300 seconds; time to drain connections from deregistering target
- **Slow start**: Gradually increase traffic to newly registered targets (0-900 seconds)
- **HTTP/2**: Supported on frontend (client-to-ALB); backend uses HTTP/1.1 by default
- **gRPC**: Full gRPC support including health checks, routing by package/service/method

### WAF Integration

AWS WAF v2 attaches directly to ALB:

- **Managed rule groups**: AWS Managed Rules (OWASP), Bot Control, Account Takeover Prevention
- **Custom rules**: IP set, geo-match, regex pattern, rate-based
- **Rule actions**: Allow, Block, Count, CAPTCHA, Challenge
- **Logging**: WAF logs to CloudWatch, S3, or Kinesis Firehose

### Cognito Authentication

```
Client request -> ALB -> Cognito User Pool
    |
    +-- Unauthenticated: Redirect to Cognito login page
    +-- Authenticated: ALB validates JWT, forwards to target
        +-- Adds headers: x-amzn-oidc-identity, x-amzn-oidc-data
```

### URL and Host Rewrite (2025)

- Regex-based rewrite of request URL path before forwarding
- Host header rewrite for backend routing
- Eliminates need for application-level URL normalization

### Target Optimizer (2025)

- Routes AI/ML inference requests to targets based on concurrency
- Prevents multiple concurrent requests to single-concurrency GPU workers
- Target group attribute: `target_group_health.concurrency_config`

---

## Network Load Balancer (NLB) Architecture

### Packet Processing

```
Client TCP SYN
    |
    v
NLB Node (per-AZ, static IP)
    |
    +-- No L7 inspection (passes TCP/UDP directly)
    +-- Flow hash: src IP, src port, dst IP, dst port, protocol
    +-- Target selection (same flow -> same target for connection duration)
    +-- Health check (is target healthy?)
    +-- Forward to target (preserves client IP by default)
```

### NLB Internal Architecture

- NLB provisions nodes with **static IPs** per AZ
- Optional: assign Elastic IPs for fixed public addresses
- No security groups on NLB itself (traffic passes through)
- Client IP preserved by default (no SNAT for instance targets)
- Handles millions of requests per second with minimal latency

### Static IP and Elastic IP

```
AZ-a: NLB Node IP = 10.0.1.100 (or Elastic IP 203.0.113.10)
AZ-b: NLB Node IP = 10.0.2.100 (or Elastic IP 203.0.113.11)
AZ-c: NLB Node IP = 10.0.3.100 (or Elastic IP 203.0.113.12)
```

Clients can hardcode these IPs in firewall rules or DNS records.

### TLS Handling

| Mode | Description |
|---|---|
| **TLS termination** | NLB terminates TLS; forwards plaintext to targets |
| **TLS passthrough** | NLB forwards encrypted traffic; target handles TLS |
| **mTLS** | Not supported on NLB; use ALB for mTLS |

### PrivateLink Architecture

```
Consumer VPC                         Provider VPC
[Application] -> [VPC Endpoint]  ->  [NLB] -> [Service]
                 (ENI in consumer)
```

- NLB is the required entry point for PrivateLink services
- Consumer creates VPC Endpoint (Interface type) pointing to NLB service
- Traffic stays on AWS backbone (no internet traversal)
- Cross-account and cross-region support

### Weighted Target Groups (Nov 2025)

```
NLB Listener:
  Forward:
    - blue-tg:  weight 90
    - green-tg: weight 10
```

Enables canary and blue/green deployments for TCP services (previously ALB-only feature).

### QUIC Pass-Through

- NLB forwards QUIC (UDP 443) to targets without modification
- Client establishes QUIC/HTTP/3 directly with backend
- Reduces mobile client latency (connection migration, 0-RTT)

---

## Gateway Load Balancer (GWLB) Architecture

### Packet Flow

```
Step 1: Route table directs traffic to GWLB Endpoint
Step 2: GWLB Endpoint forwards to GWLB
Step 3: GWLB encapsulates in GENEVE, sends to appliance
Step 4: Appliance inspects, encapsulates response in GENEVE
Step 5: GWLB decapsulates, forwards to original destination
Step 6: Return traffic follows symmetric path (same appliance)
```

### GENEVE Protocol Details

```
Outer UDP Header:
  Source Port: hash-based (for ECMP)
  Destination Port: 6081

GENEVE Header:
  Version: 0
  Option Length: variable
  Protocol Type: 0x6558 (Transparent Ethernet Bridging)
  VNI: GWLB-assigned
  Options:
    Type: 0x0108 (AWS GWLB)
    Length: variable
    Data: flow metadata (VPC, subnet, ENI, flow hash)

Inner Packet:
  Original IP packet (preserved intact)
```

### Symmetric Hashing

- GWLB uses 5-tuple hash to select appliance target
- **Symmetric**: Forward path (client->server) and return path (server->client) hash to the **same appliance**
- Critical for stateful inspection (firewalls maintain connection state)
- If an appliance fails, flows are redistributed (existing connections may break)

### GWLB Endpoint Architecture

```
Application VPC                     Security VPC
[Workload] <-> [GWLBE]         <-> [GWLB] <-> [Appliance ASG]
               (ENI)                             |
               Route table                       +-- Palo Alto VM
               entry points                      +-- Fortinet VM
               to GWLBE                          +-- Check Point VM
```

- GWLB Endpoints (GWLBEs) are ENIs in the application VPC
- VPC route table entries direct traffic through GWLBEs
- GWLB and appliances can be in a separate "security VPC"
- Cross-account support via PrivateLink

### Appliance Requirements

| Requirement | Detail |
|---|---|
| **GENEVE support** | Must encapsulate/decapsulate GENEVE on UDP 6081 |
| **AWS TLV** | Must handle AWS-specific TLV option class 0x0108 |
| **Health check** | Must respond to GWLB health checks (TCP or HTTP) |
| **Inline mode** | Must forward inspected traffic back to GWLB |

---

## Target Group Deep Dive

### Target Types

| Type | ALB | NLB | GWLB |
|---|---|---|---|
| **Instance** | Yes | Yes | Yes |
| **IP** | Yes | Yes | Yes |
| **Lambda** | Yes | No | No |
| **ALB** | No | Yes | No |

### IP Target Specifics

- Supports private IPs in any VPC (peered or connected via Transit Gateway)
- Supports on-premises IPs (reachable via VPN or Direct Connect)
- ECS Fargate tasks use IP targets (no instance ID)
- EKS pods can be registered as IP targets (AWS VPC CNI)

### Deregistration and Draining

| Parameter | Default | Description |
|---|---|---|
| **Deregistration delay** | 300s | Time to drain existing connections |
| **Connection termination on deregistration** | Disabled | Force-close connections after delay |

### Target Group Attributes

| Attribute | Description |
|---|---|
| `stickiness.enabled` | Enable sticky sessions |
| `stickiness.type` | `lb_cookie` or `app_cookie` |
| `slow_start.duration_seconds` | Gradual traffic ramp-up for new targets |
| `load_balancing.algorithm.type` | `round_robin` or `least_outstanding_requests` |
| `deregistration_delay.timeout_seconds` | Connection draining duration |

---

## Health Check Deep Dive

### ALB Health Check

```
Health Check Request:
  GET /healthz HTTP/1.1
  Host: <target-ip>
  User-Agent: ELB-HealthChecker/2.0

Health Check Response:
  HTTP/1.1 200 OK
  -> Target marked healthy (if threshold met)

  HTTP/1.1 503 Service Unavailable
  -> Target marked unhealthy (if threshold met)
```

### Health Check Parameters

| Parameter | ALB Range | NLB Range |
|---|---|---|
| **Interval** | 5-300s | 10-300s |
| **Timeout** | 2-120s | 2-120s |
| **Healthy threshold** | 2-10 | 2-10 |
| **Unhealthy threshold** | 2-10 | 2-10 |
| **Matcher** | HTTP codes (200-499) | HTTP codes or TCP success |

### Health Check Timing

```
Time to detect unhealthy target:
  = Interval x Unhealthy_Threshold
  = 15s x 3 = 45 seconds (ALB default)
  = 30s x 3 = 90 seconds (NLB default)

Time to restore healthy target:
  = Interval x Healthy_Threshold
  = 15s x 2 = 30 seconds (ALB)
  = 30s x 2 = 60 seconds (NLB)
```

---

## Access Logging

### ALB Access Log Format

Logs written to S3 in space-delimited format:

```
type timestamp elb client:port target:port request_processing_time
target_processing_time response_processing_time elb_status_code
target_status_code received_bytes sent_bytes "request" "user_agent"
ssl_cipher ssl_protocol target_group_arn "trace_id" "domain_name"
"chosen_cert_arn" matched_rule_priority request_creation_time
"actions_executed" "redirect_url" "error_reason"
```

### NLB Access Log Format

NLB logs include connection-level data (not request-level):

```
type version timestamp elb listener client:port destination:port
connection_time tls_handshake_time received_bytes sent_bytes
incoming_tls_alert chosen_cert_arn chosen_cert_serial tls_cipher
tls_protocol_version tls_named_group domain_name alpn_fe_protocol
alpn_be_protocol alpn_client_preference_list
```

---

## Cost Considerations

| LB Type | Pricing Components |
|---|---|
| **ALB** | Hourly charge + LCU (new connections, active connections, processed bytes, rule evaluations) |
| **NLB** | Hourly charge + NLCU (new connections/flows, active connections/flows, processed bytes) |
| **GWLB** | Hourly charge + GLCU (new flows, active flows, processed bytes) |

**Cross-zone data transfer**: NLB and GWLB cross-zone traffic incurs standard inter-AZ data transfer charges. ALB cross-zone is always enabled with no additional charge.

---

## Integration Patterns

### ALB + CloudFront

```
Internet -> CloudFront (CDN) -> ALB (origin) -> Targets
```
- CloudFront caches static content at edge
- ALB handles dynamic requests
- Custom origin header for ALB to verify requests come from CloudFront

### NLB + ALB (Static IP + L7)

```
Internet -> NLB (static IPs) -> ALB (L7 routing, WAF) -> Targets
```
- Clients get fixed IPs (NLB)
- ALB provides L7 features (WAF, Cognito, path routing)
- Register ALB as NLB target (ALB-type target group)

### GWLB + Transit Gateway

```
Spoke VPCs -> Transit Gateway -> Security VPC -> GWLB -> Appliances
```
- Centralized security inspection for all VPC traffic
- Transit Gateway routes traffic through security VPC
- GWLB distributes across appliance fleet
