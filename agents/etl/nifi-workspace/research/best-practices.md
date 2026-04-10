# Apache NiFi Best Practices

## Flow Design

### Processor Selection

- **Prefer native processors over scripts**: Use built-in processors (300+) whenever possible. Custom scripts (ExecuteScript, ExecuteStreamCommand) are harder to maintain, debug, and monitor. They also bypass NiFi's built-in provenance and error handling.
- **Use record-oriented processors for structured data**: ConvertRecord, UpdateRecord, QueryRecord, and other record processors handle many records per FlowFile efficiently. Avoid splitting into one-record-per-FlowFile unless necessary.
- **Use the List/Fetch pattern instead of Get processors**: For file-based ingestion, prefer ListFile + FetchFile over GetFile. The List/Fetch pattern works correctly in clusters (ListFile runs on primary node, FetchFile distributes across cluster) and provides better state management.
- **Use controller service-based Kafka processors (NiFi 2.x)**: The new ConsumeKafka/PublishKafka processors use shared controller services for connection configuration, replacing the older embedded-config approach.

### Connection Sizing

- **Set back pressure thresholds intentionally**: Defaults are 10,000 objects and 1 GB. Adjust based on:
  - Expected throughput and FlowFile sizes
  - Available memory and disk
  - Acceptable latency tolerance
- **Size connections for expected burst**: If upstream processors can produce data faster than downstream can consume, size the connection queue to absorb bursts without triggering back pressure prematurely.
- **Set FlowFile expiration on non-critical connections**: Prevent stale data from accumulating indefinitely. Particularly useful for monitoring/alerting side flows.
- **Use load-balanced connections in clusters**: Configure Round Robin, Single Node, or Partition by Attribute to distribute work effectively.

### Process Group Organization

- **Organize by function**: Create process groups for logical stages: Ingestion, Validation, Transformation, Routing, Delivery, Error Handling.
- **Use Input/Output Ports for clear interfaces**: Define the contract between process groups via named ports.
- **Name process groups descriptively**: Include the data source/destination and purpose (e.g., "Ingest: Customer Orders from Kafka", "Transform: Normalize Address Records").
- **Keep nesting to 3-4 levels maximum**: Deeply nested process groups become difficult to navigate and debug.
- **Use Parameter Contexts per environment**: Define parameters (database URLs, credentials, file paths) in parameter contexts. Swap contexts when promoting flows across environments.
- **Version process groups in the registry**: Use Git-based Flow Registry Clients (NiFi 2.x) for version control of all significant process groups.

---

## Performance Optimization

### Concurrent Tasks

- **Start conservative, scale up**: Begin with the default concurrent tasks (1) and increase based on observed throughput needs.
- **Multi-thread I/O-bound processors**: Processors like InvokeHTTP, PutDatabaseRecord, and PutS3Object benefit from higher concurrent tasks (4-16+) since they spend time waiting on external systems.
- **Limit CPU-bound processors**: Transformation processors (JoltTransformJSON, ConvertRecord) may cause contention with too many concurrent tasks. Monitor CPU utilization.
- **Balance across cluster nodes**: In clusters, the total concurrent tasks = (configured value) x (number of nodes). Account for this when setting values.

### Batch Size and FlowFile Management

- **Batch records into larger FlowFiles**: Processing 1,000 records in one FlowFile is far more efficient than 1,000 individual FlowFiles. Use MergeRecord or MergeContent to batch small FlowFiles.
- **Use MergeContent before egress**: Merge small FlowFiles before writing to destinations (S3, HDFS, databases) to reduce overhead.
- **Avoid unnecessary splits**: SplitRecord and SplitText create many FlowFiles. Only split when downstream processing requires individual records.
- **Set appropriate Run Schedule**: Timer-driven with 0 sec runs as fast as possible. Use longer intervals (e.g., 1 sec, 5 sec) for polling processors to reduce CPU overhead when idle.

### Repository Configuration

- **Place repositories on separate fast disks**: FlowFile Repository, Content Repository, and Provenance Repository should each be on separate physical disks (SSDs recommended). This prevents I/O contention.
- **Use multiple Content Repository partitions**: Spread across multiple disks for parallel I/O:
  ```
  nifi.content.repository.directory.default=./content_repository
  nifi.content.repository.directory.disk2=/data2/content_repository
  nifi.content.repository.directory.disk3=/data3/content_repository
  ```
- **Size the Provenance Repository appropriately**: Provenance generates significant I/O. Set retention limits based on compliance needs vs. performance:
  ```
  nifi.provenance.repository.max.storage.time=30 days
  nifi.provenance.repository.max.storage.size=10 GB
  ```
- **Tune JVM heap size**: Allocate 50-75% of available RAM to NiFi's JVM heap. Remaining RAM is used by the OS for disk caching (critical for repository performance).

### Content Repository Sizing

- **Provision 2-3x the expected in-flight data size**: Content Repository stores content for active FlowFiles plus recently processed content awaiting garbage collection.
- **Monitor disk usage**: Set up MonitorDiskUsage reporting task to alert before disks fill.
- **Use fast storage**: NVMe SSDs for high-throughput deployments. Network storage (NFS, EBS) adds latency and should be tested carefully.

---

## Error Handling

### Retry Loops

- **Configure retry behavior on processors**: Many processors support penalty duration (how long a FlowFile waits before retry) and yield duration (how long the processor pauses after errors).
- **Use RetryFlowFile processor (NiFi 1.10+)**: Tracks retry count on FlowFiles and routes to `retries_exceeded` after a configurable maximum. Prevents infinite retry loops.
- **Implement exponential backoff**: Use UpdateAttribute to track retry count and ControlRate or Wait processor to implement increasing delays between retries.

### Failure Routing

- **Always connect the failure relationship**: Never auto-terminate the `failure` relationship on production processors. Route failures to dedicated error handling flows.
- **Log failures with context**: Route failed FlowFiles through LogAttribute or LogMessage to capture the error details, FlowFile attributes, and relevant context.
- **Separate transient from permanent failures**: Transient errors (network timeouts, temporary unavailability) should retry. Permanent errors (malformed data, schema violations) should route to dead letter flows.

### Dead Letter Flows

- **Persist failed FlowFiles**: Write failed FlowFiles to a dead letter destination (PutFile to error directory, PutS3Object to error bucket, PutDatabaseRecord to error table).
- **Include error metadata**: Use UpdateAttribute to add error details (error message, timestamp, source processor, retry count) before persisting.
- **Design for reprocessing**: Store enough context that failed FlowFiles can be resubmitted after the root cause is fixed.
- **Monitor dead letter queues**: Set up alerting on dead letter destinations so failures are detected promptly.

### Pattern: Comprehensive Error Handling

```
[Processor] --failure--> [UpdateAttribute: add error metadata]
                              |
                              v
                         [RouteOnAttribute: transient vs permanent?]
                              |                    |
                         (transient)          (permanent)
                              |                    |
                              v                    v
                    [RetryFlowFile]     [PutFile: dead_letter/]
                         |        |
                    (retry)  (retries_exceeded)
                         |        |
                         v        v
                   [Original]  [PutFile: dead_letter/]
```

---

## Security Best Practices

### Least Privilege

- **Restrict user access to specific process groups**: Use NiFi's policy-based authorization to grant read/write access only to the process groups each team needs.
- **Use dedicated service accounts**: Each NiFi node and each integration should have its own identity (certificate, Kerberos principal, or OIDC identity).
- **Limit controller service access**: Database connection pools and SSL contexts contain sensitive credentials. Restrict which process groups can reference them.

### Sensitive Properties

- **Use Parameter Contexts for credentials**: Never hard-code passwords, API keys, or connection strings in processor properties. Use Parameter Contexts with sensitive parameter values (encrypted at rest).
- **Integrate with external secret stores**: Use Parameter Providers to pull secrets from HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, etc.
- **Encrypt sensitive properties in flow configuration**: NiFi encrypts sensitive property values in flow.json.gz using the configured sensitive properties key.

### Encrypted Provenance

- **Enable provenance encryption for sensitive data flows**: If FlowFile content or attributes contain PII or sensitive data, configure encrypted provenance to protect lineage data at rest.
- **Set appropriate provenance retention**: Balance compliance requirements against storage and performance. Shorter retention for high-volume, low-sensitivity flows.

### Network Security

- **Always use HTTPS**: Configure NiFi with TLS for all web UI and REST API access.
- **Enable inter-node TLS**: In clusters, configure mutual TLS between all NiFi nodes.
- **Use NiFi's tls-toolkit**: Automate keystore and truststore generation for consistent, correct TLS configuration.
- **Restrict network access**: Use firewalls/security groups to limit who can reach the NiFi web UI (default port 8443 for HTTPS).

---

## Deployment

### Docker

- **Use official Apache NiFi Docker images**: `apache/nifi:2.x.x` for NiFi, `apache/nifi-registry:latest` for Registry (while still supported).
- **Mount volumes for repositories**: Content, FlowFile, and Provenance repositories should be on mounted volumes, not container-local storage:
  ```yaml
  volumes:
    - nifi-content:/opt/nifi/content_repository
    - nifi-flowfile:/opt/nifi/flowfile_repository
    - nifi-provenance:/opt/nifi/provenance_repository
    - nifi-conf:/opt/nifi/conf
  ```
- **Build custom images for extensions**: Use multi-stage Dockerfiles to compile custom NARs and add them to the NiFi image.
- **Externalize configuration**: Use environment variables or mounted config files rather than baking configuration into images.

### Kubernetes

- **Deploy as StatefulSet**: NiFi requires stable network identifiers and persistent storage, making StatefulSets the correct workload type.
- **Use performant storage classes**: NiFi is I/O intensive. Use SSDs (gp3, io1 on AWS; premium-lv on Azure) for repository PVCs. Avoid network-attached HDD storage.
- **Consider single-node deployments**: For many use cases, multiple independent single-node NiFi instances (one per pipeline or team) are simpler and more reliable than clusters on K8s.
- **Use NiFi 2.x Kubernetes clustering**: Eliminates ZooKeeper dependency. Uses Kubernetes Leases and ConfigMaps for coordination.
- **Consider the NiFiKop operator**: [Konpyutaika NiFiKop](https://github.com/konpyutaika/nifikop) automates NiFi cluster provisioning, scaling, and management on Kubernetes.
- **Resource requests and limits**: Set appropriate CPU and memory requests/limits. NiFi typically needs 4-8 GB RAM minimum for production workloads.

### Monitoring Integration

- **Prometheus + Grafana**: Use the NiFi Prometheus Reporting Task to export metrics. Push to Prometheus PushGateway or use the pull model with the metrics endpoint.
- **NiFi REST API**: Poll `/nifi-api/system-diagnostics` and `/nifi-api/flow/cluster/summary` for programmatic monitoring.
- **Reporting Tasks**: Configure built-in reporting tasks:
  - MonitorDiskUsage: Alert on low disk space
  - MonitorMemory: Alert on JVM memory pressure
  - SiteToSiteProvenanceReportingTask: Send provenance events to external systems
- **Log aggregation**: Ship NiFi logs (nifi-app.log, nifi-user.log, nifi-bootstrap.log) to ELK/Splunk/CloudWatch.
- **Alerting on back pressure**: Monitor connection queue sizes and alert when queues approach thresholds.

---

## Migration: NiFi 1.x to 2.x

### Pre-Migration Checklist

1. **Upgrade to NiFi 1.27.0 first**: Migration to 2.0.0 requires being on 1.27.0. Direct jumps from older 1.x versions are not supported.
2. **Review nifi-deprecation.log**: Available in recent 1.x versions. Identifies deprecated features and components in active use.
3. **Inventory deprecated components**: Check all processors, controller services, and reporting tasks against the NiFi 2.0 removal list.
4. **Test Java 21 compatibility**: Ensure all custom NARs and extensions compile and run on Java 21.
5. **Plan for Kafka migration**: All legacy Kafka processors are removed. Migrate to the new controller service-based ConsumeKafka/PublishKafka.
6. **Plan for Hive component removal**: All Hive components are removed. Migrate to JDBC-based alternatives.

### Breaking Changes Summary

| Area | Change | Action Required |
|------|--------|-----------------|
| Java | Java 21 required | Update JDK on all nodes |
| Kafka | All legacy Kafka processors removed | Migrate to new controller service-based processors |
| Hive | All Hive components removed | Migrate to JDBC alternatives |
| Cache | Distributed*Cache* services renamed | Update flow configuration bundle coordinates |
| Kerberos | Only KerberosUserService retained | Consolidate Kerberos configuration |
| Templates | Template support removed | Convert templates to versioned process groups |
| UI | Advanced UI path changed to `/` | Update any UI automation/bookmarks |
| NAR bundles | Some components relocated to different NARs | Update bundle coordinates in flow.json.gz |

### Migration Steps

1. Upgrade to NiFi 1.27.0 and resolve all deprecation warnings
2. Back up all flow configurations, repositories, and NiFi properties
3. Replace deprecated components with recommended alternatives
4. Update Java to 21, install NiFi 2.x binaries
5. Update flow.json.gz with new bundle coordinates (for renamed/relocated components)
6. Migrate Kafka flows to new controller service-based processors
7. Test thoroughly in a non-production environment
8. Update monitoring and automation scripts for any API or path changes

### Flow Configuration Update

When components are relocated to different NARs, the `flow.json.gz` file must be updated with new bundle coordinates. Tools and scripts are available in the Apache NiFi community for automating this process.

---

## Sources

- [How to Optimize NiFi for High Performance](https://www.dfmanager.com/blog/how-to-optimize-nifi)
- [Best Practices for Data Pipeline Error Handling in Apache NiFi](https://dzone.com/articles/best-practices-for-data-pipeline-error-handling-in)
- [Achieving Peak Performance in Apache NiFi - ClearPeaks](https://www.clearpeaks.com/achieving-peak-performance-in-apache-nifi-health-checks-optimisation-strategies/)
- [How to Design Maintainable NiFi Flows: 7 Best Practices](https://www.dfmanager.com/blog/design-maintainable-nifi-flows-best-practices)
- [6 Best Data Flow Optimization Tips in Apache NiFi](https://www.dfmanager.com/blog/nifi-data-flow-optimization-tips)
- [NiFi 1.x to 2.x Migration Guide - KSolves](https://www.ksolves.com/blog/big-data/nifi-2-0-upgrade-guide)
- [Migration Guidance - Apache NiFi](https://cwiki.apache.org/confluence/display/NIFI/Migration+Guidance)
- [Breaking Changes in NiFi 2 - Cloudera](https://docs-archive.cloudera.com/cfm/4.0.0/cfm-preparing-for-nifi2-upgrade/topics/cfm-nifi2-breaking-changes.html)
- [Apache NiFi on Kubernetes - Datavolo](https://datavolo.io/2024/08/constructing-apache-nifi-clusters-on-kubernetes/)
- [NiFiKop - Kubernetes Operator for NiFi](https://github.com/konpyutaika/nifikop)
- [Apache NiFi Security Best Practices](https://www.dfmanager.com/blog/nifi-security-essentials-closing-gaps-in-real-time-data-movement)
- [NiFi Authentication LDAP OAuth SSO](https://www.dfmanager.com/blog/nifi-authentication-ldap-oauth-sso)
