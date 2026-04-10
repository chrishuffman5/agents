# PromQL Reference

## Data Types

PromQL operates on four data types:

| Type | Description | Example |
|------|-------------|---------|
| **Instant vector** | Set of time series, each with a single sample at query time | `http_requests_total` |
| **Range vector** | Set of time series, each with a range of samples | `http_requests_total[5m]` |
| **Scalar** | A single floating-point number | `1.5`, `scalar(...)` |
| **String** | A string value (limited use) | `"hello"` |

Most functions and operators return instant vectors. Range vectors are inputs to functions like `rate()`.

## Selectors and Matchers

**Metric name selector:**
```promql
http_requests_total
```

**Label matchers:**
```promql
http_requests_total{job="api", status=~"5.."}
http_requests_total{job!="batch", method="GET"}
http_requests_total{handler!~"/health|/ready"}
```

Matcher operators:
- `=` exact match
- `!=` not equal
- `=~` regex match (anchored, RE2 syntax)
- `!~` regex not match

**Range selector:**
```promql
http_requests_total{job="api"}[5m]
```

**Offset modifier:**
```promql
http_requests_total offset 1h          # value from 1 hour ago
rate(http_requests_total[5m] offset 1h)
```

**@ modifier (query at specific timestamp):**
```promql
http_requests_total @ 1609459200       # Unix timestamp
http_requests_total @ start()          # query range start
http_requests_total @ end()            # query range end
```

## Rate Functions

**`rate(v range-vector)`** -- Per-second average rate of increase over the range. Handles counter resets. Use with counters. Prefer `rate` over `irate` for alerting (smoother).

```promql
rate(http_requests_total{job="api"}[5m])
```

**`irate(v range-vector)`** -- Instantaneous rate using last two samples. Reacts faster to spikes. Use for dashboards showing momentary traffic. Requires at least 2 samples in range.

```promql
irate(http_requests_total{job="api"}[5m])
```

**`increase(v range-vector)`** -- Total increase in counter over the time range. Equivalent to `rate(v[d]) * d` for duration `d`.

```promql
increase(http_requests_total{job="api"}[1h])
```

## Histogram Functions

**`histogram_quantile(phi, v)`** -- Calculates the phi-quantile (0 <= phi <= 1) from classic histogram buckets. Requires grouping by `le` label.

```promql
# 95th percentile latency by job
histogram_quantile(0.95,
  sum by (job, le) (
    rate(http_request_duration_seconds_bucket[5m])
  )
)
```

In Prometheus 3.x, `histogram_quantile` also works directly on native histograms:
```promql
histogram_quantile(0.99, rate(http_request_duration_seconds[5m]))
```

**`histogram_avg(v)`** (3.x) -- Average of observations in a native histogram.

**`histogram_count(v)`** / **`histogram_sum(v)`** -- Extract count/sum from native histograms.

## Aggregation Operators

Applied to instant vectors, with optional `by()` or `without()` clauses:

```promql
sum by (job, method) (http_requests_total)
avg without (instance) (node_cpu_seconds_total)
max by (job) (up)
min by (datacenter) (node_memory_MemAvailable_bytes)
count by (job) (up)
count_values("version", build_info)    # counts per unique value
```

**`topk(k, v)`** and **`bottomk(k, v)`** -- Return the top/bottom k time series by value:
```promql
topk(5, sum by (handler) (rate(http_requests_total[5m])))
bottomk(3, node_filesystem_avail_bytes / node_filesystem_size_bytes)
```

**`stddev by (...)`** and **`stdvar by (...)`** -- Standard deviation and variance aggregations.

**`group by (...)`** -- Returns a single series per group with value 1. Useful for joins.

## Binary Operators and Vector Matching

**Arithmetic:** `+`, `-`, `*`, `/`, `%`, `^`

**Comparison:** `==`, `!=`, `>`, `<`, `>=`, `<=`

**Logical:** `and`, `or`, `unless`

**One-to-one matching:**
```promql
# CPU usage ratio using two metrics with same labels
node_cpu_seconds_total{mode="user"} / ignoring(mode) node_cpu_seconds_total
```

**Many-to-one / one-to-many:**
```promql
# Multiply request rate by cost-per-request, joined on service label
rate(http_requests_total[5m]) * on(service) group_left(tier)
  service_cost_per_request
```

**`bool` modifier** -- Returns 0/1 instead of filtering:
```promql
http_requests_total > bool 1000
```

## Label Manipulation Functions

**`label_replace(v, dst_label, replacement, src_label, regex)`** -- Creates or replaces a label using regex capture groups:

```promql
# Extract service name from instance "api-server-01:8080"
label_replace(up, "service", "$1", "instance", "([a-z-]+)-\\d+:\\d+")
```

**`label_join(v, dst_label, separator, src_1, src_2, ...)`** -- Joins multiple label values into one:

```promql
label_join(up, "host_port", ":", "host", "port")
```

## Utility Functions

**`absent(v)`** -- Returns 1 if the metric is missing. Used in alerting for "metric missing" conditions:
```promql
absent(up{job="api"})
```

**`absent_over_time(v[d])`** -- Returns 1 if no data exists in the window:
```promql
absent_over_time(up{job="api"}[10m])
```

**`changes(v[d])`** -- Number of times a gauge changed value in the range.

**`predict_linear(v[d], t)`** -- Linear regression prediction: predicts the value t seconds from now:
```promql
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[1h], 4 * 3600) < 0
```

**`resets(v[d])`** -- Number of counter resets in the range.

**`delta(v[d])`** -- Difference between first and last value. For gauges only.

**`deriv(v[d])`** -- Per-second derivative using least-squares regression.

**`clamp(v, min, max)`** -- Clamps values to [min, max].

**Math functions:** `abs()`, `ceil()`, `floor()`, `round()`, `exp()`, `ln()`, `log2()`, `log10()`, `sqrt()`, `sgn()`.

**Time functions:** `day_of_week()`, `day_of_month()`, `hour()`, `minute()`, `month()`, `year()`. Useful for date-based alerting.

## Over-Time Functions for Range Vectors

```promql
avg_over_time(metric[5m])        # average over the range
min_over_time(metric[5m])        # minimum over the range
max_over_time(metric[5m])        # maximum over the range
sum_over_time(metric[5m])        # sum over the range
count_over_time(metric[5m])      # count of samples in range
quantile_over_time(0.95, metric[5m])  # quantile over range
last_over_time(metric[5m])       # most recent sample
```

## Real-World Examples

**1. HTTP error rate percentage:**
```promql
100 * sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)
  /
sum(rate(http_requests_total[5m])) by (job)
```

**2. 99th percentile latency (classic histogram):**
```promql
histogram_quantile(0.99,
  sum by (le, service) (
    rate(http_request_duration_seconds_bucket[5m])
  )
)
```

**3. CPU utilization per node:**
```promql
1 - avg by (instance) (
  rate(node_cpu_seconds_total{mode="idle"}[5m])
)
```

**4. Memory usage percentage:**
```promql
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))
```

**5. Disk fill prediction (alert if filling in 4 hours):**
```promql
predict_linear(node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}[6h], 4 * 3600) < 0
```

**6. Pod restarts in the last hour:**
```promql
increase(kube_pod_container_status_restarts_total[1h]) > 5
```

**7. Top 5 endpoints by request rate:**
```promql
topk(5, sum by (handler) (rate(http_requests_total[5m])))
```

**8. Apdex score (satisfied < 0.3s, tolerated < 1.2s):**
```promql
(
  sum(rate(http_request_duration_seconds_bucket{le="0.3"}[5m])) by (job)
  +
  sum(rate(http_request_duration_seconds_bucket{le="1.2"}[5m])) by (job)
) / 2
/
sum(rate(http_request_duration_seconds_count[5m])) by (job)
```

**9. Alert: metric completely absent:**
```promql
absent(up{job="critical-service"}) == 1
```

**10. Instance down for 5+ minutes:**
```promql
up == 0
```

**11. Network receive bandwidth (bits/sec):**
```promql
rate(node_network_receive_bytes_total{device!~"lo|veth.*"}[5m]) * 8
```

**12. JVM GC pause rate (average pause duration):**
```promql
rate(jvm_gc_pause_seconds_sum[5m]) / rate(jvm_gc_pause_seconds_count[5m])
```

**13. Request success rate with label join:**
```promql
label_join(
  sum by (service, version) (rate(http_requests_total{status!~"5.."}[5m]))
    /
  sum by (service, version) (rate(http_requests_total[5m])),
  "service_version", "-", "service", "version"
)
```

**14. Slow exporters (scrape duration by job):**
```promql
topk(10, avg by (job) (scrape_duration_seconds))
```

**15. Kubernetes node CPU requests vs allocatable:**
```promql
sum by (node) (kube_pod_container_resource_requests{resource="cpu", unit="core"})
/
sum by (node) (kube_node_status_allocatable{resource="cpu", unit="core"})
```

**16. Rolling 24-hour availability:**
```promql
avg_over_time(up{job="api"}[24h])
```

**17. Rate of change in active TCP connections (gauge derivative):**
```promql
deriv(node_sockstat_TCP_inuse[10m])
```

## Recording Rules

Pre-compute expensive expressions and store results as new metrics. Run on the rule evaluation interval (default 1m).

```yaml
groups:
  - name: api_aggregations
    interval: 30s
    rules:
      - record: job:http_requests_total:rate5m
        expr: sum by (job) (rate(http_requests_total[5m]))

      - record: job_method:http_requests_total:rate5m
        expr: sum by (job, method) (rate(http_requests_total[5m]))

      - record: job:http_request_duration_seconds:p99
        expr: |
          histogram_quantile(0.99,
            sum by (job, le) (rate(http_request_duration_seconds_bucket[5m]))
          )
```

**Naming convention:** `level:metric:operations`
- `level`: aggregation level (e.g., `job`, `cluster`, `instance`)
- `metric`: base metric name
- `operations`: transformations applied (e.g., `rate5m`, `p99`, `ratio`)
