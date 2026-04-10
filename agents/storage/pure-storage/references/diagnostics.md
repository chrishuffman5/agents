# Pure Storage FlashArray Diagnostics and Troubleshooting

## Pure1 Monitoring

### Access
URL: https://pure1.purestorage.com. Mobile app: "Pure 1" (iOS/Android). All arrays with outbound HTTPS (443) auto-register. SSO/SAML authentication.

### Dashboard
Fleet-wide status. Per-array: performance (IOPS, latency, bandwidth), capacity (used, available, effective), health, alerts, support cases, replication status.

### Array Performance
Real-time IOPS (read/write), latency histograms (avg, 95th, 99th percentile), bandwidth, queue depth, data reduction ratio (current + 30-day trend), capacity breakdown (unique data, dedup savings, compression, snapshots).

### Historical Analysis
Up to 1 year of history. Workload Planner overlays growth projections. Event timeline correlation.

## Pure1 Meta AIOps Alerts

| Severity | Action |
|---|---|
| Critical | Pure Support notified automatically; investigate immediately |
| Warning | Review within hours; follow remediation |
| Info | Review next maintenance window |

### Proactive Detection
Hardware degradation (DFM wear, component prediction), capacity trending, replication lag trends, performance anomalies, software fault risk. When detected: alert, auto-open support case, attach telemetry, email notification.

### Security Assessment
SafeMode coverage, Purity version currency, snapshot policy recommendations. Review quarterly.

## Performance Troubleshooting

### High Latency
1. **Scope**: one volume, one host, or all? Filter in Pure1 by volume/host/protocol
2. **Host vs array latency**: Pure1 shows array-side. If array normal but app slow = host issue (HBA queue depth, driver, multipath, OS)
3. **Array causes**: high queue depth, data reduction pressure, ActiveCluster near 11ms RTT limit, DFM in rebuild
4. **VM Analytics**: correlate VM I/O with array metrics. Check balloon memory pressure.

### IOPS Saturation
Check max spec vs utilization. "Top Volumes" and "Top Hosts" in Pure1. Set temporary per-volume limit if one volume dominates. Engage Workload Planner for expansion.

### Bandwidth Saturation
Check front-end port utilization. Verify multipath active (saturating one path while another idle = misconfiguration). Back-end saturation rare (possible during rebuilds).

## Connectivity Issues

### FC
1. Verify zoning (initiator WWPN in zone with array target WWPN)
2. Check connections: `purehost list --connect`
3. Verify fabric login in Pure1 event log
4. Check HBA driver version (out-of-date = common FC issue)
5. Verify ALUA mode active, check TPGS settings

### iSCSI
1. Discovery: `iscsiadm -m discovery -t st -p <array-ip>`
2. Portal reachability: ping on data VLAN (not mgmt)
3. MTU consistency (mismatch silently breaks at larger transfers)
4. CHAP credentials (mismatch = auth failure without clear error)
5. Sessions: `iscsiadm -m session`

### NVMe/TCP
1. Verify initiator: `nvme list`
2. Discover: `nvme discover -t tcp -a <array-ip> -s 4420`
3. MTU consistency
4. Purity 6.4.2+ for default support

### Array Not in Pure1
Verify outbound HTTPS (443) to `pure1.purestorage.com`. Check proxy: `purearray list --proxy`. Verify DNS. Contact Pure Support to reset registration if needed.

## Replication and ActiveCluster

### Checking Status
Pure1 > Replication tab: pod status, mediator state, ActiveDR lag, FlashBlade replication lag.
```
purepod list
purepod replica list
purepod mediator test --name <pod>
```

### ActiveDR Lag
Normal: seconds. Elevated (minutes+): check replication bandwidth, source write rate, network quality, target array load. Remediate: defer bulk writes during peak, increase bandwidth. Document in incident log if lag exceeds RPO SLA.

### ActiveCluster Pod Degraded
One array temporarily unreachable or replication network transient failure. Pod continues serving I/O (zero RTO achieved). Recovery: both arrays healthy + connected, resync begins automatically. Monitor: `purepod list` for sync percentage. Verify mediator: `purepod mediator test`.

### Split-Brain
Arrays use pre-election results (Purity 5.3+) to agree on winner. One pod continues, other suspends. After mediator restored, suspended pod resyncs. Do not force-unsuspend without confirming which array has current data.

### Planned Failover Testing
```
purepod failover --name <pod>   # non-destructive, replication continues
purepod list                     # verify serving from target
purepod failover --name <pod>   # fail back
```

## Hardware Health

### Component States
Healthy, Degraded, Failed, Rebuilding. Check via Pure1 Hardware tab or CLI: `puredrive list`, `purehw list`.

### DFM Health
Wear indicators continuous to Purity/Pure1. Predictive alerts 30-90 days ahead. On failure: auto-rebuild from parity. Do not insert new DFMs during rebuild without Pure Support.

### Controller Health
Dual active/active. One can fail with zero I/O impact. Automatic transparent failover. Pure Support handles replacement under Evergreen.

## Support

### Automatic Cases
Pure1 auto-opens for critical/warning hardware alerts. Includes serial, error codes, telemetry, recommended action.

### Manual Cases
Pure1 > Support > Cases > New Case. P1 (production down): call Pure Support directly.

### Log Collection
Pure1 has continuous logs — Support pulls without customer log bundle. Immediate upload: `purearray phonehome`. Offline: `purearray export log`.

### Purity Upgrade
Pure1 > array > Actions > Upgrade. Validates compatibility. NDU — controllers upgrade one at a time. Schedule during low activity as best practice.

## Common Issues Quick Reference

| Symptom | First Check | Common Cause |
|---|---|---|
| High app latency | Pure1 latency: array vs host side | Host multipath misconfiguration |
| Volume not visible | Zoning (FC) or iSCSI discovery | Missing zone or host connection |
| ActiveDR lag growing | Replication bandwidth | WAN saturation |
| Pod degraded | Pure1 events; inter-array network | Replication network failure |
| Array not in Pure1 | Port 443 outbound; DNS; proxy | Firewall blocking call-home |
| DRR dropping | Workload data compressibility | Encrypted or pre-compressed data |
| SafeMode lock stuck | By design | Only Pure Support can release |
