# Splunk Diagnostics Reference

## Diagnostic Workflow

The standard troubleshooting approach for Splunk issues:

```
1. Identify symptoms  -->  What is the user experiencing?
        |
2. Check internal logs  -->  index=_internal for errors and warnings
        |
3. Check resource usage  -->  CPU, memory, disk, network on Splunk components
        |
4. Narrow to component  -->  Indexer, search head, forwarder, or data pipeline
        |
5. Apply targeted diagnostics  -->  Use the relevant section below
```

## License Usage Issues

### Check Current License Usage

```spl
index=_internal source=*license_usage.log type=Usage
| stats sum(b) as bytes by idx, st, s, h
| eval MB=round(bytes/1024/1024,2)
| sort -MB
| head 50
```

### License Violation Diagnostics

```spl
| rest /services/licenser/messages
| search severity=ERROR OR severity=WARN
| table create_time, description, severity

| rest /services/licenser/pools
| table title, used_bytes, effective_byte_quota, usage_percent
```

**Common causes of license violations:**
- Duplicate data ingestion (same file monitored by multiple forwarders)
- Unexpected data volume spike (new data source, verbose logging enabled)
- Misconfigured HEC tokens writing to wrong index
- Heavy Forwarder misconfigured to index locally AND forward

**Resolution:**
1. Identify the top consumers by sourcetype and index (search above)
2. Check for duplicate inputs: `| rest /services/data/inputs/all | search disabled=0`
3. Add data volume alerts: schedule a search on license_usage.log with threshold
4. Splunk allows 5 license warnings in a 30-day rolling window before violation

### License Pool Management

```spl
| rest /services/licenser/pools
| join type=left title [| rest /services/licenser/stacks | rename title as stack_title | table stack_title, quota]
| table title, used_bytes, effective_byte_quota, stack_id
```

## Search Performance Issues

### Identify Slow Searches

```spl
index=_audit action=search info=completed
| eval duration_sec=total_run_time
| where duration_sec > 60
| stats count, avg(duration_sec) as avg_sec, max(duration_sec) as max_sec by user, savedsearch_name
| sort -avg_sec
```

### Search Job Inspector

For any running or completed search, use Job Inspector (Settings > Job Inspector or `| rest /services/search/jobs/<sid>`):

Key metrics:
- **command.search.rawdata** -- Time reading raw data from buckets. High = too much data scanned.
- **command.search.index** -- Time searching tsidx files. High = many buckets, poor bloom filter hit rate.
- **command.search.filter** -- Time filtering events. High = expensive predicates.
- **command.stats / command.sort** -- Time in transforming commands. High = large result sets.

### Search Concurrency

```spl
| rest /services/server/status/resource-usage/splunk-processes
| search search_props.sid=*
| stats count by search_props.user, search_props.type
```

**Concurrency limits:**
- `max_searches_per_cpu` -- Default 1 per CPU core (historical searches)
- `max_rt_search_multiplier` -- Real-time searches consume 1 slot per search
- `max_searches_perc` -- Maximum percentage of CPU for searches (default 50%)

Tuning: `limits.conf` controls search limits. Avoid raising limits without adding capacity.

### Dispatch Directory Cleanup

If search head disk fills up:
```spl
| rest /services/search/jobs
| eval age=now()-published_time
| where age > 86400
| sort -age
| table sid, title, published_time, age, diskUsage
```

Clean with: `splunk clean-dispatch <ttl>` or delete old jobs via REST API.

## Forwarder Issues

### Forwarder Connectivity Check

**From the indexer:**
```spl
index=_internal sourcetype=splunkd component=TcpInputProc
| stats latest(_time) as last_seen by host
| eval hours_ago=round((now()-last_seen)/3600,1)
| where hours_ago > 1
| sort -hours_ago
```

**From the deployment server:**
```spl
index=_internal sourcetype=splunkd source=*metrics.log group=tcpin_connections
| stats latest(_time) as last_connected, latest(version) as version, latest(os) as os by hostname, guid
| eval hours_ago=round((now()-last_connected)/3600,1)
| sort -hours_ago
```

### Forwarder Throughput

```spl
index=_internal sourcetype=splunkd source=*metrics.log group=tcpout_connections
| timechart span=5m avg(tcp_KBps) by hostname
```

### Forwarder Queue Issues

Forwarders use internal queues. If the output queue fills up, data can be delayed or lost:

```spl
index=_internal sourcetype=splunkd source=*metrics.log group=queue
| search name=tcpout*
| timechart span=5m max(current_size_kb) by host
```

**Queue pipeline:**
```
Input Queue  -->  Parsing Queue  -->  Output Queue  -->  Indexer
```

If output queue is consistently full:
- Check network connectivity to indexer
- Check indexer is accepting connections
- Check for indexer acknowledgment (`useACK=true` in outputs.conf)
- Consider adding more indexers or load balancing

### Missing Data from Forwarders

Diagnostic steps:
1. Check forwarder is running: `splunk status` on the forwarder
2. Check inputs are configured: `splunk btool inputs list --debug`
3. Check output connectivity: `splunk list forward-server`
4. Check for errors: `index=_internal host=<forwarder> sourcetype=splunkd log_level=ERROR`
5. Check file monitoring positions: `$SPLUNK_HOME/var/lib/splunk/fishbucket/`

## Indexer Performance

### Indexing Throughput

```spl
index=_internal sourcetype=splunkd source=*metrics.log group=thruput
| timechart span=5m sum(instantaneous_kbps) as kbps by host
```

### Bucket Status

```spl
| dbinspect index=* | stats count by state, splunk_server
| chart count by splunk_server, state
```

### Disk Usage by Index

```spl
| rest /services/data/indexes
| table title, currentDBSizeMB, maxTotalDataSizeMB, totalEventCount, frozenTimePeriodInSecs
| eval retention_days=round(frozenTimePeriodInSecs/86400)
| eval pct_used=round(currentDBSizeMB/maxTotalDataSizeMB*100,1)
| sort -currentDBSizeMB
```

### SmartStore Cache Issues

```spl
index=_internal sourcetype=splunkd component=CacheManager
| stats latest(cache_usage_pct) as cache_pct, latest(cache_hit_ratio) as hit_ratio by host
```

If cache hit ratio is low:
- Increase local cache size (`maxCacheSizeMB` in indexes.conf)
- Check S3/blob storage latency
- Review search patterns -- are users searching very old data frequently?

## Clustering Issues

### Indexer Cluster Health

```spl
| rest /services/cluster/manager/peers
| table label, status, site, replication_count, search_count, bucket_count, is_searchable
```

```spl
| rest /services/cluster/manager/generation
| table generation_id, replication_factor_met, search_factor_met
```

### Search Head Cluster Health

```spl
| rest /services/shcluster/captain/members
| table label, status, last_heartbeat, is_captain
```

### Split-Brain Detection

```spl
index=_internal sourcetype=splunkd component=CMBucketId OR component=ClusteringMgr
| search "split brain" OR "primary dedup" OR "excess replicas"
| table _time, host, component, message
```

## Data Integrity Checks

### Verify Events Are Being Indexed

```spl
index=<target_index> sourcetype=<target_sourcetype> earliest=-15m
| stats count by host
| sort -count
```

### Check for Timestamp Issues

```spl
index=<target_index> sourcetype=<target_sourcetype>
| eval index_time=strftime(_indextime, "%Y-%m-%d %H:%M:%S")
| eval event_time=strftime(_time, "%Y-%m-%d %H:%M:%S")
| eval lag_sec=_indextime - _time
| where abs(lag_sec) > 3600
| table _time, index_time, lag_sec, host, source
```

Events with large lag (event time far from index time) indicate timestamp parsing problems.

### Check for Truncated Events

```spl
index=<target_index> sourcetype=<target_sourcetype>
| eval event_len=len(_raw)
| stats max(event_len) as max_len, avg(event_len) as avg_len
```

If `max_len` is consistently 10000 bytes, events are being truncated. Increase `TRUNCATE` in props.conf (default 10000).

## REST API Diagnostics

Useful REST endpoints for troubleshooting:

```bash
# Server info
curl -k -u admin:password https://localhost:8089/services/server/info

# Index status
curl -k -u admin:password https://localhost:8089/services/data/indexes?output_mode=json

# Search jobs
curl -k -u admin:password https://localhost:8089/services/search/jobs?output_mode=json

# Cluster status
curl -k -u admin:password https://localhost:8089/services/cluster/manager/health?output_mode=json

# Forwarder management
curl -k -u admin:password https://localhost:8089/services/deployment/server/clients?output_mode=json
```
