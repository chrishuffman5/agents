# Looker Diagnostics

## Slow Explores

### Symptoms

- Explores take excessively long to return results
- Dashboards time out or show loading spinners for extended periods
- Users report intermittent slowness during peak hours

### Diagnostic Process

#### 1. Identify the Bottleneck Stage

Looker query execution has distinct stages. Identify which stage is slow:

- **Query Initialization**: Time Looker spends building the query from LookML and connecting to the database. Long initialization suggests model complexity or database connectivity issues.
- **Query Execution**: Time the database spends processing the SQL. Long execution points to database-level issues (missing indexes, full table scans, insufficient compute).
- **Streaming Results**: Time to transfer results from database to Looker. Large result sets or network latency cause delays here.
- **Rendering**: Time for the browser to render visualizations. Excessive columns (50+) or rows strain browser capacity.

#### 2. Check Database Load

- Navigate to **Admin > Queries** to see active and queued queries
- Look for queries consuming excessive database resources
- Identify if multiple heavy queries are running concurrently
- Check database-side monitoring for resource bottleneck (CPU, memory, I/O)

#### 3. Check Instance Load

- Monitor the Looker server for CPU, memory, and thread pool utilization
- Heavy instance loads slow non-query tasks (folder navigation, UI responsiveness)
- All concurrent users share the Looker application server resources

#### 4. Evaluate the Generated SQL

- Open the Explore and click **SQL** tab to view the generated query
- Run the SQL directly in the database console to isolate Looker overhead vs. database time
- Look for: unnecessary joins, full table scans, missing WHERE clauses, suboptimal join order

### Common Causes and Fixes

| Cause | Fix |
|-------|-----|
| Too many joins in one Explore | Break into focused Explores or use PDTs to pre-join |
| Missing `always_filter` on time fields | Add required date filters to prevent unbounded scans |
| Subqueries in dimension SQL | Convert to PDTs or derived tables |
| Fan-out from incorrect join relationships | Fix `relationship` parameter; ensure correct cardinality |
| Large result sets rendered in browser | Limit rows; use `row_limit`; reduce columns below 50 |
| No aggregate awareness | Add aggregate tables for common query patterns |
| Expensive database functions in dimensions | Move calculations to PDTs or ETL |

### Performance Monitoring Tools

- **System Activity > Explore Recommendations**: Surfaces Explores causing performance strain, comparing metrics against healthy benchmarks
- **System Activity > Query Performance**: Track query runtimes, row counts, and cache hit rates
- **Admin > Queries**: Real-time view of running and queued queries
- **SQL Runner**: Test raw SQL performance outside the Explore context

---

## PDT Build Failures

### Symptoms

- PDTs show as stale or failed in the Admin PDT panel
- Explores return errors referencing missing or outdated tables
- PDT Event Log shows build failure entries

### Diagnostic Process

#### 1. Test Manual Build

- Navigate to the Explore using the PDT
- Click **Rebuild Derived Tables & Run**
- If manual build succeeds but automatic builds fail, the issue is with the PDT regenerator process

#### 2. Check Connection Settings

Common connection-related failures:

- **Scratch schema not configured**: PDTs require a designated scratch schema on the database connection
- **Insufficient permissions**: The database user needs CREATE TABLE, DROP TABLE, and INSERT permissions on the scratch schema
- **Schema does not exist**: Verify the scratch schema exists on the database
- **Connection pool exhausted**: Too many concurrent PDT builds consuming all available connections

#### 3. Review PDT Event Log

Access the **PDT Event Log** Explore to investigate:

- Build reason (scheduled trigger, dependency rebuild, manual trigger)
- Build duration and failure timestamps
- Specific error messages from the database
- Whether builds are stuck or timing out

#### 4. Check for Common Errors

| Error | Cause | Resolution |
|-------|-------|------------|
| Cannot construct persistent derived table | Connection not registered for PDTs or PDT setting disabled | Enable PDTs on the connection; verify scratch schema |
| Schema change in incremental PDT | Underlying table structure changed | Rebuild the incremental PDT fully (not incrementally) |
| Timeout during PDT build | Query takes longer than the configured timeout | Optimize the derived table SQL; increase timeout if needed |
| Permission denied on scratch schema | Database user lacks required privileges | Grant CREATE, DROP, INSERT on scratch schema |
| Duplicate table name | Conflicting PDT names across connections | Use unique derived table names; check for naming collisions |

### PDT Build Frequency Issues

If PDTs are rebuilding too frequently:

- **Check for scratch schema clutter**: Multiple PDT copies indicate the cleanup process for old PDTs is failing
- **Review datagroup triggers**: Ensure `sql_trigger` queries return stable values between ETL runs
- **Check dependent PDT chains**: A change in any upstream PDT triggers rebuilds of all downstream PDTs
- **Verify trigger query results**: Run the `sql_trigger` query manually to confirm it returns expected, stable values

### Multi-Instance Considerations

- Production and QA Looker instances should use **different scratch schemas** to avoid PDT management conflicts
- Shared scratch schemas can cause one instance to delete another instance's PDTs

---

## Connection Issues

### Symptoms

- Error: "Looker is having trouble connecting to your database"
- Queries fail with JDBC connection errors
- Intermittent connection drops during query execution

### Diagnostic Process

#### 1. Test Connection

- Navigate to **Admin > Connections**
- Click **Test** on the affected connection
- Review test results for specific failure messages

#### 2. Common Connection Errors

| Error | Cause | Resolution |
|-------|-------|------------|
| Connection refused | Database not reachable from Looker | Check firewall rules, VPC peering, IP allowlisting |
| Authentication failed | Invalid credentials | Update username/password; check credential rotation |
| SSL/TLS handshake failure | Certificate mismatch or expiration | Update SSL certificates; verify TLS version compatibility |
| Connection pool exhaustion | Too many concurrent queries consuming all connections | Increase connection pool size; optimize query concurrency |
| Max connection limit reached | Database-side connection limit hit | Increase database max connections; reduce Looker pool size |
| Query timeout | Query exceeded configured timeout | Optimize SQL; increase timeout; check database performance |
| Per-user query limit exceeded | User ran too many concurrent queries | Wait for queries to complete; adjust per-user limits |

#### 3. Network Troubleshooting

For **Looker (Google Cloud Core)**:

- Verify VPC peering or Private Service Connect configuration
- Check IAM permissions for service account
- Verify IP allowlisting on the database side
- Check Private IP vs. Public IP connectivity settings

For **Customer-Hosted**:

- Verify network routes between Looker server and database
- Check DNS resolution
- Test connectivity with database client tools from the Looker host
- Review firewall and security group rules

#### 4. OAuth Connection Issues (BigQuery)

- Verify OAuth client configuration in Google Cloud console
- Check user has appropriate BigQuery permissions
- Ensure OAuth tokens are not expired
- Confirm the Google Cloud project has BigQuery API enabled

---

## LookML Validation Errors

### Common Validation Errors

#### Variable Not Found

```
Unknown variable: "view_name.field_name"
```

**Causes:**
- Misspelled field name or view name
- Field does not exist in the referenced view
- View is not included in the model
- Liquid variable `{{ }}` nested inside Liquid logic `{% %}`

**Resolution:** Check spelling, verify the field exists, ensure the view file is included in the model.

#### Inaccessible View

```
View "view_name" is not accessible
```

**Causes:**
- View not joined to the Explore
- View aliased with `from` parameter but referenced by original name
- View file not included in the model

**Resolution:** Add the view as a join in the Explore, or include the view file in the model's `include` parameter.

#### Unknown or Inaccessible Field

```
Unknown or inaccessible field "view_name.field_name"
```

**Causes:**
- Field name typo
- Field excluded from Explore via `fields` parameter
- Missing timeframe on dimension_group reference (must specify `.date`, `.month`, etc.)

**Resolution:** Check field name, verify it is not excluded, add timeframe suffix for dimension groups.

#### Measure Referencing Other Measures

```
Measures with Looker aggregations may not reference other measures
```

**Causes:**
- A SUM, AVG, COUNT, MIN, MAX, or LIST measure references another measure in its `sql` parameter

**Resolution:** Use type `number` for measures that combine other measures, or dimensionalize the referenced value.

#### Duplicate Names

```
Duplicate view/Explore name: "name"
```

**Causes:**
- Two views or Explores with the same name in the same model
- Conflicting names from included files

**Resolution:** Rename one of the duplicate objects; check include patterns for conflicts.

#### Missing Primary Key

```
Warning: No primary key defined for view "view_name"
```

**Causes:**
- View lacks a dimension with `primary_key: yes`

**Resolution:** Add a primary key dimension. For derived tables, define a primary key on a unique field or combination of fields.

#### Circular References

```
Circular file reference detected
```

**Causes:**
- File A includes File B, and File B includes File A

**Resolution:** Restructure includes to eliminate circular dependencies.

### Validation Best Practices

- Run **LookML validation** before every commit
- Run **data tests** before deploying to production
- Use **Content Validator** (Admin panel) regularly to detect broken dashboards and Looks
- Enable **required pull requests** so that validation runs as part of the review process

---

## Query Performance

### Performance Measurement Framework

Use the **System Activity > History** Explore to analyze query performance:

- **Average runtime** by Explore, dashboard, user, or time period
- **Cache hit rate**: High rates indicate effective caching; low rates suggest caching misconfiguration
- **Row count distribution**: Identify queries returning excessive rows
- **Source breakdown**: Dashboard queries vs. Explore queries vs. API queries vs. scheduled queries

### Database-Level Optimization

- **Indexing**: Ensure commonly filtered and joined columns are indexed in the database
- **Partitioning**: Use table partitioning for large time-series data (especially BigQuery partition filters)
- **Clustering**: Apply clustering on commonly filtered columns (BigQuery, Snowflake)
- **Materialized views**: Use database-native materialized views for complex aggregations
- **Statistics/vacuum**: Keep database statistics current for query planner accuracy

### LookML-Level Optimization

- **Replace subqueries with PDTs**: Move expensive subqueries in dimension SQL to derived tables
- **Use aggregate tables**: Pre-compute common dashboard query patterns
- **Optimize joins**: Reduce join count; use direct joins from base view
- **Add always_filter**: Require date range filters on time-series Explores
- **Limit fields exposed**: Use `fields` parameter to restrict unnecessary columns
- **Use `sql_always_where`**: Apply permanent, invisible filters to reduce data scanned

### Caching Optimization

- **Align datagroups with ETL**: Cache should invalidate when, and only when, new data arrives
- **Set appropriate `max_cache_age`**: Match to data freshness requirements
- **Monitor cache hit rates**: Low hit rates on popular dashboards indicate tuning opportunities
- **Avoid per-user caching when unnecessary**: OAuth connections create per-user caches, reducing cache reuse

### Dashboard Performance

- **Limit tiles per dashboard**: Each tile generates a separate query; more tiles = more database load
- **Merge compatible tiles**: Use merged queries to reduce total query count
- **Auto-refresh wisely**: Set dashboard auto-refresh intervals to match data freshness, not shorter
- **Use dashboard filters**: Consolidate filtering to reduce redundant queries across tiles
- **Enable cross-filtering judiciously**: Cross-filtering adds query overhead per interaction
- **Limit result rows**: Set row limits on table visualizations to prevent browser strain

### Browser-Level Optimization

- Keep table visualizations under **50 columns** for browser performance
- Browser memory = (data per cell) x (number of rows) x (number of columns)
- Use conditional formatting sparingly on very large tables
- Prefer server-side rendering for PDF/PNG scheduled deliveries

### Monitoring and Alerting

- **System Activity dashboards**: Monitor query performance, instance health, user activity
- **Explore Recommendations**: Identifies problematic Explores based on performance benchmarks
- **PDT Activity**: Track PDT build times and failures
- **Admin > Queries**: Real-time view of active and queued queries
- **Google Cloud Monitoring** (Looker Core): Instance-level metrics and alerting
- **Custom alerts**: Set up alerts on query runtime thresholds via scheduled Looks on System Activity

Sources:
- [Troubleshooting PDTs](https://docs.cloud.google.com/looker/docs/best-practices/pdt-troubleshooting)
- [Performance overview](https://docs.cloud.google.com/looker/docs/best-practices/how-to-optimize-looker-performance)
- [Optimize Looker performance](https://docs.cloud.google.com/looker/docs/best-practices/how-to-optimize-looker-server-performance)
- [Understanding PDT log actions](https://docs.cloud.google.com/looker/docs/pdt-log-actions)
- [Looker error catalog](https://docs.cloud.google.com/looker/docs/error-catalog)
- [Admin settings - System Activity dashboards](https://docs.cloud.google.com/looker/docs/system-activity-dashboards)
- [Admin settings - Persistent Derived Tables](https://cloud.google.com/looker/docs/admin-panel-database-pdts)
- [3 Steps for Fixing Slow Looker Dashboards](https://www.integrate.io/blog/3-steps-for-fixing-slow-looker-dashboards-with-amazon-redshift/)
