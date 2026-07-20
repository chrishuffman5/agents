# Cisco Meraki Best Practices Reference

## API Patterns

### Rate Limit Management

The Meraki API enforces 10 calls per second per organization. Strategies to stay within limits:

**Exponential backoff:**
```python
import time
import requests

def api_call_with_retry(url, headers, max_retries=5):
    for attempt in range(max_retries):
        response = requests.get(url, headers=headers)
        if response.status_code == 429:
            retry_after = int(response.headers.get('Retry-After', 1))
            time.sleep(retry_after * (2 ** attempt))
            continue
        return response
    raise Exception("Max retries exceeded")
```

**Use the Meraki Python SDK:**
```python
import meraki
# SDK handles rate limiting automatically
dashboard = meraki.DashboardAPI(
    api_key='<key>',
    maximum_retries=5,
    wait_on_rate_limit=True
)
```

**Action batches for bulk operations:**
- Instead of 100 individual API calls (10 seconds minimum), use one action batch
- Synchronous: up to 100 actions, immediate result
- Asynchronous: up to 1000 actions, poll for completion
- Atomic: all-or-nothing execution

### Pagination Handling

```python
# Using the SDK (handles pagination automatically)
networks = dashboard.organizations.getOrganizationNetworks(
    organizationId='12345',
    total_pages='all'  # SDK follows pagination links automatically
)

# Manual pagination with requests
url = f'https://api.meraki.com/api/v1/organizations/{org_id}/networks'
headers = {'X-Cisco-Meraki-API-Key': api_key}
all_results = []

while url:
    response = requests.get(url, headers=headers)
    all_results.extend(response.json())
    # Check for next page in Link header
    links = response.headers.get('Link', '')
    url = None
    if 'rel=next' in links:
        url = links.split(';')[0].strip('<> ')
```

### API Key Security

- Store API keys in environment variables or secrets managers (never in code)
- Use organization-scoped API keys (not full admin keys when possible)
- Rotate API keys periodically
- Audit API key usage via Dashboard: Organization > API & Webhooks
- Use webhook shared secrets for payload validation

### Idempotent Operations

- PUT operations are idempotent -- same request produces same result
- Use PUT for configuration management (desired-state model)
- Action batches provide atomicity for multi-resource updates
- Always check current state before making changes in automation scripts

## Network Design

### Site Architecture

**Small branch (< 50 users):**
```
MX67/MX68 (firewall, AutoVPN, DHCP)
  |- MS120/MS125 (access switch, PoE)
  |- MR46 (Wi-Fi 6 AP)
```

**Medium branch (50-200 users):**
```
MX84/MX95 (firewall, AutoVPN)
  |- MS250 (distribution, L3 routing)
      |- MS120/MS125 (access, PoE)
      |- MS120/MS125 (access, PoE)
  |- MR46 x 4-8 (Wi-Fi 6 APs)
```

**Large campus (200+ users):**
```
MX250/MX450 (firewall, AutoVPN)
  |- MS425 (core, 40G uplinks)
      |- MS390 stack (distribution, L3)
          |- MS130/MS210 (access, PoE)
      |- MS390 stack (distribution, L3)
          |- MS130/MS210 (access, PoE)
  |- MR56/MR78 x 20+ (Wi-Fi 6/6E APs)
```

### VLAN Design

- **VLAN 1**: Never use for production traffic (Meraki default management VLAN)
- **Data VLAN**: User workstations (e.g., VLAN 10)
- **Voice VLAN**: VoIP phones (e.g., VLAN 20, with DSCP marking)
- **Guest VLAN**: Isolated guest access (e.g., VLAN 30, internet-only via content filter)
- **IoT VLAN**: Sensors, cameras, building management (e.g., VLAN 40)
- **Management VLAN**: Switch and AP management (e.g., VLAN 99)

### AutoVPN Subnet Planning

- Plan non-overlapping subnets across ALL sites before deploying
- Use consistent VLAN numbering across sites (VLAN 10 = data everywhere)
- Use per-site subnet ranges: Site 1 = 10.1.0.0/16, Site 2 = 10.2.0.0/16, etc.
- Document all subnets in Dashboard network tags or external IPAM

### Wireless Design

- Maximum 3-4 SSIDs in production (excessive SSIDs reduce airtime efficiency)
- Separate corporate (802.1X) and guest (PSK or splash page) SSIDs
- Enable band steering to push capable clients to 5 GHz
- Use 5 GHz for primary data; 2.4 GHz for IoT/legacy only
- Enable client isolation on guest SSIDs
- Set minimum bitrate to 12 Mbps (prevents slow clients from degrading performance)

## Licensing Strategy

### License Planning

- **New deployments**: Use Per-Device Licensing (PDL) for flexibility
- **Uniform deployments**: Co-term licensing simplifies renewal but locks all devices to same expiry
- **Budget**: 3-year licenses offer best per-year pricing vs 1-year
- **MX tier**: Choose Advanced Security for IDS/IPS-required environments; Enterprise is sufficient for basic SD-WAN

### License Tier Comparison

| Feature | Enterprise | Advanced Security | Secure SD-WAN Plus |
|---|---|---|---|
| Stateful firewall | Yes | Yes | Yes |
| AutoVPN | Yes | Yes | Yes |
| Content filtering | Yes | Yes | Yes |
| Traffic shaping | Yes | Yes | Yes |
| IDS/IPS | No | Yes | Yes |
| AMP (Anti-Malware) | No | Yes | Yes |
| URL category filtering | No | Yes | Yes |
| Meraki Insight | No | No | Yes |
| WAN health monitoring | Basic | Basic | Advanced (per-app) |

### License Gotchas

- MX licenses must be uniform per organization (cannot mix Enterprise and Advanced Security)
- MS and MR licenses are independent of MX tier
- License expiration = device becomes non-functional after 30-day grace period
- Renewals should be initiated 90+ days before expiry to avoid gaps
- Co-term to PDL migration is possible but requires Cisco account team involvement

## When Meraki vs Traditional

### Choose Meraki When

| Factor | Meraki Strength |
|---|---|
| **IT team size** | Small team, limited CLI expertise -- Dashboard simplicity reduces OPEX |
| **Site count** | Many distributed sites (retail, branches) -- centralized management shines |
| **Deployment speed** | Fast timelines -- zero-touch provisioning eliminates pre-staging |
| **Policy consistency** | Same config across 100+ sites -- templates enforce uniformity |
| **Skill availability** | Network generalists -- Dashboard accessible without deep protocol knowledge |
| **Cloud-first** | SaaS comfort -- organization accepts cloud management dependency |
| **Cisco ecosystem** | Integration with Cisco SecureX, Umbrella, Duo, ISE |

### Choose Traditional When

| Factor | Traditional Strength |
|---|---|
| **Protocol depth** | Complex routing (MPLS, advanced BGP policies, segment routing) |
| **Compliance** | Regulations prohibit cloud management dependency |
| **Data center** | High-port-density DC switching (Nexus 9000, Arista 7000 series) |
| **CLI expertise** | Team is experienced and values on-premises CLI control |
| **TCO at scale** | Perpetual licensing favored at large scale (1000+ switches) |
| **Customization** | Deep QoS policies, advanced STP tuning, VXLAN/EVPN fabrics |
| **Multi-vendor** | Organization uses or requires non-Cisco equipment |

### Hybrid Deployment Patterns

Meraki coexists well with traditional networking:

**Pattern 1: Meraki branches, traditional HQ/DC**
```
HQ: Palo Alto/ASA firewall, Catalyst 9000 campus, Nexus DC
  |- IPsec VPN to Meraki AutoVPN hub (MX250 or vMX)
Branches: MX + MS + MR (full Meraki stack)
```

**Pattern 2: Meraki wireless, traditional wired**
```
Campus: Catalyst 9300/9400 switching core
  |- MR APs connected to Catalyst access ports
  |- MR APs managed via Dashboard; switches managed via Catalyst Center
```

**Pattern 3: Meraki SD-WAN overlay**
```
Existing network: MPLS + internet at each site
  |- MX deployed alongside existing firewall
  |- AutoVPN over internet as MPLS backup/offload
  |- Gradual migration from MPLS to SD-WAN
```

### Migration Considerations

- Meraki MX replaces edge firewall/router (ASA, ISR, FortiGate)
- MS switches replace access/distribution layer (Catalyst 2960, 3850)
- MR APs replace wireless (Aironet, Aruba, Ruckus)
- Migration can be phased: wireless first (lowest risk), then switching, then security appliance
- Dashboard API can automate Day-1 configuration for large-scale migrations

## Monitoring and Alerting

### Dashboard Alerts

Configure alerts for operational events:
- Device goes offline (critical: indicates site-level outage)
- VPN tunnel down (critical for SD-WAN dependent sites)
- Rogue AP detected (security event)
- Client count exceeds threshold (capacity planning)
- WAN uplink failover (indicates WAN issue)

### Meraki Insight (Secure SD-WAN Plus)

Enhanced monitoring for WAN and application health:
- Per-application latency and loss metrics across WAN
- VoIP health scoring (MOS score estimation)
- ISP SLA tracking (compare observed vs contracted performance)
- Application health scoring with root cause identification
- Useful for: proving ISP SLA violations, identifying app performance issues

### Integration with External Monitoring

- **Syslog**: MX/MS/MR can send syslog to external collector (Splunk, ELK)
- **SNMP**: Supported for device monitoring (CPU, memory, interface stats)
- **Webhooks**: Real-time event notifications to ITSM, Slack, PagerDuty
- **API polling**: Custom scripts query Dashboard API for metrics (respect rate limits)
- **Cisco SecureX**: Unified security dashboard integrating Meraki, Umbrella, AMP, Duo

## Troubleshooting Tools

### Dashboard Live Tools

Available for connected devices:
- **Ping**: Ping from the device to a target IP
- **Traceroute**: Traceroute from device to destination
- **Cable test**: Test cable integrity on switch ports
- **Throughput test**: Test throughput between device and Meraki cloud
- **ARP table**: View device ARP entries
- **Routing table**: View device routing table (MX)
- **DHCP leases**: View active DHCP leases (MX)
- **LLDP/CDP**: View connected neighbor devices

### Event Log

- Searchable log of all device events (client associations, DHCP, VPN, firmware)
- Filter by: event type, client MAC/IP, device serial, time range
- Export to CSV for offline analysis
- Retention: 30 days (standard), longer with syslog forwarding

### Local Status Page

- Accessible at `my.meraki.com` from a device on the same network
- Provides: device IP, uplink status, serial number, firmware version
- Limited diagnostics -- not a full management interface
- Useful when Dashboard is unreachable (WAN outage)
