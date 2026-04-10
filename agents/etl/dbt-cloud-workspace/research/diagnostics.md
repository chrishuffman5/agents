# dbt Cloud Diagnostics

## Common Job Failures

### Failure Categories
1. **SQL Errors**: Syntax issues, missing tables, incorrect joins, type mismatches
2. **Model Dependency Issues**: Broken references, circular dependencies, missing upstream data
3. **Schema Changes**: Upstream schema changes not reflected in model definitions
4. **Data Quality Issues**: Unexpected nulls, duplicates, constraint violations
5. **Resource Constraints**: Warehouse timeouts, memory limitations, query complexity
6. **Code/Compilation Errors**: Jinja syntax errors, undefined variables, invalid YAML

### Debugging Workflow
1. Check job run logs in dbt Cloud for the specific error message
2. Classify the failure: infrastructure, code/compilation, or data/test issue
3. For SQL errors: examine the compiled SQL in the run artifacts
4. For dependency issues: check the DAG for broken refs or circular dependencies
5. For resource issues: review warehouse query history for timeouts or resource limits
6. For data issues: inspect source data freshness and quality

### Admin API for Diagnostics
- Retrieve job history and detailed error logs via Admin API
- Filter runs by status (success, error, cancelled)
- Programmatic access to run artifacts and compiled SQL
- Useful for building custom monitoring and alerting systems

## Environment Configuration Issues

### Common Problems
- **Credential mismatch**: Development and production credentials not configured correctly
- **Schema conflicts**: Multiple environments writing to the same schema
- **Version mismatch**: Environment running a different dbt version than expected
- **Missing environment variables**: `env_var()` calls failing due to undefined variables

### Resolution Steps
1. Verify warehouse credentials in project settings for each environment
2. Confirm schema/database configuration per environment for data isolation
3. Check dbt version settings; new projects default to Fusion Latest
4. Review environment variable definitions and ensure defaults are set for optional values
5. Test connectivity by running `dbt debug` in the development environment

## Git Sync Problems

### GitHub Issues
- **Repository name case sensitivity**: Repository name in dbt Cloud must exactly match the case used in the GitHub URL; mismatches cause cloning errors or job failures
- **OAuth token expiration**: Re-authenticate if GitHub integration shows stale credentials
- **Permissions**: Ensure the dbt Cloud GitHub app has access to the target repository

### GitLab Issues
- **Deploy key mismatch**: "GitLab Authentication is out of date" 500 error occurs when deploy keys in dbt and GitLab do not match
- **Resolution**: Go to GitLab Settings > Repository, remove/revoke active dbt deploy tokens and deploy keys, reconnect repository via dbt, verify new deploy key, refresh dbt
- **Write access**: Ensure "Allow write access" is checked on the deploy key

### Azure DevOps Issues
- **Connection configuration**: Verify Azure DevOps project URL and authentication settings
- **Service principal permissions**: Ensure the service connection has appropriate repository access

### General Git Troubleshooting
- Each dbt project generates a unique deploy key, even when connected to the same repository
- Multiple projects require separate deploy keys configured in the Git provider
- For persistent issues, contact dbt support at support@getdbt.com
- Managed repositories (dbt-hosted Git) can be used as a simpler alternative

## Performance Issues

### Slow Jobs
- **Identify bottleneck models**: Use dbt Explorer's performance insights for historical execution data
- **Materialization strategy**: Switch expensive views to tables or incremental models
- **Warehouse sizing**: Scale up compute for heavy transformation jobs
- **Query optimization**: Review compiled SQL for inefficient patterns (unnecessary joins, full table scans)
- **Parallelism**: Increase threads to run independent models concurrently
- **Incremental models**: Process only new/changed data instead of full refreshes

### Scheduler Queue Issues
- **Job overlap**: Long-running jobs can delay subsequent scheduled runs
- **Concurrency limits**: Check account-level concurrent run limits
- **Stale queue**: If the scheduler is backed up, review job frequency and consolidate where possible
- **Platform incidents**: Check status.getdbt.com for ongoing service issues (e.g., April 2025 AWS outage affected job queuing and execution across regions)

### Warehouse Bottlenecks
- **Query timeouts**: Increase warehouse timeout settings or optimize the query
- **Resource contention**: Use separate warehouses for dbt jobs vs. ad-hoc queries
- **Auto-suspend/resume**: Configure 1-2 minute suspend for cost savings without impacting job start times
- **Clustering/partitioning**: Add clustering keys or partitioning to large tables
- **Databricks-specific**: Use SQL warehouses (optimized for SQL workloads); start with Medium size

## IDE Issues

### Studio IDE (Cloud IDE)
- **Session launch failures**: Can occur during platform incidents; check status.getdbt.com
- **Compilation errors after file rename**: Renaming a model file may cause compiler errors; use File > Save All to save all edited files
- **Unsaved changes not picked up**: dbt uses last-saved version of files; always save (Cmd+S / Ctrl+S) before running commands
- **Preview timeouts**: Queries may time out on large datasets; use `limit` in preview or optimize the query
- **Stale IDE session**: Refresh the browser or restart the IDE session if compilation results seem outdated

### VS Code Extension
- **Extension conflicts**: May conflict with other VS Code extensions providing similar services (code validation); disable third-party dbt extensions when using the official one
- **Version updates**: Ensure you are running the latest version of the dbt VS Code extension; restart VS Code after updates
- **Fusion engine issues**: Make sure the dbt Fusion engine is properly installed; check VS Code output panel for errors
- **LSP cache**: New language server cache improves compile times; if experiencing issues, clear the cache and restart
- **Log inspection**: Select Log > dbt from the output panel dropdown to view detailed extension logs
- **Debug logging**: Open command palette and type "Set Log Level" to change to Debug for more verbose output

### dbt Cloud CLI
- **Authentication**: Ensure dbt Cloud CLI is authenticated; re-run `dbt auth login` if token expired
- **Configuration**: Verify `dbt_cloud.yml` or `profiles.yml` settings point to correct project and environment
- **Network issues**: Check that local network allows connections to dbt Cloud endpoints

## API and Webhook Troubleshooting

### Administrative API
- **401 Unauthorized**: Verify service token is valid and has correct permissions
- **Rate limiting**: Respect API rate limits; implement exponential backoff for retries
- **v2 vs v3**: Use v3 (recommended) for new integrations; some endpoints may differ between versions
- **Pagination**: Use pagination parameters for large result sets to avoid timeouts

### Discovery API
- **Token scoping**: Use Metadata-only service tokens with `Token` prefix in Authorization header
- **Query complexity**: Complex GraphQL queries may time out; break into smaller, focused queries
- **Environment selection**: Ensure you are querying the correct environment ID
- **Paginated endpoints**: Use pagination for large metadata queries (paginated endpoints now available for Semantic Layer metadata)

### Webhooks
- **Timeout**: Webhooks have a 10-second timeout; ensure your endpoint responds quickly
- **Failed deliveries**: Check Recent Deliveries section for each webhook to see success/failure status
- **Retry behavior**: dbt retries each event 5 times; delivery logs retained for 30 days
- **Event filtering**: Use `job.run.completed` event with `runStatus` or `runStatusCode` filters for targeted processing
- **Endpoint validation**: Ensure your webhook endpoint is publicly accessible and returns HTTP 200

### Semantic Layer APIs
- **JDBC connection**: Verify Arrow Flight SQL driver configuration; check host, port, and authentication
- **GraphQL queries**: Use the `queryRecords` endpoint for data retrieval; check schema for available fields
- **Metric not found**: Ensure semantic models and metrics are defined in YAML and the project has been built
- **Slow queries**: MetricFlow pushes computation to the warehouse; optimize warehouse performance

## Platform Status and Incidents

### Monitoring
- Check https://status.getdbt.com for current platform status
- Subscribe to status updates for your region (US AWS, APAC AWS, etc.)
- Configure notifications (email, Slack) for job failures to detect issues early

### Known Historical Issues
- **April 2025 AWS outage**: Affected IDE session launches, job queuing, and execution across all AWS regions
- **Incident response**: dbt Labs publishes detailed write-ups for major incidents

### Support Channels
- In-app support chat (Enterprise plans)
- Email: support@getdbt.com
- dbt Community Forum: discourse.getdbt.com
- dbt Slack community
- GitHub issues for open-source components
