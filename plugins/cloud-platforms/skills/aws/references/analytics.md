# AWS Analytics Service Selection Reference

> Athena, Glue, Lake Formation, EMR, Kinesis/Firehose/MSK, Amazon Quick, OpenSearch Service, and the canonical S3 data-lake composition. Selection level only.
>
> Glue job tuning, DPU sizing, DynamicFrames, and crawler internals belong to the `aws-glue` skill in `etl`. Redshift depth belongs to `database:redshift`; OpenSearch query DSL and cluster tuning to `database:opensearch`; Kafka operations to `messaging:kafka`.

---

## Query and Catalog Layer

### Amazon Athena

> Source: https://docs.aws.amazon.com/athena/latest/ug/what-is.html, https://docs.aws.amazon.com/athena/latest/ug/when-should-i-use-ate.html, https://aws.amazon.com/athena/pricing/ (official)

"Amazon Athena is an interactive query service that makes it easy to analyze data directly in Amazon Simple Storage Service (Amazon S3) using standard SQL." No loading step, no infrastructure. Athena also runs Apache Spark notebooks serverlessly. Supported inputs: CSV, JSON, and columnar formats such as Parquet and ORC.

**When to choose it, verbatim:** "You should use Amazon Athena if you want to run interactive ad hoc SQL queries against data on Amazon S3, without having to manage any infrastructure or clusters."

**Pricing:** **$5 per TB of data scanned** for standard SQL, billed on bytes scanned rounded up to the nearest MB with a **10 MB minimum per query**. Federated queries use the same model aggregated across sources. **Provisioned capacity is $0.30 per DPU-hour**; **Apache Spark on Athena is $0.35 per DPU-hour**. DDL statements, partition management, and failed queries are not charged. S3 storage/request charges and Glue Data Catalog usage are separate.

**The cost lever that matters most:** Athena bills on bytes *scanned*, not bytes *returned*. Compression plus columnar format plus partitioning is the whole optimization. AWS's own worked example for converting to compressed Parquet: "3x savings from compression and 4x savings for reading only one column." A raw-CSV data lake with expensive Athena queries has a missing format-transformation step, not a query problem.

### AWS Glue

> Source: https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html (official)

"AWS Glue is a serverless data integration service that makes it easy for analytics users to discover, prepare, move, and integrate data from multiple sources." It fills two roles the exams and most architectures treat separately:

1. **Data Catalog** — the persistent, **Hive Metastore-compatible** metadata repository. Once tables are registered, "You can immediately search and query cataloged data using Amazon Athena, Amazon EMR, and Amazon Redshift Spectrum."
2. **ETL engine** — Spark-based (DynamicFrames) or Ray-based jobs, authored visually in Glue Studio or by code, with triggers and workflows.

**Crawlers** are the automated schema-discovery mechanism: they connect to a store, infer schema and statistics, and populate the Data Catalog. Run them on a schedule so new partitions and schema drift are picked up — "Athena returns no rows for data that is definitely in S3" is almost always a missing or stale crawler run.

### AWS Lake Formation

> Source: https://docs.aws.amazon.com/lake-formation/latest/dg/what-is-lake-formation.html (official)

"AWS Lake Formation helps you centrally govern, secure, and globally share data for analytics and machine learning. With Lake Formation, you can manage fine-grained access control for your data lake data on Amazon S3 and its metadata in AWS Glue Data Catalog."

**What it adds over Glue Data Catalog plus IAM** — the question to be able to answer directly. The catalog alone is metadata; access to the underlying S3 objects is governed by IAM and bucket policies, which stop at the prefix level. Lake Formation adds a second permissions model on top:

- **Fine-grained access below the table level** — "granular controls at the column, row, and cell-levels across AWS analytics and machine learning services, including Amazon Athena, Amazon Quick, Amazon Redshift Spectrum, Amazon EMR, and AWS Glue." IAM cannot express this.
- **Grant/revoke semantics "much like a relational database management system"** — grant `SELECT` on named columns to a principal instead of maintaining path-based IAM policies per consumer.
- **LF-Tags (tag-based access control)** — manage "hundreds or even thousands of data permissions" through a small number of logical tags on databases, tables, and columns.
- **Cross-account and cross-organization sharing** of catalog metadata and underlying data **without copying it**.
- **Hybrid access mode** — onboard Lake Formation permissions table by table while others stay on plain IAM, avoiding a big-bang cutover.
- **Centralized CloudTrail audit** of "which users or roles have attempted to access what data, with which services, and when," across every integrated service.
- **Multi-level federated catalogs** — register Redshift namespaces, DynamoDB, on-premises RDBMS via JDBC, and third-party sources into the same catalog under the same permission model, without migrating the data.

**Selection rule:** reach for Lake Formation specifically when IAM and S3 policies are too coarse — when different consumers need different column or row visibility into the *same* table, or when access must be centrally audited and shared across accounts. **If every consumer may see the whole table and bucket policies express that cleanly, Lake Formation is not required to run Glue plus Athena.**

### AWS Data Exchange

> Source: https://docs.aws.amazon.com/data-exchange/latest/userguide/what-is.html (official)

"AWS Data Exchange is a service that helps AWS customers easily share and manage data entitlements from other organizations at scale." A third-party data marketplace and entitlement mechanism, not an internal catalog or ETL tool: providers publish data grants or Marketplace data products; receivers subscribe and query with compatible analytics services. Five dataset types: Files, API, Amazon Redshift, Amazon S3, and (preview) AWS Lake Formation data-permission datasets — the last lets a receiver query a provider's governed lake without copying it.

**Choose it when the data need is external** (acquiring or publishing third-party datasets), in contrast with Glue (internal ETL and cataloging) and Lake Formation (internal governance).

---

## Streaming Ingestion

> Source: https://docs.aws.amazon.com/decision-guides/latest/analytics-on-aws-how-to-choose/analytics-on-aws-how-to-choose.html (official)

AWS's one-line positioning:

- **Kinesis Data Streams** — "Optimized for rapid and continuous data intake and aggregation, including IT infrastructure log data, application logs, social media, market data feeds, and web clickstream data."
- **Amazon Data Firehose** — "Optimized for delivering real-time streaming data to destinations such as Amazon S3, Amazon Redshift, OpenSearch Service, Splunk, Apache Iceberg Tables, and any custom HTTP endpoint."
- **Amazon MSK** — "Optimized for using Apache Kafka data-plane operations and running open source versions of Apache Kafka."

**The load-bearing distinction:** Kinesis Data Streams and MSK are **stream stores you write a consumer against** — the data waits until a consumer reads it. **Data Firehose is a managed delivery pipe with nothing to read from** — it buffers and lands data at a destination automatically, and there is no consumer application to write. Choosing Firehose when the requirement is "multiple applications process the same events" is the most common mis-selection in this area.

### Kinesis Data Streams

> Source: https://docs.aws.amazon.com/streams/latest/dev/introduction.html and https://docs.aws.amazon.com/streams/latest/dev/how-do-i-size-a-stream.html (official)

Producers write records; multiple independent consumer applications read the same stream concurrently. Put-to-get delay is "typically less than 1 second."

| Mode | Capacity planning | Best fit |
|---|---|---|
| **On-demand Standard** | None — auto-scales to gigabytes per minute of write and read | Unpredictable or highly variable traffic |
| **On-demand Advantage** | None — account-level, adds proactive warm-throughput pre-scaling; ingest/retrieval/extended-retention pricing "at least 60% lower" | Sustained usage at 25 MiB/s or more on both ingest and retrieval, many fan-out consumers, or hundreds of streams |
| **Provisioned** | Manual shard count via `UpdateShardCount` | Predictable, forecastable traffic; need shard-level control of data distribution |

Documented limits: on-demand "accommodates up to double the peak write throughput observed in the previous 30 days" and auto-splits a shard when incoming traffic exceeds **500 KB/s**; **a single partition key is capped at 1 MB/s and 1,000 records/second even in on-demand mode** — uneven partition keys still throttle, and manual shard splitting in provisioned mode is the fix. **Enhanced Fan-Out supports up to 20 consumer applications** per stream in standard on-demand, raised to **50** under On-demand Advantage. Streams can switch between on-demand and provisioned **twice within 24 hours**.

Provisioned sizing formula: `shards = ceiling(max(write_KiB/1024, read_KiB/2048))`.

### Amazon Data Firehose

> Source: https://docs.aws.amazon.com/firehose/latest/dev/what-is-this-service.html and https://aws.amazon.com/firehose/pricing/ (official)

"You configure your data producers to send data to Amazon Data Firehose, and it automatically delivers the data to the destination that you specified." Optional inline transformation (typically Lambda) before delivery.

Destinations: S3, Redshift, OpenSearch Service, OpenSearch Serverless, Splunk, **Apache Iceberg Tables**, and custom or supported third-party HTTP endpoints (Datadog, Dynatrace, LogicMonitor, MongoDB, New Relic, Coralogix, Elastic).

Mechanics: a Firehose stream buffers by **buffer size (MB)** or **buffer interval (seconds)** before flushing — which is exactly why there is no read-side API. It can also read from an existing Kinesis Data Stream instead of direct-PUT producers. Max record size **1,000 KB**.

Pricing by source: **$0.029/GB** ingested for Direct PUT or Kinesis source (first 500 TB/month, billed in 5 KB increments); **$0.055/GB** for MSK source (no rounding, billed on the higher of ingested versus delivered); **$0.13/GB** for Vended Logs. Add-ons: format conversion (JSON to Parquet/ORC) **+$0.018/GB**; dynamic partitioning **+$0.020/GB** plus $0.005 per 1,000 S3 objects (plus $0.07 per JQ-processing-hour if JQ is used); VPC delivery **+$0.01/GB plus $0.01 per AZ-hour**. Destination surcharges: Snowflake $0.071/GB, Apache Iceberg Tables $0.045/GB from a Kinesis source.

### Amazon MSK

> Source: https://docs.aws.amazon.com/msk/latest/developerguide/what-is-msk.html and https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html (official)

"It runs open-source versions of Apache Kafka. This means existing applications, tooling, and plugins from partners and the Apache Kafka community are supported without requiring changes to application code." AWS manages control-plane operations (cluster lifecycle, broker failure detection and replacement); you use unmodified Kafka data-plane operations.

Architecture: broker nodes with a minimum of one per AZ, coordinated by legacy ZooKeeper or the newer **KRaft controllers** (included at no extra cost).

**Provisioned versus Serverless:** "MSK Serverless is a cluster type... that makes it possible for you to run Apache Kafka without having to manage and scale cluster capacity. It automatically provisions and scales capacity while managing the partitions in your topic... Consider using a serverless cluster if your applications need on-demand streaming capacity that scales up and down automatically." **MSK Serverless requires IAM access control for all clusters — Apache Kafka ACLs are not supported**, unlike Provisioned. Provisioned offers Standard and Express broker types for manually sized dedicated capacity.

### Kinesis versus MSK — AWS's own rule

> Source: https://aws.amazon.com/kinesis/data-streams/faqs/ (official)

Quoted directly: **"If you are new to streaming technologies, use Kinesis Data Streams."** **"If you have a preference for using open-source technologies, our recommendation is to use MSK."** Both are "scalable, secure, and highly available" and cover overlapping use cases — **the differentiator is operational preference (AWS-native simplicity versus Kafka-ecosystem compatibility and portability), not raw capability.**

---

## Processing and Consumption

### Amazon EMR — when it beats Glue

> Source: https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-what-is-emr.html and https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-overview-benefits.html (official)

"Amazon EMR... is a managed cluster platform that simplifies running big data frameworks, such as Apache Hadoop and Apache Spark, on AWS to process and analyze vast amounts of data."

**When to choose EMR, verbatim:** "You should use Amazon EMR if you use custom code to process and analyze extremely large datasets with the latest big data processing frameworks such as Spark, Hadoop, Presto, or Hbase. **Amazon EMR gives you full control over the configuration of your clusters and the software installed on them.**"

**The split versus Glue:** the official decision guide optimizes Glue for **"Data catalog"** and EMR for **"Big data processing — processing, moving, and transforming large amounts of data."** Reach for Glue when the job is serverless, catalog-centric ETL with minimal tuning surface. Reach for EMR when you need custom code across the Hadoop/Spark/Presto/Trino/HBase ecosystem, cluster-level configuration control, or compute-intensive frameworks (ML, graph analytics) beyond Glue's job model. **They are not exclusive** — the Glue Data Catalog "is a drop-in replacement for the Apache Hive Metastore for Big Data applications running on Amazon EMR," so both query the same catalog.

**Deployment surfaces:** **EMR on EC2** (you pick instance types for primary, core, and task nodes), **EMR Serverless** (sized per job), **EMR on EKS** (on an existing Kubernetes cluster).

**Storage choice is architectural:** **HDFS** is local to the cluster and disappears when it terminates; **EMRFS** is S3-backed and decouples compute from storage lifecycle — "you can scale your compute needs by resizing your cluster and you can scale your storage needs by using Amazon S3." Choose EMRFS unless you have a demonstrated need for local HDFS performance.

**Lifecycle modes:** **transient** clusters auto-terminate after their steps complete (the cost-efficient default for batch); **long-running** clusters stay up for interactive use and are terminated manually.

**Cost trap AWS calls out explicitly:** an EMR cluster in a private subnet **without an S3 VPC endpoint incurs NAT Gateway charges for all S3 traffic between the cluster and its data** — the same NAT pitfall covered in `references/cost.md`, and it is expensive at data-lake volumes. Spot instances can reduce EMR cost to "as low as a tenth of on-demand pricing in some cases."

### Amazon Quick (formerly QuickSight)

> Source: https://docs.aws.amazon.com/quicksight/latest/user/welcome.html, https://docs.aws.amazon.com/quicksight/latest/user/spice.html, https://aws.amazon.com/quick/quicksight/pricing/ (official)

**Naming, current:** "Amazon Quick evolved from Amazon QuickSight. QuickSight continues as Amazon Quick Sight, a feature within Quick. **All existing QuickSight APIs, SDKs, and integrations continue to work without changes.**" Quick Sight is one of six Quick capabilities; the rest are newer AI-agent features outside BI scope. Certification service lists now name it "Amazon Quick."

The BI layer reads directly from Athena, Redshift Spectrum, S3, and many other sources, and is optimized for "Dashboards and visualizations... visually representing complex datasets, and providing natural language query of your data."

**SPICE** — "the robust in-memory engine that Amazon Quick Sight uses." Importing a dataset (rather than querying it directly) makes it SPICE data, so dashboards hit the in-memory copy. The cost-relevant benefit: **"data stored in SPICE can be reused multiple times without incurring additional costs"**, versus a per-query-charged source such as Athena where every dashboard view bills again.

SPICE capacity mechanics: allocated **per Region and shared by all users in the account/Region**; a default allocation lands in the home Region and other Regions start at zero. Logical size is computed post-transformation — decimals and dates cost 8 bytes per cell plus 4 bytes overhead; **strings cost their UTF-8 length plus 24 bytes overhead**, making string-heavy datasets the most expensive to hold.

**Pricing:** Author **$24/user/month**, Author Pro **$40**; every provisioned Author includes a **10 GB SPICE allocation**. Reader **$3/user/month** (or $250/month for 500 reader sessions), Reader Pro **$20**. SPICE beyond the included allocation: **$0.38/GB-month**. Standard Edition (self-serve via API) $9/user/month annual or $12 monthly with 10 GB SPICE per user. Enterprise Edition is quote-based. A **$250/month infrastructure fee** applies once an account has Pro users or Q&A enabled.

**Decision rule:** the 8x gap between Author ($24) and Reader ($3) makes **role assignment the single biggest Quick cost lever** — the same shape as DynamoDB capacity mode elsewhere in this skill. Provision Authors only for people who build dashboards.

### Amazon OpenSearch Service

> Source: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/what-is.html (official)

"Amazon OpenSearch Service is a managed service that makes it easy to deploy, operate, and scale OpenSearch clusters in the AWS Cloud... It also automatically detects and replaces failed OpenSearch Service nodes." A **domain** is a cluster. Supports current OpenSearch and legacy Elasticsearch OSS up to 7.10. Use cases: "log analytics, real-time application monitoring, and clickstream analysis." Scale ceiling: **up to 1,002 data nodes and 25 PB** of attached storage, with **UltraWarm** and **cold storage** tiers for read-mostly data.

**Managed versus self-managed, AWS's own table:** choose self-managed when you have staff to monitor and maintain clusters, need compile-level code control, require open-source-only software, need a multi-cloud non-vendor-specific strategy, or want immediate access to new upstream features. Choose the managed service when you do not want to manage infrastructure, want tiered S3-backed storage cost management, want native AWS integrations (DynamoDB, DocumentDB, IAM, CloudWatch, CloudFormation), want AWS Support, or want self-healing, proactive maintenance, and backups included.

In the analytics pipeline it is a **Data Firehose delivery destination** and integrates with Kinesis Data Streams — the common shape is *Kinesis or Firehose -> OpenSearch Service -> OpenSearch Dashboards* for near-real-time log and clickstream search, running parallel to the *S3 -> Glue/Athena* shape for batch and interactive SQL. Pricing is instance-hour plus attached EBS storage plus standard data transfer, with cross-AZ and UltraWarm/cold-to-S3 transfer **not** billed.

---

## The Canonical S3 Data Lake

> Source: https://aws.amazon.com/what-is/data-lake/, https://docs.aws.amazon.com/whitepapers/latest/big-data-analytics-options/example-1-queries-against-an-amazon-s3-data-lake.html, https://docs.aws.amazon.com/decision-guides/latest/analytics-on-aws-how-to-choose/analytics-on-aws-how-to-choose.html (official)

A data lake is "a centralized repository that allows you to store all your structured and unstructured data at any scale. You can store your data as-is, without having to first structure the data." The failure mode is a **data swamp** — a lake with no oversight of what is stored, how it is cataloged, and who can reach it. That is precisely the gap Lake Formation closes.

```
Ingestion   batch (Glue ETL jobs, DataSync)  OR  streaming (Kinesis Data Streams / Firehose / MSK)
                |
Storage     Amazon S3 (Standard -> IA -> Glacier via lifecycle) | S3 Tables for Apache Iceberg
                |
Catalog     AWS Glue Data Catalog, populated by Glue crawlers (Hive Metastore compatible)
                |
Governance  AWS Lake Formation (column/row/cell permissions, LF-Tags, cross-account sharing)
                |
Query       Amazon Athena (ad hoc SQL) | Amazon EMR (custom Spark/Hadoop/Presto) | Redshift Spectrum
                |
Consume     Amazon Quick (BI dashboards, SPICE) | Amazon OpenSearch Service (search/log analytics)
```

**The property this pattern sells:** storage, catalog, and query are three independently scaling layers. You never move or duplicate data to make it queryable by a new engine — you only point that engine at the same S3 objects and the same catalog entry. AWS's own description: crawlers "run periodically to detect the availability of new data as well as changes to existing data, including table definition changes," and once registered, tables are "readily available for querying in Amazon Athena, Amazon EMR, and Amazon Redshift Spectrum so that you can have a common view of your data between these services."

### Storage tiers within a lake

- **S3 Standard** — active partitions, actively crawled and queried.
- **S3 Standard-IA / Glacier tiers** — historical partitions past their active query window, transitioned by lifecycle policy **while staying in the same bucket and prefix the catalog already points at**. Athena and Redshift Spectrum can still query IA-tier objects; Glacier retrieval-tier objects generally cannot be queried in place without a restore.
- **S3 Tables** — Iceberg-native storage queryable by Athena, Redshift, and Spark, giving table semantics without bolting a table format onto raw objects. Full storage-class detail in `references/storage.md`.

### What has been added on top

The current decision guide (last updated 2025-09-24 per its own metadata) confirms the same five-layer shape and names three extensions:

- **S3 Tables** as the current-generation refinement of the storage layer.
- **Redshift composes with the lake bidirectionally**, not just through Spectrum: "Amazon Redshift can be connected to a data lakehouse in Amazon SageMaker, allowing you to use its powerful SQL analytic capabilities on your unified data across Amazon Redshift data warehouses and Amazon S3 data lakes."
- **Governance is now a named layer**, not an implicit one — the guide adds a dedicated data-governance category (Amazon DataZone alongside Lake Formation), reflecting the same data-swamp concern.
- **Streaming lands in the same layers** — Firehose delivers to S3 and Apache Iceberg Tables, so the batch shape (crawler -> catalog -> query) and the streaming shape (Firehose -> S3/Iceberg -> same catalog) converge on identical storage and catalog layers.

### Diagnosing a lake

Given a scenario, identify the missing layer rather than reciting features:

| Symptom | Missing piece |
|---|---|
| Data is in S3 but Athena returns no rows | Crawler never ran, or ran before the partition landed |
| Multiple teams need different column visibility into the same table | Lake Formation (IAM cannot express column/row/cell scope) |
| Raw CSV, high Athena bills | Format transformation — convert to compressed, partitioned Parquet |
| One consumer starves the others on a stream | Enhanced Fan-Out, or the wrong service (Firehose has no consumers at all) |
| Dashboards re-bill the source on every view | Import to SPICE instead of direct query |
| Cluster in a private subnet, surprise NAT bill | Missing S3 gateway endpoint |

## Sources

- https://docs.aws.amazon.com/athena/latest/ug/what-is.html
- https://docs.aws.amazon.com/athena/latest/ug/when-should-i-use-ate.html
- https://aws.amazon.com/athena/pricing/
- https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html
- https://docs.aws.amazon.com/lake-formation/latest/dg/what-is-lake-formation.html
- https://docs.aws.amazon.com/data-exchange/latest/userguide/what-is.html
- https://docs.aws.amazon.com/decision-guides/latest/analytics-on-aws-how-to-choose/analytics-on-aws-how-to-choose.html
- https://docs.aws.amazon.com/streams/latest/dev/introduction.html
- https://docs.aws.amazon.com/streams/latest/dev/how-do-i-size-a-stream.html
- https://aws.amazon.com/kinesis/data-streams/faqs/
- https://docs.aws.amazon.com/firehose/latest/dev/what-is-this-service.html
- https://aws.amazon.com/firehose/pricing/
- https://docs.aws.amazon.com/msk/latest/developerguide/what-is-msk.html
- https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html
- https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-what-is-emr.html
- https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-overview-benefits.html
- https://docs.aws.amazon.com/quicksight/latest/user/welcome.html
- https://docs.aws.amazon.com/quicksight/latest/user/spice.html
- https://aws.amazon.com/quick/quicksight/pricing/
- https://docs.aws.amazon.com/opensearch-service/latest/developerguide/what-is.html
- https://aws.amazon.com/what-is/data-lake/
- https://docs.aws.amazon.com/whitepapers/latest/big-data-analytics-options/example-1-queries-against-an-amazon-s3-data-lake.html

Fetched: 2026-08-08
