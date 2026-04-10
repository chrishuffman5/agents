# Apache Spark Research Summary

## Research Date: April 2026

---

## Key Findings

### Architecture
- Spark uses a Driver-Executor model with a pluggable Cluster Manager (Standalone, YARN, Kubernetes)
- The Catalyst optimizer + Tungsten engine provide automatic query optimization and code generation for DataFrame/SQL workloads
- Kubernetes is the emerging standard deployment mode, with Mesos support removed in Spark 4.0
- Unified Memory Manager (since 1.6) dynamically shares memory between storage (caching) and execution (shuffles/joins)
- AQE (Adaptive Query Execution), enabled by default since 3.2, provides runtime optimization with 20-40% improvement on skewed workloads

### Version Landscape (as of April 2026)
- **Spark 3.5.x**: Extended LTS through November 2027 (security fixes only). Last version supporting Java 8/11 and Scala 2.12
- **Spark 4.0.x**: Current stable major version (released June 2025). Major breaking changes: ANSI mode default, Java 17 minimum, Scala 2.13 only, Mesos removed
- **Spark 4.1.x**: Latest GA release (December 2025). Key additions: Spark Declarative Pipelines, Real-Time Streaming Mode, SQL Scripting GA, VARIANT GA with shredding
- **Spark 4.2.0**: In preview (preview 3 released March 2026), GA expected mid-2026

### ETL Platform Strengths
- Mature DataFrame/SQL API with Catalyst optimization makes most ETL logic expressible without UDFs
- Spark Declarative Pipelines (4.1+) provides a built-in declarative ETL framework
- Strong integration with all major open table formats (Delta Lake, Iceberg, Hudi)
- Structured Streaming unifies batch and streaming ETL with exactly-once guarantees
- Real-Time Mode (4.1+) enables sub-second streaming latency without API changes
- Python Data Source API (4.0+) enables Python-only custom connectors

### Performance Critical Points
- Partition sizing (128-256 MB), shuffle minimization, and broadcast joins are the highest-impact optimizations
- Pandas UDFs are 10-100x faster than Python UDFs; built-in functions are fastest
- Data skew is the most common production performance issue; AQE handles it automatically in many cases
- 5 cores per executor is optimal for HDFS I/O throughput

---

## Confidence Levels

| Topic | Confidence | Notes |
|-------|-----------|-------|
| Core architecture (Driver/Executor/DAG) | **High** | Stable, well-documented, unchanged for years |
| Spark 3.5 features and LTS status | **High** | Confirmed via official Apache Spark versioning policy |
| Spark 4.0 features and breaking changes | **High** | GA released, official release notes available |
| Spark 4.1 features (SDP, RTM) | **High** | GA released December 2025, official docs available |
| Spark 4.2 features | **Low** | Still in preview, features may change before GA |
| AQE behavior and configuration | **High** | Stable since 3.2, well-documented |
| Memory management model | **High** | Unified Memory Manager stable since 1.6, well-documented |
| Join optimization strategies | **High** | Core feature, extensive documentation |
| Resource sizing formulas | **Medium** | Rules of thumb vary by workload; 5-cores-per-executor is widely cited but workload-dependent |
| Cost optimization (cloud) | **Medium** | Cloud-provider-specific; Spot savings percentages vary |
| Medallion architecture | **High** | Well-established pattern, widely adopted |
| Testing frameworks (chispa, etc.) | **High** | Active libraries, Spark 4.1 built-in testing utils |
| Monitoring/Prometheus integration | **High** | Built-in since Spark 3.0, well-documented |
| Delta Lake vs Iceberg vs Hudi comparison | **Medium** | Rapidly evolving; feature parity closing. XTable/UniForm enabling interop |
| Python Data Source API | **Medium** | New in 4.0, limited production case studies so far |

---

## Research Gaps

### Areas Needing Deeper Investigation
1. **Spark 4.2 specific features**: Only preview releases available; feature list will be finalized at GA
2. **Spark Connect production experience**: GA in 4.0 but limited production case studies published comparing Connect vs Classic mode performance
3. **Spark Declarative Pipelines in production**: Very new (4.1, Dec 2025); limited real-world battle-testing reports
4. **Real-Time Mode benchmarks**: Sub-second latency claims from Databricks; independent benchmarks scarce
5. **GPU acceleration**: RAPIDS Accelerator for Spark exists but was not deeply researched
6. **Specific cloud provider integrations**: Detailed EMR/Dataproc/Synapse-specific optimizations and configurations
7. **Spark on ARM/Graviton**: Performance characteristics on ARM-based cloud instances
8. **Security**: Authentication, encryption, access control patterns (Kerberos, Ranger, Unity Catalog)

### Information Reliability Notes
- Official Apache Spark documentation and release notes are primary sources
- Databricks blog posts provide detailed feature descriptions but may emphasize Databricks-specific features
- Medium articles and blog posts used for community practices; cross-referenced where possible
- Resource sizing formulas are guidelines; actual sizing requires workload-specific benchmarking

---

## Sources

### Official Documentation
- [Apache Spark Release Notes](https://spark.apache.org/news/)
- [Spark 4.0.0 Release](https://spark.apache.org/releases/spark-release-4-0-0.html)
- [Spark 4.1.0 Release](https://spark.apache.org/releases/spark-release-4.1.0.html)
- [Spark Versioning Policy](https://spark.apache.org/versioning-policy.html)
- [Spark Cluster Mode Overview](https://spark.apache.org/docs/latest/cluster-overview.html)
- [Spark Performance Tuning](https://spark.apache.org/docs/latest/sql-performance-tuning.html)
- [Spark Monitoring](https://spark.apache.org/docs/latest/monitoring.html)
- [Spark Structured Streaming Guide](https://spark.apache.org/docs/latest/streaming/index.html)
- [Spark Migration Guide: SQL](https://spark.apache.org/docs/latest/sql-migration-guide.html)
- [Spark Migration Guide: Core](https://spark.apache.org/docs/latest/core-migration-guide.html)
- [Spark Declarative Pipelines Guide](https://spark.apache.org/docs/latest/declarative-pipelines-programming-guide.html)
- [PySpark Testing](https://spark.apache.org/docs/latest/api/python/getting_started/testing_pyspark.html)
- [PySpark UDFs and UDTFs](https://spark.apache.org/docs/latest/api/python/user_guide/udfandudtf.html)
- [Spark Connect Overview](https://spark.apache.org/spark-connect/)
- [Apache Spark End of Life](https://endoflife.date/apache-spark)

### Vendor Documentation
- [Databricks: Introducing Spark 4.0](https://www.databricks.com/blog/introducing-apache-spark-40)
- [Databricks: Introducing Spark 4.1](https://www.databricks.com/blog/introducing-apache-sparkr-41)
- [Databricks: Real-Time Mode Architecture](https://www.databricks.com/blog/breaking-microbatch-barrier-architecture-apache-spark-real-time-mode)
- [Databricks: Medallion Architecture](https://www.databricks.com/blog/what-is-medallion-architecture)
- [Databricks: AQE](https://www.databricks.com/blog/2020/05/29/adaptive-query-execution-speeding-up-spark-sql-at-runtime.html)
- [Databricks: Debugging Spark UI](https://docs.databricks.com/en/compute/troubleshooting/debugging-spark-ui.html)
- [AWS: Spark on EMR Best Practices](https://aws.github.io/aws-emr-best-practices/docs/bestpractices/Applications/Spark/troubleshooting/)
- [AWS: Spark Performance Tuning](https://docs.aws.amazon.com/prescriptive-guidance/latest/spark-tuning-glue-emr/using-adaptive-query-execution.html)
- [AWS: Spark on K8s with Spot](https://aws.amazon.com/blogs/compute/running-cost-optimized-spark-workloads-on-kubernetes-using-ec2-spot-instances/)

### Community Resources
- [Chispa (PySpark testing)](https://github.com/MrPowers/chispa)
- [spark-fast-tests (Scala testing)](https://github.com/mrpowers-io/spark-fast-tests)
- [Spark Memory Deep Dive (luminousmen)](https://luminousmen.com/post/dive-into-spark-memory/)
- [Onehouse: Table Format Comparison](https://www.onehouse.ai/blog/apache-hudi-vs-delta-lake-vs-apache-iceberg-lakehouse-feature-comparison)
- [Grafana: Spark Performance Metrics Dashboard](https://grafana.com/grafana/dashboards/7890-spark-performance-metrics/)
