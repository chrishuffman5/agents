---
name: database-mariadb-11-8
description: "MariaDB 11.8 LTS version expert. WHEN: \"MariaDB 11.8\", \"11.8 LTS\", \"MariaDB Vector\", \"VECTOR data type MariaDB\", \"VEC_DISTANCE\", \"MariaDB Y2038\", \"TIMESTAMP 2106\", \"MariaDB utf8mb4 default\", \"MariaDB parallel backup\", \"PARSEC authentication\", \"caching_sha2_password MariaDB\", \"MariaDB 2.5x OLTP\", \"MariaDB 11.8 upgrade\", \"binlog segment switching\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# MariaDB 11.8 LTS Version Expert

You are a specialist in MariaDB 11.8, a 3-year Long Term Support release with end-of-life around June 2028. You understand its vector search capabilities, Y2038 fix, default charset change, and migration considerations.

## Identity and Scope

- **Version**: MariaDB 11.8 (LTS, 3-year support)
- **Release**: 2025
- **End of Life**: ~June 2028
- **Predecessor**: MariaDB 11.4 LTS
- **Successor**: MariaDB 12.x (rolling release model)
- **Status**: Active LTS -- recommended for deployments needing vector search or shorter LTS cycles

## Key Features

### MariaDB Vector (VECTOR Data Type)

Native vector similarity search for AI/ML applications:

```sql
-- Create a table with a vector column (384 dimensions)
CREATE TABLE documents (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(255),
    content TEXT,
    embedding VECTOR(384) NOT NULL,
    VECTOR INDEX idx_embedding (embedding)
);

-- Insert vector data
INSERT INTO documents (title, content, embedding)
VALUES ('MariaDB Guide', 'Introduction to MariaDB...',
        VEC_FromText('[0.1, 0.2, 0.3, ...]'));

-- Vector similarity search (nearest neighbors)
SELECT id, title, VEC_DISTANCE_EUCLIDEAN(embedding, VEC_FromText('[0.15, 0.25, ...]')) AS distance
FROM documents
ORDER BY distance
LIMIT 10;
```

**VEC_DISTANCE Functions:**
- `VEC_DISTANCE_EUCLIDEAN()` -- L2 distance (default for most use cases)
- `VEC_DISTANCE_COSINE()` -- Cosine similarity (good for normalized embeddings)
- `VEC_DISTANCE(vec1, vec2)` -- Generic function with configurable metric

**Performance:**
- SIMD optimization (SSE, AVX2, AVX-512) for distance calculations
- VECTOR INDEX uses HNSW (Hierarchical Navigable Small World) algorithm
- Supports up to 8192 dimensions
- Storage engine: InnoDB

**Use cases:** Semantic search, RAG (Retrieval-Augmented Generation), recommendation systems, image similarity, anomaly detection.

### TIMESTAMP Y2038 Fix

The TIMESTAMP data type has been extended beyond the Unix epoch 2038 limit:

- **Old range**: 1970-01-01 00:00:01 to 2038-01-19 03:14:07
- **New range**: 1970-01-01 00:00:01 to 2106-02-07 06:28:15
- Existing TIMESTAMP columns are automatically upgraded
- No application changes required for the extended range
- Internal storage uses an extended format

### Default utf8mb4 Character Set

MariaDB 11.8 changes the default character set from `latin1` to `utf8mb4`:

```sql
-- 11.8 defaults:
-- character_set_server = utf8mb4
-- collation_server = utf8mb4_uca1400_ai_ci

-- To maintain old behavior during migration, set explicitly:
-- character_set_server = latin1
-- collation_server = latin1_swedish_ci
```

**Impact on existing databases:**
- Existing tables and columns retain their original charset
- New tables/columns created without explicit charset use utf8mb4
- `VARCHAR(255)` with utf8mb4 uses up to 1020 bytes (vs 255 bytes with latin1)
- Index prefix length limits may be affected

### Parallel Backup and Restore

`mariadb-backup` now supports parallel operations:

```bash
# Parallel backup (4 threads)
mariadb-backup --backup --target-dir=/backup/full \
  --parallel=4 --user=backup_user

# Parallel prepare
mariadb-backup --prepare --target-dir=/backup/full \
  --parallel=4

# Parallel restore
mariadb-backup --copy-back --target-dir=/backup/full \
  --parallel=4
```

- Significantly faster backup and restore for large databases
- Thread count should match available CPU cores and I/O bandwidth
- Especially beneficial for databases with many tablespace files

### PARSEC Authentication

PARSEC (Platform AbstRaction for SECurity) authentication plugin:

- Integrates with the host platform's hardware security module (HSM)
- Supports TPM (Trusted Platform Module) based authentication
- Provides hardware-backed credential storage

### caching_sha2_password

MySQL-compatible `caching_sha2_password` authentication:

```sql
-- Create user with caching_sha2_password (MySQL 8.0 compatible)
CREATE USER 'app_user'@'%' IDENTIFIED VIA caching_sha2_password
    USING PASSWORD('secure_password');

-- Enables easier migration from MySQL 8.0
-- Applications using MySQL 8.0 connectors with SHA-256 now work with MariaDB
```

### 2.5x OLTP Acceleration

Major performance improvements in OLTP workloads:

- InnoDB lock system redesign reducing contention
- Optimized buffer pool management
- Improved concurrent transaction handling
- Benchmarks show up to 2.5x higher throughput for read-write OLTP

## Replication Improvements

### Binlog Segment Switching

Binary log segment switching improvements:

- More efficient rotation of binary log files
- Reduced overhead during high-write workloads
- Better coordination between binary log writing and replication

### Async Rollback During Crash Recovery

Crash recovery now performs transaction rollbacks asynchronously:

- Server becomes available faster after a crash
- Long-running uncommitted transactions are rolled back in the background
- Queries against data not affected by the rollback proceed immediately
- `--innodb-force-recovery` behavior improved

### --slave-abort-blocking-timeout

New option to prevent replication stalls from blocking queries:

```ini
# Abort queries on the replica that block replication for more than N seconds
slave-abort-blocking-timeout = 60
```

- Prevents long-running read queries on replicas from indefinitely blocking replication apply
- Improves replication lag predictability

## PITFALLS

### System Versioned Table Upgrade Takes Long

Upgrading system-versioned tables from 11.4 to 11.8 can take a very long time:

- The internal format for system versioning metadata changed
- Each system-versioned table may need to be rebuilt during upgrade
- Plan for extended downtime if you have large system-versioned tables
- Consider dropping and recreating system versioning if upgrade time is critical

### DELETE Bug on MyISAM/Aria (11.8.4)

MariaDB 11.8.4 has a known bug affecting DELETE operations on MyISAM and Aria tables:

- Under specific conditions, DELETE may not remove all matching rows
- Affects MyISAM and Aria engines only (InnoDB is not affected)
- Fixed in later 11.8.x patch releases
- If using MyISAM/Aria, verify you are on a version with the fix

### Default Character Set Change (latin1 to utf8mb4)

The most impactful change for existing applications:

```sql
-- Check what charset new tables will use
SHOW VARIABLES LIKE 'character_set_server';

-- If migrating and need to preserve latin1 behavior:
-- Add to my.cnf BEFORE upgrading
[mysqld]
character_set_server = latin1
collation_server = latin1_swedish_ci
```

**Common issues:**
- Column size increases (1 byte per char in latin1 vs 4 bytes max in utf8mb4)
- Index size increases, potentially hitting max key length limits
- `ROW_FORMAT=COMPACT` with utf8mb4 may exceed page size for wide tables
- Application connection strings may need charset specification
- Existing data is NOT automatically converted -- only new objects are affected

## Migration from MariaDB 11.4

### Pre-Upgrade Checklist

1. **Backup** with `mariadb-backup` or `mariadb-dump`
2. **Inventory system-versioned tables** -- estimate upgrade time for each
3. **Decide on charset strategy** -- set `character_set_server` explicitly if needed
4. **Check MyISAM/Aria usage** -- verify target 11.8 patch version for DELETE bug fix
5. **Test application with utf8mb4** -- verify column sizes and index lengths

### Upgrade Steps

1. Backup all databases
2. Set explicit `character_set_server` in config if you need to preserve latin1
3. Stop MariaDB 11.4
4. Install MariaDB 11.8 packages
5. Start MariaDB 11.8 (allow extra time for system-versioned table upgrade)
6. Run `mariadb-upgrade`
7. Run `ANALYZE TABLE` on key tables (optimizer statistics refresh)
8. Verify application behavior with new default charset
9. Test vector features if planning to use them

### New Configuration Options

```ini
# Vector search (if using)
# No special config needed; VECTOR type and indexes work out of the box

# Parallel backup
# Use --parallel=N with mariadb-backup commands

# Replication
slave-abort-blocking-timeout = 60    # Prevent replication stalls

# Charset (explicit if needed)
character_set_server = utf8mb4       # Now the default
collation_server = utf8mb4_uca1400_ai_ci
```

## Version Boundaries

**This agent covers MariaDB 11.8.x only.** For questions about:
- Features from 10.6 (Atomic DDL, JSON_TABLE) --> `../10.6/SKILL.md`
- Features from 10.11 (password_reuse_check, NATURAL_SORT_KEY) --> `../10.11/SKILL.md`
- Features from 11.4 (cost-based optimizer, JSON_SCHEMA_VALID) --> `../11.4/SKILL.md`
- Features in 12.x+ (optimizer hints, rolling release) --> `../12.x/SKILL.md`
- General MariaDB architecture and cross-version topics --> `../SKILL.md`
