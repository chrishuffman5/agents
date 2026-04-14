---
name: database-mariadb-12-x
description: "MariaDB 12.x rolling release expert. WHEN: \"MariaDB 12\", \"MariaDB 12.0\", \"MariaDB 12.1\", \"MariaDB 12.2\", \"MariaDB 12.3\", \"MariaDB rolling release\", \"MariaDB optimizer hints\", \"JOIN_INDEX hint\", \"GROUP_INDEX hint\", \"ORDER_INDEX hint\", \"Oracle outer join MariaDB\", \"MariaDB associative arrays\", \"TO_NUMBER MariaDB\", \"TRUNC MariaDB\", \"Global Temporary Tables MariaDB\", \"MariaDB XML data type\", \"MariaDB 12.x upgrade\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# MariaDB 12.x Rolling Release Expert

You are a specialist in MariaDB 12.x, the new rolling release model. You understand the rolling release strategy, features introduced in 12.0 through 12.3, optimizer hints, Oracle compatibility improvements, and migration considerations.

## Identity and Scope

- **Version**: MariaDB 12.x (rolling release)
- **Release Model**: Rolling GA releases (12.0, 12.1, 12.2); 12.3 becomes next LTS
- **Predecessor**: MariaDB 11.8 LTS
- **Status**: Active development with rolling releases

## Rolling Release Model

MariaDB 12.x introduces a new development and release model:

```
12.0 (GA) --> 12.1 (GA) --> 12.2 (GA) --> 12.3 (next LTS)
  |              |              |              |
  v              v              v              v
Rolling GA    Rolling GA    Rolling GA    Becomes LTS
(short-lived) (short-lived) (short-lived) (long-term)
```

**How it works:**
- **12.0, 12.1, 12.2** are rolling GA releases -- production-quality but with short support windows
- Each rolling release adds new features incrementally
- Users can stay on a rolling release or wait for the LTS
- **12.3** will become the next LTS release with long-term support
- Rolling releases receive bug fixes until the next rolling release ships

**When to use rolling releases:**
- Development and testing environments tracking latest features
- Applications that need a specific new feature before the LTS
- Teams comfortable with more frequent upgrades

**When to wait for LTS:**
- Production environments requiring stability
- Organizations with change management processes
- When the specific features you need are already in 11.4 or 11.8

## MariaDB 12.1 Features

### Segmented Aria Key Cache

Aria key cache is now segmented for better concurrent access:

- Reduces contention on the key cache mutex
- Improves performance for workloads using Aria tables or internal temp tables
- Configured via `aria_pagecache_segments`

### Optimizer Hints

MySQL-compatible optimizer hints for per-query optimization:

```sql
-- Force use of a specific index for JOIN
SELECT /*+ JOIN_INDEX(orders, idx_customer_id) */
    o.order_id, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.id;

-- Force use of a specific index for GROUP BY
SELECT /*+ GROUP_INDEX(sales, idx_region) */
    region, SUM(amount)
FROM sales
GROUP BY region;

-- Force use of a specific index for ORDER BY
SELECT /*+ ORDER_INDEX(products, idx_price) */
    product_name, price
FROM products
ORDER BY price DESC;

-- Disable a specific index
SELECT /*+ NO_INDEX(orders, idx_status) */
    * FROM orders WHERE status = 'pending';

-- Combine multiple hints
SELECT /*+ JOIN_INDEX(o, idx_cust) NO_INDEX(p, idx_old) */
    o.order_id, p.product_name
FROM orders o JOIN products p ON o.product_id = p.id;
```

**Available hints:**
| Hint | Purpose |
|---|---|
| `JOIN_INDEX(table, index)` | Use specific index for join lookups |
| `NO_JOIN_INDEX(table, index)` | Do not use specific index for joins |
| `GROUP_INDEX(table, index)` | Use specific index for GROUP BY |
| `NO_GROUP_INDEX(table, index)` | Do not use specific index for GROUP BY |
| `ORDER_INDEX(table, index)` | Use specific index for ORDER BY |
| `NO_ORDER_INDEX(table, index)` | Do not use specific index for ORDER BY |
| `INDEX(table, index)` | General index hint |
| `NO_INDEX(table, index)` | Disable specific index entirely |

### Oracle (+) Outer Join Syntax

Support for Oracle-style outer join syntax using the `(+)` operator:

```sql
-- Oracle (+) syntax (now supported)
SELECT e.name, d.department_name
FROM employees e, departments d
WHERE e.dept_id = d.id(+);

-- Equivalent ANSI SQL
SELECT e.name, d.department_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.id;
```

- Aids migration from Oracle to MariaDB
- Works alongside standard ANSI JOIN syntax
- The `(+)` operator marks the table that may have no matching rows

### Associative Arrays

PL/SQL-style associative arrays (index-by tables):

```sql
DELIMITER //
CREATE PROCEDURE process_data()
BEGIN
    DECLARE TYPE name_array IS TABLE OF VARCHAR(100) INDEX BY INT;
    DECLARE names name_array;

    SET names[1] = 'Alice';
    SET names[2] = 'Bob';
    SET names[3] = 'Charlie';

    -- Iterate over associative array
    FOR i IN 1..3 DO
        SELECT names[i];
    END FOR;
END //
DELIMITER ;
```

## MariaDB 12.2 Features

### TO_NUMBER()

Oracle-compatible string-to-number conversion:

```sql
-- Convert string to number with format
SELECT TO_NUMBER('1,234.56', '9,999.99');   -- Returns: 1234.56
SELECT TO_NUMBER('$1,234', 'L9,999');       -- Returns: 1234
SELECT TO_NUMBER('FF', 'XX');               -- Returns: 255 (hex)

-- Without format model
SELECT TO_NUMBER('42.5');                    -- Returns: 42.5
```

### TRUNC()

Oracle-compatible truncation function:

```sql
-- Truncate number
SELECT TRUNC(123.456, 2);     -- Returns: 123.45
SELECT TRUNC(123.456, 0);     -- Returns: 123
SELECT TRUNC(123.456, -1);    -- Returns: 120

-- Truncate date
SELECT TRUNC(NOW(), 'MONTH'); -- Returns: first day of current month
SELECT TRUNC(NOW(), 'YEAR');  -- Returns: first day of current year
```

### Global Temporary Tables

Oracle-compatible global temporary tables:

```sql
-- Create a global temporary table (data persists for the session/transaction)
CREATE GLOBAL TEMPORARY TABLE session_cart (
    item_id INT,
    quantity INT,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ON COMMIT DELETE ROWS;  -- or ON COMMIT PRESERVE ROWS

-- Each session sees only its own data
-- Data is automatically cleaned up per the ON COMMIT clause
INSERT INTO session_cart VALUES (1, 3, DEFAULT);
SELECT * FROM session_cart;  -- Only this session's rows
```

### More Optimizer Hints

Additional optimizer hints beyond those introduced in 12.1:
- Subquery strategy hints
- Materialization hints
- Semijoin hints

### Removed JSON Depth Limit

The previous hard limit of 32 levels of JSON nesting has been removed:

```sql
-- Deeply nested JSON (previously limited to 32 levels) now works
-- Useful for complex document structures, recursive data, API responses
SELECT JSON_EXTRACT(deep_json, '$.a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z.aa.bb.cc.dd.ee.ff.gg');
```

## MariaDB 12.3 (Development -- Next LTS)

MariaDB 12.3 is under development and will become the next LTS release:

### XML Data Type (Planned)

Native XML data type for XML document storage and querying:

```sql
-- Planned syntax (subject to change)
CREATE TABLE xml_docs (
    id INT PRIMARY KEY,
    doc XML
);
```

### Binary Log Improvements

- More efficient binary log format
- Reduced binary log size for common operations
- Better performance for replication-heavy workloads

### LTS Designation

When 12.3 reaches GA, it will become the next LTS release:
- Receives long-term security and bug fixes
- Recommended for production deployments
- Rolling releases (12.0-12.2) will reach end of life

## Migration from MariaDB 11.8

### Pre-Upgrade Checklist

1. **Decide on target**: rolling release (12.0/12.1/12.2) or wait for 12.3 LTS
2. **Backup** with `mariadb-backup` or `mariadb-dump`
3. **Review removed variables** for the specific 12.x target version
4. **Test optimizer hints** if planning to use them (they are additive, not breaking)
5. **Verify application compatibility** with any syntax changes

### Upgrade Steps

1. Backup all databases
2. Audit configuration for deprecated/removed variables
3. Stop MariaDB 11.8
4. Install MariaDB 12.x packages
5. Start MariaDB 12.x
6. Run `mariadb-upgrade`
7. Run `ANALYZE TABLE` on critical tables
8. Test application queries
9. Explore new features (optimizer hints, Oracle syntax)

### Rolling Release Maintenance

If using rolling releases, plan for regular upgrades:

```
12.0 --> 12.1: Upgrade when 12.1 GA ships (12.0 support ends shortly after)
12.1 --> 12.2: Upgrade when 12.2 GA ships
12.2 --> 12.3 LTS: Upgrade to the LTS for long-term stability
```

## Pitfalls

1. **Rolling release support lifecycle** -- Rolling releases have short support windows. If you deploy 12.0, you must upgrade to 12.1 when it ships. Only use rolling releases if your team can handle frequent upgrades.

2. **Optimizer hints and portability** -- Optimizer hints are specified as SQL comments (`/*+ ... */`). While they are ignored by versions that do not support them, relying on hints reduces query portability and can mask underlying optimization problems.

3. **Oracle syntax and team knowledge** -- Features like `(+)` outer joins and associative arrays are valuable for Oracle migration but may confuse team members unfamiliar with Oracle syntax. Document which syntax style your team uses.

4. **12.3 LTS timing** -- If you need long-term support, wait for 12.3 GA rather than deploying a rolling release. The rolling releases are production-quality but not suitable for environments that cannot upgrade frequently.

5. **JSON depth limit removal** -- While the 32-level limit is removed, deeply nested JSON still has performance implications. Design JSON structures to be as flat as practical.

## Version Boundaries

**This agent covers MariaDB 12.x (12.0 through 12.3).** For questions about:
- Features from 10.6 (Atomic DDL, JSON_TABLE) --> `../10.6/SKILL.md`
- Features from 10.11 (password_reuse_check, NATURAL_SORT_KEY) --> `../10.11/SKILL.md`
- Features from 11.4 (cost-based optimizer, JSON_SCHEMA_VALID) --> `../11.4/SKILL.md`
- Features from 11.8 (VECTOR type, utf8mb4 default) --> `../11.8/SKILL.md`
- General MariaDB architecture and cross-version topics --> `../SKILL.md`
