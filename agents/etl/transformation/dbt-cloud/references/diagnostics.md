# dbt Cloud Diagnostics and Troubleshooting

## Job Failure Categories

dbt Cloud job failures fall into six categories:

| Category | Description | First Action |
|---|---|---|
| **SQL Errors** | Syntax issues, missing tables, incorrect joins, type mismatches | Check compiled SQL in run artifacts |
| **Model Dependency Issues** | Broken refs, circular dependencies, missing upstream data | Check DAG for broken edges |
| **Schema Changes** | Upstream schema changes not reflected in model definitions | Review source schema vs model expectations |
| **Data Quality Issues** | Unexpected nulls, duplicates, constraint violations | Inspect test results and source data |
| **Resource Constraints** | Warehouse timeouts, memory limits, query complexity | Review warehouse query history |
| **Code/Compilation Errors** | Jinja syntax, undefined variables, invalid YAML | Check error message for file and line |

## Debugging Workflow

### Step-by-Step Process

1. **Check job run logs** in dbt Cloud for the specific error message
2. **Classify the failure**: infrastructure, code/compilation, or data/test issue
3. **For SQL errors**: examine compiled SQL in run artifacts
4. **For dependency issues**: check DAG for broken refs or circular dependencies
5. **For resource issues**: review warehouse query history for timeouts
6. **For data issues**: inspect source freshness and data quality
7. **For platform issues**: check status.getdbt.com

### Admin API for Diagnostics

- Retrieve job history and detailed error logs via Admin API
- Filter runs by status (success, error, cancelled)
- Programmatic access to run artifacts and compiled SQL
- Useful for building custom monitoring and alerting

## Environment Configuration Issues

### Common Problems

**Credential mismatch**
- Symptom: Job fails with authentication error in one environment but works in another
- Fix: Verify warehouse credentials in Project Settings > Connection for each environment
- Check: Different environments may need different service account credentials

**Schema conflicts**
- Symptom: Models overwrite each other across environments
- Fix: Configure separate schemas per environment. Use PR-specific schemas for CI:
  ```yaml
  schema: "ci_pr_{{ env_var('PR_NUMBER', 'default') }}"
  ```

**Version mismatch**
- Symptom: Features work locally but fail in Cloud, or vice versa
- Fix: Check dbt version settings for each environment. New projects default to Fusion Latest.
- Note: Fusion engine may have different behavior than the Python-based Core engine for edge cases.

**Missing environment variables**
- Symptom: `env_var()` calls fail with "Environment variable not found"
- Fix: Define the variable in dbt Cloud environment settings. Always provide defaults:
  ```
  {{ env_var('MY_VAR', 'fallback_value') }}
  ```

### Resolution Steps

1. Verify warehouse credentials in project settings for each environment
2. Confirm schema/database configuration per environment for data isolation
3. Check dbt version settings; new projects default to Fusion Latest
4. Review environment variable definitions and ensure defaults are set
5. Test connectivity by running `dbt debug` in the development environment

## Git Sync Problems

### GitHub Issues

**Repository name case sensitivity**
- Symptom: Cloning errors or job failures
- Cause: Repository name in dbt Cloud does not exactly match the case in the GitHub URL
- Fix: Update the repository name in dbt Cloud to match GitHub exactly

**OAuth token expiration**
- Symptom: Git operations fail with authentication errors
- Fix: Re-authenticate via dbt Cloud > Account Settings > Integrations > GitHub

**Permissions**
- Symptom: Cannot access repository from dbt Cloud
- Fix: Ensure the dbt Cloud GitHub app has access to the target repository in GitHub's app settings

### GitLab Issues

**Deploy key mismatch**
```
500 Error: GitLab Authentication is out of date
```
- Cause: Deploy keys in dbt and GitLab do not match
- Fix:
  1. Go to GitLab > Settings > Repository
  2. Remove/revoke active dbt deploy tokens and deploy keys
  3. Reconnect repository via dbt Cloud
  4. Verify new deploy key in GitLab
  5. Ensure "Allow write access" is checked on the deploy key
  6. Refresh dbt Cloud

### Azure DevOps Issues

- Verify Azure DevOps project URL and authentication settings
- Ensure the service connection has appropriate repository access
- Check organization and project permissions

### General Git Troubleshooting

- Each dbt project generates a unique deploy key, even when connected to the same repository
- Multiple projects require separate deploy keys in the Git provider
- Managed repositories (dbt-hosted Git) can be used as a simpler alternative
- For persistent issues: contact support@getdbt.com

## Performance Issues

### Slow Jobs

**Identify bottleneck models**:
- Use dbt Explorer's performance insights for historical execution data
- Check `run_results.json` in job artifacts for per-model timing
- Sort by execution time to find the slowest models

**Common causes and fixes**:

| Cause | Fix |
|---|---|
| Expensive views stacked 5+ levels deep | Switch to tables or incremental |
| Full table scans on large datasets | Add partitioning/clustering |
| Inefficient SQL (unnecessary joins, `SELECT *`) | Optimize compiled SQL |
| Low parallelism | Increase thread count |
| Full table rebuilds on large datasets | Switch to incremental materialization |

**Warehouse sizing**:
- Scale up warehouse for heavy transformation jobs
- Use separate warehouses for dbt jobs vs ad-hoc queries
- On Databricks: use SQL warehouses (optimized for SQL workloads); start Medium
- On Snowflake: configure auto-suspend at 1-2 minutes

### Scheduler Queue Issues

**Job overlap**
- Symptom: Scheduled runs are delayed or skipped
- Cause: Long-running jobs block subsequent scheduled runs
- Fix: Review job frequency. Consolidate overlapping jobs. Increase warehouse size.

**Concurrency limits**
- Symptom: Jobs wait in queue before starting
- Cause: Account-level concurrent run limit reached
- Fix: Check account settings for concurrent run limits. Stagger job schedules.

**Platform incidents**
- Symptom: Multiple jobs failing simultaneously
- Fix: Check status.getdbt.com for ongoing service issues
- Example: April 2025 AWS outage affected job queuing and execution across regions

### Warehouse Bottlenecks

| Issue | Fix |
|---|---|
| Query timeouts | Increase warehouse timeout or optimize query |
| Resource contention | Separate warehouses for dbt vs ad-hoc |
| Slow startup | Configure auto-resume with 1-2 min suspend |
| Full table scans | Add clustering keys or partitioning |

## IDE Issues

### Studio IDE (Cloud IDE)

**Session launch failures**
- Can occur during platform incidents
- Fix: Check status.getdbt.com. Try again after a few minutes.

**Compilation errors after file rename**
- Renaming a model file can cause compiler errors
- Fix: Use File > Save All to save all edited files. Refresh IDE session.

**Unsaved changes not picked up**
- dbt uses the last-saved version of files
- Fix: Always Cmd+S / Ctrl+S before running dbt commands

**Preview timeouts**
- Queries time out on large datasets
- Fix: Add `LIMIT` to preview queries. Optimize the underlying query.

**Stale IDE session**
- Compilation results seem outdated
- Fix: Refresh browser. Restart IDE session.

### VS Code Extension

**Extension conflicts**
- May conflict with third-party dbt extensions providing similar services
- Fix: Disable third-party dbt extensions when using the official one

**Version issues**
- Ensure latest extension version. Restart VS Code after updates.

**Fusion engine issues**
- Verify Fusion engine is properly installed
- Check VS Code Output panel > Log > dbt for detailed error logs

**LSP cache problems**
- If compile results seem stale: clear the LSP cache and restart VS Code
- For debug logging: open command palette > "Set Log Level" > Debug

### dbt Cloud CLI

**Authentication failures**
```
Error: Invalid or expired token
```
- Fix: Re-run `dbt auth login` to refresh the token

**Configuration issues**
- Verify `dbt_cloud.yml` or `profiles.yml` point to correct project and environment

**Network issues**
- Ensure local network allows connections to dbt Cloud endpoints
- Check corporate firewall or proxy settings

## API and Webhook Troubleshooting

### Administrative API

**401 Unauthorized**
- Verify service token is valid and has correct permissions
- Tokens are scoped per account; check account ID in the request

**Rate limiting**
- Respect API rate limits
- Implement exponential backoff for retries
- Use pagination for large result sets

**v2 vs v3**
- Use v3 (recommended) for new integrations
- Some endpoints differ between versions; check API docs

### Discovery API

**Token scoping**
- Use Metadata-only service tokens with `Token` prefix in Authorization header
- Example: `Authorization: Token <service-token>`

**Query complexity**
- Complex GraphQL queries may time out
- Break into smaller, focused queries
- Use pagination for large metadata sets

**Environment selection**
- Ensure you're querying the correct environment ID
- Environment IDs are visible in dbt Cloud URL and settings

### Webhooks

**Timeout**
- Webhooks have a 10-second timeout
- Ensure your endpoint responds quickly (acknowledge receipt, process async)

**Failed deliveries**
- Check Recent Deliveries section for each webhook
- dbt retries each event 5 times; delivery logs retained for 30 days

**Event filtering**
- Use `job.run.completed` with `runStatus` or `runStatusCode` for targeted processing
- Status codes: 10 (success), 20 (error), 30 (cancelled)

**Endpoint validation**
- Webhook endpoint must be publicly accessible
- Must return HTTP 200 to confirm receipt

### Semantic Layer APIs

**JDBC connection issues**
- Verify Arrow Flight SQL driver configuration
- Check host, port, and authentication token

**Metric not found**
- Ensure semantic models and metrics are defined in YAML
- Ensure the project has been built (`dbt build`) after adding semantic definitions

**Slow metric queries**
- MetricFlow pushes computation to the warehouse
- Optimize warehouse performance, partitioning, and clustering
- Consider precomputing heavy metrics into aggregate tables

## Platform Status and Monitoring

### Monitoring

- Check https://status.getdbt.com for current platform status
- Subscribe to status updates for your region (US AWS, APAC AWS, etc.)
- Configure notifications (email, Slack) for job failures to detect issues early

### Incident Response

- dbt Labs publishes detailed write-ups for major incidents
- For urgent issues: Enterprise plans have in-app support chat
- General support: support@getdbt.com
- Community: discourse.getdbt.com and dbt Slack

## Debugging Checklist

### Job Failure Quick Steps

1. **Read the error message** in the job run log (dbt Cloud UI > Runs)
2. **Classify the failure**: SQL, dependency, schema, data, resource, or compilation
3. **Check compiled SQL** in run artifacts for SQL errors
4. **Check DAG** in dbt Explorer for dependency issues
5. **Check warehouse** query history for resource constraints
6. **Check platform status** at status.getdbt.com for infrastructure issues
7. **Re-run the job** if the failure was transient (timeout, network blip)
8. **Check environment config** if the same model works in dev but fails in prod

### Common Pitfalls

1. **Unsaved files in IDE** -- Always save before running commands
2. **Wrong environment** -- Verify which environment a job runs in
3. **Stale artifacts** -- CI jobs compare against the last successful deploy job manifest; ensure deploy jobs run regularly
4. **Missing `dbt deps`** -- New packages require `dbt deps` before first use
5. **Credential rotation** -- After rotating warehouse credentials, update all environments in dbt Cloud
6. **Git branch mismatch** -- Production jobs should run from the default branch (main/master)
7. **Concurrency conflicts** -- Multiple jobs writing to the same tables can cause locking issues
8. **Fusion vs Core behavior differences** -- Edge cases may behave differently; check Fusion documentation for known differences
