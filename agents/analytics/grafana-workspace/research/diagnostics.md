# Grafana Diagnostics

## Slow Dashboards

### Symptoms
- Long loading times for dashboards or individual panels
- Frequent timeouts or "Query failed" errors
- High CPU or memory usage on the Grafana server
- Slow response when switching time ranges or filters
- Browser becoming unresponsive when viewing complex dashboards

### Diagnostic Steps

**1. Use the Query Inspector**
- Open the affected panel, click the panel title, and select Inspect > Query
- Analyze query execution time, response size, and the number of data points returned
- Identify which specific queries are slow vs. fast
- Check the "Stats" tab for request duration and response byte count

**2. Check the Network Tab**
- Open browser DevTools (F12) > Network tab
- Reload the dashboard and identify slow API requests
- Look for `/api/ds/query` requests with long response times
- Check response payload sizes for excessively large data transfers

**3. Enable Grafana Server Metrics**
- Enable the Prometheus `/metrics` endpoint in `grafana.ini`:
  ```ini
  [metrics]
  enabled = true
  ```
- Monitor key metrics:
  - `grafana_api_response_status_total`: API response codes and counts
  - `grafana_ds_query_total`: Data source query counts and durations
  - `grafana_alerting_rule_evaluations_total`: Alert evaluation performance
  - `grafana_page_response_status_total`: Page load performance

**4. Check Grafana Server Logs**
- Look for slow query warnings in `grafana.log`
- Enable debug logging temporarily: `[log] level = debug`
- Check for connection timeout errors to data sources

### Common Causes and Solutions

**Too many panels per dashboard:**
- Problem: Each panel initiates separate data fetches; 30+ panels cause cumulative lag
- Solution: Split into multiple focused dashboards or use Grafana 12 tabs
- Solution: Use dashboard links for drill-down navigation between related dashboards

**Inefficient queries:**
- Problem: Queries pulling large datasets without proper filtering or aggregation
- Solution: Add label filters to reduce cardinality; use `topk()` or `bottomk()`
- Solution: Use recording rules for expensive aggregations
- Solution: Add `$__interval` for automatic resolution adjustment

**Excessive time range:**
- Problem: Querying months of high-resolution data
- Solution: Use per-panel time range overrides for panels that need shorter windows
- Solution: Use downsampling or recording rules for long-term trend panels

**Auto-refresh too frequent:**
- Problem: Low refresh intervals (5s, 10s) on dashboards with many panels
- Solution: Set refresh intervals to 30s-60s minimum for operational dashboards
- Solution: Use 5m-15m for trend and capacity dashboards

**High-cardinality queries:**
- Problem: Queries returning thousands of time series (e.g., per-pod metrics without aggregation)
- Solution: Aggregate across dimensions; use `sum by (service)` instead of per-instance
- Solution: Use Adaptive Metrics (Cloud) to identify and reduce unused series

**Missing caching:**
- Problem: Grafana does not cache data source responses by default
- Solution: Enable query caching in Enterprise/Cloud
- Solution: Use reverse proxy caching (Nginx, Varnish) in front of Grafana OSS
- Solution: Configure data source-side caching (e.g., Thanos query frontend, Cortex query frontend)

---

## Data Source Errors

### Symptoms
- "Data source is not configured" error messages
- "Bad Gateway" or "502" errors on panels
- "Unauthorized" or "Forbidden" errors
- "Connection refused" or "timeout" errors
- Panels showing "No data" when data is expected

### Diagnostic Steps

**1. Test Data Source Connectivity**
- Navigate to Configuration > Data Sources > select the source > "Save & Test"
- This tests authentication, network connectivity, and basic query capability
- Check the error message for specific failure details

**2. Check Data Source Proxy Logs**
- Grafana proxies data source requests; check `grafana.log` for proxy errors
- Look for TLS/SSL certificate errors, DNS resolution failures, or connection resets
- Enable data source request logging:
  ```ini
  [dataproxy]
  logging = true
  ```

**3. Verify Network Connectivity**
- From the Grafana server, test connectivity to the data source:
  ```bash
  curl -v http://prometheus-server:9090/api/v1/status/buildinfo
  curl -v http://loki:3100/ready
  curl -v http://tempo:3200/ready
  ```
- Check firewall rules, security groups, and network policies
- Verify DNS resolution from the Grafana server/pod

**4. Check Authentication**
- Verify credentials have not expired or been rotated
- For service accounts, verify token validity and permissions
- For OAuth/SSO data sources, check token refresh configuration
- Verify the Grafana service account has the required data source permissions

### Common Causes and Solutions

**Authentication failures:**
- Problem: Credentials expired, rotated, or misconfigured
- Solution: Re-enter or rotate credentials in data source settings
- Solution: Use secrets management (Vault, Grafana Cloud Secrets) for automated rotation
- Solution: Verify API key scopes match required permissions

**Network/connectivity issues:**
- Problem: DNS changes, firewall rule updates, or infrastructure changes
- Solution: Verify DNS resolution and network paths from Grafana server
- Solution: Check Kubernetes NetworkPolicies if running in K8s
- Solution: Verify TLS certificate validity and trust chain

**Data source version incompatibility:**
- Problem: Data source plugin version does not match backend version
- Solution: Update the data source plugin to a compatible version
- Solution: Check plugin release notes for breaking changes

**Rate limiting:**
- Problem: Data source or cloud provider rate limiting Grafana queries
- Solution: Reduce dashboard refresh frequency
- Solution: Implement query caching to reduce backend load
- Solution: Increase rate limits on the data source side if possible

---

## Alerting Failures

### Symptoms
- Alerts not firing when expected conditions are met
- False positive alerts (firing when conditions are not met)
- `DatasourceError` alerts appearing
- `NoData` alerts when data should be present
- Notifications not being delivered to contact points
- Alert evaluation errors in the alerting log

### Diagnostic Steps

**1. Check Alert Rule State and History**
- Navigate to Alerting > Alert Rules
- Click on the specific rule to view its current state, evaluation history, and any errors
- Check the "Instances" tab for per-series alert state

**2. Inspect Alert Rule Queries**
- Open the alert rule editor and click "Preview" to test the query
- Verify the query returns expected data
- Check expression results at each stage of the evaluation pipeline
- Test the same query in Explore to compare results

**3. Check Alert Evaluation Logs**
- Enable alerting debug logging:
  ```ini
  [unified_alerting]
  log_level = debug
  ```
- Look for evaluation timeout, query failure, or expression evaluation errors
- Check for `evaluation took longer than the schedule` warnings

**4. Verify Notification Pipeline**
- Check Alerting > Contact Points > test each integration
- Verify notification policy routing by checking which policy matches your alert labels
- Check for silences or mute timings that may be suppressing notifications
- Review alerting notification logs for delivery failures

### Common Causes and Solutions

**Evaluation timeouts:**
- Problem: Alert queries exceed the evaluation timeout (default 30s)
- Solution: Optimize queries to reduce execution time
- Solution: Increase `evaluation_timeout` in alerting configuration
- Solution: Use recording rules for expensive queries
- Solution: Reduce cardinality of queried data

**No Data handling:**
- Problem: Data source returns no data points, triggering NoData state
- Solution: Configure `nodata_state` explicitly: `Alerting`, `NoData`, `OK`, or `KeepLastState`
- Solution: Use `KeepLastState` for metrics that intermittently report
- Solution: Investigate why the data source is not returning data (scrape failures, retention gaps)

**DatasourceError alerts:**
- Problem: Alert evaluation fails due to data source connectivity or query errors
- Solution: Fix underlying data source connectivity issues (see Data Source Errors section)
- Solution: Configure `error_state` to `KeepLastState` to avoid false DatasourceError alerts during transient failures
- Solution: Set appropriate `max_attempts` for retry on transient failures

**Notification delivery failures:**
- Problem: Contact point integrations fail to deliver (webhook errors, API rate limits, authentication)
- Solution: Test contact points individually using the "Test" button
- Solution: Check webhook URLs, API keys, and authentication tokens
- Solution: Verify network connectivity from Grafana to notification targets (Slack API, SMTP server, PagerDuty API)
- Solution: Check for firewall rules blocking outbound connections

**Incorrect notification routing:**
- Problem: Alerts routed to wrong contact points or not matching any policy
- Solution: Review notification policy tree; alerts match top-down, first match wins
- Solution: Verify label matchers align with alert rule labels
- Solution: Check that mute timings are not suppressing expected notifications
- Solution: Use the notification policy preview to test routing for specific label sets

**Silence/mute timing issues:**
- Problem: Notifications suppressed by forgotten silences or misconfigured mute timings
- Solution: Review active silences in Alerting > Silences
- Solution: Check mute timings attached to notification policies
- Solution: Set expiration times on silences to prevent indefinite suppression

---

## Resource Usage

### Symptoms
- Grafana server high CPU utilization
- Memory consumption growing over time (memory leak patterns)
- Out-of-memory (OOM) kills in containerized deployments
- Slow API responses and UI interactions
- Database connection pool exhaustion

### Diagnostic Steps

**1. Monitor Grafana Server Metrics**
- Scrape the `/metrics` endpoint with Prometheus
- Key metrics to watch:
  - `process_resident_memory_bytes`: Current memory usage
  - `go_memstats_alloc_bytes`: Go runtime memory allocation
  - `go_goroutines`: Number of active goroutines (indicator of concurrent operations)
  - `grafana_http_request_duration_seconds`: API response latency
  - `grafana_ds_query_total`: Total data source queries (rate indicates load)

**2. Check Database Performance**
- Monitor the Grafana configuration database (SQLite, PostgreSQL, MySQL)
- Check for slow queries, connection pool exhaustion, or lock contention
- SQLite: watch for file-level locking issues under concurrent load
- PostgreSQL/MySQL: monitor connection count, query duration, and deadlocks

**3. Review Container/Pod Resources**
- Check Kubernetes resource limits vs. actual usage:
  ```bash
  kubectl top pods -n grafana
  kubectl describe pod <grafana-pod> -n grafana
  ```
- Check for OOMKilled events in pod events
- Review resource requests and limits in deployment manifests

**4. Profile Grafana**
- Enable Go pprof endpoint for detailed profiling:
  ```ini
  [server]
  enable_gzip = true

  [diagnostics]
  profiling_enabled = true
  profiling_addr = 0.0.0.0
  profiling_port = 6060
  ```
- Access CPU profile: `http://grafana:6060/debug/pprof/profile`
- Access heap profile: `http://grafana:6060/debug/pprof/heap`

### Memory Usage Baselines

| Deployment Size | Users | Expected Memory |
|----------------|-------|-----------------|
| Small | 5-10 | 200-500 MB |
| Medium | 10-50 | 500 MB - 2 GB |
| Large | 50-200 | 2-4 GB |
| Enterprise | 200+ | 4-8+ GB |

Memory scales with: number of concurrent users, dashboard complexity, number of panels rendered, alert rule count, and data source query volume.

### Common Causes and Solutions

**High concurrent user load:**
- Problem: Many users loading complex dashboards simultaneously
- Solution: Scale horizontally with multiple Grafana instances behind a load balancer
- Solution: Use session affinity (sticky sessions) for consistent user experience
- Solution: Implement CDN or reverse proxy caching for static assets

**Alert evaluation overhead:**
- Problem: Hundreds or thousands of alert rules consuming CPU and memory
- Solution: Use data source-managed alerting rules (Prometheus/Mimir ruler) to offload evaluation
- Solution: Consolidate alert rules where possible; use recording rules to reduce query complexity
- Solution: Stagger evaluation groups to avoid CPU spikes

**Plugin resource consumption:**
- Problem: Third-party plugins consuming excessive CPU or memory
- Solution: Monitor per-plugin resource usage via Grafana metrics
- Solution: Remove or replace poorly performing plugins
- Solution: Report issues to plugin maintainers

**Database bottlenecks:**
- Problem: SQLite limitations under concurrent load; slow database queries
- Solution: Migrate from SQLite to PostgreSQL or MySQL for production deployments
- Solution: Tune database connection pool settings
- Solution: Implement database read replicas for large deployments

**Unoptimized dashboards:**
- Problem: Dashboards with many panels, short refresh intervals, and wide time ranges
- Solution: Apply dashboard best practices (see best-practices.md)
- Solution: Implement dashboard review policies; limit panel count and refresh frequency
- Solution: Use Grafana Advisor (12.1) for automated dashboard health checks

### Self-Monitoring Setup

Create a Grafana self-monitoring dashboard that tracks:
1. **Server health**: CPU, memory, goroutines, GC pause duration
2. **API performance**: Request rate, latency percentiles, error rate
3. **Data source health**: Query rate, duration, error rate per data source
4. **Alerting health**: Evaluation duration, missed evaluations, notification failures
5. **Database health**: Connection pool usage, query duration, error rate
6. **User activity**: Concurrent users, dashboard load rate, API call patterns

Set up alerts on:
- Memory usage exceeding 80% of configured limits
- API latency P95 exceeding 5 seconds
- Data source error rate exceeding 5%
- Alert evaluation missing scheduled intervals
- Database connection pool nearing exhaustion
