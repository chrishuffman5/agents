# Tableau Diagnostics

## Performance Analysis

### Performance Recording

**How to use:**
1. Enable: Help > Settings and Performance > Start Performance Recording
2. Interact with the workbook/dashboard to capture the slow operation
3. Stop: Help > Settings and Performance > Stop Performance Recording
4. Tableau generates a performance workbook with diagnostic data

**Performance Summary Dashboard contains:**
- **Timeline view**: Events arranged chronologically; shows execution sequence
- **Events view**: Events sorted by duration (longest first); identifies biggest bottlenecks
- **Query view**: Actual queries sent to data sources with execution times

**Key events to analyze:**

| Event | Indicates |
|---|---|
| `Computing layout` | Complex dashboard layout (too many containers, nested objects) |
| `Executing query` | Slow database response or network latency |
| `Compiling query` | Overly complex calculations being translated to SQL |
| `Generating extract` | Extract-related operations taking too long |
| `Connecting to data source` | Slow connection establishment (driver, network, auth) |
| `Rendering` | Too many marks being drawn on screen |
| `Blending data` | Slow merge of blended data sources |

### Workbook Optimizer (2022.1+)

- Access: Server > Run Optimizer
- Examines calculations against best practices
- Identifies issues affecting performance
- Provides specific remediation recommendations
- Checks for: unused fields, inefficient calculations, excessive marks, filter complexity

### VizQL Session Analysis

- Monitor active VizQL sessions via Tableau Server admin views
- Track session duration, query counts, and data transferred
- Identify users/workbooks consuming excessive resources
- Use Repository queries to analyze historical VizQL performance trends

## Common Issues

### Slow Dashboards

**Symptoms:** Long load times, spinning indicator, timeouts

**Diagnostic steps:**
1. Run Performance Recording to identify which events are slowest
2. Run Workbook Optimizer for automated recommendations
3. Check mark count (Status bar at bottom of view); >10,000 marks indicates potential issues
4. Review filter configuration (each quick filter = separate query)
5. Check data source type (live vs extract)

**Common causes and fixes:**

| Cause | Fix |
|---|---|
| Too many marks | Aggregate data, filter, or use summary views |
| Complex calculations | Simplify; move logic to data source; materialize in extract |
| Excessive quick filters | Replace with action filters or parameters |
| Live connection to slow DB | Switch to extract; optimize source queries |
| Large cross-database joins | Consolidate to single source; use extract |
| Nested LOD expressions | Simplify; consider pre-computing in data source |
| Unoptimized extract | Re-create extract with aggregation and field hiding |
| Dashboard overload | Split into multiple focused dashboards |

### Extract Refresh Failures

**Diagnostic steps:**
1. Navigate to site Jobs page > filter by "Refresh Extracts" + Status "Failed"
2. Click failed job for error message (most important diagnostic clue)
3. Check backgrounder logs for detailed error codes
4. Verify data source connectivity from server

**Common causes:**

| Cause | Fix |
|---|---|
| Expired credentials | Update embedded credentials; use OAuth where possible |
| Missing/outdated drivers | Install correct driver version on all server nodes |
| Network connectivity | Verify network path and port access; check Bridge status for Cloud |
| Resource contention | Stagger refresh schedules; optimize queries; add backgrounder resources |
| Timeout (default 7200s) | Increase timeout via TSM; optimize query; use incremental refresh |
| Schema changes | Update data source definition; use virtual connections for centralized management |
| Disk space | Monitor disk usage; clean old extracts; increase storage |

### Data Source Connectivity

**Common connection issues:**
- Authentication failures: wrong credentials, expired tokens, SSO misconfiguration
- Driver mismatch: driver version incompatible with database version
- SSL/TLS issues: certificate validation failures, expired certificates
- Tableau Bridge failures: Bridge client offline, network changes, proxy configuration
- Connection pooling exhaustion: too many concurrent connections to same source

**Diagnostic approach:**
1. Test connection in Tableau Desktop first (isolates server-specific issues)
2. Check driver installation on server nodes
3. Verify network connectivity (telnet/ping to database host:port)
4. Review connection string and authentication method
5. For Bridge: check Bridge client status, logs, and network connectivity

## Server Administration

### TSM (Tableau Services Manager) Commands

**Server lifecycle:**
```bash
tsm start                          # Start all server processes
tsm stop                           # Stop all server processes
tsm restart                        # Restart all processes
tsm status -v                      # Detailed status of all processes
```

**Configuration:**
```bash
tsm configuration get -k <key>     # Get configuration value
tsm configuration set -k <key> -v <value>  # Set configuration value
tsm pending-changes apply          # Apply pending configuration changes
tsm pending-changes discard        # Discard pending changes
```

**Maintenance:**
```bash
tsm maintenance backup -f <filename>       # Create server backup
tsm maintenance restore -f <filename>      # Restore from backup
tsm maintenance ziplogs -f <filename>      # Create log archive
tsm maintenance cleanup                    # Clean temporary files
```

**Topology:**
```bash
tsm topology list-nodes            # List all server nodes
tsm topology list-ports            # List ports in use
tsm topology set-process -n <node> -pr <process> -c <count>  # Configure processes
```

**Security:**
```bash
tsm security external-ssl enable   # Enable SSL
tsm security custom-cert add       # Add custom certificate
```

**Legacy tabadmin** (pre-TSM, Server 2018.1 and earlier): deprecated. TSM is the current management interface.

### Log Analysis

**Key log directories (Linux):**
```
/var/opt/tableau/tableau_server/data/tabsvc/logs/
  httpd/           # Gateway/Apache logs (access logs, request routing)
  vizqlserver/     # VizQL processing logs (query execution, rendering)
  backgrounder/    # Extract refreshes, subscriptions, scheduled tasks
  dataserver/      # Data source management, connection pooling
  vizportal/       # Application server (UI, REST API, authentication)
  tabprotosrv/     # Protocol server (data source connectivity)
```

**Key log directories (Windows):**
```
C:\ProgramData\Tableau\Tableau Server\data\tabsvc\logs\
  (same subdirectory structure as Linux)
```

**Log analysis approach:**
1. Collect logs: `tsm maintenance ziplogs -f logs.zip`
2. Identify the timeframe of the issue
3. Start with `httpd` logs for the failing request (find request ID and HTTP status code)
4. Search `vizqlserver` logs for the request ID to trace query execution
5. For extract failures: search `backgrounder` logs for the extract/data source name
6. For connection issues: check `tabprotosrv` logs for driver and connection errors

**Log levels:**
- Default: Info level (sufficient for most diagnostics)
- Increase to Debug only when troubleshooting specific issues (per Tableau Support guidance)
- Set: `tsm configuration set -k <service>.log.level -v debug`
- Reset after troubleshooting: `tsm configuration set -k <service>.log.level -v info`
- Always apply changes: `tsm pending-changes apply`

### Logs Quick Reference

| Log File | What It Captures | When to Check |
|---|---|---|
| `httpd/access.log` | All HTTP requests, response codes | Request routing, 4xx/5xx errors |
| `vizqlserver/*.log` | VizQL query generation, execution | Slow views, rendering errors |
| `backgrounder/*.log` | Scheduled tasks, extract refreshes | Refresh failures, subscription errors |
| `dataserver/*.log` | Data source connections, metadata | Connection failures, permission issues |
| `vizportal/*.log` | Web UI, REST API, authentication | Login failures, API errors |
| `tabprotosrv/*.log` | Protocol-level data source communication | Driver errors, connection timeouts |
| `hyper/*.log` | Extract engine operations | Extract creation/query failures |

### Site Management

- **Multi-site**: Isolate departments/tenants with separate sites on same server
- **Admin views**: Built-in dashboards showing server performance, user activity, extract status
- **Repository queries**: Direct PostgreSQL queries for custom monitoring (read-only access via `readonly` user)
- **Resource Monitoring Tool**: Optional add-on for detailed server health monitoring
- **Content migration**: Use REST API, `tabcmd`, or Migration SDK for cross-site content movement

## Embedding Issues

### Authentication Problems

| Symptom | Cause | Fix |
|---|---|---|
| Blank embedded view | Third-party cookies blocked | Configure browser to allow Tableau domain cookies, or use Connected Apps with JWT |
| Session expires mid-use | JWT token expiration | Set appropriate token lifetime; implement token refresh logic |
| 401/403 errors | Connected Apps misconfigured | Verify Connected App config; check JWT payload (iss, sub, aud, exp claims) |
| Redirect loops | IdP misconfiguration in iframe | Verify IdP config for iframe embedding; consider Connected Apps instead |

### Sizing Issues

| Symptom | Cause | Fix |
|---|---|---|
| Viz does not resize | Fixed-size container | Use `resize()` method on Viz/AuthoringViz after container changes |
| Not mobile responsive | Missing device layouts | Create device-specific layouts; implement responsive container CSS |
| Toolbar consumes space | Toolbar visible in small container | Set `toolbar="hidden"` via Embedding API options |

### Cross-Origin Issues

| Symptom | Cause | Fix |
|---|---|---|
| CORS errors | Locally hosted Embedding API library | Use CDN: `https://embedding.tableauusercontent.com/tableau.embedding.3.x.min.js` |
| Cannot inspect iframe | Cross-domain browser security | Use Embedding API events and methods for programmatic interaction |
| Content blocked | Mixed HTTP/HTTPS | Ensure both parent page and Tableau use HTTPS |

### Content Not Found

| Symptom | Cause | Fix |
|---|---|---|
| View URL broken | Workbook/view renamed on server | Use content URL or LUID-based references; implement error handling |
| Permission denied | User access removed | Verify Connected App scope and user permissions; show graceful error |
