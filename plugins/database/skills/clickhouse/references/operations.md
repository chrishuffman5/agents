# ClickHouse Operations

## ClickHouse SQL Extensions

ClickHouse extends standard SQL with analytical features:

```sql
-- Array functions
SELECT arrayJoin([1, 2, 3]) AS x;                    -- unnests arrays
SELECT groupArray(name) FROM users;                    -- collects into array
SELECT arrayDistinct(groupArray(tag)) FROM events;     -- distinct array

-- Window functions
SELECT
    user_id,
    event_time,
    runningDifference(event_time) AS time_since_prev
FROM events
ORDER BY user_id, event_time;

-- WITH clause (CTEs)
WITH top_users AS (
    SELECT user_id, count() AS cnt
    FROM events
    GROUP BY user_id
    ORDER BY cnt DESC
    LIMIT 100
)
SELECT e.* FROM events e SEMI JOIN top_users t ON e.user_id = t.user_id;

-- FINAL modifier (forces merge for Replacing/Collapsing engines)
SELECT * FROM replacing_table FINAL WHERE user_id = 42;

-- SAMPLE clause (approximate queries on a fraction of data)
SELECT event_type, count() * 10 AS estimated_count
FROM events SAMPLE 0.1
GROUP BY event_type;

-- Parameterized views
CREATE VIEW events_by_type AS
SELECT * FROM events WHERE event_type = {type:String};

-- FORMAT clause
SELECT * FROM events FORMAT JSONEachRow;
SELECT * FROM events FORMAT CSV;
SELECT * FROM events FORMAT Parquet;
```

## Backup and Restore

ClickHouse provides native backup capabilities:

```sql
-- Native backup to disk
BACKUP TABLE events TO Disk('backups', 'events_backup_20260407.zip');

-- Backup entire database
BACKUP DATABASE analytics TO Disk('backups', 'analytics_20260407.zip');

-- Backup to S3
BACKUP TABLE events TO S3('https://bucket.s3.amazonaws.com/backups/events/', 'access_key', 'secret_key');

-- Restore from backup
RESTORE TABLE events FROM Disk('backups', 'events_backup_20260407.zip');

-- Incremental backup (base_backup parameter)
BACKUP TABLE events TO Disk('backups', 'events_incr_20260407.zip')
SETTINGS base_backup = Disk('backups', 'events_backup_20260401.zip');
```

**Alternative approaches:**
- `clickhouse-copier` for cluster-to-cluster migration
- `ALTER TABLE ... FREEZE PARTITION` for partition-level snapshots (hardlinks to parts)
- `clickhouse-backup` (Altinity open-source tool) for S3/GCS/Azure-compatible automated backups
