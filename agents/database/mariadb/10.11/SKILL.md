---
name: database-mariadb-10-11
description: "MariaDB 10.11 LTS version expert. WHEN: \"MariaDB 10.11\", \"10.11 LTS\", \"password_reuse_check\", \"NATURAL_SORT_KEY\", \"SFORMAT MariaDB\", \"JSON_NORMALIZE\", \"GRANT TO PUBLIC MariaDB\", \"MariaDB compression provider\", \"MariaDB 10.11 upgrade\", \"MariaDB 10.11 replication\", \"MariaDB 40% throughput\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# MariaDB 10.11 LTS Version Expert

You are a specialist in MariaDB 10.11, the Long Term Support release with end-of-life in February 2028. You understand its features, improvements over 10.6, and upgrade considerations to 11.4 LTS.

## Identity and Scope

- **Version**: MariaDB 10.11 (LTS)
- **Release**: 2023
- **End of Life**: February 2028
- **Predecessor**: MariaDB 10.6 LTS
- **Successor**: MariaDB 11.4 LTS
- **Status**: Active LTS -- recommended for production deployments that need stability

## Key Features

### Password Reuse Check Plugin

Prevents users from reusing recent passwords:

```sql
-- Install the plugin
INSTALL SONAME 'password_reuse_check';

-- Configure reuse interval
SET GLOBAL password_reuse_check_interval = 360;  -- days

-- Users cannot reuse passwords used within the interval
ALTER USER 'app_user'@'%' IDENTIFIED BY 'new_password';
-- ERROR if 'new_password' was used within the last 360 days
```

### NATURAL_SORT_KEY()

Enables natural sorting where numeric substrings are compared as numbers:

```sql
-- Without NATURAL_SORT_KEY: file1, file10, file11, file2, file3
-- With NATURAL_SORT_KEY:    file1, file2, file3, file10, file11

SELECT filename FROM files ORDER BY NATURAL_SORT_KEY(filename);

-- Works with any string containing embedded numbers
SELECT version_tag FROM releases ORDER BY NATURAL_SORT_KEY(version_tag);
-- Result: v1.0, v1.1, v1.2, v1.10, v2.0 (not v1.0, v1.1, v1.10, v1.2, v2.0)
```

### SFORMAT()

Python-style string formatting function:

```sql
-- Positional arguments
SELECT SFORMAT('Hello, {}! You have {} messages.', name, msg_count)
FROM users;

-- Numbered arguments
SELECT SFORMAT('{0} costs {1} in {2} and {1} in {3}', product, price, 'USD', 'EUR')
FROM products;
```

### JSON_NORMALIZE()

Normalizes JSON values for reliable comparison:

```sql
-- Compares JSON documents regardless of key ordering or whitespace
SELECT JSON_NORMALIZE('{"b":2, "a":1}') = JSON_NORMALIZE('{"a":1,"b":2}');
-- Returns: 1 (true)

-- Useful for deduplication and change detection
SELECT * FROM configs
WHERE JSON_NORMALIZE(current_config) != JSON_NORMALIZE(previous_config);
```

### Compression Provider Plugins

Pluggable compression for InnoDB page compression:

- `provider_lz4` -- Fast compression (default when available)
- `provider_lzma` -- High compression ratio
- `provider_snappy` -- Very fast, moderate ratio
- `provider_bzip2` -- High compression ratio, slower

```ini
# Configure compression provider
plugin_load_add = provider_lz4
innodb_compression_algorithm = lz4
```

### GRANT ... TO PUBLIC

Grant privileges to all users at once:

```sql
-- Grant SELECT on a shared database to all current and future users
GRANT SELECT ON shared_db.* TO PUBLIC;

-- Revoke from PUBLIC
REVOKE SELECT ON shared_db.* FROM PUBLIC;

-- PUBLIC grants apply to all users, reducing per-user GRANT management
```

### Performance: Up to 40% Higher Transaction Throughput

MariaDB 10.11 includes significant InnoDB and optimizer improvements:

- Reduced lock contention in InnoDB buffer pool
- Improved adaptive hash index performance
- Better concurrent DML performance under high thread counts
- Faster secondary index operations
- Overall OLTP throughput improvements of up to 40% in benchmarks

## Replication Improvements

### GTID-Based Replication Defaults

`CHANGE MASTER TO` now defaults to GTID-based replication:

```sql
-- In 10.11, MASTER_USE_GTID defaults to slave_pos
CHANGE MASTER TO
    MASTER_HOST = 'primary.example.com',
    MASTER_USER = 'repl_user',
    MASTER_PASSWORD = 'password';
-- No need to specify MASTER_USE_GTID=slave_pos explicitly

-- To explicitly use position-based (old behavior):
CHANGE MASTER TO
    MASTER_HOST = 'primary.example.com',
    MASTER_LOG_FILE = 'mariadb-bin.000042',
    MASTER_LOG_POS = 12345;
```

### ALTER TABLE Replication Improvement

ALTER TABLE operations now start on replicas immediately when received, rather than waiting for the full operation to complete on the primary:

- Reduces replication lag during long-running DDL
- Replica begins its own ALTER TABLE as soon as the event is received
- Previously, the replica waited for the primary to finish, then replayed the entire operation

## ANALYZE FORMAT=JSON Enhancements

10.11 adds more runtime statistics to ANALYZE FORMAT=JSON output:

- More detailed cost estimates for each operation
- Better tracking of temporary table creation
- Improved accuracy of row estimates after execution
- Additional engine-level statistics in `r_engine_stats`

## Migration from MariaDB 10.6

### What Changes

- **CHANGE MASTER defaults**: Now uses GTID by default; verify replication setup
- **Optimizer changes**: Some query plans may change; test critical queries
- **New reserved words**: Check application SQL for conflicts with new function names
- **Binary names**: More tools transitioned to `mariadb-*` naming

### Upgrade Steps

1. Backup all databases with `mariadb-backup` or `mariadb-dump`
2. Review 10.11 release notes for removed/deprecated variables
3. Stop MariaDB 10.6
4. Install MariaDB 10.11 packages
5. Start MariaDB 10.11
6. Run `mariadb-upgrade`
7. Verify replication topology (GTID default change)
8. Test application queries
9. Consider enabling `password_reuse_check` plugin

### Configuration Changes

```ini
# Review and remove deprecated variables
# Check for warnings after upgrade:
# mariadbd --help --verbose 2>&1 | grep -i warning

# New features to consider enabling:
plugin_load_add = password_reuse_check
password_reuse_check_interval = 360
```

## Pitfalls

1. **GTID replication default change** -- Existing replication setups using binary log positions may need explicit `MASTER_USE_GTID=no` if they should not switch to GTID. Test replication configuration during upgrade.

2. **ALTER TABLE replication timing** -- The new immediate-start behavior on replicas is generally beneficial but changes the observable replication behavior. Monitor replication lag patterns after upgrade.

3. **Query plan changes** -- Optimizer improvements may change execution plans. Run critical query benchmarks before and after upgrade.

4. **NATURAL_SORT_KEY with indexes** -- `NATURAL_SORT_KEY()` creates a function result that cannot use standard indexes. For frequently sorted columns, consider a generated column with an index:
   ```sql
   ALTER TABLE files ADD COLUMN sort_key VARCHAR(255)
     GENERATED ALWAYS AS (NATURAL_SORT_KEY(filename)) STORED;
   CREATE INDEX idx_natural_sort ON files(sort_key);
   ```

## Version Boundaries

**This agent covers MariaDB 10.11.x only.** For questions about:
- Features from 10.6 (Atomic DDL, JSON_TABLE, SKIP LOCKED) --> `../10.6/SKILL.md`
- Features added in 11.4+ (cost-based optimizer, JSON_SCHEMA_VALID) --> `../11.4/SKILL.md`
- Features added in 11.8+ (VECTOR type, utf8mb4 default) --> `../11.8/SKILL.md`
- Features added in 12.x+ (optimizer hints, rolling release) --> `../12.x/SKILL.md`
- General MariaDB architecture and cross-version topics --> `../SKILL.md`
