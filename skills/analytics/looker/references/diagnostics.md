# Looker Diagnostics Reference

## Slow Explores

### Symptoms

- Explores take excessively long to return results
- Dashboards time out or show loading spinners for extended periods
- Users report intermittent slowness during peak hours

### Step-by-Step Diagnostic Workflow

**1. Identify the Bottleneck Stage**

Looker query execution has distinct stages. Identify which stage is slow:

| Stage | What Happens | Slow Stage Indicates |
|---|---|---|
| **Query Initialization** | Looker builds SQL from LookML and connects to database | Model complexity or database connectivity issues |
| **Query Execution** | Database processes the generated SQL | Database-level issues (missing indexes, full scans, insufficient compute) |
| **Streaming Results** | Results transfer from database to Looker | Large result sets or network latency |
| **Rendering** | Browser renders visualizations | Excessive columns (50+) or rows straining browser |

**2. Check Database Load**

Navigate to **Admin > Queries** to see active and queued queries:
- Look for queries consuming excessive database resources
- Identify if multiple heavy queries are running concurrently
- Check database-side monitoring for CPU, memory, I/O bottlenecks

**3. Check Instance Load**

- Monitor the Looker server for CPU, memory, and thread pool utilization
- Heavy instance loads slow non-query tasks (folder navigation, UI responsiveness)
- All concurrent users share the Looker application server resources

**4. Evaluate the Generated SQL**

- Open the Explore and click the **SQL** tab to view the generated query
- Run the SQL directly in SQL Runner or the database console to isolate Looker overhead vs database time
- Look for: unnecessary joins, full table scans, missing WHERE clauses, suboptimal join order

### Common Causes and Fixes

| Cause | Fix |
|---|---|
| Too many joins in one Explore | Break into focused Explores or use PDTs to pre-join |
| Missing `always_filter` on time fields | Add required date filters to prevent unbounded scans |
| Subqueries in dimension SQL | Convert to PDTs or derived tables |
| Fan-out from incorrect join relationships | Fix `relationship` parameter; ensure correct cardinality |
| Large result sets rendered in browser | Limit rows; use `row_limit`; reduce columns below 50 |
| No aggregate awareness | Add aggregate tables for common query patterns |
| Expensive database functions in dimensions | Move calculations to PDTs or ETL |
| No `sql_always_where` on large tables | Add permanent filters to reduce data scanned |

### Performance Monitoring Tools

| Tool | Purpose | Access |
|---|---|---|
| **System Activity > Explore Recommendations** | Surfaces Explores causing performance strain | Admin |
| **System Activity > Query Performance** | Track query runtimes, row counts, cache hit rates | Admin |
| **Admin > Queries** | Real-time view of running and queued queries | Admin |
| **SQL Runner** | Test raw SQL performance outside the Explore context | Developer |

---

## PDT Build Failures

### Symptoms

- PDTs show as stale or failed in the Admin PDT panel
- Explores return errors referencing missing or outdated tables
- PDT Event Log shows build failure entries

### Diagnostic Process

**1. Test Manual Build**

- Navigate to the Explore using the PDT
- Click **Rebuild Derived Tables & Run**
- If manual build succeeds but automatic builds fail, the issue is with the PDT regenerator process

**2. Check Connection Settings**

Common connection-related failures:

| Issue | Resolution |
|---|---|
| Scratch schema not configured | Enable PDTs on the connection; set scratch schema |
| Insufficient permissions | Grant CREATE TABLE, DROP TABLE, INSERT on scratch schema |
| Schema does not exist | Create the scratch schema on the database |
| Connection pool exhausted | Reduce concurrent PDT builds; increase pool size |

**3. Review PDT Event Log**

Access the **PDT Event Log** Explore to investigate:
- Build reason (scheduled trigger, dependency rebuild, manual trigger)
- Build duration and failure timestamps
- Specific error messages from the database
- Whether builds are stuck or timing out

**4. Check for Common Errors**

| Error | Cause | Resolution |
|---|---|---|
| Cannot construct persistent derived table | Connection not registered for PDTs | Enable PDTs on the connection; verify scratch schema setting |
| Schema change in incremental PDT | Underlying table structure changed | Rebuild the incremental PDT fully (not incrementally) |
| Timeout during PDT build | Query takes longer than configured timeout | Optimize derived table SQL; increase timeout |
| Permission denied on scratch schema | Database user lacks required privileges | Grant CREATE, DROP, INSERT on scratch schema |
| Duplicate table name | Conflicting PDT names across connections | Use unique derived table names |

### PDT Build Frequency Issues

If PDTs rebuild too frequently:
- **Check for scratch schema clutter**: Multiple PDT copies indicate cleanup is failing
- **Review datagroup triggers**: Ensure `sql_trigger` queries return stable values between ETL runs
- **Check dependent PDT chains**: A change in any upstream PDT triggers rebuilds of all downstream PDTs
- **Verify trigger query results**: Run the `sql_trigger` query manually to confirm it returns expected, stable values

### Multi-Instance Considerations

- Production and QA instances should use **different scratch schemas** to avoid conflicts
- Shared scratch schemas can cause one instance to delete another instance's PDTs

---

## Connection Issues

### Symptoms

- "Looker is having trouble connecting to your database"
- Queries fail with JDBC connection errors
- Intermittent connection drops during query execution

### Diagnostic Process

**1. Test Connection**

Navigate to **Admin > Connections** > click **Test** on the affected connection:
- Review test results for specific failure messages
- Note which test steps pass and which fail

**2. Common Connection Errors**

| Error | Cause | Resolution |
|---|---|---|
| Connection refused | Database not reachable from Looker | Check firewall rules, VPC peering, IP allowlisting |
| Authentication failed | Invalid credentials | Update username/password; check credential rotation |
| SSL/TLS handshake failure | Certificate mismatch or expiration | Update SSL certificates; verify TLS version compatibility |
| Connection pool exhaustion | Too many concurrent queries | Increase pool size; optimize query concurrency |
| Max connection limit reached | Database-side connection limit hit | Increase database max connections; reduce Looker pool |
| Query timeout | Query exceeded configured timeout | Optimize SQL; increase timeout; check database performance |
| Per-user query limit exceeded | User ran too many concurrent queries | Wait for queries to complete; adjust per-user limits |

**3. Network Troubleshooting**

For **Looker (Google Cloud Core)**:
- Verify VPC peering or Private Service Connect configuration
- Check IAM permissions for service account
- Verify IP allowlisting on the database side
- Check Private IP vs Public IP connectivity settings

For **Customer-Hosted**:
- Verify network routes between Looker server and database
- Check DNS resolution from the Looker host
- Test connectivity with database client tools
- Review firewall and security group rules

**4. OAuth Connection Issues (BigQuery)**

- Verify OAuth client configuration in Google Cloud console
- Check user has appropriate BigQuery permissions
- Ensure OAuth tokens are not expired
- Confirm Google Cloud project has BigQuery API enabled

---

## LookML Validation Errors

### Common Errors and Resolution

**Variable Not Found:**
```
Unknown variable: "view_name.field_name"
```

| Possible Cause | Resolution |
|---|---|
| Misspelled field or view name | Check spelling carefully |
| Field does not exist in the view | Verify field definition exists |
| View not included in the model | Add view file to model's `include` |
| Liquid `{{ }}` nested inside `{% %}` | Restructure Liquid syntax |

**Inaccessible View:**
```
View "view_name" is not accessible
```

| Possible Cause | Resolution |
|---|---|
| View not joined to the Explore | Add view as a join |
| View aliased with `from` but referenced by original name | Reference the alias name |
| View file not included in the model | Add to `include` |

**Unknown or Inaccessible Field:**
```
Unknown or inaccessible field "view_name.field_name"
```

| Possible Cause | Resolution |
|---|---|
| Field name typo | Check spelling |
| Field excluded via `fields` parameter | Remove exclusion or use a different field |
| Missing timeframe on dimension_group | Add `.date`, `.month`, etc. suffix |

**Measures Referencing Other Measures:**
```
Measures with Looker aggregations may not reference other measures
```

- A SUM/AVG/COUNT/MIN/MAX/LIST measure references another measure in its `sql`
- **Fix**: Use `type: number` for measures that combine other measures

**Duplicate Names:**
```
Duplicate view/Explore name: "name"
```

- Two views or Explores with the same name in the same model
- **Fix**: Rename one; check include patterns for conflicts

**Missing Primary Key:**
```
Warning: No primary key defined for view "view_name"
```

- **Fix**: Add `primary_key: yes` on a unique dimension, including derived tables

**Circular References:**
```
Circular file reference detected
```

- File A includes File B, and File B includes File A
- **Fix**: Restructure includes to eliminate circular dependencies

### Validation Best Practices

- Run **LookML validation** before every commit
- Run **data tests** before deploying to production
- Use **Content Validator** (Admin panel) regularly to detect broken dashboards and Looks
- Enable **required pull requests** so validation runs as part of the review process

---

## Query Performance

### Performance Measurement Framework

Use **System Activity > History** Explore to analyze query performance:

| Metric | What to Look For |
|---|---|
| **Average runtime** | By Explore, dashboard, user, or time period |
| **Cache hit rate** | High = effective caching; low = misconfiguration |
| **Row count distribution** | Identify queries returning excessive rows |
| **Source breakdown** | Dashboard vs Explore vs API vs scheduled queries |

### Database-Level Optimization

| Technique | When to Use |
|---|---|
| **Indexing** | Commonly filtered and joined columns |
| **Partitioning** | Large time-series tables (BigQuery partition filters, Snowflake clustering) |
| **Clustering** | Commonly filtered columns (BigQuery, Snowflake) |
| **Materialized views** | Complex aggregations that change infrequently |
| **Statistics/vacuum** | Keep database statistics current for query planner accuracy |

### LookML-Level Optimization

| Optimization | Implementation |
|---|---|
| Replace subqueries with PDTs | Move expensive subqueries in dimension SQL to derived tables |
| Use aggregate tables | Pre-compute common dashboard query patterns |
| Optimize joins | Reduce join count; use direct joins from base view |
| Add `always_filter` | Require date range filters on time-series Explores |
| Limit exposed fields | Use `fields` parameter to restrict unnecessary columns |
| Use `sql_always_where` | Apply permanent filters to reduce data scanned |

### Caching Optimization

- **Align datagroups with ETL**: Cache should invalidate when, and only when, new data arrives
- **Set appropriate `max_cache_age`**: Match data freshness requirements
- **Monitor cache hit rates**: Low hit rates on popular dashboards indicate tuning opportunities
- **Avoid per-user caching when unnecessary**: OAuth connections create per-user caches, reducing reuse

### Dashboard Performance

- **Limit tiles per dashboard**: Each tile generates a separate query
- **Merge compatible tiles**: Use merged queries to reduce total query count
- **Auto-refresh wisely**: Set intervals to match data freshness, not shorter
- **Use dashboard filters**: Consolidate filtering to reduce redundant queries across tiles
- **Enable cross-filtering judiciously**: Adds query overhead per interaction
- **Limit result rows**: Set row limits on table visualizations

### Browser-Level Optimization

- Keep table visualizations under **50 columns** for browser performance
- Browser memory = (data per cell) x (rows) x (columns)
- Use conditional formatting sparingly on large tables
- Prefer server-side rendering for PDF/PNG scheduled deliveries

### Monitoring and Alerting

| Tool | Purpose |
|---|---|
| **System Activity dashboards** | Query performance, instance health, user activity |
| **Explore Recommendations** | Identifies problematic Explores based on benchmarks |
| **PDT Activity** | Track PDT build times and failures |
| **Admin > Queries** | Real-time running and queued queries |
| **Google Cloud Monitoring** (Looker Core) | Instance-level metrics and alerting |
| **Custom alerts** | Scheduled Looks on System Activity with runtime thresholds |
