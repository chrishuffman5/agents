# Monitoring & Observability Concepts

## Three Pillars of Observability

Observability is the ability to infer the internal state of a system from its external outputs. Three complementary signal types provide this capability:

### Metrics

Numeric measurements aggregated over time intervals. Metrics are the most compact telemetry type and form the backbone of monitoring.

**Characteristics:**
- Fixed schema (metric name + labels + value + timestamp)
- Cheap to store and query (time-series databases optimized for this)
- Ideal for aggregation, trending, and alerting
- Cannot tell you *why* something happened -- only *that* something happened

**Metric types:**
- **Counter** -- Monotonically increasing value (total requests, total errors). Use `rate()` to compute per-second change.
- **Gauge** -- Point-in-time measurement that goes up or down (CPU usage, memory available, queue depth).
- **Histogram** -- Distribution of values in configurable buckets (request latency). Enables percentile computation.
- **Summary** -- Client-side computed quantiles. Cannot be aggregated across instances. Prefer histograms.

### Logs

Timestamped records of discrete events. Logs provide the richest context for debugging but are the most expensive signal at scale.

**Characteristics:**
- Semi-structured or unstructured text
- High volume (often 10-100x more data than metrics)
- Essential for root cause analysis and audit trails
- Expensive to index, store, and query at scale

**Log levels:** DEBUG < INFO < WARN < ERROR < FATAL. Production systems should log at INFO minimum. Excessive DEBUG logging in production is a common cost driver.

**Structured logging:** Always prefer structured (JSON) over unstructured logs. Structured logs enable field-based indexing and filtering without regex parsing at query time.

### Traces

Distributed traces capture the end-to-end journey of a request across service boundaries. Each trace is a tree of spans.

**Characteristics:**
- Each span has: trace ID, span ID, parent span ID, timestamps, attributes, status
- Spans form a directed acyclic graph showing causality
- Essential for understanding latency breakdown in microservices
- Sampling is required at scale (storing 100% of traces is cost-prohibitive)

**Key concepts:**
- **Trace context propagation** -- Passing trace/span IDs across service boundaries via HTTP headers (W3C `traceparent`)
- **Span attributes** -- Key-value metadata on each span (HTTP method, status code, database query)
- **Span events** -- Point-in-time events within a span (exception thrown, cache miss)

## SLI / SLO / SLA

### Service Level Indicator (SLI)

A quantitative measure of service behavior. SLIs are the metrics you track.

**Common SLIs:**
- **Availability** -- Proportion of successful requests: `successful_requests / total_requests`
- **Latency** -- Proportion of requests faster than a threshold: `requests_under_300ms / total_requests`
- **Throughput** -- Requests per second the system handles
- **Correctness** -- Proportion of requests returning correct results

**SLI specification pattern:** "The proportion of [valid events] that [meet a quality threshold]."

Example: "The proportion of HTTP requests that return a non-5xx response within 300ms."

### Service Level Objective (SLO)

A target value or range for an SLI over a time window.

**Format:** `SLI >= target% over window`

**Examples:**
- 99.9% of requests succeed over a rolling 30-day window
- 99th percentile latency < 500ms over a rolling 7-day window
- 99.95% availability measured monthly

**Choosing targets:**
- Start with what users actually experience today, then set targets slightly above
- 99.9% is not 99.99% -- the difference is 8.7 hours vs 52 minutes of downtime per year
- Higher targets cost exponentially more to achieve
- Different services deserve different SLOs (payment processing vs marketing page)

| SLO | Allowed Downtime/Month | Allowed Downtime/Year |
|-----|----------------------|---------------------|
| 99% | 7.3 hours | 3.65 days |
| 99.9% | 43.8 minutes | 8.76 hours |
| 99.95% | 21.9 minutes | 4.38 hours |
| 99.99% | 4.38 minutes | 52.6 minutes |
| 99.999% | 26.3 seconds | 5.26 minutes |

### Service Level Agreement (SLA)

A contractual commitment with consequences for missing targets. SLAs are business agreements, not engineering metrics.

**Key difference:** An SLO is an internal engineering target. An SLA is an external contractual obligation with financial penalties. Always set SLOs tighter than SLAs to provide a buffer.

**Example:** SLA guarantees 99.9% uptime. Internal SLO targets 99.95% to ensure the SLA is met.

## Error Budgets

An error budget is the inverse of an SLO: how much failure is allowed.

**Formula:** `Error budget = 1 - SLO target`

**Example:** 99.9% SLO = 0.1% error budget = 43.8 minutes of downtime per month.

**How to use error budgets:**
- **Budget remaining** -- Ship features, take risks, deploy more frequently
- **Budget exhausted** -- Freeze feature releases, focus on reliability improvements
- **Budget burn rate** -- Track how fast the budget is being consumed

**Burn rate alerting:** Alert when the error budget is being consumed faster than sustainable.

| Burn Rate | Meaning | Action |
|-----------|---------|--------|
| 1x | Budget consumed evenly over the window | Normal |
| 2x | Budget will exhaust in half the window | Investigate |
| 14x | Budget will exhaust in 1/14 of the window (~2 days for 30d window) | Page immediately |

**Multi-window burn rate alerts** (recommended by Google SRE):
- Fast burn: 14x rate over 1 hour AND 14x rate over 5 minutes -- page
- Slow burn: 2x rate over 6 hours AND 2x rate over 30 minutes -- ticket

## Cardinality

Cardinality is the number of unique time series produced by a metric. It is the primary cost driver for metrics systems.

**Formula:** `cardinality = unique_combinations(label_1_values x label_2_values x ...)`

**Example:** A metric with labels `method` (5 values), `status` (10 values), `endpoint` (50 values) produces 5 x 10 x 50 = 2,500 time series.

**Cardinality explosion happens when:**
- Labels contain unbounded values (user IDs, request IDs, email addresses, full URLs)
- Combinatorial label growth (adding one label with 100 values multiplies total series by 100)
- Auto-discovered targets with many unique label combinations

**Guidelines:**
- Keep label values to a known, bounded set
- Target < 10,000 series per metric name
- Monitor total active series (Prometheus: `prometheus_tsdb_head_series`)
- Use relabeling to drop high-cardinality labels before ingestion
- Use recording rules to pre-aggregate and reduce query-time cardinality

**Memory impact:** Each active time series consumes approximately 3-6 KB in Prometheus. 1 million series = 3-6 GB RAM.

## Sampling

Sampling is the practice of recording only a fraction of telemetry data to control cost and volume.

### Trace Sampling Strategies

| Strategy | Where | Pros | Cons |
|----------|-------|------|------|
| **Head sampling** | SDK (at span creation) | Low overhead, simple | Misses late-arriving errors |
| **Tail sampling** | Collector (after trace completes) | Captures errors and slow traces | Requires stateful Collector, higher resource use |
| **Probabilistic** | SDK or Collector | Predictable cost | Misses rare events |
| **Rate limiting** | Collector | Hard cap on volume | Random selection |
| **Priority-based** | Collector | Always captures errors/slow | Complex configuration |

**Production recommendation:** Use head sampling (10-25%) in SDKs combined with tail sampling in the Collector that always captures errors and slow requests.

### Log Sampling

- **Level-based:** Only ship WARN+ to centralized logging; keep DEBUG locally
- **Rate-limited:** Sample verbose log sources (access logs) at 10-25%
- **Dynamic:** Increase sampling when error rate spikes (adaptive sampling)

### Metric Downsampling

- Store high-resolution (15s) data for recent period (7 days)
- Downsample to 1-minute resolution for 30 days
- Downsample to 5-minute resolution for 1 year
- Tools: Thanos Compactor, Mimir compactor, Elasticsearch ILM downsampling

## USE Method (Brendan Gregg)

For every **resource** (CPU, memory, disk, network interface, GPU), check three things:

| Signal | Definition | How to Measure |
|--------|-----------|---------------|
| **Utilization** | Percentage of resource capacity in use | CPU %, memory %, disk %, network bandwidth % |
| **Saturation** | Amount of work waiting (queued) | CPU run queue, memory swap, disk I/O queue, network backlog |
| **Errors** | Count of error events | Disk I/O errors, network packet errors, ECC memory errors |

Apply systematically: make a table with every resource as a row and U/S/E as columns. Fill in each cell.

## RED Method (Tom Wilkie)

For every **service** (user-facing or internal), measure three things:

| Signal | Definition | Typical Metric |
|--------|-----------|---------------|
| **Rate** | Requests per second | `sum(rate(http_requests_total[5m]))` |
| **Errors** | Failed requests per second or error ratio | `sum(rate(http_requests_total{status=~"5.."}[5m]))` |
| **Duration** | Latency distribution | `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))` |

**Dashboard layout:** One row per service. Rate and Error panels on the left, Duration (latency percentiles) on the right.

## 4 Golden Signals (Google SRE)

A superset of RED plus saturation:

1. **Latency** -- Time to serve a request. Track success latency and error latency separately (errors are often fast, skewing averages).
2. **Traffic** -- Demand on the system. Requests/sec for web services, QPS for databases, messages/sec for queues.
3. **Errors** -- Rate of failed requests. Include explicit errors (5xx), implicit errors (200 with wrong content), and policy violations (responses exceeding SLO latency threshold).
4. **Saturation** -- How close to capacity. CPU, memory, connection pool, queue depth. Measure the resource most likely to be exhausted first.

## Alert Design Principles

### Symptom-Based Alerting

Alert on what the user experiences, not on internal system state.

**Good alerts (symptoms):**
- Error rate > 5% for 5 minutes
- p99 latency > 2 seconds for 10 minutes
- Availability dropped below SLO threshold
- Error budget burn rate > 14x for 1 hour

**Poor alerts (causes):**
- CPU > 90% (might be expected under load)
- Memory > 80% (JVM heap is designed to fill)
- Thread count > 500 (normal for async systems)

Cause-based alerts are appropriate for infrastructure protection (disk full, OOM) but should not page on-call engineers unless they indicate user impact.

### Alert Fatigue Prevention

1. **Set meaningful `for` durations** -- Minimum 1m for critical, 5m for warning. Never alert on instantaneous spikes.
2. **Group related alerts** -- Batch alerts by service/cluster/alertname. One notification per group, not per instance.
3. **Use inhibition** -- Suppress downstream alerts when the root cause is already alerting (cluster down suppresses node alerts).
4. **Tune repeat intervals** -- Resend firing alerts every 4-12 hours, not every 30 minutes.
5. **Require runbook URLs** -- Every alert annotation must include a runbook link.
6. **Review alerts quarterly** -- Delete alerts that never fire or always fire. Both indicate poor tuning.
7. **Dead man's switch** -- Send a constant "watchdog" alert. If it stops arriving, the alerting pipeline is broken.
8. **Severity calibration** -- Only `critical` alerts should page. Everything else goes to Slack or a ticket queue.
