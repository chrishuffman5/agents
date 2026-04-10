# Metabase Diagnostics and Troubleshooting

## Diagnostic Tools

### Built-in Diagnostic Info
- **Keyboard shortcut**: `Cmd+F1` (Mac) or `Ctrl+F1` (Windows/Linux)
- **Command palette**: `Cmd/Ctrl+K` > search "Diagnostic" > "Open diagnostic error modal"
- Downloads a JSON file containing selectable diagnostic data:
  - Item definitions (dashboard information, etc.)
  - Browser error messages
  - All server error messages
  - All server logs
  - Server logs filtered to current user only
  - Metabase instance version information
- Content varies based on the page where diagnostic request is initiated
- **Privacy note**: Review downloaded file before sharing; may contain sensitive data

### Server Logs
- **Access**: Admin > Tools > Logs (requires admin account)
- **Key metrics**:
  - Response time: Time from request receipt to result return
  - Queries in flight: Number of active and queued queries across all connected databases
- **Log levels**: Can be adjusted for more verbose debugging
- Logs show SQL queries being executed, timing, errors, and stack traces

### Browser Console Logs
- Available through browser developer tools (F12)
- Accessible to all users (no admin required)
- Shows client-side JavaScript errors, network failures, and rendering issues

### HAR Files
- Network request recordings from browser developer tools
- Capture full request/response cycle including headers and timing
- Useful for diagnosing performance issues, API errors, and network problems
- Can be generated in Chrome, Edge, Firefox, and Safari

### JMX Monitoring
- Enable JMX for JVM-level diagnostics
- Use VisualVM or similar tools to inspect:
  - Memory usage and garbage collection
  - Thread dumps (useful when Metabase appears stalled or slow)
  - CPU profiling
  - Heap analysis

### Usage Analytics (Pro/Enterprise)
- Built-in analytics about Metabase usage patterns
- Identifies most-used and least-used questions/dashboards
- Helps find expensive queries that strain the database
- Supports housekeeping decisions (archive unused content)

## Common Issues and Solutions

### Slow Queries

**Symptoms:**
- Questions take a long time to load
- Dashboard cards spin for extended periods
- Timeout errors on complex queries

**Diagnosis:**
1. Check server logs for query execution times
2. Compare Metabase query time vs direct database query time
3. Review "Queries in flight" metric for concurrency issues
4. Use database-specific tools (e.g., `pg_stat_statements` for PostgreSQL)

**Solutions:**
- Add database indexes on frequently queried columns (WHERE, JOIN, ORDER BY)
- Reduce data volume with default filters and time range limits
- Enable caching for expensive queries
- Use models or materialized views for complex aggregations
- Consider a read replica to separate analytics from production
- Optimize JSON handling: extract keys into dedicated columns
- Ensure correct column data types to avoid runtime conversion
- Limit dashboard cards to 20-25 per tab

### Slow Dashboards

**Symptoms:**
- Dashboard takes >10 seconds to load
- Multiple cards loading sequentially
- Browser becomes unresponsive

**Diagnosis:**
1. Count the number of cards on the dashboard
2. Check individual question execution times
3. Review if cards share similar queries that could be combined
4. Check for unfiltered queries returning large datasets

**Solutions:**
- Split into multiple tabs (reduces simultaneous queries)
- Set default filter values to limit initial data load
- Enable dashboard-level caching (Pro/Enterprise)
- Reduce card count; aim for 20-25 maximum
- Use models as data sources for consistent caching
- Pre-warm caches via API during off-hours
- Consider denormalized summary tables for heavy aggregations

### Connection Problems

**Symptoms:**
- "Could not connect to database" errors
- Intermittent connection failures
- Timeout during database sync

**Common Causes and Solutions:**
- **Firewall/network**: Verify Metabase server can reach database host:port
- **SSH tunnel**: Check SSH key permissions, bastion host availability, tunnel timeout
- **SSL/TLS**: Verify certificate validity; try with SSL disabled to isolate
- **Credentials**: Verify username/password; check for password rotation
- **Connection pool**: Increase max connections if seeing pool exhaustion
- **Database load**: Check if database is under heavy load or maintenance
- **AWS IAM**: Verify IAM role permissions and token refresh (v58+)

### Permission Errors

**Symptoms:**
- Users see "Permission denied" or empty results
- Data sandboxing not filtering correctly
- Users can access data they shouldn't

**Diagnosis:**
1. Check user's group memberships
2. Review data permissions for each group at database/schema/table level
3. Verify collection permissions
4. Check if "All Users" group has overly permissive settings
5. Test from the user's perspective (impersonate if possible)

**Common Causes:**
- "All Users" group not restricted before applying granular permissions
- Permissions are additive: most permissive group wins
- Native query access granted to sandboxed database (overrides sandboxing)
- Collection permissions confused with data permissions
- Download permissions not aligned with view permissions

### Embedding Issues

**Symptoms:**
- Embedded content not loading
- CORS errors in browser console
- Authentication failures in embedded context
- "Powered by Metabase" badge appearing unexpectedly

**Solutions:**
- **CORS**: Add embedding origin URLs in Admin > Embedding settings
- **JWT signing**: Verify secret key matches between app and Metabase
- **Session expiry**: Check MAX_SESSION_AGE and implement token refresh
- **SameSite cookies**: Adjust cookie settings for cross-domain embedding
- **SDK version mismatch**: Ensure SDK version matches Metabase version
- **Origin whitelist**: Verify authorized origins include the embedding domain
- **Badge removal**: Requires Pro/Enterprise plan with white-labeling enabled

### Sync and Scan Issues

**Symptoms:**
- New tables/columns not appearing in Metabase
- Field values not showing in filter dropdowns
- JSON unfolding causing slow syncs

**Solutions:**
- Manually trigger sync: Admin > Databases > Sync database schema now
- Adjust sync schedule for large databases
- Disable JSON unfolding if not needed (reduces sync time significantly)
- Check database permissions for the Metabase connection user
- Review scan settings; reduce scan frequency for large tables
- Monitor sync duration in server logs

### Application Database Issues

**Symptoms:**
- H2 database corruption (production use)
- Slow Metabase startup or operations
- Migration failures during upgrades

**Solutions:**
- **H2 corruption**: Migrate to PostgreSQL immediately; restore from backup
- **Slow operations**: Migrate from H2 to PostgreSQL; optimize PostgreSQL settings
- **Migration failures**: Restore from pre-upgrade backup; do not interrupt migrations
- **Disk space**: Monitor application database size; clean up old audit/log entries

## Upgrade Troubleshooting

### Pre-Upgrade Checklist
1. Back up the application database (critical)
2. Review release notes for breaking changes
3. Reduce cluster to single node
4. Plan for potential downtime during migrations
5. Test upgrade in staging environment first

### Upgrade Process
- **Cloud**: Automatic; no action needed
- **Docker**: Stop container, pull new image, restart
- **JAR**: Stop service, replace JAR, restart
- Metabase runs database migrations automatically on startup

### Version Upgrade Paths
- **From before v40**: Must upgrade sequentially through each major version
- **Between major versions**: Use latest minor version as stepping stone (e.g., v54.5 before v55.x)
- **Never interrupt migrations**: Can corrupt application database

### Common Upgrade Issues

**Migration Failures:**
- Cause: Interrupted previous migration, incompatible data, version jump too large
- Solution: Restore from backup, follow sequential upgrade path

**SDK Breaking Changes:**
- Test SDK integration locally before upgrading production
- Review SDK upgrade documentation for required code changes

**Rollback Options:**
1. Restore application database from pre-upgrade backup (recommended)
2. Use `migrate down` command to roll back schema changes
3. Never run older Metabase version against a migrated database without rollback

### Post-Upgrade Verification
- Verify all dashboards and questions load correctly
- Test permissions and sandboxing
- Check embedding functionality
- Verify database connections and sync
- Monitor server logs for errors
- Test caching behavior

## Performance Diagnostics

### Identifying Bottlenecks

**Metabase Application Level:**
- Server logs: query execution times, response times
- Queries in flight: concurrency pressure
- JMX/VisualVM: memory, threads, CPU
- Usage analytics: identify expensive queries and popular dashboards

**Database Level:**
- Database-specific monitoring tools (pg_stat_statements, slow query log)
- Compare direct query times vs Metabase query times
- Monitor index usage and missing index suggestions
- Check connection pool utilization

**Network Level:**
- HAR files: request/response timing
- Browser developer tools: network waterfall
- SSH tunnel latency (if applicable)

### Key Metrics to Monitor
- Average query execution time
- Dashboard load time (total and per-card)
- Cache hit rate
- Queries in flight (concurrent query count)
- JVM heap usage and GC frequency
- Database connection pool utilization
- Sync/scan duration and frequency
- API response times

## Sources

- [Troubleshooting Guides](https://www.metabase.com/docs/latest/troubleshooting-guide/)
- [Diagnostic Information](https://www.metabase.com/docs/latest/troubleshooting-guide/diagnostic-info)
- [Database Performance](https://www.metabase.com/docs/latest/troubleshooting-guide/db-performance)
- [Slow Dashboards](https://www.metabase.com/docs/latest/troubleshooting-guide/my-dashboard-is-slow)
- [Server Logs](https://www.metabase.com/docs/latest/troubleshooting-guide/server-logs)
- [Monitoring Metabase](https://www.metabase.com/docs/latest/installation-and-operation/monitoring-metabase)
- [Upgrading Metabase](https://www.metabase.com/docs/latest/installation-and-operation/upgrading-metabase)
- [Sync and Scan Troubleshooting](https://www.metabase.com/docs/latest/troubleshooting-guide/sync-fingerprint-scan)
- [Model Troubleshooting](https://www.metabase.com/docs/latest/troubleshooting-guide/models)
- [Filter Troubleshooting](https://www.metabase.com/docs/latest/troubleshooting-guide/filters)
