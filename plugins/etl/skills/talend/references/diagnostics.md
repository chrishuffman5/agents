# Talend Diagnostics

## Job Failures

### Compilation Errors

**Symptoms**: Job fails to build or run with Java compilation errors.

**Common Causes**:
- Incompatible Java version (Java 8 code running on Java 17 runtime)
- Missing routine dependencies or corrupt project metadata
- Removed `javax` packages in Java 17 (replaced by `jakarta`)

**Diagnostic Steps**:
1. Check Error Log view: Window > Show View > Error Log
2. Review generated Java code: right-click job > Edit Code
3. Verify Java version: Help > About > Installation Details

**Resolutions**:
- Update custom routines for Java 17 compatibility
- Clean and rebuild: Project > Clean, then Build All
- Re-import missing external JARs in routine dependencies
- Check for deprecated APIs removed in Java 17

### Connection Failures

**Symptoms**: Job fails at database or API connection components.

**Common Causes**: Wrong credentials, network/firewall issues, connection pool exhaustion, JDBC driver incompatibility.

**Diagnostic Steps**:
1. Test connection from Metadata > DB Connection > right-click > Check
2. Review error message for specific JDBC error codes
3. Verify network connectivity: `telnet <host> <port>` from the execution server
4. Check database server logs for rejected connection attempts

**Resolutions**:

| Problem | Fix |
|---|---|
| Expired credentials | Update connection parameters in context variables |
| Driver version mismatch | Ensure JDBC driver version matches database server |
| Pool exhaustion | Increase connection pool limits on database server |
| Timeout | Configure connection timeout parameters on the component |
| Firewall blocking | Open required ports between engine host and data source |

### Data Errors

**Symptoms**: Job fails during data processing with type conversion, null pointer, or constraint violations.

**Diagnostic Steps**:
1. Enable row-level logging with tLogRow before the failing component
2. Check reject flows for detailed error information
3. Review tLogCatcher output for the specific exception stack trace
4. Use tSampleRow to isolate problematic records

**Resolutions**:
- Add null checks in tMap expressions: `row.field == null ? defaultValue : row.field`
- Validate data types and lengths before transformation
- Configure "Die on error" vs reject routing based on business requirements
- Set appropriate character encoding on file and database components

### Resource Exhaustion

**Symptoms**: OutOfMemoryError, disk space errors, jobs that hang or become unresponsive.

**Diagnostic Steps**:
1. Check JVM settings: Run tab > Advanced Settings
2. Monitor memory during execution with JVisualVM or JConsole
3. Check disk space on execution server
4. Review temp directory size: `${java.io.tmpdir}`

**Resolutions**:
- Increase JVM heap: `-Xms1024M -Xmx4096M` (or higher)
- Switch large lookups from in-memory to database joins or hash files
- Implement batch processing instead of loading entire datasets
- Clean temp files in tPostJob

### Studio vs Server Execution Discrepancy

**Symptoms**: Job runs successfully in Studio but fails on Remote Engine or JobServer.

**Common Causes**: Missing dependencies, different Java versions, environment-specific file paths, classpath differences.

**Diagnostic Steps**:
1. Build as Standalone Job in Studio and test on the execution server directly
2. Compare Java version on Studio vs execution server
3. Verify all external JARs are included in the built artifact
4. Check file paths and permissions on the execution server

**Resolutions**:
- Build artifact with all dependencies included (`--include-libs` in Maven)
- Ensure Java 17 is installed and configured on the execution server
- Replace hardcoded file paths with context variables
- Verify external JAR files are deployed to the execution server's lib directory

## Performance Bottlenecks

### Identifying Bottlenecks

**Step 1: Measure Baseline Performance**
- Enable tStatCatcher on the job to capture per-component execution times
- Record total job duration, row counts, and resource utilization
- Use TMC monitoring dashboards for production jobs

**Step 2: Identify the Bottleneck Component**
- Review tStatCatcher output: identify components with the longest duration
- Common bottleneck locations:
  - Database input/output components (I/O bound)
  - tMap with complex transformations or large lookups (CPU/memory bound)
  - tSort operations on large datasets (memory bound)
  - Network-bound components (API calls, remote file access)

**Step 3: Root Cause Analysis**

| Bottleneck Type | Indicators | Investigation |
|---|---|---|
| Database I/O | Long query execution time | Check execution plan, missing indexes, table locks |
| Network I/O | High latency on remote connections | Test network throughput, check firewall/proxy |
| CPU | High CPU utilization, slow transformations | Profile Java code, simplify expressions |
| Memory | Frequent GC pauses, swapping | Monitor heap usage, check for memory leaks |
| Disk I/O | Slow file reads/writes, temp file growth | Check disk speed, available space, I/O wait |

### Common Performance Fixes

**Database Performance**:
- Add indexes on columns used in WHERE clauses and JOIN conditions
- Use database-specific bulk loading (tBulkExec family) -- 50%+ write improvement
- Increase JDBC fetch size (default often 10; try 1,000-5,000 for large extracts)
- Use prepared statements and connection pooling
- Push filtering and aggregation to the database query

**Transformation Performance**:
- Simplify tMap expressions; move complex logic to routines (compiled once, not per-row inline)
- Remove unnecessary columns early with tFilterColumns
- Avoid tSort when possible; use ORDER BY in the source query
- Replace multiple sequential components with a single tMap where feasible

**I/O Performance**:
- Use compression for large file operations
- Write to local disk first, then transfer to network locations
- Use buffered I/O for file components
- Configure appropriate commit intervals on database output (1,000-10,000 rows)

**Parallelization**:
- Partition data by a key column and process partitions in parallel
- Use tParallelize for independent subjobs
- Configure thread pool sizes based on available resources
- Avoid parallelism on components writing to the same target table without isolation

## Remote Engine Issues

### Remote Engine (Classic) Diagnostics

**Engine Not Connected to TMC**:

Symptoms: Engine shows as "Unavailable" or "Disconnected" in TMC.

Diagnostic Steps:
1. Check engine service status: `systemctl status talend-remote-engine` (Linux) or Windows Services
2. Verify outbound HTTPS connectivity: `curl -v https://api.us.cloud.talend.com`
3. Check proxy configuration if behind corporate proxy
4. Review engine logs: `<RE_HOME>/logs/`

Resolutions:
- Restart the Remote Engine service
- Update proxy settings in `<RE_HOME>/etc/` configuration files
- Verify and renew the pairing token between engine and TMC
- Check firewall rules for outbound HTTPS (port 443)

**Job Fails on Engine but Works in Studio**:

Diagnostic Steps:
1. Build as Standalone Job in Studio and test directly on engine host
2. Compare Java versions (Studio vs Remote Engine)
3. Check if all external dependencies are included in the artifact
4. Verify context variables are configured in TMC
5. Check file paths and permissions on engine host

Resolutions:
- Ensure Java 17 on the Remote Engine host
- Include all external JARs in Maven build
- Configure context variables in TMC task definition
- Use configurable paths instead of absolute paths

**Task Execution Timeout**:

Diagnostic Steps:
1. Review TMC task timeout settings
2. Check execution logs for hang point
3. Monitor engine resource utilization (CPU, memory, disk, network)
4. Check for database locks or deadlocks

Resolutions:
- Increase task timeout in TMC if legitimately needed
- Optimize the job (see Performance Bottlenecks)
- Implement checkpointing for long-running jobs
- Resolve resource contention

### Remote Engine Gen2 Diagnostics

**Engine Startup Failures**:

Diagnostic Steps:
1. Check container logs: `docker-compose logs -f --tail 50 component-server`
2. Verify Docker resource allocation (memory, CPU limits)
3. Check port conflicts on 9005 (default)
4. Verify Docker and Docker Compose versions

Resolutions:
- Increase Docker resource limits
- Change default port in `.env` file if 9005 is in use
- Update Docker to required version
- Restart Docker service and containers

**Heartbeat/Connectivity Issues**:

- TMC considers connection broken after 180 seconds without heartbeat
- Check network from container to Talend Cloud
- Verify DNS resolution within container
- Update proxy in engine configuration
- Restart VM or Docker containers

**Database Driver Issues**:

Symptoms: "Driver not found" or JDBC connection errors.

Resolutions:
- Copy JDBC driver JAR to engine's extensions directory
- Restart engine containers after adding drivers
- Verify driver class name in connection configuration

## Memory Management

### JVM Memory Configuration

| Parameter | JVM Flag | Default | Production Recommendation |
|---|---|---|---|
| Min Heap | `-Xms` | 256M | 1-4 GB |
| Max Heap | `-Xmx` | 1024M | 2-8 GB |
| Metaspace | `-XX:MaxMetaspaceSize` | JVM default | 256-512M if needed |
| Stack Size | `-Xss` | JVM default | Rarely needs change |

### Where to Configure

| Environment | Configuration Location |
|---|---|
| **Talend Studio** (per-job) | Run tab > Advanced Settings |
| **Talend Studio** (IDE) | TalendStudio.ini -- modify `-Xms`/`-Xmx`, restart Studio |
| **Remote Engine** | `<RE_HOME>/bin/setenv.sh` (Linux) or `setenv.bat` (Windows) -- JAVA_MIN_MEM, JAVA_MAX_MEM |
| **TMC Cloud execution** | Task Advanced Settings or engine Run Profiles |

### Memory Sizing Guidelines

| Data Volume | Recommended Heap (-Xmx) | Notes |
|---|---|---|
| Small (< 100K rows) | 1 GB | Default usually sufficient |
| Medium (100K - 1M rows) | 2-4 GB | Increase for jobs with lookups |
| Large (1M - 10M rows) | 4-8 GB | Use batch processing patterns |
| Very Large (> 10M rows) | 8-16 GB | Consider partitioning and parallelization |

### Diagnosing Memory Issues

**OutOfMemoryError: Java heap space**:
- Cause: Too much data loaded simultaneously
- Quick fix: Increase `-Xmx`
- Permanent fix: Batch processing (tFlowToIterate), replace in-memory lookups with DB joins, remove unnecessary columns early

**OutOfMemoryError: GC overhead limit exceeded**:
- Cause: JVM spending >98% time in GC with <2% heap recovered
- Quick fix: Increase `-Xmx`
- Permanent fix: Profile memory to find largest allocations; check for leaks in custom routines (unclosed streams, growing collections)

**OutOfMemoryError: Metaspace**:
- Cause: Too many loaded classes (many components or dynamic class generation)
- Fix: Increase `-XX:MaxMetaspaceSize=512M`

### Garbage Collection Tuning

**Recommended for Talend 8.0 (Java 17)**:
- **G1GC** (default): Good general-purpose collector, suitable for most workloads
  - `-XX:+UseG1GC` (default)
  - `-XX:G1HeapRegionSize=16M` for large heaps
  - `-XX:MaxGCPauseMillis=200` to control pause times
- **ZGC**: For very large heaps (>16 GB) requiring low-latency pauses
  - `-XX:+UseZGC`

**GC Monitoring**:
- Enable logging: `-Xlog:gc*:file=gc.log:time,level,tags`
- Analyze with GCViewer or GCEasy
- Key metrics: GC frequency, pause duration, heap usage after GC

### Memory Leak Detection

**Symptoms**: Heap usage grows continuously; increasing GC frequency; job that worked initially fails after more data.

**Investigation**:
1. Enable heap dumps on OOM: `-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp/`
2. Analyze with Eclipse MAT or VisualVM
3. Look for: large collections growing unboundedly, unclosed connections/result sets, cached objects never evicted

**Common Leak Sources**:
- Custom routines with static collections accumulating data across rows
- Database connections opened in tJava but not closed
- Large XML/JSON documents parsed entirely into memory
- tLogRow in production accumulating output buffers

## Monitoring and Observability

### Built-in Monitoring

**TMC Dashboards**:
- Execution history with status, duration, row counts
- Log viewer for output and error details
- Dashboard views for task health and trends
- Alert configuration for failure notifications

**tStatCatcher**:
- Embed in every production job to capture per-component metrics
- Route statistics to a monitoring database for historical analysis
- Track execution trends: duration over time, row count variations

### External Integration

- **APM tools**: Datadog, New Relic, Dynatrace, Prometheus integration via engine metrics
- **Log aggregation**: Forward Remote Engine logs to ELK Stack or Splunk
- Configure log4j/logback for structured logging with correlation IDs (job name, execution ID, task ID)

### Health Check Checklist

| Check | Frequency | Method |
|---|---|---|
| Remote Engine connectivity | Continuous | TMC dashboard / heartbeat |
| Job success rate | Daily | TMC execution history |
| Execution duration trends | Weekly | tStatCatcher database analysis |
| Disk space on engine hosts | Daily | OS monitoring |
| JVM heap utilization | Per-execution | GC logs / APM |
| Database connection pool usage | Daily | Database monitoring tools |
| Artifact repository availability | Daily | Nexus/Artifactory health check |
