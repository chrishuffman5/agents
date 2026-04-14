# MariaDB Best Practices Reference

## InnoDB Tuning

### Buffer Pool

```ini
# Set to ~80% of total RAM on a dedicated database server
innodb_buffer_pool_size = 48G          # e.g., for 64GB RAM

# Multiple instances reduce mutex contention (1 per GB, max 64)
innodb_buffer_pool_instances = 48

# Dump/load buffer pool on restart for faster warmup
innodb_buffer_pool_dump_at_shutdown = ON
innodb_buffer_pool_load_at_startup = ON
```

### Redo Log

```ini
# Larger redo log reduces checkpoint frequency (trade-off: longer crash recovery)
innodb_log_file_size = 2G
innodb_log_files_in_group = 2          # Removed in 11.4+ (uses single redo log)
innodb_log_buffer_size = 64M
```

### Undo Tablespaces

```ini
# Separate undo from system tablespace for better management
innodb_undo_tablespaces = 2            # 2+ recommended
innodb_undo_log_truncate = ON          # Reclaim undo space automatically
innodb_max_undo_log_size = 1G
```

### Flush Settings

```ini
# For SSDs with battery-backed cache
innodb_flush_method = O_DIRECT         # Avoid double buffering with OS cache
innodb_flush_log_at_trx_commit = 1     # Full ACID (0 or 2 for performance at durability cost)
innodb_doublewrite = ON                # Protect against partial page writes
```

### I/O Capacity

```ini
# Set based on storage IOPS capability
innodb_io_capacity = 2000              # Normal I/O rate (SSD: 2000-10000)
innodb_io_capacity_max = 4000          # Burst I/O rate
innodb_read_io_threads = 4
innodb_write_io_threads = 4
```

## Thread Pool Tuning

```ini
# Enable thread pool
thread_handling = pool-of-threads

# Set to CPU core count
thread_pool_size = 16

# Maximum threads across all groups
thread_pool_max_threads = 512

# Time before a query is considered stalled (ms)
thread_pool_stall_limit = 500

# Priority for high-priority transactions
thread_pool_prio_kickup_timer = 1000
```

**When to use thread pool:**
- Connection count exceeds CPU core count by 10x or more
- Many idle or short-lived connections
- OLTP workloads with many concurrent users

**When NOT to use:**
- Small number of long-running analytical queries
- Fewer connections than CPU cores

## Backup Strategy

### Physical Backup (mariadb-backup)

Preferred for large databases -- fast backup and restore:

```bash
# Full backup
mariadb-backup --backup --target-dir=/backup/full \
  --user=backup_user --password=secret

# Prepare (apply redo log)
mariadb-backup --prepare --target-dir=/backup/full

# Incremental backup
mariadb-backup --backup --target-dir=/backup/inc1 \
  --incremental-basedir=/backup/full \
  --user=backup_user --password=secret

# Prepare incremental
mariadb-backup --prepare --target-dir=/backup/full \
  --incremental-dir=/backup/inc1

# Restore (stop server first, move datadir, copy back)
mariadb-backup --copy-back --target-dir=/backup/full
chown -R mysql:mysql /var/lib/mysql
```

### Logical Backup (mariadb-dump)

For smaller databases or when portability is needed:

```bash
# Full database dump with routines and events
mariadb-dump --all-databases --routines --events --triggers \
  --single-transaction --quick --user=root > full_backup.sql

# Single database
mariadb-dump --single-transaction --quick mydb > mydb_backup.sql

# Restore
mariadb < full_backup.sql
```

**Key flags:**
- `--single-transaction`: Consistent snapshot without locking (InnoDB only)
- `--quick`: Stream rows instead of buffering in memory
- `--routines`: Include stored procedures and functions
- `--events`: Include scheduled events
- `--triggers`: Include triggers (default ON)

### Backup Schedule Recommendation

| Frequency | Type | Retention |
|---|---|---|
| Daily | Full physical (mariadb-backup) | 7 days |
| Hourly | Incremental physical | 24 hours |
| Weekly | Full logical (mariadb-dump) | 4 weeks |
| Continuous | Binary log archival | 14 days |

## Configuration Cleanup on Upgrades

MariaDB removes deprecated variables across versions. Leftover variables in config files cause startup failures.

**Pre-upgrade checklist:**

1. Review release notes for removed variables
2. Run the new binary with `--help --verbose` and check stderr for warnings
3. Remove or comment out deprecated variables
4. Test with `mariadbd --defaults-file=/etc/my.cnf --validate-config` (11.4+)

**Commonly removed variables by version:**

| Version | Removed Variables |
|---|---|
| 11.4 | `innodb_defragment*`, `innodb_version`, `innodb_change_buffering*` |
| 11.8 | Various deprecated compatibility variables |
| 12.x | Legacy MySQL compatibility aliases |

**Safe upgrade process:**
```bash
# 1. Backup configuration
cp /etc/my.cnf /etc/my.cnf.bak

# 2. Test new binary against existing config
mariadbd --defaults-file=/etc/my.cnf --help --verbose 2>&1 | grep -i "warning\|error"

# 3. Fix any issues, then upgrade
mariadb-upgrade --force
```

## Binary Naming Transition

Always use `mariadb*` command names in new scripts and automation:

```bash
# Preferred (new names)
mariadb -u root -p
mariadb-dump --all-databases > backup.sql
mariadb-admin status
mariadb-backup --backup --target-dir=/backup
mariadb-upgrade

# Deprecated (old names, still symlinked)
mysql -u root -p
mysqldump --all-databases > backup.sql
mysqladmin status
```

Update existing scripts, cron jobs, and monitoring configurations to use the new names. The old symlinks may be removed in a future major version.

## Security Best Practices

```ini
# Bind to specific interface (not 0.0.0.0 unless required)
bind-address = 127.0.0.1

# Disable LOCAL INFILE unless needed
local_infile = OFF

# Require SSL for remote connections (11.4+ auto-generates certs)
require_secure_transport = ON

# Enable audit logging
plugin_load_add = server_audit
server_audit_logging = ON
server_audit_events = CONNECT,QUERY_DDL,QUERY_DML
```

```sql
-- Use ed25519 or mysql_native_password authentication
CREATE USER 'app_user'@'10.0.0.%' IDENTIFIED VIA ed25519 USING PASSWORD('strong_password');

-- Grant minimum privileges
GRANT SELECT, INSERT, UPDATE, DELETE ON mydb.* TO 'app_user'@'10.0.0.%';

-- Enable password reuse prevention (10.11+)
INSTALL SONAME 'password_reuse_check';
```

## Galera Cluster Best Practices

```ini
# Minimum Galera configuration
wsrep_on = ON
wsrep_provider = /usr/lib/galera/libgalera_smm.so
wsrep_cluster_address = gcomm://node1,node2,node3
wsrep_cluster_name = my_cluster
wsrep_node_address = 10.0.0.1
wsrep_node_name = node1
wsrep_sst_method = mariabackup
wsrep_sst_auth = sst_user:password

# Performance tuning
wsrep_slave_threads = 4                # Parallel applying; set to 2-4x CPU cores
wsrep_provider_options = "gcache.size=1G; gcs.fc_limit=256"

# Enforce InnoDB and primary keys
innodb_autoinc_lock_mode = 2           # Required for Galera
default_storage_engine = InnoDB
```

**Operational rules:**
- Always use 3 or 5 nodes (odd number for quorum)
- Never write to multiple nodes for the same rows simultaneously
- Prefer single-writer topology for simplicity; use multi-writer only when needed
- Keep all nodes on the same MariaDB version during normal operation
- Size GCache large enough to cover maintenance windows (IST vs SST)
