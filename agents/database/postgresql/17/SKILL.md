---
name: database-postgresql-17
description: "PostgreSQL 17 version-specific expert. Deep knowledge of incremental backup, JSON_TABLE, MERGE RETURNING, COPY ON_ERROR, failover slots, MAINTAIN privilege, pg_wait_events, and improved VACUUM memory management. WHEN: \"PostgreSQL 17\", \"Postgres 17\", \"PG 17\", \"pg17\", \"incremental backup\", \"pg_combinebackup\", \"JSON_TABLE\", \"MERGE RETURNING\", \"COPY ON_ERROR\", \"failover slot\", \"MAINTAIN privilege\", \"pg_wait_events\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# PostgreSQL 17 Expert

You are a specialist in PostgreSQL 17, released September 2024. You have deep knowledge of the features introduced in this version, particularly incremental backup support, full JSON_TABLE, MERGE improvements, and operational enhancements.

**Support status:** Actively supported with security and bug fix updates. EOL November 2029.

## Key Features Introduced in PostgreSQL 17

### Incremental Backup (pg_combinebackup)

PostgreSQL 17 introduces built-in incremental backup, reducing backup time and storage for large databases:

```bash
# Take a full base backup (with WAL summarization enabled)
pg_basebackup -D /backup/full --checkpoint=fast -P

# Later: take an incremental backup (only changed blocks)
pg_basebackup -D /backup/incr1 --incremental /backup/full/backup_manifest -P

# Chain incremental backups
pg_basebackup -D /backup/incr2 --incremental /backup/incr1/backup_manifest -P

# Combine full + incrementals into a restorable backup
pg_combinebackup /backup/full /backup/incr1 /backup/incr2 -o /backup/combined

# Restore from the combined backup
cp -r /backup/combined /var/lib/postgresql/17/main
```

**Prerequisites:**
```
# postgresql.conf -- must be set BEFORE the full backup
summarize_wal = on                  # enables WAL summarization
wal_level = replica                 # minimum for base backups
```

**How it works:**
- WAL summarizer process tracks which blocks changed since the last backup
- `pg_basebackup --incremental` sends only modified blocks
- `pg_combinebackup` reconstructs a full backup from the chain
- Block-level granularity (not file-level), so even large tables with few changes result in small incremental backups

**Backup size comparison (example: 500GB database, 5% daily change):**
| Backup Type | Size | Time |
|---|---|---|
| Full (pg_basebackup) | ~500GB | ~60min |
| Incremental | ~25GB | ~5min |
| Combined (full + 7 incrementals) | ~500GB | ~10min to combine |

### JSON_TABLE (Full Support)

PostgreSQL 17 delivers full SQL-standard JSON_TABLE, allowing JSON data to be queried as relational rows and columns:

```sql
-- Basic JSON_TABLE: extract fields from JSON array
SELECT jt.*
FROM orders,
     JSON_TABLE(
         order_data, '$.items[*]'
         COLUMNS (
             item_id     int          PATH '$.id',
             product     text         PATH '$.name',
             quantity    int          PATH '$.qty',
             unit_price  numeric(10,2) PATH '$.price',
             in_stock    boolean      PATH '$.available'
                         DEFAULT true ON EMPTY
         )
     ) AS jt;

-- Nested JSON_TABLE with NESTED PATH
SELECT jt.*
FROM api_responses,
     JSON_TABLE(
         response_body, '$.data[*]'
         COLUMNS (
             user_id   int   PATH '$.id',
             username  text  PATH '$.name',
             NESTED PATH '$.addresses[*]' COLUMNS (
                 addr_type  text  PATH '$.type',
                 city       text  PATH '$.city',
                 zip        text  PATH '$.zip'
             )
         )
     ) AS jt;

-- Error handling
SELECT jt.*
FROM documents,
     JSON_TABLE(
         content, '$.records[*]'
         COLUMNS (
             id    int   PATH '$.id',
             value text  PATH '$.value'
                   NULL ON ERROR   -- return NULL if path is invalid
                   NULL ON EMPTY   -- return NULL if path doesn't exist
         )
     ) AS jt;
```

**JSON_TABLE vs lateral jsonb_array_elements:**
| Feature | JSON_TABLE | jsonb_array_elements + ->> |
|---|---|---|
| SQL standard | Yes | PostgreSQL-specific |
| Nested arrays | NESTED PATH syntax | Multiple lateral joins |
| Type casting | PATH + column type | Manual casts |
| Error handling | ON ERROR / ON EMPTY clauses | COALESCE / try-catch |
| Readability | High | Low for complex JSON |

### MERGE Improvements (RETURNING Clause)

The MERGE command (introduced in PG 15) now supports RETURNING:

```sql
-- MERGE with RETURNING: get affected rows
MERGE INTO inventory AS target
USING incoming AS source
ON target.product_id = source.product_id
WHEN MATCHED THEN
    UPDATE SET quantity = target.quantity + source.quantity
WHEN NOT MATCHED THEN
    INSERT (product_id, quantity)
    VALUES (source.product_id, source.quantity)
RETURNING merge_action(), target.*;

-- merge_action() returns 'INSERT', 'UPDATE', or 'DELETE'
-- Useful for audit logging
MERGE INTO accounts AS a
USING changes AS c
ON a.id = c.id
WHEN MATCHED AND c.action = 'close' THEN
    DELETE
WHEN MATCHED THEN
    UPDATE SET balance = c.new_balance
WHEN NOT MATCHED THEN
    INSERT (id, balance) VALUES (c.id, c.new_balance)
RETURNING merge_action() AS action, a.id, a.balance;
```

### COPY ON_ERROR Option

COPY FROM can now skip rows with errors instead of aborting:

```sql
-- Skip malformed rows during import
COPY large_import FROM '/data/messy_data.csv'
WITH (FORMAT csv, HEADER true, ON_ERROR stop);
-- ON_ERROR options:
-- 'stop' (default): abort on first error
-- 'ignore': skip the row with the error and continue

-- Example with ignore
COPY events FROM '/data/events.csv'
WITH (FORMAT csv, ON_ERROR ignore);
-- Check how many rows were skipped via NOTICE messages
```

**Use case:** Importing data from external sources where some rows may have type mismatches, encoding issues, or constraint violations. Previously required preprocessing or staging tables.

### Failover Slots for Logical Replication

Logical replication slots can now survive failover to a standby:

```
# postgresql.conf on primary
wal_level = logical
sync_replication_slots = on     # synchronize slot positions to standby

# postgresql.conf on standby
hot_standby_feedback = on
primary_slot_name = 'physical_slot'
```

When the standby is promoted, logical replication subscribers can reconnect to the new primary without losing data. Previously, logical replication slots existed only on the primary and were lost during failover.

### Improved VACUUM Memory Management

PostgreSQL 17 makes VACUUM more memory-efficient:

- **TID store optimization:** VACUUM now uses a radix tree (TID store) instead of a flat array for tracking dead tuple IDs. This reduces memory consumption for VACUUM on large tables by up to 20x.
- **maintenance_work_mem efficiency:** The same `maintenance_work_mem` budget now allows VACUUM to process more dead tuples per pass, reducing the number of index scans needed.

```sql
-- Monitor VACUUM memory usage (PG 17)
SELECT pid, relid::regclass, phase,
       heap_blks_total, heap_blks_scanned,
       max_dead_tuples, num_dead_tuples
FROM pg_stat_progress_vacuum;
```

### pg_wait_events View

A new view listing all possible wait events with descriptions:

```sql
-- List all wait events
SELECT type, name, description
FROM pg_wait_events
ORDER BY type, name;

-- Correlate with active sessions
SELECT a.pid, a.wait_event_type, a.wait_event, w.description
FROM pg_stat_activity a
LEFT JOIN pg_wait_events w
    ON a.wait_event_type = w.type AND a.wait_event = w.name
WHERE a.state = 'active' AND a.wait_event IS NOT NULL;
```

### MAINTAIN Privilege

A new privilege that grants VACUUM, ANALYZE, REINDEX, REFRESH MATERIALIZED VIEW, CLUSTER, and LOCK TABLE without requiring table ownership:

```sql
-- Grant maintenance privileges to a monitoring role
GRANT MAINTAIN ON ALL TABLES IN SCHEMA public TO maintenance_role;

-- Grant on specific table
GRANT MAINTAIN ON TABLE large_events TO maintenance_role;

-- Now the role can vacuum without owning the table
SET ROLE maintenance_role;
VACUUM ANALYZE large_events;
```

### Identity Columns in Partitioned Tables

PostgreSQL 17 allows identity columns (GENERATED ALWAYS AS IDENTITY) on partitioned tables:

```sql
-- Previously not allowed; now works in PG 17
CREATE TABLE events (
    id bigint GENERATED ALWAYS AS IDENTITY,
    event_type text NOT NULL,
    created_at timestamptz NOT NULL
) PARTITION BY RANGE (created_at);

CREATE TABLE events_2025_q1 PARTITION OF events
    FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');
```

### Other Notable Features

- **Event triggers for login:** `login` event trigger fires on successful authentication
- **pg_stat_checkpointer:** Extracted from pg_stat_bgwriter as a separate view
- **Improved EXPLAIN output:** Better cost estimation display
- **GRANT SET/ALTER SYSTEM for GUC parameters:** Fine-grained control over who can change settings
- **Subscriptions with two_phase commit:** Enhanced two-phase commit support for logical replication

## Version Boundaries

- **Not available in PG 17:** Virtual generated columns (PG 18), UUIDv7 (PG 18), async I/O (PG 18), skip scan (PG 18), OAuth authentication (PG 18), temporal constraints (PG 18), OLD/NEW RETURNING (PG 18)
- **New in PG 17 vs PG 16:** Incremental backup, JSON_TABLE full, MERGE RETURNING, COPY ON_ERROR, failover slots, TID store VACUUM, pg_wait_events, MAINTAIN privilege, identity columns in partitioned tables
- **No major breaking changes from PG 16**

## Common Pitfalls

1. **Incremental backup requires summarize_wal** -- Must be enabled BEFORE the full backup. If you enable it after, the first incremental will fail because there is no WAL summary covering the full backup period.

2. **pg_combinebackup output is not incremental-ready** -- The combined output is a full backup but does NOT have a backup_manifest suitable for further incrementals. Take a new full backup to restart the chain.

3. **COPY ON_ERROR ignore silently drops rows** -- Monitor NOTICE messages or compare row counts after import. Silently dropped rows can cause data integrity issues if not tracked.

4. **Failover slots require sync_replication_slots** -- Without this setting on the primary, slot positions are not replicated to the standby and will be lost on failover.

5. **MAINTAIN privilege does not include TRUNCATE** -- MAINTAIN covers VACUUM, ANALYZE, REINDEX, REFRESH MATERIALIZED VIEW, CLUSTER, and LOCK, but not TRUNCATE or DROP. TRUNCATE still requires the TRUNCATE privilege.

## Migration Notes

### Upgrading from PostgreSQL 16 to 17

Pre-upgrade checklist:
1. **Plan incremental backup adoption** -- Enable `summarize_wal = on` after upgrade and take a full backup to start the incremental chain.
2. **Evaluate JSON_TABLE adoption** -- Replace complex `jsonb_array_elements` + lateral join patterns with JSON_TABLE.
3. **Consider MAINTAIN privilege** -- Set up dedicated maintenance roles instead of using table owners for VACUUM/ANALYZE.
4. **Update MERGE statements** -- Add RETURNING clauses where audit logging or result tracking is needed.

### Upgrading from PostgreSQL 17 to 18+

- Plan for virtual generated columns (PG 18) as replacement for stored generated columns where appropriate
- UUIDv7 (PG 18) provides better index performance than UUIDv4 for primary keys
- Async I/O (PG 18) may require `io_method` configuration

## Reference Files

For deep technical details, load the parent technology agent's references:

- `../references/architecture.md` -- Process architecture, shared memory, WAL internals
- `../references/diagnostics.md` -- pg_stat views, EXPLAIN ANALYZE, lock analysis
- `../references/best-practices.md` -- Configuration tuning, backup, security
