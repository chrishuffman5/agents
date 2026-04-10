# AWS Glue Features

## Current Capabilities (as of early 2026)

---

## Glue Spark Runtime Versions

### Glue 4.0

Released at AWS re:Invent 2022, Glue 4.0 brought:
- Apache Spark 3.3.0 with an optimized AWS Glue runtime
- Python 3.10 support
- Faster job start times (reduced cold-start overhead)
- Improved support for open table formats
- Enhanced JDBC connectivity and Spark SQL compatibility
- Support in Glue Studio notebooks and interactive sessions

### Glue 5.0

Released in January 2025:
- Apache Spark 3.5.4, Python 3.11, Java 17
- Native S3 access with performance improvements
- Automatic partition pruning
- Open table format library updates: Apache Iceberg 1.7.1, Apache Hudi 0.15.0, Delta Lake 3.3.0
- Upgraded analytics and ML libraries

### Glue 5.1

Released in November 2025, expanded to 18 additional regions in February 2026:
- Apache Spark 3.5.6, Python 3.11, Scala 2.12.18
- **Apache Iceberg format version 3.0** -- default column values, deletion vectors for merge-on-read tables, multi-argument transforms, row lineage tracking
- Open table format updates: Iceberg 1.10.0, Hudi 1.0.2, Delta Lake 3.3.2
- S3A as the default S3 connector (aligned with Amazon EMR)
- Spark-native fine-grained access control with AWS Lake Formation for writes to Iceberg and Hive tables
- Full-Table Access (FTA) support extended to Apache Hudi and Delta Lake tables
- Integration with Amazon SageMaker Unified Studio (March 2026)

---

## Interactive Sessions

Interactive sessions provide a live, managed Spark environment for iterative development.

**Key Features:**
- Start in seconds (sub-minute provisioning)
- Native Jupyter notebook integration through Glue Studio notebooks
- Support for PySpark, Scala, and Python kernels
- Auto Scaling support (added October 2024)
- Default 5 DPU allocation, configurable up or down
- Idle timeout with automatic session termination
- Per-second billing (minimum 1 minute)

**Use Cases:**
- Prototyping ETL logic before deploying as a scheduled job
- Debugging data quality issues interactively
- Exploratory data analysis on data lake contents
- Testing schema transformations against sample data

**Magic Commands:**
- `%glue_version` -- set Glue version
- `%worker_type` -- configure worker type
- `%number_of_workers` -- set worker count
- `%idle_timeout` -- configure auto-stop timer
- `%connections` -- specify Data Catalog connections

---

## AWS Glue Data Quality

Built on the open-source DeeQu framework, Glue Data Quality provides automated rule-based and ML-based data validation.

### Data Quality Definition Language (DQDL)

A domain-specific language for writing data quality rules:

**Rule Categories:**
- **Completeness** -- `Completeness "column_name" > 0.95` (95% non-null)
- **Uniqueness** -- `IsUnique "id_column"`
- **Value Constraints** -- `ColumnValues "status" in ["active", "inactive"]`
- **Statistical** -- `StandardDeviation "amount" < 100`
- **Referential** -- `ReferentialIntegrity "orders.customer_id" "customers.id" > 0.99`
- **Freshness** -- `DataFreshness "timestamp_col" <= 24 hours`
- **Row-level** -- `RowCount between 1000 and 1000000`
- **Custom SQL** -- `CustomSql "SELECT COUNT(*) FROM primary_table" = 1000`

**Advanced DQDL Features (2025):**
- `NOT` operator for rule negation
- `WHERE` clause for conditional rule application
- Composite rules combining multiple conditions
- File-centric checks for freshness and uniqueness
- Rule labeling for strategic quality management
- Preprocessing queries for complex datasets

### ML-Powered Anomaly Detection

- `DetectAnomalies` rule type learns historical patterns and flags deviations
- Time-series forecasting predicts expected statistic ranges
- Detects seasonality shifts, unexpected surges, and gradual drift
- Automatically collects and stores evaluated values over successive runs
- Triggers alerts when new data points fall outside predicted bounds

### Data Quality Integration Points

- Embedded in Glue Studio visual ETL as a transform node
- Available in ETL scripts via API
- Results published to CloudWatch for alerting
- Quality scores visible in Data Catalog table properties
- Recommendation engine auto-suggests rules based on data profiling

---

## AWS Glue DataBrew

A visual, no-code data preparation tool for data analysts and data scientists.

**Core Features:**
- **250+ built-in transformations** -- cleaning, normalization, aggregation, pivoting, transposing
- **Interactive data profiling** -- automatic statistical summaries, distribution analysis, and correlation detection
- **Project-based workflow** -- connect to data, explore visually, build transformation recipes, publish to datasets
- **Recipe system** -- reusable, versioned transformation sequences that can be applied to new incoming data

**Data Source Support:**
- Amazon S3 (CSV, JSON, Parquet, ORC, Excel, etc.)
- Amazon Redshift
- Amazon Aurora, Amazon RDS
- AWS Glue Data Catalog tables

**Integration with Glue Studio:**
- DataBrew recipes can be used as nodes in Glue Studio visual ETL jobs
- Enables data analysts to author transformation logic that data engineers incorporate into production pipelines

**Scheduling and Automation:**
- Recipe jobs can be scheduled independently
- Output to S3 in various formats with partitioning options
- Integration with Step Functions for workflow orchestration

---

## Sensitive Data Detection

- Automatically identifies PII (SSNs, credit card numbers, email addresses, phone numbers, etc.)
- Supports detection across 50+ PII entity types
- Remediation actions: redact, mask, SHA-256 hash, or report
- Integrated with AWS Lake Formation for governance workflows
- Available as a transform in Glue Studio visual ETL

---

## Auto Scaling

Available for Glue 3.0+ ETL, streaming, and interactive session jobs:
- Dynamically adds and removes workers based on workload parallelism
- Specify only the maximum number of workers; Glue selects the optimal count per stage
- Eliminates manual experimentation for worker count tuning
- Particularly effective for jobs with varying data volumes across stages
- Reduces cost by avoiding over-provisioning during low-parallelism phases

---

## Flex Execution

For non-urgent, batch ETL workloads that can tolerate delayed start times:
- 34% cost reduction ($0.29/DPU-hour vs $0.44 standard)
- Jobs may wait for available capacity before starting
- Same runtime behavior once execution begins
- Suitable for overnight batch jobs, backfills, and non-time-sensitive transforms

---

## Streaming ETL

Built on Spark Structured Streaming:
- **Sources:** Kinesis Data Streams, Apache Kafka, Amazon MSK
- **Processing:** Micro-batch or continuous processing modes, windowed aggregations, stateful operations
- **Targets:** S3, JDBC, Data Catalog tables, open table formats (Hudi, Iceberg, Delta Lake)
- **Checkpointing:** Automatic state management for fault tolerance
- **Auto Scaling:** Dynamic worker scaling based on stream throughput
- **Integration with CDC:** Works with AWS DMS for change data capture pipelines -- stream database changes through Kinesis into Glue for near-real-time data lake updates

---

## Open Table Format Support

Glue 5.x provides native integration with all three major open table formats:

**Apache Iceberg:**
- ACID transactions, time travel, schema evolution
- Format v3 support (Glue 5.1): deletion vectors, default column values, row lineage
- Fine-grained access control via Lake Formation

**Apache Hudi:**
- Copy-on-write and merge-on-read table types
- Incremental processing, record-level updates/deletes
- Full-Table Access support (Glue 5.1)

**Delta Lake:**
- ACID transactions, schema enforcement
- Time travel and data versioning
- Full-Table Access support (Glue 5.1)

---

## Zero-ETL Integration

AWS Glue supports Zero-ETL patterns for real-time data synchronization:
- Direct integration between operational databases and analytics engines
- Eliminates the need to build and maintain custom ETL pipelines for certain use cases
- Available for Aurora-to-Redshift, DynamoDB-to-Redshift, and other managed service pairs

---

## Generative AI Script Generation

Glue Studio includes AI-assisted script generation:
- Natural language to PySpark/Scala code conversion
- AI-recommended data quality rules
- Automated transformation suggestions based on source and target schemas

---

## Additional Capabilities

- **Job bookmarks** -- incremental processing with persistent state
- **Classifiers** -- built-in and custom format detection for crawlers
- **Workflows** -- DAG-based orchestration of crawlers and jobs
- **Triggers** -- scheduled, conditional, or on-demand job execution
- **Blueprint** -- reusable ETL workflow templates
- **Schema Registry** -- Avro/JSON schema management for streaming data
- **FindMatches ML Transform** -- fuzzy deduplication and record linkage using ML
