# Apache Superset Best Practices

## Dashboard Design

### Layout and Organization

- **Limit charts per dashboard**: Keep dashboards to 15-25 charts maximum. Dashboards with 50+ charts cause significant rendering overhead, though Redux memoization improvements in 2025 have helped
- **Use tabs for large dashboards**: Split related content into tabs rather than creating extremely long scrollable dashboards. Charts in inactive tabs do not render until the tab is selected
- **Design for the audience**: Executive dashboards should emphasize Big Number and trend visualizations; analyst dashboards can include more detailed tables and complex charts
- **Use consistent color schemes**: Apply consistent color palettes across related charts for visual coherence. Leverage Superset 6.0's theming system for organization-wide consistency
- **Add context with Markdown**: Include titles, descriptions, and contextual notes using Markdown components to help users interpret data correctly
- **Set meaningful default filters**: Configure default filter values so dashboards load with useful data immediately rather than showing empty states

### Filter Strategy

- **Use native filters over legacy filter boxes**: Native filters provide cascading, scoping, and cross-filter capabilities
- **Scope filters appropriately**: Not every filter needs to affect every chart. Use filter scoping to target specific charts or tabs
- **Implement cascading filters**: When filter values depend on other selections (e.g., country -> state -> city), configure dependent filters to reduce irrelevant options
- **Pre-filter large datasets**: Use SQL pre-filters on filter components to limit the values shown to users

### Cross-Filtering

- **Enable cross-filtering judiciously**: Cross-filtering is powerful but can cause cascading query execution. Enable it on dashboards where users benefit from interactive exploration
- **Design chart interactions**: Place charts that users will click on (bar charts, pie charts) near related detail charts that will respond to the filter

## SQL Lab Usage

### Query Writing

- **Select only needed columns**: Avoid `SELECT *`. Specify columns explicitly to reduce data transfer and improve performance
- **Use EXPLAIN ANALYZE**: Inspect query plans to identify performance issues before creating charts
- **Leverage Jinja templating**: Use `{{ current_username() }}`, `{{ url_param() }}`, and `{{ filter_values() }}` for dynamic, parameterized queries
- **Define parameters in SQL Lab**: Use the Parameters menu to define JSON parameters that can be referenced in Jinja templates for reusable queries

### Virtual Datasets

- **Prefer physical datasets when possible**: Physical datasets are faster because they can leverage table-level metadata and indexing
- **Optimize virtual dataset SQL**: When virtual datasets are necessary, ensure the underlying SQL is performant. Add appropriate WHERE clauses and aggregations
- **Materialize complex queries**: For frequently accessed virtual datasets with complex SQL, consider materializing the results as physical tables or views in your data warehouse
- **Document virtual datasets**: Add descriptions to calculated columns and metrics to help other users understand the business logic

### Query Management

- **Save frequently used queries**: Use the "Save As" feature to create a library of reusable queries
- **Use query tagging**: Tag queries by domain, team, or purpose for easier discovery
- **Clean up query history**: Configure `QUERY_HISTORY_RETENTION_DAYS` to automatically prune old query logs

## Chart Performance

### Query Optimization

- **Add indexes on filter and group-by columns**: Ensure your analytical database has appropriate indexes for columns commonly used in WHERE clauses and GROUP BY operations
- **Pre-aggregate data**: For dashboards showing high-level metrics, create summary tables rather than aggregating raw data at query time
- **Limit result sets**: Set reasonable row limits on charts. Most visualizations do not benefit from more than a few thousand data points
- **Use time partitioning**: Partition large tables by date and ensure time range filters align with partition boundaries
- **Avoid expensive JOINs in chart queries**: Complex multi-table joins should be handled in ETL/ELT pipelines or materialized views, not in chart definitions

### Visualization Selection

- **Choose appropriate chart types for data volume**: Time-series charts handle many data points well; pivot tables with thousands of cells will be slow to render
- **Use Big Number for KPIs**: Big Number visualizations are the fastest to render and most impactful for key metrics
- **Limit pie/donut chart segments**: Cap at 7-10 segments; group smaller values into "Other"
- **Use Table chart sparingly**: Tables with many columns and rows are expensive to render. Paginate results and limit visible columns

### Client-Side Performance

- **Enable dashboard virtualization**: The `DASHBOARD_VIRTUALIZATION` feature flag enables virtual scrolling, only rendering visible charts
- **Lazy-load charts in tabs**: Charts in inactive tabs are not rendered until the tab is activated, reducing initial load time
- **Minimize custom CSS**: Excessive custom CSS can cause layout recalculations and slow rendering

## Database Optimization

### Metadata Database

- **Use PostgreSQL for production**: PostgreSQL is the recommended metadata database for production. MySQL is supported but PostgreSQL generally performs better with Superset's query patterns
- **Never use SQLite in production**: SQLite does not support concurrent writes and will cause data corruption under load
- **Regular VACUUM and ANALYZE**: Run PostgreSQL maintenance to keep metadata queries fast
- **Monitor metadata DB size**: Query logs and cached data can cause the metadata database to grow significantly. Configure appropriate retention policies

### Analytical Database Configuration

- **Use OLAP-optimized databases**: Columnar databases (ClickHouse, Snowflake, BigQuery, StarRocks) are ideal for Superset's analytical query patterns
- **Configure connection pools appropriately**: Set `pool_size`, `max_overflow`, and `pool_timeout` based on your expected concurrency
- **Enable query cost estimation**: For supported databases, enable cost estimation so users can assess query impact before execution
- **Set query timeouts**: Configure `SQLLAB_TIMEOUT` and database-level timeouts to prevent runaway queries from consuming resources

```python
# Example database connection extra configuration
{
    "engine_params": {
        "pool_size": 10,
        "max_overflow": 20,
        "pool_timeout": 30,
        "pool_recycle": 3600
    }
}
```

### Data Modeling for Superset

- **Denormalize where practical**: Star schema or flat tables perform better than highly normalized schemas for analytical queries
- **Create summary/rollup tables**: Pre-compute common aggregations for dashboard-level metrics
- **Use materialized views**: For complex joins or transformations that are queried frequently
- **Implement clustering/sorting**: Organize data by commonly filtered columns (e.g., date, tenant_id) to minimize scan volume

## Caching Strategy

### Cache Configuration

```python
# Redis-based caching (recommended for production)
CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,      # 5 minutes
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_REDIS_URL": "redis://redis:6379/0",
}

DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 3600,     # 1 hour for data cache
    "CACHE_KEY_PREFIX": "superset_data_",
    "CACHE_REDIS_URL": "redis://redis:6379/1",
}

FILTER_STATE_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 600,
    "CACHE_KEY_PREFIX": "superset_filter_",
    "CACHE_REDIS_URL": "redis://redis:6379/2",
}
```

### Cache Timeout Strategy

| Data Type | Recommended Timeout | Rationale |
|-----------|-------------------|-----------|
| **Real-time dashboards** | 30-60 seconds | Frequent refresh needed |
| **Operational dashboards** | 5-15 minutes | Balance freshness and performance |
| **Analytical dashboards** | 1-4 hours | Data refreshed on ETL schedule |
| **Static reports** | 12-24 hours | Data changes infrequently |
| **Metadata cache** | 5-10 minutes | Schema/table list changes rarely |

### Cache Warm-Up

Schedule cache warm-up jobs to pre-populate dashboard caches before peak usage:

```python
# In Celery Beat schedule
beat_schedule = {
    "cache-warmup": {
        "task": "cache-warmup",
        "schedule": crontab(minute=0, hour=6),  # 6 AM daily
        "kwargs": {
            "strategy_name": "top_n_dashboards",
            "top_n": 10,
        },
    },
}
```

### Cache Best Practices

- **Use separate Redis databases** for different cache types (data, metadata, filter state, Celery broker) to allow independent configuration and eviction policies
- **Monitor cache hit rates**: Low hit rates indicate timeouts are too short or query patterns are too diverse
- **Set Redis maxmemory policy**: Use `allkeys-lru` to evict least recently used keys when memory is full
- **Do not use in-memory cache with GAQ**: Global Async Queries requires Redis for cache consistency between web processes and Celery workers
- **Configure RESULTS_BACKEND separately**: SQL Lab async results need a persistent backend (Redis, S3, or filesystem), not just an in-memory cache

## Deployment at Scale with Kubernetes

### Helm Chart Configuration

The official Superset Helm chart is the recommended deployment method for production Kubernetes environments.

```yaml
# values.yaml key configurations
supersetNode:
  replicaCount: 3              # Multiple web server replicas
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "4Gi"

supersetWorker:
  replicaCount: 4              # Celery workers
  resources:
    requests:
      cpu: "500m"
      memory: "2Gi"
    limits:
      cpu: "2"
      memory: "8Gi"

supersetCeleryBeat:
  enabled: true

supersetWebsockets:
  enabled: true                # For Global Async Queries
```

### Scaling Guidelines

| Component | Scaling Trigger | Recommendation |
|-----------|----------------|----------------|
| **Web Servers** | Concurrent users, API requests | 3+ replicas behind load balancer; scale on CPU/memory |
| **Celery Workers** | Async queries, reports, alerts | Scale based on queue depth; dedicated workers per task type |
| **Redis** | Cache size, connection count | Redis Cluster or managed Redis for HA |
| **Metadata DB** | Query volume, connection count | Managed PostgreSQL with read replicas |
| **WebSocket Server** | Concurrent async queries | Scale with web servers |

### Production Deployment Checklist

- **Use a production WSGI server**: Gunicorn with multiple workers (`-w 4 --threads 4`)
- **Configure `SECRET_KEY`**: Set a strong, unique secret key for session security
- **Set `SUPERSET_WEBSERVER_TIMEOUT`**: Configure to match your longest expected query time
- **Enable HTTPS**: Terminate TLS at the load balancer or ingress controller
- **Use external Redis and PostgreSQL**: Do not use in-cluster single-instance databases for production
- **Configure health checks**: Liveness and readiness probes for all components
- **Set resource limits**: Define CPU and memory requests/limits for all pods
- **Implement ingress**: Use Nginx Ingress or cloud-native load balancers with session affinity
- **Enable HPA**: Horizontal Pod Autoscaler for web servers and workers based on CPU/memory metrics

### Celery Worker Configuration

```python
# For Kubernetes deployments, use --pool solo or --pool gevent
# Default prefork pool causes OOM issues with K8s memory limits
CELERY_WORKER_POOL = "solo"  # or "gevent" (requires gevent installed)
CELERY_WORKER_CONCURRENCY = 4
```

### High Availability

- **3+ web server replicas** behind a load balancer for fault tolerance
- **3+ Celery worker replicas** with task routing for priority management
- **Redis Sentinel or Redis Cluster** for cache and broker HA
- **PostgreSQL with streaming replication** or managed database with automatic failover
- **Multi-AZ deployment** for cloud environments

## Security Configuration

### Production Security Essentials

```python
# superset_config.py security settings

# Strong secret key (generate with: openssl rand -base64 42)
SECRET_KEY = "your-strong-secret-key-here"

# Force HTTPS
ENABLE_PROXY_FIX = True
TALISMAN_ENABLED = True
TALISMAN_CONFIG = {
    "force_https": True,
    "content_security_policy": None,  # Configure CSP per your needs
}

# Session security
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_SAMESITE = "Lax"

# CSRF protection
WTF_CSRF_ENABLED = True

# Disable public role by default
PUBLIC_ROLE_LIKE = None
```

### Authentication Best Practices

- **Use OAuth/LDAP for production**: Integrate with your organization's identity provider (Okta, Azure AD, Keycloak, Google)
- **Enable `AUTH_ROLES_SYNC_AT_LOGIN`**: Automatically sync roles from LDAP/OAuth groups on every login
- **Map external groups to Superset roles**: Use `AUTH_ROLES_MAPPING` for consistent access control
- **Implement MFA**: Rely on your IdP's MFA capabilities through OAuth/OIDC

### Row-Level Security

- **Define RLS rules for multi-tenant deployments**: Filter data based on user attributes
- **Test RLS rules thoroughly**: Verify that users cannot bypass filters through SQL Lab or API
- **Use Jinja macros in RLS**: `{{ current_username() }}` and `{{ current_user_id() }}` for user-scoped data access
- **Combine with dataset-level permissions**: Use Gamma role + dataset grants + RLS for defense in depth

### Database Connection Security

- **Use environment variables for credentials**: Never hardcode database passwords in `superset_config.py`
- **Enable SSH tunneling** for databases not directly accessible
- **Restrict SQL Lab access**: Only grant `sql_lab` role to users who need raw SQL access
- **Set `PREVENT_UNSAFE_DB_CONNECTIONS`**: Block SQLite and other file-based connections in production
- **Configure per-database permissions**: Use schema-level and table-level access grants

## Monitoring and Observability

### Key Metrics to Monitor

- **Dashboard load times**: Track P50/P95/P99 dashboard render times
- **Query execution times**: Monitor slow queries and timeout rates
- **Cache hit rates**: Measure effectiveness of caching strategy
- **Celery queue depth**: Monitor pending task counts for capacity planning
- **Worker memory usage**: Track for memory leak detection
- **Error rates**: API 5xx errors, query failures, worker crashes
- **Active users and concurrency**: Track concurrent user counts for scaling decisions

### Logging Configuration

```python
# Enable structured logging
ENABLE_TIME_ROTATE = True
TIME_ROTATE_LOG_LEVEL = "INFO"

# StatsD integration for metrics
STATS_LOGGER = StatsdStatsLogger(
    host="statsd",
    port=8125,
    prefix="superset"
)
```

## Sources

- [Best Practices to Optimize Apache Superset Dashboards](https://celerdata.com/glossary/best-practices-to-optimize-apache-superset-dashboards)
- [6 Tips to Optimize Apache Superset for Performance](https://mobisoftinfotech.com/resources/blog/apache-superset-optimization-tips)
- [The Data Engineer's Guide to Lightning-Fast Dashboards](https://preset.io/blog/the-data-engineers-guide-to-lightning-fast-apache-superset-dashboards/)
- [Running Apache Superset at Scale](https://medium.com/data-science/running-apache-superset-at-scale-1539e3945093)
- [Kubernetes Deployment Documentation](https://superset.apache.org/admin-docs/installation/kubernetes/)
- [Securing Your Superset Installation](https://superset.apache.org/admin-docs/security/securing_superset/)
- [Caching Configuration](https://superset.apache.org/admin-docs/configuration/cache/)
- [How to Scale Superset on Kubernetes](https://www.restack.io/docs/superset-on-kubernetes)
