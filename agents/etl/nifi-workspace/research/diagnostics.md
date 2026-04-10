# Apache NiFi Diagnostics

## Common Issues

### Back Pressure

**Symptoms:**
- Connection queues fill up (visible as yellow/red indicators in the UI)
- Upstream processors stop being scheduled
- Data flow stalls or slows dramatically
- FlowFiles age in queues (increasing latency)

**Causes:**
- Downstream processor is slower than upstream (throughput mismatch)
- Downstream processor is in an error state and not processing
- External system (database, API, file system) is unresponsive or slow
- Incorrectly configured thresholds (too low triggers premature back pressure; too high risks resource exhaustion)

**Resolution:**
1. Identify the bottleneck processor (check processor stats: in vs. out FlowFile counts)
2. Check downstream processor bulletins for errors
3. Increase concurrent tasks on the bottleneck processor if I/O-bound
4. Scale the cluster if CPU/memory-bound
5. Adjust back pressure thresholds if the defaults don't match the workload:
   - Object threshold (default: 10,000 FlowFiles)
   - Data size threshold (default: 1 GB)
6. Check external system health (database connections, API availability)
7. Consider adding intermediate buffering (MergeRecord to batch, ControlRate to throttle)

**Monitoring:**
- Connection queue status is visible in the NiFi UI (object count, data size, percentage full)
- REST API: `/nifi-api/connections/{id}` returns queue size and back pressure status
- Prometheus metrics for connection queue sizes when using the reporting task

---

### Memory Pressure

**Symptoms:**
- High CPU or memory usage reported in System Diagnostics
- Slow, unresponsive NiFi UI
- JVM garbage collection pauses (visible in GC logs)
- OutOfMemoryError in nifi-app.log
- Node disconnections in clustered environments
- JVM crashes

**Causes:**
- Inadequate JVM heap sizing for the workload
- Too many FlowFiles in flight (large queues across many connections)
- Large FlowFile content loaded into memory (e.g., processors that buffer entire content)
- Excessive concurrent tasks creating too many threads
- Provenance or Content Repository growing unchecked
- Memory leaks in custom processors or scripts

**Resolution:**
1. **Increase JVM heap**: Edit `bootstrap.conf`:
   ```
   java.arg.2=-Xms4g
   java.arg.3=-Xmx4g
   ```
   Allocate 50-75% of available RAM. Leave remaining for OS disk caching.
2. **Reduce in-flight FlowFiles**: Lower back pressure thresholds on connections to limit queue sizes.
3. **Avoid content buffering**: Use streaming processors where possible. Avoid loading entire FlowFile content into memory for large files.
4. **Tune garbage collection**: Use G1GC (default in Java 21). Monitor GC logs for long pauses:
   ```
   java.arg.13=-Xlog:gc*:file=./logs/nifi-gc.log
   ```
5. **Reduce concurrent tasks**: Lower total thread count if memory pressure is from thread overhead.
6. **Configure Content Repository cleanup**: Set appropriate `nifi.content.claim.max.appendable.size` and ensure garbage collection runs regularly.
7. **Configure Provenance Repository limits**:
   ```
   nifi.provenance.repository.max.storage.size=10 GB
   nifi.provenance.repository.max.storage.time=30 days
   nifi.provenance.repository.rollover.time=30 secs
   ```

---

### Processor Errors

**Symptoms:**
- Red error indicator on processor in UI
- Bulletins appearing on processor (visible as icon overlay)
- FlowFiles routing to `failure` relationship
- Processor in STOPPED or INVALID state

**Common Error Types:**

| Error | Typical Cause | Resolution |
|-------|--------------|------------|
| Connection refused / timeout | External system down or unreachable | Verify network connectivity, firewall rules, service health |
| Authentication failure | Invalid credentials or expired tokens | Update credentials in controller services or parameter contexts |
| Schema mismatch | Input data doesn't match expected schema | Validate input data; use ValidateRecord to filter non-conforming records |
| Permission denied | File system or service permissions | Fix permissions; check NiFi user identity |
| SQL exception | Bad query, constraint violation, connection pool exhaustion | Review SQL, check database constraints, increase connection pool size |
| NullPointerException | Missing required FlowFile attributes or content | Add attribute validation before the failing processor |
| Invalid configuration | Missing required properties or invalid values | Review processor configuration; check for deprecated properties after upgrade |

**Resolution Steps:**
1. Check the processor's bulletin (hover over the processor or check the Bulletin Board)
2. Review `nifi-app.log` for detailed stack traces
3. Inspect the FlowFile in the incoming connection queue (right-click connection -> List queue -> View attributes and content)
4. Test with a simple FlowFile to isolate the issue
5. Check controller service status (ensure referenced services are enabled)

---

### Clustering Issues

**Symptoms:**
- Nodes showing as DISCONNECTED in the cluster summary
- Flows not propagating to all nodes
- Inconsistent processing (some nodes working, others not)
- ZooKeeper connection errors in logs
- "Unable to communicate with cluster" errors

**Common Causes:**

| Issue | Cause | Resolution |
|-------|-------|------------|
| Node disconnection | Network partition, ZooKeeper timeout, node overload | Check network, ZooKeeper health, node resources |
| Flow out of sync | Manual edits on individual nodes, version conflicts | Use NiFi Registry/Git for flow versioning; re-sync from coordinator |
| Primary node failover | Primary node crashed or disconnected | Automatic via ZooKeeper election; verify new primary node is operational |
| ZooKeeper quorum loss | Majority of ZK nodes down | Restore ZK nodes; requires majority for quorum |
| Split brain | Network partition isolating groups of nodes | Resolve network partition; may require manual intervention to rejoin |
| K8s lease expiry | Pod rescheduling, resource pressure | Check pod health; review lease TTL configuration |

**Clustering Health Checks:**
1. Verify all nodes are connected: NiFi UI -> Cluster Summary (hamburger menu)
2. Check ZooKeeper status: `echo ruok | nc zookeeper-host 2181` (should return `imok`)
3. Review `nifi-app.log` on disconnected nodes for root cause
4. Verify network connectivity between all nodes (NiFi ports + ZooKeeper ports)
5. Check time synchronization across nodes (NTP)

---

## Performance Monitoring

### Bulletin Board

The Bulletin Board is NiFi's real-time alerting mechanism:

- **Access**: Global Menu -> Bulletin Board, or status bar at top of UI
- **Severity levels**: DEBUG, INFO, WARNING, ERROR
- **Scope**: System-level bulletins (status bar) and component-level bulletins (processor/connection icons)
- **Filtering**: Filter by component, severity, message content, and time range
- **Retention**: Bulletins are retained for a configurable period (default: 5 minutes)

**Key bulletins to watch for:**
- ERROR bulletins on any processor (indicates processing failures)
- WARNING bulletins on controller services (connectivity issues)
- System-level bulletins about memory, disk, or cluster state

### System Diagnostics

Access via the Global Menu -> System Diagnostics or REST API `/nifi-api/system-diagnostics`:

| Metric | Description | Warning Threshold |
|--------|-------------|-------------------|
| **Heap Usage** | JVM heap memory utilization | >80% sustained |
| **Non-Heap Usage** | Metaspace and other non-heap memory | Unusual growth |
| **Processor Load** | System CPU load average | >80% sustained |
| **Thread Count** | Total active JVM threads | Unusual growth |
| **Uptime** | Time since NiFi started | Frequent restarts |
| **FlowFile Repository Usage** | Disk usage for FlowFile repo | >80% |
| **Content Repository Usage** | Disk usage for Content repo | >80% |
| **Provenance Repository Usage** | Disk usage for Provenance repo | >80% |
| **Garbage Collection** | GC count and time | Long pauses (>500ms) |

### Provenance Analysis

Data provenance provides deep insight into flow behavior:

- **Lineage view**: Visual DAG showing the complete path of a FlowFile through the system
- **Event search**: Query provenance events by processor, FlowFile UUID, time range, event type
- **Replay**: Re-submit a FlowFile from any point in its lineage for debugging
- **Event types tracked**: CREATE, RECEIVE, SEND, CLONE, FORK, JOIN, ROUTE, MODIFY_CONTENT, MODIFY_ATTRIBUTES, DROP, EXPIRE, DOWNLOAD, FETCH, ADDINFO

**Performance impact of provenance:**
- Provenance indexing (Lucene) generates significant I/O
- High-volume flows may need reduced provenance detail or separate provenance disk
- Consider setting `nifi.provenance.repository.indexed.fields` to only the fields you need to search

### Reporting Tasks

Built-in background monitoring:

| Reporting Task | Purpose |
|---------------|---------|
| **MonitorDiskUsage** | Alert when repository disk usage exceeds threshold |
| **MonitorMemory** | Alert when JVM memory pool usage exceeds threshold |
| **ControllerStatusReportingTask** | Report overall controller status metrics |
| **SiteToSiteProvenanceReportingTask** | Forward provenance events to remote NiFi or external system |
| **PrometheusReportingTask** | Export metrics in Prometheus format |

---

## Troubleshooting Procedures

### Flow Debugging

**Step-by-step approach:**

1. **Identify the problem area**: Look for processors with error bulletins, connections with growing queues, or processors with zero output.

2. **Check the Bulletin Board**: Global Menu -> Bulletin Board. Filter by ERROR severity. Note which components are reporting errors and the error messages.

3. **Inspect connection queues**: Right-click a connection -> "List queue" to see queued FlowFiles. Examine individual FlowFiles:
   - **View attributes**: Check that expected attributes are present and correctly formatted
   - **View content**: Download or view in-browser to verify data format and content

4. **Review provenance**: Right-click a processor -> "View data provenance". Find the problematic FlowFile and trace its lineage backward to identify where the issue was introduced.

5. **Use DebugFlow processor**: Insert a DebugFlow processor to simulate specific failure modes (e.g., throw exception, yield, penalize) for testing error handling flows.

6. **Check processor stats**: Right-click a processor -> "View status history". Review:
   - Tasks/Time: How long processing takes per execution
   - FlowFiles In/Out: Throughput rates
   - Bytes Read/Written: Data volume
   - Identify trends (degradation over time, periodic spikes)

7. **Review logs**: Check `nifi-app.log` for detailed error messages and stack traces. Use `nifi-user.log` for access-related issues.

### FlowFile Inspection

**Inspecting queued FlowFiles:**

1. Right-click the connection -> "List queue"
2. Select a FlowFile from the list
3. Click the "eye" icon to view details:
   - **Attributes tab**: All key-value attribute pairs
   - **Content tab**: View or download the FlowFile content
4. For the content tab, NiFi can render common formats (text, JSON, XML, hex view)
5. The queue listing shows: position, FlowFile UUID, filename, file size, queue duration, lineage duration

**Inspecting FlowFile provenance:**

1. Right-click processor -> "View data provenance"
2. Search by FlowFile UUID, time range, component, or event type
3. Click a provenance event to see:
   - Input and output attributes (before and after)
   - Content claim references (can view/download content at that point)
   - Processing time, component ID, event type
4. Click "Lineage" to see the visual DAG of the FlowFile's journey

### Connection Queue Monitoring

**Monitoring approaches:**

1. **UI-based**: Connections display object count and data size. Color coding indicates back pressure status:
   - Green: Normal
   - Yellow: Approaching threshold
   - Red: Back pressure active

2. **REST API-based**:
   ```
   GET /nifi-api/connections/{id}/status
   ```
   Returns: queuedCount, queuedSize, percentUseCount, percentUseBytes

3. **Programmatic monitoring**: Use the REST API to poll all connections and alert on:
   - Queue size exceeding a percentage of back pressure threshold
   - Queue growth rate (increasing over time)
   - Oldest FlowFile age (detecting stuck FlowFiles)

4. **Prometheus integration**: The PrometheusReportingTask exports connection queue metrics for Grafana dashboards and alerting.

### Log Files

| Log File | Contents |
|----------|----------|
| `nifi-app.log` | Main application log: processor errors, framework events, stack traces |
| `nifi-user.log` | User actions: login, flow changes, access denials |
| `nifi-bootstrap.log` | NiFi startup/shutdown, JVM launch parameters |
| `nifi-deprecation.log` | Deprecated feature usage (important for migration planning) |
| `nifi-gc.log` | JVM garbage collection events (if configured) |

### Common Diagnostic Commands

**Check NiFi status:**
```bash
./bin/nifi.sh status
```

**View system diagnostics via REST API:**
```bash
curl -k https://localhost:8443/nifi-api/system-diagnostics
```

**Check cluster status:**
```bash
curl -k https://localhost:8443/nifi-api/controller/cluster
```

**List all connections with queue sizes:**
```bash
curl -k https://localhost:8443/nifi-api/flow/process-groups/root/status?recursive=true
```

**Check ZooKeeper health (1.x clusters):**
```bash
echo ruok | nc zookeeper-host 2181
echo stat | nc zookeeper-host 2181
```

---

## Performance Tuning Checklist

- [ ] JVM heap sized to 50-75% of available RAM
- [ ] Repositories on separate fast disks (SSD/NVMe)
- [ ] Content Repository spread across multiple partitions
- [ ] Provenance Repository with appropriate retention limits
- [ ] Concurrent tasks tuned per processor based on workload type
- [ ] Back pressure thresholds set appropriately for each connection
- [ ] MergeRecord/MergeContent used before data egress
- [ ] Record-oriented processors used instead of per-FlowFile processing
- [ ] Monitoring configured (Prometheus, disk alerts, memory alerts)
- [ ] GC logging enabled for diagnosing memory issues
- [ ] Load-balanced connections configured in clusters
- [ ] Run schedule appropriate (not polling too frequently when idle)

---

## Sources

- [Preventing Bottlenecks: Handling Dataflow Backpressure in NiFi](https://www.ksolves.com/blog/big-data/handle-dataflow-backpressure-in-nifi)
- [Monitoring Apache NiFi's Back Pressure](https://developers.ascendcorp.com/monitoring-apache-nifis-back-pressure-c63ce8d1ca84)
- [Achieving Peak Performance in Apache NiFi - ClearPeaks](https://www.clearpeaks.com/achieving-peak-performance-in-apache-nifi-health-checks-optimisation-strategies/)
- [Top 10 Apache NiFi Debugging Mistakes](https://www.dfmanager.com/blog/top-10-apache-nifi-debugging-mistakes)
- [Debugging NiFi Data Flows - Data Flow Manager](https://www.dfmanager.com/blog/debugging-nifi-data-flows)
- [Monitoring Apache NiFi Data Flows](https://www.dfmanager.com/blog/monitoring-apache-nifi-data-flows)
- [Why NiFi Flows Fail and How to Fix Them](https://www.dfmanager.com/blog/why-nifi-flows-fail-how-to-fix-them-with-agentic-ai)
- [Apache NiFi User Guide - Monitoring](https://nifi.apache.org/docs/nifi-docs/html/user-guide.html)
- [DebugFlow Processor Documentation](https://nifi.apache.org/components/org.apache.nifi.processors.standard.DebugFlow/)
- [MonitoFi - GitHub](https://github.com/microsoft/MonitoFi)
