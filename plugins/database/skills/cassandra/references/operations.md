# Cassandra Operations

## JVM Tuning

Cassandra runs on the JVM and is sensitive to garbage collection behavior:

**Heap sizing (cassandra-env.sh or jvm.options):**
```bash
# For nodes with <= 32GB RAM, typical heap:
-Xms8G
-Xmx8G
# Never exceed 50% of RAM for heap -- the rest is used for OS page cache and off-heap structures

# For large datasets (>100GB per node):
-Xms16G
-Xmx16G
# 31GB is the practical max due to compressed oops threshold
```

**Garbage collector selection:**
- **G1GC** (recommended for Cassandra 3.11+, 4.x): good throughput, manageable pause times
- **ZGC** (Cassandra 4.1+, Java 11+): ultra-low pause times, experimental in 4.x
- **Shenandoah** (alternative low-pause): supported on some JDK distributions

**G1GC tuning (jvm11-server.options):**
```
-XX:+UseG1GC
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:MaxGCPauseMillis=300
-XX:InitiatingHeapOccupancyPercent=70
-XX:ParallelGCThreads=<num_cpu_cores>
-XX:ConcGCThreads=<num_cpu_cores / 4>
```

**Off-heap memory:**
Cassandra uses significant off-heap memory for:
- Bloom filters
- Partition index summary
- Compression offset maps
- Key cache
- Chunk cache (4.0+)
- Networking buffers

**Rule of thumb:** Total process memory = heap + off-heap + OS page cache. Plan for heap to be 25-50% of total RAM.

## Multi-Datacenter Replication

```cql
-- Create keyspace with multi-DC replication
CREATE KEYSPACE global_ks WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'us-east': 3,
    'eu-west': 3
};
```

**Configuration requirements:**
- Each node must have `GossipingPropertyFileSnitch` or a cloud-specific snitch
- `cassandra-rackdc.properties` on each node:
  ```
  dc=us-east
  rack=rack1
  ```
- Use `LOCAL_QUORUM` consistency level for reads and writes (isolates latency to local DC)
- Use `EACH_QUORUM` for writes when cross-DC consistency is required (higher latency)

**Multi-DC topology considerations:**
- RF=3 per datacenter is the standard (total 6 replicas for 2 DCs)
- Remote DC replicas are updated asynchronously (from the client's perspective when using LOCAL_QUORUM)
- One DC can serve reads independently if the other DC goes down entirely
- Schema changes propagate via gossip; use `nodetool describecluster` to check for schema disagreements
