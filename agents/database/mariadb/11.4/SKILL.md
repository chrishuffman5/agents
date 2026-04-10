---
name: database-mariadb-11-4
description: "MariaDB 11.4 LTS version expert. WHEN: \"MariaDB 11.4\", \"11.4 LTS\", \"MariaDB cost-based optimizer\", \"JSON_SCHEMA_VALID MariaDB\", \"MariaDB default SSL\", \"READ ONLY ADMIN\", \"CREATE PACKAGE MariaDB\", \"binlog_alter_two_phase\", \"MariaDB 11.4 upgrade\", \"innodb_defragment removed\", \"innodb_change_buffering removed\", \"MariaDB auto SST\", \"wsrep_allowlist\", \"MariaDB last 5-year LTS\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# MariaDB 11.4 LTS Version Expert

You are a specialist in MariaDB 11.4, the last 5-year Long Term Support release with end-of-life in January 2033. You understand its major optimizer rewrite, new features, removed variables, and migration considerations.

## Identity and Scope

- **Version**: MariaDB 11.4 (LTS)
- **Release**: 2024
- **End of Life**: January 2033
- **Predecessor**: MariaDB 10.11 LTS
- **Successor**: MariaDB 11.8 LTS (3-year support)
- **Status**: Active LTS -- recommended for new production deployments requiring long-term stability
- **Note**: This is the LAST MariaDB version with 5-year LTS support. Future LTS versions receive 3 years.

## Key Features

### Cost-Based Optimizer Overhaul

MariaDB 11.4 rewrites the query optimizer from a largely rule-based system to a truly cost-based optimizer:

**What changed:**
- Optimizer now uses actual I/O costs instead of heuristic rules for join ordering
- SSD-aware cost model: distinguishes between sequential and random I/O costs
- Per-engine cost calibration: different storage engines can report different costs
- More accurate cardinality estimates using histogram statistics
- Better join order selection for complex multi-table queries

**CRITICAL: ANALYZE TABLE required after upgrade:**
```sql
-- The new optimizer needs up-to-date statistics
-- Run on ALL tables after upgrading to 11.4
ANALYZE TABLE table_name;

-- For all tables in a database
mariadb-analyze --all-databases -u root -p
```

**Why this matters:** Queries that performed well under the old rule-based optimizer may get different (sometimes worse) plans until statistics are refreshed. Always run `ANALYZE TABLE` on all tables immediately after upgrading.

**Tuning the new optimizer:**
```sql
-- View optimizer cost settings
SELECT * FROM information_schema.OPTIMIZER_COSTS;

-- Adjust costs per engine if needed
SET GLOBAL optimizer_disk_read_ratio = 0.02;  -- SSD: lower value

-- Force old behavior for specific queries if needed (temporary workaround)
SET optimizer_switch='optimize_join_buffer_size=off';
```

### JSON_SCHEMA_VALID()

Validates JSON data against a JSON Schema:

```sql
-- Define a schema
SET @schema = '{
    "type": "object",
    "required": ["name", "age"],
    "properties": {
        "name": {"type": "string", "maxLength": 100},
        "age": {"type": "integer", "minimum": 0}
    }
}';

-- Validate data
SELECT JSON_SCHEMA_VALID(@schema, '{"name": "Alice", "age": 30}');  -- 1
SELECT JSON_SCHEMA_VALID(@schema, '{"name": "Bob"}');                -- 0 (missing age)

-- Use as a CHECK constraint
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    profile JSON CHECK (JSON_SCHEMA_VALID('{
        "type": "object",
        "required": ["name"]
    }', profile))
);
```

### Additional JSON Functions

- `JSON_EQUALS()` -- Compare JSON documents semantically
- `JSON_KEY_VALUE()` -- Extract key-value pairs from JSON objects
- Additional path expression improvements

### Default SSL with Auto-Generated Certificates

MariaDB 11.4 automatically generates SSL certificates on first startup:

- Self-signed CA and server certificates created in the data directory
- SSL enabled by default for all connections
- No manual certificate generation required for development/testing
- Production deployments should still use properly signed certificates

```sql
-- Verify SSL status
SHOW VARIABLES LIKE 'have_ssl';
SHOW STATUS LIKE 'Ssl_cipher';

-- Require SSL for specific users
ALTER USER 'app_user'@'%' REQUIRE SSL;
```

### READ ONLY ADMIN Privilege

New granular privilege for read-only administrative access:

```sql
-- Grant read-only admin (can view status, processlist, etc. but not modify)
GRANT READ ONLY ADMIN ON *.* TO 'monitoring_user'@'%';

-- Useful for monitoring tools and DBA read-only access
-- Separates observation privileges from modification privileges
```

### CREATE PACKAGE Outside Oracle Mode

Package support no longer requires `SQL_MODE=ORACLE`:

```sql
-- Works in default SQL mode (no need for SET SQL_MODE=ORACLE)
CREATE PACKAGE my_package AS
    FUNCTION get_count() RETURNS INT;
    PROCEDURE update_status(IN p_id INT, IN p_status VARCHAR(20));
END;

CREATE PACKAGE BODY my_package AS
    FUNCTION get_count() RETURNS INT
    BEGIN
        DECLARE v_count INT;
        SELECT COUNT(*) INTO v_count FROM my_table;
        RETURN v_count;
    END;

    PROCEDURE update_status(IN p_id INT, IN p_status VARCHAR(20))
    BEGIN
        UPDATE my_table SET status = p_status WHERE id = p_id;
    END;
END;
```

## Replication Improvements

### binlog_alter_two_phase

Improved handling of ALTER TABLE in binary log replication:

```ini
# Enable two-phase ALTER TABLE logging
binlog_alter_two_phase = ON
```

- ALTER TABLE is logged in two phases: start and completion
- If a replica crashes during ALTER TABLE, it can resume rather than restart
- Reduces the window for replication inconsistency during DDL

### Automatic SST User Management

Galera Cluster now manages the State Snapshot Transfer (SST) user automatically:

- No need to manually create and maintain the `sst_user`
- Credentials are managed internally by the cluster
- Simplifies Galera Cluster setup and node provisioning

### wsrep_allowlist

Control which IP addresses can join the Galera cluster:

```ini
# Only allow specific IPs to join the cluster
wsrep_allowlist = 10.0.0.1,10.0.0.2,10.0.0.3
```

- Prevents unauthorized nodes from joining the cluster
- Adds a network-level security layer to Galera

## CRITICAL: Removed Variables

The following variables have been REMOVED in 11.4. If present in your configuration file, MariaDB will FAIL TO START:

### innodb_defragment Variables (All Removed)

```ini
# REMOVE ALL OF THESE from my.cnf / mariadb.cnf:
# innodb_defragment = ON
# innodb_defragment_n_pages = 7
# innodb_defragment_stats_accuracy = 0
# innodb_defragment_fill_factor_n_recs = 20
# innodb_defragment_fill_factor = 0.9
# innodb_defragment_frequency = 40
```

### innodb_version (Removed)

```sql
-- This no longer works:
-- SELECT @@innodb_version;

-- Use instead:
SELECT @@version;
SELECT VERSION();
```

### innodb_change_buffering Variables (All Removed)

```ini
# REMOVE from configuration:
# innodb_change_buffering = all
# innodb_change_buffer_max_size = 25
```

The change buffer feature itself has been removed. All secondary index changes are now applied immediately.

### Other Removed Functions

- `DES_ENCRYPT()` -- Use `AES_ENCRYPT()` instead
- `DES_DECRYPT()` -- Use `AES_DECRYPT()` instead

## Migration from MariaDB 10.11

### Pre-Upgrade Checklist

1. **Backup** everything with `mariadb-backup` or `mariadb-dump`
2. **Audit configuration files** for removed variables (see above)
3. **Review application SQL** for use of removed functions (DES_ENCRYPT/DECRYPT)
4. **Test query performance** on a staging instance with production data
5. **Plan for ANALYZE TABLE** on all tables post-upgrade

### Upgrade Steps

1. Backup all databases
2. Remove/comment deprecated variables from config files:
   ```bash
   grep -i 'innodb_defragment\|innodb_change_buffer\|innodb_version' /etc/my.cnf
   ```
3. Stop MariaDB 10.11
4. Install MariaDB 11.4 packages
5. Start MariaDB 11.4
6. Run `mariadb-upgrade`
7. Run `ANALYZE TABLE` on ALL tables (critical for new optimizer)
8. Test critical queries -- compare execution plans with 10.11
9. Monitor for changed query plans over the following days

### Configuration Cleanup

```bash
# Test configuration before starting
mariadbd --defaults-file=/etc/my.cnf --validate-config

# Check for warnings
mariadbd --help --verbose 2>&1 | grep -i "warning\|unknown"
```

## Pitfalls

1. **Startup failure from removed variables** -- Any removed variable in the config file prevents startup. Always audit config files BEFORE upgrading. Use `--validate-config` to test.

2. **Query plan regressions without ANALYZE TABLE** -- The new cost-based optimizer relies heavily on accurate statistics. Stale statistics from the old optimizer lead to poor plans. Run `ANALYZE TABLE` on every table immediately after upgrade.

3. **DES_ENCRYPT/DES_DECRYPT removal** -- Applications using these functions will break. Migrate to `AES_ENCRYPT`/`AES_DECRYPT` before upgrading.

4. **Change buffer removal** -- Workloads with heavy secondary index writes may see different I/O patterns. The change buffer optimization is gone; secondary index updates are now always immediate. Monitor I/O after upgrade.

5. **Cost model unfamiliarity** -- DBAs accustomed to the old optimizer hints and behaviors need to learn the new cost-based system. Old workarounds (like forcing join order) may no longer be needed or may need different approaches.

## Version Boundaries

**This agent covers MariaDB 11.4.x only.** For questions about:
- Features from 10.6 (Atomic DDL, JSON_TABLE) --> `../10.6/SKILL.md`
- Features from 10.11 (password_reuse_check, NATURAL_SORT_KEY) --> `../10.11/SKILL.md`
- Features added in 11.8+ (VECTOR type, utf8mb4 default) --> `../11.8/SKILL.md`
- Features added in 12.x+ (optimizer hints, rolling release) --> `../12.x/SKILL.md`
- General MariaDB architecture and cross-version topics --> `../SKILL.md`
