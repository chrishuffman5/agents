# Databricks Best Practices Reference

## Delta Lake Table Design

### Choosing a Clustering Strategy

**Decision tree:**
1. New table? -> Use Liquid Clustering (recommended default)
2. Existing table with Hive partitioning? -> Migrate to Liquid Clustering if query patterns are diverse; keep Hive partitioning if queries always filter on a single low-cardinality column
3. Need multi-dimensional co-location? -> Liquid Clustering (Hilbert curves) is superior to Z-ORDER

**Liquid Clustering best practices:**
- Choose 1-4 columns that appear most frequently in WHERE, JOIN, and GROUP BY clauses
- Order columns from highest to lowest filtering selectivity
- Run `OPTIMIZE` regularly (ideally after each batch write or on a schedule)
- Start with fewer clustering columns (1-2) and add more only if query patterns demand it
- Change clustering columns with `ALTER TABLE ... CLUSTER BY` -- no full rewrite needed

**When Hive-style partitioning is still appropriate:**
- Extremely large tables (10+ TB) where queries always filter on a single low-cardinality date column
- Tables shared with non-Databricks engines that do not support Liquid Clustering
- Regulatory requirements mandating physical data separation

### File Size Optimization

- Target file size: 256 MB to 1 GB (Delta Lake default target is ~1 GB for OPTIMIZE)
- Too many small files: high metadata overhead, slow file listing, poor scan performance
- Too few large files: poor parallelism, long task durations, wasted reads when filtering
- Configure target file size: `ALTER TABLE ... SET TBLPROPERTIES ('delta.targetFileSize' = '256mb')`
- For streaming tables with frequent small writes, run `OPTIMIZE` regularly or use DLT (which auto-optimizes)
- Auto-compaction: `delta.autoOptimize.autoCompact = true` triggers lightweight compaction on writes
- Optimized writes: `delta.autoOptimize.optimizeWrite = true` coalesces small files during write

### Schema Evolution

- Use `mergeSchema = true` for additive changes (new columns, widening types) during writes:
  ```python
  df.write.format("delta").mode("append").option("mergeSchema", "true").saveAsTable("catalog.schema.table")
  ```
- Use `overwriteSchema = true` for breaking changes (dropping columns, type changes) -- rewrites metadata
- With MERGE statements: set `spark.databricks.delta.schema.autoMerge.enabled = true` to auto-evolve schema
- Column mapping: enable `delta.columnMapping.mode = 'name'` to support column rename and drop without rewriting data
- Always test schema changes in a development environment before applying to production

### VACUUM and Retention

- Default retention: 7 days (`delta.deletedFileRetentionDuration = 'interval 7 days'`)
- Never set retention below your longest-running query duration or streaming checkpoint interval
- Run VACUUM regularly (daily or weekly) to reclaim storage from deleted files
- VACUUM is incremental -- it only lists and deletes files; it does not rewrite data
- Predictive optimization auto-runs VACUUM on managed tables in Unity Catalog -- confirm it is enabled
- Monitoring: `DESCRIBE HISTORY table` shows when VACUUM last ran and how many files were removed

### Change Data Feed

- Enable CDF when downstream consumers need incremental changes (CDC pipelines, incremental ETL)
- CDF adds storage overhead (~10-20%) for the change data files
- CDF change records include `_change_type` (insert, update_preimage, update_postimage, delete), `_commit_version`, and `_commit_timestamp`
- Use `table_changes()` function to read changes efficiently
- CDF works with both batch and streaming readers

## Unity Catalog Governance

### Namespace Organization

**Recommended catalog structure:**

| Catalog | Purpose | Who Has Access |
|---|---|---|
| `raw` | Landing zone for raw ingested data | Data engineers (full), analysts (read) |
| `curated` or `silver` | Cleaned, conformed, business-modeled data | Data engineers (full), analysts (read) |
| `analytics` or `gold` | Aggregated, report-ready tables | Analysts, BI tools, data scientists (read) |
| `sandbox` | Ad hoc exploration, personal schemas | Individual users (own schema) |
| `ml` | Feature tables, training datasets, model artifacts | Data scientists, ML engineers |

**Schema naming conventions:**
- Use domain-driven naming: `analytics.finance.revenue`, `analytics.marketing.campaigns`
- Create per-team or per-project schemas in `sandbox` catalog
- Use `information_schema` queries to audit schema proliferation

### Access Control Patterns

**Principle of least privilege:**
1. Grant `USAGE` on catalogs/schemas to groups, not individuals
2. Grant `SELECT` on production tables to consumer groups
3. Grant `MODIFY` only to ETL service principals and data engineers
4. Use row filters and column masks for PII rather than creating separate filtered tables
5. Use `ALL PRIVILEGES` sparingly -- only for catalog/schema owners

**Service principal pattern for ETL:**
```sql
-- Create groups
CREATE GROUP `etl-writers`;
CREATE GROUP `analytics-readers`;

-- Grant ETL service principal full access to raw and curated
GRANT USAGE, CREATE SCHEMA ON CATALOG raw TO `etl-writers`;
GRANT USAGE, CREATE TABLE, MODIFY, SELECT ON SCHEMA raw.ingestion TO `etl-writers`;

-- Grant analysts read-only access to analytics
GRANT USAGE ON CATALOG analytics TO `analytics-readers`;
GRANT USAGE ON SCHEMA analytics.finance TO `analytics-readers`;
GRANT SELECT ON SCHEMA analytics.finance TO `analytics-readers`;
```

**External locations:**
- Map cloud storage paths to Unity Catalog external locations with fine-grained access
- Use storage credentials (IAM roles / service principals) scoped to specific paths
- Avoid granting direct cloud storage access; route all access through Unity Catalog

### Data Lineage

- Lineage is automatically captured -- no configuration needed
- View lineage in the Unity Catalog UI (Catalog Explorer > table > Lineage tab)
- Query lineage programmatically via `system.access.table_lineage` and `system.access.column_lineage`
- Lineage tracks: notebooks, Workflows jobs, DLT pipelines, SQL warehouse queries
- Use lineage for impact analysis before schema changes or table deprecation

### Delta Sharing

**Provider-side best practices:**
- Share only the minimal set of tables/partitions needed by the recipient
- Use partition filtering on shares to limit data exposure
- Rotate recipient tokens on a regular schedule
- Monitor share access via `system.access.audit` logs
- Use recipient properties to tag and identify external consumers

**Consumer-side best practices:**
- Treat shared data as external -- apply schema validation before downstream use
- Monitor for schema changes in shared tables
- Cache shared data locally if latency-sensitive queries are needed

## Compute Configuration

### Cluster Sizing Guidelines

| Workload Type | Recommended Config |
|---|---|
| Small ETL (< 100 GB) | Single node or 2-4 workers, standard VMs |
| Medium ETL (100 GB - 1 TB) | 4-16 workers, memory-optimized VMs, Photon |
| Large ETL (> 1 TB) | 16-64+ workers, memory-optimized, Photon, auto-scaling |
| Interactive / ad hoc | 2-8 workers, auto-scaling, Photon, auto-termination 15 min |
| Streaming | Fixed-size cluster (avoid auto-scaling oscillation), memory-optimized |
| ML training | GPU clusters (A10G, A100, T4), single node for experimentation |

### Cluster Policies

Cluster policies restrict what users can configure, preventing cost overruns and misconfigurations:

```json
{
  "spark_version": { "type": "regex", "pattern": "1[4-9]\\..*" },
  "node_type_id": {
    "type": "allowlist",
    "values": ["i3.xlarge", "i3.2xlarge", "i3.4xlarge"]
  },
  "num_workers": { "type": "range", "maxValue": 20 },
  "autotermination_minutes": {
    "type": "range", "minValue": 10, "maxValue": 120, "defaultValue": 30
  },
  "custom_tags.team": { "type": "fixed", "value": "data-engineering" },
  "aws_attributes.availability": {
    "type": "allowlist",
    "values": ["SPOT_WITH_FALLBACK", "SPOT"]
  }
}
```

**Key policies to enforce:**
- Maximum worker count per cluster
- Auto-termination minimum (prevent always-on interactive clusters)
- Allowed instance types (prevent expensive GPU/memory instances for non-ML workloads)
- Spot instance usage for batch workloads
- Custom tags for cost attribution
- Databricks runtime version (prevent outdated runtimes)

### Spot Instances and Cost Optimization

- **Workers:** Use spot instances for batch ETL workers (60-90% savings). Set `SPOT_WITH_FALLBACK` for reliability.
- **Driver:** Always use on-demand for the driver node -- driver failure kills the entire job
- **Streaming:** Avoid spot for streaming workloads unless you can tolerate restart delays
- **Auto-scaling:** Set `min_workers` to handle baseline load on on-demand; let auto-scaling add spot workers for peaks
- **Graviton/ARM instances (AWS):** 20-40% cheaper than equivalent x86 instances; supported in Databricks Runtime 13.0+

### SQL Warehouse Configuration

**Serverless SQL warehouses (recommended):**
- Zero management overhead, sub-second startup
- Auto-scaling from 0 to configured maximum
- Best for: dashboards, ad hoc SQL, scheduled queries, BI tool connections
- Set appropriate auto-stop delay (5-10 minutes for active users, 1 minute for scheduled queries)

**Pro SQL warehouses:**
- Use when serverless is not available in your region
- Enable Photon for performance
- Configure cluster size (T-shirt sizing: 2X-Small to 4X-Large) based on concurrency and data volume
- Set scaling min/max for concurrent query capacity

**Channel selection:**
- Current channel: latest stable features, recommended for production
- Preview channel: early access to upcoming features, use in development

## Workflow Design

### Job Structure

**Single-task jobs:**
- Simple batch ETL, scheduled notebooks, SQL queries
- Use serverless compute for fastest startup and lowest cost

**Multi-task jobs (DAGs):**
- Model task dependencies explicitly
- Use shared job clusters when multiple tasks need the same cluster configuration to avoid repeated cluster startup
- Pass data between tasks via Delta tables (not task values for large data)
- Use task values (`dbutils.jobs.taskValues.set/get`) for small metadata (row counts, status flags)

**Conditional tasks:**
- `IF/ELSE` conditions based on task values or job parameters
- `FOR EACH` loops over arrays for parameterized parallel execution
- Error handling: `on_failure` tasks for alerting and cleanup

### Idempotent Pipeline Design

- **MERGE (upsert) over INSERT:** Use MERGE for incremental loads to handle reprocessing gracefully
- **Overwrite partition:** For full-refresh loads, overwrite by partition to maintain atomicity:
  ```python
  df.write.format("delta").mode("overwrite") \
    .option("replaceWhere", "event_date = '2026-04-07'") \
    .saveAsTable("catalog.schema.events")
  ```
- **Write-audit-publish pattern:** Write to a staging table, validate, then swap/merge into production
- **Structured Streaming exactly-once:** Checkpoints + Delta's transactional writes guarantee exactly-once end-to-end

### Error Handling and Alerting

- Configure task-level retries for transient failures (network errors, spot instance reclamation)
- Set job-level email/webhook/PagerDuty notifications for failures
- Use `on_failure` dependency tasks for cleanup (e.g., dropping temp tables, sending Slack alerts)
- Monitor job health via `system.lakeflow.job_run_timeline`
- Set SLA expectations using job run duration alerts

## Performance Tuning

### Query Optimization Checklist

1. **Use Liquid Clustering** on frequently filtered columns
2. **Collect table statistics:** `ANALYZE TABLE ... COMPUTE STATISTICS FOR ALL COLUMNS`
3. **Check file count and sizes:** `DESCRIBE DETAIL table` -- run OPTIMIZE if needed
4. **Enable Photon** for scan-heavy and aggregation-heavy queries
5. **Avoid `SELECT *`:** Project only needed columns to maximize data-skipping benefits
6. **Use predicate pushdown:** Place filter conditions as early as possible in the query
7. **Broadcast small tables:** For joins where one side is < 100 MB, use broadcast hint or rely on AQE
8. **Tune shuffle partitions:** Default 200 may be too low for large datasets; AQE coalesces partitions automatically
9. **Cache frequently accessed data:** `CACHE SELECT * FROM table WHERE ...` for repeated interactive queries
10. **Avoid UDFs when possible:** Native SQL functions and Photon are much faster than Python/Scala UDFs

### Join Optimization

| Join Strategy | When Used | Best For |
|---|---|---|
| Broadcast hash join | One side < `spark.sql.autoBroadcastJoinThreshold` (default 10 MB) | Small dimension tables |
| Sort-merge join | Both sides large, pre-sorted or sortable | Large-to-large joins |
| Shuffle hash join | One side fits in memory per partition | Medium-to-large joins |
| Skew join (AQE) | Detected skew in sort-merge join partitions | Skewed data distributions |

**Handling skew:**
- Enable AQE skew join: `spark.sql.adaptive.skewJoin.enabled = true` (default in Databricks)
- Manual salting: add a random salt column to break up hot keys
- Pre-aggregate: reduce the large side before joining

### Streaming Performance

- **Trigger interval:** Shorter intervals increase overhead; longer intervals increase latency. Balance based on SLA.
- **Partition alignment:** Ensure Kafka partition count aligns with Spark parallelism
- **State management:** Use RocksDB state store for large stateful operations (enabled by default in Databricks)
- **Watermarks:** Set watermarks for windowed aggregations to bound state growth:
  ```python
  df.withWatermark("event_time", "1 hour").groupBy(window("event_time", "10 minutes")).count()
  ```
- **Auto Loader vs Kafka:** Use Auto Loader for file-based ingestion (S3/ADLS/GCS), Kafka for event streams
- **Backpressure:** Limit batch size with `maxFilesPerTrigger` (Auto Loader) or `maxOffsetsPerTrigger` (Kafka)

## MLflow and ML Best Practices

### Experiment Organization

- Create one experiment per project/model type under a team workspace path
- Use meaningful run names with parameters: `lr_0.01_epochs_100_v2`
- Log all hyperparameters, metrics, and artifacts consistently
- Tag runs with metadata: `mlflow.set_tag("team", "fraud-detection")`
- Use MLflow autologging for supported frameworks: `mlflow.sklearn.autolog()`, `mlflow.pytorch.autolog()`

### Model Registry (Unity Catalog)

- Register all production models in Unity Catalog: `models:/catalog.schema.model_name/version`
- Use model aliases instead of stages: `champion`, `challenger`, `archived`
- Set model alias for production serving:
  ```python
  from mlflow import MlflowClient
  client = MlflowClient()
  client.set_registered_model_alias("catalog.schema.my_model", "champion", version=5)
  ```
- Implement approval workflows: model review before promoting to `champion`
- Track model lineage: Unity Catalog automatically captures which tables were used for training

### Feature Engineering

- Store features as Unity Catalog tables with primary key and timestamp columns
- Use `FeatureEngineeringClient` to create and manage feature tables:
  ```python
  from databricks.feature_engineering import FeatureEngineeringClient
  fe = FeatureEngineeringClient()
  fe.create_table(
      name="catalog.schema.customer_features",
      primary_keys=["customer_id"],
      timestamp_keys=["update_ts"],
      df=feature_df
  )
  ```
- Use point-in-time lookups for training data to avoid data leakage
- Publish features to online stores for low-latency inference

## Security Best Practices

### Authentication

- Use OAuth M2M (service principals) for automated pipelines -- not personal access tokens
- Configure SCIM provisioning from your IdP for user/group lifecycle management
- Disable personal access tokens at the workspace level if OAuth is fully adopted
- Rotate service principal secrets regularly (every 90 days)

### Network Security

- Enable Private Link (AWS) or Private Endpoints (Azure) for production workspaces
- Use customer-managed VPC/VNet with no public IP for cluster nodes
- Restrict workspace access with IP access lists
- Use Unity Catalog network policies to restrict data access by network location

### Data Protection

- Enable customer-managed keys (CMK) for control plane encryption
- Use Unity Catalog row filters and column masks for PII protection
- Enable audit logging and monitor via `system.access.audit`
- Encrypt secrets with Databricks Secrets or integrate with cloud key vaults (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager)

## Cost Management

### Monitoring DBU Consumption

```sql
-- Daily DBU consumption by SKU
SELECT
  usage_date,
  sku_name,
  SUM(usage_quantity) AS total_dbus,
  SUM(usage_quantity * list_price) AS estimated_cost
FROM system.billing.usage u
JOIN system.billing.list_prices p ON u.sku_name = p.sku_name
  AND u.cloud = p.cloud
  AND u.usage_date BETWEEN p.price_start_time AND COALESCE(p.price_end_time, '2099-12-31')
WHERE usage_date >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY usage_date, sku_name
ORDER BY usage_date DESC, estimated_cost DESC;
```

### Cost Attribution

- Use custom tags on clusters and jobs for cost allocation by team/project
- Query `system.billing.usage` joined with cluster metadata for per-team cost reports
- Implement cluster policies with mandatory tags
- Use budgets and alerts in your cloud provider billing (AWS Budgets, Azure Cost Management)

### Optimization Checklist

1. Migrate interactive workloads to serverless SQL warehouses (eliminate idle cluster costs)
2. Move all production pipelines to job compute (lower DBU rate)
3. Enable spot instances for batch workers
4. Set auto-termination on all interactive clusters (10-30 minutes)
5. Use Photon for scan-heavy workloads (faster completion = fewer DBUs despite higher rate)
6. Enable predictive optimization to auto-manage OPTIMIZE and VACUUM
7. Right-size clusters: monitor CPU/memory utilization and reduce over-provisioned workers
8. Consolidate small jobs into multi-task Workflows to share compute
9. Use `trigger(availableNow=True)` instead of continuous streaming for near-real-time SLAs (minutes, not seconds)
10. Review and archive unused clusters, jobs, and notebooks monthly
