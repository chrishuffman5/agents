# Aruba Wireless Architecture Reference

## AOS 10 Platform Architecture

### Cloud Management Plane (Aruba Central)

Aruba Central (part of HPE GreenLake) is the cloud management platform for AOS 10:

**Management Services:**
- Device provisioning: template-based configuration pushed to APs and gateways
- Firmware management: scheduled upgrades, compliance tracking, staged rollouts
- Monitoring: real-time device health, client statistics, event correlation
- Alerting: configurable alerts for device down, high utilization, rogue APs, authentication failures
- Reporting: historical analytics, compliance reports, capacity planning

**Central Architecture:**
- Multi-tenant SaaS platform hosted on AWS
- APs and gateways establish outbound HTTPS connections to Central (no inbound firewall rules needed)
- API-first design: all GUI operations available via REST API
- Role-based access control (RBAC) for admin accounts
- Audit logging for all configuration changes

### AOS 10 AP Architecture

AOS 10 APs are intelligent edge devices:
- Run full AOS 10 operating system (Linux-based)
- Maintain local client state table (associations, authentication, VLAN assignments)
- Forward data traffic locally (bridge to VLAN) or tunnel to gateway
- Cache authentication state for survivability during cloud/gateway outage
- Execute local firewall rules (basic ACLs) even without gateway
- Connect to Central via HTTPS for management; operate independently for data plane

### Aruba Gateway Architecture

The Aruba Gateway (formerly SD-WAN gateway) is an on-premises appliance providing:

**Security Services:**
- Stateful firewall with role-based policies (roles assigned by ClearPass)
- Deep packet inspection (DPI) for application identification
- URL filtering and content classification
- IDS/IPS for threat detection
- ZTNA (Zero Trust Network Access) for private application access

**SD-WAN Services:**
- Multiple WAN link management (MPLS, broadband, LTE)
- Application-aware path selection based on SLA metrics
- Forward Error Correction (FEC) and packet duplication for link quality improvement
- Centralized SD-WAN orchestration via Aruba Central

**Gateway Models:**
- Gateway hardware appliances for branch and campus deployment
- Virtual gateway for cloud/VM deployment
- Gateway capacity determines maximum throughput for firewall/DPI features

### AP-Gateway Tunnel Architecture

When a gateway is deployed:
```
Client -> AP (802.11) -> GRE tunnel -> Gateway -> Policy enforcement -> WAN/LAN
                                                -> Role-based firewall
                                                -> DPI / URL filtering
```
- AP establishes GRE tunnel to gateway for SSID traffic requiring policy enforcement
- Multiple SSIDs can be split: corporate traffic to gateway, guest traffic bridged locally
- If gateway is unreachable, AP can fall back to local bridging (configurable)

## ClearPass Architecture

### ClearPass Component Model

| Component | Function |
|---|---|
| ClearPass Policy Manager | Core authentication and authorization engine (RADIUS, TACACS+) |
| ClearPass Guest | Guest management portal (self-registration, sponsor, social login) |
| ClearPass OnBoard | BYOD certificate provisioning and device enrollment |
| ClearPass OnGuard | Endpoint posture agent (health checks, compliance) |
| ClearPass Insight | Reporting and analytics (authentication logs, trends) |
| ClearPass Device Insight | AI-driven device profiling and classification |

### Authentication Flow (802.1X)
```
1. Client associates to SSID
2. AP/Gateway sends RADIUS Access-Request to ClearPass
3. ClearPass initiates EAP exchange with client (via AP/Gateway as pass-through)
4. ClearPass validates credentials against AD/LDAP/local DB
5. ClearPass evaluates enforcement policy (role, VLAN, ACL based on user + device + posture)
6. ClearPass returns RADIUS Access-Accept with attributes:
   - Aruba-User-Role: <role-name>
   - Tunnel-Private-Group-ID: <vlan-id>
   - Filter-Id: <acl-name>
7. AP/Gateway applies returned attributes to client session
```

### ClearPass Profiling

Device profiling uses multiple data sources:
- **DHCP fingerprinting**: Client's DHCP options reveal OS type
- **MAC OUI**: First 3 octets identify manufacturer
- **HTTP User-Agent**: Browser string identifies OS and device
- **SNMP**: Query network devices for CDP/LLDP neighbor info
- **OnConnect**: Active scanning of endpoints for open ports and services
- **Collector integration**: SPAN/mirror port for passive traffic analysis

Profiling feeds into enforcement policy: e.g., "if device is profiled as printer AND user role is IoT, assign Printer-Role with restricted ACL."

## AirMatch Deep Dive

### How AirMatch Works

1. **Data collection**: APs continuously send RF telemetry (neighbor APs, RSSI, channel utilization, noise floor, client counts) to Central
2. **Global analysis**: AirMatch ML engine analyzes RF data across the entire organization (all sites)
3. **Optimization computation**: Computes globally optimal channel and power plan that minimizes co-channel interference across all APs
4. **Plan distribution**: Pushes optimized plan to APs once per day during configured maintenance window
5. **Continuous learning**: ML model improves over time based on outcomes of previous optimizations

### AirMatch vs ARM (Adaptive Radio Management)

ARM is the legacy on-prem RF management (AOS 8):
- ARM reacts in real-time to RF changes (interference -> immediate channel change)
- ARM decisions are local (AP-to-AP neighbor awareness)
- ARM can cause RF churn (APs constantly changing channels in response to each other)

AirMatch differences:
- Global optimization (considers all APs across all sites)
- Batch updates (daily, not real-time) reduce RF churn
- ML-based prediction (anticipates interference patterns)
- Cloud-computed (no on-prem processing overhead)
- 5 GHz and 6 GHz managed independently; 2.4 GHz still uses ARM-style management

### AirMatch Configuration
- Enable/disable via Central: Configuration > RF > AirMatch
- Schedule maintenance window for plan application
- Exclude specific APs from AirMatch management (for manually managed APs)
- View proposed plan vs current plan in Central before application

## Dynamic Segmentation Architecture

### Role-Based Policy Model

Traditional VLAN-based segmentation:
```
Client -> SSID -> VLAN 10 -> Firewall rule for VLAN 10
Problem: Policy is tied to network topology (VLAN), not identity
```

Dynamic segmentation:
```
Client -> SSID -> ClearPass assigns role "Employee" -> Gateway enforces Employee firewall policy
Advantage: Same policy regardless of SSID, VLAN, AP, or site
```

### Roles and Policies
- **Role**: A named identity label (e.g., "Employee", "Contractor", "IoT-Camera", "Guest")
- **Firewall Policy**: A set of rules bound to a role (e.g., Employee can access internal apps, IoT-Camera can only reach NVR on port 554)
- **Role assignment**: ClearPass returns role via RADIUS attribute; gateway enforces
- **Role stacking**: Multiple attributes (user identity + device type + posture) combine to determine final role

### Tunneled Node for Wired Segmentation

Extends dynamic segmentation to wired infrastructure:
```
Wired client -> Switch port (tunneled node) -> GRE tunnel -> Gateway -> Role-based policy
```
- Switch encapsulates wired client traffic in GRE tunnel to gateway
- ClearPass authenticates wired client (802.1X or MAB) and assigns role
- Gateway enforces same firewall policies as for wireless clients
- Consistent policy across wired and wireless without per-VLAN ACLs on switches

### Supported Switch Models
- Aruba CX switches with AOS-CX firmware (6200, 6300, 6400, 8320, 8400 series)
- Configuration via Central or switch CLI
- Not supported on legacy ArubaOS switches (2930F/M, 3810M with ArubaOS-Switch firmware)

## Aruba Central API Architecture

### Authentication
- OAuth2 token-based authentication
- API Gateway provides rate limiting and token lifecycle management
- Long-lived refresh tokens for automation scripts
- Per-customer API rate limits (configurable via support)

### API Namespaces

| Namespace | Resources |
|---|---|
| /monitoring/v2/ | APs, clients, switches, gateways, alerts |
| /configuration/v1/ | Device config, groups, templates, labels |
| /firmware/v1/ | Firmware images, compliance, upgrade scheduling |
| /rapids/v1/ | Rogue AP/client detection |
| /analytics/v2/ | RF analytics, client analytics, application analytics |
| /auditlogs/v1/ | Admin audit trail |
| /msp/v1/ | Multi-tenant (MSP) management |

### Webhook Integration
Central supports webhooks for real-time event notification:
- Device up/down events
- Rogue AP detection
- Authentication failures
- Alert triggers
- Configure via Central UI or API
