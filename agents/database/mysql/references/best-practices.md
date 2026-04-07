# MySQL Best Practices Reference

## InnoDB Tuning Parameters

### Memory and Buffer Pool

```ini
# Buffer pool: 70-80% of available RAM for dedicated MySQL server
innodb_buffer_pool_size = 24G           # e.g., for 32GB RAM server
innodb_buffer_pool_instances = 8        # split into instances for concurrency (when pool > 1GB)
innodb_buffer_pool_chunk_size = 128M    # granularity of online resizing

# Log buffer
innodb_log_buffer_size = 64M            # increase from 16MB default for write-heavy workloads
```

### Redo Log

```ini
# 8.0.30+: single parameter replaces innodb_log_file_size + innodb_log_files_in_group
innodb_redo_log_capacity = 2G           # size for 1-2 hours of peak write volume
# Pre-8.0.30:
# innodb_log_file_size = 1G
# innodb_log_files_in_group = 2
```

### Flush and I/O

```ini
innodb_flush_log_at_trx_commit = 1      # full ACID (flush+sync on every commit)
innodb_flush_method = O_DIRECT          # bypass OS page cache (avoid double caching)
innodb_flush_neighbors = 0              # disable neighbor flushing on SSD (unnecessary coalescing)
innodb_io_capacity = 2000               # background I/O ops per second (SSD: 2000-5000)
innodb_io_capacity_max = 4000           # burst limit (2x innodb_io_capacity)
innodb_doublewrite = ON                 # ON unless storage guarantees 16KB atomic writes
```

### Concurrency and Threading

```ini
innodb_thread_concurrency = 0           # 0 = unlimited (let InnoDB manage); set to 2x CPU cores if contention
innodb_read_io_threads = 4              # increase for read-heavy workloads (up to 64)
innodb_write_io_threads = 4             # increase for write-heavy workloads (up to 64)
innodb_purge_threads = 4                # background purge of undo log records
innodb_page_cleaners = 4                # dirty page flush threads (match buffer_pool_instances or lower)
```

### Other InnoDB Settings

```ini
innodb_file_per_table = ON              # each table in its own .ibd file (default)
innodb_adaptive_hash_index = ON         # disable (OFF) if btr_search latch contention observed
innodb_change_buffer_max_size = 25      # % of buffer pool; reduce for read-heavy workloads
innodb_stats_persistent = ON            # persist optimizer statistics across restarts
innodb_stats_persistent_sample_pages = 20  # sample pages for persistent stats; increase for large tables
```

### Server-Level Parameters

```ini
max_connections = 200                   # adjust based on workload; use connection pooling
table_open_cache = 4000                 # cache of open table descriptors
table_definition_cache = 2000           # cache of table definitions
tmp_table_size = 64M                    # max size for in-memory temp tables
max_heap_table_size = 64M               # must match tmp_table_size
thread_cache_size = 50                  # cache threads for reuse
sort_buffer_size = 256K                 # per-session; increase only for specific queries
join_buffer_size = 256K                 # per-session; used for joins without indexes
```

## Replication Best Practices

### GTID Replication Setup

Always use GTID-based replication for new deployments:

```ini
[mysqld]
gtid_mode = ON
enforce_gtid_consistency = ON
binlog_format = ROW                     # ROW is default in 8.0+ and safest for replication
log_replica_updates = ON                # required for GTID and chain replication
binlog_row_image = FULL                 # default; MINIMAL saves space but limits point-in-time analysis
```

### Multi-Threaded Replica Applier

Configure replicas to apply events in parallel:

```ini
# MySQL 8.0
replica_parallel_workers = 8            # number of applier threads (4-16 typical)
replica_parallel_type = LOGICAL_CLOCK   # 8.0: parallelism based on commit timestamps
replica_preserve_commit_order = ON      # maintain commit order on replica

# MySQL 8.4+: improved defaults; LOGICAL_CLOCK is the only option
```

### Monitoring Replication Lag

```sql
-- Check replica lag
SHOW REPLICA STATUS\G
-- Key fields:
--   Seconds_Behind_Source: estimated lag in seconds
--   Retrieved_Gtid_Set: GTIDs received from source
--   Executed_Gtid_Set: GTIDs applied on replica

-- Performance Schema replication tables (more detailed)
SELECT * FROM performance_schema.replication_applier_status_by_worker;
SELECT * FROM performance_schema.replication_connection_status;
```

### Replication Filters

```ini
# Filter replication to specific databases (use with caution)
replicate_do_db = myapp_db
replicate_ignore_db = test_db

# Row-based filtering (safer than statement-based)
replicate_wild_do_table = myapp_db.%
```

**Warning:** Replication filters with statement-based replication can silently skip statements. Always use `binlog_format=ROW` with filters.

## Security Best Practices

### Authentication

```ini
# Default plugin (8.0+)
default_authentication_plugin = caching_sha2_password   # 8.0 default
# 8.4+: mysql_native_password is disabled by default; do not re-enable
```

- `caching_sha2_password` requires TLS or RSA key exchange for the first authentication
- Ensure all client connectors support `caching_sha2_password` before upgrading
- For legacy applications that cannot upgrade connectors, use `mysql_clear_password` over TLS

### TLS Configuration

```ini
[mysqld]
require_secure_transport = ON           # reject non-TLS connections
ssl_ca = /etc/mysql/ssl/ca.pem
ssl_cert = /etc/mysql/ssl/server-cert.pem
ssl_key = /etc/mysql/ssl/server-key.pem
tls_version = TLSv1.2,TLSv1.3          # disable TLS 1.0 and 1.1
```

### Roles (8.0+)

Use roles instead of granting privileges directly to users:

```sql
-- Create roles
CREATE ROLE 'app_read', 'app_write', 'app_admin';

-- Grant privileges to roles
GRANT SELECT ON myapp_db.* TO 'app_read';
GRANT INSERT, UPDATE, DELETE ON myapp_db.* TO 'app_write';
GRANT ALL ON myapp_db.* TO 'app_admin';

-- Assign roles to users
GRANT 'app_read', 'app_write' TO 'appuser'@'%';

-- Activate roles
SET DEFAULT ROLE ALL TO 'appuser'@'%';
```

### Dual Passwords (8.0.14+)

Allow password rotation without application downtime:

```sql
-- Set new password while retaining the old one
ALTER USER 'appuser'@'%' IDENTIFIED BY 'new_password' RETAIN CURRENT PASSWORD;

-- After all applications have switched to the new password:
ALTER USER 'appuser'@'%' DISCARD OLD PASSWORD;
```

### At-Rest Encryption (8.0+)

```ini
# Tablespace encryption
innodb_redo_log_encrypt = ON            # encrypt redo log
innodb_undo_log_encrypt = ON            # encrypt undo log
binlog_encryption = ON                  # encrypt binary log

# Encrypt individual tablespaces
ALTER TABLE sensitive_data ENCRYPTION = 'Y';

# Encrypt all new tables by default
default_table_encryption = ON
```

Requires a keyring plugin (`component_keyring_file`, `component_keyring_encrypted_file`, or enterprise `component_keyring_kms`).

## Backup Strategies

### mysqldump (Logical, Built-in)

```bash
# Full instance backup with GTID info
mysqldump --all-databases --single-transaction --routines --triggers \
  --set-gtid-purged=ON --result-file=/backup/full_dump.sql

# Single database
mysqldump --single-transaction --routines --triggers \
  myapp_db > /backup/myapp_db.sql

# Compressed
mysqldump --single-transaction --all-databases | gzip > /backup/full_dump.sql.gz
```

**Limitations:** Single-threaded, slow for large databases (>100GB). Use MySQL Shell or physical backup instead.

### MySQL Shell Dump/Load (Logical, Parallel)

```javascript
// Parallel logical dump (much faster than mysqldump)
util.dumpInstance('/backup/full', {threads: 8, compression: 'zstd'});

// Dump specific schemas
util.dumpSchemas(['myapp_db'], '/backup/myapp', {threads: 8});

// Parallel load
util.loadDump('/backup/full', {threads: 8, progressFile: '/tmp/progress.json'});
```

Advantages over mysqldump:
- Multi-threaded dump and load
- Chunked tables for parallel restore
- Progress tracking and resumable loads
- Built-in compression (zstd, gzip)

### Percona XtraBackup (Physical, Open Source)

```bash
# Full backup
xtrabackup --backup --target-dir=/backup/full --user=backup_user --password=xxx

# Prepare backup (apply redo log)
xtrabackup --prepare --target-dir=/backup/full

# Incremental backup
xtrabackup --backup --target-dir=/backup/incr1 \
  --incremental-basedir=/backup/full

# Prepare incremental
xtrabackup --prepare --apply-log-only --target-dir=/backup/full
xtrabackup --prepare --target-dir=/backup/full --incremental-dir=/backup/incr1
```

Advantages: Hot backup (no locks for InnoDB), fast restore (copy files), incremental support.

### MySQL Enterprise Backup (Physical, Commercial)

```bash
# Full backup
mysqlbackup --user=backup_user --backup-dir=/backup/full backup-and-apply-log

# Incremental
mysqlbackup --incremental --incremental-base=history:last_backup \
  --backup-dir=/backup/incr1 backup
```

### Backup Best Practices

- **Test restores regularly** -- a backup you cannot restore is not a backup
- **Use `--single-transaction`** for logical backups of InnoDB tables (consistent snapshot without locking)
- **Include GTID information** in backups for seamless replica provisioning
- **Retain binary logs** between full backups for point-in-time recovery
- **Monitor backup duration and size trends** to detect growth before it causes window overruns
- **Encrypt backups** at rest and in transit
- **Store backups off-server** (different storage, different region)
