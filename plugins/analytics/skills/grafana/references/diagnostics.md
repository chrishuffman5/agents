# Grafana Diagnostics Reference

## Slow Dashboard Diagnosis

### Symptoms

- Long loading times for dashboards or individual panels
- Frequent timeouts or "Query failed" errors
- High CPU or memory usage on the Grafana server
- Slow response when switching time ranges or filters
- Browser becoming unresponsive when viewing complex dashboards

### Step-by-Step Diagnostic Workflow

**1. Use the Query Inspector**

Open the affected panel > click the panel title > select **Inspect > Query**:
- Analyze query execution time, response size, and number of data points returned
- Identify which specific queries are slow vs fast
- Check the "Stats" tab for request duration and response byte count
- Export query results for offline analysis

**2. Check the Network Tab**

Open browser DevTools (F12) > Network tab:
- Reload the dashboard and identify slow API requests
- Look for `/api/ds/query` requests with long response times
- Check response payload sizes for excessively large data transfers
- Sort by duration to find the slowest requests

**3. Enable Grafana Server Metrics**

Enable the Prometheus `/metrics` endpoint in `grafana.ini`:
```ini
[metrics]
enabled = true
```

Key metrics to monitor:
- `grafana_api_response_status_total`: API response codes and counts
- `grafana_ds_query_total`: Data source query counts and durations
- `grafana_alerting_rule_evaluations_total`: Alert evaluation performance
- `grafana_page_response_status_total`: Page load performance

**4. Check Grafana Server Logs**

- Look for slow query warnings in `grafana.log`
- Enable debug logging temporarily:
  ```ini
  [log]
  level = debug
  ```
- Check for connection timeout errors to data sources
- Look for repeated error patterns indicating systemic issues

### Common Causes and Solutions

| Cause | Symptom | Solution |
|---|---|---|
| Too many panels (30+) | All panels slow; high page load time | Split into focused dashboards or use tabs; keep to 10-15 panels |
| Inefficient queries | Individual panels slow; high SE time in inspector | Add label filters; use `topk()`; use recording rules |
| Excessive time range | Large data transfers; slow rendering | Per-panel time range overrides; recording rules for trends |
| Auto-refresh too frequent | Constant load on data sources | 30s-60s for operational; 5m-15m for trends |
| High-cardinality queries | Thousands of time series per query | Aggregate: `sum by (service)` instead of per-instance |
| Missing caching | Same queries re-execute constantly | Enable query caching (Enterprise/Cloud); reverse proxy cache (OSS) |
| Browser rendering | Visual Display time dominates | Reduce data points per panel; simplify visual type |
| Large transformations | Panel-level transforms on large datasets | Move computation to recording rules or backend |

---

## Data Source Errors

### Symptoms

- "Data source is not configured" error messages
- "Bad Gateway" or "502" errors on panels
- "Unauthorized" or "Forbidden" errors
- "Connection refused" or "timeout" errors
- Panels showing "No data" when data is expected

### Diagnostic Process

**1. Test Data Source Connectivity**

Navigate to **Configuration > Data Sources** > select the source > **Save & Test**:
- Tests authentication, network connectivity, and basic query capability
- Check the error message for specific failure details

**2. Check Data Source Proxy Logs**

Grafana proxies data source requests; check `grafana.log` for proxy errors:
```ini
[dataproxy]
logging = true
```
Look for TLS/SSL certificate errors, DNS resolution failures, or connection resets.

**3. Verify Network Connectivity**

From the Grafana server/pod, test connectivity:
```bash
# Prometheus
curl -v http://prometheus-server:9090/api/v1/status/buildinfo

# Loki
curl -v http://loki:3100/ready

# Tempo
curl -v http://tempo:3200/ready

# Generic database
nc -zv database-host 5432
```

Check firewall rules, security groups, and Kubernetes NetworkPolicies.

**4. Check Authentication**

- Verify credentials have not expired or been rotated
- For service accounts, verify token validity and permissions
- For OAuth/SSO data sources, check token refresh configuration
- Verify the Grafana service account has required data source permissions

### Common Causes and Solutions

| Cause | Diagnostic Clue | Solution |
|---|---|---|
| Credential expiry/rotation | "Unauthorized" or "403" errors | Re-enter or rotate credentials; use Vault for automated rotation |
| DNS/network changes | "Connection refused" or DNS errors | Verify DNS resolution and network paths from Grafana |
| TLS certificate issues | SSL handshake errors in proxy logs | Update certificates; verify trust chain |
| Rate limiting | Intermittent 429 errors | Reduce refresh frequency; implement query caching |
| Data source version mismatch | Unexpected query failures | Update plugin to compatible version; check release notes |
| Kubernetes NetworkPolicy | Connection timeouts from Grafana pods | Allow egress to data source endpoints |

---

## Alerting Failures

### Symptoms

- Alerts not firing when expected conditions are met
- False positive alerts (firing when conditions are not met)
- `DatasourceError` alerts appearing
- `NoData` alerts when data should be present
- Notifications not being delivered to contact points
- Alert evaluation errors in the alerting log

### Diagnostic Process

**1. Check Alert Rule State and History**

Navigate to **Alerting > Alert Rules**:
- Click the specific rule to view current state, evaluation history, and errors
- Check the "Instances" tab for per-series alert state
- Review state transitions (Normal -> Pending -> Firing)

**2. Inspect Alert Rule Queries**

- Open the alert rule editor and click **Preview** to test the query
- Verify the query returns expected data
- Check expression results at each stage of the evaluation pipeline
- Test the same query in **Explore** to compare results

**3. Check Alert Evaluation Logs**

Enable alerting debug logging:
```ini
[unified_alerting]
log_level = debug
```

Look for:
- Evaluation timeout errors
- Query failures during evaluation
- Expression evaluation errors
- `evaluation took longer than the schedule` warnings

**4. Verify Notification Pipeline**

- Check **Alerting > Contact Points** > test each integration
- Verify notification policy routing by checking which policy matches alert labels
- Check for silences or mute timings suppressing notifications
- Review alerting notification logs for delivery failures

### Common Causes and Solutions

| Issue | Cause | Solution |
|---|---|---|
| Evaluation timeouts | Alert queries exceed timeout (default 30s) | Optimize queries; increase `evaluation_timeout`; use recording rules |
| NoData state | Data source returns no data points | Configure `nodata_state` to `KeepLastState` for intermittent metrics |
| DatasourceError alerts | Data source connectivity or query errors | Fix data source issues; set `error_state` to `KeepLastState` for transient failures |
| Notifications not delivered | Contact point integration failure | Test individually; check webhook URLs, API keys, network connectivity |
| Wrong notification routing | Alert labels don't match policy matchers | Review policy tree; verify label matchers; use policy preview |
| Silenced alerts | Forgotten silences or misconfigured mute timings | Review active silences; set expiration times; check mute timings on each policy level |
| Mute timing not working | Expected inheritance from parent | Mute timings are NOT inherited; apply at each relevant policy level |

---

## Resource Usage Monitoring

### Symptoms

- Grafana server high CPU utilization
- Memory consumption growing over time
- Out-of-memory (OOM) kills in containerized deployments
- Slow API responses and UI interactions
- Database connection pool exhaustion

### Diagnostic Process

**1. Monitor Grafana Server Metrics**

Scrape the `/metrics` endpoint with Prometheus:

| Metric | What It Indicates | Action Threshold |
|---|---|---|
| `process_resident_memory_bytes` | Current memory usage | >80% of limits |
| `go_memstats_alloc_bytes` | Go runtime memory allocation | Growing unbounded |
| `go_goroutines` | Active goroutines (concurrent operations) | Abnormally high |
| `grafana_http_request_duration_seconds` | API response latency | P95 > 5 seconds |
| `grafana_ds_query_total` | Data source query rate | Rate indicates load |

**2. Check Database Performance**

- Monitor the Grafana configuration database (SQLite, PostgreSQL, MySQL)
- Check for slow queries, connection pool exhaustion, or lock contention
- **SQLite**: Watch for file-level locking issues under concurrent load -- migrate to PostgreSQL
- **PostgreSQL/MySQL**: Monitor connection count, query duration, deadlocks

**3. Review Container/Pod Resources**

```bash
kubectl top pods -n grafana
kubectl describe pod <grafana-pod> -n grafana
```

- Check for OOMKilled events in pod events
- Review resource requests and limits in deployment manifests

**4. Profile Grafana**

Enable Go pprof endpoint:
```ini
[diagnostics]
profiling_enabled = true
profiling_addr = 0.0.0.0
profiling_port = 6060
```

- CPU profile: `http://grafana:6060/debug/pprof/profile`
- Heap profile: `http://grafana:6060/debug/pprof/heap`

### Memory Usage Baselines

| Deployment Size | Users | Expected Memory |
|---|---|---|
| Small | 5-10 | 200-500 MB |
| Medium | 10-50 | 500 MB - 2 GB |
| Large | 50-200 | 2-4 GB |
| Enterprise | 200+ | 4-8+ GB |

Memory scales with: concurrent users, dashboard complexity, panel count, alert rule count, and query volume.

### Common Causes and Solutions

| Cause | Diagnostic Clue | Solution |
|---|---|---|
| High concurrent users | Many simultaneous dashboard loads | Scale horizontally; sticky sessions; CDN for static assets |
| Alert evaluation overhead | Hundreds/thousands of rules | Use data source-managed rules; recording rules; stagger evaluation groups |
| Plugin resource consumption | Per-plugin metrics show high usage | Remove or replace poorly performing plugins |
| SQLite under load | File locking errors; slow operations | Migrate to PostgreSQL or MySQL |
| Unoptimized dashboards | High panel count, frequent refresh | Apply dashboard best practices; limit panels; increase refresh intervals |
| Database bottlenecks | Slow config queries; pool exhaustion | Tune connection pool; add read replicas |

---

## Self-Monitoring Setup

### Recommended Self-Monitoring Dashboard

Create a dashboard tracking:

1. **Server health**: CPU, memory, goroutines, GC pause duration
2. **API performance**: Request rate, latency percentiles (P50/P95/P99), error rate
3. **Data source health**: Query rate, duration, error rate per data source
4. **Alerting health**: Evaluation duration, missed evaluations, notification failures
5. **Database health**: Connection pool usage, query duration, error rate
6. **User activity**: Concurrent users, dashboard load rate, API call patterns

### Recommended Alerts

| Alert | Condition | Action |
|---|---|---|
| Memory high | `process_resident_memory_bytes` > 80% of limit | Investigate leak or scale |
| API latency high | P95 request duration > 5s | Check dashboard complexity and data sources |
| Data source errors | Error rate > 5% for any data source | Check connectivity and credentials |
| Missed alert evaluations | Evaluation takes longer than schedule | Optimize queries or reduce rule count |
| Database pool exhaustion | Active connections near max | Increase pool size or add replicas |

### Grafana Advisor (12.1 GA)

Automated health monitoring for Grafana instances:
- Detects plugin, data source, and SSO configuration issues
- Proactive recommendations for instance security and reliability
- Run periodically or when investigating issues
