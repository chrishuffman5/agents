# SSIS Best Practices

## Package Design Patterns

### Master-Child Package Pattern

- Use a **master package** that calls child packages via Execute Package Task
- Master handles orchestration: sequencing, error handling, logging, notifications
- Each child is a self-contained unit of work (one per source system, one per dimension/fact table)
- Pass values between packages using project parameters or parent package variables
- Benefits: modularity, independent testing, parallel development, reusability
- Anti-pattern: a single monolithic package that does everything

### Configuration and Parameterization

- **Project parameters**: Define at project level for values shared across packages (connection strings, file paths, environment-specific settings)
- **Package parameters**: Define at package level for package-specific settings
- **Environment variables**: Map parameters to SSISDB environment variables for Dev/QA/Prod promotion
- **Never hard-code**: connection strings, file paths, server names, or credentials in packages
- **Property expressions**: Use expressions on task properties to make them dynamic (e.g., file name with date stamp: `@[User::vOutputFolder] + "\\Export_" + (DT_WSTR,8)GETDATE() + ".csv"`)

### Naming Conventions

| Element | Prefix | Example |
|---|---|---|
| Execute SQL Task | `SQL_` | `SQL_LoadCustomers` |
| Data Flow Task | `DFT_` | `DFT_TransformOrders` |
| File System Task | `FSYS_` | `FSYS_ArchiveFile` |
| Script Task | `SCR_` | `SCR_ValidateInput` |
| Foreach Loop | `FELC_` | `FELC_ProcessFiles` |
| For Loop | `FLC_` | `FLC_RetryLoad` |
| Sequence Container | `SEQ_` | `SEQ_LoadDimensions` |
| Execute Package Task | `EPT_` | `EPT_LoadFactSales` |
| Data flow source | `SRC_` | `SRC_ODS_Customers` |
| Data flow lookup | `LKP_` | `LKP_DimProduct` |
| Data flow destination | `DST_` | `DST_DW_FactSales` |
| Variables | `User::v` | `User::vFilePath`, `User::vRowCount` |

### Package Organization

- One data flow per logical operation -- avoid combining unrelated data movements
- Group related tasks in Sequence Containers for shared error handling or transactions
- Use annotations liberally to document business rules and logic in the designer
- Keep package complexity manageable -- if a package exceeds ~50 tasks, split it
- Place shared connection managers at project level, not package level

## Data Flow Optimization

### Buffer Sizing

| Property | Default | Recommendation |
|---|---|---|
| `DefaultBufferMaxRows` | 10,000 | Increase for narrow rows to maximize rows per buffer |
| `DefaultBufferSize` | 10 MB | Increase up to 100 MB for wide rows (many columns, large strings) |
| `AutoAdjustBufferSize` | false | Set true (2016+) to auto-calculate from row count; allows up to 2 GB buffers |
| `EngineThreads` | 10 | Increase for complex data flows with many execution trees |

**Goal**: Maximize rows per buffer to reduce buffer cycling overhead. Monitor `BufferSizeTuning` event in logs.

### Synchronous vs Asynchronous Transformations

- **Always prefer synchronous** (Derived Column, Conditional Split, Data Conversion, Multicast) -- they reuse input buffers
- **Minimize fully blocking** (Sort, Aggregate) -- they require all input before producing output, creating severe memory pressure
- **Replace Sort with ORDER BY** in the source query; set `IsSorted = true` on the source output
- **Replace Aggregate with GROUP BY** in the source query when feasible
- Semi-blocking (Merge Join, Union All) are acceptable but Merge Join requires sorted inputs

### Lookup Optimization

| Cache Mode | Behavior | When to Use |
|---|---|---|
| Full cache (default) | Loads entire reference table into memory at start | Best for most scenarios; fastest repeated lookups |
| Partial cache | Caches rows as looked up | Reference table too large for memory; moderate hit rate |
| No cache | Issues a query per row | Avoid unless reference table changes during execution |

**Optimization techniques:**
- Add indexes on lookup source columns in the reference database
- Select only needed columns from the lookup reference (reduce memory footprint)
- Use Cache connection manager to pre-load and share lookup data across packages
- For very large references, replace Lookup with Merge Join (requires sorted inputs from both sides)

### Source Query Optimization

- Use SQL queries instead of table/view mode to control exactly which columns and rows are retrieved
- Add WHERE clauses to filter at the source (reduce data before SSIS processes it)
- Use `WITH (NOLOCK)` hint for source reads when dirty reads are acceptable
- Avoid SELECT * -- specify only needed columns
- For incremental loads, use watermark columns (modified date, identity) to extract only changed data
- Use `OPTION (RECOMPILE)` query hint for parameterized queries subject to parameter sniffing

### Destination Optimization

- **Always use Fast Load** (OLE DB Destination) for bulk operations (uses BULK INSERT internally)
- **MaxInsertCommitSize**: `0` = single commit at end (fastest, most transaction log); `N` = commit every N rows (balances speed and log usage)
- **TABLOCK hint**: Enable for exclusive lock during load (faster for large loads to empty tables)
- **Drop/rebuild indexes**: For large fact table loads, drop non-clustered indexes before load, rebuild after
- **Bulk-logged recovery**: Use bulk-logged or simple recovery model during large loads when appropriate

### Parallel Execution

- **MaxConcurrentExecutables**: Controls maximum concurrent tasks; default `-1` (processors + 2)
- Multiple Data Flow Tasks in parallel Sequence Containers run simultaneously
- Be mindful of source/destination system capacity when running parallel loads
- Stagger high-memory data flows to avoid memory exhaustion

## Error Handling Strategy

### Data Flow Error Handling

1. **Redirect error rows**: Configure error output on all sources, transformations, and destinations
2. **Error destination**: Write error rows to an error table or flat file with ErrorCode, ErrorColumn, and source row data
3. **Error lookup**: Map ErrorCode/ErrorColumn to human-readable descriptions using `catalog.execution_component_phases` or a script
4. **Include primary keys**: Include source system primary key in error output for traceability
5. **Threshold-based failure**: Use Row Count transformation to count errors; fail the package if errors exceed a threshold

### Control Flow Error Handling

- **Failure precedence constraints**: Route to error handling tasks on failure
- **OnError event handler** at package level: catch-all for unhandled errors
  - Send email notification on failure
  - Log to custom audit table
  - Execute cleanup/rollback
- **OnTaskFailed vs OnError**: OnTaskFailed fires once per failed task; OnError fires for every error (can fire multiple times)
- Use Failure constraints to continue the workflow after handling the error

### Logging Strategy

- **SSISDB catalog logging** (project deployment): Use Performance level for production; Verbose only for targeted debugging
- **Custom audit logging**: Supplement SSISDB with custom tables for business-level tracking:
  - Package execution start/end times
  - Row counts (extracted, transformed, loaded, rejected)
  - Source file names and sizes
  - Environment-specific identifiers
- **Avoid Verbose in production**: Generates massive log volume; use Performance level which captures data flow statistics

## CI/CD Deployment

### Source Control

- Store SSIS projects in Git (or TFVC)
- `.gitignore` for user-specific files: `*.user`, `*.suo`, `bin/`, `obj/`
- Treat `.dtsx` files as code -- review changes in pull requests (XML diffs can be challenging but are necessary)
- Use DontSaveSensitive protection level so no credentials appear in source control

### Build Pipeline (CI)

1. **SSIS Build Task** (Azure DevOps -- Microsoft SSIS DevOps Tools extension)
   - Builds `.dtproj` project file
   - Produces `.ispac` artifact
2. **Alternative**: Use `devenv.com` or `MSBuild` with SSDT for command-line builds
3. **Artifact**: Publish the `.ispac` file as a pipeline artifact

### Release Pipeline (CD)

1. **SSIS Deploy Task** (SSIS DevOps Tools extension)
   - Deploys `.ispac` to SSISDB catalog
   - Supports Windows and SQL Authentication
   - Can deploy to on-premises or Azure-SSIS IR
2. **SSIS Catalog Configuration Task**: Configure folder/project/environment settings from JSON config files
3. **PowerShell deployment** (alternative):
   ```powershell
   [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices")
   $conn = New-Object System.Data.SqlClient.SqlConnection "Data Source=.;Initial Catalog=master;Integrated Security=SSPI"
   $ssis = New-Object Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices $conn
   $catalog = $ssis.Catalogs["SSISDB"]
   $folder = $catalog.Folders["MyFolder"]
   $folder.DeployProject("MyProject", [System.IO.File]::ReadAllBytes("MyProject.ispac"))
   ```
4. **dtutil**: Legacy command-line utility for package deployment model (not recommended for new work)

### Multi-Environment Promotion

- Define SSISDB **environments** per target (Dev, QA, Staging, Prod)
- Create environment variables for connection strings, file paths, credentials (mark sensitive values as `Sensitive = true`)
- Create environment references linking projects to environments
- Automate configuration via SSIS Catalog Configuration Task or PowerShell scripts
- Deploy the same .ispac to all environments; only environment variable values differ

## Security Best Practices

### Protection Levels

| Level | Behavior | Use Case |
|---|---|---|
| DontSaveSensitive | Strips all sensitive values on save | Development -- credentials supplied at runtime via parameters |
| EncryptSensitiveWithUserKey | Encrypts with user's Windows key | Development only -- other users cannot decrypt |
| EncryptSensitiveWithPassword | Encrypts with a password | Sharing between developers; password required at execution |
| EncryptAllWithUserKey | Encrypts entire package | Development only |
| EncryptAllWithPassword | Encrypts entire package | Rarely used; high overhead |
| ServerStorage | SSISDB handles encryption | Automatic on deployment to SSISDB (recommended for production) |

### Recommended Security Flow

1. Set protection level to **DontSaveSensitive** during development
2. Use **project/package parameters** for all sensitive values
3. Map parameters to **SSISDB environment variables** with `Sensitive = true`
4. SSISDB encrypts sensitive values with the database master key (ServerStorage)
5. **Never** commit passwords or connection strings to source control

### Connection String Management

- Use **project-level connection managers** for shared connections
- Parameterize connection strings using expressions or parameter bindings
- In Azure-SSIS IR, use **managed identity** to eliminate passwords
- On-premises: prefer **Windows Authentication** to avoid SQL passwords
- Store secrets in **SSISDB environments** (encrypted) or **Azure Key Vault** (via Script Task or third-party connector)

### Execution Security

- Run packages under dedicated **service accounts** with least-privilege permissions
- Use **SQL Server Agent proxy accounts** rather than the Agent service account
- Grant `ssis_admin` sparingly; use `ssis_operator` for execution-only access
- Restrict SSISDB folder permissions to appropriate teams/environments

## Performance Tuning Reference

### Key Configuration Properties

| Property | Default | Recommendation |
|---|---|---|
| MaxConcurrentExecutables | -1 (CPUs + 2) | Tune based on available CPU cores and I/O capacity |
| DefaultBufferMaxRows | 10,000 | Increase for narrow rows; monitor memory |
| DefaultBufferSize | 10 MB | Increase up to 100 MB for wide rows |
| AutoAdjustBufferSize | false | Set true (2016+) for auto-calculation |
| EngineThreads | 10 | Increase for complex data flows with many execution trees |
| CheckpointUsage | Never | Enable (IfExists or Always) for long-running packages |

### Network and I/O

- **Network packet size**: Increase from 4 KB to 32 KB on OLE DB connection manager for large transfers
- **Collocate**: Run SSIS on the same server or data center as source/destination
- **Minimize data movement**: Filter and aggregate at the source, not in SSIS

### Memory Management

- Monitor for buffer spills to disk (tempdb or temp files); increase memory or optimize transformations
- Remove unnecessary columns early in the data flow
- Avoid fully blocking transformations on large datasets
- Stagger concurrent data flows if memory is constrained

## Testing Approaches

### Manual Validation

- **Data viewers**: Attach to data flow paths to inspect data in real-time during debug execution
- **Breakpoints**: Set on control flow tasks to pause and inspect variable values
- **Row counts**: Use Row Count transformations and validate against source
- **Progress tab**: Real-time execution progress in SSDT showing task timing

### Automated Testing

- **ssisUnit** (open-source, GitHub: johnwelch/ssisUnit): Unit testing framework for SSIS tasks with setup/assert/teardown phases
- **SSISTester** (commercial, bytesoftwo.com): Data tap, fake source/destination, assertion on data and execution results
- **Custom harness**: Execute packages via PowerShell or C# and validate results:
  ```
  dtexec /ISServer "\SSISDB\Folder\Project\Package.dtsx" /Server "localhost" /Par "ParamName";"Value"
  ```

### Integration Testing

- Deploy to a dedicated test SSISDB catalog
- Run against test data sets with known expected outcomes
- Validate row counts, data quality, referential integrity
- Test error handling paths with deliberately invalid data

## Migration Patterns

### SSIS to Azure Data Factory (ADF)

| Approach | Effort | Description |
|---|---|---|
| **Lift-and-shift** (Azure-SSIS IR) | Low | Deploy existing packages to Azure-SSIS IR -- no rewrite |
| **Hybrid** | Medium | Run existing packages on IR while building new pipelines natively in ADF |
| **Native ADF rewrite** | High | Rewrite as ADF pipelines with Mapping Data Flows (Spark-based) |

Native ADF migration is not a 1:1 translation. ADF Mapping Data Flows use Spark under the hood with a different transformation paradigm.

### SSIS to Microsoft Fabric

1. **Invoke SSIS Package activity** (preview): Execute existing packages from Fabric pipelines
2. **Fabric Dataflows Gen2**: Rebuild transformations using Power Query-based Dataflows
3. **Fabric Data Pipelines**: Orchestration equivalent to ADF pipelines
4. **Fabric Notebooks**: PySpark notebooks for complex transformations
5. **COPY INTO**: Replace bulk load with T-SQL COPY INTO for Fabric warehouse loading

### SSIS to Apache Airflow

- Replace control flow with **Airflow DAGs** (Python)
- Replace data flow with **Python operators**, **SQL operators**, or **Spark jobs**
- Use **Airflow providers** for SQL Server, file systems, cloud storage
- Migrate incrementally: run Airflow alongside SSIS, migrate package by package
- Airflow supports native pytest-based testing

### SSIS to dbt

- dbt handles **transformations only** (T in ELT); does not extract or load
- Replace data flow transformations with **dbt SQL models**
- Pair dbt with **Fivetran/Airbyte** for extraction and loading
- Use **Airflow or Dagster** for orchestration
- Best fit for ELT patterns where transformations happen in the database/warehouse

### Migration Prioritization

1. **Immediate**: Packages using removed components (Attunity CDC, Oracle connector, Hadoop tasks in 2025)
2. **High priority**: Packages using deprecated features (32-bit providers, legacy SSIS Service, package deployment model)
3. **Medium priority**: Packages that would benefit from cloud scalability or serverless execution
4. **Low priority**: Stable on-premises packages with no deprecated dependencies
