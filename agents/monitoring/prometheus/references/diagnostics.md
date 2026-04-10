# Prometheus Diagnostics

## TSDB Status and Analysis

Access the TSDB status page at `http://prometheus:9090/tsdb-status` or via API:

```bash
curl http://prometheus:9090/api/v1/status/tsdb | jq .
```

Key fields:
- `headStats.numSeries`: Total active time series in head block
- `headStats.numSamples`: Total samples in head block
- `headStats.numChunks`: Number of chunks in head block
- `seriesCountByMetricName[]`: Top metrics by series count
- `labelValueCountByLabelName[]`: Top labels by unique value count (high value = high cardinality)
- `memoryInBytesByLabelName[]`: Memory used per label name
- `seriesCountByLabelValuePair[]`: Top label=value pairs by series count

## Cardinality Analysis

**Find top cardinality metrics via API:**
```bash
curl -s 'http://prometheus:9090/api/v1/status/tsdb' | \
  jq '.data.seriesCountByMetricName | sort_by(-.count) | .[0:20]'
```

**PromQL cardinality queries:**
```promql
# Count all active series
count({__name__!=""})

# Series count per metric name
count by (__name__) ({__name__!=""})

# Series per job
count by (job) (up)

# Find metrics with many label values for a specific label
count by (handler) (http_requests_total)
```

**promtool cardinality analysis:**
```bash
promtool tsdb analyze /var/lib/prometheus --limit 20
```

## Scrape Failure Diagnosis

**Check scrape status in UI:** `http://prometheus:9090/targets`

**PromQL queries for scrape health:**
```promql
# Targets currently down
up == 0

# Scrape duration (slow exporters)
scrape_duration_seconds > 10

# Sample limit exceeded
scrape_samples_post_metric_relabeling < scrape_samples_scraped

# Scrapes exceeding sample_limit
scrape_exceeded_sample_limit != 0
```

**Via API:**
```bash
curl http://prometheus:9090/api/v1/targets | \
  jq '.data.activeTargets[] | {job, instance, health, lastError}'
```

**Common scrape failure causes:**

| Error | Cause | Fix |
|-------|-------|-----|
| Connection refused | Target not listening | Check `__address__` after relabeling, verify service is running |
| Context deadline exceeded | Target too slow | Increase `scrape_timeout`, optimize exporter |
| Sample limit | Too many metrics | Add `metric_relabel_configs` to drop unneeded metrics |
| TLS error | Certificate mismatch or expiry | Check `tls_config`, verify certs |
| 401 Unauthorized | Missing or wrong auth | Verify `basic_auth` / `bearer_token` configuration |

## High Memory Usage

Prometheus memory is dominated by the head block (active time series):

```promql
# Check process memory
process_resident_memory_bytes{job="prometheus"}

# Active series count
prometheus_tsdb_head_series

# Chunks in head
prometheus_tsdb_head_chunks
```

**Diagnosis steps:**
1. Check `prometheus_tsdb_head_series` -- if > 1M, cardinality is likely the problem
2. Use TSDB status to find top offending metrics (`seriesCountByMetricName`)
3. Drop unnecessary labels with `metric_relabel_configs` (`labeldrop`)
4. Drop entire unnecessary metrics with `action: drop`
5. Reduce number of targets if relabeling cannot help
6. Increase Prometheus memory limit (but fix cardinality root cause)

**Memory estimate:** Each active time series uses approximately 3-6 KB in the head block. 500,000 series = ~1.5-3 GB RAM.

## High Disk Usage

```promql
# TSDB block bytes on disk
prometheus_tsdb_storage_blocks_bytes

# WAL size
prometheus_tsdb_wal_storage_size_bytes

# Head bytes
prometheus_tsdb_head_chunks_storage_size_bytes
```

**Diagnosis:**
1. Verify retention settings: `--storage.tsdb.retention.time`, `--storage.tsdb.retention.size`
2. Check if compaction is running: `prometheus_tsdb_compactions_total` should increase over time
3. Tombstones accumulate if deletions are not applied -- wait for compaction or run `promtool tsdb clean`
4. Large blocks in `data/` directory: each 2h block should be small; large blocks may indicate compaction issues

## Slow Queries

```promql
# Query duration histogram (99th percentile)
histogram_quantile(0.99, rate(prometheus_engine_query_duration_seconds_bucket[5m]))
```

**Diagnosis:**
1. Check execution time in the Prometheus expression browser
2. Add recording rules for expensive expressions
3. Reduce range window size: `[1h]` is 4x more data than `[15m]`
4. Limit aggregation cardinality: `sum by (job)` vs `sum by (job, instance, handler)`
5. Use `topk()` to limit output series
6. Enable `--query.max-samples` to prevent runaway queries (default 50M samples)
7. Check if query involves high-cardinality labels or regex matching on label values

## WAL Corruption Recovery

The WAL protects against data loss on crash. If WAL is corrupted:

```bash
# Check WAL for corruption
promtool tsdb analyze /var/lib/prometheus

# Prometheus auto-recovers on startup by truncating corrupt segment
# Check logs for: "WAL segment is corrupted" / "WAL segment recovered"
```

**Manual WAL repair:**
```bash
# Stop Prometheus first
systemctl stop prometheus

# Use promtool to repair WAL
promtool tsdb repack-wal /var/lib/prometheus/wal

# Or delete corrupted WAL segments (lose data in that segment only)
ls /var/lib/prometheus/wal/
rm /var/lib/prometheus/wal/000000XX

systemctl start prometheus
```

**Prevention:**
- Run on filesystems with journaling (ext4, XFS)
- Do not use NFS for TSDB storage (file locking issues)
- Use SSD for WAL (write-intensive)
- Set `--storage.tsdb.wal-compression=true` to reduce WAL I/O

## Alertmanager Diagnostics

```bash
# Check alert status
amtool alert query --alertmanager.url=http://alertmanager:9093

# List active silences
amtool silence query --alertmanager.url=http://alertmanager:9093

# Test routing configuration
amtool config routes test --config.file=/etc/alertmanager/alertmanager.yml \
  --verify.receivers=pagerduty \
  severity=critical job=api

# Check cluster status
curl http://alertmanager:9093/api/v2/status | jq .cluster
```

**Common Alertmanager issues:**
1. **Alerts not routing correctly:** Use `amtool config routes test` to trace routing decisions
2. **Duplicate notifications:** Ensure Prometheus `external_labels` are set for HA dedup
3. **Cluster split-brain:** Check mesh connectivity; all nodes should show `ready` in `/api/v2/status`
4. **Notification failures:** Check `alertmanager_notifications_failed_total` metric

```promql
# Failed notifications by integration
sum by (integration) (rate(alertmanager_notifications_failed_total[5m]))

# Alerts received by Alertmanager
rate(alertmanager_alerts_received_total[5m])

# Silenced alerts
alertmanager_alerts{state="suppressed"}
```

## Key Prometheus Internal Metrics

```promql
# Scrape samples ingested per second
rate(prometheus_tsdb_head_samples_appended_total[5m])

# Rule evaluation duration (average)
rate(prometheus_rule_evaluation_duration_seconds_sum[5m])
  / rate(prometheus_rule_evaluation_duration_seconds_count[5m])

# Remote write queue shards
prometheus_remote_storage_shards

# Remote write pending samples (lag indicator)
prometheus_remote_storage_pending_samples

# Remote write failures
rate(prometheus_remote_storage_failed_samples_total[5m])

# Configuration reload status
prometheus_config_last_reload_successful
prometheus_config_last_reload_success_timestamp_seconds

# HTTP API request duration (95th percentile)
histogram_quantile(0.95, rate(prometheus_http_request_duration_seconds_bucket[5m]))
```
