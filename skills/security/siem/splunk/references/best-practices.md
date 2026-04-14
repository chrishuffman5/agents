# Splunk Best Practices Reference

## SPL Optimization

### Query Performance Hierarchy

From fastest to slowest:

1. **`tstats` on accelerated data models** -- Searches pre-built tsidx summaries. Sub-second for most queries.
2. **`tstats` on non-accelerated data models** -- Still fast because it reads tsidx, not raw data.
3. **`stats` with indexed fields only** -- Leverages bloom filters and tsidx for filtering.
4. **`stats` with search-time fields** -- Must read raw data to extract fields, then aggregate.
5. **`transaction`** -- Single-threaded, memory-intensive. Avoid for large datasets.
6. **`join`** -- Memory-limited (default 50,000 rows on right side). Use `stats` or `lookup` instead.

### SPL Optimization Patterns

**Pattern 1: Replace `join` with `stats`**
```spl
# Bad: join is memory-limited and slow
index=auth action=login | join user [search index=auth action=logout]

# Good: stats with multiple conditions
index=auth (action=login OR action=logout)
| stats earliest(eval(if(action="login",_time,null()))) as login_time,
        latest(eval(if(action="logout",_time,null()))) as logout_time
    by user
| eval session_duration=logout_time-login_time
```

**Pattern 2: Use `tstats` instead of raw search**
```spl
# Slow: raw search
index=firewall action=blocked | stats count by src_ip | sort -count | head 20

# Fast: tstats on CIM-mapped data model
| tstats count from datamodel=Network_Traffic where All_Traffic.action=blocked
    by All_Traffic.src_ip
| sort -count | head 20
```

**Pattern 3: Filter before transforming**
```spl
# Bad: transforms all events before filtering
index=web | eval response_time=response_time_ms/1000 | where response_time > 5

# Good: filter first with search-level predicate
index=web response_time_ms>5000 | eval response_time=response_time_ms/1000
```

**Pattern 4: Use `eventstats` sparingly**
```spl
# eventstats adds fields to every event -- expensive for large datasets
# Use stats + append/join only when you truly need per-event enrichment

# If you just need the aggregate, use stats:
index=web | stats avg(response_time_ms) as avg_rt by uri_path

# If you need per-event comparison to aggregate, eventstats is appropriate:
index=web | eventstats avg(response_time_ms) as avg_rt by uri_path
| where response_time_ms > avg_rt * 3
```

**Pattern 5: Efficient `dedup`**
```spl
# Bad: dedup on large dataset
index=auth | dedup user

# Good: stats (returns same result, parallelizable)
index=auth | stats latest(_time) as _time, latest(_raw) as _raw by user
```

### Search-Time Field Extraction Optimization

- **Inline extractions** (`EXTRACT-` in props.conf) run on every event. Keep them simple.
- **Report-based extractions** (`REPORT-` + transforms.conf) are preferred for complex regex.
- **Use `SHOULD_RUN` conditionals** (props.conf) to skip extractions when field not needed.
- **Calculated fields** (`EVAL-` in props.conf) run after extraction. Keep eval expressions simple.
- **Automatic lookups** run on every event. Use only for fields that are always needed.

## CIM Compliance

### What is CIM?

The Common Information Model (CIM) defines standard field names and values for common event categories. CIM compliance enables:
- Splunk Enterprise Security to work with your data
- Cross-sourcetype searches with consistent field names
- Data model acceleration for fast analytics
- Reuse of Splunkbase apps and dashboards

### CIM Data Models

Key data models for security:

| Data Model | Use | Key Fields |
|---|---|---|
| **Authentication** | Login/logout events | `action`, `user`, `src`, `dest`, `app` |
| **Network_Traffic** | Firewall, proxy, flow | `action`, `src_ip`, `dest_ip`, `dest_port`, `transport`, `bytes` |
| **Endpoint** (Processes, Filesystem, Registry) | EDR, Sysmon | `process_name`, `parent_process`, `user`, `dest` |
| **Intrusion_Detection** | IDS/IPS alerts | `signature`, `severity`, `src`, `dest`, `action` |
| **Malware** | AV/EDR detections | `signature`, `file_name`, `file_hash`, `action`, `dest` |
| **Web** | Web proxy, WAF | `url`, `http_method`, `status`, `src`, `dest`, `user_agent` |
| **Change** | Change management | `object`, `object_category`, `action`, `user`, `dest` |
| **Email** | Email gateway | `sender`, `recipient`, `subject`, `action`, `file_name` |

### CIM Mapping Implementation

```ini
# props.conf -- map vendor fields to CIM
[vendor:firewall_logs]
# Field aliases (rename vendor fields to CIM names)
FIELDALIAS-src = source_address AS src_ip
FIELDALIAS-dest = destination_address AS dest_ip
FIELDALIAS-dport = destination_port AS dest_port

# Calculated field (normalize action values)
EVAL-action = case(
    fw_action=="permit", "allowed",
    fw_action=="deny", "blocked",
    fw_action=="drop", "blocked",
    true(), fw_action
)

# Automatic lookup (enrich with asset data)
LOOKUP-asset = asset_lookup dest_ip AS dest_ip OUTPUT asset_priority, asset_owner

# Tags (associate sourcetype with data model)
# In tags.conf:
# [sourcetype=vendor:firewall_logs]
# network = enabled
# communicate = enabled
```

### Data Model Acceleration

Acceleration builds summary tsidx files in the background for fast `tstats` queries:

```
Settings > Data Models > <model> > Accelerate
  - Enable acceleration
  - Set summary range (7 days, 30 days, 1 year)
  - Earliest/latest time for backfill
```

**Monitoring acceleration:**
```spl
| rest /services/admin/summarization
| search is_inprogress=1 OR eai:acl.app="*"
| table eai:acl.app, name, summary.complete_pct, summary.size, summary.is_inprogress
```

**Trade-offs:**
- Accelerated data models consume disk and CPU for summary building
- Each acceleration job runs as a scheduled search
- Acceleration lag: summary may be 5-15 minutes behind real-time
- Disable acceleration for data models you don't query

## Notable Event Management (Enterprise Security Context)

### Alert Tuning Workflow

1. **Baseline** -- Enable a correlation search and let it run for 1-2 weeks without response actions
2. **Analyze** -- Review notable events for false positives. Document patterns.
3. **Tune** -- Add suppression rules, exception lookups, or modify the search logic
4. **Validate** -- Re-run for 1 week. Measure true-positive rate.
5. **Activate** -- Enable response actions (notable event creation, adaptive response)
6. **Maintain** -- Review monthly. Detection rules decay as the environment changes.

### False Positive Suppression Strategies

```spl
# Strategy 1: Exception lookup
| lookup fp_exceptions src_ip, dest_ip OUTPUT is_exception
| where is_exception!="true"

# Strategy 2: Threshold adjustment (avoid magic numbers)
| stats count by src_ip
| where count > [| inputlookup alert_thresholds.csv | search alert_name="brute_force" | return $threshold]

# Strategy 3: Whitelisting known benign patterns
| search NOT [| inputlookup known_scanners.csv | fields src_ip | format]
```

### Risk-Based Alerting (RBA) Best Practices

RBA assigns risk scores to entities (users, hosts) rather than generating individual alerts:

1. **Risk factors** -- Each correlation search contributes a risk score when it matches
2. **Risk aggregation** -- `Risk Analysis` data model sums risk per entity over a time window
3. **Risk threshold** -- Alert when cumulative risk exceeds a threshold (e.g., > 100 in 24 hours)

Benefits:
- Reduces alert volume by 90%+ (aggregate scoring vs. individual alerts)
- Captures slow-and-low attacks that individual rules miss
- Analysts see the full risk story for an entity, not isolated events

Implementation:
```spl
# Each correlation search outputs risk events:
| eval risk_object=src_user, risk_object_type="user", risk_score=25, risk_message="Suspicious login pattern"

# RBA aggregation search:
| tstats summariesonly=true sum(All_Risk.calculated_risk_score) as risk_score,
    dc(All_Risk.source) as source_count,
    values(All_Risk.source) as sources
    from datamodel=Risk.All_Risk
    where All_Risk.risk_object_type="user"
    by All_Risk.risk_object
| where risk_score > 100 AND source_count >= 3
```

## Security Content Development

### Detection Rule Template

```spl
# Title: [ATT&CK Technique] - [Brief Description]
# MITRE ATT&CK: T1059.001 (PowerShell)
# Data Sources: Sysmon (EventCode 1)
# Severity: High
# Confidence: Medium
# Version: 1.0
# Author: SOC Team
# Last Reviewed: 2026-01-15

index=windows sourcetype=XmlWinEventLog:Microsoft-Windows-Sysmon/Operational EventCode=1
    (CommandLine="*-EncodedCommand*" OR CommandLine="*-enc *" OR CommandLine="*-e *")
    (CommandLine="*powershell*" OR ParentImage="*powershell*")
| stats count, values(CommandLine) as commands, values(ParentImage) as parents by dest, user
| lookup known_encoded_ps_users user OUTPUT is_expected
| where is_expected!="true"
| eval risk_score=case(count>5, 80, count>1, 50, true(), 30)
```

### MITRE ATT&CK Coverage Dashboard

```spl
# Map saved searches to ATT&CK techniques (uses a lookup)
| inputlookup mitre_mapping.csv
| join type=left technique_id [
    | rest /services/saved/searches
    | search disabled=0 is_scheduled=1
    | rex field=qualifiedSearch "mitre_technique=(?<technique_id>T\d{4}(\.\d{3})?)"
    | stats count as detection_count by technique_id
]
| fillnull detection_count value=0
| table technique_id, technique_name, tactic, detection_count
| sort tactic, technique_name
```

## Cost Optimization

### Identify High-Volume, Low-Value Sources

```spl
index=_internal source=*license_usage.log type=Usage
| stats sum(b) as bytes by st
| eval GB=round(bytes/1024/1024/1024,2)
| sort -GB
| head 20
```

Cross-reference the top consumers with detection value. Sources not used in any correlation search are candidates for:
- **Filtering** -- Drop verbose events at the forwarder or HF
- **Routing** -- Send to a cheaper storage tier or summary index
- **Sampling** -- Ingest only a percentage of events

### Filtering at the Forwarder

```ini
# props.conf on Heavy Forwarder
[source::WinEventLog:Security]
# Drop noisy success-only events
TRANSFORMS-drop_success = drop_success_events

# transforms.conf
[drop_success_events]
REGEX = EventCode=(4624|4634|4672)
DEST_KEY = queue
FORMAT = nullQueue
```

### Summary Indexing for Compliance

For compliance reporting that doesn't need raw events:

```spl
# Scheduled search that writes summaries
index=firewall | stats count by src_ip, dest_ip, action, _time span=1h
| collect index=summary_firewall marker="report=hourly_traffic"
```

Retain raw data for 30 days (operational). Retain summaries for 1 year (compliance).

## Operational Best Practices

### Health Monitoring

Deploy Splunk's Monitoring Console (MC) or build custom dashboards:

```spl
# Index latency (time from event to indexed)
index=_internal sourcetype=splunkd source=*metrics.log group=per_index_thruput
| timechart span=5m avg(ev_latency) by series

# Forwarder health
index=_internal sourcetype=splunkd source=*metrics.log group=tcpin_connections
| stats latest(_time) as last_seen, latest(version) as ver by hostname
| eval status=if(now()-last_seen < 900, "healthy", "stale")
| stats count by status

# Search concurrency
index=_audit action=search info=granted NOT user=splunk-system-user
| timechart span=5m dc(search_id) as concurrent_searches
```

### Backup Strategy

- **Configuration** -- Back up `$SPLUNK_HOME/etc/` (apps, system/local, users)
- **KV Store** -- `splunk backup kvstore` or rsync `$SPLUNK_HOME/var/lib/splunk/kvstore/`
- **Lookups** -- Back up CSV lookups in `$SPLUNK_HOME/etc/apps/*/lookups/`
- **Index data** -- SmartStore handles durability (S3 has 11 9s). Non-SmartStore: rely on clustering replication factor.
- **Disaster recovery** -- For single-site: replicate to remote site. For multi-site clustering, use site-aware replication.

### Change Management

- Use version control (Git) for all Splunk configs and searches
- Deploy changes through the deployment server or deployer (not manual edits)
- Test config changes with `btool check` before applying
- Maintain a staging environment that mirrors production topology
- Document all custom apps, add-ons, and their dependencies
