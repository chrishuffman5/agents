# LibreNMS Architecture Reference

## System Architecture

### Component Stack
```
[User Browser] --> [Nginx/Apache] --> [PHP 8.x / Laravel] --> [MySQL/MariaDB]
                                                           --> [Redis]
                                                           --> [RRDtool / InfluxDB]

[Cron/Systemd] --> [Poller Daemon] --> [SNMP] --> [Devices]
               --> [Discovery Daemon] --> [SNMP/CDP/LLDP/BGP] --> [Devices]
               --> [Alert Daemon] --> [Alert Rules] --> [Transports]
```

### Web Application
- **Framework**: PHP 8.x with Laravel (MVC)
- **Web server**: Nginx (recommended) or Apache with PHP-FPM
- **Authentication**: Local database, LDAP/AD, RADIUS, SAML, OAuth2
- **RBAC**: Per-device and per-device-group access controls
- **Session management**: Redis-backed for performance

### Database
- **MySQL 8.0+ or MariaDB 10.5+** (InnoDB engine)
- **Schema**: Normalized tables for devices, ports, sensors, storage, processors, mempools, alerts, events
- **Key tables**:
  - `devices` -- All monitored devices (hostname, IP, SNMP credentials, status)
  - `ports` -- Network interfaces with current and historical counters
  - `sensors` -- Environmental sensors (temperature, voltage, current, power)
  - `processors` -- CPU utilization per processor
  - `mempools` -- Memory pool utilization
  - `alerts` -- Active and historical alert states
  - `eventlog` -- System and device events
  - `syslog` -- Collected syslog messages

### Redis
- Caching layer for frequently accessed data
- Session storage
- Queue backend for dispatched jobs
- Reduces database load on large deployments

## SNMP Polling

### Polling Process
1. **Scheduler** triggers polling for each device (default: every 5 minutes)
2. **SNMP bulk walk** retrieves interface counters, device metrics, sensor readings
3. **Data normalization** converts raw SNMP values to rates (bits/sec, errors/sec)
4. **Database update** writes current values to MySQL
5. **RRD/InfluxDB write** stores time-series data for graphing
6. **Alert evaluation** checks current values against alert rules
7. **Health check** updates device availability status

### SNMP Credential Management
- Per-device SNMP credentials (v1/v2c community or v3 user/auth/priv)
- Global default credentials for auto-discovery
- Credential rotation: update per-device or bulk-update via API
- SNMPv3 recommended for production (authPriv with AES-256)

### OID Libraries
- Standard MIBs: IF-MIB (interfaces), HOST-RESOURCES-MIB (CPU/mem), ENTITY-MIB (hardware)
- Vendor MIBs: Cisco, Juniper, Arista, HP/Aruba, Dell, Fortinet, Palo Alto, etc.
- Custom OIDs: Add custom SNMP pollers via YAML device definitions

## Auto-Discovery

### Discovery Protocols

#### SNMP-Based
- Probe IP with configured SNMP credentials
- If device responds, read sysObjectID to identify device type
- Apply matching device definition (YAML) for metrics, graphs, health sensors
- Discover interfaces, routing protocols, VLANs, sensors, hardware components

#### CDP/LLDP Neighbor Discovery
- Walk CDP/LLDP MIB tables on discovered devices
- Extract neighbor hostname and management IP
- Attempt SNMP connection to neighbor with configured credentials
- Recursively discover the network

#### BGP Peer Discovery
- Walk BGP4-MIB peer table on discovered routers
- Extract peer IP addresses
- Attempt SNMP connection to peers
- Useful for discovering routing infrastructure

#### ARP Table Discovery
- Walk ARP table on routers/switches
- Attempt SNMP connection to discovered IPs
- Useful for discovering hosts on directly connected subnets

### Device Definitions (YAML)
```yaml
# example: device definition for Cisco IOS
os: ios
type: network
icon: cisco
over:
  - { graph: device_bits, text: "Device Traffic" }
  - { graph: device_processor, text: "CPU Usage" }
  - { graph: device_mempool, text: "Memory Usage" }
discovery:
  - sysObjectID:
      - .1.3.6.1.4.1.9.1.*    # Cisco enterprise OID tree
mib_dir:
  - cisco
```

## Alert Engine

### Rule Evaluation
- Alert rules are SQL-like expressions evaluated against the LibreNMS data model
- Evaluated after each polling cycle for each device/component matching the rule scope
- State machine: OK -> ALERT -> ACKNOWLEDGED -> OK (or ALERT -> OK if auto-resolved)

### Rule Syntax
```sql
-- Basic threshold
ports.ifOperStatus = "down" AND ports.ifAdminStatus = "up"

-- Numeric comparison
processors.processor_usage > 90

-- String matching
devices.sysDescr LIKE "%IOS XE%"

-- Multiple conditions
ports.ifInErrors_rate > 100 AND ports.ifOutErrors_rate > 100

-- Aggregate
ports.ifInOctets_rate > 1000000000  -- > 1 Gbps inbound
```

### Alert Lifecycle
1. **Trigger**: Rule condition becomes true
2. **Notification**: Alert transports fire (email, Slack, webhook, etc.)
3. **Active**: Alert remains active until condition clears or is acknowledged
4. **Acknowledge**: Admin marks alert as acknowledged (stops repeated notifications)
5. **Clear**: Condition returns to normal; alert auto-closes
6. **Recovery notification**: Optional notification on alert clear

### Transport Configuration
Each transport type has specific configuration requirements:

#### Slack
```
Webhook URL: https://hooks.slack.com/services/T.../B.../xxx
Channel: #network-alerts
Bot name: LibreNMS
```

#### PagerDuty
```
Integration Key: <PagerDuty integration key>
Severity mapping: Critical -> Critical, Warning -> Warning
```

#### Generic Webhook
```
URL: https://automation.example.com/librenms-alert
Method: POST
Headers: Content-Type: application/json, Authorization: Bearer xxx
Body template: JSON with alert variables
```

## Oxidized Integration

### Architecture
```
[LibreNMS] --API--> [Oxidized] --SSH/Telnet--> [Network Devices]
                         |
                    [Git Repository]
                         |
                    [Config History]
```

### LibreNMS -> Oxidized Data Flow
1. Oxidized queries LibreNMS API: `GET /api/v0/oxidized`
2. LibreNMS returns device list with hostname, IP, OS model, credentials
3. Oxidized maps LibreNMS OS to Oxidized model (ios -> ios, junos -> junos, etc.)
4. Oxidized connects to each device, retrieves running config
5. Config committed to Git (one file per device)
6. On config change: diff generated, optionally alert

### Config Display in LibreNMS
- Device view includes "Config" tab showing latest configuration
- Side-by-side diff between any two config versions
- Search across all device configs for specific strings
- Alert on configuration changes (integrates with LibreNMS alerting)

### Oxidized Model Support
Supports 300+ device types including:
- Cisco IOS, IOS XE, NX-OS, ASA
- Juniper Junos
- Arista EOS
- Palo Alto PAN-OS
- Fortinet FortiOS
- HP/Aruba OS
- Dell OS10, FTOS
- MikroTik RouterOS
- Linux (generic)
- Many more

## Distributed Polling

### Architecture
Multiple poller instances share a single database:

```
[Poller 1]  ----+
[Poller 2]  ----|----> [MySQL/MariaDB] <---- [Web Server]
[Poller 3]  ----+             |
                       [rrdcached]
                              |
                     [Shared RRD Storage]
```

### Device Assignment
- Devices assigned to pollers via `poller_group` field
- Round-robin assignment or manual per-device
- Each poller only polls its assigned devices
- All pollers write to the same database

### rrdcached
- Caching daemon for RRDtool writes
- Batches random writes into sequential flushes
- Reduces disk I/O dramatically (100x reduction in random writes)
- Required for any deployment over 500 devices
- Configuration: `rrdcached -l unix:/var/run/rrdcached.sock -w 1800 -z 900`

### Shared Storage
For distributed polling with RRDtool:
- RRD files must be accessible from all pollers AND web server
- Options: NFS share, GlusterFS, or InfluxDB (eliminates file-sharing requirement)
- InfluxDB recommended for distributed deployments (no shared filesystem needed)

## REST API

### Design
- RESTful endpoints under `/api/v0/`
- JSON response format
- Authentication: `X-Auth-Token` header with per-user API token
- Rate limiting: configurable per-token

### Device Management
```
GET    /api/v0/devices                    # List all devices
GET    /api/v0/devices/{hostname}         # Get device details
POST   /api/v0/devices                    # Add device
PATCH  /api/v0/devices/{hostname}         # Update device
DELETE /api/v0/devices/{hostname}         # Delete device
GET    /api/v0/devices/{hostname}/ports   # List device ports
GET    /api/v0/devices/{hostname}/health  # Device health sensors
```

### Alert Management
```
GET    /api/v0/alerts                     # List all alerts
GET    /api/v0/alerts/{id}               # Get alert details
PUT    /api/v0/alerts/{id}               # Acknowledge alert
GET    /api/v0/rules                     # List alert rules
POST   /api/v0/rules                     # Create alert rule
```

### Graph and Data Retrieval
```
GET    /api/v0/devices/{hostname}/graphs/{type}  # Get graph image (PNG)
GET    /api/v0/devices/{hostname}/ports/{id}/port_bits  # Port traffic data
GET    /api/v0/resources/sensors          # All sensor readings
```

## Performance Tuning

### Database Optimization
- InnoDB buffer pool: Set to 50-70% of available RAM on database server
- Enable slow query log; optimize queries taking >1 second
- Regular table maintenance: `OPTIMIZE TABLE ports, devices, eventlog`
- Event log and syslog purge: configure retention to prevent unbounded growth

### Polling Performance
- **rrdcached**: Enable for all deployments over 500 devices
- **Polling threads**: `$config['threads']['poll']` -- increase for more parallel polling
- **Fast ping**: Enable `$config['fast_ping']` for ICMP availability (faster than SNMP availability check)
- **Poller modules**: Disable unused modules per device group (e.g., disable wireless polling for non-wireless devices)

### SNMP Performance
- Use SNMP v2c or v3 GET-BULK (more efficient than v1 GET-NEXT)
- Increase SNMP timeout for slow WAN links
- Reduce polling interval for non-critical devices (5 min -> 10 min)
- Use 64-bit counters (ifXTable) for high-speed interfaces

## Deployment Options

### Bare Metal / VM
- Ubuntu 22.04+ or Debian 12+ (recommended)
- RHEL/CentOS/Rocky 8+ supported
- Manual installation with community scripts

### Docker
- Official Docker image: `librenms/librenms`
- Docker Compose for full stack (LibreNMS + MariaDB + Redis + rrdcached)
- Suitable for single-server and small deployments

### Community Support
- GitHub: https://github.com/librenms/librenms
- Discord: Active community support channel
- Documentation: https://docs.librenms.org
- No commercial support (community only; third-party support available)
