# Cisco ISE Architecture Reference

## ISE Node Roles

In a distributed ISE deployment, different node types handle different functions. Understanding node roles is critical for sizing, high availability, and troubleshooting.

### Policy Administration Node (PAN)

- **Role:** Central management and configuration
- **Functions:** Policy authoring, GUI access, replication to PSNs, license management
- **HA:** Primary PAN + Secondary PAN (manual or auto-failover)
- **Scaling:** Two PANs maximum in a deployment (Primary + Standby)
- **Network requirements:** Must communicate with all MnT and PSN nodes

**Key principle:** ALL configuration changes are made on the Primary PAN and replicated to other nodes. Never configure directly on PSN or MnT.

### Monitoring and Troubleshooting Node (MnT)

- **Role:** Log collection, reporting, and troubleshooting
- **Functions:** Receives syslog from PSNs, stores authentication logs, provides Live Logs UI, generates reports
- **HA:** Primary MnT + Secondary MnT (automatic log streaming to both)
- **Scaling:** Two MnTs maximum; both receive logs simultaneously
- **Storage:** MnT requires significant disk space (authentication logs); sizing depends on authentications/day

**Key principle:** Authentication logs are stored ONLY on MnT nodes, not on PSNs. If MnT is down, authentications still succeed but logging stops.

### Policy Service Node (PSN)

- **Role:** Runtime authentication and authorization
- **Functions:** Process RADIUS requests, serve guest portals, profiling, posture, pxGrid
- **HA:** Multiple PSNs load-balanced via RADIUS server groups on network devices
- **Scaling:** Scale out by adding PSNs; no hard limit (licensed by node count)
- **Deployment:** PSNs should be distributed geographically close to authenticating devices

**Key principle:** PSNs are stateless with respect to policy. Policy is replicated from PAN. PSNs can be added/removed without service disruption.

### pxGrid Controller (built into PAN in ISE 3.x)

In ISE 3.x, the pxGrid controller function is integrated into the PAN nodes. In ISE 2.x, pxGrid was a separate node role.

## Distributed Deployment Architecture

### Small Deployment (up to ~20,000 endpoints)

```
[Primary PAN + Primary MnT + PSN] --- [Secondary PAN + Secondary MnT + PSN]
       (All-in-one Node 1)                    (All-in-one Node 2)

Network devices authenticate to both nodes (RADIUS server group with load balancing)
```

### Medium Deployment (up to ~100,000 endpoints)

```
[Primary PAN]    [Secondary PAN]
      |                 |
[Primary MnT]  [Secondary MnT]
      |                 |
[PSN 1] [PSN 2] [PSN 3] [PSN 4]  <-- Load balanced across network devices
```

### Large Enterprise Deployment (250,000+ endpoints)

```
Data Center A:
  [Primary PAN] + [Primary MnT]
  [PSN 1] [PSN 2] [PSN 3] ... [PSN N]

Data Center B:
  [Secondary PAN] + [Secondary MnT]
  [PSN 1] [PSN 2] [PSN 3] ... [PSN N]

Regional Site C:
  [PSN 1] [PSN 2]  <-- Local PSNs for regional authentication (avoid WAN latency)
```

**PSN placement principle:** Network devices should authenticate to a PSN with low latency (< 100ms round trip). Place PSNs near authenticating devices, especially for large remote sites.

### Node Sizing Guidelines

| Role | Small (< 20K) | Medium (< 100K) | Large (100K+) |
|---|---|---|---|
| PAN | 4 vCPU / 16GB | 8 vCPU / 32GB | 16 vCPU / 64GB |
| MnT | 4 vCPU / 16GB / 600GB | 8 vCPU / 32GB / 1.2TB | 16 vCPU / 64GB / 3.2TB |
| PSN | 4 vCPU / 16GB | 8 vCPU / 32GB | 16 vCPU / 64GB |

**Note:** These are minimums. Production deployments should always exceed minimum requirements by 20-30% headroom.

## RADIUS Architecture

### RADIUS Protocol Flow

```
[Endpoint]  <--> [Switch/AP (Authenticator)] <--> [ISE PSN (RADIUS Server)]
                                                          |
                                             [Identity Store: AD/LDAP/Internal]
```

**UDP ports:**
- UDP/1812 -- Authentication and Authorization (Access-Request/Accept/Reject/Challenge)
- UDP/1813 -- Accounting (Accounting-Request/Response)
- UDP/1645,1646 -- Legacy alternative ports (avoid in new deployments)

**RADIUS attributes flow:**
1. Switch sends `Access-Request` with attributes (username, NAS-IP, NAS-Port, EAP payload)
2. ISE processes authentication, returns `Access-Accept` with:
   - `Tunnel-Private-Group-ID` (VLAN)
   - `Filter-Id` (dACL name)
   - `Cisco-AV-Pair: cts:security-group-tag` (SGT)
   - EAP attributes

### RADIUS Server Groups (Switch Configuration)

Network devices should be configured with both PSNs in a server group:

**Cisco IOS:**
```
radius server ISE-PSN-1
 address ipv4 10.0.0.10 auth-port 1812 acct-port 1813
 key your-shared-secret

radius server ISE-PSN-2
 address ipv4 10.0.0.11 auth-port 1812 acct-port 1813
 key your-shared-secret

aaa group server radius ISE-SERVERS
 server name ISE-PSN-1
 server name ISE-PSN-2
 load-balance method least-outstanding batch-size 5

aaa authentication dot1x default group ISE-SERVERS
aaa authorization network default group ISE-SERVERS
aaa accounting dot1x default start-stop group ISE-SERVERS
```

### RADIUS CoA (Change of Authorization) Architecture

CoA allows ISE to proactively update a connected endpoint's authorization without requiring re-authentication.

**CoA use cases:**
- Posture compliance result received -- upgrade from restricted to full access
- Admin manually quarantines a device (ANC quarantine)
- Endpoint profile changes -- update VLAN or ACL
- Guest session timeout

**CoA configuration on switch:**
```cisco
aaa server radius dynamic-author
 client 10.0.0.10 server-key your-shared-secret   ! ISE PSN 1
 client 10.0.0.11 server-key your-shared-secret   ! ISE PSN 2
 auth-type any
```

**CoA message types:**
- `CoA-Request: Disconnect` -- Disconnect the session (triggers re-authentication)
- `CoA-Request: Session` -- Update the existing session's authorization

## TrustSec Architecture

TrustSec provides SGT (Security Group Tag)-based segmentation without requiring VLAN changes.

### SGT Architecture

```
[Endpoint Authenticates] 
     |
     v
[ISE authorizes SGT (e.g., SGT=10 "Employee")]
     |
     v
[Switch tags all traffic from endpoint with SGT 10 in Cisco metadata header]
     |
     v
[Traffic arrives at firewall/switch with destination]
     |
     v
[Policy: IF src-SGT=Employee AND dst-SGT=Database -> permit HTTPS (443)]
         IF src-SGT=Employee AND dst-SGT=Database -> deny all
```

### SGT Propagation Methods

**Inline tagging (hardware):**
- Traffic is tagged with SGT in the 802.1Q header or Cisco metadata
- Requires TrustSec-capable hardware (Catalyst switches, Nexus)
- Most efficient; no additional overhead at ISE

**SXP (SGT Exchange Protocol):**
- ISE exports IP-to-SGT mappings to network devices via SXP
- Network devices apply SGT based on IP address
- Supports non-TrustSec hardware that can still apply SGT-based policies
- Used when inline tagging is not available

**pxGrid SGT distribution:**
- Firewalls (Firepower, Palo Alto) receive SGT-to-IP bindings via pxGrid
- Apply firewall rules based on SGT rather than IP addresses
- Rules remain valid even when IPs change (laptop moves, DHCP refresh)

### TrustSec Matrix

The SGT policy matrix defines which SGTs can communicate:

```
Source SGT | Destination SGT | Policy
Employee   | Database        | Permit HTTPS only
Employee   | PCI             | Deny All
Guest      | Internet        | Permit Web only
Guest      | Internal        | Deny All
IoT        | IoT             | Permit Any
IoT        | Corporate       | Deny All
```

## pxGrid Architecture

### pxGrid in ISE 3.x

pxGrid is the platform for bi-directional sharing of contextual data:

**Session directory (read):**
- External systems query ISE for IP-to-identity mapping
- "Who is at 10.1.2.3?" -> "CORP\john.doe, VLAN 100, SGT Employee, Posture Compliant"
- Used by: SIEM correlation, firewall dynamic rules, SOAR playbooks

**Adaptive Network Control / ANC (write):**
- External systems instruct ISE to quarantine or change policy for an endpoint
- "Quarantine 10.1.2.3" -> ISE sends CoA to move endpoint to restricted VLAN
- Used by: SIEM automated response, SOAR playbooks, MDM compliance events

**pxGrid subscription model:**
```
pxGrid Publisher (ISE) publishes to topics:
  - sessionTopic: New/updated/deleted sessions
  - ancOperationTopic: ANC policy changes
  - trustsecPolicyTopic: SGT policy updates

pxGrid Subscriber (SIEM, FW, etc.) subscribes to topics of interest
```

**pxGrid client types:**
- Certificate-based (production) -- Client presents certificate to ISE pxGrid controller
- Password-based (legacy, ISE 2.x) -- Username/password authentication
- Cloud-delivered (ISE 3.2+) -- API-based for cloud-native integrations

## High Availability Design

### PAN High Availability

- **Primary PAN** -- Active; all configuration changes made here
- **Secondary PAN** -- Standby; receives config replication from primary
- **Failover:** Can be automatic (ISE 2.7+) or manual
- **Failover trigger:** Primary PAN unreachable for configured threshold
- **Note:** Authentication continues during PAN failover (PSNs continue processing)

### MnT High Availability

- Both MnT nodes receive authentication logs simultaneously from PSNs
- If one MnT fails, the other continues receiving and storing logs
- PSNs must be configured to send logs to both MnT nodes:
  ```
  Administration > System > Logging > Remote Logging Targets
  ```

### PSN High Availability

PSNs are load-balanced at the network device level -- there is no ISE-level cluster failover for PSNs:

- Network devices have a RADIUS server group with multiple PSN IPs
- If a PSN fails RADIUS health checks, the server group falls over to the next PSN
- PSN failure detection: dead time (~15 seconds after no response)
- All PSN state (sessions, posture) is independent -- no replication between PSNs
- **Impact of PSN failure:** Endpoints authenticated to that PSN remain connected until re-auth; new auth attempts go to surviving PSNs

### Network Redundancy for ISE

```
Recommended ISE connectivity:
- ISE nodes connected to redundant switches (separate paths to core)
- PSNs have 2 NICs: one for RADIUS traffic, one for guest/portal traffic (optional)
- Management network separate from authentication traffic network
- ISE nodes should not share subnets with endpoints (administrative network)
```

## Identity Store Integration

### Active Directory Integration

ISE joins the AD domain for user and computer authentication lookups.

**AD join requirements:**
- Service account with domain join rights (for initial join)
- DNS resolution of domain controller FQDNs from ISE
- Ports: TCP/389 (LDAP), TCP/636 (LDAPS), TCP/3268 (GC), UDP+TCP/88 (Kerberos), TCP/135 (RPC endpoint mapper)

**Multiple AD forests/domains:**
- ISE supports joins to multiple AD forests (up to 50 in ISE 3.x)
- Configure trust relationships at AD level; ISE follows the trusts
- Multi-domain search: ISE can search all joined domains for a user

**AD attribute retrieval:**
ISE fetches user and machine attributes from AD for use in policy conditions:
- Group membership (`memberOf`)
- Custom attributes (department, location, etc.)
- Machine status (enabled/disabled)
- Password expiry

### LDAP Integration

For non-AD LDAP directories (OpenLDAP, eDirectory):
```
Administration > Identity Management > External Identity Sources > LDAP
  Server: ldap.corp.local:636
  Admin DN: cn=ise-service,ou=service-accounts,dc=corp,dc=local
  Password: [service account password]
  User Object Class: inetOrgPerson
  User Name Attribute: uid  (or sAMAccountName for AD-compatible)
  Subject: ou=users,dc=corp,dc=local
```

### Certificate Authentication Profile

For EAP-TLS, ISE needs to map a certificate to an identity store entry:

```
Certificate Authentication Profile:
  Name: EAP-TLS-AD
  Principal Name X509: Subject Alternative Name - DNS Name
  Identity Source: [Active Directory]
  
  Matching:
    - Use SAN: DNS name matches AD machine account (for machine auth)
    - Use SAN: UPN matches AD user account (for user auth)
```
