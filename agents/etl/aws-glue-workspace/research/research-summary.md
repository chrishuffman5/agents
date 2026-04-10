# AWS Glue Research Summary

## What Is AWS Glue

AWS Glue is a fully managed, serverless data integration service from AWS that provides ETL (Extract, Transform, Load) processing, a centralized metadata catalog (the Data Catalog), automated schema discovery (crawlers), data quality validation, and visual job authoring. It eliminates the need to provision or manage infrastructure for data processing workloads.

---

## Key Findings

### Architecture

AWS Glue is built around five core pillars:

1. **Data Catalog** -- a centralized, Hive-compatible metadata repository (one per account per region) that stores database, table, partition, and connection definitions; integrates with Athena, Redshift Spectrum, EMR, and Lake Formation
2. **Crawlers and Classifiers** -- automated schema discovery programs that scan data stores (S3, JDBC, DynamoDB, MongoDB), classify file formats, infer schemas, and populate the Data Catalog
3. **ETL Engine** -- Apache Spark-based (with DynamicFrame extensions), Ray-based (for distributed Python), and Python Shell (lightweight single-node) runtimes for data transformation
4. **Glue Studio** -- visual drag-and-drop ETL authoring with auto-generated code, data preview, data quality transforms, and DataBrew recipe integration
5. **Job System** -- managed orchestration with triggers (scheduled, conditional, on-demand), workflows (DAG-based multi-job/crawler coordination), and EventBridge integration

### Worker Types and Compute

AWS Glue offers a comprehensive range of worker types for different workload profiles:

- **G-series (Standard):** G.025X through G.16X -- from 0.25 DPU (2 vCPU, 4 GB) for Python Shell to 16 DPU (64 vCPU, 256 GB) for the largest workloads
- **R-series (Memory-Optimized):** R.1X through R.8X -- double the memory per DPU (32 GB per DPU vs 16 GB) for memory-intensive operations
- **Z-series (Ray):** Z.2X for distributed Python via Ray framework

Auto Scaling (Glue 3.0+) dynamically adjusts worker count based on workload parallelism, and Flex execution provides a 34% cost reduction for non-urgent batch jobs.

### Current Runtime (Glue 5.1)

As of early 2026, Glue 5.1 is the latest runtime offering:
- Apache Spark 3.5.6, Python 3.11, Scala 2.12.18, Java 17
- Apache Iceberg format v3 support (deletion vectors, default columns, row lineage)
- Updated open table format libraries: Iceberg 1.10.0, Hudi 1.0.2, Delta Lake 3.3.2
- S3A as the default S3 connector
- Fine-grained Lake Formation access control for writes to Iceberg, Hive, Hudi, and Delta Lake tables
- Integration with Amazon SageMaker Unified Studio

### Data Quality

Glue Data Quality uses DQDL (Data Quality Definition Language) built on the open-source DeeQu framework. It offers:
- Rule-based validation (completeness, uniqueness, value constraints, referential integrity, freshness)
- ML-powered anomaly detection via `DetectAnomalies` rule type
- Auto-recommendation engine that profiles data and suggests rules
- Advanced DQDL operators: NOT, WHERE, composite rules, labels, preprocessing queries
- Integration as a visual transform node in Glue Studio

### DataBrew

A separate visual, no-code data preparation tool with 250+ built-in transformations, interactive profiling, and reusable recipe workflows. DataBrew recipes can be embedded into Glue Studio visual ETL jobs.

---

## Best Practices Summary

| Area | Key Recommendation |
|------|--------------------|
| **DPU Sizing** | Start with 2-5 G.1X workers; scale based on CloudWatch metrics, not assumptions |
| **Cost Optimization** | Enable Auto Scaling, use Flex execution for non-urgent jobs, right-size workers |
| **Data Format** | Write Parquet/ORC with Snappy compression; target 128 MB-512 MB output files |
| **Small Files** | Use `groupFiles` at read time; run compaction jobs; avoid millions of tiny outputs |
| **Partitioning** | Partition by query access patterns (typically time-based); target 100 MB-1 GB per partition |
| **Incremental Processing** | Enable job bookmarks with unique `transformation_ctx` on every source and sink |
| **Catalog Organization** | One database per domain, consistent naming, separate raw/curated/published layers |
| **Crawler Management** | Use exclusion patterns, sample sizes, targeted crawlers; prefer API-based partition registration |
| **Testing** | Docker images for local dev, pytest with mock GlueContext, isolated transformation functions |
| **Monitoring** | CloudWatch alarms on heap usage, CPU, and job duration; enable Job Run Insights |

---

## Diagnostics Summary

| Issue | Primary Diagnostic | Key Fix |
|-------|-------------------|---------|
| **Driver OOM** | `glue.driver.jvm.heap.usage` > 50% rapidly | Enable `groupFiles`, avoid `.collect()`, upgrade worker |
| **Executor OOM** | YARN container killed messages | Set JDBC fetchsize, fix data skew, increase memory overhead |
| **Slow Jobs** | Spark UI stage/task analysis | Fix small files, address skew, use pushdown predicates |
| **Crawler Slowness** | Millions of files being scanned | Exclusion patterns, sample size, split crawlers |
| **Connection Failures** | `ConnectionTimeoutException` | NAT gateway, security group self-referencing rule, subnet routing |
| **Permission Errors** | `AccessDeniedException` | IAM role policies, Lake Formation grants, KMS key policies |
| **Data Quality Failures** | DQDL rule evaluation results | Review rules, check for schema changes, tune anomaly thresholds |

---

## Research Sources

- AWS Glue Documentation: https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html
- AWS Glue Components: https://docs.aws.amazon.com/glue/latest/dg/components-overview.html
- AWS Glue Worker Types: https://docs.aws.amazon.com/glue/latest/dg/worker-types.html
- AWS Glue Best Practices Whitepaper: https://docs.aws.amazon.com/whitepapers/latest/aws-glue-best-practices-build-performant-data-pipeline/
- AWS Glue Data Quality (DQDL): https://docs.aws.amazon.com/glue/latest/dg/dqdl.html
- Debugging OOM Exceptions: https://docs.aws.amazon.com/glue/latest/dg/monitor-profile-debug-oom-abnormalities.html
- CloudWatch Metrics for Glue: https://docs.aws.amazon.com/glue/latest/dg/monitor-profile-glue-job-cloudwatch-metrics.html
- Glue 5.0 Announcement: https://aws.amazon.com/blogs/big-data/introducing-aws-glue-5-0-for-apache-spark/
- Glue 5.1 Announcement: https://aws.amazon.com/blogs/big-data/introducing-aws-glue-5-1-for-apache-spark/
- Glue Data Catalog Best Practices: https://docs.aws.amazon.com/glue/latest/dg/best-practice-catalog.html
- Glue Pricing: https://aws.amazon.com/glue/pricing/
- Glue Features Overview: https://aws.amazon.com/glue/features/
- Glue DataBrew: https://docs.aws.amazon.com/prescriptive-guidance/latest/serverless-etl-aws-glue/databrew.html
- Glue Troubleshooting: https://docs.aws.amazon.com/glue/latest/dg/glue-troubleshooting-errors.html
- Local Testing with Docker: https://aws.amazon.com/blogs/big-data/develop-and-test-aws-glue-5-0-jobs-locally-using-a-docker-container/
- Unit Testing with Pytest: https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/run-unit-tests-for-python-etl-jobs-in-aws-glue-using-the-pytest-framework.html
- Glue Cost Optimization: https://docs.aws.amazon.com/whitepapers/latest/aws-glue-best-practices-build-performant-data-pipeline/building-a-cost-effective-data-pipeline.html
- Glue Auto Scaling: https://docs.aws.amazon.com/glue/latest/dg/auto-scaling.html

---

## File Inventory

| File | Description |
|------|-------------|
| `architecture.md` | Complete architecture covering Data Catalog, crawlers, classifiers, ETL engine (Spark/Ray), Glue Studio, DPU/worker types, job bookmarks, connections, pricing |
| `features.md` | Current capabilities: Glue 4.0/5.0/5.1 runtimes, interactive sessions, Data Quality/DQDL, DataBrew, Auto Scaling, Flex execution, streaming ETL, open table formats, Zero-ETL, AI script generation |
| `best-practices.md` | Job design, DPU sizing, partitioning strategy, Data Catalog organization, crawler management, cost optimization, testing strategies, operational practices |
| `diagnostics.md` | Job failures, OOM debugging (driver/executor), crawler issues, slow job diagnosis, CloudWatch metrics reference, alarm thresholds, error message lookup table, debugging workflow |
| `research-summary.md` | This file -- consolidated findings, recommendations, and source references |
