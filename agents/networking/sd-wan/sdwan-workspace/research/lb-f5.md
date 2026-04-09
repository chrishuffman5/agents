# F5 BIG-IP — Deep Dive Reference

> Last updated: April 2026 | Covers BIG-IP 17.1.x / BIG-IQ 8.x / F5 Distributed Cloud

---

## 1. Architecture Overview

F5 BIG-IP is a full-proxy application delivery platform. Traffic passes through BIG-IP, which terminates connections on both client and server sides, enabling deep inspection and manipulation at every layer.

### 1.1 Core Architecture

**TMM (Traffic Management Microkernel)**
- Custom high-performance packet processing engine (not Linux kernel networking)
- Handles all traffic: SSL termination, load balancing, iRules, persistence, compression, caching
- Runs as a userspace process; bypasses kernel network stack for performance
- Each TMM thread handles a subset of connections; cores dedicated exclusively to TMM

**CMP (Clustered Multiprocessing)**
- Allows TMM to scale across multiple CPU cores on multi-blade chassis hardware (VIPRION) and high-core appliances
- Traffic flows are distributed across TMM instances using a flow-distribution algorithm
- Synchronizes connection state across TMM instances for seamless handling

**TMOS (Traffic Management Operating System)**
- BIG-IP's operating system layer: based on CentOS Linux with F5 custom kernel and TMM
- Provides management plane (TMSH CLI, iControl REST API, GUI), logging, SNMP
- Modules licensed and activated on top of TMOS base

### 1.2 Module Processing Order

```
Ingress Interface
    → Packet Filter (rate-based rules)
    → AFM (Advanced Firewall Manager — network firewall)
    → iRule FLOW_INIT event
    → LTM / GTM-DNS (load balancing, virtual servers)
    → APM (Access Policy Manager — auth, SSL-VPN)
    → ASM/Advanced WAF (application security)
Egress toward pool members
```

---

## 2. LTM — Local Traffic Manager

LTM is the foundational load balancing module. All other modules (APM, ASM, AFM) require LTM as a base.

### 2.1 Virtual Servers

Virtual servers are the listener objects; they define what traffic BIG-IP intercepts.

| Type | Description |
|---|---|
| **Standard** | Full proxy; terminates client connection, initiates new connection to pool |
| **Performance (Layer 4)** | FastL4 — passes TCP/UDP at L4 with minimal processing; no SSL, iRules limited |
| **Performance (HTTP)** | FastHTTP — optimized HTTP processing; limited profile support |
| **Stateless** | UDP/IP; no connection tracking; high PPS forwarding |
| **Forwarding (IP)** | Routes packets without load balancing; acts as router |
| **Reject** | Drops matching traffic and sends RST/ICMP unreach |

```tcl
# TMSH — create basic HTTPS virtual server
create ltm virtual VS_APP_HTTPS {
    destination 10.10.0.100:443
    ip-protocol tcp
    pool POOL_APP
    profiles add { clientssl { context clientside } tcp http }
    source-address-translation { type automap }
}
```

### 2.2 Pools and Nodes

**Nodes** represent individual backend servers (IP address + optional port). Nodes exist independently of pools.

**Pools** group nodes/members with a load-balancing algorithm and health monitor.

```bash
# Create node
create ltm node NODE_APP1 { address 192.168.10.11 }

# Create pool with two members and Round Robin LB
create ltm pool POOL_APP {
    members add {
        NODE_APP1:8080 { priority-group 1 }
        NODE_APP2:8080 { priority-group 1 }
    }
    load-balancing-mode round-robin
    monitor http_head_f5
}
```

**Load Balancing Methods:**

| Method | Description |
|---|---|
| Round Robin | Distribute in order |
| Least Connections | Send to member with fewest active connections |
| Fastest | Send to member with fastest response |
| Observed | Combines connection count and response time |
| Predictive | Predictive scoring based on observed trends |
| Least Sessions | For connection-oriented protocols (SIP, etc.) |
| Ratio | Weight-based distribution |
| Dynamic Ratio (SNMP) | Ratio updated dynamically via SNMP metrics from pool members |

### 2.3 Health Monitors

Monitors probe pool members and mark them up/down:

| Monitor | Protocol | Use Case |
|---|---|---|
| ICMP | Ping | Basic reachability |
| TCP | TCP connect | Port availability |
| HTTP | HTTP GET | Web server response |
| HTTPS | HTTPS GET | TLS-terminated services |
| TCP Half Open | TCP SYN-ACK | Firewall-friendly L4 check |
| MSSQL | SQL query | Database health |
| LDAP | LDAP bind | Directory service |
| External | Custom script | Custom application checks |
| Gateway ICMP | Ping (router awareness) | Gateway/next-hop check |

### 2.4 Persistence

Persistence ensures sessions from the same client continue to the same pool member.

| Type | Mechanism |
|---|---|
| **Source Address** | Client IP → member mapping |
| **Cookie** | BIG-IP injects or reads HTTP cookie |
| **SSL Session ID** | TLS session identifier (before decryption) |
| **HTTP Header** | Value of a specific HTTP header |
| **SIP** | SIP Call-ID |
| **Universal** | iRule sets the persistence key (custom) |
| **Hash** | Hash of URL, header, or custom data |

Persistence records are stored in the connection table with configurable TTL.

### 2.5 Profiles

Profiles define protocol behavior attached to virtual servers:

- **TCP Profile**: Congestion control, send/receive buffers, keepalive, slow-start
- **HTTP Profile**: One-connect (connection multiplexing), header manipulation, chunking, compression
- **SSL/TLS Profile**: Cipher suites, TLS versions, certificate/key bindings, SNI, OCSP stapling
- **Compression**: gzip/deflate for HTTP responses
- **Analytics**: Per-virtual-server application analytics (requires AFM or AVR)
- **FTP/RTSP/SIP**: Application-layer gateway profiles

---

## 3. GTM / BIG-IP DNS — Global Server Load Balancing

GTM (now called BIG-IP DNS) provides DNS-based GSLB across multiple data centers.

### 3.1 Wide-IP

A Wide-IP is a FQDN that GTM resolves using intelligent GSLB logic:
```bash
create gtm wideip a APP.EXAMPLE.COM {
    pools add { POOL_DC1 { order 0 } POOL_DC2 { order 1 } }
    pool-lb-mode topology
}
```

### 3.2 GSLB Pools and Pool Members

GTM pools contain virtual servers from multiple data centers. Pool members are defined as (data-center-name, LTM virtual-server) pairs.

### 3.3 Load Balancing Methods (GTM)

| Method | Description |
|---|---|
| Round Robin | DNS round-robin across VIPs |
| Topology | Select based on geolocation/topology rules |
| Least Connections | Prefer data center with fewest connections |
| Performance | Prefer data center with best performance (measured by iQuery/probes) |
| Static Persist | DNS-based persistence via hashing |
| Quality of Service | Weighted scoring across multiple metrics |

### 3.4 iQuery

iQuery is a proprietary F5 protocol between GTM and LTM instances to exchange real-time load and availability data. Enables GTM to make informed decisions about which data center's VIP to serve.

---

## 4. ASM / Advanced WAF — Application Security Manager

### 4.1 WAF Policy Model

BIG-IP ASM (now marketed as Advanced WAF) uses a positive security model (whitelist + blocking) combined with negative security (signatures).

**Security Policy components:**
- Attack Signatures (OWASP Top 10, server-type-specific, generic)
- Entity lists: URLs, parameters, file types, headers — define expected application behavior
- Bot Detection: Proactive bot defense, JS challenges, CAPTCHA, rate limiting
- DataSafe: Encrypts form fields in the browser to prevent credential harvesting/keylogging
- Brute Force Protection: Login page rate limiting and lockout
- L7 DDoS: Application-layer flood mitigation

### 4.2 Deployment Modes

| Mode | Description |
|---|---|
| Transparent | Inspect-only; no blocking (learning mode) |
| Blocking | Block requests matching attack signatures; return blocking page |
| Selective Blocking | Per-violation or per-entity blocking decisions |

### 4.3 Attack Signatures

Signatures are organized into signature sets:
- Generic Detection Signatures (SQL injection, XSS, RFI, LFI, etc.)
- Server Technology sets (Apache, IIS, PHP, Java, etc.)
- CVE-based signatures for specific vulnerabilities
- Custom signatures (regex-based)

Signature updates delivered via F5 LiveUpdate (scheduled automatic updates).

---

## 5. APM — Access Policy Manager

APM provides authentication, authorization, SSL-VPN, and zero-trust access control.

### 5.1 Access Policies

Access policies are visual workflow editors (flowchart) defining authentication and authorization logic:
- Endpoint inspection (OS version, antivirus, firewall presence)
- Authentication: LDAP, RADIUS, SAML IdP/SP, Kerberos, OTP, client certificate
- Authorization: Group membership check, LDAP attribute evaluation
- SSO: NTLM, Kerberos, Form-based, SAML
- Per-session and per-request policies

### 5.2 SSL-VPN / Network Access

APM provides full SSL-VPN (Network Access resource):
- Full tunnel VPN with split tunneling options
- Client integrity checking before granting access
- Dynamic LAN rules injected based on user role
- F5 Edge Client on Windows/macOS/iOS/Android

### 5.3 SAML Integration

APM acts as SAML Identity Provider (IdP) or Service Provider (SP):
- IdP: Issues SAML assertions after local authentication; federates to SP applications
- SP: Accepts assertions from external IdP (Azure AD, Okta, etc.)

---

## 6. AFM — Advanced Firewall Manager

AFM is a stateful L3-L7 network firewall integrated in the data path before LTM.

### 6.1 Rule Configuration

```bash
create security firewall rule-list ALLOW_WEB {
    rules add {
        ALLOW_HTTPS {
            action accept
            ip-protocol tcp
            destination { ports add { 443 } }
        }
        ALLOW_HTTP {
            action accept
            ip-protocol tcp
            destination { ports add { 80 } }
        }
    }
}
```

### 6.2 Network Firewall Policy

Policies are applied at context levels:
- **Global** (applies to all traffic before virtual server matching)
- **Route Domain** (per VRF-equivalent)
- **Virtual Server** (applied to specific VS)
- **Self-IP** (management plane protection)

### 6.3 DoS and DDoS Mitigation

AFM includes:
- Device DoS protection (SYN flood, UDP flood, ICMP flood mitigation)
- IP Intelligence (Threat IP feeds from F5/third parties)
- DNS DoS (malformed DNS, DNS amplification mitigation)
- Protocol inspection and anomaly detection

---

## 7. iRules

iRules are TCL-based event-driven scripts that give BIG-IP operators complete programmatic control over traffic. They run inside TMM.

### 7.1 Event Model

iRules respond to events triggered at specific points in traffic processing:

| Event | Trigger Point |
|---|---|
| `CLIENT_ACCEPTED` | New TCP connection from client |
| `HTTP_REQUEST` | HTTP request headers received |
| `HTTP_RESPONSE` | HTTP response headers received |
| `CLIENT_DATA` | Client payload data available |
| `SERVER_CONNECTED` | Connection to pool member established |
| `LB_SELECTED` | Pool member selected |
| `LB_FAILED` | All pool members down |
| `RULE_INIT` | Rule loaded (for initialization) |
| `DNS_REQUEST` | DNS query received (GTM/DNS) |

### 7.2 Key Commands

```tcl
# Route to specific pool
pool POOL_APP

# Set persistence
persist source_addr

# Manipulate HTTP header
HTTP::header insert "X-Forwarded-Proto" "https"
HTTP::header remove "Server"

# Log message
log local0. "Client [IP::client_addr] requested [HTTP::uri]"

# Redirect
HTTP::redirect "https://[HTTP::host][HTTP::uri]"

# Reject connection
reject

# Datagroup lookup (IP list, string list, value map)
if { [class match [IP::client_addr] equals BLACKLIST_IPs] } {
    drop
}

# Set variable for later use
set user_role [HTTP::header "X-User-Role"]

# iRule-based persistence key
persist uie [HTTP::cookie "SESSIONID"] 3600
```

### 7.3 iRules Performance Considerations

iRules add CPU overhead per transaction. CPU clock speed is critical when complex iRules are applied at scale. Best practices:
- Minimize iRule complexity; avoid unnecessary events
- Use `class match` for large IP/string lists (datagroup lookup is O(log n))
- Consider iRules LX (Node.js based) for complex string processing

---

## 8. iControl REST API

iControl REST provides full CRUD access to all BIG-IP configuration objects.

### 8.1 API Structure

Base URL: `https://<bigip>/mgmt/tm/`

Namespaces map to TMOS configuration sections:
- `/mgmt/tm/ltm/virtual` — virtual servers
- `/mgmt/tm/ltm/pool` — pools
- `/mgmt/tm/ltm/node` — nodes
- `/mgmt/tm/asm/policies` — WAF policies
- `/mgmt/tm/gtm/wideip/a` — Wide-IPs

### 8.2 Example REST Calls

Authentication: Basic auth or token (`X-F5-Auth-Token`). Common patterns:
- `GET /mgmt/tm/ltm/virtual` — list virtual servers
- `POST /mgmt/tm/ltm/pool/~Common~POOL/members` with `{"name":"IP:port","ratio":1}` — add member
- `PATCH .../members/~Common~IP:port` with `{"session":"user-disabled"}` — gracefully drain member

### 8.3 Transactions

iControl REST supports atomic batch operations: `POST /mgmt/tm/transaction` returns a `transId`; subsequent requests include `X-F5-REST-Coordination-Id: <transId>` header; commit with `PATCH /mgmt/tm/transaction/<transId> {"state":"VALIDATING"}`. Rollback by `DELETE` on the transaction.

---

## 9. BIG-IQ Centralized Management

BIG-IQ provides centralized management, analytics, and licensing for BIG-IP fleets.

### 9.1 Key BIG-IQ Functions

| Function | Description |
|---|---|
| Device Management | Inventory, backup/restore, software upgrades for all BIG-IPs |
| Centralized Policy | Deploy and sync LTM, ASM, APM, AFM policies across multiple devices |
| License Management | Utility licensing (ELA, PAYG) and pool license management |
| Analytics | Application performance analytics from all managed BIG-IPs |
| Access Management | APM policy management across devices |
| WAF Management | Centralized ASM/Advanced WAF policy lifecycle |

---

## 10. HA (High Availability)

### 10.1 Device Groups

HA in BIG-IP is built around Device Groups and Device Trust:
- **Device Trust**: Cryptographic trust relationship between BIG-IP devices
- **Device Group**: Group of trusted devices that synchronize configuration

### 10.2 HA Modes

| Mode | Description |
|---|---|
| **Active-Standby** | One active device handles traffic; standby ready to take over; config sync bidirectional |
| **Active-Active (Pair)** | Both devices active with different traffic groups; each handles subset of VIPs |
| **Sync-Only** | Config replication only; no failover (multi-device scale-out behind external LB) |

### 10.3 Traffic Groups

Traffic groups are collections of floating IPs that move between devices during failover. A traffic group has:
- An active device (owner)
- MAC masquerade address (optional — reduces ARP delay on failover)
- Floating self-IPs associated with the traffic group

### 10.4 Config Sync

Config sync propagates changes from one device to all members:
- **Incremental sync**: Only changed objects synced (default, efficient)
- **Full sync**: Complete configuration push (used after device replacement)

---

## 11. Version 17.x and F5 Distributed Cloud

### 11.1 BIG-IP 17.1.x

- Latest long-term support release (as of early 2026)
- Requires minimum TLS 1.2 for management interfaces
- Advanced WAF includes updated ML-based bot detection
- Improved CGNAT performance on r-series appliances
- FIPS 140-2 Level 2 compliance on supported hardware

### 11.2 F5 Distributed Cloud (XC)

F5 Distributed Cloud (formerly Volterra) is F5's SaaS-delivered platform:
- **App-to-App Networking**: Connect services across clouds, edge, and on-prem
- **Distributed Cloud WAF**: Cloud-delivered WAF with same rule engine as BIG-IP ASM
- **Bot Defense**: ML-powered bot mitigation as a service
- **API Security**: Automatic API discovery, schema enforcement, rate limiting
- **Network Connect**: SD-WAN-like connectivity between cloud VPCs and on-prem
- **Customer Edge (CE)**: Virtual appliance deployed on-premises or in cloud; connects to F5 XC PoPs

### 11.3 Terraform Provider for BIG-IP

```hcl
provider "bigip" {
  address  = "https://192.168.1.1"
  username = "admin"
  password = var.bigip_password
}

resource "bigip_ltm_pool" "app_pool" {
  name                = "/Common/APP_POOL"
  load_balancing_mode = "least-connections-member"
  monitors            = ["/Common/http"]
}

resource "bigip_ltm_pool_attachment" "app_member" {
  pool = bigip_ltm_pool.app_pool.name
  node = "/Common/192.168.10.10:80"
}

resource "bigip_ltm_virtual_server" "app_vs" {
  name                       = "/Common/VS_APP"
  destination                = "10.10.0.100"
  port                       = 443
  pool                       = bigip_ltm_pool.app_pool.name
  client_profiles            = ["/Common/clientssl"]
  snatpool                   = "automap"
  source_address_translation = "automap"
}
```

---

## References

- [F5 BIG-IP Module Overview (Medium)](https://mohsinccie.medium.com/high-level-overview-of-f5-big-ip-software-modules-ltm-asm-apm-afm-and-dns-78d5d928776b)
- [F5 BIG-IP 17.1.3 Release Notes](https://techdocs.f5.com/en-us/bigip-17-1-3/big-ip-release-notes/big-ip-general.html)
- [AFM Lab Documentation](https://f5-agility-labs-firewall.readthedocs.io/en/latest/class1/lab1/step3.html)
- [Understanding BIG-IP Modules](https://f5edge.com/blog/understand-f5-big-ip-main-modules/)
- [Terraform F5 BIG-IP Provider](https://registry.terraform.io/providers/F5Networks/bigip/latest/docs)
- [Module Processing Order (DevCentral)](https://community.f5.com/discussions/technicalforum/knowledge-sharing-an-example-of-the-general-order-of-precedence-for-the-big-ip-m/208283)
