# PostgreSQL Best Practices Reference

## postgresql.conf Tuning

### Memory Parameters

```
# Shared buffer cache -- 25% of RAM, rarely exceed 16GB
shared_buffers = 8GB

# Per-operation sort/hash memory -- start at 64MB, tune per query if needed
work_mem = 64MB

# Hint to planner about OS cache -- 75% of total RAM
effective_cache_size = 24GB

# Memory for VACUUM, CREATE INDEX, ALTER TABLE ADD FK
maintenance_work_mem = 2GB

# Temp buffers for temporary tables per session
temp_buffers = 64MB
```

**work_mem warning:** This is allocated per sort/hash operation, not per query. A complex query with 5 sorts uses 5 * work_mem. With 100 concurrent connections, worst case is 100 * 5 * 64MB = 32GB. Monitor `log_temp_files = 0` to see which queries spill to disk, then increase work_mem selectively:

```sql
-- Set per-session for a specific batch job
SET work_mem = '256MB';
-- Or per-transaction
SET LOCAL work_mem = '256MB';
```

### WAL and Checkpoint Parameters

```
# WAL level: 'replica' for streaming, 'logical' for logical replication
wal_level = replica

# Max WAL before triggering checkpoint
max_wal_size = 4GB

# Min WAL to retain (avoids recycling churn)
min_wal_size = 1GB

# Spread checkpoint writes over this fraction of the interval
checkpoint_completion_target = 0.9

# Checkpoint interval (raise to reduce checkpoint frequency)
checkpoint_timeout = 15min

# WAL compression (PG 15+): lz4 or zstd
wal_compression = lz4

# WAL buffers (auto-sized is usually fine)
wal_buffers = -1

# Synchronous commit (trade durability for speed)
synchronous_commit = on       # safest
# synchronous_commit = off    # ~3x faster writes, risk of losing last ~200ms of commits on crash
```

### Connection Parameters

```
# Maximum connections -- keep LOW, use PgBouncer for scaling
max_connections = 100

# Superuser reserved connections
superuser_reserved_connections = 3

# Timeout for idle transactions (prevents long-running transaction bloat)
idle_in_transaction_session_timeout = '10min'

# Statement timeout (prevent runaway queries)
statement_timeout = '60s'     # set per-application; not a global default

# TCP keepalive (detect dead connections)
tcp_keepalives_idle = 60
tcp_keepalives_interval = 10
tcp_keepalives_count = 6
```

### Planner Parameters for SSDs

```
# SSD storage (default 4.0 is for spinning disks)
random_page_cost = 1.1
seq_page_cost = 1.0

# SSD I/O concurrency
effective_io_concurrency = 200
maintenance_io_concurrency = 200
```

### Parallel Query Parameters

```
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_parallel_maintenance_workers = 4
parallel_setup_cost = 1000
parallel_tuple_cost = 0.1
min_parallel_table_scan_size = 8MB
min_parallel_index_scan_size = 512kB
```

### Autovacuum Parameters

```
autovacuum = on
autovacuum_max_workers = 5                    # default 3; increase for many tables
autovacuum_naptime = 15s                      # check interval
autovacuum_vacuum_threshold = 50              # min dead tuples
autovacuum_vacuum_scale_factor = 0.1          # fraction of table (default 0.2)
autovacuum_analyze_threshold = 50
autovacuum_analyze_scale_factor = 0.05
autovacuum_vacuum_cost_delay = 2ms            # throttle delay (lower = faster)
autovacuum_vacuum_cost_limit = 800            # work per round (raise for faster vacuum)

# Anti-wraparound
autovacuum_freeze_max_age = 200000000
vacuum_freeze_min_age = 50000000
vacuum_freeze_table_age = 150000000
```

## pg_hba.conf

### Authentication Configuration

The pg_hba.conf file controls who can connect, from where, and how they authenticate:

```
# TYPE  DATABASE  USER         ADDRESS          METHOD

# Local Unix socket connections
local   all       postgres                      peer
local   all       all                           scram-sha-256

# IPv4 local connections
host    all       all          127.0.0.1/32     scram-sha-256

# Application servers (specific subnet)
host    mydb      appuser      10.0.1.0/24      scram-sha-256

# Replication connections from standby
host    replication  replicator  10.0.2.0/24    scram-sha-256

# Reject everything else
host    all       all          0.0.0.0/0        reject
```

### Authentication Methods (Ranked by Security)

| Method | Security | Use Case |
|---|---|---|
| `scram-sha-256` | High | Default for password auth (PG 10+) |
| `cert` | High | Client certificate authentication |
| `gss` / `sspi` | High | Kerberos / Windows domain auth |
| `ldap` | Medium | LDAP directory authentication |
| `peer` | High (local only) | Unix socket, OS user = PG user |
| `md5` | Low | Legacy password hashing; use scram-sha-256 instead |
| `password` | None | Plaintext password; NEVER use in production |
| `trust` | None | No authentication; NEVER use except local dev |

**Upgrade from md5 to scram-sha-256:**
```sql
-- Set default for new passwords
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
SELECT pg_reload_conf();

-- Reset existing passwords (users must set new passwords)
ALTER USER appuser WITH PASSWORD 'new_secure_password';

-- Then update pg_hba.conf: change md5 to scram-sha-256
```

## Backup Strategies

### pg_dump / pg_dumpall (Logical Backup)

```bash
# Single database (custom format, compressed, parallel)
pg_dump -Fc -j 4 -f mydb.dump mydb

# Restore
pg_restore -d mydb -j 4 mydb.dump

# All databases + globals (roles, tablespaces)
pg_dumpall -f cluster_backup.sql

# Schema only
pg_dump -s -f schema.sql mydb

# Specific tables
pg_dump -t 'public.orders' -t 'public.customers' -Fc -f tables.dump mydb
```

**Limitations:** Logical backups are slow for large databases (> 100GB). No point-in-time recovery. Acquires AccessShareLock (does not block writes but holds back vacuum).

### pg_basebackup (Physical Backup)

```bash
# Full base backup with WAL streaming
pg_basebackup -h primary -U replicator -D /backup/base \
  --wal-method=stream --checkpoint=fast -P --format=tar --gzip

# With replication slot (prevents WAL removal during backup)
pg_basebackup -h primary -U replicator -D /backup/base \
  --wal-method=stream --slot=backup_slot -P
```

### WAL Archiving (Continuous / PITR)

Enable continuous archiving for point-in-time recovery:

```
# postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'cp %p /archive/%f'         # simple local copy
# archive_command = 'aws s3 cp %p s3://wal-archive/%f'  # S3

# Recovery target (in recovery.conf / postgresql.conf PG 12+)
restore_command = 'cp /archive/%f %p'
recovery_target_time = '2025-06-15 14:30:00'
recovery_target_action = 'promote'
```

### pgBackRest (Recommended for Production)

pgBackRest provides full, differential, and incremental backups with parallel compression, encryption, and S3/Azure/GCS support:

```ini
# /etc/pgbackrest/pgbackrest.conf
[global]
repo1-path=/backup/pgbackrest
repo1-retention-full=4
repo1-retention-diff=7
repo1-cipher-type=aes-256-cbc
repo1-cipher-pass=<encryption_key>
compress-type=zst
compress-level=3
process-max=4

[mydb]
pg1-path=/var/lib/postgresql/18/main
```

```bash
# Full backup
pgbackrest --stanza=mydb backup --type=full

# Differential (changes since last full)
pgbackrest --stanza=mydb backup --type=diff

# Incremental (changes since last backup of any type)
pgbackrest --stanza=mydb backup --type=incr

# Point-in-time restore
pgbackrest --stanza=mydb restore \
  --type=time --target='2025-06-15 14:30:00'

# Verify backup integrity
pgbackrest --stanza=mydb verify
```

### Backup Strategy Comparison

| Method | Speed | PITR | Size | Complexity | Best For |
|---|---|---|---|---|---|
| pg_dump | Slow | No | Small (compressed) | Low | < 50GB, schema migrations |
| pg_basebackup | Medium | With WAL archiving | Full cluster size | Medium | Simple PITR setups |
| pgBackRest | Fast | Yes | Incremental/differential | Medium | Production, > 100GB |
| Barman | Fast | Yes | Incremental | Medium | Alternative to pgBackRest |

### Backup Verification

**Never trust an untested backup.** Regularly restore to a test environment:

```bash
# Test restore to a separate instance
pg_restore -d test_restore -j 4 mydb.dump

# Verify row counts match
psql -d test_restore -c "SELECT count(*) FROM critical_table;"

# For pgBackRest, use the verify command
pgbackrest --stanza=mydb verify
```

## Vacuum Tuning

### Monitoring Vacuum Health

```sql
-- Tables needing vacuum (most dead tuples)
SELECT schemaname, relname,
       n_dead_tup, n_live_tup,
       round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
       last_autovacuum, last_vacuum,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 20;

-- Autovacuum currently running
SELECT pid, relid::regclass AS table_name,
       phase, heap_blks_total, heap_blks_scanned, heap_blks_vacuumed,
       index_vacuum_count, max_dead_tuples
FROM pg_stat_progress_vacuum;
```

### Per-Table Vacuum Tuning

For large, write-heavy tables, set aggressive per-table parameters:

```sql
-- 100M+ row table with high update rate
ALTER TABLE large_events SET (
    autovacuum_vacuum_scale_factor = 0.01,     -- vacuum at 1% dead tuples
    autovacuum_vacuum_threshold = 10000,
    autovacuum_analyze_scale_factor = 0.005,
    autovacuum_vacuum_cost_delay = 0            -- no throttling for this table
);
```

### Bloat Detection

```sql
-- Estimate table bloat (simplified)
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size,
       pg_size_pretty(
           pg_total_relation_size(schemaname || '.' || tablename) -
           pg_relation_size(schemaname || '.' || tablename)
       ) AS toast_and_index_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC
LIMIT 20;
```

For precise bloat estimation, use the `pgstattuple` extension:
```sql
CREATE EXTENSION pgstattuple;
SELECT * FROM pgstattuple('my_table');
-- dead_tuple_percent > 20% indicates significant bloat
```

### Bloat Remediation

| Approach | Downtime | Lock | When to Use |
|---|---|---|---|
| Regular VACUUM | None | ShareUpdateExclusiveLock (minimal) | Routine maintenance |
| VACUUM FULL | Yes | AccessExclusiveLock | Last resort, small tables |
| pg_repack | None | Brief AccessExclusiveLock at end | Online bloat removal |
| CLUSTER | Yes | AccessExclusiveLock | Physically reorder by index |

```bash
# pg_repack -- online table repack
pg_repack -d mydb -t bloated_table --no-superuser-check
```

## Security Hardening

### Connection Security

```
# postgresql.conf
listen_addresses = '10.0.1.5'       # bind to specific interface, NOT '*'
port = 5432
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'
ssl_ca_file = '/etc/ssl/certs/ca.crt'
ssl_min_protocol_version = 'TLSv1.3'

# pg_hba.conf -- require SSL for remote connections
hostssl  all  all  0.0.0.0/0  scram-sha-256
```

### Role Management

```sql
-- Application role (least privilege)
CREATE ROLE app_readonly LOGIN PASSWORD 'strong_password';
GRANT CONNECT ON DATABASE mydb TO app_readonly;
GRANT USAGE ON SCHEMA public TO app_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_readonly;

-- Application read-write role
CREATE ROLE app_readwrite LOGIN PASSWORD 'strong_password';
GRANT CONNECT ON DATABASE mydb TO app_readwrite;
GRANT USAGE ON SCHEMA public TO app_readwrite;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_readwrite;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_readwrite;

-- Separate admin role (never use superuser for applications)
CREATE ROLE app_admin LOGIN PASSWORD 'strong_password' CREATEROLE;

-- Row-Level Security (RLS)
ALTER TABLE tenant_data ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON tenant_data
    USING (tenant_id = current_setting('app.tenant_id')::int);
```

### Auditing

```sql
-- pg_audit extension for compliance
CREATE EXTENSION pgaudit;

-- postgresql.conf
-- pgaudit.log = 'ddl, role, write'
-- pgaudit.log_catalog = off
-- pgaudit.log_relation = on
```

### Password Policy

```
# postgresql.conf
password_encryption = 'scram-sha-256'

# Connection rate limiting (via pg_hba.conf + fail2ban or pgbouncer)
# PostgreSQL has no built-in password policy; enforce at application/LDAP level

# Password expiration
ALTER ROLE appuser VALID UNTIL '2026-01-01';
```

### File and OS Security

```bash
# File permissions (standard PostgreSQL installation)
chmod 700 /var/lib/postgresql/18/main
chown postgres:postgres /var/lib/postgresql/18/main

# pg_hba.conf should not be world-readable
chmod 600 /etc/postgresql/18/main/pg_hba.conf

# Disable core dumps (prevent credential exposure)
# /etc/security/limits.conf
# postgres  hard  core  0

# Restrict pg_read_server_files, pg_write_server_files, pg_execute_server_program
# Never grant these to application roles
```
