# SSIS Best Practices

## Package Design Patterns

### Master-Child Package Pattern
- Use a **master package** that calls child packages via **Execute Package Task**
- Master package handles orchestration (sequencing, error handling, logging)
- Child packages are self-contained units of work (one per source system, one per dimension/fact table)
- Benefits: modularity, independent testing, parallel development, reusability
- Pass values between packages using **parent package variables** or **project parameters**

### Configuration and Parameterization
- **Project parameters**: Define at project level for values shared across packages (connection strings, file paths, environment-specific settings)
- **Package parameters**: Define at package level for package-specific settings
- **Environment variables**: Map parameters to environment variables in SSISDB for Dev/QA/Prod promotion
- **Avoid hard-coding**: Never hard-code connection strings, file paths, server names, or credentials in packages
- **Property expressions**: Use expressions on task properties to make them dynamic (e.g., file name with date stamp)

### Naming Conventions
- Prefix tasks with type abbreviation: `SQL_LoadCustomers`, `DFT_TransformOrders`, `FSYS_ArchiveFile`, `SCR_ValidateInput`
- Prefix variables with scope or data type: `User::vFilePath`, `User::vRowCount`
- Name data flow components descriptively: `SRC_ODS_Customers`, `LKP_DimProduct`, `DST_DW_FactSales`
- Annotate packages with descriptions and annotations explaining business logic

### Package Organization
- One data flow per logical operation (avoid monolithic data flows)
- Group related tasks in Sequence Containers
- Use annotations liberally to document business rules and logic
- Keep package complexity manageable -- if a package exceeds ~50 tasks, consider splitting

---

## Data Flow Optimization

### Buffer Sizing
- **DefaultBufferMaxRows**: Default 10,000 rows; increase for narrow row widths to fit more rows per buffer
- **DefaultBufferSize**: Default 10 MB; increase up to ~100 MB for wide rows (maximum allowed is 100 MB when `AutoAdjustBufferSize` is false, or 2 GB with `AutoAdjustBufferSize` set to true in SSIS 2016+)
- **Goal**: Maximize rows per buffer to reduce buffer cycling overhead
- **AutoAdjustBufferSize** (SSIS 2016+): Set to `true` to let SSIS automatically calculate optimal buffer size based on `DefaultBufferMaxRows`
- **Monitoring**: Check `BufferSizeTuning` event in SSIS logs to see if buffer sizes are being auto-adjusted

### Synchronous vs. Asynchronous Transformations
- **Prefer synchronous transformations** (Derived Column, Conditional Split, Data Conversion, Multicast) -- they reuse input buffers and are fastest
- **Minimize fully blocking transformations** (Sort, Aggregate) -- they require all input before producing output and create memory pressure
- **Replace Sort transformations** with ORDER BY in source queries whenever possible
- **Replace Aggregate transformations** with GROUP BY in source queries when feasible
- Semi-blocking transformations (Merge Join, Union All) are acceptable but require sorted inputs for Merge Join

### Lookup Optimization
- **Full cache mode** (default): Loads entire reference table into memory at start; fastest for repeated lookups but requires memory for the full table
- **Partial cache mode**: Caches rows as they are looked up; useful when reference table is too large for memory and lookup hit rate is moderate
- **No cache mode**: Issues a query per row; very slow, avoid unless reference table changes during execution
- **Cache connection manager**: Pre-load lookup data into a cache file (.caw) to share across multiple lookups or packages
- **Index the lookup source table**: Ensure the lookup column(s) are indexed in the source database
- **Select only needed columns**: Only include columns needed from the lookup reference to reduce memory footprint

### Source Query Optimization
- Use SQL queries instead of table/view mode to control exactly which columns and rows are retrieved
- Add WHERE clauses to filter at the source (reduce data volume before SSIS processes it)
- Use NOLOCK hint (or READ UNCOMMITTED) for source reads when dirty reads are acceptable
- Avoid SELECT * -- specify only needed columns
- For incremental loads, use watermark columns (modified date, identity) to extract only changed data

### Destination Optimization
- **Fast Load** (OLE DB Destination): Always use fast load for bulk operations; it uses BULK INSERT internally
- **Rows per batch / Maximum insert commit size**: Control batch sizes for destination inserts
  - `MaxInsertCommitSize = 0`: Single commit at end (fastest but uses most transaction log)
  - `MaxInsertCommitSize = N`: Commit every N rows (balances speed and transaction log usage)
- **Table lock**: Enable `TABLOCK` hint for exclusive lock during load (faster for large loads to empty tables)
- **Drop/rebuild indexes**: For large loads into fact tables, drop non-clustered indexes before load and rebuild after
- **Minimize logging**: Use bulk-logged or simple recovery model during large loads when appropriate

### Parallel Execution
- **MaxConcurrentExecutables**: Controls maximum number of concurrent tasks; default is `-1` (number of processors + 2)
- **EngineThreads**: Controls the number of threads for the data flow engine; default is 10
- Multiple Data Flow Tasks in parallel Sequence Containers can run simultaneously
- Be mindful of source/destination system capacity when running parallel loads

---

## Error Handling Strategy

### Data Flow Error Handling
- **Redirect error rows**: Configure error output on all sources, transformations, and destinations to redirect failed rows
- **Error output destination**: Write error rows to an error table or flat file with ErrorCode, ErrorColumn, and source row data
- **Error lookup**: Use `catalog.execution_component_phases` or a script to map ErrorCode/ErrorColumn to human-readable descriptions
- **Row-level error logging**: Include source system primary key in error output for traceability
- **Threshold-based failure**: Use Row Count transformation to count errors, then fail the package if errors exceed a threshold

### Control Flow Error Handling
- **Precedence constraints**: Use Failure constraints to route to error handling tasks
- **Event handlers**: Define OnError handlers at package level for global error capture
  - Send email notifications on failure
  - Log errors to a custom audit table
  - Execute cleanup/rollback tasks
- **OnTaskFailed vs. OnError**: OnTaskFailed fires once per failed task; OnError fires for every error (can fire multiple times)
- **Package-level OnError**: Catch-all for unhandled errors; log and notify

### Logging Strategy
- **SSISDB catalog logging** (project deployment): Use Performance or Verbose logging levels
- **Custom logging**: Supplement SSISDB with custom audit tables for business-level logging:
  - Package execution start/end times
  - Row counts (extracted, transformed, loaded, rejected)
  - Source file names and sizes
  - Environment-specific identifiers
- **Avoid excessive logging**: Verbose mode generates massive amounts of data; use Performance level for production

---

## Deployment: CI/CD for SSIS

### Source Control
- Store SSIS projects in Git (or TFVC)
- Use `.gitignore` for user-specific files: `*.user`, `*.suo`, `bin/`, `obj/`
- Treat `.dtsx` files as code -- review changes in pull requests (XML diffs can be challenging)

### Build Pipeline (CI)
1. **SSIS Build Task** (Azure DevOps Marketplace -- Microsoft SSIS DevOps Tools extension)
   - Builds `.dtproj` project file
   - Produces `.ispac` artifact
   - Supports both project and package deployment models
2. **Alternative**: Use `devenv.com` or `MSBuild` with SSDT to build from command line
3. **Artifact**: Publish the `.ispac` file as a pipeline artifact

### Release Pipeline (CD)
1. **SSIS Deploy Task** (from SSIS DevOps Tools extension)
   - Deploys `.ispac` to SSISDB catalog on target SQL Server
   - Supports Windows Authentication and SQL Authentication
   - Can deploy to on-premises or Azure-SSIS IR
2. **SSIS Catalog Configuration Task**: Configure folder/project/environment settings using JSON config files
3. **Alternative: PowerShell deployment**:
   ```powershell
   # Load the IntegrationServices assembly
   [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices")
   
   # Connect and deploy
   $connection = New-Object System.Data.SqlClient.SqlConnection "Data Source=.;Initial Catalog=master;Integrated Security=SSPI"
   $integrationServices = New-Object Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices $connection
   $catalog = $integrationServices.Catalogs["SSISDB"]
   $folder = $catalog.Folders["MyFolder"]
   $folder.DeployProject("MyProject", [System.IO.File]::ReadAllBytes("MyProject.ispac"))
   ```
4. **dtutil**: Command-line utility for package deployment (legacy, package deployment model)

### Multi-Environment Promotion
- Use SSISDB **environments** for environment-specific values
- Define environment variables for each environment (Dev, QA, Staging, Prod)
- Create environment references in each deployment target
- Automate environment configuration via SSIS Catalog Configuration Task or PowerShell scripts

---

## Security Best Practices

### Protection Levels
| Level | Behavior | Recommended Use |
|---|---|---|
| DontSaveSensitive | Strips all sensitive values on save | When credentials are supplied at runtime via parameters/environments |
| EncryptSensitiveWithUserKey | Encrypts sensitive data with user's Windows key | Development only -- other users/service accounts cannot decrypt |
| EncryptSensitiveWithPassword | Encrypts sensitive data with a password | Sharing packages between developers; password must be provided at execution |
| EncryptAllWithUserKey | Encrypts entire package with user's key | Development only |
| EncryptAllWithPassword | Encrypts entire package with a password | Rarely used; high overhead |
| ServerStorage | SSISDB handles encryption | Automatic when deploying to SSISDB catalog (recommended for production) |

### Recommended Approach
1. Set protection level to **DontSaveSensitive** during development
2. Use **project/package parameters** for all sensitive values (connection strings, passwords)
3. Map parameters to **SSISDB environment variables** with `Sensitive = true`
4. SSISDB encrypts sensitive values with the database master key (ServerStorage)
5. **Never** commit connection strings with passwords to source control

### Connection String Management
- Use **project-level connection managers** for shared connections
- Parameterize connection strings using **expressions** or **parameter bindings**
- In Azure-SSIS IR, use **managed identity** authentication to eliminate passwords entirely
- For on-premises, use **Windows Authentication** where possible to avoid storing SQL passwords
- Store sensitive configurations in **SSISDB environments** (encrypted) or **Azure Key Vault** (via Script Task or third-party connector)

### Execution Security
- Run packages under dedicated **service accounts** with least-privilege permissions
- Use **SQL Server Agent proxy accounts** rather than the Agent service account
- Grant `ssis_admin` role sparingly; use `ssis_operator` for execution-only access
- Restrict SSISDB folder permissions to appropriate teams/environments

---

## Performance Tuning

### Key Configuration Properties
| Property | Default | Recommendation |
|---|---|---|
| MaxConcurrentExecutables | -1 (CPUs + 2) | Tune based on available CPU cores and I/O capacity |
| DefaultBufferMaxRows | 10,000 | Increase for narrow rows; monitor memory usage |
| DefaultBufferSize | 10 MB | Increase up to 100 MB for wide rows |
| AutoAdjustBufferSize | false | Set to true (SSIS 2016+) to auto-calculate buffer size |
| EngineThreads | 10 | Increase for complex data flows with many execution trees |
| CheckpointUsage | Never | Enable (IfExists or Always) for long-running packages to support restart |

### Network and I/O
- **Network packet size**: Increase from default 4 KB to 32 KB for large data transfers (set on OLE DB connection manager)
- **Collocate**: When possible, run SSIS on the same server or in the same data center as source/destination
- **Minimize data movement**: Filter and aggregate at the source rather than in SSIS

### Memory Management
- Monitor memory usage during execution; if buffers spill to disk (tempdb or temp files), increase available memory or optimize transformations
- Remove unnecessary columns early in the data flow (use Derived Column to remove or Conditional Split to filter)
- Avoid fully blocking transformations (Sort, Aggregate) on large datasets -- push to source query

---

## Testing Approaches

### Manual Validation
- **Data viewers**: Attach to data flow paths during debugging to inspect data in real-time
- **Breakpoints**: Set on control flow tasks to pause execution and inspect variable values
- **Row counts**: Use Row Count transformations and validate against source counts
- **Spot checks**: Compare samples of source and destination data

### Automated Testing
- **ssisUnit**: Open-source framework for unit testing SSIS tasks (GitHub: johnwelch/ssisUnit)
  - Define test suites targeting specific tasks
  - Setup, assert, and teardown phases
  - Validate variable values, row counts, and data content
- **SSISTester (bytesoftwo.com)**: Commercial library for unit and integration testing
  - Data tap: Capture data flowing through pipeline paths
  - Fake source/destination: Eliminate external dependencies
  - Assert on data content, row counts, and execution results
- **Custom test harness**: Execute packages via PowerShell or C# and validate results:
  ```powershell
  # Execute package and check result
  dtexec /ISServer "\SSISDB\Folder\Project\Package.dtsx" /Server "localhost" /Par "ParameterName";"Value"
  # Then query destination tables to validate results
  ```

### Integration Testing
- Deploy to a dedicated test SSISDB catalog
- Run packages against test data sets with known expected outcomes
- Validate row counts, data quality, referential integrity
- Test error handling paths with deliberately invalid data

---

## Migration Patterns

### SSIS to Azure Data Factory (ADF)
1. **Lift-and-shift (Azure-SSIS IR)**: Deploy existing packages to Azure-SSIS IR -- fastest path, no rewrite
2. **Hybrid**: Run existing packages on Azure-SSIS IR while building new pipelines natively in ADF
3. **Native ADF migration**: Rewrite packages as ADF pipelines with Mapping Data Flows
   - ADF Mapping Data Flows use Spark under the hood
   - Different transformation paradigm (visual Spark vs. SSIS pipeline engine)
   - Not a 1:1 translation; requires re-architecture

### SSIS to Microsoft Fabric
1. **Invoke SSIS Package activity** (Preview): Execute existing SSIS packages from Fabric pipelines
2. **Fabric Dataflows Gen2**: Rebuild transformations using Power Query-based Dataflows
3. **Fabric Data Pipelines**: Orchestration equivalent to ADF pipelines
4. **Fabric Notebooks**: For complex transformations, use PySpark notebooks
5. **COPY INTO**: Replace BCP/bulk load with T-SQL `COPY INTO` for high-performance loading into Fabric warehouses

### SSIS to Apache Airflow
- Replace control flow with **Airflow DAGs** (Python)
- Replace data flow transformations with **Python operators**, **SQL operators**, or **Spark jobs**
- Use **Airflow providers** for SQL Server, file systems, cloud storage
- **Incremental migration**: Run Airflow alongside SSIS; migrate package by package
- **Testing**: Airflow supports native pytest-based testing

### SSIS to dbt
- dbt handles **transformations only** (T in ELT); does not handle extraction or loading
- Replace SSIS data flow transformations with **dbt SQL models**
- Pair dbt with **Fivetran/Airbyte** for extraction and loading
- Use **Airflow or Dagster** for orchestration
- Best fit for **ELT** patterns where transformations happen in the database/warehouse
