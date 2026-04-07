# SQL Server Best Practices Reference

## Instance Configuration

### Memory

```sql
-- Set max server memory (leave 4-8 GB for OS on dedicated servers)
-- Formula: Total RAM - 4GB (for OS) - 1GB per 4GB above 16GB (for thread stacks, CLR, etc.)
-- Example for 64 GB server: 64 - 4 - ((64-16)/4) = 48 GB
EXEC sp_configure 'max server memory (MB)', 49152;
RECONFIGURE;

-- Enable Lock Pages in Memory (prevents OS from paging out buffer pool)
-- Requires Windows policy: Lock pages in memory granted to SQL Server service account
```

### MAXDOP (Max Degree of Parallelism)

Rules of thumb:
- **OLTP**: MAXDOP = 1-4 (lower to reduce parallelism waits)
- **Data warehouse**: MAXDOP = 4-8 or 0 (unlimited, let the optimizer decide)
- **General**: Number of physical cores per NUMA node, capped at 8

```sql
-- Check NUMA configuration
SELECT parent_node_id, COUNT(*) AS scheduler_count
FROM sys.dm_os_schedulers
WHERE status = 'VISIBLE ONLINE'
GROUP BY parent_node_id;

-- Set MAXDOP
EXEC sp_configure 'max degree of parallelism', 4;
RECONFIGURE;
```

### Cost Threshold for Parallelism

Default is 5, which is far too low for most workloads. Many trivial queries go parallel unnecessarily.

```sql
-- Recommended: start at 50 and adjust based on workload
EXEC sp_configure 'cost threshold for parallelism', 50;
RECONFIGURE;
```

Find a good value by examining query costs:
```sql
-- Distribution of query costs in plan cache
SELECT
    CASE
        WHEN qs.total_worker_time/qs.execution_count/1000 < 5 THEN '< 5ms'
        WHEN qs.total_worker_time/qs.execution_count/1000 < 50 THEN '5-50ms'
        WHEN qs.total_worker_time/qs.execution_count/1000 < 500 THEN '50-500ms'
        ELSE '> 500ms'
    END AS cpu_range,
    COUNT(*) AS query_count
FROM sys.dm_exec_query_stats qs
GROUP BY
    CASE
        WHEN qs.total_worker_time/qs.execution_count/1000 < 5 THEN '< 5ms'
        WHEN qs.total_worker_time/qs.execution_count/1000 < 50 THEN '5-50ms'
        WHEN qs.total_worker_time/qs.execution_count/1000 < 500 THEN '50-500ms'
        ELSE '> 500ms'
    END;
```

### tempdb Configuration

```sql
-- Check current tempdb files
SELECT file_id, name, type_desc, size * 8 / 1024 AS size_mb,
       growth, is_percent_growth
FROM sys.master_files WHERE database_id = 2;
```

Best practices:
- **Number of files**: 1 per logical CPU core, up to 8 data files. Add more in groups of 4 if `PAGELATCH` waits persist.
- **Equal sizing**: All data files must be the same size for proportional fill to work correctly.
- **Pre-size**: Size files large enough to avoid autogrowth during normal operations.
- **Separate disk**: Place tempdb on its own fast storage (SSD/NVMe preferred).
- **Instant file initialization**: Grant the SQL Server service account "Perform volume maintenance tasks" to avoid zero-initialization on growth.
- **SQL Server 2016+**: Uniform extent allocation is default. Consider enabling tempdb metadata optimization (2019+):
  ```sql
  ALTER SERVER CONFIGURATION SET MEMORY_OPTIMIZED TEMPDB_METADATA = ON;
  -- Requires restart
  ```

## Backup Strategy

### The 3-2-1 Rule

- **3** copies of data (production + 2 backups)
- **2** different media types (disk + tape/cloud)
- **1** offsite copy

### Recovery Model Selection

| Recovery Model | Use Case | Log Backup? | Point-in-Time Restore? |
|---|---|---|---|
| **Simple** | Dev/test, data you can regenerate | No | No |
| **Full** | Production OLTP, compliance | Yes (every 15-30 min) | Yes |
| **Bulk-logged** | Temporarily during bulk operations | Yes | Limited |

### Backup Schedule Template

**Production OLTP (Full recovery model):**
- Full backup: Daily (or weekly for very large databases)
- Differential backup: Every 4-6 hours (reduces restore time)
- Transaction log backup: Every 5-15 minutes (RPO target)

```sql
-- Full backup with compression and checksum
BACKUP DATABASE [MyDB] TO DISK = N'E:\Backups\MyDB_Full.bak'
WITH COMPRESSION, CHECKSUM, INIT, STATS = 10;

-- Differential
BACKUP DATABASE [MyDB] TO DISK = N'E:\Backups\MyDB_Diff.bak'
WITH DIFFERENTIAL, COMPRESSION, CHECKSUM, INIT;

-- Transaction log
BACKUP LOG [MyDB] TO DISK = N'E:\Backups\MyDB_Log.trn'
WITH COMPRESSION, CHECKSUM, INIT;
```

### Backup Validation

**Always test restores.** An untested backup is not a backup.

```sql
-- Verify backup integrity
RESTORE VERIFYONLY FROM DISK = N'E:\Backups\MyDB_Full.bak' WITH CHECKSUM;

-- Test restore to a different database
RESTORE DATABASE [MyDB_Test] FROM DISK = N'E:\Backups\MyDB_Full.bak'
WITH MOVE N'MyDB' TO N'E:\Data\MyDB_Test.mdf',
     MOVE N'MyDB_log' TO N'E:\Log\MyDB_Test_log.ldf',
     NORECOVERY;
RESTORE DATABASE [MyDB_Test] FROM DISK = N'E:\Backups\MyDB_Diff.bak'
WITH NORECOVERY;
RESTORE LOG [MyDB_Test] FROM DISK = N'E:\Backups\MyDB_Log.trn'
WITH RECOVERY;
```

### Copy-Only Backups

Use `COPY_ONLY` when you need an ad-hoc backup without breaking the differential or log chain:
```sql
BACKUP DATABASE [MyDB] TO DISK = N'E:\Backups\MyDB_CopyOnly.bak'
WITH COPY_ONLY, COMPRESSION, CHECKSUM;
```

## Index Maintenance

### Fragmentation Thresholds

| Fragmentation | Action | Method |
|---|---|---|
| < 10% | None | -- |
| 10-30% | Reorganize | `ALTER INDEX ... REORGANIZE` (online, minimal logging) |
| > 30% | Rebuild | `ALTER INDEX ... REBUILD` (offline or online with Enterprise) |

```sql
-- Check fragmentation for a specific table
SELECT
    i.name AS index_name,
    ips.index_type_desc,
    ips.avg_fragmentation_in_percent,
    ips.page_count,
    ips.avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.MyTable'), NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.page_count > 1000  -- Skip tiny indexes
ORDER BY ips.avg_fragmentation_in_percent DESC;
```

### Statistics Maintenance

Statistics drive the query optimizer's cardinality estimates. Stale statistics cause bad plans.

```sql
-- Check when statistics were last updated
SELECT
    OBJECT_NAME(s.object_id) AS table_name,
    s.name AS stat_name,
    sp.last_updated,
    sp.rows, sp.rows_sampled,
    sp.modification_counter
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
ORDER BY sp.modification_counter DESC;
```

Best practices:
- Keep `AUTO_UPDATE_STATISTICS` ON (default)
- Enable `AUTO_UPDATE_STATISTICS_ASYNC` for OLTP to avoid query delays during stats updates
- For large tables: schedule manual stats updates with `FULLSCAN` or high sample rates during maintenance windows
- Trace flag 2371 (pre-2016): Lowers the auto-update threshold for large tables. Default behavior in 2016+.

### Recommended Maintenance Plan

Use Ola Hallengren's maintenance solution (industry standard, free):

1. **Index Optimize** -- Weekly (or nightly for heavy-write workloads)
2. **Statistics Update** -- Nightly (after index maintenance)
3. **Integrity Checks** -- Weekly (`DBCC CHECKDB`)
4. **Backup cleanup** -- Delete old backups based on retention policy

## Security Hardening

### Authentication

- **Windows Authentication** preferred over SQL Authentication (uses Kerberos, integrates with AD policies)
- Disable the `sa` account or rename it and use a strong password
- Enable **login auditing** (at minimum, failed logins)

### Authorization

```sql
-- Create application role with minimum permissions
CREATE ROLE [AppRole] AUTHORIZATION [dbo];
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[dbo] TO [AppRole];
DENY ALTER ON SCHEMA::[dbo] TO [AppRole];

-- Never grant db_owner or sysadmin to application accounts
```

### Encryption

| Feature | Protects | Performance Impact | Version |
|---|---|---|---|
| TDE | Data at rest (files, backups) | 3-5% | 2008+ (Enterprise), 2019+ (all editions) |
| Always Encrypted | Column-level, client-side | Query limitations | 2016+ |
| TLS | Data in transit | Minimal | All versions |
| Backup encryption | Backup files | Minimal | 2014+ |

### Network Security

- Enable encrypted connections (force encryption in SQL Server Configuration Manager)
- Use non-default ports (not 1433) to reduce scan exposure
- Disable SQL Server Browser if not using named instances
- Enable Windows Firewall, allow only SQL Server port
- Disable `xp_cmdshell` unless specifically required

### Auditing

```sql
-- Create server audit
CREATE SERVER AUDIT [SecurityAudit]
TO FILE (FILEPATH = N'E:\Audit\', MAXSIZE = 100 MB, MAX_ROLLOVER_FILES = 10)
WITH (ON_FAILURE = CONTINUE);
ALTER SERVER AUDIT [SecurityAudit] WITH (STATE = ON);

-- Audit login events
CREATE SERVER AUDIT SPECIFICATION [LoginAudit]
FOR SERVER AUDIT [SecurityAudit]
ADD (FAILED_LOGIN_GROUP),
ADD (SUCCESSFUL_LOGIN_GROUP);
ALTER SERVER AUDIT SPECIFICATION [LoginAudit] WITH (STATE = ON);
```

## Monitoring Essentials

### Key Metrics to Track

| Metric | Source | Warning Threshold |
|---|---|---|
| CPU utilization | `sys.dm_os_ring_buffers` or perfmon | > 80% sustained |
| Buffer cache hit ratio | `sys.dm_os_performance_counters` | < 99% (OLTP) |
| Page life expectancy | `sys.dm_os_performance_counters` | < 300 seconds |
| Batch requests/sec | `sys.dm_os_performance_counters` | Baseline-dependent |
| Active user connections | `sys.dm_exec_sessions` | Baseline-dependent |
| Disk latency (read) | `sys.dm_io_virtual_file_stats` | > 20ms |
| Disk latency (write) | `sys.dm_io_virtual_file_stats` | > 5ms (log), > 20ms (data) |
| Log space used % | `DBCC SQLPERF(LOGSPACE)` | > 80% |
| Blocking duration | `sys.dm_exec_requests` | > 30 seconds |
| Failed jobs | `msdb.dbo.sysjobhistory` | Any failure |
| AG sync lag | `sys.dm_hadr_database_replica_states` | `log_send_queue_size` > 0 sustained |

### Alerting Setup

Configure SQL Agent alerts for critical conditions:

```sql
-- Alert on severity 17+ errors (insufficient resources)
EXEC msdb.dbo.sp_add_alert @name = N'Severity 17 Error',
    @severity = 17, @notification_message = N'Severity 17 error detected';

-- Alert on severity 20+ errors (fatal errors)
EXEC msdb.dbo.sp_add_alert @name = N'Severity 20 Error',
    @severity = 20, @notification_message = N'Fatal error detected';

-- Alert on error 825 (read retry - disk issue warning)
EXEC msdb.dbo.sp_add_alert @name = N'Error 825 - Read Retry',
    @message_id = 825;
```

### Proactive Health Check Schedule

| Task | Frequency | Method |
|---|---|---|
| DBCC CHECKDB | Weekly | SQL Agent job |
| Backup validation (test restore) | Monthly | SQL Agent job |
| Index fragmentation review | Weekly | Maintenance solution |
| Security audit review | Monthly | Manual review |
| Capacity planning (disk growth) | Monthly | Trending reports |
| Unused index cleanup | Quarterly | DMV analysis |
| Statistics review | Monthly | DMV analysis |
| Recovery drill (full restore) | Quarterly | Manual test |
