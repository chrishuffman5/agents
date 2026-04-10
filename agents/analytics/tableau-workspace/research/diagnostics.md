# Tableau Diagnostics

## Performance Analysis

### Performance Recording
**How to use:**
1. Enable: Help > Settings and Performance > Start Performance Recording
2. Interact with the workbook/dashboard to capture the slow operation
3. Stop: Help > Settings and Performance > Stop Performance Recording
4. Tableau generates a performance workbook with diagnostic data

**Performance Summary Dashboard contains:**
- **Timeline view**: Events arranged chronologically left-to-right; shows execution sequence
- **Events view**: Events sorted by duration (longest first); identifies biggest bottlenecks
- **Query view**: Actual queries sent to data sources with execution times

**Key events to analyze:**
- `Computing layout`: Time spent calculating view layout (high = complex dashboard)
- `Executing query`: Time spent waiting for database response (high = slow queries or network)
- `Compiling query`: Time VizQL spends translating to SQL (high = overly complex calculations)
- `Generating extract`: Time for extract-related operations
- `Connecting to data source`: Time establishing database connections
- `Rendering`: Time drawing marks on screen (high = too many marks)
- `Blending data`: Time merging blended data sources

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

---

## Common Issues

### Slow Dashboards

**Symptoms:** Long load times, spinning indicator, timeouts

**Diagnostic Steps:**
1. Run Performance Recording to identify which events are slowest
2. Run Workbook Optimizer for automated recommendations
3. Check mark count (Status bar > bottom of view); >10,000 marks indicates potential issues
4. Review filter configuration (each quick filter = separate query)
5. Check data source type (live vs extract)

**Common Causes & Fixes:**
| Cause | Fix |
|-------|-----|
| Too many marks | Aggregate data, filter, or use summary views |
| Complex calculations | Simplify; move logic to data source; materialize in extract |
| Excessive quick filters | Replace with action filters or parameters |
| Live connection to slow DB | Switch to extract; optimize source queries |
| Large cross-database joins | Consolidate to single source; use extract |
| Nested LOD expressions | Simplify; consider pre-computing in data source |
| Unoptimized extract | Re-create extract with aggregation and field hiding |
| Dashboard overload | Split into multiple focused dashboards |

### Extract Refresh Failures

**Diagnostic Steps:**
1. Navigate to site Jobs page > filter by "Refresh Extracts" + Status "Failed"
2. Click failed job for error message (most important diagnostic clue)
3. Check backgrounder logs for detailed error codes
4. Verify data source connectivity from server

**Common Causes:**
- **Expired credentials**: Database passwords expired or service accounts locked out
  - Fix: Update embedded credentials in data source; use OAuth where possible
- **Missing/outdated drivers**: Tableau Server lacks required database driver
  - Fix: Install correct driver version on all server nodes
- **Network connectivity**: Firewall blocking server-to-database communication
  - Fix: Verify network path and port access; check Tableau Bridge status for Cloud
- **Resource contention**: Database overloaded during refresh window
  - Fix: Stagger refresh schedules; optimize source queries; increase backgrounder resources
- **Timeout (7200 seconds default)**: Query too complex or database too slow
  - Fix: Increase timeout via TSM; optimize query; use incremental refresh
- **Schema changes**: Source table/column renamed or removed
  - Fix: Update data source definition; use virtual connections for centralized management
- **Disk space**: Insufficient space for .hyper file creation
  - Fix: Monitor disk usage; clean old extracts; increase storage

### Data Source Connectivity

**Common connection issues:**
- **Authentication failures**: Wrong credentials, expired tokens, SSO misconfiguration
- **Driver mismatch**: Driver version incompatible with database version
- **SSL/TLS issues**: Certificate validation failures, expired certificates
- **Tableau Bridge failures**: Bridge client offline, network changes, proxy configuration
- **Connection pooling exhaustion**: Too many concurrent connections to same source

**Diagnostic approach:**
1. Test connection in Tableau Desktop first (isolates server-specific issues)
2. Check driver installation on server nodes
3. Verify network connectivity (telnet/ping to database host:port)
4. Review connection string and authentication method
5. For Bridge: check Bridge client status, logs, and network connectivity

---

## Server Administration

### TSM (Tableau Services Manager) Commands

**Core administrative commands:**
```bash
# Server lifecycle
tsm start                          # Start all server processes
tsm stop                           # Stop all server processes
tsm restart                        # Restart all processes
tsm status -v                      # Detailed status of all processes

# Configuration
tsm configuration get -k <key>     # Get configuration value
tsm configuration set -k <key> -v <value>  # Set configuration value
tsm pending-changes apply          # Apply pending configuration changes
tsm pending-changes discard        # Discard pending changes

# Maintenance
tsm maintenance backup -f <filename>       # Create server backup
tsm maintenance restore -f <filename>      # Restore from backup
tsm maintenance ziplogs -f <filename>      # Create log archive
tsm maintenance cleanup                    # Clean temporary files

# Topology
tsm topology list-nodes            # List all server nodes
tsm topology list-ports            # List ports in use
tsm topology set-process -n <node> -pr <process> -c <count>  # Configure processes

# Security
tsm security external-ssl enable   # Enable SSL
tsm security custom-cert add       # Add custom certificate

# User management
tsm user-identity-store            # Configure identity store
```

**Legacy tabadmin (pre-TSM, Server 2018.1 and earlier):**
- `tabadmin start/stop/restart`
- `tabadmin backup/restore`
- `tabadmin ziplogs`
- Note: tabadmin is deprecated; TSM is the current management interface

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
- Command: `tsm configuration set -k <service>.log.level -v debug`
- Reset after troubleshooting: `tsm configuration set -k <service>.log.level -v info`
- Always apply changes: `tsm pending-changes apply`

### Site Management
- **Multi-site**: Isolate departments/tenants with separate sites on same server
- **Admin views**: Built-in dashboards showing server performance, user activity, extract status
- **Repository queries**: Direct PostgreSQL queries for custom monitoring (read-only access via `readonly` user)
- **Resource Monitoring Tool**: Optional add-on for detailed server health monitoring
- **Content migration**: Use REST API, `tabcmd`, or Migration SDK for cross-site content movement

---

## Troubleshooting Guides

### Tableau Logs Quick Reference

| Log File | What It Captures | When to Check |
|----------|------------------|---------------|
| `httpd/access.log` | All HTTP requests, response codes | Request routing, 4xx/5xx errors |
| `vizqlserver/*.log` | VizQL query generation, execution | Slow views, rendering errors |
| `backgrounder/*.log` | Scheduled tasks, extract refreshes | Refresh failures, subscription errors |
| `dataserver/*.log` | Data source connections, metadata | Connection failures, permission issues |
| `vizportal/*.log` | Web UI, REST API, authentication | Login failures, API errors |
| `tabprotosrv/*.log` | Protocol-level data source communication | Driver errors, connection timeouts |
| `hyper/*.log` | Extract engine operations | Extract creation/query failures |

### tabprotosrv Diagnostics
- Captures low-level data source protocol communication
- Error codes map directly to connection or authentication anomalies
- Check when: ODBC/JDBC driver errors, SSL handshake failures, connection pool issues
- Contains detailed query text sent to data sources (useful for debugging generated SQL)

### vizportal Diagnostics
- Application server logs for the web interface
- Check when: login failures, permission errors, REST API issues, content management problems
- Contains authentication flow details (SAML, OIDC, Connected Apps)

### Backgrounder Diagnostics
- One log per backgrounder process instance
- Check when: extract refresh failures, subscription delivery failures, flow execution errors
- Contains: start/end times, error messages, data source connection details
- Monitor backgrounder queue depth for capacity planning

---

## Embedding Issues

### Authentication Problems
- **Third-party cookies**: Browsers blocking third-party cookies prevent authentication in embedded iframes
  - Fix: Configure browser to allow cookies from Tableau domain, or use Connected Apps with JWT
- **Token expiration**: JWT tokens expiring during sessions
  - Fix: Set appropriate token lifetime; implement token refresh logic
- **Connected Apps misconfiguration**: Wrong secret, incorrect scope, expired credentials
  - Fix: Verify Connected App configuration; check JWT payload (iss, sub, aud, exp claims)
- **SSO redirect loops**: Identity provider misconfiguration in embedded context
  - Fix: Verify IdP configuration for iframe embedding; consider Connected Apps instead

### Sizing Issues
- **Fixed-size containers**: Embedded viz doesn't resize with container
  - Fix: Use the `resize()` method on Viz/AuthoringViz objects after container size changes
- **Mobile responsiveness**: Embedded content not adapting to mobile screens
  - Fix: Use device-specific layouts in the dashboard; implement responsive container CSS
- **Toolbar overlap**: Tableau toolbar consuming space in small containers
  - Fix: Configure toolbar visibility via Embedding API options; use `toolbar="hidden"` for minimal embedding

### Cross-Origin Issues
- **CORS errors with local library**: Hosting Embedding API library locally causes CORS failures
  - Fix: Use CDN-hosted version: `https://embedding.tableauusercontent.com/tableau.embedding.3.x.min.js`
- **Iframe inspection blocked**: Cannot inspect embedded iframe content across domains (browser security)
  - Fix: Use Embedding API events and methods for programmatic interaction instead of direct DOM access
- **Mixed content**: Embedding HTTPS Tableau in HTTP page (or vice versa) blocked by browsers
  - Fix: Ensure both parent page and Tableau use HTTPS

### Content-Not-Found Errors
- **View URL changes**: Workbook/view renamed on server but embed URL not updated
  - Fix: Use content URL or LUID-based references; implement error handling in embedding code
- **Permission changes**: User no longer has access to embedded content
  - Fix: Verify Connected App scope and user permissions; implement graceful error display
