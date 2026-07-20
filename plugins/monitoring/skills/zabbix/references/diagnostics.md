# Zabbix Diagnostics Reference

> Performance tuning, database optimization, common issues, and internal monitoring.

---

## Performance Tuning

### Server Process Counts

Tune in `/etc/zabbix/zabbix_server.conf` based on workload profile:

| Parameter | Purpose | Tuning |
|-----------|---------|--------|
| `StartPollers` | Active polling of items | Increase for many passive agent items |
| `StartPollersUnreachable` | Polling unreachable hosts | Increase if many hosts go offline |
| `StartTrappers` | Receiving trapper/active agent data | Increase for push-heavy workloads |
| `StartPingers` | ICMP checks | Increase for large host counts |
| `StartDiscoverers` | Network discovery | Increase for large subnet scans |
| `StartHTTPPollers` | HTTP Agent items | Increase for many web checks |

Monitor process utilization via `zabbix[process,<type>,avg,busy]` internal items. If any process type exceeds 70% busy, increase its count.

### Cache Tuning

| Parameter | Default | Guidance |
|-----------|---------|---------|
| `ValueCacheSize` | 8M | Increase for trend function acceleration |
| `HistoryCacheSize` | 16M | Increase for high write throughput |
| `HistoryIndexCacheSize` | 4M | Increase with HistoryCacheSize |
| `ConfigCacheSize` | 32M | Increase for large host/item counts |
| `TrendCacheSize` | 4M | Increase if trend cache full warnings appear |

Monitor cache hit ratios via `zabbix[vcache,cache,hits]` and `zabbix[vcache,cache,misses]`.

### Item Interval Optimization

- Avoid all items at :00 seconds -- creates polling spikes
- Use randomized delays or offset intervals
- Agent2 scheduled checks with jitter distribute load
- `FlexibleIntervals` allow different rates by time of day

---

## Database Tuning

### TimescaleDB (Recommended for PostgreSQL)

```sql
-- Convert history tables to hypertables
SELECT create_hypertable('history', 'clock', chunk_time_interval => 86400);
SELECT create_hypertable('history_uint', 'clock', chunk_time_interval => 86400);
SELECT create_hypertable('trends', 'clock', chunk_time_interval => 2592000);
SELECT create_hypertable('trends_uint', 'clock', chunk_time_interval => 2592000);
```

Enable compression:
```sql
ALTER TABLE history SET (timescaledb.compress);
SELECT add_compression_policy('history', INTERVAL '7 days');
```

Achieves 5-10x compression ratio. Dramatically improves INSERT performance via parallel chunk writes. Enables sustained 100K+ values/second on modern hardware.

### PostgreSQL Tuning

```
shared_buffers = 25% RAM
effective_cache_size = 75% RAM
work_mem = 16MB
checkpoint_completion_target = 0.9
max_wal_size = 2GB
```

Use PgBouncer connection pooler for large deployments.

### MySQL/MariaDB Tuning

```
innodb_buffer_pool_size = 70-80% RAM
innodb_flush_log_at_trx_commit = 2    # slight durability trade-off
innodb_flush_method = O_DIRECT
```

---

## Housekeeping

The housekeeper process deletes old history, trends, events, and alerts based on retention settings.

**For large deployments:** Disable built-in housekeeper (`HousekeepingFrequency=0`) and use TimescaleDB retention policies or PostgreSQL table partitioning. These are orders of magnitude faster than row-by-row deletion.

**Tune `MaxHousekeeperDelete`** to limit rows deleted per cycle, reducing lock contention during peak hours.

---

## Internal Monitoring

### Key Internal Items

| Item Key | What It Monitors |
|----------|-----------------|
| `zabbix[process,poller,avg,busy]` | Poller process busy % |
| `zabbix[process,trapper,avg,busy]` | Trapper process busy % |
| `zabbix[queue]` | Items delayed in processing queue |
| `zabbix[queue,10m]` | Items delayed > 10 minutes |
| `zabbix[vcache,cache,hits]` | Value cache hits |
| `zabbix[vcache,cache,misses]` | Value cache misses |
| `zabbix[wcache,values]` | Values waiting to be written to DB |
| `zabbix[rcache,buffer,pfree]` | Configuration cache free % |
| `zabbix[requiredperformance]` | Required NVPS (new values per second) |

### Health Indicators

- **Queue > 0 (sustained):** Server cannot keep up with polling. Increase pollers or reduce item count.
- **Process busy > 70%:** That process type is saturated. Increase count.
- **Value cache misses > 10%:** Increase `ValueCacheSize`.
- **Configuration cache < 10% free:** Increase `ConfigCacheSize`.

---

## Common Issues

### "Zabbix agent on host is unreachable"

1. Check agent is running: `systemctl status zabbix-agent2`
2. Check firewall allows port 10050 inbound
3. Check `Server=` directive in agent config includes Zabbix server IP
4. Check hostname matches: agent `Hostname` must match host name in Zabbix frontend

### "Not supported" Items

- Value type mismatch (expecting integer, receiving string)
- Missing UserParameter or plugin on agent
- Permission denied (agent running as non-root, accessing restricted resource)
- Network timeout on remote check

### High Queue / Slow Processing

1. Check `zabbix[process,*,avg,busy]` for saturated processes
2. Check database performance (slow queries, lock contention)
3. Check network latency to monitored hosts
4. Consider adding proxies to distribute load

### Database Growing Too Fast

1. Review history retention settings on items
2. Enable TimescaleDB compression
3. Check for high-frequency items (every 10s) on many hosts
4. Use "Discard unchanged" preprocessing to reduce storage

---

## Monitoring Scale Reference

| Topology | Capacity |
|----------|----------|
| Single server, no proxy | ~5,000 hosts, ~500K checks/min |
| With proxies | Linear scale: 10 proxies x 50K checks/min |
| TimescaleDB | Sustained 100K+ values/second |

Scale depends on hardware, database performance, and item complexity.
