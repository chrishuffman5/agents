# ThoughtSpot Diagnostics

## Search Performance Diagnostics

### Slow Search Queries

**Symptoms**: search queries take more than a few seconds; users report slow response times; timeout errors on complex queries.

**Diagnostic Steps**:

1. **Check the Performance Tracking Liveboard**: navigate to the built-in Performance Tracking Liveboard to review query execution metrics.
2. **Review AI/BI Stats data model**: create custom Answers against the AI/BI Stats model that captures query performance metrics for every query executed against external databases.
3. **Analyze query patterns**: identify which Models, columns, or join paths produce slow queries.
4. **Examine warehouse query logs**: check the target data warehouse's query history for ThoughtSpot-generated SQL to identify bottlenecks.

**Common Causes and Remediation**:

| Cause | Remediation |
|---|---|
| Unoptimized warehouse tables | Add clustering, partitioning, or indexing on frequently queried columns |
| Complex join paths in Models | Simplify join relationships; consider pre-joining in the warehouse |
| Large result sets without filters | Add default filters or encourage users to apply filters before searching |
| Over-indexed columns | Remove indexing from high-cardinality columns that are rarely searched |
| Insufficient warehouse compute | Scale up warehouse resources or enable auto-scaling |

### Poor Search Relevance

**Symptoms**: search suggestions do not match user intent; wrong columns are selected; unexpected results.

**Diagnostic Steps**:

1. **Review column names and synonyms**: verify that column names are business-friendly and synonyms cover common terminology.
2. **Check column indexing**: ensure frequently searched columns are indexed for auto-suggestions.
3. **Validate column types**: confirm that measures vs. attributes are correctly classified.
4. **Test with Spotter optimization**: use the Spotter optimization tab to review and correct column configurations.

**Remediation**:

- Rename columns to match business vocabulary
- Add synonyms for alternative terms users may search
- Reclassify incorrectly typed columns (measure vs. attribute)
- Enable indexing on key searchable columns
- Add column descriptions to improve search context

### Search Token Errors

**Symptoms**: "ambiguous" errors; "could not resolve" messages; incorrect token matching.

**Diagnostic Steps**:

1. Check for duplicate column names across tables in the Model
2. Verify FQN references in TML if objects share names
3. Review join paths for ambiguous relationships

**Remediation**:

- Use unique, descriptive column names
- Add FQN parameters to TML references
- Simplify or disambiguate join paths in Models

## Data Connectivity Diagnostics

### Connection Failures

**Symptoms**: unable to create or use a data connection; timeout errors when connecting to warehouses; authentication failures.

**Diagnostic Steps**:

1. **Verify credentials**: confirm service account credentials or OAuth tokens are valid and not expired.
2. **Test network connectivity**: check network paths between ThoughtSpot and the data warehouse.
3. **Review firewall/security group rules**: ensure ThoughtSpot IP ranges are whitelisted.
4. **Check PrivateLink configuration**: if using AWS PrivateLink, verify endpoint configuration.
5. **Enable client-side logging**: turn on ODBC/JDBC driver logs for detailed connection diagnostics.

### Common Connection Issues by Warehouse

#### Snowflake

| Issue | Remediation |
|---|---|
| OAuth token expiration | Refresh tokens or reconfigure OAuth with Azure AD/Okta |
| Warehouse suspended | Ensure Snowflake warehouse is set to auto-resume |
| Role permissions | Verify service account role has access to required schemas and tables |
| PrivateLink DNS | Confirm DNS resolution for the PrivateLink endpoint |

#### Google BigQuery

| Issue | Remediation |
|---|---|
| Service account permissions | Verify IAM roles include BigQuery Data Viewer and BigQuery Job User |
| Project/dataset access | Confirm service account has access to the specific project and dataset |
| API quotas | Check if BigQuery API quotas are being exceeded |

#### Databricks

| Issue | Remediation |
|---|---|
| Cluster state | Ensure Databricks cluster or SQL warehouse is running |
| Token validity | Verify personal access tokens are current |
| Unity Catalog permissions | Confirm catalog and schema access for the service principal |

### Data Sync Issues

**Symptoms**: stale data in ThoughtSpot; data does not match source warehouse; missing rows or columns.

**Diagnostic Steps**:

1. **Check connection status**: verify the connection is active and not in an error state.
2. **Review table metadata**: compare ThoughtSpot table definitions with source warehouse schemas.
3. **Validate column mappings**: ensure data types match between source and ThoughtSpot.
4. **Check SpotCache freshness**: if using SpotCache, verify cache refresh schedule and last refresh timestamp.

**Remediation**:

- Re-sync table metadata from the connection
- Update column data types in the Model/Worksheet
- Manually refresh SpotCache datasets
- Recreate the connection if persistent issues occur

### Multiple Configuration Management

**Symptoms**: need to route different queries to different warehouse configurations (e.g., different compute sizes).

**Remediation**:

- Use ThoughtSpot's multiple configurations per connection feature (Snowflake, Databricks, BigQuery)
- Route high-cost queries to appropriately sized compute resources
- Configure default and override connection settings

## Embedding Issues (ThoughtSpot Everywhere)

### Embed Not Rendering

**Symptoms**: blank iframe; loading spinner that never resolves; JavaScript errors in console.

**Diagnostic Steps**:

1. **Check browser console**: look for JavaScript errors, CORS issues, or blocked resources.
2. **Verify SDK initialization**: confirm `init` is called with correct `thoughtSpotHost` and `authType` parameters.
3. **Test authentication**: verify the authentication flow completes successfully.
4. **Check CSP headers**: ensure Content Security Policy headers allow ThoughtSpot iframe embedding.

**Common Causes and Remediation**:

| Cause | Remediation |
|---|---|
| CORS policy blocking requests | Configure ThoughtSpot to allow the host application's domain |
| Third-party cookie blocking | Switch to cookieless trusted authentication |
| Incorrect `thoughtSpotHost` URL | Verify the ThoughtSpot instance URL (include `https://`) |
| SDK version mismatch | Update to the latest Visual Embed SDK version |
| CSP frame-src restriction | Add ThoughtSpot domain to Content Security Policy `frame-src` |

### Authentication Failures in Embedded Context

**Symptoms**: login prompt appears in the embed; 401/403 errors; token expired errors.

**Diagnostic Steps**:

1. **Verify authentication type**: confirm the correct `authType` is configured in SDK init.
2. **Check token generation**: for trusted auth, verify the token request service is returning valid tokens.
3. **Review SSO configuration**: for SAML/OIDC, confirm IdP settings and redirect URIs.
4. **Test in popup mode**: for SSO, try `inPopup: true` to isolate redirect issues.

**Remediation**:

- Implement token refresh logic for trusted authentication
- Verify redirect URIs in SAML/OIDC configuration
- Enable popup-based SSO if iframe redirects fail
- Check that the user exists in ThoughtSpot (auto-provisioning via just-in-time)

### Styling and Layout Issues

**Symptoms**: embedded content does not match host application styling; layout overflows or is clipped; responsive sizing fails.

**Diagnostic Steps**:

1. **Inspect CSS overrides**: check if custom CSS is being applied correctly.
2. **Review container sizing**: verify the embed container has explicit width/height.
3. **Check responsive breakpoints**: test at different viewport sizes.

**Remediation**:

- Apply `customCssUrl` in SDK configuration with appropriate style overrides
- Set explicit dimensions on the embed container element
- Use CSS `resize: both` or responsive units for the container
- Test across target devices and screen sizes

### Custom Action Failures

**Symptoms**: custom actions do not trigger; callback data is empty or malformed; URL actions fail to open.

**Diagnostic Steps**:

1. **Verify action registration**: confirm the custom action is registered in the Developer Portal.
2. **Check event listeners**: ensure the host application has registered event listeners for callback actions.
3. **Review action context**: verify the action is configured for the correct visualization/object type.
4. **Test in Playground**: use the Developer Portal Playground to validate action behavior.

**Remediation**:

- Re-register the custom action with correct callback/URL configuration
- Add or fix event listeners in the host application code
- Verify CORS and CSP settings allow the action URL domain
- Check that required data columns are included in the action payload

## SpotIQ Tuning

### Low-Quality Insights

**Symptoms**: SpotIQ returns irrelevant insights; too many trivial outliers; insights do not match business context.

**Diagnostic Steps**:

1. **Review algorithm parameters**: check outlier detection sensitivity settings (multiplier, P-value thresholds).
2. **Check data quality**: verify source data does not contain excessive nulls, zeros, or outliers that skew analysis.
3. **Review column selections**: ensure SpotIQ is analyzing the right measures and attributes.
4. **Check user feedback history**: review thumbs-up/thumbs-down ratings to understand learning trajectory.

**Tuning Parameters**:

| Parameter | Effect | Recommendation |
|---|---|---|
| Outlier multiplier | Higher = fewer outliers flagged | Increase to 2.5-3.0 for noisy data |
| Maximum P-Value | Lower = more statistically significant only | Set to 0.01 for high-confidence insights |
| Min rows for analysis | Minimum data points required | Increase for small, volatile datasets |
| Max insight count | Insights per algorithm type | Reduce to 5-10 for focused output |
| Exclude nulls/zeros | Remove empty/zero values | Enable for cleaner results |

### SpotIQ Performance Issues

**Symptoms**: SpotIQ analysis takes too long; analysis times out; high warehouse compute costs during SpotIQ runs.

**Diagnostic Steps**:

1. **Check dataset size**: SpotIQ analyzes across many combinations; large datasets multiply compute requirements.
2. **Review column count**: more columns = exponentially more combinations to analyze.
3. **Monitor warehouse load**: check if SpotIQ queries are competing with other workloads.

**Remediation**:

- Limit the number of measure and attribute columns included in analysis
- Restrict analysis to the current result set rather than the full dataset
- Auto-tune date boundaries to reduce temporal analysis scope
- Schedule SpotIQ analyses during off-peak hours
- Use SpotCache for frequently analyzed datasets to reduce warehouse costs

### SpotIQ Learning Not Improving

**Symptoms**: insights remain generic despite extended use; user preferences not reflected.

**Diagnostic Steps**:

1. Check that users are providing thumbs-up/thumbs-down feedback
2. Verify sufficient feedback volume for the learning algorithm
3. Review if multiple users with different preferences are conflicting

**Remediation**:

- Encourage consistent user feedback on insights
- Train users on which insights to upvote/downvote
- Consider user-specific SpotIQ preferences for different roles

## Cluster Health (ThoughtSpot Software / On-Premises)

### Monitoring Tools

#### System Liveboards

- **Overview Board**: summarizes essential cluster information and user activity (Admin > System Health > Overview)
- **System charts**: generated in real-time from internal system data
- **System Worksheets**: underlying data models updated hourly from internal monitoring tables
- **Performance Tracking Liveboard**: detailed cluster performance metrics

#### Log Collection

ThoughtSpot logs are organized by component:

| Component | Logs Include |
|---|---|
| **Falcon** | In-memory engine operations, query execution, data loading |
| **Sage** | Search engine operations, query parsing, token resolution |
| **Orion Core** | Cluster management, node health, service coordination |
| **HDFS** | Distributed file system operations, data storage |
| **ZooKeeper** | Cluster coordination, configuration management |

### Common Cluster Health Issues

#### High Memory Usage

**Symptoms**: slow query performance; out-of-memory errors; Falcon engine crashes.

**Remediation**:

- Review indexed columns and remove unnecessary indexes
- Reduce in-memory data volume by archiving old data
- Scale cluster horizontally (add nodes) or vertically (more memory per node)
- Optimize Model designs to reduce join complexity

#### Node Failures

**Symptoms**: cluster operates in degraded mode; some queries fail; replication warnings.

**Remediation**:

- Check node health via System Liveboards
- Review hardware status (disk, memory, network)
- Restart failed services on the affected node
- Replace failed nodes and allow data rebalancing

#### Data Loading Failures

**Symptoms**: ETL/data load jobs fail; data appears stale; loading progress stalls.

**Remediation**:

- Check log files for specific error messages
- Verify source data format and schema compatibility
- Review disk space availability on cluster nodes
- Check network connectivity to data sources

### Network Connectivity (On-Premises)

**Diagnostic Steps**:

1. Check ODBC/JDBC drivers: verify versions and configuration
2. Test port connectivity between ThoughtSpot and data sources
3. Review DNS resolution
4. Enable client-side logging for driver-level diagnostics

**Common Network Issues**:

- Firewall rules blocking required ports
- DNS resolution failures for internal hostnames
- SSL/TLS certificate issues
- Proxy configuration preventing direct connections

## ThoughtSpot Cloud Diagnostics

### Cloud-Specific Monitoring

- **System Liveboards**: cluster health views available in cloud
- **AI/BI Stats**: query performance data model for custom monitoring
- **Connection health**: monitor status of cloud data warehouse connections
- **SpotCache status**: track cache freshness, size utilization, and refresh schedules

### Cloud Performance Issues

**Diagnostic Steps**:

1. Review query performance via AI/BI Stats data model
2. Check data warehouse connection latency
3. Monitor SpotCache hit rates and freshness
4. Review ThoughtSpot status page for platform-wide issues

**Remediation**:

- Optimize warehouse compute sizing for ThoughtSpot query patterns
- Enable SpotCache for high-frequency query patterns
- Review and optimize Model join paths
- Contact ThoughtSpot support for cluster-level issues (cloud-managed infrastructure)

## Diagnostic Checklist

### Quick Health Check

- [ ] System Liveboards show normal metrics
- [ ] All data warehouse connections are active
- [ ] Search queries return results within acceptable time
- [ ] SpotIQ analyses complete without errors
- [ ] Embedded components render correctly
- [ ] Monitor alerts are firing as expected
- [ ] User authentication flows complete successfully
- [ ] TML import/export operations succeed

### Escalation Path

1. **Self-service**: System Liveboards, log bundles, Performance Tracking Liveboard
2. **Community**: ThoughtSpot Community forums for peer guidance
3. **Support**: ThoughtSpot Support with log bundles and reproduction steps
4. **Professional Services**: for complex architecture, performance, or migration issues
