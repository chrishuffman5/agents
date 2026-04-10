# Metabase Diagnostics Reference

## Diagnostic Tools

### Built-in Diagnostic Info

- **Keyboard shortcut**: `Ctrl+F1` (Windows/Linux) or `Cmd+F1` (Mac)
- **Command palette**: `Cmd/Ctrl+K` > search "Diagnostic" > "Open diagnostic error modal"
- Downloads a JSON file containing selectable diagnostic data:
  - Item definitions (dashboard information)
  - Browser error messages
  - All server error messages and logs
  - Server logs filtered to current user only
  - Metabase instance version information
- Content varies based on the page where the diagnostic request is initiated
- **Privacy note**: Review the downloaded file before sharing; may contain sensitive data

### Server Logs

- **Access**: Admin > Tools > Logs (requires admin account)
- **Key metrics**:
  - Response time: Time from request receipt to result return
  - Queries in flight: Number of active and queued queries across all connected databases
- **Log levels**: Adjustable for more verbose debugging
- Logs show SQL queries being executed, timing, errors, and stack traces

### Browser Console Logs

- Available through browser developer tools (F12)
- Accessible to all users (no admin required)
- Shows client-side JavaScript errors, network failures, and rendering issues
- Useful for diagnosing embedding and SDK issues

### HAR Files

- Network request recordings from browser developer tools
- Capture full request/response cycle including headers and timing
- Useful for diagnosing performance issues, API errors, and network problems
- Available in Chrome, Edge, Firefox, and Safari

### JMX Monitoring

Enable JMX for JVM-level diagnostics:
- Use VisualVM or similar tools to inspect:
  - Memory usage and garbage collection
  - Thread dumps (useful when Metabase appears stalled or slow)
  - CPU profiling
  - Heap analysis
- Particularly useful for identifying memory leaks and thread contention

### Usage Analytics (Pro/Enterprise)

- Built-in analytics about Metabase usage patterns
- Identifies most-used and least-used questions/dashboards
- Helps find expensive queries straining the database
- Supports housekeeping decisions (archive unused content)

---

## Slow Queries

### Symptoms

- Questions take a long time to load
- Dashboard cards spin for extended periods
- Timeout errors on complex queries

### Diagnostic Process

1. Check server logs (Admin > Tools > Logs) for query execution times
2. Compare Metabase query time vs direct database query time (run the SQL directly)
3. Review "Queries in flight" metric for concurrency issues
4. Use database-specific tools (e.g., `pg_stat_statements` for PostgreSQL, slow query log for MySQL)

### Common Causes and Solutions

| Cause | Solution |
|---|---|
| Missing database indexes | Add indexes on columns in WHERE, JOIN, ORDER BY |
| Unbounded queries (no filters) | Add default filters and time range limits |
| No caching configured | Enable caching (adaptive as default; duration/schedule for known patterns) |
| Complex aggregations at query time | Use models, materialized views, or summary tables |
| Production database under load | Point Metabase at a read replica |
| JSON blob queries | Extract JSON keys into dedicated columns |
| Incorrect column types | Fix types at schema level to avoid runtime conversion |
| Too many dashboard cards | Limit to 20-25 per tab; split across tabs |

---

## Slow Dashboards

### Symptoms

- Dashboard takes >10 seconds to load
- Multiple cards loading sequentially
- Browser becomes unresponsive

### Diagnostic Process

1. Count the number of cards on the dashboard
2. Check individual question execution times (inspect each card)
3. Review if cards share similar queries that could be combined
4. Check for unfiltered queries returning large datasets
5. Check if cross-filtering is adding unnecessary query overhead

### Solutions

| Approach | Impact |
|---|---|
| Split into multiple tabs | Reduces simultaneous queries (each tab loads independently) |
| Set default filter values | Limits initial data load (especially time ranges) |
| Enable dashboard-level caching | Users always see cached results (Pro/Enterprise) |
| Reduce card count | Target 20-25 max per tab |
| Use models as data sources | Consistent caching and potential query optimization |
| Pre-warm caches via API | Run queries during off-hours before peak usage |
| Create summary tables | Denormalized tables for heavy aggregations |

---

## Connection Problems

### Symptoms

- "Could not connect to database" errors
- Intermittent connection failures
- Timeout during database sync

### Common Causes and Solutions

| Cause | Diagnostic Clue | Solution |
|---|---|---|
| Firewall/network | Connection timeout | Verify Metabase server can reach database host:port |
| SSH tunnel | "Connection refused" after timeout | Check SSH key permissions, bastion host availability, tunnel timeout |
| SSL/TLS | Certificate errors in logs | Verify certificate validity; try with SSL disabled to isolate |
| Credentials | "Authentication failed" | Verify username/password; check for password rotation |
| Connection pool exhaustion | Intermittent failures under load | Increase max connections in database settings |
| Database under load | Slow connections, timeouts | Check database CPU/memory; consider read replica |
| AWS IAM | Token refresh failures | Verify IAM role permissions and token refresh (v58+) |

### Network Diagnostic Commands

```bash
# Test TCP connectivity
nc -zv database-host 5432

# Test through SSH tunnel
ssh -N -L 5432:database-host:5432 bastion-host

# Test SSL certificate
openssl s_client -connect database-host:5432
```

---

## Permission Errors

### Symptoms

- Users see "Permission denied" or empty results
- Data sandboxing not filtering correctly
- Users can access data they should not see

### Diagnostic Process

1. Check user's group memberships (Admin > People > select user)
2. Review data permissions for each group at database/schema/table level
3. Verify collection permissions
4. Check if "All Users" group has overly permissive settings
5. Test from the user's perspective (use a test account in the same groups)

### Common Causes

| Cause | Symptom | Fix |
|---|---|---|
| "All Users" unrestricted | Granular permissions have no effect | Restrict "All Users" first |
| Permissions are additive | User sees more data than expected | Most permissive group wins; review all group memberships |
| Native SQL on sandboxed DB | Sandboxing bypassed | Disable native query access for sandboxed databases |
| Collection vs data confusion | User sees dashboard, gets empty results | Configure both collection AND data permissions |
| Download perms misaligned | Users download full data, bypassing RLS | Align download permissions with data access restrictions |
| Stale group membership | User in wrong group after role change | Audit group memberships regularly |

---

## Embedding Issues

### Symptoms

- Embedded content not loading
- CORS errors in browser console
- Authentication failures in embedded context
- "Powered by Metabase" badge appearing unexpectedly
- SDK components render blank or error

### Solutions

| Issue | Diagnostic Clue | Solution |
|---|---|---|
| CORS errors | "Access-Control-Allow-Origin" errors in console | Add embedding origin URLs in Admin > Embedding settings |
| JWT signing failure | "Invalid token" errors | Verify secret key matches between app and Metabase |
| Session expiry | Content loads then disappears | Check `MAX_SESSION_AGE`; implement token refresh |
| SameSite cookies | Cookies not sent in iframe | Adjust cookie settings for cross-domain embedding |
| SDK version mismatch | Components fail to load or behave unexpectedly | Ensure SDK npm package version matches Metabase version exactly |
| Origin whitelist | "Origin not allowed" errors | Verify authorized origins include the embedding domain |
| Badge appearing | "Powered by Metabase" visible | Requires Pro/Enterprise with white-labeling enabled |
| SSR issues | Hydration errors in Next.js | SDK auto-skips SSR (v57+); ensure dynamic import if needed |

### Embedding Debug Checklist

1. Verify Metabase version matches SDK version
2. Check CORS configuration in Admin > Embedding
3. Verify JWT secret key or session token validity
4. Check browser console for JavaScript errors
5. Check network tab for failed API requests
6. Verify the embedding URL includes all required parameters
7. Test with a simple embed first before adding complexity

---

## Sync and Scan Issues

### Symptoms

- New tables/columns not appearing in Metabase
- Field values not showing in filter dropdowns
- JSON unfolding causing slow syncs

### Solutions

| Issue | Solution |
|---|---|
| New tables not appearing | Manually trigger sync: Admin > Databases > Sync database schema now |
| Slow syncs | Disable JSON unfolding if not needed; adjust sync schedule for large databases |
| Missing filter values | Check scan settings; ensure field scanning is enabled for relevant columns |
| Permission errors during sync | Verify Metabase database user has schema read permissions |
| Excessive scan frequency | Reduce scan frequency for large tables; disable scanning for tables that don't need filter suggestions |

---

## Application Database Issues

### Symptoms

- H2 database corruption (production use)
- Slow Metabase startup or operations
- Migration failures during upgrades

### Solutions

| Issue | Cause | Solution |
|---|---|---|
| H2 corruption | Using H2 in production | Migrate to PostgreSQL immediately; restore from backup |
| Slow operations | H2 limitations | Migrate from H2 to PostgreSQL; optimize PostgreSQL settings |
| Migration failures | Interrupted migration or version jump too large | Restore from pre-upgrade backup; follow sequential upgrade path |
| Disk space | Growing application database | Monitor size; clean up old audit/log entries |

---

## Upgrade Troubleshooting

### Pre-Upgrade Checklist

1. **Back up the application database** (critical -- always do this)
2. Review release notes for breaking changes
3. Reduce cluster to single node (migrations must run on one node)
4. Plan for potential downtime during migrations
5. Test upgrade in staging environment first
6. Verify SDK/embedding compatibility if using embedded analytics

### Upgrade Process

| Deployment | Process |
|---|---|
| **Cloud** | Automatic; no action needed |
| **Docker** | Stop container, pull new image, restart |
| **JAR** | Stop service, replace JAR, restart |

Metabase runs database migrations automatically on startup. **Never interrupt migrations.**

### Version Upgrade Paths

- **From before v40**: Must upgrade sequentially through each major version
- **Between major versions**: Use latest minor version as stepping stone (e.g., v54.5 before v55.x)
- **Never interrupt migrations**: Can corrupt application database

### Common Upgrade Issues

| Issue | Cause | Solution |
|---|---|---|
| Migration failure | Interrupted previous migration, version jump too large | Restore from backup; follow sequential path |
| SDK breaking changes | API or component changes between versions | Test SDK integration locally before upgrading production |
| Embedding breaks | URL or API changes | Review embedding docs for the new version |
| Permissions change | Permission model updates | Test permissions from end-user perspective post-upgrade |

### Rollback Options

1. **Restore application database from pre-upgrade backup** (recommended)
2. Use `migrate down` command to roll back schema changes
3. **Never run older Metabase version against a migrated database** without rollback

### Post-Upgrade Verification

1. Verify all dashboards and questions load correctly
2. Test permissions and sandboxing
3. Check embedding functionality (if used)
4. Verify database connections and sync
5. Monitor server logs for errors
6. Test caching behavior
7. Verify SDK components (if using Modular Embedding)

---

## Performance Diagnostics

### Identifying Bottlenecks

**Metabase Application Level:**
- Server logs: query execution times, response times
- Queries in flight: concurrency pressure
- JMX/VisualVM: memory, threads, CPU
- Usage analytics: expensive queries and popular dashboards (Pro/Enterprise)

**Database Level:**
- Database-specific monitoring (pg_stat_statements, slow query log)
- Compare direct query times vs Metabase query times
- Monitor index usage and missing index suggestions
- Check connection pool utilization

**Network Level:**
- HAR files: request/response timing
- Browser developer tools: network waterfall
- SSH tunnel latency (if applicable)

### Key Metrics to Monitor

| Metric | Source | Warning Threshold |
|---|---|---|
| Average query execution time | Server logs | > 5 seconds |
| Dashboard load time | Browser network tab | > 10 seconds |
| Cache hit rate | Caching admin | < 50% on popular dashboards |
| Queries in flight | Server logs | Sustained high count |
| JVM heap usage | JMX | > 80% of configured max |
| Database connection pool | Database monitoring | Near max connections |
| Sync/scan duration | Server logs | Growing over time |
| API response times | Server logs / HAR | > 2 seconds |
