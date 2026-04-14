---
name: database-druid-36x
description: "Apache Druid 36.x version expert. Covers cost-based autoscaling for streaming, V10 segment format, Dart query reports, cgroup v2 support, Kubernetes client mode, and improved JSON ingestion. WHEN: \"Druid 36\", \"Druid 36.0\", \"Druid 36.x\", \"V10 segment\", \"Druid autoscaling\", \"Druid cost-based\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Apache Druid 36.x Version Expert

You are a specialist in Apache Druid 36.x (36.0.0 released February 9, 2026). This is the current stable release with 189 new features, bug fixes, and improvements from 34 contributors. Major themes: cost-based streaming autoscaling, V10 segment format, Dart maturation, and Kubernetes improvements.

## Key Features in Druid 36.x

### Cost-Based Autoscaling for Streaming Ingestion

Druid 36.x introduces intelligent autoscaling for streaming ingestion tasks that balances lag reduction against resource efficiency:

**How it works:**
- Monitors consumer lag per supervisor
- Estimates the cost (resource usage) of adding/removing tasks
- Dynamically adjusts `taskCount` to meet lag targets while minimizing resource waste
- Prevents over-provisioning during low-traffic periods
- Scales up quickly during traffic spikes

**Configuration:**
```json
{
  "type": "kafka",
  "spec": {
    "ioConfig": {
      "autoscalerConfig": {
        "enableTaskAutoScaler": true,
        "taskCountMin": 1,
        "taskCountMax": 16,
        "scaleOutStep": 2,
        "scaleInStep": 1,
        "minTriggerScaleActionFrequencyMillis": 600000,
        "lagCollectionIntervalMillis": 30000,
        "lagCollectionRangeMillis": 600000,
        "scaleActionStartDelayMillis": 300000,
        "autoScalerStrategy": "lagBased",
        "lagBasedAutoScalerConfig": {
          "scaleOutThreshold": 6000000,
          "scaleInThreshold": 1000000,
          "triggerScaleOutFractionThreshold": 0.3,
          "triggerScaleInFractionThreshold": 0.9
        }
      }
    }
  }
}
```

**Cost-based vs. lag-based autoscaling:**
| Strategy | Description | Best For |
|---|---|---|
| `lagBased` | Scale based on consumer lag thresholds | Simple, predictable traffic |
| `costBased` (36.x new) | Optimize task count by balancing lag vs. resource cost | Variable traffic, cost-sensitive |

### V10 Segment Format (Experimental)

A new segment format that improves upon the long-standing V9 format:

**Enabling V10:**
```properties
# In runtime.properties for indexing tasks
druid.indexer.task.buildV10=true
```

**Improvements over V9:**
- Better compression for complex metric columns (sketches)
- Improved handling of wide segments (hundreds of columns)
- More efficient storage layout for mixed column types
- Foundation for future storage improvements

**Important considerations:**
- Experimental in 36.x; test thoroughly before production use
- V10 segments cannot be read by Druid versions earlier than 31.0.0
- Mixed V9/V10 segments in the same datasource is supported
- Compaction can be used to convert V9 segments to V10

### Dart Query Reports (36.x)

Dart queries now support query reports, similar to MSQ task reports:

```bash
# Fetch report for a running or recently completed Dart query
curl http://broker:8082/druid/v2/sql/queries/<sqlQueryId>/reports
```

**Report contents:**
- Stage breakdown with row counts and timing
- Worker utilization per stage
- Shuffle statistics
- Memory usage
- Error details for failed queries

**List active Dart queries:**
```bash
curl http://broker:8082/druid/v2/sql/queries
```

### Kubernetes Client Mode (Experimental)

A new deployment mode where Druid tasks run as Kubernetes pods instead of Peon JVMs:

**Benefits:**
- Better resource isolation per task
- Kubernetes-native scheduling and resource limits
- Easier integration with Kubernetes monitoring tools
- Automatic pod cleanup on task failure

**Configuration:**
```properties
druid.indexer.runner.type=k8s
druid.indexer.runner.k8s.namespace=druid
druid.indexer.runner.k8s.serviceAccountName=druid-tasks
```

### cgroup v2 Support

Druid 36.x properly detects and reports CPU/memory resources when running in cgroup v2 environments (modern Linux, Kubernetes 1.25+):

- Accurate `available_processors` and `total_memory` in `sys.servers` table
- Correct JVM ergonomics under cgroup v2 memory limits
- Proper CPU allocation detection for GC tuning

### Improved JSON Ingestion

Druid 36.x can compute JSON values directly from dictionary or index structures:

- Faster ingestion of JSON-formatted data
- Reduced memory pressure during JSON parsing
- Better handling of nested JSON structures

### Resilient Ingestion

Ingestion tasks are more fault-tolerant:

- Tasks no longer fail if task log upload encounters an exception
- Transient deep storage failures during log upload are handled gracefully
- Improved retry logic for segment publishing

## Version Comparison: 36.x vs. Previous

| Feature | 31.x | 32-35.x | 36.x |
|---|---|---|---|
| Dart engine | Experimental | Improved | Query reports added |
| Projections | Experimental (JSON only) | Continued refinement | Continued refinement |
| Autoscaling | Lag-based only | Lag-based | Cost-based (new) |
| Segment format | V9 + new features | V9 | V10 experimental |
| Kubernetes tasks | Not available | Limited | K8s client mode experimental |
| cgroup support | v1 only | v1 primarily | v2 fully supported |
| Window functions | MSQ support added | Improved | Mature |

## Upgrade Notes for 36.x

### From 35.x

1. **Straightforward upgrade** -- No major breaking changes from 35.x
2. **Test autoscaling** -- If using streaming, evaluate cost-based autoscaling in staging
3. **V10 format is opt-in** -- Does not affect existing segments; enable only after testing
4. **Kubernetes mode is opt-in** -- Existing MiddleManager/Indexer deployments are unaffected

### From 31.x-34.x

1. Review release notes for each intermediate version
2. Apply all security patches from intermediate versions
3. Test Dart query reports with your analytical workloads
4. Evaluate MSQ compaction engine improvements
5. Verify cgroup v2 compatibility if running in containers

### Recommended Configuration Changes

```properties
# Enable cost-based autoscaling for Kafka supervisors (evaluate in staging first)
# Configure in supervisor spec, not global properties

# Monitor new metrics
# query/dart/time       -- Dart query execution time
# query/dart/count      -- Dart query count

# For Kubernetes environments
# Ensure cgroup v2 detection is working:
# Check sys.servers table for correct available_processors and total_memory
```

## Known Issues in 36.0.0

- V10 segment format is experimental; avoid for critical production datasources
- Kubernetes client mode is experimental; monitor pod lifecycle carefully
- Cost-based autoscaling may need tuning for workloads with very bursty traffic patterns
- Dart query reports endpoint may return 404 for queries that completed before the report was generated
