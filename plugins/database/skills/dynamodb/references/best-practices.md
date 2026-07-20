# Amazon DynamoDB Best Practices Reference

## Single-Table Design Methodology

### Step-by-Step Process

1. **Document all access patterns** -- List every read and write operation your application performs. Include:
   - Operation name (e.g., "Get user profile by user ID")
   - Parameters (e.g., user_id)
   - Expected frequency (e.g., 1,000 reads/sec)
   - Consistency requirement (eventual or strong)
   - Sort/filter requirements

2. **Identify entities and relationships** -- Map out entity types (User, Order, Product) and their relationships (one-to-many, many-to-many).

3. **Design the primary key** -- Choose PK and SK that satisfy the most critical and highest-volume access patterns:
   - PK should be high-cardinality and evenly distributed
   - SK enables range queries and hierarchical relationships
   - Use entity type prefixes: `PK = "USER#<id>"`, `SK = "PROFILE#<id>"` or `SK = "ORDER#<date>"`

4. **Map remaining access patterns to GSIs** -- Each GSI serves one or more additional access patterns.

5. **Validate with sample data** -- Create a spreadsheet with 20-50 sample items and verify every access pattern works.

### Single-Table Design Patterns

**Pattern 1: Entity Store (Adjacency List)**
```
PK              SK                  Type      Attributes...
USER#u1         #METADATA           User      name=Alice, email=a@b.com
USER#u1         ORDER#2025-001      Order     total=99.99, status=shipped
USER#u1         ORDER#2025-002      Order     total=45.00, status=pending
ORDER#2025-001  ITEM#sku-100        LineItem  qty=2, price=49.99
ORDER#2025-001  ITEM#sku-200        LineItem  qty=1, price=0.01
```

Access patterns served:
- Get user: `PK = USER#u1, SK = #METADATA`
- Get user orders: `PK = USER#u1, SK begins_with ORDER#`
- Get user orders in date range: `PK = USER#u1, SK between ORDER#2025-01 and ORDER#2025-12`
- Get order items: `PK = ORDER#2025-001, SK begins_with ITEM#`

**Pattern 2: GSI Overloading**
```
Base table:
PK              SK                GSI1PK              GSI1SK
USER#u1         #METADATA         a@b.com             USER#u1
USER#u1         ORDER#2025-001    shipped              ORDER#2025-001
PRODUCT#sku100  #METADATA         Electronics          PRODUCT#sku100

GSI1 enables:
- Get user by email: GSI1PK = "a@b.com"
- Get all shipped orders: GSI1PK = "shipped", GSI1SK begins_with "ORDER#"
- Get products by category: GSI1PK = "Electronics", GSI1SK begins_with "PRODUCT#"
```

**Pattern 3: Composite Sort Key**
```
PK              SK
ORG#acme        STATUS#active#DATE#2025-03-15#EMP#e1
ORG#acme        STATUS#active#DATE#2025-03-16#EMP#e2
ORG#acme        STATUS#inactive#DATE#2024-12-01#EMP#e3

Access patterns:
- All active employees: PK=ORG#acme, SK begins_with "STATUS#active"
- Active employees in date range: PK=ORG#acme, SK between "STATUS#active#DATE#2025-03" and "STATUS#active#DATE#2025-04"
```

**Pattern 4: Write Sharding for High-Throughput Writes**
```
PK                      SK              data...
VOTES#election1#0       VOTE#timestamp  voter_id, choice
VOTES#election1#1       VOTE#timestamp  voter_id, choice
...
VOTES#election1#9       VOTE#timestamp  voter_id, choice

Write: Hash voter_id to shard 0-9, write to that shard
Read (aggregate): Query all 10 shards in parallel, aggregate results
```

**Pattern 5: Inverted Index GSI**
```
Base table:
PK              SK
EMPLOYEE#e1     DEPT#engineering
EMPLOYEE#e1     PROJECT#alpha
EMPLOYEE#e2     DEPT#marketing

GSI (inverted: SK as GSI-PK, PK as GSI-SK):
- Get all employees in engineering: GSI-PK = "DEPT#engineering"
- Get all employees on project alpha: GSI-PK = "PROJECT#alpha"
```

### When NOT to Use Single-Table Design

Single-table design adds complexity. Consider multi-table design when:
- **Small development team** unfamiliar with DynamoDB patterns
- **Simple access patterns** that do not benefit from denormalization
- **Evolving schema** where access patterns change frequently (early-stage startups)
- **Analytics/reporting** requirements (better served by export to S3 + Athena)
- **Many-to-many relationships** that would require excessive GSI overloading

Alex DeBrie's guidance: "If you have fewer than 4-5 access patterns, single-table design might not be worth the complexity."

## Partition Key Selection

### High-Cardinality Keys

Good partition keys have many distinct values and evenly distribute traffic:

| Use Case | Good Partition Key | Bad Partition Key |
|---|---|---|
| User data | `user_id` (UUID or unique identifier) | `country` (low cardinality) |
| IoT sensor data | `device_id` + time bucket | `sensor_type` (few types) |
| E-commerce orders | `order_id` | `status` (only a few values) |
| Multi-tenant SaaS | `tenant_id#entity_type` | `entity_type` alone |
| Chat messages | `channel_id` | `date` (all channels on same partition) |

### Write Sharding Strategies

When a partition key is inherently hot (e.g., a viral post receiving millions of votes):

**Strategy 1: Random suffix**
```
PK = "POST#viral-post-123#" + random(0, N-1)
```
- Write: Append random shard number to PK
- Read: Query all N shards in parallel, aggregate results client-side
- Trade-off: Faster writes, slower reads

**Strategy 2: Calculated suffix**
```
PK = "POST#viral-post-123#" + hash(voter_id) % N
```
- Write: Deterministic shard based on voter ID
- Read: Can read specific shard if voter ID is known, or all shards for aggregation
- Trade-off: Deterministic, enables single-shard reads

**Strategy 3: Time-based bucketing**
```
PK = "METRIC#cpu-usage#" + floor(timestamp / 3600)  // hourly bucket
```
- Write: Current hour always receives writes
- Read: Query specific hours for time-range queries
- Trade-off: Simple, natural for time-series data

### Hot Partition Detection

1. **Enable Contributor Insights** on the table
2. **Check CloudWatch metrics:**
   - `ThrottledRequests` -- Any throttling indicates potential hot partition
   - `ConsumedReadCapacityUnits` / `ConsumedWriteCapacityUnits` -- Compare per-partition vs. average
3. **Contributor Insights report** shows the top accessed and throttled partition keys
4. **CloudWatch Logs Insights** -- If using Lambda triggers, analyze invocation patterns

## GSI Design Patterns

### GSI Best Practices

1. **Project only what you need:**
   - `KEYS_ONLY` -- Cheapest. Use when you only need to find primary keys via the GSI, then fetch full items from the base table.
   - `INCLUDE` -- Project specific attributes needed for the query. Avoids base table fetch.
   - `ALL` -- Most expensive. Use only when the GSI is the primary read path and you need all attributes.

2. **GSI capacity planning:**
   - In provisioned mode, GSI capacity must be set separately
   - GSI WCU should be >= base table WCU (for attributes projected to the GSI)
   - Under-provisioned GSI causes back-pressure throttling on the base table
   - In on-demand mode, GSI scales automatically (no separate capacity management)

3. **Sparse indexes for subset queries:**
   - Only items with the GSI key attribute appear in the GSI
   - Use for status-based queries (e.g., only "pending" orders have `GSI_PK = "PENDING"`)
   - Dramatically reduces GSI size and cost

4. **GSI overloading:**
   - Use generic key names (`GSI1PK`, `GSI1SK`) that hold different values per entity type
   - One GSI can serve multiple access patterns for different entity types
   - Maximum 20 GSIs per table -- overloading reduces the number needed

5. **Avoid GSI hot partitions:**
   - Same partition key design principles apply to GSIs
   - A GSI with a low-cardinality partition key (e.g., `status`) will have hot partitions
   - Combine with a sort key to distribute: `GSI_PK = status, GSI_SK = timestamp`

### GSI vs. LSI Decision

| Factor | GSI | LSI |
|---|---|---|
| When to create | Any time | Table creation only |
| Partition key | Different from base table | Same as base table |
| Consistency | Eventually consistent only | Eventually or strongly consistent |
| Capacity | Separate provisioned capacity | Shares base table capacity |
| Size limit | No item collection limit | 10 GB per partition key value |
| Maximum per table | 20 | 5 |
| **Recommendation** | **Preferred in almost all cases** | **Avoid unless strongly consistent reads on alternate sort key are required** |

## Capacity Planning

### Estimating Capacity Requirements

**Step 1: Calculate item sizes**
```
String: length of UTF-8 encoded value + 3 bytes (attribute name overhead)
Number: approximately (number of significant digits / 2) + 1 byte
Binary: length of raw binary + 3 bytes
Boolean: 1 byte
Null: 1 byte
List/Map: sum of nested element sizes + 3 bytes overhead per element + 3 bytes for the attribute
Set: sum of element sizes + attribute name overhead
```

**Step 2: Calculate RCU**
```
Reads per second * ceil(item_size_KB / 4) = RCU (strongly consistent)
Reads per second * ceil(item_size_KB / 4) * 0.5 = RCU (eventually consistent)
Reads per second * ceil(item_size_KB / 4) * 2 = RCU (transactional)
```

**Step 3: Calculate WCU**
```
Writes per second * ceil(item_size_KB / 1) = WCU (standard)
Writes per second * ceil(item_size_KB / 1) * 2 = WCU (transactional)
```

**Step 4: Account for GSIs**
- Each GSI adds write cost proportional to the projected item size
- Each GSI adds read capacity for queries served by the GSI

### Cost Optimization Strategies

**1. Right-size capacity mode:**
| Workload Pattern | Recommended Mode | Why |
|---|---|---|
| Predictable, steady | Provisioned + auto-scaling | Lower cost than on-demand |
| Spiky, unpredictable | On-demand | No throttling, no over-provisioning |
| Predictable base + occasional spikes | Provisioned + auto-scaling (generous max) | Cost-effective with burst protection |
| New application (unknown traffic) | On-demand initially | Switch to provisioned once patterns emerge |

**2. Reserved capacity (provisioned mode only):**
- 1-year commitment: ~53% discount on provisioned throughput
- 3-year commitment: ~77% discount on provisioned throughput
- Purchase in increments of 100 RCU/WCU
- Reserved capacity applies at the account level per region (not per table)

**3. Table class selection:**
- Standard: ~$0.25 per GB-month storage
- Standard-IA: ~$0.10 per GB-month storage, higher per-request cost
- Break-even: if read/write costs are < 15-20% of storage costs, Standard-IA saves money

**4. Reduce item sizes:**
- Use short attribute names (save bytes per item)
- Compress large string/binary attributes (gzip)
- Store large objects in S3, reference from DynamoDB
- Remove unnecessary attributes

**5. Optimize read patterns:**
- Use eventually consistent reads (50% cheaper than strongly consistent)
- Use projection expressions to return only needed attributes (reduces data transfer)
- Use Query instead of Scan (targeted vs. full table)
- Use DAX for read-heavy, repetitive access patterns

**6. Optimize write patterns:**
- Use BatchWriteItem for bulk operations (reduces per-request overhead)
- Use UpdateItem with SET/REMOVE instead of full PutItem (only updates changed attributes)
- Use TTL for automatic deletion (free, no WCU consumed)
- Use conditional writes to avoid unnecessary writes

**7. Monitor and alert:**
- Set CloudWatch alarms on ConsumedReadCapacityUnits and ConsumedWriteCapacityUnits
- Track cost with AWS Cost Explorer (filter by DynamoDB)
- Review monthly cost trends for unexpected growth

## Monitoring Setup

### Essential CloudWatch Metrics

| Metric | What It Measures | Warning Threshold | Critical Threshold |
|---|---|---|---|
| `ConsumedReadCapacityUnits` | Actual read throughput | > 70% of provisioned | > 90% of provisioned |
| `ConsumedWriteCapacityUnits` | Actual write throughput | > 70% of provisioned | > 90% of provisioned |
| `ReadThrottleEvents` | Read requests rejected due to throttling | > 0 sustained | > 100/min |
| `WriteThrottleEvents` | Write requests rejected due to throttling | > 0 sustained | > 100/min |
| `ThrottledRequests` | Total throttled API calls | > 0 sustained | > 100/min |
| `SystemErrors` | DynamoDB internal errors (5xx) | > 0 sustained | > 10/min |
| `UserErrors` | Client errors (4xx, e.g., validation) | Monitor trend | Spike investigation |
| `SuccessfulRequestLatency` | p50/p99 latency per operation | p99 > 10ms | p99 > 50ms |
| `ReturnedItemCount` | Items returned per Query/Scan | High counts indicate missing indexes | Very high = scan |
| `ReturnedBytes` | Bytes returned per operation | Monitor for large responses | > 1MB per request |
| `ConditionalCheckFailedRequests` | Failed conditional writes | Monitor trend | High = contention |
| `TransactionConflict` | Conflicting transactions | > 0 sustained | > 10/min |
| `AccountProvisionedReadCapacityUtilization` | Account-level read utilization | > 70% | > 90% |
| `AccountProvisionedWriteCapacityUtilization` | Account-level write utilization | > 70% | > 90% |
| `OnlineIndexPercentageProgress` | GSI backfill progress | Monitor during creation | Stalled at % |
| `PendingReplicationCount` (Global Tables) | Items pending replication | > 0 sustained | Growing trend |
| `ReplicationLatency` (Global Tables) | Cross-region lag | > 1 second | > 5 seconds |

### CloudWatch Dashboard Template

Create a dashboard with these widget groups:
1. **Throughput:** ConsumedRead/WriteCapacityUnits vs. provisioned (line chart)
2. **Throttling:** ReadThrottleEvents + WriteThrottleEvents (line chart, alarm on > 0)
3. **Latency:** SuccessfulRequestLatency p50 and p99 for GetItem, PutItem, Query (line chart)
4. **Errors:** SystemErrors + UserErrors (line chart)
5. **Global Tables:** ReplicationLatency + PendingReplicationCount (if applicable)
6. **GSI Health:** Per-GSI throttle events and consumed capacity

### Contributor Insights Setup

Enable Contributor Insights on tables experiencing throttling:

```bash
# Enable on base table
aws dynamodb update-contributor-insights \
  --table-name MyTable \
  --contributor-insights-action ENABLE

# Enable on GSI
aws dynamodb update-contributor-insights \
  --table-name MyTable \
  --index-name MyGSI \
  --contributor-insights-action ENABLE
```

Contributor Insights shows:
- Top 10 most accessed partition keys (by request count)
- Top 10 most throttled partition keys
- Updated every 5 minutes

## Security Hardening

### IAM Best Practices

1. **Least privilege:** Grant only the DynamoDB actions needed
```json
{
  "Effect": "Allow",
  "Action": [
    "dynamodb:GetItem",
    "dynamodb:Query",
    "dynamodb:PutItem",
    "dynamodb:UpdateItem",
    "dynamodb:DeleteItem"
  ],
  "Resource": [
    "arn:aws:dynamodb:us-east-1:123456789012:table/MyTable",
    "arn:aws:dynamodb:us-east-1:123456789012:table/MyTable/index/*"
  ]
}
```

2. **Fine-grained access control (item-level):**
```json
{
  "Effect": "Allow",
  "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query"],
  "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/UserData",
  "Condition": {
    "ForAllValues:StringEquals": {
      "dynamodb:LeadingKeys": ["${cognito-identity.amazonaws.com:sub}"]
    }
  }
}
```

3. **Attribute-level access control:**
```json
{
  "Effect": "Allow",
  "Action": ["dynamodb:GetItem", "dynamodb:Query"],
  "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/Employees",
  "Condition": {
    "ForAllValues:StringEquals": {
      "dynamodb:Attributes": ["employee_id", "name", "department"]
    },
    "StringEqualsIfExists": {
      "dynamodb:Select": "SPECIFIC_ATTRIBUTES"
    }
  }
}
```

4. **Deny dangerous operations:**
```json
{
  "Effect": "Deny",
  "Action": [
    "dynamodb:DeleteTable",
    "dynamodb:UpdateTable"
  ],
  "Resource": "arn:aws:dynamodb:*:*:table/Production*"
}
```

### VPC Endpoint Configuration

```bash
# Create gateway endpoint for DynamoDB
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-abc123 \
  --service-name com.amazonaws.us-east-1.dynamodb \
  --route-table-ids rtb-abc123 rtb-def456

# Restrict DynamoDB access to VPC endpoint only (bucket policy style)
# Add this condition to IAM policies:
{
  "Condition": {
    "StringEquals": {
      "aws:sourceVpce": "vpce-abc123"
    }
  }
}
```

### Encryption Best Practices

1. **Use customer managed keys (CMK) for sensitive data** -- Gives you control over key rotation, deletion, and cross-account access
2. **Enable CloudTrail logging** for KMS key usage -- Audit who decrypted what
3. **Enable DynamoDB data plane API logging** in CloudTrail for compliance workloads
4. **Rotate CMKs annually** (automatic rotation recommended)

## Backup Strategies

### Backup Tiers

| Strategy | RPO | Cost | Complexity |
|---|---|---|---|
| On-demand backup | Point-in-time (when triggered) | Low | Low |
| PITR | Any second in last 35 days | Higher (continuous) | Low |
| Export to S3 | Point-in-time (when triggered) | S3 storage costs | Medium |
| Global tables | Near-real-time (cross-region) | Region replication costs | Medium |
| Custom (Streams to S3) | Near-real-time | Variable | High |

### Recommended Backup Strategy

1. **Enable PITR on all production tables** -- 35-day recovery window, protects against accidental deletes
2. **Schedule daily on-demand backups** for long-term retention (retained until deleted)
3. **Weekly export to S3** for analytics and cross-account access
4. **Global tables** for disaster recovery (RPO near zero)
5. **Tag all backups** with retention policy metadata

### Restore Considerations

- Restore always creates a new table (no in-place restore)
- Restore includes table data but NOT:
  - Auto-scaling settings
  - IAM policies
  - CloudWatch alarms
  - Tags
  - Stream settings
  - TTL settings
  - PITR settings
- After restore, you must reconfigure these settings manually (or via CloudFormation/Terraform)

## Migration from RDBMS

### Migration Strategy

**Phase 1: Assessment**
1. Catalog all RDBMS tables, relationships, and queries
2. Identify access patterns (every SQL query your application runs)
3. Evaluate which patterns map well to DynamoDB (key-value lookups, simple queries) vs. poorly (complex joins, ad-hoc analytics)

**Phase 2: Data Model Design**
1. Convert entity-relationship model to DynamoDB single-table (or multi-table) design
2. Map every SQL query to a DynamoDB access pattern
3. Design partition keys, sort keys, and GSIs
4. Validate with sample data

**Phase 3: Migration Execution**
1. **Dual-write period:** Application writes to both RDBMS and DynamoDB
2. **Backfill:** Export RDBMS data, transform, and import into DynamoDB (use DynamoDB Import from S3 or AWS DMS)
3. **Validation:** Compare query results between RDBMS and DynamoDB
4. **Cutover:** Switch reads to DynamoDB, then stop writing to RDBMS

**AWS Database Migration Service (DMS):**
- Supports continuous replication from RDBMS to DynamoDB
- Source: MySQL, PostgreSQL, Oracle, SQL Server, MariaDB
- Handles schema transformation and data type mapping
- Useful for gradual migration with minimal downtime

### Common RDBMS-to-DynamoDB Mapping

| RDBMS Concept | DynamoDB Equivalent |
|---|---|
| Table | Table (but single-table design may combine multiple) |
| Row | Item |
| Column | Attribute |
| Primary key | Partition key + sort key |
| Foreign key | Denormalized (embedded or duplicated data) |
| JOIN | Pre-joined via single-table design or GSI |
| INDEX | GSI or LSI |
| Transaction | TransactWriteItems / TransactGetItems |
| View | GSI (materialized, not virtual) |
| Stored procedure | Lambda function (triggered by Streams) |
| Auto-increment ID | UUID (uuid()) or ULID/KSUID for sortable IDs |

## Operational Runbooks

### Runbook: Table Throttling

**Symptoms:** ThrottledRequests > 0, application errors with ProvisionedThroughputExceededException

**Diagnosis:**
1. Check CloudWatch: Which metric is throttling? (ReadThrottleEvents vs. WriteThrottleEvents)
2. Is it the base table or a GSI? (Check per-GSI metrics)
3. Enable Contributor Insights to identify hot keys
4. Check if auto-scaling is configured and working

**Resolution:**
- **Short-term:** Increase provisioned capacity or switch to on-demand
- **Medium-term:** Fix hot partition keys (write sharding, better key design)
- **Long-term:** Redesign data model if fundamentally imbalanced

### Runbook: GSI Lag

**Symptoms:** GSI query returns stale data, application inconsistency

**Diagnosis:**
1. Check GSI throttle events (WriteThrottleEvents on the GSI)
2. Check base table write volume vs. GSI write capacity
3. Check OnlineIndexPercentageProgress if GSI is being backfilled

**Resolution:**
- Increase GSI provisioned capacity
- Switch to on-demand mode
- Reduce GSI projection size (fewer attributes = less write amplification)

### Runbook: Transaction Conflicts

**Symptoms:** TransactionCanceledException, high ConditionalCheckFailedRequests

**Diagnosis:**
1. Identify which items are conflicting (application logs)
2. Check if multiple processes/services are writing to the same items
3. Check transaction sizes (larger transactions have more conflict surface)

**Resolution:**
- Reduce transaction scope (fewer items per transaction)
- Implement exponential backoff with jitter
- Use optimistic locking with version attributes
- Redesign to reduce contention (e.g., use UpdateExpression ADD instead of read-modify-write)

### Runbook: Large Item Size

**Symptoms:** ValidationException (item size > 400 KB), slow reads

**Diagnosis:**
1. Identify which items are approaching 400 KB
2. Check for large List/Map attributes or large string values

**Resolution:**
- Compress large attributes before storing
- Move large data to S3 (store S3 key in DynamoDB)
- Split large items into multiple items (e.g., chunk pattern)
- Remove unnecessary attributes

### Runbook: Capacity Planning for Launch

**Pre-launch checklist:**
1. Load test with realistic traffic patterns
2. Verify auto-scaling is configured with appropriate min/max
3. Pre-warm the table (if provisioned): set capacity to expected peak 24 hours before launch
4. Consider on-demand mode for launch day (switch back to provisioned after traffic stabilizes)
5. Set up CloudWatch alarms for throttling
6. Enable Contributor Insights
7. Enable PITR
8. Verify IAM policies are correct
9. Test backup and restore procedures
10. Document rollback plan
