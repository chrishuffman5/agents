# Cisco Catalyst SD-WAN Diagnostics Reference

## Control Plane Diagnostics

### OMP Sessions
```
! Show OMP peer sessions to vSmart
show sdwan omp peers

! Show OMP routes for a specific VPN
show sdwan omp routes vpn 1

! Show all learned TLOCs
show sdwan omp tlocs

! Show service routes (service chaining)
show sdwan omp services
```

### Control Connections
```
! Show all control connections (to vManage, vSmart, vBond)
show sdwan control connections

! Show connection history (useful for diagnosing flaps)
show sdwan control connections-history

! Show certificate validity
show sdwan certificates validity

! System status overview
show sdwan system status
```

### Control Connection Troubleshooting Flow

1. **Check basic reachability**: Can WAN Edge reach vBond public IP?
   ```
   ping vrf 0 <vbond-ip>
   ```

2. **Check control connections**: Are DTLS/TLS sessions established?
   ```
   show sdwan control connections
   ```
   Expected: Connections to vBond (port 12346), vSmart (12346), vManage (12446)

3. **Check connection history**: Why did a connection fail?
   ```
   show sdwan control connections-history
   ```
   Look for error codes: `DCONFAIL` (config mismatch), `CHMISMATCH` (chassis mismatch), `SERNOTFOUND` (serial not in whitelist)

4. **Check certificates**: Are certificates valid and not expired?
   ```
   show sdwan certificates installed
   show sdwan certificates validity
   ```

5. **Check OMP peers**: Is OMP session to vSmart established?
   ```
   show sdwan omp peers
   ```
   State should be `Up`. If `Init` or `Handshake`, check DTLS between WAN Edge and vSmart.

## Data Plane Diagnostics

### BFD Sessions
```
! Show all BFD sessions and state
show sdwan bfd sessions

! Summary of BFD session states
show sdwan bfd summary

! BFD session history (flaps, state changes)
show sdwan bfd history
```

**Reading BFD output**:
- `state: up` -- Tunnel is active and healthy
- `state: down` -- Tunnel is failed; check underlay connectivity
- `jitter`, `latency`, `loss` columns show current path quality metrics

### Tunnel Statistics
```
! Show all tunnel statistics (packets, bytes, drops)
show sdwan tunnel statistics

! Show tunnel SLA class compliance
show sdwan tunnel sla-class

! Show IPsec session details
show sdwan ipsec outbound-connections
show sdwan ipsec inbound-connections
```

### App-Route Statistics
```
! Show per-tunnel app-route statistics (latency, jitter, loss)
show sdwan app-route statistics

! Filter to specific remote system-IP
show sdwan app-route stats remote-system-ip 10.0.0.5

! Show app-route SLA class compliance
show sdwan app-route stats sla-class
```

**In SD-WAN Manager**: Monitor > Network > App Route Statistics
- Per-tunnel BFD metrics: latency, jitter, loss
- SLA compliance per tunnel (pass/fail against each SLA class)
- Historical 24h / 7d / 30d graphs

### Interface Statistics
```
! Show SD-WAN interface status
show sdwan interface

! Show interface counters
show interfaces GigabitEthernet 0/0/0

! Show interface error counters
show interfaces GigabitEthernet 0/0/0 | include errors|drops|overruns
```

## Policy Diagnostics

### Verify Policy Application
```
! Show centralized policy pushed from vSmart
show sdwan policy from-vsmart

! Show app-route policy filter details
show sdwan policy app-route-policy-filter

! Show data policy
show sdwan policy data-policy-filter

! Show access lists
show sdwan policy access-list
```

### Verify Template Push
In SD-WAN Manager:
1. Configuration > Devices -- Check device status (In Sync / Out of Sync)
2. Configuration > Templates -- Check template attachment status
3. Monitor > Events -- Filter for template push events

## NWPI (Network-Wide Path Insights)

NWPI provides end-to-end path tracing across the SD-WAN fabric:

- **Visual topology**: Source branch to destination with per-hop detail
- **Per-hop metrics**: Latency, jitter, loss overlaid on topology diagram
- **20.18**: Automatic security alert tracing -- links IPS/UTD hits to specific path segments
- **Exportable**: Trace data in JSON/CSV for ticketing system integration

**Access**: SD-WAN Manager > Monitor > Network-Wide Path Insights

**Use cases**:
- Application performance complaints -- trace the exact path and identify degradation point
- Security incident correlation -- link UTD/IPS alerts to specific tunnel segments
- Capacity planning -- identify bottleneck hops in the path

## Radioactive Tracing (Deep Debug)

For deep packet-level debug on IOS-XE WAN Edge without impacting production:
```
! Enable radioactive trace for SD-WAN data plane
debug platform condition feature sdwan-data-plane submode all level verbose

! Start trace collection
debug platform condition start

! Reproduce the issue...

! Stop trace collection
debug platform condition stop

! Collect the trace file
show platform software trace message ios level verbose
```

**Warning**: Radioactive tracing generates significant output. Use `platform condition` filters (source IP, destination IP, interface) to scope the trace to specific traffic flows.

## Common Troubleshooting Scenarios

### WAN Edge Not Connecting to Controllers

| Step | Command | What to Check |
|---|---|---|
| 1 | `show sdwan control connections-history` | Error codes on failed connections |
| 2 | `ping vrf 0 <vbond-ip>` | Basic reachability to vBond |
| 3 | `show sdwan certificates validity` | Certificate expiration |
| 4 | `show clock` | NTP sync (cert validation requires correct time) |
| 5 | Check SD-WAN Manager device whitelist | Serial number must be registered |

### Tunnels Not Forming

| Step | Command | What to Check |
|---|---|---|
| 1 | `show sdwan omp tlocs` | Are remote TLOCs being received? |
| 2 | `show sdwan tunnel statistics` | Any tunnel in `down` state? |
| 3 | `show sdwan bfd sessions` | BFD session state and metrics |
| 4 | Check color configuration | TLOC color mismatch? Restrict flag set? |
| 5 | Check NAT/firewall at site | IPsec (UDP 12346, ESP) permitted? |

### Application on Wrong Path

| Step | Command | What to Check |
|---|---|---|
| 1 | `show sdwan policy app-route-policy-filter` | Is AAR policy applied? |
| 2 | `show sdwan app-route stats` | Are BFD metrics meeting SLA? |
| 3 | `show sdwan policy from-vsmart` | Is centralized policy active? |
| 4 | Check SLA class thresholds | Are thresholds realistic for the transport? |
| 5 | Check app-route polling-interval | Default 600s may be too slow for detection |

### Throughput Degradation

| Step | Command | What to Check |
|---|---|---|
| 1 | `show sdwan bfd sessions` | Elevated jitter/loss on tunnel? |
| 2 | `show interfaces` | Interface errors, drops, CRC? |
| 3 | `show sdwan tunnel statistics` | Packet drops per tunnel? |
| 4 | `show platform hardware qfp active statistics drop` | QFP hardware drop counters |
| 5 | Check underlay provider | ISP circuit quality issue? |

## Key CLI Reference Summary

```bash
# System
show sdwan system status
show version

# Control plane
show sdwan control connections
show sdwan omp peers
show sdwan omp routes vpn 1
show sdwan omp tlocs
show sdwan certificates validity

# Data plane
show sdwan tunnel statistics
show sdwan ipsec outbound-connections
show sdwan ipsec inbound-connections
show sdwan bfd sessions
show sdwan bfd summary

# App-route / AAR
show sdwan app-route statistics
show sdwan app-route stats remote-system-ip <ip>

# Policy
show sdwan policy from-vsmart
show sdwan policy app-route-policy-filter
show sdwan policy data-policy-filter

# Interface
show sdwan interface
show interfaces <name>

# Events and logs
show sdwan events
show logging | include SDWAN
```
