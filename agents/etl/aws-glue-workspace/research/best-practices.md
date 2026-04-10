# AWS Glue Best Practices

## Job Design

### Script Architecture

- **Modularize transformation logic** -- separate extraction, transformation, and loading into distinct functions to improve readability, testability, and reuse
- **Use DynamicFrames for Glue-native features** -- job bookmarks, schema flexibility, and data grouping work natively with DynamicFrames; convert to Spark DataFrames only when you need Spark SQL or DataFrame-specific operations
- **Set transformation_ctx on every source and sink** -- job bookmarks require unique `transformation_ctx` strings to track processing state; omitting them silently disables incremental processing
- **Parameterize jobs** -- use `getResolvedOptions()` to accept runtime parameters for source paths, target locations, dates, and processing modes rather than hardcoding values
- **Minimize driver-side operations** -- avoid collecting large datasets to the driver with `.collect()`, `.toPandas()`, or `.count()` as these cause driver OOM

### Data Format Selection

- **Write columnar formats** -- Parquet and ORC provide compression, column pruning, and predicate pushdown, dramatically reducing I/O cost and job duration
- **Use Snappy compression** -- default for Parquet in Spark; provides a good balance between compression ratio and decompression speed
- **Avoid small files** -- target output file sizes of 128 MB to 512 MB; use coalesce or repartition before writing to control output file count
- **Compact small input files** -- use Glue's `groupFiles` option (`inPartition` or `acrossPartitions`) to coalesce small files at read time, reducing driver memory pressure

### Incremental Processing

- **Enable job bookmarks** for all repeating batch jobs to process only new or changed data
- **Partition output by time dimensions** -- `year/month/day` or `year/month/day/hour` enables partition pruning in downstream queries and simplifies data lifecycle management
- **Use pushdown predicates** -- filter data at the catalog level with `push_down_predicate` to read only relevant partitions rather than scanning entire datasets

---

## DPU Sizing and Worker Selection

### Right-Sizing Strategy

1. **Start small** -- begin with 2-5 G.1X workers for new jobs rather than the legacy default of 10 DPUs
2. **Monitor utilization** -- use CloudWatch metrics (`glue.ALL.jvm.heap.usage`, `glue.ALL.system.cpuSystemLoad`) to identify actual resource consumption
3. **Scale based on evidence** -- increase workers only when metrics show sustained CPU or memory pressure above 70%
4. **Leverage Auto Scaling** -- for Glue 3.0+, enable auto scaling and set max workers to let Glue optimize dynamically

### Worker Type Selection Guide

| Scenario | Recommended Worker | Rationale |
|----------|-------------------|-----------|
| General ETL (joins, maps, filters) | G.1X | Cost-effective for typical transforms |
| Memory-intensive joins/aggregations | G.2X | Double memory for in-memory operations |
| ML transforms, large shuffles | G.4X or G.8X | High memory and CPU for compute-heavy tasks |
| Very large in-memory datasets | R.1X through R.4X | Memory-optimized; 2x memory per DPU |
| Distributed Python (non-Spark) | Z.2X | Ray-based Python workloads |
| Simple scripts, small data | G.025X (Python Shell) | Minimal cost for lightweight tasks |

### Auto Scaling Configuration

- Set `MaxCapacity` (or `NumberOfWorkers`) to the upper bound you would consider provisioning
- Glue scales down during low-parallelism stages (e.g., single-partition writes) and up during high-parallelism stages (e.g., wide shuffles)
- Monitor `glue.driver.ExecutorAllocationManager.executors.numberAllExecutors` to understand actual utilization patterns

---

## Partitioning Strategy

### Output Partitioning

- **Choose partition keys based on query patterns** -- the most common access pattern determines the partition scheme (e.g., `year/month/day` for time-series, `region/product` for dimensional queries)
- **Avoid over-partitioning** -- too many partitions (millions of small directories) create excessive S3 LIST operations and slow crawler and query performance
- **Avoid under-partitioning** -- too few partitions force full scans and prevent parallelism
- **Target 100 MB - 1 GB per partition** as a general guideline
- **Use consistent folder naming** -- `s3://bucket/table/year=2025/month=08/day=15/` (Hive-style) for automatic partition recognition

### Partition Management

- **Register partitions via MSCK REPAIR TABLE or Glue API** -- for known partition schemes, directly add partition metadata rather than running a full crawler
- **Use partition indexes** -- Glue crawlers create these by default for S3 and Delta Lake targets; they accelerate partition metadata lookups for tables with millions of partitions
- **Implement partition lifecycle** -- archive or delete old partitions to control catalog size and storage costs

---

## Data Catalog Organization

### Naming Conventions

- Use consistent, descriptive names: `<domain>_<dataset>_<format>` (e.g., `sales_orders_parquet`)
- Prefix database names with environment: `prod_analytics`, `dev_analytics`, `staging_analytics`
- Use lowercase with underscores (avoid spaces and special characters)

### Database Structure

- **One database per data domain or team** -- prevents a single flat namespace with hundreds of tables
- **Separate raw, curated, and published layers** -- e.g., `raw_sales`, `curated_sales`, `published_sales` to represent the data processing stages
- **Use tags** -- apply resource tags for cost allocation, ownership tracking, and access control

### Schema Management

- **Enable schema versioning** -- the Data Catalog retains schema history, useful for auditing and rollback
- **Configure schema change policies on crawlers** -- decide whether to add new columns, update types, or create new table versions on schema changes
- **Use Lake Formation** for column-level and row-level security on catalog tables

---

## Crawler Management

### Performance Optimization

- **Use exclusion patterns** -- skip temporary files, logs, checkpoint directories, and non-data objects (`_SUCCESS`, `_temporary`, `.crc` files)
- **Set sample size** -- for large datasets, configure the crawler to sample a subset of files per leaf folder rather than reading every file
- **Run multiple targeted crawlers** -- rather than one crawler scanning an entire bucket, create focused crawlers per data domain or table group
- **Use incremental crawls** -- for frequently changing sources, configure crawlers to process only new or changed files

### Scheduling

- **Schedule crawlers to run after ETL jobs** -- use workflow triggers or EventBridge to chain crawler runs after data is written
- **Avoid excessive crawler frequency** -- crawling costs DPU-hours; schedule only as often as data actually changes
- **Prefer direct partition registration** -- for well-known schemas, use `batch_create_partition` API or `MSCK REPAIR TABLE` instead of crawlers

### Reliability

- **Test classifiers against sample data** -- verify custom classifiers produce the expected schema before deploying to production
- **Monitor crawler logs** -- check `/aws-glue/crawlers` in CloudWatch Logs for warnings and errors
- **Handle schema conflicts** -- configure crawler behavior for schema changes (ADD_NEW_COLUMNS, LOG, or UPDATE) based on your tolerance for schema evolution

---

## Cost Optimization

### Compute Cost Reduction

1. **Right-size workers** -- most jobs do not need 10 DPUs; start with 2-5 and scale based on metrics
2. **Enable Auto Scaling** -- let Glue optimize worker count per stage
3. **Use Flex execution** -- 34% savings for non-urgent batch jobs ($0.29 vs $0.44/DPU-hour)
4. **Set appropriate timeouts** -- prevent runaway jobs from consuming DPU-hours indefinitely
5. **Use Python Shell** for lightweight tasks -- 1 DPU max at $0.44/DPU-hour vs multi-DPU Spark jobs

### Data-Level Optimizations

1. **Pushdown predicates** -- filter at the partition level to avoid reading unnecessary data
2. **Column pruning** -- select only needed columns; columnar formats (Parquet/ORC) make this highly efficient
3. **Compact small files** -- reduce overhead of processing millions of tiny files
4. **Cache intermediate results** -- `.persist()` intermediate DataFrames that are reused multiple times to avoid redundant computation

### Catalog Cost Reduction

- First million catalog objects and first million API requests per month are free
- Beyond that, $1.00 per 100K objects and $1.00 per million requests
- Remove stale/unused table definitions and partitions periodically
- Avoid running crawlers more frequently than data changes

### Monitoring for Cost

- Use AWS Cost Explorer to track Glue spending by job name (tag jobs for granularity)
- Set up CloudWatch alarms when executor utilization stays below 50% to identify over-provisioned jobs
- Review job run durations and DPU-hours consumed in the Glue console job history

---

## Testing Strategies

### Local Development

- **Docker-based testing** -- AWS provides official Glue Docker images (ECR Public Gallery) for Glue 3.0, 4.0, and 5.0 that replicate the Glue runtime environment locally
- **Glue ETL library** -- install the open-source AWS Glue ETL Scala/Python library locally for development without Docker
- **Interactive sessions** -- use Glue Studio notebooks for rapid prototyping with real data connections

### Unit Testing

- **Use pytest** with mock GlueContext and SparkSession fixtures
- **Isolate transformation logic** -- extract business logic into pure functions that accept and return DataFrames, testable without Glue infrastructure
- **Mock data sources** -- create test DataFrames from local files or inline data rather than connecting to live S3/JDBC sources
- **Test job bookmarks** -- verify transformation_ctx values are unique and consistent

### Integration Testing

- **Deploy to a dev/staging Glue environment** with separate Data Catalog databases
- **Use small representative datasets** -- mirror production schema with reduced row counts
- **Validate output schema** -- assert column names, types, partition structure, and record counts
- **Test error handling** -- verify behavior with malformed data, missing partitions, and schema mismatches

### CI/CD Integration

- Use AWS CodePipeline + CodeBuild for automated testing and deployment
- Store Glue scripts in version control (Git)
- Run pytest in CodeBuild using the Glue Docker image
- Deploy via CloudFormation, CDK, or Terraform

---

## Operational Best Practices

### Monitoring

- Enable Spark UI for all production jobs -- provides detailed stage, task, and shuffle analysis
- Set up CloudWatch alarms for job failures, duration anomalies, and memory pressure
- Use Glue Job Run Insights (Glue 2.0+) for automated root cause analysis
- Track job lineage and dependencies in workflow visualizations

### Error Handling

- Implement try/catch blocks around data source connections and writes
- Use Glue's built-in retry mechanism (configurable retry count) for transient failures
- Write failed records to a dead-letter location for later investigation
- Log sufficient context for debugging: record counts, partition values, and timing

### Governance

- Apply least-privilege IAM policies per job -- avoid wildcard S3 and Glue permissions
- Use Lake Formation for fine-grained data access control
- Enable CloudTrail logging for all Glue API calls
- Tag all Glue resources (jobs, crawlers, connections) with owner, team, environment, and cost center
