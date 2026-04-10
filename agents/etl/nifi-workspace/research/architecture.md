# Apache NiFi Architecture

## Overview

Apache NiFi is a data integration and flow management platform built on flow-based programming (FBP) principles. It provides a web-based UI for designing, controlling, and monitoring data flows in real time. NiFi was originally developed by the NSA as "Niagarafiles" and donated to the Apache Software Foundation in 2014.

---

## Core Concepts

### FlowFile

The **FlowFile** is the atomic unit of data in NiFi. Every piece of data brought into NiFi for processing is represented as a FlowFile. A FlowFile consists of two parts:

- **Attributes**: Key-value pairs of metadata (e.g., filename, path, MIME type, UUID). Attributes travel with the FlowFile and can be added, modified, or removed by processors. Standard attributes include `uuid`, `filename`, `path`, and `entryDate`.
- **Content**: The actual data payload (bytes). Content is stored in the Content Repository and referenced by pointer from the FlowFile. Content is immutable -- when a processor modifies content, NiFi creates a new version (copy-on-write).

FlowFiles are lightweight references; the actual content resides in the Content Repository on disk, allowing NiFi to handle very large data objects without holding them entirely in memory.

### Processor

A **Processor** is the fundamental building block that performs work in NiFi. Processors can:

- Listen for or pull data from external sources (data ingestion)
- Transform, route, filter, or enrich FlowFiles
- Push data to external destinations (data egress)
- Extract information from FlowFile attributes or content

Each processor has configurable properties, scheduling settings (timer-driven, cron-driven, or event-driven), and defined **Relationships** (e.g., `success`, `failure`, `matched`, `unmatched`) that determine where FlowFiles are routed after processing.

Key processor settings:
- **Concurrent Tasks**: Number of threads allocated to the processor
- **Run Schedule**: How frequently the processor executes
- **Penalty Duration**: How long a FlowFile is penalized before retry
- **Yield Duration**: How long a processor waits after yielding (e.g., on error)
- **Bulletin Level**: Minimum severity for bulletin messages

### Connection

A **Connection** links processors together and serves as a queue for FlowFiles between components. Each connection:

- Maps one or more **Relationships** from a source processor to a destination processor
- Contains a **FlowFile Queue** where FlowFiles wait to be processed
- Has configurable **back pressure thresholds** (object count and data size)
- Supports **FlowFile expiration** (auto-drop aged FlowFiles)
- Supports **prioritization** (e.g., FirstInFirstOut, NewestFlowFileFirst, OldestFlowFileFirst, PriorityAttribute)
- Can be configured for **load balancing** across cluster nodes (Round Robin, Single Node, Partition by Attribute)

### Process Group

A **Process Group** is a logical grouping of processors, connections, and other components that forms a reusable sub-workflow. Process Groups:

- Provide modularity and organization for complex flows
- Use **Input Ports** and **Output Ports** to receive and send data across group boundaries
- Can be nested (Process Groups within Process Groups)
- Support versioning via NiFi Registry / Git-based flow registries
- Have their own parameter contexts and controller services
- Can be converted to/from templates (deprecated in NiFi 2.x in favor of registry-based versioning)

### Controller Service

A **Controller Service** provides shared configuration and resources that processors and other controller services can reference. They are defined at the Process Group level or globally. Common types include:

- **DBCPConnectionPool**: Database connection pooling
- **StandardSSLContextService**: SSL/TLS certificate configuration
- **AvroSchemaRegistry / JsonSchemaRegistry**: Schema management for record-oriented processing
- **RecordReader/RecordSetWriter implementations**: CSVReader, JsonTreeReader, AvroReader, etc.
- **HortonworksSchemaRegistry**: Integration with external schema registries
- **DistributedMapCacheClient** (renamed to MapCacheClientService in 2.x): Distributed caching

Controller services can be scoped:
- **Global Scope**: Accessible across all process groups (defined at root canvas)
- **Process Group Scope**: Accessible only within the defining process group and its children

---

## Core Repositories

NiFi relies on three persistent repositories on local storage:

### FlowFile Repository
- Stores metadata for all **current** FlowFiles in the system
- Uses a Write-Ahead Log (WAL) for durability and crash recovery
- Contains FlowFile attributes and pointers to content in the Content Repository
- Should be on fast storage (SSD recommended) for optimal performance

### Content Repository
- Stores the actual **content** (data payload) of FlowFiles
- Uses a content claim system with reference counting for deduplication
- Can span multiple disk partitions for throughput and capacity
- Supports copy-on-write semantics -- modifying content creates a new claim
- Content claims are garbage collected when no longer referenced

### Provenance Repository
- Stores the complete **history and lineage** of every FlowFile
- Records provenance events: CREATE, RECEIVE, SEND, CLONE, FORK, JOIN, ROUTE, MODIFY_CONTENT, MODIFY_ATTRIBUTES, DROP, EXPIRE, etc.
- Indexed via Apache Lucene for fast querying
- Default implementation: PersistentProvenanceRepository
- Journals are merged and compressed every 30 seconds by default
- Lucene indices are sharded (default 500 MB per shard)
- Configurable retention period and storage limits
- Enables data lineage visualization (DAG), replay from any point, and compliance auditing

---

## Flow-Based Programming Model

NiFi implements the Flow-Based Programming (FBP) paradigm:

1. **Data as packets**: FlowFiles are independent information packets flowing through a network of processors
2. **Black-box processes**: Processors are self-contained units that transform data without knowledge of the broader flow
3. **External connections**: Connections between processors are explicitly defined and configurable
4. **Asynchronous processing**: Processors run independently on their own schedules
5. **Back pressure**: Built-in flow control prevents system overload

### Provenance and Lineage

Every operation on a FlowFile generates a **provenance event**, creating a complete audit trail:
- Full data lineage from source to destination
- Ability to replay data from any point in the flow
- Compliance and debugging capabilities
- Accessible via the NiFi UI provenance search or REST API

---

## Clustering Architecture

### NiFi 1.x Clustering (ZooKeeper-based)

In NiFi 1.x, clustering requires Apache ZooKeeper for coordination:

- **Zero-Leader Clustering**: Every node in the cluster performs the same work on different data. There is no "leader" that distributes work -- instead, each node processes data independently.
- **Cluster Coordinator**: Elected by ZooKeeper. Responsible for managing cluster membership, node heartbeats, and disconnecting/reconnecting nodes.
- **Primary Node**: Elected by ZooKeeper. Runs "isolated" processors (processors configured to run on only one node, e.g., ListFile, to avoid duplicate processing).
- **ZooKeeper**: Manages leader election, ephemeral znodes for node registration, and cluster state. Minimum 3 ZooKeeper instances recommended (odd number for quorum). Can be embedded within NiFi or external.

Data flow changes made on any node are replicated to all nodes via the Cluster Coordinator. Each node processes its own data independently.

### NiFi 2.x Clustering Enhancements

NiFi 2.0 introduced **Kubernetes-native clustering**, removing the ZooKeeper dependency for Kubernetes deployments:

- **Kubernetes Leases**: Used for cluster coordinator and primary node election (replacing ZooKeeper leader election)
- **Kubernetes ConfigMaps**: Used for shared state tracking (replacing ZooKeeper znodes)
- **Reduced Complexity**: Eliminates the need to deploy and manage ZooKeeper alongside NiFi on Kubernetes
- **ZooKeeper still supported**: For bare-metal and non-Kubernetes deployments, ZooKeeper-based clustering remains available

This change decoupled the leader election interface from ZooKeeper by promoting it to the `nifi-framework-api` library, enabling alternative implementations.

---

## NiFi Registry and Flow Versioning

### NiFi Registry (1.x and early 2.x)

NiFi Registry is a standalone application for centralized flow storage and version control:

- **Buckets**: Logical containers for organizing versioned flows
- **Version Control**: Process groups can be committed to the registry with version history
- **CI/CD Integration**: Flows can be promoted across environments (dev -> staging -> prod)
- **Access Control**: Bucket-level and flow-level authorization policies

### Git-Based Flow Registry Clients (NiFi 2.x)

NiFi 2.x introduced Git-based Flow Registry Clients as an alternative:

- Flows are stored directly in Git repositories
- Leverages standard Git workflows (branching, pull requests, merging)
- Better alignment with existing CI/CD pipelines

**Important**: Apache NiFi Registry was deprecated following a community vote in February 2026 and is planned for removal in Apache NiFi 3.0. Git-based Flow Registry Clients are the recommended replacement.

---

## Processor Categories

NiFi ships with 300+ processors organized into categories:

### Data Ingestion
- **GetFile**, **GetSFTP**, **GetFTP**: File system ingestion
- **ListFile**, **FetchFile**: List-then-fetch pattern for reliable ingestion
- **ConsumeKafka**: Kafka consumer
- **QueryDatabaseTable**, **GenerateTableFetch**: Database ingestion
- **ListenHTTP**, **HandleHttpRequest**: HTTP endpoints
- **GetS3Object**, **ListS3**: Cloud storage ingestion
- **ConsumeJMS**, **ConsumeAMQP**: Message queue consumers

### Routing and Mediation
- **RouteOnAttribute**: Route based on FlowFile attribute expressions
- **RouteOnContent**: Route based on content matching (regex, XPath, etc.)
- **DistributeLoad**: Load balance across relationships
- **ControlRate**: Throttle flow rate
- **DetectDuplicate**: Identify and route duplicate FlowFiles

### Data Transformation
- **ConvertRecord**: Convert between data formats (CSV, JSON, Avro, Parquet, etc.)
- **UpdateRecord**: Modify record fields using RecordPath expressions
- **JoltTransformJSON**: JSON-to-JSON transformation using Jolt specs
- **ReplaceText**: Content manipulation via regex or literal replacement
- **ConvertCharacterSet**: Character encoding conversion
- **CompressContent / DecompressContent**: Compression handling
- **SplitRecord**, **MergeRecord**: Split and merge record-based data

### System Interaction
- **ExecuteProcess**: Run OS commands
- **ExecuteStreamCommand**: Pipe FlowFile content through external commands
- **ExecuteScript**: Run Groovy, Python, Ruby, Lua, Clojure scripts
- **InvokeHTTP**: HTTP client for REST API calls

### Database Interaction
- **ExecuteSQL**, **ExecuteSQLRecord**: Execute SQL queries
- **PutDatabaseRecord**: Insert/update/upsert records into databases
- **QueryDatabaseTable**: Incremental database extraction

### Data Egress
- **PutFile**, **PutSFTP**, **PutFTP**: File system output
- **PublishKafka**: Kafka producer
- **PutS3Object**: Cloud storage output
- **PutEmail**: Email delivery
- **PutDatabaseRecord**: Database writes

### Attribute Extraction
- **UpdateAttribute**: Set or modify FlowFile attributes
- **EvaluateJsonPath**: Extract JSON values to attributes
- **ExtractText**: Extract content via regex to attributes
- **AttributesToJSON**: Convert attributes to JSON content

---

## Back Pressure and Flow Control

### Connection-Level Back Pressure

Each connection has two configurable back pressure thresholds:

1. **Object Threshold** (default: 10,000 FlowFiles): Maximum number of FlowFiles queued
2. **Data Size Threshold** (default: 1 GB): Maximum total size of queued FlowFile content

When either threshold is reached:
- The upstream (source) processor is **no longer scheduled to run**
- The connection is visually indicated in the UI (color change to yellow/red)
- Downstream processing continues to drain the queue
- Once the queue drops below thresholds, the upstream processor resumes

These are **soft limits** -- if a processor produces multiple FlowFiles in a single execution, the queue may temporarily exceed the threshold before back pressure takes effect.

### System-Level Flow Control
- **FlowFile expiration**: FlowFiles can be auto-dropped after a configurable time in a connection queue
- **Prioritization**: Queue ordering can be customized to process important data first
- **Yield**: Processors can yield execution when encountering temporary errors
- **Penalization**: Individual FlowFiles can be penalized (delayed) before retry

---

## Security Model

### Authentication

NiFi supports multiple authentication mechanisms:

- **Mutual TLS (mTLS)**: Client certificate authentication; always enabled when HTTPS is configured. Cannot be disabled -- it is always the first authentication method attempted.
- **LDAP/LDAPS**: Integration with LDAP directories (Active Directory, OpenLDAP). LDAPS provides encrypted authentication.
- **Kerberos**: SPNEGO-based authentication. In NiFi 2.x, only the Kerberos User Service is retained (supports keytab, password, and ticket cache).
- **OpenID Connect (OIDC)**: Integration with identity providers (Keycloak, Okta, etc.). Supports RP-Initiated Logout 1.0, refresh tokens, and automatic bearer token renewal.
- **SAML**: SAML 2.0 single sign-on support

### Authorization

- **Role-Based Access Control (RBAC)**: Granular permissions at the level of individual processors, process groups, controller services, and UI components
- **Policy-based authorization**: Read, write, and component-specific policies
- **Multi-tenant**: Different users/groups can have different access to different parts of the flow
- **File-based and LDAP-based user/group providers**

### Data Protection
- **SSL/TLS**: All inter-node and client communication can be encrypted
- **Sensitive Properties**: Encrypted at rest in flow configuration files
- **Encrypted Provenance**: Provenance data can be encrypted
- **tls-toolkit**: Command-line utility for generating keystores, truststores, and configuration

---

## NiFi 2.x Architecture Changes from 1.x

### Major Framework Changes
- **Java 21 required** (up from Java 8/11 in 1.x)
- **Spring 6, Jetty 12, Servlet 6**: Updated web framework stack
- **Angular 18**: Modernized UI framework
- **OpenAPI 3**: Updated REST API specification

### Clustering
- Kubernetes-native clustering support (Leases + ConfigMaps)
- ZooKeeper no longer required for Kubernetes deployments

### Component Changes
- Renamed cache services (DistributedMapCacheServer -> MapCacheServer, etc.)
- Removed all legacy Kafka processors (replaced with controller service-based approach)
- Removed all Hive-related components
- Removed many deprecated processors with better alternatives available
- Python processor support as first-class extension mechanism

### Registry and Versioning
- Git-based Flow Registry Clients introduced
- NiFi Registry deprecated (planned removal in 3.0)
- Template support removed (registry-based versioning is the replacement)

### Configuration
- Advanced UI path changed from `/configure` to root path `/`
- Kerberos consolidated to single Kerberos User Service
- `nifi-deprecation.log` added for identifying deprecated feature usage pre-upgrade

---

## Sources

- [Apache NiFi User Guide](https://nifi.apache.org/docs/nifi-docs/html/user-guide.html)
- [Apache NiFi In Depth](https://nifi.apache.org/docs/nifi-docs/html/nifi-in-depth.html)
- [Apache NiFi Overview](https://nifi.apache.org/nifi-docs/overview.html)
- [Getting Started with Apache NiFi](https://nifi.apache.org/nifi-docs/getting-started.html)
- [NiFi System Administrator's Guide](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html)
- [Next Generation Apache NiFi 2.0.0 is GA - Datavolo](https://datavolo.io/2024/11/next-generation-apache-nifi-nifi-2-0-0-is-ga/)
- [Bringing Kubernetes Clustering to Apache NiFi - ExceptionFactory](https://exceptionfactory.com/posts/2024/08/10/bringing-kubernetes-clustering-to-apache-nifi/)
- [Apache NiFi 2: Key Updates - Stackable](https://stackable.tech/en/blog/apache-nifi2-key-updates-stackable/)
- [Apache NiFi Release Notes](https://cwiki.apache.org/confluence/display/NIFI/Release+Notes)
