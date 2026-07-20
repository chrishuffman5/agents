# SSIS Architecture

## Two-Engine Design

SSIS architecture centers on two distinct engines that separate workflow orchestration from data movement.

### Control Flow Engine (Runtime Engine)

The control flow engine manages package execution orchestration:

- **Task execution ordering** via precedence constraints (Success, Failure, Completion)
- **Container management** for grouping, looping, and iteration
- **Variable scoping** at package, container, or task level
- **Event handling** (OnError, OnWarning, OnPreExecute, OnPostExecute, OnTaskFailed, etc.)
- **Logging** to configured log providers
- **Transaction management** across tasks (supports MSDTC distributed transactions)
- **Checkpoint/restart** for resuming failed packages from the last successful task

#### Control Flow Tasks

| Category | Tasks |
|---|---|
| Database | Execute SQL Task, Bulk Insert Task, Transfer Database Task, Transfer Logins Task |
| Data Flow | Data Flow Task (bridges to pipeline engine) |
| Scripting | Script Task (C#/VB.NET custom logic) |
| File System | File System Task, FTP Task, XML Task |
| Workflow | Execute Package Task, Execute Process Task, Send Mail Task, Web Service Task, WMI Tasks |
| Maintenance | Back Up Database, Check Database Integrity, Rebuild Index, Shrink Database |
| Analysis Services | AS Processing Task, AS Execute DDL Task |
| Expression | Expression Task (evaluate expressions, set variables) |

#### Containers

| Container | Purpose |
|---|---|
| Sequence Container | Groups tasks for organizational clarity, shared transactions, or shared error handling |
| For Loop Container | Repeats tasks based on an initialization, evaluation, and assignment expression |
| Foreach Loop Container | Iterates over a collection (files in a folder, rows in a dataset, ADO recordset, items in a variable, etc.) |
| Task Host Container | Implicit container wrapping every individual task |

#### Precedence Constraints

- Link tasks and containers in execution order
- Three evaluation types: **Success**, **Failure**, **Completion** (regardless of success/failure)
- Can include **expressions** for conditional logic (e.g., execute only if `@[User::vRowCount] > 0`)
- Support **AND/OR** logical combinations when multiple constraints converge on a single task
- Expression + constraint: both the constraint result and expression must be true

### Data Flow Engine (Pipeline Engine)

The data flow engine handles high-performance, in-memory data movement and transformation. It operates within a Data Flow Task.

#### Data Flow Components

| Type | Examples |
|---|---|
| Sources | OLE DB Source, ADO.NET Source, Flat File Source, Excel Source, XML Source, Raw File Source, Flexible File Source (Parquet/Avro/ORC, 2019+) |
| Transformations | Derived Column, Conditional Split, Lookup, Merge Join, Union All, Aggregate, Sort, Pivot/Unpivot, Data Conversion, Multicast, Row Count, Script Component, Slowly Changing Dimension, OLE DB Command |
| Destinations | OLE DB Destination, ADO.NET Destination, Flat File Destination, Excel Destination, Raw File Destination, SQL Server Destination, Recordset Destination |

## Buffer Management

The data flow engine uses an in-memory buffer system for high throughput.

### Buffer Basics

- Data is read from sources into **buffers** (in-memory row sets)
- Default buffer: **10,000 rows** or **10 MB** (whichever limit is reached first)
- Configurable via `DefaultBufferMaxRows` and `DefaultBufferSize` on the Data Flow Task
- `AutoAdjustBufferSize` (2016+): when true, SSIS calculates optimal buffer size from `DefaultBufferMaxRows`, allowing buffers up to 2 GB
- The **buffer manager** allocates, recycles, and decommissions buffers as data flows through the pipeline

### Buffer Sizing Strategy

| Scenario | Adjustment |
|---|---|
| Narrow rows (few small columns) | Increase `DefaultBufferMaxRows` to fit more rows per buffer |
| Wide rows (many columns or large strings/BLOBs) | Increase `DefaultBufferSize` up to 100 MB (or enable `AutoAdjustBufferSize`) |
| Memory pressure / disk spills | Reduce buffer sizes or reduce concurrent data flows |
| High-throughput streaming | Enable `AutoAdjustBufferSize = true` with large `DefaultBufferMaxRows` |

### Monitoring Buffers

- Check `BufferSizeTuning` event in SSIS logs to see buffer allocation decisions
- Monitor Windows performance counters: `SSIS Pipeline > Buffers in use`, `Buffers spooled`, `Flat buffers in use`
- If `Buffers spooled` is non-zero, buffers are spilling to disk (performance degradation)

## Execution Trees

An execution tree defines a path through the data flow pipeline from a source (or asynchronous transformation output) to the next asynchronous transformation or destination.

### How Execution Trees Form

1. The pipeline engine analyzes the data flow layout
2. It identifies boundaries at sources, fully blocking (asynchronous) transformations, and destinations
3. Each segment between boundaries becomes an execution tree
4. Synchronous transformations are absorbed into the tree of their input source

### Thread Model

- Each execution tree receives at least one worker thread
- Threads may be shared across execution trees when there are more trees than available threads
- The `EngineThreads` property (default 10) controls the thread pool size
- More execution trees = more parallelism, but also more memory (separate buffer sets per tree)

### Performance Implications

| Transformation Type | Buffer Behavior | Execution Tree Impact |
|---|---|---|
| **Synchronous** (Derived Column, Conditional Split, Data Conversion, Multicast) | Reuses input buffer in-place | Stays in same tree -- best performance |
| **Semi-blocking** (Merge, Merge Join, Union All) | Creates new output buffers but streams | Creates new tree -- moderate overhead |
| **Fully blocking** (Sort, Aggregate) | Must consume ALL input before producing ANY output | Creates new tree -- worst performance; entire dataset buffered in memory or spills to disk |

### Design Guidelines

- Minimize the number of execution trees by preferring synchronous transformations
- Each fully blocking transformation adds a tree boundary, creating memory pressure
- Replace Sort with ORDER BY at the source; replace Aggregate with GROUP BY at the source
- For Merge Join, sort at the source and set `IsSorted = true` on the output to avoid an SSIS Sort

## Connection Managers

Connection managers encapsulate connection information and are reusable across tasks.

### Connection Manager Types

| Manager | Use Case | Notes |
|---|---|---|
| **OLE DB** | SQL Server, Oracle, Access | Highest performance for SQL Server; supports fast load (BULK INSERT) |
| **ADO.NET** | .NET data providers | Required for Always Encrypted; supports Microsoft.Data.SqlClient in 2025 (Entra ID, TLS 1.3) |
| **ODBC** | Cross-platform relational access | Limited to relational databases |
| **Flat File** | CSV, fixed-width, delimited text | Supports column definitions, code pages, text qualifiers |
| **Excel** | .xls, .xlsx workbooks | Uses Jet/ACE provider; notorious 32/64-bit issues |
| **HTTP** | HTTP endpoints | Used with Web Service Task or XML Source |
| **FTP** | FTP servers | Used with FTP Task |
| **SMTP** | Email servers | Used with Send Mail Task |
| **Flexible File** | Azure Blob Storage, ADLS Gen2 | 2019+; supports Parquet, Avro, ORC (Java required for Parquet/ORC) |

### Scope

- **Package-level**: Available to all tasks within the package
- **Project-level**: Shared across all packages in the project (project deployment model)
- Project-level connection managers reduce duplication and centralize connection string management

### OLE DB vs ADO.NET vs ODBC

| Factor | OLE DB | ADO.NET | ODBC |
|---|---|---|---|
| SQL Server performance | Best (native fast load) | Good (SqlBulkCopy) | Good |
| Always Encrypted | No | Yes | No |
| Entra ID (2025) | No | Yes (Microsoft.Data.SqlClient) | No |
| Non-SQL Server databases | Oracle, Access via providers | Any .NET provider | Any ODBC driver |
| Recommended for | SQL Server source/destination | Encrypted columns, Entra ID auth | Cross-platform, non-Microsoft |

## Expression Language

SSIS expressions use a C-like syntax for dynamic property values, conditional logic, and data transformation.

### Where Expressions Are Used

- **Property expressions**: Make any task/component property dynamic (e.g., file path with date stamp)
- **Precedence constraints**: Conditional execution based on variable values
- **Derived Column transformation**: Create or modify columns in data flow
- **Conditional Split transformation**: Route rows to different outputs based on conditions
- **For Loop Container**: Initialization, evaluation, and assignment expressions
- **Variable evaluation**: Variables with `EvaluateAsExpression = true`

### Operators

| Category | Operators |
|---|---|
| Arithmetic | `+`, `-`, `*`, `/`, `%` |
| Comparison | `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Logical | `&&`, `||`, `!` |
| Conditional | `? :` (ternary) |
| String | `+` (concatenation) |
| Bitwise | `&`, `|`, `^`, `~` |

### Key Functions

| Category | Functions |
|---|---|
| String | `SUBSTRING`, `UPPER`, `LOWER`, `TRIM`, `LTRIM`, `RTRIM`, `LEN`, `REPLACE`, `FINDSTRING`, `REVERSE`, `TOKEN` |
| Date/Time | `DATEADD`, `DATEDIFF`, `DATEPART`, `GETDATE`, `GETUTCDATE`, `YEAR`, `MONTH`, `DAY` |
| Type Casting | `(DT_STR,length,codepage)`, `(DT_WSTR,length)`, `(DT_I4)`, `(DT_DBTIMESTAMP)`, `(DT_DECIMAL,scale)` |
| Null Handling | `ISNULL(expr)`, `NULL(type)` |
| Math | `ABS`, `CEILING`, `FLOOR`, `ROUND`, `POWER`, `SQRT`, `SIGN` |

### Common Expression Patterns

```
-- Dynamic file path with date stamp
@[User::vOutputFolder] + "\\Export_" + (DT_WSTR,4)YEAR(GETDATE()) + RIGHT("0" + (DT_WSTR,2)MONTH(GETDATE()),2) + RIGHT("0" + (DT_WSTR,2)DAY(GETDATE()),2) + ".csv"

-- Conditional value assignment
@[User::vRowCount] > 0 ? "Data found" : "No data"

-- Null-safe string concatenation
ISNULL(FirstName) ? "" : FirstName + " " + (ISNULL(LastName) ? "" : LastName)

-- Date arithmetic
DATEADD("dd", -7, GETDATE())
```

## Script Task vs Script Component

| Aspect | Script Task | Script Component |
|---|---|---|
| Location | Control Flow | Data Flow |
| Languages | C# or VB.NET (VSTA editor) | C# or VB.NET (VSTA editor) |
| Execution | Runs once per task execution | Runs per row (or per buffer) |
| Access | `Dts` object model (connections, variables, events) | Input/output columns, connection managers |
| Use Cases | Custom control logic, file operations, API calls, variable manipulation | Custom source, transformation, or destination |
| Result | Must set `Dts.TaskResult` (Success/Failure) | No explicit result; processes rows |
| Scope | General-purpose custom code | Data pipeline extensibility |

### Script Task Best Practices

- Reference external assemblies via GAC or project references
- Use `Dts.Events.FireInformation()` and `Dts.Events.FireError()` for logging
- Always set `Dts.TaskResult` in all code paths
- Use try/catch with `Dts.Events.FireError()` for proper error propagation
- Access variables via `Dts.Variables["User::vMyVar"].Value`

### Script Component Best Practices

- Define input/output columns on the Inputs and Outputs page before writing code
- For transformation: override `Input0_ProcessInputRow(Input0Buffer row)` 
- For source: override `CreateNewOutputRows()` and call `Output0Buffer.AddRow()`
- For destination: override `Input0_ProcessInputRow()` and write to external system
- Keep processing logic minimal per row; complex logic degrades throughput

## Error Handling

### Data Flow Error Outputs

Most data flow components support an **error output** path with three options per column:

| Option | Behavior |
|---|---|
| Fail Component | Stops the data flow (default) |
| Redirect Row | Sends the row to an error output path for separate handling |
| Ignore Failure | Continues processing with null/default values |

Error output rows include `ErrorCode` (integer) and `ErrorColumn` (column lineage ID) system columns.

### Control Flow Event Handlers

Event handlers are defined at package, container, or task level:

| Event | Fires When |
|---|---|
| OnError | An error occurs (can fire multiple times per task) |
| OnWarning | A warning is raised |
| OnInformation | An informational message is raised |
| OnPreExecute | Before a task begins execution |
| OnPostExecute | After a task completes execution |
| OnTaskFailed | A task fails (fires once per failed task) |
| OnVariableValueChanged | A variable value changes |
| OnProgress | Progress updates during execution |

Event handlers can contain their own control flow (tasks, containers, constraints). Common pattern: OnError sends email and logs to a custom error audit table.

### Logging Providers

| Provider | Destination |
|---|---|
| SQL Server | SQL Server table (sysssislog) |
| Text Files | Flat text file |
| XML Files | XML file |
| Windows Event Log | Windows Event Log |
| SQL Server Profiler | .trc trace file |

### SSISDB Logging Levels

| Level | Detail |
|---|---|
| None | No logging |
| Basic | Errors and warnings (production default) |
| Performance | Adds data flow statistics and component timing |
| Verbose | All events including custom messages |
| RuntimeLineage | Data lineage tracking |

## Deployment Models

### Project Deployment Model (Recommended)

- Deploys entire project as .ispac file (all packages, parameters, connection managers)
- Target: SSISDB catalog on SQL Server
- Supports **parameters** for runtime configuration
- Supports **environments** with variables for Dev/QA/Prod promotion
- Automatic execution logging in SSISDB
- Protection level automatically set to ServerStorage upon deployment
- Supports project versioning for rollback

### Package Deployment Model (Legacy)

- Deploys individual .dtsx files
- Target: file system, MSDB database, or SSIS Package Store
- Uses configurations (.dtsConfig XML, SQL Server tables, registry, environment variables)
- Manual log provider configuration per package
- Protection level set per package
- **Deprecated in SSIS 2025**: legacy SSIS Service and Package Store are deprecated

## SSISDB Catalog Structure

```
SSISDB
├── Folders
│   ├── Projects
│   │   ├── Packages
│   │   └── Project Parameters
│   ├── Environments
│   │   └── Environment Variables
│   └── Environment References (link projects to environments)
```

### Key Catalog Views

| View | Purpose |
|---|---|
| `catalog.executions` | Execution history with status, start/end times |
| `catalog.event_messages` | Detailed event messages per execution |
| `catalog.executable_statistics` | Performance stats per task |
| `catalog.execution_data_statistics` | Data flow row counts and timing |
| `catalog.execution_component_phases` | Data flow component timing breakdown |
| `catalog.operation_messages` | Deployment and validation messages |

## Azure Integration

### Azure-SSIS Integration Runtime

A fully managed cluster of Azure VMs in Azure Data Factory for running SSIS packages:

- **Lift-and-shift**: Existing on-premises packages run without rewriting
- **SSISDB hosting**: Azure SQL Database or Azure SQL Managed Instance
- **Node sizing**: Standard_D, Standard_E series (match to workload)
- **Scaling**: 1-10+ nodes for parallel execution
- **Custom setup**: Install components, drivers, assemblies via setup scripts
- **VNet integration**: Access on-premises data via VPN/ExpressRoute
- **Cost management**: Start/stop on schedule; ~20-30 minute cold start
- **Supports both deployment models**: Project (SSISDB) and package (file system/MSDB on Azure SQL MI)

### Microsoft Fabric Integration

- **Invoke SSIS Package activity** (preview): Execute SSIS packages from Fabric pipelines
- **SSIS in Fabric**: Private preview; allows packages to run in Fabric workspaces
- **Migration path**: Microsoft positions Fabric as long-term successor with coexistence tooling
