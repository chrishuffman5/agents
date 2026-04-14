# ThousandEyes Architecture Reference

## Platform Overview

Cisco ThousandEyes is a SaaS-based synthetic monitoring and internet intelligence platform. It uses distributed agent probes to actively test network paths and application availability from multiple vantage points.

### Core Principle
ThousandEyes measures the network from the **outside in** -- rather than polling device metrics (SNMP), it probes end-to-end paths and application endpoints to measure what users actually experience. This is complementary to, not a replacement for, traditional NMS.

## Agent Architecture

### Cloud Agents
- **Count**: 1,057+ globally distributed vantage points across 271 cities
- **Hosting**: Deployed in Tier 1/2/3 ISP networks, broadband providers, major cloud regions (AWS, Azure, GCP)
- **Management**: Fully managed by Cisco; no customer operational burden
- **Capabilities**: Run all test types except Voice/RTP; execute path visualization probes
- **Limitations**: Cannot access private/internal networks; external perspective only
- **Selection**: When creating a test, choose Cloud Agents by geography, ISP, or cloud region to match your user base

### Enterprise Agents

#### Deployment Options
| Platform | Method | Use Case |
|---|---|---|
| Linux VM | OVA/ISO/package install | Data center, private cloud |
| Docker | Container image | Kubernetes, container platforms |
| Cisco IOS XE | Native integration | SD-WAN routers (no extra hardware) |
| Physical appliance | Cisco-provided device | Branch offices without VMs |

#### Requirements
- Outbound HTTPS (443) to ThousandEyes SaaS platform
- DNS resolution for ThousandEyes endpoints
- Resources: 2 vCPU, 2 GB RAM minimum (varies with test count)
- Network access to test targets (internal or external)

#### SD-WAN Integration
- ThousandEyes agent embedded in Cisco IOS XE 17.x+
- Configured via vManage feature template or CLI
- Agent runs in a Linux container (LXC) on the router
- Monitors from the branch perspective through SD-WAN tunnels
- Provides both overlay (tunnel) and underlay (WAN link) visibility

### Endpoint Agents

#### Architecture
- Browser extension (Chrome, Edge) + system agent
- Lightweight: minimal CPU/memory footprint
- Data collection modes:
  - **Scheduled tests**: Run defined tests at intervals (like Enterprise Agent)
  - **Browser triggers**: Activate when user visits monitored URLs
  - **Automated Session Tests (AST)**: Background HTTP tests without browser

#### Data Collected
- HTTP page load performance (waterfall timing)
- Network path to destination (traceroute-based)
- WiFi signal strength, channel, AP details
- VPN connection status and performance
- System metrics (CPU, memory, network interface)
- DNS resolution for visited domains

#### Privacy
- Configurable collection windows (business hours only)
- URL filtering: only collect data for defined domains
- No content capture (headers/body not collected unless configured)
- Data ownership: customer owns all data; Cisco processes only

## Test Architecture

### HTTP Server Test
- Sends HTTP/HTTPS request to target URL
- Measures:
  - DNS resolution time
  - TCP connect time
  - SSL/TLS handshake time (HTTPS)
  - Wait time (time to first byte)
  - Transfer time (time to receive full response)
  - Total response time
  - HTTP response code
  - SSL certificate validity and expiration
- Configurable: custom headers, body, auth, redirect follow, content verification (regex)

### Page Load Test
- Launches headless Chromium browser
- Loads full page including all resources (JS, CSS, images, fonts, XHR)
- Measures:
  - DOM load time
  - Page load time (window.onload)
  - Individual component load times (waterfall)
  - Component count by type and domain
  - Error count (failed resource loads)
- Configurable: custom headers, auth, viewport size

### Web Transaction Test
- Selenium-compatible scripted browser automation
- Multi-step user journeys: login, navigate, fill forms, click buttons, verify content
- Measures per-step timing, overall transaction time, success/failure
- Uses ThousandEyes Recorder (Chrome extension) for script creation
- Configurable: step-level screenshots, markers, assertions

### DNS Server Test
- Queries a specific DNS server for a record
- Measures: resolution time, answer correctness, DNSSEC chain validation
- Supports: A, AAAA, CNAME, MX, NS, PTR, SOA, SRV, TXT records
- Use cases: verify DNS server performance, detect DNS hijacking, validate DNSSEC

### DNS Trace Test
- Traces the full recursive resolution path from root to authoritative
- Reveals: delegation chain, glue records, DNSSEC chain, all nameservers involved
- Measures per-server response time at each delegation level
- Use cases: debug delegation issues, identify slow authoritative servers

### BGP Test
- Monitors BGP routing table entries from ThousandEyes BGP monitors
- BGP monitors peer with major route collectors and ISP routers globally
- Detects:
  - Prefix reachability (is your prefix visible from all vantage points?)
  - AS path changes (routing changes that may affect traffic path)
  - Prefix hijacking (unexpected origin AS)
  - Route leaks (unexpected AS in path)
  - RPKI validation status

### Network Test (ICMP/TCP)
- **ICMP mode**: Ping-based measurement (latency, jitter, packet loss)
- **TCP mode**: TCP SYN/ACK timing to specific port
- Both modes include path visualization (traceroute-based hop discovery)
- Measures: end-to-end latency, jitter, packet loss, MTU

### API Test
- REST API endpoint testing
- Configurable: HTTP method, headers, body, assertions on response (status code, JSON path, response time)
- Multi-step API workflows supported
- Use cases: monitor API availability, verify response correctness, track performance trends

### Voice Test (RTP Stream)
- Simulates VoIP call between two Enterprise Agents
- Measures: MOS (Mean Opinion Score), jitter, packet loss, latency
- Uses RTP protocol with configurable codec (G.711, G.729)
- Requires two Enterprise Agents (caller and callee)
- Use cases: VoIP quality monitoring, UC platform health

## Path Visualization

### How It Works
1. Agent sends TCP or ICMP probes with incrementing TTL values
2. Each hop returns ICMP Time Exceeded or TCP RST
3. Agent measures round-trip time to each hop
4. Multiple rounds detect path changes and ECMP
5. Hops annotated with WHOIS data (owning organization/ISP)
6. BGP route data overlaid to show AS-level path

### Data Points Per Hop
- IP address
- DNS reverse lookup (hostname)
- Owning organization (WHOIS/BGP)
- AS number
- Latency (min/avg/max)
- Packet loss percentage
- MPLS labels (if present)
- Geographic location

### Path Analysis Capabilities
- **Forward and reverse path**: Some tests show bidirectional paths
- **ECMP detection**: Multiple paths shown when load balancing is present
- **Historical paths**: Compare current path with paths from minutes/hours/days ago
- **Topology grouping**: Group hops by organization/ISP for high-level view
- **SD-WAN layers**: Enterprise Agents on SD-WAN show overlay tunnel and underlay WAN path separately

## Internet Insights

### Data Source
- Aggregate signal from ALL ThousandEyes Cloud Agents worldwide
- When multiple agents in different networks see failures to the same destination/network, ThousandEyes identifies a correlated outage

### Outage Detection
- **Application outage**: Multiple agents fail HTTP/HTTPS tests to the same destination
- **Network outage**: Multiple agents show path failures through the same network
- **DNS outage**: Multiple agents fail DNS resolution via the same provider

### Coverage Packages
| Package | What It Covers |
|---|---|
| ISP | Transit providers, backbone networks |
| CDN | Content delivery networks (Akamai, Cloudflare, Fastly) |
| DNS | Public DNS providers (Cloudflare DNS, Google DNS, etc.) |
| IaaS | Cloud providers (AWS, Azure, GCP) |
| SECaaS | Security service providers (Zscaler, Palo Alto Prisma) |
| UCaaS | UC platforms (Zoom, Teams, Webex) |

### Geographic Coverage
- North America, EMEA, APAC, LATAM
- Each geography x provider type is a separate license package
- **Global Insights Bundle**: All packages, all geographies

### Outage Timeline
When an outage is detected:
1. **Start time**: When correlated failures first observed
2. **Scope**: Which networks/prefixes affected, geographic extent
3. **Peak**: Maximum impact point
4. **Resolution**: When correlated failures clear
5. **Affected tests**: Which of YOUR tests were impacted by this outage

## Alerting Architecture

### Alert Rule Types
- **Threshold**: Static value comparison (e.g., response time > 500ms)
- **Compound**: Multiple conditions combined (e.g., loss > 5% AND latency > 200ms)
- **Test-level**: Apply to all agents in a test
- **Agent-specific**: Alert only when specific agents see the issue

### Alert Evaluation
- Evaluated after each test round completes
- **Number of rounds**: Require N consecutive rounds exceeding threshold before alerting (dampening)
- **Number of agents**: Require N out of M agents to see the issue (prevents single-agent noise)

### Notification Integrations
| Integration | Method |
|---|---|
| Email | SMTP |
| PagerDuty | API integration |
| Slack | Webhook |
| Microsoft Teams | Webhook |
| ServiceNow | API integration |
| Webhook | Generic HTTP POST |
| Syslog | UDP/TCP syslog |

## API Architecture

### REST API v7
- Base URL: `https://api.thousandeyes.com/v7/`
- Authentication: OAuth2 Bearer token or Basic Auth (email + API token)
- Rate limiting: Per-endpoint limits; 429 response with retry-after header
- Pagination: Link headers for multi-page results

### Key Resources
| Resource | Operations |
|---|---|
| /tests | CRUD for all test types |
| /test-results | Read test results (metrics, path-vis, BGP) |
| /agents | List Cloud and Enterprise agents |
| /alert-rules | CRUD for alert rules |
| /alerts | Read active and historical alerts |
| /internet-insights/outages | Read Internet Insights outage data |
| /dashboards | CRUD for dashboards |
| /endpoint-agents | List and manage Endpoint agents |

### Streaming API
- Webhook-based real-time data delivery
- Events: test results, alerts, agent status changes
- Use cases: real-time dashboards, event-driven automation

## Snapshot Sharing

### Concept
- Point-in-time capture of test results, path visualization, and metrics
- Shareable via URL; viewer does not need ThousandEyes login
- Includes all visualization data (path-vis, waterfall, metrics) at the captured moment
- Configurable expiration (24 hours to permanent)

### Use Cases
- Share network proof with ISP for SLA claims
- Attach to incident tickets as evidence
- Cross-team collaboration (share with app team, ISP NOC)
- Historical reference for post-incident reviews
