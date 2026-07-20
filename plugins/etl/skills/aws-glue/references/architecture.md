# AWS Glue Architecture Deep Dive

## Data Catalog

### Structure and Purpose

The Data Catalog is a centralized, persistent metadata repository -- one per AWS account per region. It is Hive-compatible and serves as a drop-in replacement for the Apache Hive Metastore.

**Core objects**:

- **Databases**: Logical groupings of table definitions. Organize by data domain or processing layer (e.g., `raw_sales`, `curated_sales`, `published_sales`).
- **Tables**: Metadata describing the schema, physical location (S3 path, JDBC endpoint), file format, SerDe, and table properties of data. Tables do not contain data -- they point to it.
- **Partitions**: Subdivisions of a table based on column values. Each partition maps to a specific S3 prefix or JDBC predicate. Example: `s3://bucket/orders/year=2025/month=08/day=15/`.
- **Connections**: Catalog objects containing connection properties for external data stores (JDBC endpoint, VPC subnet, security group, credentials via Secrets Manager).
- **User-Defined Functions**: Custom functions registered in the catalog for use in ETL scripts.

**Integration points**:

- Amazon Athena queries Data Catalog tables directly (serverless SQL over S3)
- Amazon Redshift Spectrum uses the catalog for external table definitions
- Amazon EMR reads catalog metadata when configured as Hive Metastore
- AWS Lake Formation extends the catalog with column-level and row-level access control
- AWS CloudTrail provides audit logging for all catalog API operations

### Schema Versioning

The Data Catalog retains schema history for each table. When a crawler or API call updates a table's schema, the previous version is preserved. This enables schema change auditing and rollback.

### Partition Indexes

Glue crawlers automatically create partition indexes for S3 and Delta Lake targets. Partition indexes accelerate partition metadata lookups for tables with millions of partitions, significantly improving Athena and Spark query planning times.

## Crawlers

### Execution Flow

1. **Connect** to the configured data store (S3, JDBC, DynamoDB, MongoDB)
2. **Walk** through the data, reading the first megabyte of each file to classify format
3. **Classify** by applying classifiers in priority order until one succeeds
4. **Group** compatible schemas and create or update table definitions in the Data Catalog
5. **Partition** -- automatically create partition entries for S3 and Delta Lake targets

### Classifiers

Classifiers determine the data format encountered by crawlers.

**Built-in classifiers**: CSV, JSON, Avro, Parquet, ORC, XML, Ion, JDBC, Grok patterns for semi-structured logs.

**Custom classifiers**:
- **Grok**: Pattern-based matching for log files and unstructured text
- **XML**: Match XML data using a row tag
- **JSON**: Match JSON using a JSON path
- **CSV**: Custom delimiters, quote characters, header handling

Custom classifiers are evaluated before built-in classifiers. Assign them to crawlers and verify against sample data before production deployment.

### Crawler Scheduling

- **On-demand**: Manual or API-driven execution
- **Scheduled**: Cron-based recurring runs
- **Event-driven**: EventBridge rules triggered by S3 object creation or other events

### Schema Change Behavior

Configure crawler behavior when schema changes are detected:
- **ADD_NEW_COLUMNS**: Add new columns to the existing table definition
- **UPDATE**: Replace the table schema with the new version
- **LOG**: Log the change but do not modify the table definition

## ETL Engine

### Glue Spark Runtime

AWS Glue ETL jobs run on a managed Apache Spark environment. The runtime evolves through versioned releases:

| Version | Spark | Python | Java | Key Additions |
|---|---|---|---|---|
| Glue 3.0 | 3.1 | 3.7 | 8 | Auto Scaling, optimized shuffle, small file grouping |
| Glue 4.0 | 3.3 | 3.10 | 8 | Optimized runtime, improved start times |
| Glue 5.0 | 3.5.4 | 3.11 | 17 | Native S3 access, Iceberg 1.7, Hudi 0.15, Delta Lake 3.3 |
| Glue 5.1 | 3.5.6 | 3.11 | 17 | Iceberg format v3, S3A default, Hudi 1.0.2, Iceberg 1.10, Delta Lake 3.3.2 |

### DynamicFrame API

AWS Glue extends Spark with the DynamicFrame API:

- Handles schema inconsistencies (mixed types in the same column) without requiring upfront schema definition
- Integrates natively with the Data Catalog for reading and writing
- Supports Glue-specific features: job bookmarks, `groupFiles`, `transformation_ctx`
- Convert to Spark DataFrame with `.toDF()` when you need Spark SQL or DataFrame-specific operations; convert back with `DynamicFrame.fromDF()`

Key DynamicFrame operations:
- `ApplyMapping` -- rename, cast, and restructure columns
- `ResolveChoice` -- handle columns with mixed data types (cast, make_cols, make_struct, project)
- `Relationalize` -- flatten nested structures into relational tables
- `DropFields` / `SelectFields` -- column projection
- `Filter` -- row-level filtering
- `Join` -- join two DynamicFrames

### Glue for Ray

Distributed Python workloads using the Ray.io framework:
- Python-native processing without Spark overhead
- Libraries: pandas, NumPy, scikit-learn at scale
- Embarrassingly parallel tasks: data validation, inference, file processing
- Z.2X worker types, fully serverless

### Python Shell

Lightweight single-node Python scripts:
- Maximum 1 DPU (G.025X worker)
- Suitable for API calls, small file processing, notification scripts
- $0.44/DPU-hour (0.25 DPU = $0.11/hour)

## DPU and Worker Types

A Data Processing Unit (DPU) provides 4 vCPUs and 16 GB of memory. A Memory-Optimized DPU provides 4 vCPUs and 32 GB of memory.

### Standard Workers (G-series)

| Worker Type | DPUs | vCPUs | Memory | Disk | Use Case |
|---|---|---|---|---|---|
| G.025X | 0.25 | 2 | 4 GB | 64 GB | Python Shell jobs |
| G.1X | 1 | 4 | 16 GB | 94 GB | General-purpose ETL |
| G.2X | 2 | 8 | 32 GB | 138 GB | Memory-intensive transforms |
| G.4X | 4 | 16 | 64 GB | 256 GB | Large dataset processing |
| G.8X | 8 | 32 | 128 GB | 512 GB | ML transforms, heavy computation |
| G.12X | 12 | 48 | 192 GB | 768 GB | Very large memory workloads |
| G.16X | 16 | 64 | 256 GB | 1024 GB | Largest standard workloads |

### Memory-Optimized Workers (R-series)

| Worker Type | DPUs | vCPUs | Memory | Disk | Use Case |
|---|---|---|---|---|---|
| R.1X | 1 | 4 | 32 GB | 94 GB | Memory-intensive with moderate compute |
| R.2X | 2 | 8 | 64 GB | 128 GB | Large in-memory joins and caching |
| R.4X | 4 | 16 | 128 GB | 256 GB | Very large in-memory operations |
| R.8X | 8 | 32 | 256 GB | 512 GB | Extreme memory requirements |

### Auto Scaling (Glue 3.0+)

- Dynamically adds and removes workers based on workload parallelism
- Specify only the maximum number of workers; Glue selects optimal count per stage
- Eliminates manual experimentation for worker count tuning
- Reduces cost by scaling down during low-parallelism phases (e.g., single-partition writes)
- Monitor `glue.driver.ExecutorAllocationManager.executors.numberAllExecutors` to understand utilization

### Flex Execution

For non-urgent batch workloads tolerating delayed starts:
- 34% cost reduction ($0.29/DPU-hour vs $0.44 standard)
- Jobs may wait for available capacity before starting
- Same runtime behavior once execution begins
- Suitable for overnight batch jobs, backfills, non-time-sensitive transforms

## Job Bookmarks

### How Bookmarks Work

Job bookmarks persist state information between job runs for incremental processing:

- **S3 sources**: Track file timestamps and paths already processed. New runs process only files newer than the bookmark.
- **JDBC sources**: Track primary key boundaries (high watermark) of processed rows. New runs query only rows beyond the bookmark.
- **State persistence**: Bookmark state stored in the Glue service, not in the job script.

### Critical Configuration

Every source and sink in the job **must** have a unique `transformation_ctx` string:

```python
# Correct: unique transformation_ctx enables bookmarks
source = glueContext.create_dynamic_frame.from_catalog(
    database="raw_db",
    table_name="orders",
    transformation_ctx="orders_source"
)

# Write with unique context
glueContext.write_dynamic_frame.from_catalog(
    frame=transformed,
    database="curated_db",
    table_name="orders_curated",
    transformation_ctx="orders_sink"
)
```

Omitting `transformation_ctx` silently disables incremental processing for that source/sink.

### Bookmark States

- **Enabled**: Bookmark is active; only new data is processed
- **Disabled**: Bookmark is not used; all data is processed each run
- **Paused**: Bookmark state is retained but not used; useful for testing full reprocessing without losing the bookmark position

### Resetting Bookmarks

```bash
# Reset bookmark for a job (reprocesses all data on next run)
aws glue reset-job-bookmark --job-name my-etl-job
```

## Connections

Connections define how Glue accesses external data stores:

- **JDBC**: RDS, Redshift, Aurora, on-premises databases (MySQL, PostgreSQL, Oracle, SQL Server)
- **MongoDB / DocumentDB**
- **Kafka / Amazon MSK**
- **Network**: VPC endpoints, subnet, and security group configurations
- **Marketplace**: Snowflake, SAP, Salesforce via AWS Marketplace connectors
- **Custom**: Spark connectors packaged as JARs

Connections store VPC configuration (subnet, security groups) and can reference AWS Secrets Manager for credential management.

**VPC networking for JDBC**: Glue creates elastic network interfaces (ENIs) in the specified subnet. The security group must allow all TCP traffic inbound from itself (self-referencing rule) for Spark inter-node communication. A NAT gateway is required for internet access (e.g., reaching public API endpoints).

## Data Quality (DQDL)

### Rule Types

| Category | Example Rule | Purpose |
|---|---|---|
| Completeness | `Completeness "email" > 0.95` | 95%+ non-null values |
| Uniqueness | `IsUnique "customer_id"` | No duplicate values |
| Value constraints | `ColumnValues "status" in ["active","inactive"]` | Allowed values |
| Statistical | `StandardDeviation "amount" < 100` | Statistical bounds |
| Referential | `ReferentialIntegrity "orders.cust_id" "customers.id" > 0.99` | Foreign key integrity |
| Freshness | `DataFreshness "updated_at" <= 24 hours` | Data currency |
| Row count | `RowCount between 1000 and 1000000` | Volume validation |
| Custom SQL | `CustomSql "SELECT COUNT(*) ..." = 1000` | Arbitrary SQL checks |
| Anomaly | `DetectAnomalies ...` | ML-based pattern detection |

### Integration

- Visual transform node in Glue Studio
- Programmatic API in ETL scripts
- Results published to CloudWatch for alerting
- Quality scores visible in Data Catalog table properties
- Auto-recommendation engine profiles data and suggests rules

## Open Table Format Support (Glue 5.x)

**Apache Iceberg**: ACID transactions, time travel, schema evolution. Format v3 (Glue 5.1): deletion vectors, default columns, row lineage. Fine-grained Lake Formation access control.

**Apache Hudi**: Copy-on-write and merge-on-read table types. Incremental processing, record-level updates/deletes.

**Delta Lake**: ACID transactions, schema enforcement, time travel, data versioning.

## Security

- **IAM roles**: Per-job execution roles with least-privilege policies
- **AWS Lake Formation**: Fine-grained column- and row-level access control on Data Catalog tables
- **Encryption**: SSE-S3, SSE-KMS at rest; TLS in transit; encryption of job bookmarks and connection passwords
- **VPC support**: ENIs in customer VPCs for private data store access
- **CloudTrail**: Audit logging for all Glue API calls
- **Resource policies**: Cross-account Data Catalog access
- **Sensitive data detection**: Automatic PII identification across 50+ entity types with redact/mask/hash remediation

## Pricing

| Component | Unit | Rate (US East) |
|---|---|---|
| ETL Jobs (Standard) | DPU-hour | $0.44 |
| ETL Jobs (Flex) | DPU-hour | $0.29 |
| Interactive Sessions | DPU-hour | $0.44 |
| Data Catalog Storage | Per 100K objects/month | $1.00 (first 1M free) |
| Data Catalog Requests | Per 1M requests/month | $1.00 (first 1M free) |
| Crawlers | DPU-hour | $0.44 |
| DataBrew | Node-hour | $0.48 |

Billing: per-second with 1-minute minimum (Glue 3.0+), 10-minute minimum for Glue 2.0.
