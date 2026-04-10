# Talend Architecture Deep Dive

## Platform Overview

Talend is an enterprise data integration platform built on Eclipse RCP and Java, now part of the Qlik ecosystem following the May 2023 acquisition. The platform generates native Java code from visual job designs, enabling high-performance ETL/ELT processing across on-premises, cloud, and hybrid environments. The current major version is Talend 8.0 with monthly cumulative patches (R2026-xx format).

## Talend Studio

Talend Studio is the primary development environment, built on the Eclipse Rich Client Platform (RCP).

### Core Capabilities

- **Visual Job Designer**: Drag-and-drop canvas for designing data integration workflows
- **Code Generation Engine**: Converts visual job designs into executable Java code
- **Eclipse-Based IDE**: Full Java IDE capabilities including code editing, debugging, and syntax highlighting
- **Palette**: Categorized library of 1,000+ pre-built components for connectors, transformations, orchestration, and quality
- **Repository Browser**: Centralized navigation for all project artifacts (jobs, metadata, routines, contexts)
- **Perspective Views**: Design, Debug, Profiling, and Integration perspectives for different development tasks
- **Java 17 Requirement**: As of R2025-02, all artifacts must be built and executed using Java 17. Java 8 support has ended.

### Code Generation

Jobs are stored internally as XML but generate executable Java code. Each job compiles to a self-contained JAR file with all dependencies. This approach means:
- Jobs execute as standard Java applications (no special runtime needed beyond JVM)
- Performance characteristics are those of compiled Java (not interpreted)
- Generated code can be inspected (right-click job > Edit Code) for debugging
- External Java libraries integrate directly as routine dependencies

## Job Architecture

### Job Types

| Type | Purpose | Runtime |
|---|---|---|
| **Standard DI Jobs** | Traditional batch ETL for data extraction, transformation, loading | Java on any JVM |
| **Big Data Batch Jobs** | Spark-based batch processing on Hadoop/cloud clusters | Spark cluster |
| **Big Data Streaming Jobs** | Real-time data processing using Spark Streaming | Spark Streaming |
| **Route Jobs (ESB)** | Mediation routes for Enterprise Service Bus (Apache Camel) | Talend Runtime (OSGi) |
| **Service Jobs (ESB)** | RESTful or SOAP web service implementations (Apache CXF) | Talend Runtime (OSGi) |
| **Joblets** | Reusable sub-job fragments shared across multiple jobs | Embedded in consuming job |

### Job Lifecycle

1. **Design**: Visual component placement and configuration in Studio
2. **Code Generation**: Studio generates Java source code from the visual design
3. **Compilation**: Java compiler produces bytecode (JAR)
4. **Testing**: Debug perspective with breakpoints, data inspection, and step execution
5. **Build**: Maven build with Talend CI Builder Plugin produces deployable artifact
6. **Deployment**: Artifact published to Nexus/Artifactory and deployed to Remote Engine via TMC
7. **Execution**: TMC schedules and monitors execution on the target engine
8. **Monitoring**: TMC dashboards, tStatCatcher statistics, and log analysis

### Parent/Child Job Pattern

Jobs support hierarchical orchestration via the tRunJob component:
- Parent job orchestrates child jobs with control flow (OnSubjobOk, OnSubjobError)
- Data passes between parent and child via context variables (not data flows)
- Recommended maximum nesting: 3 levels (deeper nesting increases memory and complexity)
- Each child job should have a clear, single responsibility

### Job Entry and Exit Points

- **tPreJob**: Initializes connections, validates prerequisites, logs start time. Runs before the main job logic.
- **tPostJob**: Closes connections, cleans temp files, logs completion metrics. Runs after the main job logic regardless of success or failure.
- **tWarn**: Generates a warning that continues execution. Caught by tLogCatcher.
- **tDie**: Generates an error and terminates the job. Caught by tLogCatcher.

## Component Architecture

### Component Categories and Key Components

**Connectivity** (databases, files, cloud, messaging, API):
- Database: tMysqlInput/Output, tOracleInput/Output, tPostgresqlInput/Output, tSnowflakeInput/Output, tBigQueryOutput
- File: tFileInputDelimited, tFileOutputDelimited, tFileInputExcel, tFileOutputExcel
- Cloud: tS3Connection, tAzureBlobInput, tGoogleStorageGet
- Messaging: tKafkaInput/Output, tJMSInput/Output
- API: tRESTClient, tSOAP, tHTTPRequest

**Processing/Transformation**:
- **tMap**: Primary transformation engine -- lookups, filtering, expressions, multi-output routing
- tJoin, tUnite: Set operations
- tNormalize, tDenormalize: Structure changes
- tAggregate: Grouping and aggregation
- tSort: In-memory sorting
- tUniqRow: Deduplication
- tFilterRow, tFilterColumns: Row and column filtering
- tReplicate: Duplicate flow to multiple outputs

**Orchestration**:
- tRunJob: Invoke child jobs
- tParallelize: Execute independent subjobs concurrently
- tLoop: Iterative execution
- tIterateToFlow: Convert iteration context to data flow
- tPreJob/tPostJob: Job initialization and cleanup

**Bulk Operations**:
- tBulkExec, tMysqlBulkExec, tPostgresqlBulkExec, tOracleBulkExec: High-performance batch loading (50%+ write improvement over row-by-row)

**Error Handling**:
- tLogRow: Console output (development only)
- tLogCatcher: Catches all warnings, errors, and Java exceptions across the job
- tStatCatcher: Captures per-component execution statistics
- tWarn: Non-fatal warning generation
- tDie: Fatal error and job termination
- tFlowToIterate: Convert data flow to iteration for error processing loops

### Connection Types

Components connect via two types:
- **Row connections**: Main data flow, reject flow, lookup flow
- **Trigger connections**: OnSubjobOk, OnSubjobError, OnComponentOk, OnComponentError, Run If

### Custom Components

The Talend Component Kit (TCK) SDK enables building custom components:
- Java-based component development
- Integration with the Studio palette
- Publishing to Talend Cloud component repository
- Support for custom processors, sources, and sinks

## tMap Deep Dive

tMap is the central transformation engine with capabilities spanning:

### Lookup Modes

| Mode | Memory | When to Use |
|---|---|---|
| **Load All** | Loads entire lookup table into memory | Small reference tables (< 100K rows typical) |
| **Reload at Each Row** | Re-queries per row | Dynamic lookup data that changes between rows |
| **Flow to Stream** | Streams lookup data | Large lookups that do not fit in memory |

### Join Configuration

- **Inner Join**: Only matched records pass through (unmatched dropped or routed to reject)
- **Left Outer Join**: All main flow records pass; unmatched lookups produce nulls
- **Die on error vs reject**: Die terminates job on lookup failure; reject routes unmatched to reject flow

### Expression Capabilities

- Java-based expressions in each output column
- String functions: `StringHandling.UPCASE()`, `StringHandling.TRIM()`
- Date functions: `TalendDate.parseDate()`, `TalendDate.formatDate()`
- Null checks: `row.field == null ? defaultValue : row.field`
- Conditional logic: standard Java ternary and if/else
- Access to custom routines: `MyRoutine.myMethod(row.field)`

## Routines

Routines are reusable Java code libraries accessible across all jobs in a project.

### Types

- **System Routines**: Pre-built utility functions -- StringHandling, Numeric, TalendDate, TalendString, Relational
- **User Routines**: Custom Java classes for project-specific logic
- **Custom Routine JARs**: External Java libraries imported as routine dependencies

### Design Guidelines

- Routines should be stateless and thread-safe
- Include Javadoc comments for all public methods
- Test independently before deploying to production jobs
- Complex expression logic in tMap cells should be extracted to routines (compiled once, not generated inline per-row)

## Metadata

Metadata provides centralized, reusable definitions for data connections, schemas, and structures.

### Metadata Types

- **Database Connections**: Connection parameters with schema retrieval
- **File Connections**: Delimited, positional, Excel, XML, JSON structure definitions
- **Generic Schemas**: Reusable column definitions independent of connection
- **Context Groups**: Environment-specific variable sets (DEV, QA, PROD)
- **Hadoop Connections**: HDFS, Hive, HBase cluster configurations
- **SaaS Connections**: Salesforce, SAP, Marketo

### Benefits

- Change a metadata definition once and propagate to all referencing jobs
- Schema evolution management with impact analysis
- Connection parameter centralization reduces configuration errors

## Talend Management Console (TMC)

### Core Capabilities

- **Task Management**: Create, schedule, manage executable tasks from deployed artifacts
- **Scheduling**: 15+ trigger types -- Once, Daily, Weekly, Monthly, Cron, webhooks; Plan Builder for complex scenarios
- **Execution Monitoring**: Real-time dashboards showing status, history, logs, errors
- **Execution Plans**: Multi-task orchestration with dependencies, sequencing, conditional execution
- **Environment Management**: Logical separation of DEV, QA, STAGING, PROD
- **User/Role Management**: RBAC with granular permissions for projects, environments, engines
- **REST API**: TMC API for programmatic management

### Operational Features

- Pause and resume tasks for maintenance windows
- Task timeout configuration to prevent hung executions
- Alerts and notifications on task failures
- Audit logging of all administrative actions
- Task versioning with rollback capability

## Remote Engines

### Remote Engine (Classic)

- Deployed on customer-managed servers (Linux or Windows)
- Executes Standard DI Jobs and Routes
- Communicates with TMC via outbound HTTPS
- Configured with Nexus artifact repository access for artifact retrieval
- Supports clustering for high availability
- JVM configuration via `<RE_HOME>/bin/setenv.sh` (Linux) or `setenv.bat` (Windows)

### Remote Engine Gen2

- Docker-based architecture for Pipeline Designer artifacts
- Components: Component Server, Livy (Spark execution), supporting services
- Default port 9005 (configurable via `.env` file)
- Heartbeat mechanism: TMC considers connection broken after 180 seconds without heartbeat
- Secure data access to Kafka, databases, file systems within the customer network
- Run profiles in TMC customize resource allocation per execution

### Deployment Architecture

```
[Talend Cloud / TMC]
        |
   HTTPS (outbound only)
        |
[Customer Network / VPC]
   +----+----+
   |         |
[Remote     [Remote
 Engine]     Engine Gen2]
   |              |
[Data Sources: DBs, Files, APIs, Kafka, Cloud Storage]
```

## Repository and Version Control

### Git Integration

- Native Git integration in Talend Studio
- Project items versioned in Git: Jobs, Routines, Metadata, Context Groups
- Branch-based development with merge capabilities
- Recommended strategies: feature branches, release branches, trunk-based development

### Artifact Repository

- Compiled artifacts (.jar, .zip) published to Maven-compatible repositories
- **Nexus Snapshot**: Development/testing builds
- **Nexus Release**: Production-ready artifacts
- Production environments should only access Release repositories
- Semantic versioning (MAJOR.MINOR.PATCH)

### Project Structure

```
Talend Project
+-- Job Designs (Standard, Big Data, Streaming)
+-- Joblets
+-- Routines (System, User)
+-- Metadata (DB Connections, File Connections, Generic Schemas, Context Groups)
+-- Contexts
+-- Business Models
+-- Documentation
+-- SQL Templates
+-- References (child job references)
```

## Deployment Tiers

### Development Tier
- Talend Studio on developer workstations
- Local or shared Git server
- Local or shared test databases

### CI/CD Tier
- CI server (Jenkins, Azure DevOps, GitLab CI, GitHub Actions)
- Talend CI Builder Plugin (Maven-based)
- Nexus/Artifactory artifact repository
- Automated build, test, and publish pipeline

### Execution/Production Tier
- Talend Management Console (SaaS)
- Remote Engines in production infrastructure
- Cloud Engines for cloud-native execution
- Monitoring and alerting integration
