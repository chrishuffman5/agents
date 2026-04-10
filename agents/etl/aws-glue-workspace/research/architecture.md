# AWS Glue Architecture

## Overview

AWS Glue is a fully managed, serverless ETL (Extract, Transform, Load) service that provides data integration, data cataloging, and job orchestration capabilities. It eliminates the need to provision, configure, or manage infrastructure for data processing workloads.

---

## Core Components

### AWS Glue Data Catalog

The Data Catalog is a centralized, persistent metadata repository -- one per AWS account per region. It serves as a drop-in replacement for the Apache Hive Metastore.

**Structure:**
- **Databases** -- logical groupings of table definitions
- **Tables** -- metadata definitions describing the schema, location, format, and properties of data stored in S3, JDBC sources, or other data stores
- **Partitions** -- subdivisions of a table based on column values (e.g., `year=2025/month=08/day=15`)
- **Connections** -- Data Catalog objects containing properties required to connect to a particular data store (JDBC endpoints, credentials via Secrets Manager, VPC/subnet/security-group config)
- **User-Defined Functions** -- custom functions registered in the catalog for use in ETL scripts

**Integration Points:**
- Amazon Athena, Amazon Redshift Spectrum, and Amazon EMR can query directly against the Data Catalog
- AWS Lake Formation extends the catalog with fine-grained access control
- CloudTrail provides audit logging for all catalog operations

### AWS Glue Crawlers

Crawlers are automated programs that connect to data stores, infer schemas, and populate or update the Data Catalog.

**Crawler Workflow:**
1. Connect to the source data store (S3, JDBC, DynamoDB, MongoDB, etc.)
2. Walk through the data, reading the first megabyte of each file to classify format
3. Apply classifiers in priority order to determine data format and schema
4. Group compatible schemas and create/update table definitions in the Data Catalog
5. Automatically create partition indexes for S3 and Delta Lake targets

**Crawler Scheduling:**
- On-demand execution
- Scheduled (cron-based) runs
- Event-driven via EventBridge (e.g., trigger on S3 object creation)

### AWS Glue Classifiers

Classifiers determine the schema of data encountered by crawlers. They are evaluated in priority order until one succeeds.

**Built-in Classifiers:**
- CSV, JSON, Avro, Parquet, ORC, XML, Ion
- JDBC-based classifiers for relational databases
- Grok patterns for semi-structured logs

**Custom Classifiers:**
- **Grok classifiers** -- pattern-based matching for log files and unstructured text
- **XML classifiers** -- match XML data using a row tag
- **JSON classifiers** -- match JSON data using a JSON path
- **CSV classifiers** -- custom delimiters, quote characters, and header handling

---

## ETL Engine

### Glue Spark Runtime

AWS Glue ETL jobs run on a managed Apache Spark environment. The runtime evolves through versioned releases:

| Version | Spark | Python | Java | Key Additions |
|---------|-------|--------|------|---------------|
| Glue 2.0 | 2.4 | 3.7 | 8 | Auto-scaling foundations, start-time improvements |
| Glue 3.0 | 3.1 | 3.7 | 8 | Auto Scaling, optimized shuffle, small file grouping |
| Glue 4.0 | 3.3 | 3.10 | 8 | Optimized Spark runtime, improved start times |
| Glue 5.0 | 3.5.4 | 3.11 | 17 | Native S3 access, Iceberg 1.7, Hudi 0.15, Delta Lake 3.3 |
| Glue 5.1 | 3.5.6 | 3.11 | 17 | Iceberg format v3, S3A default connector, Hudi 1.0.2, Iceberg 1.10, Delta Lake 3.3.2 |

**Glue DynamicFrame:**
AWS Glue extends Spark with the DynamicFrame API, which handles schema inconsistencies (e.g., mixed types in the same column) without requiring upfront schema definition. DynamicFrames integrate with the Data Catalog and support Glue-specific features like job bookmarks and data grouping.

### Glue for Ray

AWS Glue for Ray enables distributed Python workloads using the Ray.io open-source compute framework. It is designed for:
- Python-native data processing without Spark overhead
- Workloads using libraries like pandas, NumPy, scikit-learn at scale
- Embarrassingly parallel tasks such as data validation, inference, or file processing

Ray jobs use Z.2X worker types and are fully serverless with no infrastructure management.

### Glue Streaming ETL

Built on Apache Spark Structured Streaming, Glue streaming jobs run continuously and consume data from:
- Amazon Kinesis Data Streams
- Apache Kafka (self-managed or Amazon MSK)

Streaming jobs support windowed aggregations, micro-batch processing, checkpointing, and writing to data lakes in open table formats (Hudi, Iceberg, Delta Lake) for near-real-time analytics.

---

## Job System

### ETL Jobs

Jobs are the core execution units in AWS Glue. Each job encapsulates:
- **Script** -- PySpark, Scala, or Python (for Shell/Ray jobs)
- **IAM Role** -- permissions for accessing data stores and resources
- **Worker Configuration** -- type and number of workers (DPUs)
- **Connections** -- references to Data Catalog connection objects
- **Job Parameters** -- key-value pairs passed at runtime
- **Timeout and Retry Settings** -- max execution time and retry count

**Job Types:**
- **Spark** -- distributed ETL using Apache Spark
- **Spark Streaming** -- continuously running Spark Structured Streaming
- **Python Shell** -- lightweight single-node Python scripts (1 DPU max)
- **Ray** -- distributed Python using Ray framework

### DPU and Worker Types

A Data Processing Unit (DPU) provides 4 vCPUs and 16 GB of memory. A Memory-Optimized DPU (M-DPU) provides 4 vCPUs and 32 GB of memory.

**Standard Workers (G-series):**

| Worker Type | DPUs | vCPUs | Memory | Disk | Use Case |
|-------------|------|-------|--------|------|----------|
| G.025X | 0.25 | 2 | 4 GB | 64 GB | Python Shell jobs |
| G.1X | 1 | 4 | 16 GB | 94 GB | General-purpose ETL |
| G.2X | 2 | 8 | 32 GB | 138 GB | Memory-intensive transforms |
| G.4X | 4 | 16 | 64 GB | 256 GB | Large dataset processing |
| G.8X | 8 | 32 | 128 GB | 512 GB | ML transforms, heavy computation |
| G.12X | 12 | 48 | 192 GB | 768 GB | Very large memory workloads |
| G.16X | 16 | 64 | 256 GB | 1024 GB | Largest standard workloads |

**Memory-Optimized Workers (R-series):**

| Worker Type | DPUs | vCPUs | Memory | Disk | Use Case |
|-------------|------|-------|--------|------|----------|
| R.1X | 1 | 4 | 32 GB | 94 GB | Memory-intensive with moderate compute |
| R.2X | 2 | 8 | 64 GB | 128 GB | Large in-memory joins and caching |
| R.4X | 4 | 16 | 128 GB | 256 GB | Very large in-memory operations |
| R.8X | 8 | 32 | 256 GB | 512 GB | Extreme memory requirements |

**Ray Workers:**

| Worker Type | Use Case |
|-------------|----------|
| Z.2X | Ray distributed Python jobs |

### Job Bookmarks

Job bookmarks persist state information between job runs to enable incremental processing. They track:
- **S3 sources** -- file timestamps and paths already processed
- **JDBC sources** -- primary key boundaries of processed rows
- **Transformation context** -- each source/sink in the job must have a unique `transformation_ctx` string for bookmarks to function correctly

Bookmark states: `enabled`, `disabled`, or `paused` (retain state but do not use it).

### Glue Studio Visual ETL

AWS Glue Studio provides a graphical drag-and-drop interface for building ETL jobs:

**Visual Canvas Components:**
- **Source nodes** -- S3, JDBC, Kinesis, Kafka, Data Catalog tables
- **Transform nodes** -- ApplyMapping, Filter, Join, SelectFields, DropFields, RenameField, Spigot, SQL Query, Custom Code, and more
- **Target nodes** -- S3, JDBC, Data Catalog tables

**Additional Capabilities:**
- Real-time data preview during job authoring
- Output schema inspection at each node
- Code generation (auto-generates PySpark/Scala from the visual DAG)
- Version control integration
- Embedded DataBrew recipe nodes
- Data quality transform nodes

### Connections

Connections define how Glue accesses external data stores:
- **JDBC** -- RDS, Redshift, Aurora, on-prem databases (MySQL, PostgreSQL, Oracle, SQL Server)
- **MongoDB / DocumentDB**
- **Kafka / Amazon MSK**
- **Network** -- VPC endpoints, subnet, and security group configurations
- **Marketplace** -- connectors from AWS Marketplace (Snowflake, SAP, Salesforce, etc.)
- **Custom** -- Spark connectors packaged as JARs

Connections store VPC configuration (subnet, security groups) and can reference AWS Secrets Manager for credential management.

---

## Orchestration and Scheduling

### Triggers

Triggers initiate job runs based on:
- **Scheduled** -- cron expressions
- **Conditional** -- job/crawler completion events (success/failure/any)
- **On-demand** -- manual or API-driven

### Workflows

Workflows chain multiple crawlers and jobs into a single execution graph with dependency management. They provide:
- Visual DAG representation
- Run history and status tracking
- Parameterization across the workflow

### EventBridge Integration

AWS Glue publishes events to Amazon EventBridge for job state changes, crawler completions, and Data Catalog updates, enabling event-driven architectures.

---

## Security and Governance

- **IAM roles** -- per-job execution roles with least-privilege policies
- **AWS Lake Formation** -- fine-grained column- and row-level access control on Data Catalog tables
- **Encryption** -- SSE-S3, SSE-KMS for data at rest; TLS for data in transit; encryption of job bookmarks and connection passwords
- **VPC support** -- elastic network interfaces in customer VPCs for accessing private data stores
- **CloudTrail** -- audit logging for all API calls
- **Resource policies** -- cross-account Data Catalog access

---

## Pricing Model

| Component | Unit | Rate (US East) |
|-----------|------|----------------|
| ETL Jobs (Standard) | DPU-hour | $0.44 |
| ETL Jobs (Flex) | DPU-hour | $0.29 |
| Interactive Sessions | DPU-hour | $0.44 |
| Data Catalog Storage | Per 100K objects/month | $1.00 (first million free) |
| Data Catalog Requests | Per million requests | $1.00 (first million free) |
| Crawlers | DPU-hour | $0.44 |
| DataBrew | Node-hour | $0.48 |

Billing is per-second with a minimum of 1 minute for interactive sessions and 10 minutes for batch jobs (1 minute for Glue 3.0+).
