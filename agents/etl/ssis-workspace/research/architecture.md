# SSIS Architecture

## Overview

SQL Server Integration Services (SSIS) is Microsoft's enterprise ETL (Extract, Transform, Load) platform, shipped as a component of SQL Server. It provides a visual design environment (SSDT / Visual Studio) for building data integration and workflow packages. SSIS has been part of SQL Server since SQL Server 2005 (replacing DTS - Data Transformation Services).

---

## Core Architecture: Two Engines

SSIS architecture centers on two distinct engines that separate concerns:

### 1. Control Flow Engine (Runtime Engine)

The control flow engine manages package execution orchestration. It is responsible for:

- **Task execution ordering** via precedence constraints
- **Container management** (grouping tasks, loops)
- **Variable scoping and evaluation**
- **Event handling** (OnError, OnWarning, OnPreExecute, OnPostExecute, etc.)
- **Logging** to configured log providers
- **Transaction management** across tasks
- **Checkpoint/restart** capability for failed packages

**Control Flow Tasks:**
| Task Category | Tasks |
|---|---|
| Database | Execute SQL Task, Bulk Insert Task, Transfer Database Task, Transfer Logins Task |
| Data Flow | Data Flow Task (bridges to the data flow engine) |
| Scripting | Script Task (C#/VB.NET custom logic) |
| File System | File System Task, FTP Task, XML Task |
| Workflow | Execute Package Task, Execute Process Task, Send Mail Task, Web Service Task, WMI Tasks |
| Maintenance | Back Up Database, Check Database Integrity, Rebuild Index, Shrink Database |
| Analysis Services | Analysis Services Processing Task, Analysis Services Execute DDL Task |
| Expression | Expression Task (evaluate expressions, set variables) |

**Containers:**
| Container | Purpose |
|---|---|
| Sequence Container | Groups tasks for organizational clarity, shared transactions, or shared error handling |
| For Loop Container | Repeats tasks a fixed number of times based on an expression |
| Foreach Loop Container | Iterates over a collection (files in a folder, rows in a dataset, items in a variable, ADO recordset, etc.) |
| Task Host Container | Implicit container wrapping every individual task |

**Precedence Constraints:**
- Link tasks/containers in execution order
- Support three evaluation types: **Success**, **Failure**, **Completion**
- Can include **expressions** for conditional logic (e.g., execute only if variable > threshold)
- Support **AND/OR** logical combinations when multiple constraints converge on a single task

### 2. Data Flow Engine (Pipeline Engine)

The data flow engine handles high-performance, in-memory data movement and transformation. It operates within a Data Flow Task (which is a control flow task that delegates to the pipeline engine).

**Data Flow Pipeline Components:**

| Component Type | Examples |
|---|---|
| Sources | OLE DB Source, ADO.NET Source, Flat File Source, Excel Source, XML Source, Raw File Source, Flexible File Source (Parquet/Avro) |
| Transformations | Derived Column, Conditional Split, Lookup, Merge Join, Union All, Aggregate, Sort, Pivot/Unpivot, Data Conversion, Multicast, Row Count, Script Component, Slowly Changing Dimension, OLE DB Command |
| Destinations | OLE DB Destination, ADO.NET Destination, Flat File Destination, Excel Destination, Raw File Destination, SQL Server Destination, Recordset Destination |

**Buffer Architecture:**

The data flow engine uses an in-memory buffer system for high throughput:

- Data is read from sources into **buffers** (configurable via `DefaultBufferMaxRows` and `DefaultBufferSize`)
- Default buffer: 10,000 rows or 10 MB (whichever is reached first)
- Buffers flow through an **execution tree** -- a path from source (or async output) to the next async transformation or destination
- Each execution tree gets its own set of buffers and an OS thread
- The **buffer manager** allocates, recycles, and decommissions buffers

**Execution Trees:**

An execution tree starts at a source or an asynchronous transformation output and ends at the next asynchronous transformation or a destination. The significance:

- Components within the same execution tree share buffers (synchronous transformations reuse input buffers)
- Asynchronous transformations create new execution trees because they produce new buffers
- Each tree gets a worker thread; threads may be shared across trees

**Transformation Types by Buffer Behavior:**

| Type | Behavior | Examples | Performance Impact |
|---|---|---|---|
| Synchronous (Non-blocking) | Processes row-by-row in the same buffer; output count = input count | Derived Column, Data Conversion, Conditional Split, Multicast | Best -- no new buffers needed |
| Partially Blocking (Semi-blocking) | Requires a subset of rows before producing output; creates new buffers | Merge, Merge Join, Union All | Moderate -- new buffers, but streaming |
| Fully Blocking (Asynchronous) | Must read ALL input rows before producing ANY output; creates new buffers | Sort, Aggregate | Worst -- entire dataset must fit in memory or spills to disk |

---

## Package Structure

An SSIS package (.dtsx file) is the primary unit of work:

```
Package (.dtsx)
├── Connection Managers (data source/destination connections)
├── Variables (user-defined + system variables)
├── Parameters (project or package level, for runtime configuration)
├── Control Flow
│   ├── Tasks (Execute SQL, Script, Data Flow, etc.)
│   ├── Containers (Sequence, For Loop, Foreach Loop)
│   └── Precedence Constraints (execution order + conditions)
├── Data Flow(s)
│   ├── Sources
│   ├── Transformations
│   └── Destinations
├── Event Handlers (OnError, OnWarning, OnPreExecute, etc.)
└── Package Properties (protection level, transaction settings, etc.)
```

---

## Connection Managers

Connection managers encapsulate connection information and are reusable across tasks:

| Connection Manager | Use Case | Notes |
|---|---|---|
| **OLE DB** | Most common for SQL Server, Oracle, Access | Highest performance for SQL Server; supports fast load |
| **ADO.NET** | .NET data providers; required for Always Encrypted | In SSIS 2025, now supports Microsoft.Data.SqlClient (Entra ID, TLS 1.3) |
| **ODBC** | Cross-platform relational database access | Limited to relational databases only |
| **Flat File** | CSV, fixed-width, delimited text files | Supports column definitions, code pages |
| **Excel** | Excel workbooks (.xls, .xlsx) | Uses Jet/ACE provider; 32/64-bit issues common |
| **HTTP** | HTTP endpoints for web services | Used with Web Service Task or XML Source |
| **FTP** | FTP servers | Used with FTP Task |
| **SMTP** | Email servers | Used with Send Mail Task |
| **MSMQ** | Message queues | Used with Message Queue Task |
| **WMI** | Windows Management Instrumentation | Used with WMI tasks |
| **Flexible File** | Azure Blob Storage, ADLS Gen2 | Supports Parquet, Avro, ORC (requires Java for Parquet/ORC) |

**Scope:** Connection managers can be defined at **package level** (available to all tasks in that package) or **project level** (shared across all packages in the project).

---

## Deployment Models

### Project Deployment Model (Recommended -- introduced SQL Server 2012)

- Deploys an entire **project** as a unit (.ispac file containing all packages, parameters, connection managers)
- Deploys to the **SSISDB catalog** on a SQL Server instance
- Supports **parameters** for runtime configuration (replacing legacy configurations)
- Supports **environments** with environment variables for multi-environment deployment (Dev/QA/Prod)
- Automatic **execution logging** captured in SSISDB
- Protection level automatically set to **ServerStorage** upon deployment
- Uses **Managed Object Model** for programmatic administration

### Package Deployment Model (Legacy)

- Deploys individual **packages** (.dtsx files)
- Deploys to file system, MSDB database, or SSIS Package Store
- Uses **configurations** for runtime values (.dtsConfig XML files, SQL Server tables, registry, environment variables, parent package variables)
- Requires manually adding **log providers** to packages for logging
- Protection level must be set per package (EncryptSensitiveWithUserKey, EncryptSensitiveWithPassword, etc.)
- **Deprecated in SSIS 2025** -- the legacy SSIS Service and Package Store are deprecated

---

## SSIS Catalog (SSISDB)

The SSISDB catalog is the central management database for the project deployment model:

### Structure
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

### Capabilities
- **Deployment**: Deploy .ispac project files via SSMS, PowerShell, or T-SQL
- **Parameterization**: Bind parameters to literal values or environment variables at execution time
- **Environments**: Define sets of variables (connection strings, file paths, etc.) per environment (Dev/QA/Prod)
- **Execution**: Execute packages via T-SQL (`catalog.create_execution`, `catalog.start_execution`) or SSMS
- **Logging**: Automatic capture of execution events, messages, data flow statistics, and performance counters
- **Reports**: Built-in SSMS reports -- Integration Services Dashboard, All Executions, All Connections, All Operations, All Validations
- **Security**: Server-level roles for access control; encryption of sensitive data via database master key
- **Versioning**: Retains previous project versions for rollback

### Key Catalog Views
| View | Purpose |
|---|---|
| `catalog.executions` | Execution history with status, start/end times |
| `catalog.event_messages` | Detailed event messages per execution |
| `catalog.executable_statistics` | Performance stats per executable (task) |
| `catalog.execution_data_statistics` | Data flow row counts and timing |
| `catalog.execution_component_phases` | Data flow component timing breakdown |
| `catalog.operation_messages` | Deployment and validation messages |

---

## Azure Integration

### Azure-SSIS Integration Runtime (Azure-SSIS IR)

The Azure-SSIS IR is a fully managed cluster of Azure VMs within Azure Data Factory (ADF) or Synapse Analytics dedicated to running SSIS packages:

- **Lift-and-shift**: Run existing on-premises SSIS packages in the cloud without rewriting
- **Node sizing**: Choose VM size (Standard_D, Standard_E, etc.) to match workload
- **Scaling**: Configure number of nodes (1-10+) for parallel execution
- **SSISDB hosting**: Uses Azure SQL Database or Azure SQL Managed Instance to host the SSISDB catalog
- **Custom setup**: Install additional components, drivers, or assemblies on the IR nodes
- **VNet integration**: Connect to on-premises data sources via VPN/ExpressRoute
- **Cost management**: Start/stop the IR on demand to minimize costs
- **Supports both deployment models**: Project deployment (SSISDB) and package deployment (file system/MSDB on Azure SQL MI)

### Microsoft Fabric Integration (Preview as of 2025-2026)

- **Invoke SSIS Package activity**: Execute SSIS packages from Fabric pipelines (lift-and-shift)
- **SSIS in Fabric**: Currently in private preview; allows existing packages to run in Fabric workspaces
- **Migration path**: Microsoft positions Fabric as the long-term successor, but provides coexistence tooling

---

## Script Task vs. Script Component

| Aspect | Script Task | Script Component |
|---|---|---|
| Location | Control Flow | Data Flow |
| Languages | C# or VB.NET (VSTA editor) | C# or VB.NET (VSTA editor) |
| Execution | Runs once per task execution | Runs once per row (or per buffer) |
| Access | Dts object model (connections, variables, events) | Input/output columns, connection managers |
| Use cases | Custom control logic, file operations, web API calls, variable manipulation | Custom source, transformation, or destination; row-level data processing |
| Result | Must set `Dts.TaskResult` (Success/Failure) | No explicit result; processes rows in data flow |
| Scope | General-purpose custom code | Data pipeline extensibility |

---

## Expression Language and Variables

### Variables
- **User-defined**: Created by developers; scoped to package, container, or task
- **System variables**: Auto-generated (e.g., `System::PackageName`, `System::ExecutionInstanceGUID`, `System::StartTime`, `System::ErrorCode`, `System::ErrorDescription`, `System::TaskName`)
- **Data types**: Boolean, Byte, Char, DateTime, DBNull, Decimal, Double, Int16, Int32, Int64, Object, SByte, Single, String, UInt32, UInt64
- **Object variables**: Can hold ADO.NET DataTable, recordsets for Foreach Loop iteration

### Expression Language
- C-like syntax with operators and functions
- Used in: Precedence constraints, property expressions, Derived Column transformation, Conditional Split, For Loop conditions, variable evaluation
- **Operators**: Arithmetic (+, -, *, /, %), comparison (==, !=, <, >, <=, >=), logical (&&, ||, !), bitwise, string concatenation (+), conditional (?:)
- **Functions**: String (SUBSTRING, UPPER, LOWER, TRIM, LEN, REPLACE, FINDSTRING, REVERSE, TOKEN), date (DATEADD, DATEDIFF, DATEPART, GETDATE, YEAR, MONTH, DAY), type casting ((DT_STR), (DT_WSTR), (DT_I4), (DT_DBTIMESTAMP)), null handling (ISNULL, NULL)

---

## Error Handling

### Error Output Rows (Data Flow)
- Most data flow components support an **error output** path
- When a row causes an error (type conversion, truncation, lookup failure), it can be:
  - **Fail component** (default) -- stops the data flow
  - **Redirect row** -- sends the row to an error output for separate handling
  - **Ignore failure** -- continues processing, potentially with null/default values
- Error output rows include `ErrorCode` and `ErrorColumn` system columns

### Event Handlers (Control Flow)
- Defined at package, container, or task level
- Events: OnError, OnWarning, OnInformation, OnPreExecute, OnPostExecute, OnPreValidate, OnPostValidate, OnProgress, OnTaskFailed, OnVariableValueChanged
- Event handlers can contain their own control flow (tasks, containers, constraints)
- Common pattern: OnError handler sends email notification or logs to custom error table

### Logging Providers
| Provider | Destination |
|---|---|
| SSIS Log Provider for SQL Server | SQL Server table |
| SSIS Log Provider for Text Files | Flat text file |
| SSIS Log Provider for XML Files | XML file |
| SSIS Log Provider for Windows Event Log | Windows Event Log |
| SSIS Log Provider for SQL Server Profiler | .trc trace file |

### SSISDB Logging Levels
| Level | Detail |
|---|---|
| None | No logging |
| Basic | Errors and warnings |
| Performance | Performance statistics and data flow component timing |
| Verbose | All events including custom messages |
| RuntimeLineage | Data lineage tracking information |
