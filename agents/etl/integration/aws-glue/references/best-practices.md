# AWS Glue Best Practices

## Job Design

### Script Architecture

- **Modularize transformation logic**: Separate extraction, transformation, and loading into distinct functions. This improves readability, testability, and reuse.
- **Use DynamicFrames for Glue-native features**: Job bookmarks, schema flexibility, and `groupFiles` work natively with DynamicFrames. Convert to Spark DataFrames with `.toDF()` only when you need Spark SQL or DataFrame-specific operations.
- **Set `transformation_ctx` on every source and sink**: Job bookmarks require unique `transformation_ctx` strings to track processing state. Omitting them silently disables incremental processing.
- **Parameterize jobs**: Use `getResolvedOptions()` to accept runtime parameters for source paths, target locations, dates, and processing modes rather than hardcoding values.
- **Minimize driver-side operations**: Avoid `.collect()`, `.toPandas()`, or `.count()` on large datasets. These pull data to the driver and cause OOM.

```python
from awsglue.utils import getResolvedOptions
import sys

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'source_path', 'target_path', 'load_date'])

# Use args['source_path'], args['target_path'], args['load_date'] throughout
```

### Data Format Selection

- **Write columnar formats**: Parquet and ORC provide compression, column pruning, and predicate pushdown, reducing I/O cost and job duration.
- **Use Snappy compression**: Default for Parquet in Spark. Good balance between compression ratio and decompression speed.
- **Avoid small files**: Target output file sizes of 128 MB to 512 MB. Use `coalesce()` or `repartition()` before writing to control output file count.
- **Compact small input files**: Use Glue's `groupFiles` option (`inPartition` or `acrossPartitions`) to coalesce small files at read time:

```python
datasource = glueContext.create_dynamic_frame.from_catalog(
    database="raw_db",
    table_name="events",
    additional_options={"groupFiles": "inPartition", "groupSize": "134217728"},  # 128 MB
    transformation_ctx="events_source"
)
```

### Incremental Processing

- **Enable job bookmarks** for all repeating batch jobs to process only new or changed data
- **Partition output by time dimensions**: `year/month/day` or `year/month/day/hour` enables partition pruning and simplifies data lifecycle management
- **Use pushdown predicates**: Filter at the catalog level to read only relevant partitions:

```python
datasource = glueContext.create_dynamic_frame.from_catalog(
    database="raw_db",
    table_name="orders",
    push_down_predicate="(year=='2025' and month=='08')",
    transformation_ctx="orders_source"
)
```

## DPU Sizing and Worker Selection

### Right-Sizing Strategy

1. **Start small**: Begin with 2-5 G.1X workers for new jobs, not the legacy default of 10 DPUs
2. **Monitor utilization**: Use CloudWatch metrics (`glue.ALL.jvm.heap.usage`, `glue.ALL.system.cpuSystemLoad`) to identify actual resource consumption
3. **Scale based on evidence**: Increase workers only when metrics show sustained CPU or memory pressure above 70%
4. **Enable Auto Scaling**: For Glue 3.0+, set max workers and let Glue optimize dynamically

### Worker Type Selection

| Scenario | Worker | Rationale |
|---|---|---|
| General ETL (joins, maps, filters) | G.1X | Cost-effective for typical transforms |
| Memory-intensive joins/aggregations | G.2X | Double memory for in-memory operations |
| ML transforms, large shuffles | G.4X or G.8X | High memory and CPU for compute-heavy tasks |
| Very large in-memory datasets | R.1X - R.4X | Memory-optimized: 2x memory per DPU |
| Distributed Python (non-Spark) | Z.2X | Ray-based Python workloads |
| Simple scripts, small data | G.025X | Python Shell; minimal cost |

### Auto Scaling Configuration

- Set `NumberOfWorkers` to the upper bound you would consider provisioning
- Glue scales down during low-parallelism stages and up during high-parallelism stages
- Monitor `glue.driver.ExecutorAllocationManager.executors.numberAllExecutors` to understand actual utilization
- Particularly effective for jobs with varying data volumes across stages

## Partitioning Strategy

### Output Partitioning

- **Choose partition keys based on query patterns**: Most common access pattern determines the scheme (e.g., `year/month/day` for time-series)
- **Avoid over-partitioning**: Too many partitions (millions of small directories) create excessive S3 LIST operations and slow crawler and query performance
- **Avoid under-partitioning**: Too few partitions force full scans and limit parallelism
- **Target 100 MB - 1 GB per partition** as a guideline
- **Use Hive-style naming**: `s3://bucket/table/year=2025/month=08/day=15/` for automatic partition recognition

### Partition Management

- **Register partitions via API or MSCK REPAIR TABLE**: For known partition schemes, directly add partition metadata rather than running a full crawler
- **Use partition indexes**: Created by default by crawlers for S3 and Delta Lake; accelerate partition lookups for tables with millions of partitions
- **Lifecycle management**: Archive or delete old partitions to control catalog size and storage costs

```bash
# Register new partition via API
aws glue batch-create-partition --database-name my_db --table-name orders \
  --partition-input-list '[{"Values":["2025","08","15"],"StorageDescriptor":{...}}]'
```

## Data Catalog Organization

### Naming Conventions

- Consistent, descriptive names: `<domain>_<dataset>_<format>` (e.g., `sales_orders_parquet`)
- Prefix database names with environment: `prod_analytics`, `dev_analytics`, `staging_analytics`
- Lowercase with underscores (no spaces or special characters)

### Database Structure

- **One database per data domain or team**: Prevents a single flat namespace with hundreds of tables
- **Separate raw, curated, and published layers**: `raw_sales`, `curated_sales`, `published_sales`
- **Use tags**: Apply resource tags for cost allocation, ownership, and access control

### Schema Management

- **Enable schema versioning**: Data Catalog retains schema history for auditing and rollback
- **Configure schema change policies on crawlers**: ADD_NEW_COLUMNS, UPDATE, or LOG
- **Use Lake Formation** for column-level and row-level security on catalog tables

## Crawler Management

### Performance Optimization

- **Use exclusion patterns**: Skip temporary files, checkpoints, and metadata: `**/_temporary/**`, `**/_SUCCESS`, `**/*.crc`, `**/checkpoint/**`
- **Set sample size**: Configure crawlers to sample a subset of files per leaf folder rather than reading every file
- **Run targeted crawlers**: One per domain or table group, not one for the entire data lake
- **Use incremental crawls**: For frequently updated sources, process only new or changed files

### Scheduling

- **Chain crawlers after ETL jobs**: Use workflow triggers or EventBridge
- **Avoid excessive frequency**: Crawling costs DPU-hours; schedule only as often as data changes
- **Prefer direct partition registration**: For well-known schemas, use `batch_create_partition` API or `MSCK REPAIR TABLE` instead of crawlers

### Reliability

- **Test classifiers against sample data**: Verify expected schema before deploying
- **Monitor crawler logs**: Check `/aws-glue/crawlers` in CloudWatch Logs
- **Handle schema conflicts**: Configure crawler behavior for schema changes based on your tolerance for evolution

## Cost Optimization

### Compute Cost Reduction

1. **Right-size workers**: Start with 2-5 G.1X; scale based on CloudWatch metrics
2. **Enable Auto Scaling**: Let Glue optimize worker count per stage
3. **Use Flex execution**: 34% savings for non-urgent batch jobs ($0.29 vs $0.44/DPU-hour)
4. **Set appropriate timeouts**: Prevent runaway jobs from consuming DPU-hours indefinitely
5. **Use Python Shell for lightweight tasks**: 1 DPU max at $0.44/DPU-hour vs multi-DPU Spark jobs

### Data-Level Optimizations

1. **Pushdown predicates**: Filter at the partition level to avoid reading unnecessary data
2. **Column pruning**: Select only needed columns; Parquet/ORC make this highly efficient
3. **Compact small files**: Reduce overhead of processing millions of tiny files
4. **Cache intermediate results**: `.persist()` DataFrames reused multiple times to avoid redundant computation

### Catalog Cost Reduction

- First million catalog objects and first million API requests per month are free
- Beyond that: $1.00 per 100K objects and $1.00 per million requests
- Remove stale/unused table definitions and partitions periodically
- Avoid running crawlers more frequently than data changes

### Cost Monitoring

- Use AWS Cost Explorer to track Glue spending by job name (tag jobs for granularity)
- Set CloudWatch alarms when executor utilization stays below 50% (over-provisioned)
- Review job run durations and DPU-hours in the Glue console job history

```bash
# Tag a Glue job for cost tracking
aws glue tag-resource \
  --resource-arn arn:aws:glue:us-east-1:123456789012:job/my-etl-job \
  --tags-to-add '{"project":"analytics","team":"data-engineering","environment":"production"}'
```

## Testing Strategies

### Local Development

- **Docker-based testing**: AWS provides official Glue Docker images (ECR Public Gallery) for Glue 3.0, 4.0, and 5.0 that replicate the Glue runtime locally
- **Glue ETL library**: Install the open-source AWS Glue ETL Scala/Python library locally
- **Interactive sessions**: Use Glue Studio notebooks for rapid prototyping with real data connections (sub-minute provisioning, per-second billing)

### Unit Testing

- **Use pytest** with mock GlueContext and SparkSession fixtures
- **Isolate transformation logic**: Extract business logic into pure functions that accept and return DataFrames, testable without Glue infrastructure
- **Mock data sources**: Create test DataFrames from local files or inline data
- **Test job bookmarks**: Verify `transformation_ctx` values are unique and consistent

```python
# Example: testable transformation function
def clean_orders(df):
    return df.filter(df.amount > 0).withColumn("order_date", to_date("order_date_str", "yyyy-MM-dd"))

# Test with pytest
def test_clean_orders(spark_session):
    input_df = spark_session.createDataFrame([
        {"amount": 100, "order_date_str": "2025-08-15"},
        {"amount": -5, "order_date_str": "2025-08-16"}
    ])
    result = clean_orders(input_df)
    assert result.count() == 1
```

### Integration Testing

- Deploy to a dev/staging Glue environment with separate Data Catalog databases
- Use small representative datasets mirroring production schema
- Validate output schema, partition structure, and record counts
- Test error handling with malformed data, missing partitions, and schema mismatches

### CI/CD Integration

- Use AWS CodePipeline + CodeBuild for automated testing and deployment
- Store Glue scripts in version control (Git)
- Run pytest in CodeBuild using the Glue Docker image
- Deploy via CloudFormation, CDK, or Terraform

## Operational Best Practices

### Monitoring

- Enable Spark UI for all production jobs (detailed stage, task, and shuffle analysis)
- Set up CloudWatch alarms for job failures, duration anomalies, and memory pressure
- Use Glue Job Run Insights (Glue 2.0+) for automated root cause analysis
- Track job lineage and dependencies in workflow visualizations

### Error Handling

- Implement try/catch blocks around data source connections and writes
- Use Glue's built-in retry mechanism (configurable retry count) for transient failures
- Write failed records to a dead-letter S3 location for later investigation
- Log sufficient context: record counts, partition values, timing

### Governance

- Apply least-privilege IAM policies per job -- avoid wildcard S3 and Glue permissions
- Use Lake Formation for fine-grained data access control
- Enable CloudTrail logging for all Glue API calls
- Tag all Glue resources with owner, team, environment, and cost center
