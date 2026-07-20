# Snowflake Architecture Reference

## Three-Layer Architecture Deep Dive

### Cloud Services Layer

The cloud services layer is the "brain" of Snowflake. It is a shared, multi-tenant service that handles:

**Metadata Management:**
- Maintains a catalog of all micro-partitions for every table
- Stores min/max values, distinct count, null count, and byte size for every column in every micro-partition
- This metadata enables partition pruning without scanning actual data
- Metadata queries (COUNT(*), MIN/MAX on clustered columns) can return results from metadata alone -- zero warehouse compute needed

**Query Compilation and Optimization:**
- Parses SQL, resolves references, checks access control
- Cost-based optimizer uses micro-partition statistics for join ordering and pruning decisions
- Generates an execution plan (DAG of operators) distributed across warehouse nodes
- Compilation time is typically 50-500ms; complex queries with many CTEs or deeply nested subqueries may take longer

**Transaction Management:**
- ACID transactions with snapshot isolation (SI)
- Multi-statement transactions supported (`BEGIN ... COMMIT`)
- Read queries see a consistent snapshot as of transaction start
- Write transactions create new micro-partitions (never modify existing ones -- copy-on-write)
- Conflict detection: Two concurrent transactions modifying overlapping micro-partitions cause one to abort

**Result Set Cache:**
- Exact query text match (case-sensitive, whitespace-sensitive, including comments)
- Valid for 24 hours from execution
- Invalidated when any underlying table's data changes
- Free -- no warehouse credits consumed
- Cross-user: if User A runs a query and User B runs the same query with the same role, User B gets the cached result
- Persisted in cloud services layer (not on warehouse nodes)

**Cloud Services Billing:**
- Cloud services compute is billed in credits
- However, only the portion exceeding 10% of the daily total warehouse credit consumption is charged
- Example: If warehouses consume 100 credits/day, cloud services up to 10 credits/day are free. Only amounts above 10 credits are billed.
- Heavy metadata operations (INFORMATION_SCHEMA queries, SHOW commands, very frequent small queries) can push cloud services above the 10% threshold

### Compute Layer -- Virtual Warehouse Internals

**Warehouse Node Architecture:**
Each warehouse node is a cloud VM (EC2, Azure VM, GCE) with:
- Multi-core CPU (varies by cloud provider and warehouse size)
- Local NVMe SSD storage used as a raw data cache
- RAM for query processing (hash tables, sort buffers, aggregation state)
- Network connectivity to cloud object storage

**How warehouse sizing works:**
- Each warehouse size doubles the node count (XS=1, S=2, M=4, L=8, XL=16, etc.)
- All nodes in a warehouse share the work for every query via distributed execution
- A query on a Medium warehouse is split across 4 nodes, each processing ~25% of the data
- Scaling up (larger size) improves single-query performance for scan-heavy workloads
- Scaling out (multi-cluster) improves concurrency by running multiple independent clusters

**Query Execution Flow:**
1. Cloud services layer compiles the query plan and identifies which micro-partitions to scan
2. The plan is sent to the warehouse coordinator node
3. The coordinator distributes work to all warehouse nodes (data is hash-partitioned across nodes)
4. Each node:
   a. Checks local SSD cache for needed micro-partitions
   b. Fetches missing micro-partitions from cloud object storage
   c. Decompresses and processes its share of the data
   d. Sends partial results to the coordinator (or reshuffles for JOINs/GROUP BYs)
5. The coordinator merges final results and returns to the client

**Local SSD Cache (Raw Data Cache):**
- Each warehouse node maintains an LRU cache of micro-partition data on local SSDs
- Cache is populated as queries read data from cloud storage
- Cache persists across queries as long as the warehouse is running (not suspended)
- After a warehouse resumes from suspension, the cache is empty (cold start)
- Cache hit rates of 80-95% are typical for repeated analytical workloads on the same dataset
- Monitor with: `BYTES_SCANNED` (total) vs `PERCENTAGE_SCANNED_FROM_CACHE` in QUERY_HISTORY

**Warehouse Suspension and Resumption:**
- Suspension releases all compute nodes (no credits consumed)
- Resumption provisions new nodes (takes 1-5 seconds for small warehouses, up to 30 seconds for very large ones)
- Local SSD cache is lost on suspension -- first queries after resumption will be slower (cold cache)
- AUTO_SUSPEND timer starts from the moment the last query on that warehouse completes (including queued queries)
- AUTO_RESUME triggers when any query arrives for that warehouse

**Multi-Cluster Warehouse Architecture (Enterprise+):**
```
Multi-Cluster Warehouse (MAX=3)
├── Cluster 1 (always running when warehouse is active)
│   ├── Node 1 (with local SSD cache)
│   ├── Node 2
│   ├── Node 3
│   └── Node 4   (if warehouse size = Medium)
├── Cluster 2 (started when concurrency demand increases)
│   ├── Node 1
│   ├── Node 2
│   ├── Node 3
│   └── Node 4
└── Cluster 3 (started under highest concurrency)
    ├── Node 1
    ├── Node 2
    ├── Node 3
    └── Node 4
```

- Each cluster is an independent, full-size copy of the warehouse
- New queries are routed to the cluster with the shortest queue
- STANDARD policy: starts a new cluster as soon as a query queues on all existing clusters
- ECONOMY policy: starts a new cluster only after ~6 minutes of sustained queueing
- Clusters are removed (scaled in) when idle for 2-3 consecutive load checks (~5-10 minutes)

### Storage Layer -- Micro-Partition Internals

**Micro-Partition Structure:**
Each micro-partition is a single file in cloud object storage containing:
- Column-oriented data for all columns in the table
- Each column stored contiguously within the file (enables reading only needed columns)
- Compressed using a proprietary format (similar to PAX/hybrid columnar)
- Typical size: 50-500MB compressed
- Contains approximately 16MB of uncompressed data per column (varies)
- Immutable -- never modified after creation; updates/deletes create new micro-partitions

**Micro-Partition Metadata (stored in cloud services layer, not in the partition file):**
For each micro-partition, Snowflake maintains:
- Min and max values for every column (enables pruning)
- Number of distinct values for every column
- Number of null values for every column
- Total byte count (compressed and uncompressed)
- Encryption key reference

**How DML Creates Micro-Partitions:**

INSERT:
```
INSERT INTO orders VALUES (...), (...), ...
→ New micro-partitions are created containing the inserted rows
→ Existing micro-partitions are untouched
```

UPDATE:
```
UPDATE orders SET status = 'shipped' WHERE order_id = 42
→ Micro-partitions containing matching rows are identified
→ New micro-partitions are created with the updated values
→ Old micro-partitions are marked as deleted (but retained for Time Travel)
```

DELETE:
```
DELETE FROM orders WHERE order_date < '2025-01-01'
→ Micro-partitions containing matching rows are identified
→ If ALL rows in a micro-partition match: partition is simply removed
→ If SOME rows match: a new micro-partition is created without the deleted rows
→ Old micro-partitions retained for Time Travel
```

**Reclustering (Automatic Clustering Service):**
When a clustering key is defined, Snowflake's background service periodically:
1. Identifies micro-partitions with poor clustering (high overlap in clustering key values)
2. Reads those micro-partitions
3. Rewrites them as new micro-partitions sorted by the clustering key
4. Removes the old micro-partitions (after Time Travel retention)
5. This is billed as serverless credits (separate from warehouse credits)

## Data Types Deep Dive

### Numeric Types
| Type | Storage | Range | Notes |
|------|---------|-------|-------|
| NUMBER(p,s) | Variable (up to 16 bytes) | Up to 38 digits precision | Default: NUMBER(38,0). Use for exact decimals. |
| INT/INTEGER | 16 bytes | Alias for NUMBER(38,0) | No separate integer storage optimization |
| FLOAT/DOUBLE | 8 bytes | IEEE 754 double precision | Use for scientific data; avoid for financial |
| DECIMAL(p,s) | Variable | Alias for NUMBER(p,s) | - |

**Important:** Snowflake stores all NUMBER types as variable-length integers internally. There is no storage advantage to using INT vs NUMBER(38,0) -- both consume the same space. FLOAT/DOUBLE are stored as 8-byte IEEE 754.

### String Types
| Type | Max Size | Notes |
|------|----------|-------|
| VARCHAR(n) | 16MB | Default max length if n omitted is 16,777,216 |
| STRING/TEXT | 16MB | Aliases for VARCHAR(16777216) |
| CHAR(n) | 16MB | NOT right-padded (unlike traditional RDBMS) |
| BINARY(n) | 8MB | Binary data |

**Important:** Unlike Oracle/SQL Server, Snowflake VARCHAR is always variable-length. Specifying VARCHAR(100) vs VARCHAR does NOT save storage -- it only adds a constraint check.

### Date/Time Types
| Type | Storage | Range | Notes |
|------|---------|-------|-------|
| DATE | 4 bytes | 0001-01-01 to 9999-12-31 | Date only, no time component |
| TIME | 8 bytes | 00:00:00 to 23:59:59.999999999 | Time only, no date component |
| TIMESTAMP_NTZ | 8 bytes | Without timezone | "Wall clock" time; default TIMESTAMP type |
| TIMESTAMP_LTZ | 8 bytes | With local timezone | Stored as UTC, displayed in session timezone |
| TIMESTAMP_TZ | 12 bytes | With explicit timezone | Stores the timezone offset with the value |

**Best practice:** Use TIMESTAMP_LTZ for event timestamps (always stores UTC internally, displays in session's timezone). Use TIMESTAMP_NTZ for business dates/times that should not shift with timezone. Set `TIMEZONE = 'UTC'` at session or account level for consistency.

### Semi-Structured Types
| Type | Max Size | Notes |
|------|----------|-------|
| VARIANT | 16MB | Holds any JSON, Avro, ORC, or Parquet value |
| OBJECT | 16MB | A VARIANT that must be a JSON object (key-value) |
| ARRAY | 16MB | A VARIANT that must be a JSON array |

**VARIANT Storage Optimization:**
Snowflake automatically extracts commonly-queried paths from VARIANT columns into separate internal columns (a process sometimes called "columnarization" or "schema detection"). Paths that are:
- Consistently present across rows
- Consistently the same data type
are extracted into dedicated columnar storage, enabling the same compression and pruning benefits as native typed columns.

**Querying VARIANT (dot notation and bracket notation):**
```sql
-- Dot notation (case-insensitive for unquoted keys)
SELECT src:user_id, src:address.city, src:tags[0]

-- Bracket notation (case-sensitive, required for special characters)
SELECT src['user_id'], src['address']['city'], src['tags'][0]

-- Explicit casting (required for comparisons, joins, and correct type handling)
SELECT src:user_id::INTEGER, src:address.city::STRING
```

### GEOGRAPHY and GEOMETRY Types
```sql
-- GEOGRAPHY: spherical coordinates (lat/long on WGS84 ellipsoid)
SELECT ST_DISTANCE(
    ST_MAKEPOINT(-73.9857, 40.7484),  -- Empire State Building
    ST_MAKEPOINT(-73.9712, 40.7614)   -- Rockefeller Center
);

-- GEOMETRY: planar coordinates (Cartesian plane, any SRID)
SELECT ST_AREA(ST_GEOMFROMWKT('POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))'));
```

## Transaction Model

### Snapshot Isolation

Snowflake uses **snapshot isolation** for all transactions:
- Each statement (or explicit transaction) sees a consistent snapshot of the database as of the transaction's start timestamp
- Readers never block writers; writers never block readers
- Two concurrent writers to the SAME micro-partitions cause a conflict -- the second transaction to commit will fail with a serialization error
- This is fundamentally different from lock-based systems (Oracle, SQL Server)

**Implications:**
- No row-level locking, no lock escalation, no deadlocks
- Read-heavy workloads (BI, analytics) never interfere with write workloads (ETL)
- Write-write conflicts are detected at commit time (optimistic concurrency)
- Long-running transactions hold their snapshot, consuming Time Travel storage

**Multi-statement transactions:**
```sql
BEGIN;
  INSERT INTO orders VALUES (...);
  UPDATE inventory SET qty = qty - 1 WHERE item_id = 42;
  INSERT INTO audit_log VALUES (...);
COMMIT;
-- All three statements see the same snapshot and commit atomically
```

**Auto-commit behavior:** By default, each statement is an auto-committed transaction. Enable explicit transactions with `BEGIN ... COMMIT/ROLLBACK` or set `AUTOCOMMIT = FALSE`.

### Write Conflicts

Snowflake detects write-write conflicts at the micro-partition level:
```
Transaction A: UPDATE orders SET status='shipped' WHERE order_id = 1;
Transaction B: UPDATE orders SET status='cancelled' WHERE order_id = 1;
-- If both modify rows in the same micro-partition:
-- The second transaction to commit fails with:
-- "Transaction conflict: the resource is locked by another transaction."
```

**Avoiding conflicts:**
- Batch writes by time window or partition to minimize overlap
- Use tasks/stored procedures to serialize writes to hot tables
- For CDC patterns, use streams + tasks (single consumer per stream)
- Retry logic for transient conflict errors (error code 000625)

## Replication and Failover

### Database Replication
```sql
-- Primary account: enable replication
ALTER DATABASE analytics ENABLE REPLICATION TO ACCOUNTS org.secondary_account;

-- Secondary account: create a replica
CREATE DATABASE analytics_replica AS REPLICA OF org.primary_account.analytics;

-- Refresh the replica (manual or scheduled)
ALTER DATABASE analytics_replica REFRESH;

-- Promote replica to primary (failover)
ALTER DATABASE analytics_replica PRIMARY;
```

### Failover Groups (Business Critical+)
```sql
-- Create a failover group (replicates databases, shares, warehouses, roles, users)
CREATE FAILOVER GROUP my_failover_group
  OBJECT_TYPES = DATABASES, ROLES, USERS, WAREHOUSES, INTEGRATIONS
  ALLOWED_DATABASES = analytics, warehouse_db
  ALLOWED_ACCOUNTS = org.secondary_account
  REPLICATION_SCHEDULE = '10 MINUTE';

-- Secondary account: create from failover group
CREATE FAILOVER GROUP my_failover_group
  AS REPLICA OF org.primary_account.my_failover_group;

-- Failover (on secondary account)
ALTER FAILOVER GROUP my_failover_group PRIMARY;
```

### Cross-Cloud and Cross-Region Replication
Snowflake supports replication across cloud providers and regions:
- AWS us-east-1 to Azure West Europe
- GCP us-central1 to AWS eu-west-1
- Replication is asynchronous; lag depends on data volume and network
- Data transfer costs apply for cross-region/cross-cloud replication
- Use replication for disaster recovery, data locality, and sharing across regions

## Encryption and Key Management

**Default encryption (all editions):**
- All data at rest: AES-256 encryption
- All data in transit: TLS 1.2+
- Snowflake manages the encryption key hierarchy (root key, account key, table key, file key)
- Keys are automatically rotated annually

**Tri-Secret Secure (Business Critical+):**
- Customer provides a wrapping key via their cloud KMS (AWS KMS, Azure Key Vault, GCP Cloud KMS)
- Snowflake's account key is wrapped by the customer's key
- Both Snowflake and the customer must cooperate to decrypt data
- Customer can revoke their key to make data inaccessible (crypto-shredding)

```sql
-- Check encryption status
SELECT SYSTEM$GET_SNOWFLAKE_PLATFORM_INFO();

-- View key rotation history
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.SESSION_POLICIES;
```

## Network Architecture

**Standard connectivity:**
- All communication over HTTPS (port 443)
- Snowflake endpoints are public by default (accessible from the internet)
- Network policies restrict access by IP allowlist/blocklist

**Private connectivity (Business Critical+):**
- AWS PrivateLink: Traffic stays on AWS backbone, never traverses the internet
- Azure Private Link: Same for Azure
- Google Cloud Private Service Connect: Same for GCP
- Internal stages use the same private connectivity path

**Configuration:**
```sql
-- Create a network rule for private endpoints
CREATE NETWORK RULE private_access
  TYPE = PRIVATE_HOST_PORT
  VALUE_LIST = ('my-private-endpoint.snowflakecomputing.com');

-- Create network policy using the rule
CREATE NETWORK POLICY private_only
  ALLOWED_NETWORK_RULE_LIST = ('private_access');
```

## Stage Architecture

Stages are locations for data files used in loading and unloading:

**Internal stages** (data stored in Snowflake-managed cloud storage):
- User stage (`@~`): One per user, implicit
- Table stage (`@%table_name`): One per table, implicit
- Named internal stage (`@my_stage`): Explicitly created, shareable

**External stages** (data stored in customer-managed cloud storage):
```sql
-- S3 stage with storage integration (recommended)
CREATE STORAGE INTEGRATION s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/snowflake-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://my-bucket/data/');

CREATE STAGE my_s3_stage
  URL = 's3://my-bucket/data/'
  STORAGE_INTEGRATION = s3_integration
  FILE_FORMAT = (TYPE = 'PARQUET');

-- Azure stage
CREATE STAGE my_azure_stage
  URL = 'azure://myaccount.blob.core.windows.net/mycontainer/data/'
  STORAGE_INTEGRATION = azure_integration;

-- GCS stage
CREATE STAGE my_gcs_stage
  URL = 'gcs://my-bucket/data/'
  STORAGE_INTEGRATION = gcs_integration;
```

**Directory tables** (metadata layer over stages):
```sql
-- Enable directory table on a stage
ALTER STAGE my_stage SET DIRECTORY = (ENABLE = TRUE);
ALTER STAGE my_stage REFRESH;

-- Query files in the stage
SELECT * FROM DIRECTORY(@my_stage);
-- Returns: RELATIVE_PATH, SIZE, LAST_MODIFIED, MD5, ETAG
```

## Search Optimization Service (Enterprise+)

The search optimization service accelerates point-lookup and equality-predicate queries:

```sql
-- Enable search optimization on a table
ALTER TABLE customers ADD SEARCH OPTIMIZATION;

-- Enable on specific columns only (more targeted, less cost)
ALTER TABLE customers ADD SEARCH OPTIMIZATION
  ON EQUALITY(customer_id, email)
  ON SUBSTRING(name)
  ON GEO(location);

-- Check search optimization status
SELECT * FROM TABLE(INFORMATION_SCHEMA.SEARCH_OPTIMIZATION_HISTORY(
    DATE_RANGE_START => DATEADD(day, -7, CURRENT_TIMESTAMP())
));

-- Drop search optimization
ALTER TABLE customers DROP SEARCH OPTIMIZATION;
```

**How it works:** Snowflake builds supplementary data structures (search access paths) that enable rapid point-lookup without scanning micro-partitions. This is particularly effective for:
- Selective equality predicates on high-cardinality columns (`WHERE customer_id = 'ABC123'`)
- VARIANT field access (`WHERE src:user.email = 'user@example.com'`)
- Substring searches (`WHERE name LIKE '%smith%'`)
- Geospatial queries (`WHERE ST_CONTAINS(region, point)`)
- IN-list predicates

**Cost:** Billed as serverless credits for building and maintaining search access paths. Monitor with `SEARCH_OPTIMIZATION_HISTORY`.

## Query Acceleration Service (Enterprise+)

Offloads portions of eligible queries to shared serverless compute:

```sql
-- Enable on a warehouse
ALTER WAREHOUSE analytics_wh SET ENABLE_QUERY_ACCELERATION = TRUE;
ALTER WAREHOUSE analytics_wh SET QUERY_ACCELERATION_MAX_SCALE_FACTOR = 8;
-- scale_factor: 0 = no limit; N = up to N times the warehouse's compute

-- Check which queries benefited
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ACCELERATION_HISTORY
WHERE start_time > DATEADD(day, -7, CURRENT_TIMESTAMP());

-- Check eligible queries before enabling
SELECT query_id, eligible_query_acceleration_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE eligible_query_acceleration_time > 0
  AND start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY eligible_query_acceleration_time DESC;
```

**Best for:** Queries with large scans but selective filters, queries with disproportionately expensive operations (large sorts, distinct counts on high-cardinality columns). Not beneficial for all queries -- check `eligible_query_acceleration_time` in query history.

## Snowflake Notebooks and Streamlit

**Snowflake Notebooks:** Jupyter-like notebooks running natively in Snowflake:
- Support Python, SQL, and Markdown cells
- Access Snowpark DataFrames, Cortex ML functions, and Streamlit visualizations
- Backed by Snowflake compute (no external infrastructure)
- Git integration for version control

**Streamlit in Snowflake:** Build interactive data applications directly in Snowflake:
```python
# Deployed as a Streamlit app inside Snowflake
import streamlit as st
from snowflake.snowpark.context import get_active_session

session = get_active_session()
df = session.sql("SELECT region, SUM(revenue) AS total FROM sales GROUP BY region")
st.bar_chart(df.to_pandas().set_index("REGION"))
```

## Snowflake Data Governance

### Tags and Classification
```sql
-- Create a tag
CREATE TAG pii_type ALLOWED_VALUES 'email', 'phone', 'ssn', 'address';

-- Apply tag to a column
ALTER TABLE customers MODIFY COLUMN email SET TAG pii_type = 'email';
ALTER TABLE customers MODIFY COLUMN phone SET TAG pii_type = 'phone';

-- Query tags
SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('customers', 'TABLE'));

-- Auto-classification (detects PII/sensitive data)
SELECT EXTRACT_SEMANTIC_CATEGORIES('customers');
```

### Access History (Enterprise+)
```sql
-- Track which columns and objects were accessed
SELECT user_name, query_id, direct_objects_accessed, base_objects_accessed
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE query_start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY query_start_time DESC;
```

### Object Dependencies
```sql
-- View dependencies between objects (views referencing tables, etc.)
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES
WHERE referencing_object_name = 'MY_VIEW';
```
