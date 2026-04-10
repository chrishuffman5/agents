# AWS Glue Diagnostics

## Job Failures

### Common Failure Categories

**1. Script Errors**
- Syntax errors in PySpark/Scala code
- Missing or incorrect import statements
- Incompatible library versions

**Diagnosis:** Check `/aws-glue/jobs/error` log group in CloudWatch Logs for stack traces. Glue Job Run Insights (Glue 2.0+) provides the specific line number, last executed Spark action, exception events, and recommended actions.

**2. Permission Failures**
- IAM role lacks S3 read/write permissions
- Missing Glue Data Catalog access
- KMS key permissions not granted
- Lake Formation permissions not configured

**Diagnosis:** Look for `AccessDeniedException` or `403 Forbidden` in error logs. Verify the job's IAM role has the required policies for all data stores and the Data Catalog.

**3. Connection Failures**
- VPC subnet routing issues (missing NAT gateway for internet access)
- Security group not allowing bidirectional TCP traffic for Spark
- JDBC endpoint unreachable from Glue's elastic network interfaces
- DNS resolution failures in VPC

**Diagnosis:** Check `/aws-glue/jobs/error` for `ConnectionTimeoutException` or `JDBC connection failure`. Verify VPC configuration: subnet route tables, NAT gateway, security group rules (must allow all TCP inbound from itself for Spark inter-node communication).

**4. Data Format Errors**
- Schema mismatch between Data Catalog definition and actual data
- Corrupt or truncated files in S3
- Unsupported file formats or compression codecs
- Encoding issues (non-UTF-8 data)

**Diagnosis:** Look for `AnalysisException`, `IOException`, or classifier-related errors. Test with a small sample file using interactive sessions.

**5. Timeout Failures**
- Job exceeds configured timeout
- Network connections to external services time out
- Long-running shuffles or skewed tasks

**Diagnosis:** Check job run duration in Glue console. Review Spark UI for stage timing and task distribution.

---

## Out-of-Memory (OOM) Errors

### Driver OOM

**Symptoms:**
- `java.lang.OutOfMemoryError: Java heap space` in error logs
- `-XX:OnOutOfMemoryError="kill -9 %p"` message
- `glue.driver.jvm.heap.usage` crosses 50% rapidly while executor memory remains low

**Common Causes:**
- Millions of small files forcing the driver to build a large `InMemoryFileIndex`
- `.collect()`, `.toPandas()`, or `.count()` pulling large datasets to the driver
- Broadcast joins with tables too large for driver memory
- Large accumulator variables
- Too many partitions generating excessive task metadata on the driver

**Solutions:**

| Cause | Fix |
|-------|-----|
| Small files | Enable `groupFiles: 'inPartition'` in DynamicFrame options |
| Collect operations | Replace with distributed writes or sample-based operations |
| Large broadcasts | Increase `spark.sql.autoBroadcastJoinThreshold` limit or disable broadcasting |
| Excessive partitions | Repartition to a reasonable count (e.g., `coalesce(100)`) |
| General driver pressure | Upgrade worker type (e.g., G.1X to G.2X) for more driver memory |

### Executor OOM

**Symptoms:**
- `WARN YarnAllocator: Container killed by YARN for exceeding memory limits`
- `ERROR YarnClusterScheduler: Lost executor [N]: Container killed by YARN`
- `Consider boosting spark.yarn.executor.memoryOverhead`
- `Command Failed with Exit Code 1` on the History tab
- Executors repeatedly launching and failing (`numberAllExecutors` metric shows spike/drop pattern)

**Common Causes:**
- JDBC reads with default `fetchsize=0` pulling entire result sets into executor memory
- Skewed data causing one executor to process disproportionately more data
- Complex UDFs accumulating memory without releasing
- Caching large DataFrames that exceed available memory
- Insufficient memory overhead for off-heap operations

**Solutions:**

| Cause | Fix |
|-------|-----|
| JDBC full fetch | Use DynamicFrames (default fetchsize=1000) or set explicit fetchsize on Spark JDBC reads |
| Data skew | Repartition on a high-cardinality key, use salting for skewed joins |
| Memory overhead | Set `spark.yarn.executor.memoryOverhead` to 15-20% of executor memory |
| Large caches | Use `.persist(StorageLevel.DISK_ONLY)` or remove unnecessary caches |
| General executor pressure | Upgrade to G.2X, G.4X, or R-series workers |

---

## Crawler Issues

### Crawler Takes Too Long

**Common Causes:**
- Scanning millions of small files (first MB of each file is read)
- No exclusion patterns filtering out non-data files
- Single crawler scanning entire data lake
- Network latency to JDBC sources

**Solutions:**
- Add exclusion patterns: `**/_temporary/**`, `**/_SUCCESS`, `**/*.crc`, `**/checkpoint/**`
- Set sample size to limit files scanned per leaf folder
- Split into multiple targeted crawlers (one per domain/table)
- Use incremental crawls for frequently updated data

### Crawler Creates Wrong Schema

**Common Causes:**
- Mixed file formats in the same path
- Inconsistent schemas across files in a partition
- Custom data format not matched by built-in classifiers
- Crawler classifying files as a different format than intended

**Solutions:**
- Ensure all files under a table path share the same format and compatible schema
- Create custom classifiers and assign them to the crawler with appropriate priority
- Use exclusion patterns to skip problematic files
- Manually define the table in the Data Catalog and skip crawling

### Crawler Creates Too Many Tables

**Common Causes:**
- Schema differences across partitions causing the crawler to treat them as separate tables
- Inconsistent folder naming conventions
- Mixing data from different sources in the same root path

**Solutions:**
- Configure the crawler's grouping behavior to merge compatible schemas
- Standardize folder structures and naming conventions
- Use table-level configuration in the crawler to map paths to specific tables

### Crawler Internal Service Exception

**Common Causes:**
- Temporary AWS service issues
- S3 bucket policy or KMS key permission issues
- VPC/networking problems for JDBC crawlers

**Solutions:**
- Retry the crawler run
- Verify IAM role permissions for S3, KMS, and Glue
- Check VPC configuration for JDBC targets
- Review `/aws-glue/crawlers` log group for detailed error messages

---

## Slow Job Performance

### Diagnosis Process

1. **Check Spark UI** -- accessible from the Glue console job run details
   - Review stage timelines for bottlenecks
   - Check task distribution for skew (some tasks taking 10x+ longer than others)
   - Examine shuffle read/write volumes

2. **Review CloudWatch Metrics:**

| Metric | What It Reveals |
|--------|-----------------|
| `glue.ALL.system.cpuSystemLoad` | CPU saturation -- high values indicate compute-bound work |
| `glue.ALL.jvm.heap.usage` | Memory pressure -- sustained >70% indicates memory-bound work |
| `glue.ALL.s3.filesystem.read_bytes` | S3 read volume -- compare to expected data size |
| `glue.ALL.s3.filesystem.write_bytes` | S3 write volume -- compare to output data size |
| `glue.driver.aggregate.shuffleBytesWritten` | Shuffle volume -- large values indicate expensive joins/aggregations |
| `glue.driver.aggregate.elapsedTime` | Total job time |
| `glue.driver.aggregate.numFailedTasks` | Failed tasks requiring retry |
| `glue.driver.aggregate.numCompletedStages` | Stage progress |

### Common Performance Problems

**Small Files Problem:**
- Millions of tiny files exhaust driver memory building file indexes and create excessive task overhead
- Fix: Use `groupFiles` option, run a compaction job, or use Iceberg/Hudi compaction features

**Data Skew:**
- One or few partitions contain disproportionately more data than others
- Visible in Spark UI as tasks with dramatically different durations
- Fix: Repartition on a high-cardinality column, salt skewed join keys, or use Spark AQE (Adaptive Query Execution)

**Unnecessary Full Scans:**
- Reading entire datasets when only a subset is needed
- Fix: Use pushdown predicates, partition filtering, and column pruning

**Excessive Shuffles:**
- Multiple wide transformations (joins, groupBy, distinct) creating large intermediate datasets
- Fix: Reduce shuffle by broadcasting small tables, pre-partitioning data, or restructuring the transformation DAG

**Inefficient JDBC Reads:**
- Single-threaded reads from JDBC sources without partitioning
- Fix: Configure `hashfield` or `hashexpression` for parallel reads, or use `partitionColumn`, `lowerBound`, `upperBound`, and `numPartitions`

---

## CloudWatch Metrics Reference

### Key Metrics for Monitoring

**Driver Metrics:**
- `glue.driver.jvm.heap.usage` -- driver heap utilization (%)
- `glue.driver.jvm.heap.used` -- driver heap used (bytes)
- `glue.driver.aggregate.elapsedTime` -- cumulative elapsed time
- `glue.driver.aggregate.numCompletedStages` -- completed stage count
- `glue.driver.aggregate.numFailedTasks` -- failed task count
- `glue.driver.ExecutorAllocationManager.executors.numberAllExecutors` -- active executor count

**Executor Metrics:**
- `glue.ALL.jvm.heap.usage` -- average executor heap utilization (%)
- `glue.ALL.jvm.heap.used` -- average executor heap used (bytes)
- `glue.ALL.system.cpuSystemLoad` -- average executor CPU load
- `glue.<executorId>.jvm.heap.usage` -- per-executor heap utilization

**I/O Metrics:**
- `glue.ALL.s3.filesystem.read_bytes` -- S3 read volume
- `glue.ALL.s3.filesystem.write_bytes` -- S3 write volume
- `glue.driver.aggregate.shuffleBytesWritten` -- shuffle write volume
- `glue.driver.aggregate.shuffleLocalBytesRead` -- shuffle read volume

### Alarm Thresholds

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| `driver.jvm.heap.usage` | > 50% | > 80% | Upgrade worker type or reduce driver operations |
| `ALL.jvm.heap.usage` | > 60% | > 85% | Add workers or upgrade worker type |
| `ALL.system.cpuSystemLoad` | > 0.8 | > 0.95 | Add workers for more parallelism |
| `numFailedTasks` | > 0 | > 10 | Investigate task failures in Spark UI |
| Job duration | > 1.5x baseline | > 2x baseline | Check for data growth or skew |

---

## Debugging Workflow

### Step-by-Step Diagnosis

1. **Check Job Status** -- Glue console > Jobs > Run history
   - Note the error message summary, duration, and DPU-hours consumed

2. **Review Job Run Insights** (Glue 2.0+)
   - Provides: failure line number, last Spark action, exception events, root cause analysis, recommended actions

3. **Examine CloudWatch Logs**
   - Output logs: `/aws-glue/jobs/output` -- standard output, print statements
   - Error logs: `/aws-glue/jobs/error` -- exceptions, stack traces, YARN errors
   - Search for: `OutOfMemoryError`, `Container killed by YARN`, `AccessDeniedException`, `ConnectionTimeoutException`

4. **Analyze CloudWatch Metrics**
   - Plot `jvm.heap.usage` for driver and executors over the job duration
   - Check CPU load patterns
   - Compare S3 read/write bytes to expected data volumes

5. **Inspect Spark UI**
   - Available from the Glue console for completed and running jobs
   - Stages tab: identify slow stages and their operations
   - Tasks tab: look for skewed task durations
   - Storage tab: verify caching behavior
   - SQL tab: review query execution plans

6. **Reproduce in Interactive Session**
   - Start an interactive session with the same Glue version and worker configuration
   - Step through the job logic incrementally
   - Test with sample data to isolate the failing transformation

---

## Common Error Messages and Fixes

| Error Message | Likely Cause | Fix |
|---------------|-------------|-----|
| `java.lang.OutOfMemoryError: Java heap space` | Driver or executor OOM | See OOM section above |
| `Container killed by YARN for exceeding memory limits` | Executor OOM | Increase worker type or set memory overhead |
| `Command Failed with Exit Code 1` | Generic Spark executor failure | Check error logs for root cause |
| `AccessDeniedException` | IAM role missing permissions | Add required S3/Glue/KMS policies |
| `No space left on device` | Disk full during shuffle | Upgrade to a worker type with more disk |
| `ConnectionTimeoutException` | Network/VPC misconfiguration | Verify NAT gateway, security groups, route tables |
| `Table not found in database` | Data Catalog reference error | Verify database/table names and crawler has run |
| `AnalysisException: cannot resolve` | Column name mismatch | Check schema mapping and case sensitivity |
| `GlueException: Insufficient Lake Formation permissions` | Lake Formation ACL issue | Grant required Lake Formation permissions |
| `Job bookmark validation failed` | Bookmark state corruption | Reset job bookmark and rerun |

---

## Proactive Monitoring Setup

### Recommended CloudWatch Dashboard

Create a Glue monitoring dashboard with:
- Job success/failure rate over time
- Average and P95 job duration by job name
- DPU-hours consumed per day/week
- Driver and executor memory utilization heatmap
- Active executor count timeline

### EventBridge Rules

Set up EventBridge rules for:
- `Glue Job State Change` (FAILED, TIMEOUT) -- route to SNS/Slack for alerting
- `Glue Crawler State Change` (FAILED) -- alert on crawler failures
- `Glue Data Quality Evaluation Results` -- alert on quality rule failures

### Cost Monitoring

- Tag all Glue jobs with `project`, `team`, and `environment` tags
- Set up AWS Budgets with alerts for Glue spending thresholds
- Review Cost Explorer weekly, filtered by Glue service
