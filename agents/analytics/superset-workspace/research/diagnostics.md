# Apache Superset Diagnostics Guide

## Slow Queries

### Symptoms

- Charts take a long time to render
- SQL Lab queries time out or run slowly
- Dashboard load times exceed acceptable thresholds
- Users report "Loading..." states that last minutes

### Diagnostic Steps

1. **Identify the slow query**
   - Open the chart in Explore view and click "View Query" to see the generated SQL
   - In SQL Lab, check the query history for execution times
   - Review Superset logs for queries exceeding `SQLLAB_TIMEOUT`

2. **Analyze the query plan**
   ```sql
   EXPLAIN ANALYZE <your_query>;
   ```
   Look for: full table scans, missing indexes, expensive sorts, hash joins on large tables

3. **Check database-side metrics**
   - Monitor database CPU, memory, and I/O during query execution
   - Check for lock contention or resource queuing
   - Review database-specific slow query logs

4. **Review query patterns**
   - Is `SELECT *` being used? Specify only needed columns
   - Are there expensive JOINs that could be pre-materialized?
   - Is the time range filter too broad, scanning unnecessary partitions?

### Solutions

| Problem | Solution |
|---------|----------|
| Full table scans | Add indexes on filter and GROUP BY columns |
| Broad time ranges | Ensure time partitioning and align filters to partitions |
| Complex aggregations | Pre-aggregate in ETL, use materialized views |
| Large result sets | Add row limits, paginate, use approximate functions |
| Missing query caching | Configure `DATA_CACHE_CONFIG` with appropriate timeouts |
| Expensive virtual datasets | Materialize as physical tables or views |

### Configuration Tuning

```python
# Increase query timeout for long-running queries
SQLLAB_TIMEOUT = 300  # seconds (default: 30)
SUPERSET_WEBSERVER_TIMEOUT = 300

# Limit result set sizes
ROW_LIMIT = 50000          # Default row limit for charts
SQL_MAX_ROW = 100000       # Maximum rows SQL Lab can return
SAMPLES_ROW_LIMIT = 1000   # Row limit for data samples

# Enable async queries for SQL Lab
FEATURE_FLAGS = {
    "GLOBAL_ASYNC_QUERIES": True,
}
```

## Dashboard Loading Issues

### Symptoms

- Dashboard shows a blank page or spinner for extended periods
- Some charts load while others remain in "Loading..." state indefinitely
- Dashboard freezes or becomes unresponsive after loading
- Filter bar takes a long time to populate

### Diagnostic Steps

1. **Check browser developer tools**
   - Open Network tab: look for slow API requests (`/api/v1/chart/data`)
   - Open Console: check for JavaScript errors
   - Monitor memory usage in Performance tab

2. **Identify bottleneck charts**
   - Open each chart individually to isolate which ones are slow
   - Check if the issue is query time vs. rendering time

3. **Inspect filter queries**
   - Dashboard rendering is blocked until filter value data is retrieved
   - Filters that query large unindexed columns cause initial load delays

4. **Check network and infrastructure**
   - Verify connectivity between Superset and the analytical database
   - Check if reverse proxy or load balancer timeouts are too short
   - Monitor WebSocket connections if GAQ is enabled

### Solutions

| Problem | Solution |
|---------|----------|
| Too many charts | Split dashboard into tabs or multiple dashboards |
| Slow filter initialization | Pre-filter values with SQL, index filter columns |
| Large unoptimized charts | Reduce data volume, simplify queries |
| Browser memory exhaustion | Enable `DASHBOARD_VIRTUALIZATION` feature flag |
| Cascading re-renders | Update to 6.0+ for Redux memoization improvements |
| Embedded dashboard slow | Check cross-origin settings, reduce iframe overhead |

### Frontend Performance Tuning

```python
FEATURE_FLAGS = {
    "DASHBOARD_VIRTUALIZATION": True,      # Virtual scrolling
    "DASHBOARD_CROSS_FILTERS": True,       # Enable selectively
    "CLIENT_CACHE": True,                  # Browser-side caching
}

# Reduce initial load by limiting chart data
DEFAULT_SQLLAB_LIMIT = 1000
```

## Caching Issues

### Symptoms

- Dashboards always hit the database, never serve from cache
- Stale data displayed despite underlying data changes
- Inconsistent data between dashboard loads
- Cache warm-up jobs fail or produce no effect
- "Loading..." state persists with Global Async Queries enabled

### Diagnostic Steps

1. **Verify Redis connectivity**
   ```bash
   redis-cli -h <redis-host> -p 6379 ping
   # Expected: PONG

   # Check Redis memory usage
   redis-cli info memory

   # Check key count
   redis-cli dbsize
   ```

2. **Inspect cache keys**
   ```bash
   # List Superset cache keys
   redis-cli keys "superset_*" | head -20

   # Check specific key TTL
   redis-cli ttl "superset_data_<key>"
   ```

3. **Verify cache configuration**
   - Confirm `CACHE_CONFIG`, `DATA_CACHE_CONFIG`, and `FILTER_STATE_CACHE_CONFIG` are correctly set in `superset_config.py`
   - Ensure Redis URL is reachable from all Superset web servers and Celery workers
   - Verify that the same Redis instance/database is used by both web and worker processes

4. **Check for GAQ-specific issues**
   - GAQ does NOT work with in-memory caching; Redis is required
   - Verify `RESULTS_BACKEND` points to a shared Redis or S3 backend
   - Check that Celery workers have `superset.tasks.async_queries` in imports

### Solutions

| Problem | Solution |
|---------|----------|
| Cache never hit | Verify `CACHE_DEFAULT_TIMEOUT > 0`, check Redis connectivity |
| Stale data | Reduce cache timeout, implement cache invalidation strategy |
| Inconsistent data | Ensure all processes use the same Redis instance |
| Cache warm-up fails | Verify Celery Beat is running and task is scheduled |
| GAQ stuck loading | Check Redis backend, WebSocket server, Celery worker imports |
| Redis OOM | Configure `maxmemory` and `maxmemory-policy allkeys-lru` |
| Key serialization mismatch | Ensure consistent `CACHE_KEY_PREFIX` across all configs |

### Cache Debugging Configuration

```python
# Enable verbose cache logging
import logging
logging.getLogger("flask_caching").setLevel(logging.DEBUG)

# Verify cache is working programmatically
from superset.extensions import cache_manager
cache_manager.cache.set("test_key", "test_value", timeout=60)
assert cache_manager.cache.get("test_key") == "test_value"
```

## Database Connection Problems

### Symptoms

- "Connection refused" or "Connection timed out" errors
- "Could not translate host name to address" errors
- Intermittent connection drops during query execution
- "Too many connections" errors from the database
- SSL/TLS handshake failures
- Authentication failures after credential rotation

### Diagnostic Steps

1. **Test basic connectivity**
   ```bash
   # From within the Superset container/pod
   telnet <db-host> <db-port>

   # Or use database-specific CLI tools
   psql -h <host> -p 5432 -U <user> -d <database>
   mysql -h <host> -P 3306 -u <user> -p <database>
   ```

2. **Verify SQLAlchemy URI**
   - Check URI format: `dialect+driver://user:password@host:port/database`
   - URL-encode special characters in passwords
   - Verify the database driver is installed in the Superset environment

3. **Check connection pool health**
   - Monitor active connections from Superset to the database
   - Check if connections are being properly returned to the pool
   - Look for connection leak patterns in logs

4. **Review network configuration**
   - Firewall rules between Superset and the database
   - VPC peering or private link configuration
   - DNS resolution from the Superset environment
   - SSH tunnel configuration if applicable

### Solutions

| Problem | Solution |
|---------|----------|
| Connection refused | Verify host/port, firewall rules, database is running |
| Connection timeout | Check network path, increase `connect_timeout` in extras |
| Too many connections | Tune `pool_size` and `max_overflow`, add connection recycling |
| SSL errors | Verify cert paths, ensure CA certificates are mounted |
| Authentication failure | Verify credentials, check for password special characters |
| DNS resolution failure | Use IP address directly, verify DNS config |
| Intermittent drops | Add `pool_recycle=3600` to recycle stale connections |
| Driver not found | Install the appropriate PyPI package for the database |

### Connection Pool Configuration

```python
# Database connection extra settings (in DB connection UI)
{
    "engine_params": {
        "connect_args": {
            "connect_timeout": 10,
            "sslmode": "require"
        },
        "pool_size": 10,
        "max_overflow": 20,
        "pool_timeout": 30,
        "pool_recycle": 3600,
        "pool_pre_ping": true
    }
}
```

### Common Database Driver Packages

| Database | PyPI Package |
|----------|-------------|
| PostgreSQL | `psycopg2-binary` or `psycopg2` |
| MySQL | `mysqlclient` or `PyMySQL` |
| Snowflake | `snowflake-sqlalchemy` |
| BigQuery | `sqlalchemy-bigquery` |
| ClickHouse | `clickhouse-connect` |
| Trino | `trino` |
| Presto | `pyhive` |
| Redshift | `sqlalchemy-redshift` |
| Databricks | `databricks-sql-connector` |
| SQL Server | `pymssql` |
| Oracle | `cx_Oracle` |
| DuckDB | `duckdb-engine` |

## Celery Worker Issues

### Symptoms

- Async queries stuck in "pending" or "running" state indefinitely
- Scheduled reports not being sent
- Celery workers crashing and restarting repeatedly
- Tasks accumulating in the queue without being processed
- "Worker was sent SIGKILL" messages in logs
- Alert monitoring not triggering

### Diagnostic Steps

1. **Check worker status**
   ```bash
   # List active workers
   celery -A superset.tasks.celery_app inspect active

   # Check registered tasks
   celery -A superset.tasks.celery_app inspect registered

   # Monitor queue lengths
   celery -A superset.tasks.celery_app inspect reserved

   # Check for stuck tasks
   celery -A superset.tasks.celery_app inspect active_queues
   ```

2. **Verify Celery configuration**
   ```python
   # Ensure these imports are present
   CELERY_CONFIG.imports = (
       "superset.sql_lab",
       "superset.tasks.scheduler",
       "superset.tasks.thumbnails",
       "superset.tasks.async_queries",  # Required for GAQ
   )
   ```

3. **Check Redis broker health**
   ```bash
   # Verify broker connectivity
   redis-cli -h <broker-host> ping

   # Check queue lengths
   redis-cli llen celery
   redis-cli llen default
   ```

4. **Review worker logs**
   - Look for `OOMKilled`, `SIGKILL`, or `WorkerLostError` messages
   - Check for task retry loops
   - Monitor task execution duration trends

### Solutions

| Problem | Solution |
|---------|----------|
| Tasks not picked up | Verify worker is running and connected to correct broker |
| Tasks stuck pending | Check imports in `CELERY_CONFIG`, restart workers |
| Worker OOMKilled | Increase memory limits, use `--pool solo`, limit concurrency |
| Beat not scheduling | Verify `celery beat` process is running, check schedule config |
| Task retry loops | Check for transient errors, increase retry delays |
| Queue backlog | Add more workers, implement task priority routing |
| Reports not sending | Verify SMTP/Slack config, check `ALERT_REPORTS` feature flag |

### Kubernetes-Specific Celery Issues

The default Celery `prefork` pool spawns child processes that can exceed Kubernetes pod memory limits:

```python
# Option 1: Use solo pool (recommended for K8s)
# In Helm chart values or worker command:
# celery worker --pool solo --concurrency 1

# Option 2: Use gevent pool (requires gevent installed)
# celery worker --pool gevent --concurrency 100

# Option 3: Increase memory limits in Helm values
supersetWorker:
  resources:
    limits:
      memory: "8Gi"   # Increase from default
```

### Worker Health Monitoring

```python
# Configure task time limits
CELERY_CONFIG.task_time_limit = 600      # Hard time limit (seconds)
CELERY_CONFIG.task_soft_time_limit = 500  # Soft limit (raises exception)

# Configure task result expiration
CELERY_CONFIG.result_expires = 86400  # 24 hours

# Enable task events for monitoring
CELERY_CONFIG.worker_send_task_events = True
CELERY_CONFIG.task_send_sent_event = True
```

## Memory Issues

### Symptoms

- Superset web server processes consuming excessive memory
- Celery workers growing in memory over time (memory leaks)
- OOMKilled pods in Kubernetes
- Slow garbage collection causing request latency spikes
- Browser tab crashes when viewing large dashboards

### Diagnostic Steps

1. **Server-side memory profiling**
   ```bash
   # Monitor process memory from within the container
   ps aux --sort=-rss | head -10

   # Check memory allocation over time (K8s)
   kubectl top pods -n superset

   # Check for OOMKilled events
   kubectl describe pod <pod-name> -n superset | grep -A5 "Last State"
   ```

2. **Identify memory-intensive operations**
   - Large result set processing (especially nested JSON fields)
   - Thumbnail generation for many dashboards
   - Concurrent query execution across multiple workers
   - Chart rendering with very large datasets

3. **Client-side memory profiling**
   - Open Chrome DevTools > Memory tab
   - Take heap snapshots before and after loading dashboards
   - Look for detached DOM nodes and large retained arrays
   - Monitor JavaScript heap size in Performance tab

### Server-Side Memory Solutions

| Problem | Solution |
|---------|----------|
| Worker memory leak | Configure `--max-tasks-per-child=100` to restart workers periodically |
| Large result sets | Reduce `SQL_MAX_ROW`, limit nested field expansion |
| Nested JSON OOM | Avoid querying deeply nested columns (e.g., Presto MAP/ARRAY types) |
| Gunicorn memory growth | Configure `--max-requests=1000 --max-requests-jitter=50` |
| Thumbnail generation OOM | Limit concurrent thumbnail tasks, increase worker memory |
| Many concurrent queries | Limit Celery concurrency, implement query queuing |

### Gunicorn Memory Management

```bash
# Start Gunicorn with memory management options
gunicorn \
  --bind 0.0.0.0:8088 \
  --workers 4 \
  --threads 4 \
  --timeout 300 \
  --max-requests 1000 \
  --max-requests-jitter 50 \
  --worker-class gthread \
  "superset.app:create_app()"
```

The `--max-requests` flag causes Gunicorn to respawn workers after a set number of requests, preventing gradual memory growth from leaking.

### Celery Worker Memory Management

```python
# Restart workers after processing N tasks to free leaked memory
CELERY_CONFIG.worker_max_tasks_per_child = 100

# Limit prefork pool memory
CELERY_CONFIG.worker_max_memory_per_child = 400000  # 400MB in KB

# Use solo pool to avoid subprocess memory multiplication
# celery worker --pool solo
```

### Client-Side Memory Solutions

| Problem | Solution |
|---------|----------|
| Dashboard with 50+ charts | Split into tabs, enable `DASHBOARD_VIRTUALIZATION` |
| Large table renderings | Paginate results, limit visible rows |
| Memory leak on navigation | Clear state on dashboard switch, report bug if persistent |
| Embedded dashboard OOM | Reduce chart count, optimize data volume |

### Kubernetes Resource Configuration

```yaml
# Helm chart values for memory management
supersetNode:
  resources:
    requests:
      memory: "1Gi"
    limits:
      memory: "4Gi"

supersetWorker:
  resources:
    requests:
      memory: "2Gi"
    limits:
      memory: "8Gi"    # Workers need more memory for query processing

# Pod disruption budget for rolling restarts
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

### Memory Monitoring Checklist

- [ ] Grafana dashboard monitoring per-pod memory usage
- [ ] Alerts on memory usage > 80% of limit
- [ ] OOMKilled event alerting via Kubernetes events
- [ ] Redis memory monitoring with `maxmemory` policy
- [ ] PostgreSQL shared_buffers and work_mem tuning
- [ ] Periodic review of query result sizes in SQL Lab
- [ ] Celery worker restart policy configured

## General Diagnostic Tools

### Log Analysis

```python
# superset_config.py logging configuration
ENABLE_TIME_ROTATE = True
FILENAME = "/var/log/superset/superset.log"
TIME_ROTATE_LOG_LEVEL = "INFO"  # Set to DEBUG for troubleshooting

# Per-module debug logging
import logging
logging.getLogger("superset.sql_lab").setLevel(logging.DEBUG)
logging.getLogger("superset.security").setLevel(logging.DEBUG)
logging.getLogger("flask_caching").setLevel(logging.DEBUG)
logging.getLogger("celery").setLevel(logging.DEBUG)
```

### Health Check Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/health` | Basic application health check |
| `/healthcheck` | Alias for health check |
| `/api/v1/database/test_connection` | Test database connectivity |

### StatsD Metrics

```python
# Enable StatsD for monitoring
from superset.stats_logger import StatsdStatsLogger
STATS_LOGGER = StatsdStatsLogger(
    host="statsd-host",
    port=8125,
    prefix="superset"
)
```

Key metrics emitted:
- `superset.query.time`: Query execution duration
- `superset.cache.hit`: Cache hit count
- `superset.cache.miss`: Cache miss count
- `superset.error`: Error count by type
- `superset.dashboard.load_time`: Dashboard rendering time

## Sources

- [Async Queries via Celery](https://superset.apache.org/docs/configuration/async-queries-celery/)
- [Caching Configuration](https://superset.apache.org/admin-docs/configuration/cache/)
- [Worker Memory Issues (GitHub #25604)](https://github.com/apache/superset/issues/25604)
- [High Memory Usage on Results (GitHub #20741)](https://github.com/apache/superset/issues/20741)
- [Celery Pool Discussion (GitHub #27070)](https://github.com/apache/superset/discussions/27070)
- [Slow Dashboard Issues (GitHub #29636)](https://github.com/apache/superset/issues/29636)
- [GAQ Setup Guide](https://medium.com/@ngigilevis/how-to-set-up-global-async-queries-gaq-in-apache-superset-a-complete-guide-9d2f4a047559)
- [Scaling Superset on Kubernetes](https://www.restack.io/docs/superset-on-kubernetes)
