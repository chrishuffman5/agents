# NRQL Reference

> New Relic Query Language -- syntax, functions, clauses, subqueries, and real-world examples.

---

## Core Syntax

```sql
SELECT <function(attribute) | attribute | *>
FROM <EventType | Metric | Log | Span>
[WHERE <condition>]
[FACET <attribute> [, <attribute2>]]
[TIMESERIES [<interval>]]
[SINCE <time> [UNTIL <time>]]
[COMPARE WITH <time offset>]
[LIMIT <n> | MAX]
[EXTRAPOLATE]
[SLIDE BY <interval>]
```

---

## Aggregate Functions

| Function | Description | Example |
|----------|-------------|---------|
| `count(*)` | Count all matching records | `SELECT count(*) FROM Transaction` |
| `average(attr)` | Mean of attribute | `SELECT average(duration) FROM Transaction` |
| `max(attr)` / `min(attr)` | Maximum / minimum | `SELECT max(duration) FROM Transaction` |
| `sum(attr)` | Sum of values | `SELECT sum(diskBytes) FROM StorageSample` |
| `percentile(attr, n)` | Nth percentile | `SELECT percentile(duration, 95, 99) FROM Transaction` |
| `rate(count(*), 1 minute)` | Events per time unit | `SELECT rate(count(*), 1 minute) FROM Transaction` |
| `uniqueCount(attr)` | Distinct value count | `SELECT uniqueCount(session) FROM PageView` |
| `latest(attr)` | Most recent value | `SELECT latest(cpuPercent) FROM SystemSample` |
| `stddev(attr)` | Standard deviation | `SELECT stddev(duration) FROM Transaction` |
| `histogram(attr, width, buckets)` | Frequency distribution | `SELECT histogram(duration, 10, 20) FROM Transaction` |
| `funnel(attr, ...)` | Conversion funnel | See example 9 below |
| `filter(func, WHERE ...)` | Scoped aggregation | `SELECT filter(count(*), WHERE error IS true)` |
| `apdex(attr, t)` | Apdex score | `SELECT apdex(duration, 0.5) FROM Transaction` |
| `percentage(count(*), WHERE ...)` | Percentage matching condition | `SELECT percentage(count(*), WHERE error IS true)` |

---

## Clauses

### WHERE -- Filter

Standard comparisons, `IN`, `LIKE`, `IS NULL`, boolean operators:

```sql
WHERE appName = 'checkout-service' AND httpResponseCode >= 400
WHERE error.class IN ('TimeoutException', 'NullPointerException')
WHERE request.uri LIKE '/api/v2/%'
```

### FACET -- Group By

Group results. Up to 5 facet attributes:

```sql
FACET appName
FACET httpResponseCode, request.method
FACET cases(WHERE duration < 0.5 AS 'fast', WHERE duration >= 0.5 AS 'slow')
```

### TIMESERIES -- Time Bucketing

```sql
TIMESERIES 5 minutes
TIMESERIES AUTO   -- New Relic chooses interval based on SINCE range
```

### SINCE / UNTIL -- Time Range

```sql
SINCE 1 hour ago
SINCE 7 days ago UNTIL 1 day ago
SINCE '2025-03-01 00:00:00'
```

### COMPARE WITH -- Period-Over-Period

```sql
SELECT count(*) FROM Transaction SINCE 1 week ago COMPARE WITH 1 week ago
```

### LIMIT -- Result Cap

Default 10 for FACET queries. Maximum 2000 with `LIMIT MAX`:

```sql
LIMIT 50
LIMIT MAX
```

---

## Subqueries

Nested subqueries for correlated filtering:

```sql
SELECT count(*) FROM Transaction
WHERE appName IN (
  SELECT uniques(appName) FROM Transaction
  WHERE error IS true AND appName LIKE 'payment%'
)
SINCE 1 hour ago
```

---

## Lookup Tables

Upload CSV reference data; join with NRQL:

```sql
SELECT count(*), lookup(ServiceOwner.team, 'service_name', appName)
FROM Transaction FACET appName
```

---

## Real-World NRQL Examples

### 1. Error Rate by Service

```sql
SELECT percentage(count(*), WHERE error IS true) AS 'Error Rate %'
FROM Transaction
FACET appName
SINCE 1 hour ago
ORDER BY 'Error Rate %' DESC
LIMIT 20
```

### 2. P95/P99 Latency Time Series

```sql
SELECT percentile(duration, 95, 99) AS 'Latency'
FROM Transaction
WHERE appName = 'api-gateway'
TIMESERIES 5 minutes
SINCE 3 hours ago
```

### 3. Infrastructure CPU Heatmap

```sql
SELECT average(cpuPercent)
FROM SystemSample
FACET hostname
TIMESERIES 10 minutes
SINCE 6 hours ago
LIMIT MAX
```

### 4. Top Slow Database Queries

```sql
SELECT count(*), average(duration), max(duration)
FROM DatastoreSegment
WHERE appName = 'order-service'
FACET db.statement
SINCE 24 hours ago
ORDER BY average(duration) DESC
LIMIT 20
```

### 5. Throughput (Requests Per Minute)

```sql
SELECT rate(count(*), 1 minute) AS 'RPM'
FROM Transaction
WHERE transactionType = 'Web'
FACET appName
TIMESERIES AUTO
SINCE 1 day ago
```

### 6. Log Error Count by Level

```sql
SELECT count(*)
FROM Log
WHERE level IN ('ERROR', 'CRITICAL', 'FATAL')
FACET level, service.name
SINCE 30 minutes ago
TIMESERIES 2 minutes
```

### 7. Browser Core Web Vitals

```sql
SELECT average(largestContentfulPaint) AS 'LCP (ms)',
       average(firstInputDelay) AS 'FID (ms)',
       average(cumulativeLayoutShift) AS 'CLS'
FROM PageViewTiming
WHERE appName = 'marketing-site'
FACET pageUrl
SINCE 1 day ago
LIMIT 20
```

### 8. Synthetic Monitor Success Rate

```sql
SELECT percentage(count(*), WHERE result = 'SUCCESS') AS 'Uptime %'
FROM SyntheticCheck
FACET monitorName
SINCE 7 days ago
COMPARE WITH 7 days ago
```

### 9. Funnel Analysis (Checkout Conversion)

```sql
SELECT funnel(session,
  WHERE pageUrl LIKE '%/cart%' AS 'Cart',
  WHERE pageUrl LIKE '%/checkout%' AS 'Checkout',
  WHERE pageUrl LIKE '%/confirmation%' AS 'Order Confirmed'
)
FROM PageView
SINCE 1 day ago
```

### 10. Apdex by Transaction Name

```sql
SELECT apdex(duration, 0.5) AS 'Apdex'
FROM Transaction
WHERE transactionType = 'Web'
FACET name
SINCE 1 hour ago
ORDER BY apdex(duration, 0.5) ASC
LIMIT 10
```

### 11. Data Ingest by Source (Cost Visibility)

```sql
SELECT sum(GigabytesIngested) AS 'GB Ingested'
FROM NrConsumption
WHERE productLine = 'DataPlatform'
FACET usageMetric
SINCE 30 days ago
```

### 12. Custom Event Query

```sql
SELECT count(*), uniqueCount(userId)
FROM FeatureFlagExposure
WHERE flagName = 'new-checkout-flow'
FACET variant
SINCE 7 days ago
```
