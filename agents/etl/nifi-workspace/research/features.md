# Apache NiFi Features

## Overview

Apache NiFi provides a comprehensive suite of features for data integration, flow management, and real-time data processing. As of early 2026, the latest release line is NiFi 2.8.x, with the platform having undergone significant modernization in the 2.x series.

---

## NiFi 2.x (Current Generation)

### Major Changes from 1.x

**Runtime and Framework:**
- Java 21 required (previously Java 8/11)
- Spring 6, Jetty 12, Servlet 6
- Angular 18 UI framework
- OpenAPI 3 REST API specification

**Python Processor Support:**
- Python 3.10+ is a first-class extension language
- Processors can be written entirely in Python using the NiFi Python API
- Full CPython support with access to the broad Python package ecosystem (pip, conda)
- Python processors support state management (added in NiFi 2.1.0)
- Python components can be packaged in NARs with included dependencies
- Works well with NiFi's stateless mode for on-demand processing, data enrichment, and inline ML inference
- MiNiFi also supports Python processors

**Kubernetes-Native Clustering:**
- Cluster coordination via Kubernetes Leases (no ZooKeeper needed on K8s)
- Shared state via Kubernetes ConfigMaps
- ZooKeeper remains supported for non-Kubernetes deployments

**Component Overhaul:**
- Removed all legacy Kafka processors; replaced with controller service-based ConsumeKafka/PublishKafka
- Removed all Hive-related components
- Removed many deprecated processors (alternatives available)
- Renamed distributed cache services (e.g., DistributedMapCacheServer -> MapCacheServer)

**Versioning and Registry:**
- Git-based Flow Registry Clients introduced as primary versioning mechanism
- NiFi Registry deprecated (February 2026 vote; removal planned in NiFi 3.0)
- Template support removed; registry-based versioning is the replacement

**Parameter Providers:**
- Enhanced parameter management with Parameter Tags
- MigrateProperties support in Registry Clients and Parameter Providers
- Integration with external secret stores (HashiCorp Vault, AWS Secrets Manager, etc.)

### Recent Version Highlights

| Version | Date | Key Changes |
|---------|------|-------------|
| 2.8.0 | 2026 | 170+ issues resolved; Record Gauge method added to Process Session |
| 2.7.2 | Dec 2025 | Bug fixes: sensitive property migration for Management Controller Services |
| 2.7.1 | Dec 2025 | Bug fixes: property name migration for ExecuteScript and scripted components |
| 2.6.0 | 2025 | 175+ issues resolved |
| 2.5.0 | 2025 | 150+ issues resolved |
| 2.1.0 | Jan 2025 | State management in Python processors; Python NAR packaging |
| 2.0.0 | Nov 2024 | GA release: Java 21, Python support, K8s clustering, component removals |

---

## Key Processor Types

### File System Processors

| Processor | Purpose |
|-----------|---------|
| **GetFile** | Reads files from a local or network-mounted directory; deletes or moves originals |
| **PutFile** | Writes FlowFile content to a file on the local or network filesystem |
| **ListFile / FetchFile** | List-then-fetch pattern: ListFile lists files (stateful, runs on primary node), FetchFile retrieves them (distributed across cluster). Preferred over GetFile for production use. |

### Database Processors

| Processor | Purpose |
|-----------|---------|
| **QueryDatabaseTable** | Incrementally extracts rows from a database table using a maximum-value column (e.g., timestamp or auto-increment ID). Stateful -- tracks last-seen value. |
| **PutDatabaseRecord** | Writes records to a database table using a RecordReader. Supports INSERT, UPDATE, UPSERT, and DELETE operations. |
| **ExecuteSQL** | Executes arbitrary SQL SELECT statements, producing Avro-formatted results |
| **ExecuteSQLRecord** | Like ExecuteSQL but uses Record-oriented output (configurable RecordSetWriter) |
| **GenerateTableFetch** | Generates SQL SELECT statements for partitioned fetching of large tables |

### Messaging Processors

| Processor | Purpose |
|-----------|---------|
| **ConsumeKafka** | Consumes messages from Apache Kafka topics. In NiFi 2.x, uses a controller service for Kafka connection configuration (breaking change from 1.x). |
| **PublishKafka** | Publishes FlowFile content to Kafka topics. Also uses controller service approach in 2.x. |
| **ConsumeJMS** | Consumes messages from JMS queues/topics |
| **PublishJMS** | Publishes to JMS destinations |
| **ConsumeAMQP / PublishAMQP** | AMQP 0.9.1 messaging (e.g., RabbitMQ) |

### HTTP Processors

| Processor | Purpose |
|-----------|---------|
| **InvokeHTTP** | Makes HTTP requests (GET, POST, PUT, DELETE, PATCH) to external services. Supports configurable SSL, proxy, authentication, and response handling. |
| **ListenHTTP** | Starts an HTTP/HTTPS server to receive incoming data |
| **HandleHttpRequest / HandleHttpResponse** | Pair of processors for building custom HTTP endpoints with full request/response control |

### Record-Oriented Processors

| Processor | Purpose |
|-----------|---------|
| **ConvertRecord** | Converts data between formats (CSV, JSON, Avro, Parquet, XML, etc.) using pluggable RecordReader and RecordSetWriter controller services |
| **UpdateRecord** | Modifies individual fields within records using RecordPath expressions. Can set literal values, reference other fields, or use NiFi Expression Language. |
| **QueryRecord** | Executes SQL queries against FlowFile content (in-memory SQL via Apache Calcite) |
| **SplitRecord** | Splits a FlowFile containing multiple records into smaller FlowFiles |
| **MergeRecord** | Merges multiple FlowFiles into a single FlowFile with multiple records |
| **LookupRecord** | Enriches records by looking up values from external sources |
| **ValidateRecord** | Validates records against a schema and routes valid/invalid records separately |
| **PartitionRecord** | Partitions records based on field values into separate FlowFiles |

### Routing Processors

| Processor | Purpose |
|-----------|---------|
| **RouteOnAttribute** | Routes FlowFiles based on evaluation of NiFi Expression Language against FlowFile attributes. Supports multiple named routes with individual conditions. |
| **RouteOnContent** | Routes FlowFiles based on content matching (regex or literal). Useful for content-based routing without attribute extraction. |
| **RouteText** | Routes individual lines of text content based on matching criteria |
| **DistributeLoad** | Distributes FlowFiles across relationships in weighted round-robin fashion |

---

## Record-Oriented Processing

### Architecture

NiFi's record-oriented processing framework enables schema-aware data handling through a layered abstraction:

1. **RecordReader** (Controller Service): Deserializes FlowFile content into a stream of Record objects. Implementations: CSVReader, JsonTreeReader, AvroReader, ParquetReader, XMLReader, GrokReader, SyslogReader.

2. **RecordSetWriter** (Controller Service): Serializes Record objects back to FlowFile content. Implementations: CSVRecordSetWriter, JsonRecordSetWriter, AvroRecordSetWriter, ParquetRecordSetWriter, XMLRecordSetWriter, FreeFormTextRecordSetWriter.

3. **Record Processors**: Operate on records abstractly, independent of the underlying data format.

### Schema Management

- **Embedded Schema**: Schema inferred from data (e.g., Avro files contain their schema)
- **Schema Inference**: NiFi can automatically infer schemas from data (added in NiFi 1.9). Allows record processors to work dynamically without manually defining schemas.
- **Schema Registry**: External schema management via AvroSchemaRegistry, JsonSchemaRegistry, or HortonworksSchemaRegistry controller services
- **Schema conversion**: Write schema can be a subset of read schema fields, or can have additional fields with default values

### RecordPath

RecordPath is an expression language for navigating and manipulating record structures:
- Navigate nested records: `/person/address/city`
- Array access: `/items[0]`, `/items[*]`
- Predicates: `/items[./price > 100]`
- Functions: `substringBefore()`, `toDate()`, `coalesce()`, etc.

### Benefits of Record-Oriented Processing
- Process many records in a single FlowFile (batch efficiency)
- Format-agnostic transformations (same processor handles CSV, JSON, Avro, etc.)
- Schema evolution support
- Reduced FlowFile overhead compared to one-record-per-FlowFile approaches

---

## MiNiFi: Edge Data Collection

### Overview

Apache MiNiFi (Minimal NiFi) is a lightweight agent designed for edge data collection and processing, deployed directly adjacent to data sources such as sensors, IoT devices, and remote systems.

### Implementations

| Variant | Runtime | Use Case |
|---------|---------|----------|
| **MiNiFi Java** | JVM | Edge devices with JVM support; broader processor compatibility |
| **MiNiFi C++** | Native C++ | Resource-constrained devices; minimal footprint; embedded systems |

### Key Characteristics

- **Small footprint**: Runs on resource-constrained edge devices
- **Subset of NiFi processors**: Supports core data collection and routing processors
- **Central management**: Flows designed in NiFi, deployed to MiNiFi agents
- **C2 Protocol (Command and Control)**: Enables remote configuration updates and operational commands to MiNiFi agents
- **Data relay**: Collects data at the edge and forwards to a central NiFi cluster for complex processing
- **Intermittent connectivity**: Handles environments with restricted or intermittent bandwidth
- **Python processor support**: MiNiFi Java supports Python processors (NiFi 2.x)

### Architecture Pattern

```
[Edge Sensors/Systems] -> [MiNiFi Agent] -> [Network] -> [NiFi Cluster] -> [Destinations]
```

MiNiFi handles the "first mile" of data collection, while NiFi handles complex routing, transformation, and delivery.

---

## Expression Language

NiFi Expression Language is used throughout the platform for dynamic property values:

- **Attribute references**: `${filename}`, `${uuid}`
- **String functions**: `${filename:substringAfter('_')}`, `${attr:toUpper()}`
- **Date functions**: `${now():format('yyyy-MM-dd')}`
- **Conditional logic**: `${attr:equals('value'):ifElse('yes','no')}`
- **Math operations**: `${fileSize:toNumber():divide(1024)}`
- **Environment variables**: `${ENV_VAR}`

Used in processor properties, RouteOnAttribute conditions, UpdateAttribute rules, and more.

---

## NiFi REST API

NiFi exposes a comprehensive REST API for programmatic control:

- **Flow management**: Create, configure, start, stop processors and connections
- **Provenance queries**: Search and retrieve data lineage events
- **System diagnostics**: Retrieve system metrics (heap, disk, threads)
- **Cluster management**: View node status, disconnect/connect nodes
- **Reporting tasks**: Configure and manage background reporting
- **Counters**: Access flow-level counters and metrics
- **Templates** (1.x) / **Registry operations** (2.x): Version control operations

---

## Sources

- [Apache NiFi 2.0.0: Building Python Processors - The New Stack](https://thenewstack.io/apache-nifi-2-0-0-building-python-processors/)
- [NiFi Python Developer's Guide](https://nifi.apache.org/nifi-docs/python-developer-guide.html)
- [Apache NiFi 2.1.0 Released](https://www.techsnet.net/2025/01/10/apache-nifi-2-1-0-released/)
- [Next Generation Apache NiFi 2.0.0 is GA - Datavolo](https://datavolo.io/2024/11/next-generation-apache-nifi-nifi-2-0-0-is-ga/)
- [Record-Oriented Data with NiFi - Apache Blogs](https://blogs.apache.org/nifi/entry/record-oriented-data-with-nifi)
- [Apache NiFi RecordPath Guide](https://nifi.apache.org/docs/nifi-docs/html/record-path-guide.html)
- [MiNiFi - Apache NiFi](https://nifi.apache.org/projects/minifi/)
- [NiFi 2 Python Extensions - First Impressions](https://apex974.com/articles/nifi-2-python-extensions)
- [Apache NiFi Release Notes](https://cwiki.apache.org/confluence/display/NIFI/Release+Notes)
- [Types of Apache NiFi Processors](https://www.dfmanager.com/blog/types-of-apache-nifi-processors)
