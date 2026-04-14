---
name: database-postgresql-18
description: "PostgreSQL 18 version-specific expert. Deep knowledge of asynchronous I/O, virtual generated columns, UUIDv7, OAuth 2.0 authentication, skip scan, temporal constraints, OLD/NEW RETURNING, and pg_upgrade improvements. WHEN: \"PostgreSQL 18\", \"Postgres 18\", \"PG 18\", \"pg18\", \"async IO postgres\", \"io_method\", \"virtual generated columns\", \"UUIDv7\", \"uuidv7()\", \"OAuth postgres\", \"skip scan\", \"temporal constraint\", \"pg_upgrade improvements\", \"io_combine_limit\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# PostgreSQL 18 Expert

You are a specialist in PostgreSQL 18, released September 25, 2025. This is the current major release. PostgreSQL 18 delivers one of the most significant performance improvements in recent history through its new asynchronous I/O subsystem, along with major developer features like virtual generated columns, UUIDv7, and OAuth 2.0 authentication.

**Support status:** Current release. Actively supported. EOL November 2030.

## Key Features Introduced in PostgreSQL 18

### Asynchronous I/O Subsystem

PostgreSQL 18 introduces an asynchronous I/O (AIO) subsystem that has demonstrated up to 3x performance improvements for read-heavy workloads. Backends can now queue multiple I/O requests instead of performing synchronous, blocking reads:

```sql
-- Check current I/O method
SHOW io_method;
```

```
# postgresql.conf
# I/O method: 'sync' (default, legacy), 'worker' (thread-pool AIO),
# or 'io_uring' (Linux io_uring -- best performance)
io_method = io_uring               # Linux with io_uring support
# io_method = worker               # Cross-platform alternative

# Control I/O combining (merging adjacent requests)
io_combine_limit = 128kB           # max combined I/O size
io_max_combine_limit = 256kB       # upper bound for io_combine_limit
```

**Which operations benefit:**
- Sequential scans (largest improvement, up to 3x faster)
- Bitmap heap scans
- VACUUM (reading dead tuple pages)
- Bulk COPY operations
- pg_basebackup

**Monitor AIO activity:**
```sql
-- New view: pg_aios -- shows active asynchronous I/O operations
SELECT * FROM pg_aios;
```

**io_method comparison:**
| Method | Platform | Performance | Notes |
|---|---|---|---|
| `sync` | All | Baseline | Legacy synchronous I/O |
| `worker` | All | 1.5-2x | Thread pool handles I/O asynchronously |
| `io_uring` | Linux 5.1+ | 2-3x | Kernel-level async I/O, lowest overhead |

### Virtual Generated Columns

Virtual generated columns compute their values at read time rather than storing them. They are now the default type for generated columns:

```sql
-- Virtual generated column (PG 18 default)
CREATE TABLE products (
    id int GENERATED ALWAYS AS IDENTITY,
    price numeric NOT NULL,
    tax_rate numeric NOT NULL DEFAULT 0.08,
    total_price numeric GENERATED ALWAYS AS (price * (1 + tax_rate)) VIRTUAL
);

-- Explicit VIRTUAL keyword (optional, it's the default)
CREATE TABLE employees (
    first_name text,
    last_name text,
    full_name text GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL
);

-- Stored generated columns still available with STORED keyword
CREATE TABLE metrics (
    raw_value double precision,
    normalized double precision GENERATED ALWAYS AS (raw_value / 100.0) STORED
);
```

**Virtual vs Stored generated columns:**
| Aspect | VIRTUAL (PG 18 default) | STORED |
|---|---|---|
| Disk space | None (computed on read) | Full column storage |
| Read performance | Slightly slower (computed) | Faster (pre-computed) |
| Write performance | Faster (no computation) | Slower (computed on write) |
| Indexing | Can be indexed | Can be indexed |
| Best for | Infrequently accessed, simple expressions | Frequently accessed, expensive expressions |

### UUIDv7 Support

PostgreSQL 18 includes a native `uuidv7()` function generating timestamp-ordered UUIDs:

```sql
-- Generate UUIDv7
SELECT uuidv7();
-- Example: 01932b9c-7e30-7cc3-9a1f-4b5e6d7f8a9b

-- Use as primary key (much better B-tree performance than UUIDv4)
CREATE TABLE events (
    id uuid DEFAULT uuidv7() PRIMARY KEY,
    event_type text NOT NULL,
    payload jsonb,
    created_at timestamptz DEFAULT now()
);

-- Extract timestamp from UUIDv7
SELECT uuid_extract_timestamp('01932b9c-7e30-7cc3-9a1f-4b5e6d7f8a9b');

-- Compare with UUIDv4 (gen_random_uuid)
-- UUIDv4: random, causes random index writes -> index fragmentation
-- UUIDv7: time-ordered, sequential index writes -> better performance
```

**Why UUIDv7 matters for databases:**
- **B-tree locality:** UUIDv7 values are monotonically increasing, so new inserts go to the rightmost leaf page. UUIDv4 scatter across the entire index.
- **Compression:** Sequential UUIDs compress much better in WAL and backups
- **Natural ordering:** No need for a separate `created_at` column for chronological ordering
- **Distributed systems:** Globally unique without coordination, with built-in temporal ordering

### OLD and NEW in RETURNING Clauses

INSERT, UPDATE, DELETE, and MERGE can now reference OLD and NEW tuples in RETURNING:

```sql
-- UPDATE: return both old and new values
UPDATE products
SET price = price * 1.10
WHERE category = 'electronics'
RETURNING OLD.price AS old_price, NEW.price AS new_price, id;

-- DELETE: return deleted row
DELETE FROM expired_sessions
WHERE expires_at < now()
RETURNING OLD.*;

-- INSERT: return inserted values (NEW is default)
INSERT INTO audit_log (action, details)
VALUES ('test', '{}')
RETURNING NEW.id, NEW.action;

-- MERGE with OLD/NEW
MERGE INTO inventory AS i
USING shipments AS s ON i.product_id = s.product_id
WHEN MATCHED THEN
    UPDATE SET quantity = i.quantity + s.quantity
WHEN NOT MATCHED THEN
    INSERT (product_id, quantity) VALUES (s.product_id, s.quantity)
RETURNING merge_action(),
          OLD.quantity AS prev_qty,
          NEW.quantity AS new_qty,
          NEW.product_id;
```

### Temporal Constraints

PostgreSQL 18 introduces temporal constraints -- constraints that operate over time ranges using PRIMARY KEY, UNIQUE, and FOREIGN KEY:

```sql
-- Temporal primary key: unique per entity per time period
CREATE TABLE room_bookings (
    room_id int,
    booked_during tstzrange,
    guest_name text,
    PRIMARY KEY (room_id, booked_during WITHOUT OVERLAPS)
);

-- Prevents overlapping bookings for the same room
INSERT INTO room_bookings VALUES
    (101, '[2025-06-01, 2025-06-05)', 'Alice'),    -- OK
    (101, '[2025-06-10, 2025-06-12)', 'Bob');       -- OK
    -- (101, '[2025-06-03, 2025-06-08)', 'Charlie') -- ERROR: overlaps Alice

-- Temporal foreign key
CREATE TABLE room_inventory (
    room_id int,
    valid_during tstzrange,
    room_type text,
    PRIMARY KEY (room_id, valid_during WITHOUT OVERLAPS)
);

CREATE TABLE reservations (
    id int PRIMARY KEY,
    room_id int,
    stay tstzrange,
    FOREIGN KEY (room_id, PERIOD stay)
        REFERENCES room_inventory (room_id, PERIOD valid_during)
);
```

### Skip Scan Optimization

PostgreSQL 18 adds skip scan support for multicolumn B-tree indexes, allowing queries to use an index even without an equality condition on the leading column:

```sql
-- Index on (region, created_at)
CREATE INDEX idx_orders_region_date ON orders (region, created_at);

-- PG 17: cannot use this index efficiently (no condition on 'region')
-- PG 18: uses skip scan -- jumps between distinct 'region' values
SELECT * FROM orders WHERE created_at > '2025-01-01';

-- Most beneficial when the leading column has LOW cardinality
-- (few distinct values to skip between)
EXPLAIN (ANALYZE) SELECT * FROM orders WHERE created_at > '2025-01-01';
-- Index Scan using idx_orders_region_date on orders
--   Index Searches: 5  (one per distinct region value)
```

**When skip scan helps:**
- Leading column has few distinct values (< 100)
- Remaining columns are highly selective
- The alternative would be a sequential scan

**When skip scan does NOT help:**
- Leading column has high cardinality (many distinct values)
- A dedicated index on the non-leading column exists

### OAuth 2.0 Authentication

PostgreSQL 18 adds OAuth 2.0 support, allowing authentication through external identity providers:

```
# pg_hba.conf
host  all  all  0.0.0.0/0  oauth
```

```
# postgresql.conf
oauth_provider_url = 'https://login.microsoftonline.com/tenant-id/v2.0'
oauth_client_id = 'your-client-id'
oauth_client_secret = 'your-client-secret'
oauth_scope = 'openid profile email'
```

**Supported providers:** Auth0, Okta, Microsoft Entra ID (Azure AD), Google, Keycloak, any OpenID Connect-compliant provider.

**Benefits:**
- Centralized authentication through existing SSO infrastructure
- Multi-factor authentication (MFA) enforcement via the identity provider
- No local password management for database users
- Token-based access with automatic expiration

### pg_upgrade Improvements

PostgreSQL 18 significantly improves the major version upgrade experience:

- **Parallel checks:** `pg_upgrade --jobs=N` runs pre-upgrade checks in parallel
- **--swap flag:** Swaps data directories instead of copying, dramatically reducing upgrade time for large databases
- **Preserved optimizer statistics:** Statistics survive the upgrade, eliminating the post-upgrade performance dip that previously required running ANALYZE on all tables
- **--set-char-signedness:** Override character signedness for the new cluster

```bash
# Fast upgrade with PG 18 improvements
pg_upgrade \
    --old-datadir /var/lib/postgresql/17/main \
    --new-datadir /var/lib/postgresql/18/main \
    --old-bindir /usr/lib/postgresql/17/bin \
    --new-bindir /usr/lib/postgresql/18/bin \
    --jobs=4 \
    --swap    # swap directories instead of copy (fastest)
```

### Other Notable Features

- **OR/IN optimization:** Improved query plans for queries with multiple OR conditions or large IN lists
- **NOT NULL inheritance improvements:** Better handling of NOT NULL constraints across table inheritance hierarchies
- **VACUUM/ANALYZE on inheritance children:** Now processes inheritance children by default (behavior change from PG 17)
- **EXPLAIN improvements:** `VERBOSE` mode shows delay timing (when `track_cost_delay_timing` is enabled), "buffers full" in WAL usage, and Index Searches count with `BUFFERS`
- **COPY end-of-file handling:** Modified end-of-file marker behavior for COPY FROM
- **New wire protocol version:** Updated PostgreSQL wire protocol for future extensibility

## Version Boundaries

- **New in PG 18 vs PG 17:** Async I/O, virtual generated columns, UUIDv7, OAuth 2.0, skip scan, temporal constraints, OLD/NEW RETURNING, pg_upgrade --swap/--jobs, preserved optimizer statistics, OR/IN optimization
- **Not available in prior versions:** All features above are PG 18 exclusive
- **Behavior changes from PG 17:** VACUUM/ANALYZE now processes inheritance children by default; virtual is the default generated column type

## Common Pitfalls

1. **io_method = io_uring requires Linux 5.1+** -- On older Linux kernels or non-Linux platforms, use `io_method = worker`. The `io_uring` method provides the best performance but is Linux-specific.

2. **Virtual generated columns cannot be indexed directly in some cases** -- While virtual columns can be indexed, the index stores computed values. If the expression is volatile, the index cannot be created.

3. **UUIDv7 clock dependency** -- UUIDv7 relies on the system clock. Clock skew or NTP jumps can cause non-monotonic UUID generation. In multi-node setups, ensure NTP synchronization.

4. **Temporal constraints require range types** -- The WITHOUT OVERLAPS syntax requires range or multirange columns. You cannot use plain timestamp columns; they must be wrapped in a range type.

5. **VACUUM behavior change with inheritance** -- If you have scripts that manually VACUUM/ANALYZE inheritance children separately, they may now run twice (once automatically as a child, once from your script). Review maintenance scripts.

6. **pg_upgrade --swap is destructive** -- The `--swap` flag modifies both old and new data directories in place. There is no rollback. Take a backup of the old cluster before using `--swap`.

7. **OAuth requires network access** -- The PostgreSQL server must be able to reach the OAuth provider URL. Ensure firewall rules allow outbound HTTPS from the database server.

## Migration Notes

### Upgrading from PostgreSQL 17 to 18

Pre-upgrade checklist:
1. **Test async I/O** -- After upgrade, test with `io_method = worker` first, then `io_uring` if on Linux. Benchmark your workload.
2. **Plan UUIDv7 adoption** -- For new tables, switch from `gen_random_uuid()` to `uuidv7()` for better index performance.
3. **Evaluate virtual generated columns** -- Existing stored generated columns continue to work. Consider virtual for new columns that are infrequently read.
4. **Review VACUUM scripts** -- Adjust for the new default behavior of processing inheritance children.
5. **Use pg_upgrade --jobs** -- Take advantage of parallel pre-upgrade checks to reduce downtime.
6. **Test OAuth integration** -- If planning to adopt OAuth, test with a non-production identity provider first.

```sql
-- After upgrade: verify async I/O is active
SHOW io_method;

-- Check UUIDv7 availability
SELECT uuidv7();

-- Test virtual generated column
CREATE TABLE test_virtual (
    a int, b int,
    c int GENERATED ALWAYS AS (a + b) VIRTUAL
);
INSERT INTO test_virtual (a, b) VALUES (1, 2);
SELECT * FROM test_virtual;  -- c = 3
DROP TABLE test_virtual;
```

## Reference Files

For deep technical details, load the parent technology agent's references:

- `../references/architecture.md` -- Process architecture, shared memory, WAL internals
- `../references/diagnostics.md` -- pg_stat views, EXPLAIN ANALYZE, lock analysis
- `../references/best-practices.md` -- Configuration tuning, backup, security
