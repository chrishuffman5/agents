# Splunk Cost Reference

> License model, forwarder filtering, summary indexing, data model acceleration, SmartStore, and volume monitoring.

---

## License Model

Splunk Enterprise is licensed by **daily indexing volume** (GB indexed per calendar day, UTC).

- Volume measured at index time after parsing (compressed raw events)
- License pools can be subdivided across business units or environments
- **License warning** issued when daily volume exceeds licensed amount
- After 5 warnings in a 30-day rolling window, search disabled for non-internal indexes

### License Tiers

| Tier | Description |
|------|-------------|
| Enterprise | Standard per-GB/day, annual commitment |
| Infrastructure License | Flat-rate for infrastructure/metrics use cases |
| Ingest Pricing (Cloud) | Pay-per-GB ingest, no daily cap penalties |
| Workload Pricing (Cloud) | Based on compute (vCPUs) rather than ingest |
| Dev/Test | Reduced-cost for non-production instances |

---

## Cost Optimization Strategies

### 1. Filter at the Forwarder (Most Impactful)

Drop unwanted events before they reach the indexer. Data never counted against license.

```ini
# transforms.conf on Heavy Forwarder
[drop_debug_logs]
REGEX = level=DEBUG
DEST_KEY = queue
FORMAT = nullQueue
```

Apply via props.conf: `TRANSFORMS-drop = drop_debug_logs`

### 2. Reduce Verbosity at Source

- Set application log levels from DEBUG to INFO/WARN in production
- Disable access logging for internal health endpoints (`/health`, `/metrics`, `/ping`)

### 3. Prefer Search-Time Over Index-Time Extractions

Avoid `TRANSFORMS` that create many index-time fields -- these increase tsidx size but do not reduce raw volume. Use search-time extractions (`EXTRACT-` or `report-` stanzas in props.conf).

### 4. Summary Indexing

Pre-aggregate high-volume data into a summary index at scheduled intervals:

```spl
| sitimechart span=1h count as requests, avg(response_ms) as avg_latency by service
| collect index=summary_web source=hourly_agg
```

Dashboard reports query `index=summary_web` instead of raw logs. Dramatically faster and license-neutral (summary events are small).

### 5. Data Model Acceleration

Accelerate CIM-compliant data models for frequently queried data types (Network Traffic, Web, Authentication). Accelerated models use tsidx summary files enabling `tstats` -- 10-100x faster than raw searches. Counts against storage, not license.

### 6. SmartStore (Indexer Cluster)

Move warm/cold buckets to S3-compatible object storage. Hot bucket stays on SSD. Reduces local disk cost for long-retention data without eliminating searchability.

### 7. Tiered Index Retention

- Short retention for noisy sources: 7 days for debug logs
- Long retention for compliance: 1-7 years on cold/SmartStore
- Prevents costly disk expansion for low-value data

### 8. Data Volume Monitoring

Track license usage by index and sourcetype:

```spl
index=_internal sourcetype=splunkd source=*license_usage*
| stats sum(b) as bytes by idx, st
| eval GB = round(bytes / 1024 / 1024 / 1024, 3)
| sort -GB
| rename idx as index, st as sourcetype
```

Run weekly to identify growth trends and target optimization efforts.

---

## License Usage Monitoring

### Daily License Dashboard Query

```spl
index=_internal source=*license_usage.log type=Usage
| timechart span=1d sum(b) as bytes
| eval GB = round(bytes / 1024 / 1024 / 1024, 2)
| eval license_cap_GB = <your_license_GB>
| eval pct_used = round(GB / license_cap_GB * 100, 1)
```

### Top Consumers by Sourcetype

```spl
index=_internal source=*license_usage.log type=Usage
| stats sum(b) as bytes by st
| eval GB = round(bytes / 1024 / 1024 / 1024, 3)
| sort -GB | head 20
| rename st as sourcetype
```

### Alert at 80% License Capacity

Create a saved search alert:
```spl
index=_internal source=*license_usage.log type=Usage earliest=-1d@d latest=@d
| stats sum(b) as bytes
| eval GB = round(bytes / 1024 / 1024 / 1024, 2)
| where GB > (<license_GB> * 0.8)
```

Schedule daily. Alert action: email to capacity-planning team.
