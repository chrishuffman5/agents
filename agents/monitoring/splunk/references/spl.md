# SPL Reference

> Search Processing Language -- commands, subsearch, macros, and 15+ real-world examples.

---

## SPL Overview

SPL is a pipeline-based query language where commands are chained with `|`. Processing flows left to right: each command receives the output of the previous command.

```spl
index=main sourcetype=access_combined | stats count by status
```

Command categories:
- **Streaming:** Applied per event (where, eval, rex, fields, rename)
- **Transforming:** Aggregate into results (stats, chart, timechart, top, rare)
- **Generating:** Produce new events (inputlookup, tstats, makeresults)
- **Orchestrating:** Control pipeline flow (append, join, subsearch)

---

## Core Commands

### search

Filters events matching a boolean expression. Implicit at query start.
```spl
index=web_logs status=500 host=prod-* NOT uri="/health"
```

### where

Filters using eval expressions after initial retrieval.
```spl
index=app_logs | where response_time > 2000 AND status != 200
```

### eval

Creates or modifies fields using expressions and conditionals.
```spl
index=access | eval latency_sec = response_ms / 1000
             | eval tier = if(latency_sec > 5, "slow", "fast")
```

### stats

Aggregates events into a statistical table. Most common transforming command.
```spl
index=web status=200 | stats count, avg(response_time), max(response_time) by host, uri
```

### chart

Like stats but shaped for charting (one column per field value).
```spl
index=access | chart count over _time by status
```

### timechart

Aggregates over time intervals; always uses `_time` as X-axis.
```spl
index=access | timechart span=5m avg(response_time) by host limit=10
```

### table

Selects and orders fields for tabular display.
```spl
index=network | table _time, src_ip, dest_ip, bytes_in, bytes_out, action
```

### fields

Includes or excludes fields. `fields +` includes, `fields -` excludes.
```spl
index=logs | fields - _raw, punct, linecount
```

### rename

Renames fields for readability.
```spl
index=db | stats avg(query_duration) as "Avg Duration (ms)" by db_name
         | rename db_name as "Database"
```

### sort

Sorts results. `-` prefix for descending.
```spl
index=app | stats count by error_code | sort -count limit=20
```

### dedup

Removes duplicates based on field values.
```spl
index=auth | dedup user sortby -_time | table _time, user, action
```

### top / rare

Most (top) or least (rare) frequent values.
```spl
index=web | top limit=10 uri by host
index=app | rare limit=5 error_type
```

### transaction

Groups events into transactions by fields, time span, or pause.
```spl
index=web | transaction session_id maxspan=30m maxpause=5m
          | eval duration_min = duration / 60
          | stats avg(duration_min) by clientip
```

### join

SQL-style join between result sets (use sparingly -- expensive).
```spl
index=orders | join order_id [search index=fulfillment | fields order_id, status]
```

### lookup

Enriches events from a lookup table (CSV, KV Store, external).
```spl
index=network | lookup ip_geo_lookup src_ip OUTPUT country, city
              | stats count by country
```

### rex

Extracts fields using regex named capture groups.
```spl
index=app_logs | rex field=message "user=(?P<username>\w+) action=(?P<action>\w+)"
               | stats count by username, action
```

### spath

Extracts fields from JSON or XML.
```spl
index=api_logs | spath input=_raw path=response.errors{} output=errors
               | where isnotnull(errors)
```

### streamstats

Running statistics (cumulative, window-based). Streaming, preserves event order.
```spl
index=sales | sort _time | streamstats sum(revenue) as running_revenue by region
```

### eventstats

Adds aggregate values back to each event (does not reduce row count).
```spl
index=app | eventstats avg(response_time) as avg_rt
          | where response_time > avg_rt * 2
```

---

## Subsearch

Search nested in brackets, executed first. Results passed to outer search as OR expression.
```spl
index=auth action=failed
  [search index=auth action=failed | stats count by src_ip | where count > 50 | fields src_ip]
| stats count by user, src_ip
```

Default limits: 10,000 results, 60-second timeout (configurable in limits.conf).

---

## Macros

Reusable SPL snippets. Defined in Settings > Advanced Search > Search Macros.

```spl
`web_errors(500)`
# Expands to: index=web_logs status=500 sourcetype=access_combined
```

With arguments:
```
Name: web_errors(1)
Definition: index=web_logs status=$status$ sourcetype=access_combined
```

---

## Real-World SPL Examples

### 1. Top 10 Slowest API Endpoints (P95)

```spl
index=api_logs sourcetype=api_access
| stats perc95(response_ms) as p95, count by endpoint
| sort -p95 | head 10
```

### 2. Error Rate by Service Over Time

```spl
index=app_logs
| eval is_error = if(level="ERROR", 1, 0)
| timechart span=1h sum(is_error) as errors, count as total by service
| eval error_rate = round(errors / total * 100, 2)
```

### 3. User Session Duration

```spl
index=auth (action=login OR action=logout)
| transaction user maxspan=8h startswith="action=login" endswith="action=logout"
| eval duration_min = round(duration / 60, 1)
| stats avg(duration_min), max(duration_min) by user
```

### 4. Kubernetes Pod Restarts

```spl
index=k8s sourcetype=kube:events reason=BackOff
| rex field=message "pod (?P<pod_name>[\w-]+)"
| stats count as restarts by pod_name, namespace
| where restarts > 5
| sort -restarts
```

### 5. Network Traffic Anomaly Detection

```spl
index=network sourcetype=firewall
| timechart span=1h sum(bytes) as hourly_bytes by src_ip
| eventstats avg(hourly_bytes) as avg_bytes, stdev(hourly_bytes) as stdev_bytes
| where hourly_bytes > avg_bytes + (3 * stdev_bytes)
```

### 6. Log Correlation Across Indexes

```spl
index=app_logs error_id=*
| join error_id [search index=infra_logs | fields error_id, host, cpu_util]
| table _time, error_id, app_service, host, cpu_util
```

### 7. JSON API Log Parsing

```spl
index=api_gateway sourcetype=json_logs
| spath path=request.method output=method
| spath path=response.statusCode output=status
| spath path=response.latencyMs output=latency
| stats avg(latency) as avg_latency by method, status
```

### 8. Regex Extraction from Syslog

```spl
index=syslog sourcetype=linux_syslog
| rex field=_raw "kernel: \[(?P<uptime>\d+\.\d+)\] (?P<subsystem>\w+): (?P<msg>.+)"
| stats count by subsystem | sort -count
```

### 9. Lookup Enrichment for Asset Inventory

```spl
index=windows sourcetype=WinEventLog:Security EventCode=4625
| lookup asset_inventory ComputerName OUTPUT owner, department, location
| stats count as failed_logins by ComputerName, owner, department
| where failed_logins > 10
```

### 10. Running Cumulative Cost

```spl
index=cloud_billing sourcetype=aws_cost
| sort _time
| streamstats sum(cost_usd) as cumulative_cost
| timechart span=1d max(cumulative_cost) as daily_cumulative
```

### 11. Detecting Data Gaps

```spl
| tstats count WHERE index=* by index, host, _time span=5m
| streamstats current=f window=1 last(count) as prev_count by index, host
| where isnull(prev_count) OR prev_count = 0
```

### 12. Availability SLA Calculation

```spl
index=synthetics test_name="Homepage Check"
| eval success = if(status="pass", 1, 0)
| timechart span=1d avg(success) as availability
| eval availability_pct = round(availability * 100, 3)
```

### 13. Multi-Value Field Expansion

```spl
index=config_changes
| mvexpand changed_fields
| stats count by changed_fields, host | sort -count
```

### 14. First-Time-Seen Events

```spl
index=auth action=login
| stats earliest(_time) as first_seen by user, src_ip
| eval first_seen_date = strftime(first_seen, "%Y-%m-%d")
| where first_seen_date = strftime(now(), "%Y-%m-%d")
```

### 15. License Usage by Index and Sourcetype

```spl
index=_internal sourcetype=splunkd source=*license_usage*
| stats sum(b) as bytes by idx, st
| eval GB = round(bytes / 1024 / 1024 / 1024, 3)
| sort -GB
| rename idx as index, st as sourcetype
```
