# Talend Architecture Reference

## Platform Overview

Talend is an enterprise data integration platform built on Eclipse RCP and Java, now part of the Qlik ecosystem following the May 2023 acquisition. The platform generates native Java code from visual job designs, enabling high-performance ETL/ELT processing across on-premises, cloud, and hybrid environments.

## Core Architectural Components

### Talend Studio

Talend Studio is the primary development environment, built on the Eclipse Rich Client Platform (RCP).

- **Visual Job Designer**: Drag-and-drop canvas for designing data integration workflows
- **Eclipse-Based IDE**: Full Java IDE capabilities including code editing, debugging, and syntax highlighting
- **Code Generation Engine**: Converts visual job designs into executable Java code
- **Palette**: Categorized library of 1,000+ pre-built components for connectors, transformations, orchestration, and quality
- **Repository Browser**: Centralized navigation for all project artifacts (jobs, metadata, routines, contexts, etc.)
- **Perspective Views**: Design, Debug, Profiling, and Integration perspectives for different development tasks
- **Java 17 Requirement**: As of Talend 8.0 (R2025-02+), all artifacts must be built and executed using Java 17; Java 8 support has ended

### Jobs

Jobs are the fundamental execution unit in Talend, representing a complete data integration workflow.

**Job Types:**
- **Standard Jobs (DI Jobs)**: Traditional batch ETL jobs for data extraction, transformation, and loading
- **Big Data Batch Jobs**: Designed for Spark-based batch processing on Hadoop/cloud clusters
- **Big Data Streaming Jobs**: Real-time data processing using Spark Streaming
- **Route Jobs (ESB)**: Mediation routes for Enterprise Service Bus integrations based on Apache Camel
- **Service Jobs (ESB)**: RESTful or SOAP web service implementations
- **Joblets**: Reusable sub-job fragments that can be shared across multiple jobs

**Job Architecture:**
- Jobs are stored internally as XML but generate executable Java code
- Each job compiles to a self-contained JAR file with all dependencies
- Jobs support parameterization through Context Variables and Context Groups
- Parent/Child job hierarchies via tRunJob component (recommended max 3 nesting levels)

### Components

Components are the building blocks placed on the job canvas. Each component encapsulates specific functionality.

**Component Categories:**
- **Connectivity**: Database connectors (tMysqlInput, tOracleOutput, tPostgresqlInput), file connectors (tFileInputDelimited, tFileOutputExcel), cloud connectors (tS3Connection, tSnowflakeInput, tBigQueryOutput), messaging (tKafkaInput, tJMSOutput), API (tRESTClient, tSOAP)
- **Processing/Transformation**: tMap (primary transformation component), tJoin, tUnite, tNormalize, tDenormalize, tAggregate, tSort, tUniqRow, tFilterRow, tFilterColumns, tReplicate
- **Orchestration**: tRunJob, tParallelize, tLoop, tIterateToFlow, tPreJob, tPostJob
- **Quality**: tMatchGroup, tFuzzyMatch, tPatternCheck, tDataMasking
- **Logging/Error Handling**: tLogRow, tLogCatcher, tStatCatcher, tWarn, tDie, tFlowToIterate
- **File Management**: tFileCopy, tFileDelete, tFileList, tFileArchive
- **Bulk Operations**: tBulkExec, tMysqlBulkExec, tPostgresqlBulkExec (high-performance batch loading)

**Component Architecture:**
- Input components (sources) connect to output components (targets) via Row connections (main, reject, lookup)
- Trigger connections (OnSubjobOk, OnSubjobError, OnComponentOk, OnComponentError) control flow
- The tMap component is the central transformation engine supporting lookups, filtering, expressions, and multi-output routing
- Custom components can be built using the Talend Component Kit (TCK) SDK

### Routines

Routines are reusable Java code libraries accessible across all jobs in a project.

**Types:**
- **System Routines**: Pre-built utility functions (StringHandling, Numeric, TalendDate, TalendString, Relational)
- **User Routines**: Custom Java classes created by developers for project-specific logic
- **Custom Routine JARs**: External Java libraries imported and managed as routine dependencies

**Usage:**
- Referenced in tMap expressions, tJava/tJavaRow components, and component configuration fields
- Stored in the project repository under the Routines node
- Shared across all jobs within a project; cross-project sharing requires export/import

### Metadata

Metadata provides centralized, reusable definitions for data connections, schemas, and structures.

**Metadata Types:**
- **Database Connections**: Connection parameters for RDBMS systems with schema retrieval
- **File Connections**: Delimited, positional, Excel, XML, JSON, LDIF file structure definitions
- **Web Service (WSDL)**: SOAP service definitions
- **Salesforce/SAP/Marketo Connections**: SaaS and ERP-specific connection metadata
- **Generic Schemas**: Reusable column definitions independent of any connection
- **Context Groups**: Environment-specific variable sets (DEV, QA, PROD)
- **Hadoop Connections**: HDFS, Hive, HBase cluster configurations

**Benefits:**
- Change a metadata definition once and propagate to all jobs referencing it
- Schema evolution management with impact analysis
- Connection parameter centralization reduces configuration errors

---

## Talend Cloud / Management Console (TMC)

### Talend Management Console (TMC)

TMC is the cloud-based administration and operations platform for managing Talend artifacts in production.

**Core Capabilities:**
- **Task Management**: Create, schedule, and manage executable tasks from deployed artifacts
- **Scheduling**: Supports Once, Daily, Weekly, Monthly, Cron-based triggers, and webhooks (15+ trigger types); includes Plan Builder for complex scheduling scenarios
- **Execution Monitoring**: Real-time dashboards showing task status, execution history, logs, and error details
- **Execution Plans**: Orchestrate multi-task workflows with dependencies, sequencing, and conditional execution
- **Environment Management**: Logical separation of DEV, QA, STAGING, PROD environments
- **User/Role Management**: RBAC with granular permissions for projects, environments, and engines
- **API Access**: RESTful TMC API for programmatic task management and monitoring
- **Task Versioning**: Deploy and manage multiple versions of tasks with rollback capability

**Operational Features:**
- Pause and resume tasks for maintenance windows
- Task timeout configuration to prevent hung executions
- Alerts and notifications on task failures
- Audit logging of all administrative actions

### Talend Cloud Engine

- **Cloud Engine**: Fully managed compute resource hosted by Talend/Qlik for executing tasks directly in the cloud
- **Cloud Engine for Design**: Enables testing pipeline designs without local infrastructure
- Engines are allocated to environments proportionally to expected concurrent task execution counts

### Remote Engines

Remote Engines execute Talend jobs within the customer's own infrastructure while being orchestrated from TMC.

**Remote Engine (Classic):**
- Deployed on customer-managed servers (Linux or Windows)
- Executes Standard DI Jobs and Routes
- Communicates with TMC via HTTPS outbound connections
- Configured as a Talend JobServer with Nexus artifact repository access
- Supports clustering for high availability

**Remote Engine Gen2:**
- Docker-based architecture for executing Pipeline Designer artifacts
- Runs within customer's VPC or local network
- Components: Component Server, Livy (Spark execution), and supporting services
- Default port 9005 (configurable via .env file)
- Heartbeat mechanism: TMC considers connection broken after 180 seconds without heartbeat
- Secure data access to Kafka, databases, file systems within the customer network
- Run profiles in TMC customize resource allocation per execution

**Remote Engine Deployment Architecture:**
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

---

## Repository and Version Control

### Git Integration
- Talend Studio integrates natively with Git for version control
- Project items (Jobs, Routines, Metadata, Context Groups) are stored and versioned in Git
- Branch-based development with merge capabilities
- Recommended branching strategies: feature branches, release branches, trunk-based development

### Artifact Repository (Nexus/Artifactory)
- Compiled job artifacts (.jar, .zip) are published to Maven-compatible artifact repositories
- Nexus Snapshot repository for development/testing builds
- Nexus Release repository for production-ready artifacts
- Production environments should only access Release repositories

### Project Structure
```
Talend Project
+-- Job Designs (Standard, Big Data, Streaming)
+-- Joblets
+-- Routines (System, User)
+-- Metadata
|   +-- DB Connections
|   +-- File Connections
|   +-- Generic Schemas
|   +-- Context Groups
+-- Contexts
+-- Business Models
+-- Documentation
+-- SQL Templates
+-- References (child job references)
```

---

## Deployment Architecture Tiers

### Development Tier
- Talend Studio instances on developer workstations
- Local Git repositories or shared Git server
- Local or shared test databases

### CI/CD Tier
- CI server (Jenkins, Azure DevOps, GitLab CI, GitHub Actions)
- Talend CI Builder Plugin (Maven-based)
- Nexus/Artifactory artifact repository
- Automated build, test, and publish pipeline

### Execution/Production Tier
- Talend Management Console (SaaS)
- Remote Engines deployed in production infrastructure
- Cloud Engines for cloud-native execution
- Monitoring and alerting integration with APM tools

---

## Sources

- [Functional Architecture of Talend Data Integration](https://help.qlik.com/talend/en-US/studio-getting-started-guide-data-integration/8.0/functional-architecture)
- [Talend Studio 8.0 Release Notes](https://help.qlik.com/talend/en-US/release-notes/8.0/r2026-03-studio)
- [Remote Engine Gen2 Architecture](https://help.talend.com/r/en-US/Cloud/remote-engine-gen2-quick-start-guide/remote-engine-gen2-architecture)
- [Executing Artifacts on Remote Engine](https://help.qlik.com/talend/en-US/studio-user-guide/8.0-R2026-03/executing-artifacts-on-remote-engine-from-talend-studio)
- [Managing User Routines](https://help.qlik.com/talend/en-US/studio-user-guide/8.0-R2026-03/managing-user-routines)
- [Configuring Components Through Metadata](https://help.qlik.com/talend/en-US/creating-using-metadata-talend-studio/8.0/adding-a-component-metadata)
- [TMC Scheduling Job Tasks](https://help.qlik.com/talend/en-US/management-console-user-guide/Cloud/scheduling-job-tasks)
- [TMC Execution Engines](https://help.qlik.com/talend/en-US/management-console-user-guide/Cloud/tmc-engines)
