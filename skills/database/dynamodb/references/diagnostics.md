# Amazon DynamoDB Diagnostics Reference

> 100+ AWS CLI commands for DynamoDB diagnostics, monitoring, and troubleshooting. Every command includes full syntax, what it reveals, key output fields, concerning thresholds, and remediation steps.

---

## Table Information and Schema

### 1. Describe Table (Full Schema, Capacity, Status)

```bash
aws dynamodb describe-table --table-name MyTable
```
**Shows:** Table status, key schema, attribute definitions, provisioned throughput, GSIs, LSIs, stream settings, item count, table size, table class, encryption, deletion protection.
**Key output fields:**
- `Table.TableStatus` -- ACTIVE, CREATING, UPDATING, DELETING, ARCHIVING
- `Table.ProvisionedThroughput.ReadCapacityUnits` / `.WriteCapacityUnits`
- `Table.ItemCount` -- Approximate item count (updated every ~6 hours)
- `Table.TableSizeBytes` -- Approximate table size
- `Table.GlobalSecondaryIndexes[].IndexStatus` -- ACTIVE, CREATING, UPDATING, DELETING
- `Table.GlobalSecondaryIndexes[].Backfilling` -- true if GSI is backfilling
- `Table.StreamSpecification.StreamEnabled` / `.StreamViewType`
- `Table.SSEDescription.Status` -- ENABLED/DISABLED, `.SSEType` -- AES256/KMS
- `Table.DeletionProtectionEnabled` -- true/false
- `Table.TableClassSummary.TableClass` -- STANDARD or STANDARD_INFREQUENT_ACCESS

**Concerning:** `TableStatus` not ACTIVE, GSI `IndexStatus` not ACTIVE, `Backfilling: true` on GSI.
**Remediation:** Wait for operations to complete. If stuck, check AWS Service Health Dashboard.

### 2. List All Tables

```bash
aws dynamodb list-tables
```
**Shows:** All DynamoDB table names in the current region.

```bash
# List tables with pagination (if > 100 tables)
aws dynamodb list-tables --max-items 100
aws dynamodb list-tables --starting-token <NextToken>
```

### 3. Describe Table with Query Filter (Key Schema Only)

```bash
aws dynamodb describe-table --table-name MyTable \
  --query 'Table.{KeySchema:KeySchema,AttributeDefinitions:AttributeDefinitions}'
```
**Shows:** Primary key schema and attribute type definitions only.

### 4. Check Table Provisioned vs. Consumed Capacity

```bash
aws dynamodb describe-table --table-name MyTable \
  --query 'Table.ProvisionedThroughput.{ReadCapacity:ReadCapacityUnits,WriteCapacity:WriteCapacityUnits,LastDecreaseTime:LastDecreaseDateTime,LastIncreaseTime:LastIncreaseDateTime}'
```
**Shows:** Current provisioned throughput and last scaling events.

### 5. List Table ARN

```bash
aws dynamodb describe-table --table-name MyTable --query 'Table.TableArn' --output text
```

### 6. Check Table Class

```bash
aws dynamodb describe-table --table-name MyTable \
  --query 'Table.TableClassSummary.TableClass' --output text
```
**Shows:** STANDARD or STANDARD_INFREQUENT_ACCESS.

### 7. Check Deletion Protection

```bash
aws dynamodb describe-table --table-name MyTable \
  --query 'Table.DeletionProtectionEnabled' --output text
```
**Shows:** Whether the table has deletion protection enabled.

### 8. Describe TTL Settings

```bash
aws dynamodb describe-time-to-live --table-name MyTable
```
**Key output fields:**
- `TimeToLiveDescription.TimeToLiveStatus` -- ENABLED, DISABLED, ENABLING, DISABLING
- `TimeToLiveDescription.AttributeName` -- The TTL attribute name
**Concerning:** Status ENABLING/DISABLING for extended periods.

### 9. Describe Continuous Backups (PITR)

```bash
aws dynamodb describe-continuous-backups --table-name MyTable
```
**Key output fields:**
- `ContinuousBackupsDescription.ContinuousBackupsStatus` -- ENABLED/DISABLED
- `ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus` -- ENABLED/DISABLED
- `ContinuousBackupsDescription.PointInTimeRecoveryDescription.EarliestRestorableDateTime`
- `ContinuousBackupsDescription.PointInTimeRecoveryDescription.LatestRestorableDateTime`
**Concerning:** PITR disabled on production tables.
**Remediation:** Enable PITR immediately on production tables.

### 10. Describe Endpoints

```bash
aws dynamodb describe-endpoints
```
**Shows:** Regional DynamoDB endpoint URLs. Useful for verifying SDK endpoint configuration.

### 11. Describe Account Limits

```bash
aws dynamodb describe-limits
```
**Key output fields:**
- `AccountMaxReadCapacityUnits` -- Maximum RCU across all tables in region
- `AccountMaxWriteCapacityUnits` -- Maximum WCU across all tables in region
- `TableMaxReadCapacityUnits` -- Maximum RCU for a single table
- `TableMaxWriteCapacityUnits` -- Maximum WCU for a single table
**Concerning:** Approaching account-level limits.
**Remediation:** Request a service quota increase via AWS Support or Service Quotas console.

---

## Item Operations

### 12. Get Single Item

```bash
aws dynamodb get-item --table-name MyTable \
  --key '{"PK": {"S": "USER#alice"}, "SK": {"S": "PROFILE#alice"}}' \
  --return-consumed-capacity TOTAL
```
**Shows:** The item and consumed capacity units.
**Key output fields:**
- `Item` -- The item attributes
- `ConsumedCapacity.CapacityUnits` -- RCU consumed
**Use `--consistent-read` for strongly consistent reads.**

### 13. Get Item with Projection Expression

```bash
aws dynamodb get-item --table-name MyTable \
  --key '{"PK": {"S": "USER#alice"}, "SK": {"S": "PROFILE#alice"}}' \
  --projection-expression "#n, email" \
  --expression-attribute-names '{"#n": "name"}' \
  --return-consumed-capacity TOTAL
```
**Shows:** Only the specified attributes (saves RCU for large items).

### 14. Put Item

```bash
aws dynamodb put-item --table-name MyTable \
  --item '{"PK": {"S": "USER#bob"}, "SK": {"S": "PROFILE#bob"}, "name": {"S": "Bob"}, "email": {"S": "bob@example.com"}}' \
  --return-consumed-capacity TOTAL
```
**Key output:** `ConsumedCapacity.CapacityUnits` -- WCU consumed.

### 15. Put Item with Condition (Prevent Overwrite)

```bash
aws dynamodb put-item --table-name MyTable \
  --item '{"PK": {"S": "USER#bob"}, "SK": {"S": "PROFILE#bob"}, "name": {"S": "Bob"}}' \
  --condition-expression "attribute_not_exists(PK)" \
  --return-consumed-capacity TOTAL
```
**Shows:** Fails with ConditionalCheckFailedException if item already exists.

### 16. Update Item

```bash
aws dynamodb update-item --table-name MyTable \
  --key '{"PK": {"S": "USER#alice"}, "SK": {"S": "PROFILE#alice"}}' \
  --update-expression "SET #n = :name, updated_at = :ts" \
  --expression-attribute-names '{"#n": "name"}' \
  --expression-attribute-values '{":name": {"S": "Alice Smith"}, ":ts": {"N": "1711900000"}}' \
  --return-values ALL_NEW \
  --return-consumed-capacity TOTAL
```
**Shows:** Updated item and consumed WCU.

### 17. Update Item with Atomic Counter

```bash
aws dynamodb update-item --table-name MyTable \
  --key '{"PK": {"S": "PAGE#home"}, "SK": {"S": "COUNTER"}}' \
  --update-expression "ADD view_count :inc" \
  --expression-attribute-values '{":inc": {"N": "1"}}' \
  --return-values UPDATED_NEW
```
**Shows:** Atomically incremented counter value. No read-before-write required.

### 18. Delete Item

```bash
aws dynamodb delete-item --table-name MyTable \
  --key '{"PK": {"S": "USER#alice"}, "SK": {"S": "PROFILE#alice"}}' \
  --return-consumed-capacity TOTAL
```

### 19. Delete Item with Condition

```bash
aws dynamodb delete-item --table-name MyTable \
  --key '{"PK": {"S": "USER#alice"}, "SK": {"S": "PROFILE#alice"}}' \
  --condition-expression "#s = :status" \
  --expression-attribute-names '{"#s": "status"}' \
  --expression-attribute-values '{":status": {"S": "inactive"}}' \
  --return-consumed-capacity TOTAL
```

### 20. Query by Partition Key

```bash
aws dynamodb query --table-name MyTable \
  --key-condition-expression "PK = :pk" \
  --expression-attribute-values '{":pk": {"S": "USER#alice"}}' \
  --return-consumed-capacity TOTAL
```
**Shows:** All items with the given partition key, sorted by sort key.
**Key output fields:**
- `Items` -- Matching items
- `Count` -- Number of items returned
- `ScannedCount` -- Number of items evaluated (before filter)
- `ConsumedCapacity.CapacityUnits` -- RCU consumed

### 21. Query with Sort Key Condition

```bash
aws dynamodb query --table-name MyTable \
  --key-condition-expression "PK = :pk AND begins_with(SK, :prefix)" \
  --expression-attribute-values '{":pk": {"S": "USER#alice"}, ":prefix": {"S": "ORDER#"}}' \
  --return-consumed-capacity TOTAL
```
**Shows:** Only items matching the sort key prefix (e.g., all orders for a user).

### 22. Query with Sort Key Range

```bash
aws dynamodb query --table-name MyTable \
  --key-condition-expression "PK = :pk AND SK BETWEEN :start AND :end" \
  --expression-attribute-values '{":pk": {"S": "USER#alice"}, ":start": {"S": "ORDER#2025-01"}, ":end": {"S": "ORDER#2025-12"}}' \
  --scan-index-forward \
  --return-consumed-capacity TOTAL
```
**Use `--no-scan-index-forward` for descending order.**

### 23. Query with Filter Expression

```bash
aws dynamodb query --table-name MyTable \
  --key-condition-expression "PK = :pk AND begins_with(SK, :prefix)" \
  --filter-expression "#s = :status" \
  --expression-attribute-names '{"#s": "status"}' \
  --expression-attribute-values '{":pk": {"S": "USER#alice"}, ":prefix": {"S": "ORDER#"}, ":status": {"S": "shipped"}}' \
  --return-consumed-capacity TOTAL
```
**Important:** Filter expressions are applied AFTER reading items from the table. RCU is consumed for all items matching the key condition, not just filtered results. High `ScannedCount` with low `Count` indicates filter inefficiency.

### 24. Query a GSI

```bash
aws dynamodb query --table-name MyTable \
  --index-name GSI1 \
  --key-condition-expression "GSI1PK = :gsi_pk" \
  --expression-attribute-values '{":gsi_pk": {"S": "alice@example.com"}}' \
  --return-consumed-capacity INDEXES
```
**Use `--return-consumed-capacity INDEXES` to see per-index capacity consumption.**

### 25. Query with Limit and Pagination

```bash
# First page
aws dynamodb query --table-name MyTable \
  --key-condition-expression "PK = :pk" \
  --expression-attribute-values '{":pk": {"S": "USER#alice"}}' \
  --limit 10

# Subsequent pages (use LastEvaluatedKey from previous response)
aws dynamodb query --table-name MyTable \
  --key-condition-expression "PK = :pk" \
  --expression-attribute-values '{":pk": {"S": "USER#alice"}}' \
  --limit 10 \
  --exclusive-start-key '{"PK": {"S": "USER#alice"}, "SK": {"S": "ORDER#2025-003"}}'
```
**Key output:** `LastEvaluatedKey` -- If present, more results exist. Absence means end of results.

### 26. Query with Select COUNT

```bash
aws dynamodb query --table-name MyTable \
  --key-condition-expression "PK = :pk" \
  --expression-attribute-values '{":pk": {"S": "USER#alice"}}' \
  --select COUNT
```
**Shows:** Only the count of matching items (no item data returned). Still consumes RCU.

### 27. Scan Table (Full Table Scan)

```bash
aws dynamodb scan --table-name MyTable \
  --return-consumed-capacity TOTAL \
  --max-items 100
```
**Warning:** Scans read every item in the table. Extremely expensive for large tables.
**Use only for:** Table export, data migration, debugging small tables.

### 28. Parallel Scan

```bash
# Segment 0 of 4
aws dynamodb scan --table-name MyTable \
  --total-segments 4 --segment 0 --return-consumed-capacity TOTAL

# Segment 1 of 4
aws dynamodb scan --table-name MyTable \
  --total-segments 4 --segment 1 --return-consumed-capacity TOTAL

# (Run all 4 segments in parallel)
```
**Shows:** Distributes the scan across multiple workers for faster completion. Use for large table exports.

### 29. Scan with Filter

```bash
aws dynamodb scan --table-name MyTable \
  --filter-expression "entity_type = :type" \
  --expression-attribute-values '{":type": {"S": "USER"}}' \
  --return-consumed-capacity TOTAL
```
**Warning:** Filter does not reduce RCU consumed. The full table is still scanned.

### 30. Batch Get Items

```bash
aws dynamodb batch-get-item --request-items '{
  "MyTable": {
    "Keys": [
      {"PK": {"S": "USER#alice"}, "SK": {"S": "PROFILE#alice"}},
      {"PK": {"S": "USER#bob"}, "SK": {"S": "PROFILE#bob"}}
    ],
    "ProjectionExpression": "PK, SK, #n, email",
    "ExpressionAttributeNames": {"#n": "name"}
  }
}' --return-consumed-capacity TOTAL
```
**Key output:** `UnprocessedKeys` -- If non-empty, some keys were not processed (retry with exponential backoff).
**Limit:** 100 items, 16 MB total response.

### 31. Batch Write Items

```bash
aws dynamodb batch-write-item --request-items '{
  "MyTable": [
    {"PutRequest": {"Item": {"PK": {"S": "USER#charlie"}, "SK": {"S": "PROFILE#charlie"}, "name": {"S": "Charlie"}}}},
    {"DeleteRequest": {"Key": {"PK": {"S": "USER#old"}, "SK": {"S": "PROFILE#old"}}}}
  ]
}' --return-consumed-capacity TOTAL
```
**Key output:** `UnprocessedItems` -- If non-empty, some items were not written (retry).
**Limit:** 25 items, 16 MB total request, 400 KB per item.

---

## Capacity and Throughput Management

### 32. Update Table Capacity (Provisioned Mode)

```bash
aws dynamodb update-table --table-name MyTable \
  --provisioned-throughput ReadCapacityUnits=500,WriteCapacityUnits=200
```
**Note:** Capacity decreases are limited to 4 per day (with certain exceptions). Increases are unlimited.

### 33. Switch to On-Demand Mode

```bash
aws dynamodb update-table --table-name MyTable \
  --billing-mode PAY_PER_REQUEST
```
**Note:** Can switch back to provisioned once per 24 hours.

### 34. Switch to Provisioned Mode

```bash
aws dynamodb update-table --table-name MyTable \
  --billing-mode PROVISIONED \
  --provisioned-throughput ReadCapacityUnits=100,WriteCapacityUnits=50
```

### 35. Check Current Billing Mode

```bash
aws dynamodb describe-table --table-name MyTable \
  --query 'Table.BillingModeSummary.BillingMode' --output text
```
**Shows:** PAY_PER_REQUEST or PROVISIONED.

### 36. Describe Auto-Scaling Settings

```bash
aws application-autoscaling describe-scalable-targets \
  --service-namespace dynamodb \
  --resource-ids "table/MyTable"
```
**Shows:** Min/max capacity, scaling role, target tracking configuration.

### 37. Describe Auto-Scaling Policies

```bash
aws application-autoscaling describe-scaling-policies \
  --service-namespace dynamodb \
  --resource-id "table/MyTable"
```
**Shows:** Target utilization, scale-up/down cooldown, alarm ARNs.

### 38. Register Auto-Scaling Target (Read)

```bash
aws application-autoscaling register-scalable-target \
  --service-namespace dynamodb \
  --resource-id "table/MyTable" \
  --scalable-dimension "dynamodb:table:ReadCapacityUnits" \
  --min-capacity 5 \
  --max-capacity 1000
```

### 39. Register Auto-Scaling Target (Write)

```bash
aws application-autoscaling register-scalable-target \
  --service-namespace dynamodb \
  --resource-id "table/MyTable" \
  --scalable-dimension "dynamodb:table:WriteCapacityUnits" \
  --min-capacity 5 \
  --max-capacity 500
```

### 40. Create Target Tracking Scaling Policy (Read)

```bash
aws application-autoscaling put-scaling-policy \
  --service-namespace dynamodb \
  --resource-id "table/MyTable" \
  --scalable-dimension "dynamodb:table:ReadCapacityUnits" \
  --policy-name "MyTable-read-scaling" \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "DynamoDBReadCapacityUtilization"
    },
    "ScaleInCooldown": 60,
    "ScaleOutCooldown": 60
  }'
```

### 41. Create Target Tracking Scaling Policy (Write)

```bash
aws application-autoscaling put-scaling-policy \
  --service-namespace dynamodb \
  --resource-id "table/MyTable" \
  --scalable-dimension "dynamodb:table:WriteCapacityUnits" \
  --policy-name "MyTable-write-scaling" \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "DynamoDBWriteCapacityUtilization"
    },
    "ScaleInCooldown": 60,
    "ScaleOutCooldown": 60
  }'
```

### 42. Register GSI Auto-Scaling Target

```bash
aws application-autoscaling register-scalable-target \
  --service-namespace dynamodb \
  --resource-id "table/MyTable/index/GSI1" \
  --scalable-dimension "dynamodb:index:ReadCapacityUnits" \
  --min-capacity 5 \
  --max-capacity 500
```

### 43. Describe Auto-Scaling Activity

```bash
aws application-autoscaling describe-scaling-activities \
  --service-namespace dynamodb \
  --resource-id "table/MyTable" \
  --max-results 10
```
**Shows:** Recent scaling actions (increases/decreases) with timestamps and causes.
**Concerning:** Frequent scaling (indicates volatile traffic) or "Failed" status.

---

## GSI Management

### 44. List GSIs on a Table

```bash
aws dynamodb describe-table --table-name MyTable \
  --query 'Table.GlobalSecondaryIndexes[].{Name:IndexName,Status:IndexStatus,Backfilling:Backfilling,RCU:ProvisionedThroughput.ReadCapacityUnits,WCU:ProvisionedThroughput.WriteCapacityUnits,ItemCount:ItemCount,SizeBytes:IndexSizeBytes}'
```

### 45. Create a GSI

```bash
aws dynamodb update-table --table-name MyTable \
  --attribute-definitions '[{"AttributeName": "GSI1PK", "AttributeType": "S"}, {"AttributeName": "GSI1SK", "AttributeType": "S"}]' \
  --global-secondary-index-updates '[{
    "Create": {
      "IndexName": "GSI1",
      "KeySchema": [
        {"AttributeName": "GSI1PK", "KeyType": "HASH"},
        {"AttributeName": "GSI1SK", "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"},
      "ProvisionedThroughput": {"ReadCapacityUnits": 100, "WriteCapacityUnits": 100}
    }
  }]'
```
**Note:** GSI creation triggers a backfill process that reads all existing items. Monitor with OnlineIndexPercentageProgress.

### 46. Delete a GSI

```bash
aws dynamodb update-table --table-name MyTable \
  --global-secondary-index-updates '[{
    "Delete": {"IndexName": "GSI1"}
  }]'
```

### 47. Update GSI Provisioned Capacity

```bash
aws dynamodb update-table --table-name MyTable \
  --global-secondary-index-updates '[{
    "Update": {
      "IndexName": "GSI1",
      "ProvisionedThroughput": {"ReadCapacityUnits": 200, "WriteCapacityUnits": 200}
    }
  }]'
```

### 48. Monitor GSI Backfill Progress

```bash
aws dynamodb describe-table --table-name MyTable \
  --query 'Table.GlobalSecondaryIndexes[?IndexName==`GSI1`].{Status:IndexStatus,Backfilling:Backfilling}' \
  --output table
```
**Also check CloudWatch metric `OnlineIndexPercentageProgress` for the specific GSI.**

---

## DynamoDB Streams

### 49. List Streams for a Table

```bash
aws dynamodbstreams list-streams --table-name MyTable
```
**Shows:** Stream ARNs associated with the table.

### 50. Describe a Stream

```bash
aws dynamodbstreams describe-stream --stream-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable/stream/2025-03-15T00:00:00.000
```
**Key output fields:**
- `StreamDescription.StreamStatus` -- ENABLED, DISABLED, ENABLING, DISABLING
- `StreamDescription.StreamViewType` -- KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES
- `StreamDescription.Shards[]` -- List of shards with sequence number ranges

### 51. Get Shard Iterator

```bash
aws dynamodbstreams get-shard-iterator \
  --stream-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable/stream/2025-03-15T00:00:00.000 \
  --shard-id shardId-00000001 \
  --shard-iterator-type TRIM_HORIZON
```
**Shard iterator types:**
- `TRIM_HORIZON` -- Start from oldest record
- `LATEST` -- Start from newest record
- `AT_SEQUENCE_NUMBER` -- Start at specific sequence number
- `AFTER_SEQUENCE_NUMBER` -- Start after specific sequence number

### 52. Get Stream Records

```bash
aws dynamodbstreams get-records --shard-iterator <shard-iterator-value>
```
**Key output fields:**
- `Records[].eventName` -- INSERT, MODIFY, REMOVE
- `Records[].dynamodb.Keys` -- Item key attributes
- `Records[].dynamodb.NewImage` -- Item after change (if stream view includes it)
- `Records[].dynamodb.OldImage` -- Item before change (if stream view includes it)
- `Records[].dynamodb.SequenceNumber` -- Stream sequence number
- `Records[].dynamodb.SizeBytes` -- Size of the stream record
- `NextShardIterator` -- Iterator for next batch (null if shard is closed)

### 53. Enable Streams on a Table

```bash
aws dynamodb update-table --table-name MyTable \
  --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES
```

### 54. Disable Streams on a Table

```bash
aws dynamodb update-table --table-name MyTable \
  --stream-specification StreamEnabled=false
```

### 55. Enable Kinesis Streaming Destination

```bash
aws dynamodb enable-kinesis-streaming-destination \
  --table-name MyTable \
  --stream-arn arn:aws:kinesis:us-east-1:123456789012:stream/my-kinesis-stream
```

### 56. Describe Kinesis Streaming Destination

```bash
aws dynamodb describe-kinesis-streaming-destination --table-name MyTable
```
**Shows:** Status of Kinesis Data Streams integration (ACTIVE, ENABLING, DISABLING, DISABLED).

### 57. Disable Kinesis Streaming Destination

```bash
aws dynamodb disable-kinesis-streaming-destination \
  --table-name MyTable \
  --stream-arn arn:aws:kinesis:us-east-1:123456789012:stream/my-kinesis-stream
```

---

## DAX (DynamoDB Accelerator)

### 58. Describe DAX Clusters

```bash
aws dax describe-clusters
```
**Key output fields:**
- `Clusters[].ClusterName`
- `Clusters[].Status` -- available, creating, deleting, modifying
- `Clusters[].TotalNodes` / `.ActiveNodes`
- `Clusters[].NodeType` -- e.g., dax.r5.large
- `Clusters[].ClusterDiscoveryEndpoint.Address` / `.Port`
- `Clusters[].SSEDescription.Status` -- ENABLED/DISABLED

### 59. Describe Specific DAX Cluster

```bash
aws dax describe-clusters --cluster-names my-dax-cluster
```

### 60. Describe DAX Parameter Groups

```bash
aws dax describe-parameter-groups
```

### 61. Describe DAX Parameters (Cache TTL, etc.)

```bash
aws dax describe-parameters --parameter-group-name default.dax1.0
```
**Key parameters:**
- `record-ttl-millis` -- Item cache TTL (default 300000 = 5 minutes)
- `query-ttl-millis` -- Query cache TTL (default 300000 = 5 minutes)

### 62. Describe DAX Subnet Groups

```bash
aws dax describe-subnet-groups
```
**Shows:** VPC and subnet configuration for DAX clusters.

### 63. List Tags on DAX Cluster

```bash
aws dax list-tags --resource-name arn:aws:dax:us-east-1:123456789012:cache/my-dax-cluster
```

### 64. Describe DAX Events

```bash
aws dax describe-events --source-type CLUSTER --duration 1440
```
**Shows:** DAX events from the last 24 hours (1440 minutes). Useful for diagnosing failovers and node issues.

### 65. Create DAX Cluster

```bash
aws dax create-cluster \
  --cluster-name my-dax-cluster \
  --node-type dax.r5.large \
  --replication-factor 3 \
  --iam-role-arn arn:aws:iam::123456789012:role/DAXServiceRole \
  --subnet-group-name my-dax-subnet-group \
  --sse-specification Enabled=true
```

---

## Global Tables

### 66. Describe Global Table

```bash
aws dynamodb describe-global-table --global-table-name MyGlobalTable
```
**Key output fields:**
- `GlobalTableDescription.GlobalTableStatus` -- ACTIVE, CREATING, UPDATING, DELETING
- `GlobalTableDescription.ReplicationGroup[].RegionName`
- `GlobalTableDescription.ReplicationGroup[].ReplicaStatus` -- ACTIVE, CREATING, UPDATING, DELETING

### 67. Describe Global Table Settings

```bash
aws dynamodb describe-global-table-settings --global-table-name MyGlobalTable
```
**Shows:** Per-region capacity settings and auto-scaling configuration.

### 68. List Global Tables

```bash
aws dynamodb list-global-tables
```

### 69. Describe Table Replica Settings (Version 2019.11.21)

```bash
aws dynamodb describe-table --table-name MyTable \
  --query 'Table.Replicas[].{Region:RegionName,Status:ReplicaStatus,KMSKeyId:KMSMasterKeyId}'
```
**Shows:** Replica status per region for current-version global tables.

### 70. Create Global Table Replica

```bash
aws dynamodb update-table --table-name MyTable \
  --replica-updates '[{"Create": {"RegionName": "eu-west-1"}}]'
```
**Note:** The table must have DynamoDB Streams enabled with NEW_AND_OLD_IMAGES.

### 71. Delete Global Table Replica

```bash
aws dynamodb update-table --table-name MyTable \
  --replica-updates '[{"Delete": {"RegionName": "eu-west-1"}}]'
```

### 72. Check Replication Latency (CloudWatch)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ReplicationLatency \
  --dimensions Name=TableName,Value=MyTable Name=ReceivingRegion,Value=eu-west-1 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum \
  --unit Milliseconds
```
**Concerning:** Average > 1000ms, Maximum > 5000ms.
**Remediation:** Check source region write throttling, GSI back-pressure, or AWS service issues.

### 73. Check Pending Replication Count

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name PendingReplicationCount \
  --dimensions Name=TableName,Value=MyTable Name=ReceivingRegion,Value=eu-west-1 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum Maximum
```
**Concerning:** Growing count over time.
**Remediation:** Check destination region capacity, GSI throttling in destination.

---

## Backups

### 74. List Backups

```bash
aws dynamodb list-backups --table-name MyTable
```
**Shows:** All on-demand backups for the table.

```bash
# List all backups across all tables
aws dynamodb list-backups

# Filter by time range
aws dynamodb list-backups \
  --time-range-lower-bound 2025-01-01T00:00:00Z \
  --time-range-upper-bound 2025-12-31T23:59:59Z
```

### 75. Create On-Demand Backup

```bash
aws dynamodb create-backup \
  --table-name MyTable \
  --backup-name MyTable-backup-$(date +%Y%m%d-%H%M%S)
```
**Shows:** BackupArn, BackupStatus (CREATING, AVAILABLE).

### 76. Describe Backup

```bash
aws dynamodb describe-backup --backup-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable/backup/01234567890
```
**Key output fields:**
- `BackupDescription.BackupDetails.BackupStatus` -- CREATING, AVAILABLE, DELETED
- `BackupDescription.BackupDetails.BackupSizeBytes`
- `BackupDescription.BackupDetails.BackupCreationDateTime`

### 77. Restore from On-Demand Backup

```bash
aws dynamodb restore-table-from-backup \
  --target-table-name MyTable-restored \
  --backup-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable/backup/01234567890
```
**Note:** Creates a new table. Does not restore auto-scaling, IAM policies, tags, PITR, TTL, or stream settings.

### 78. Delete Backup

```bash
aws dynamodb delete-backup --backup-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable/backup/01234567890
```

### 79. Enable Point-in-Time Recovery

```bash
aws dynamodb update-continuous-backups --table-name MyTable \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```

### 80. Restore to Point in Time

```bash
aws dynamodb restore-table-to-point-in-time \
  --source-table-name MyTable \
  --target-table-name MyTable-pit-restore \
  --restore-date-time 2025-03-15T12:00:00Z
```

```bash
# Restore to latest restorable time
aws dynamodb restore-table-to-point-in-time \
  --source-table-name MyTable \
  --target-table-name MyTable-pit-latest \
  --use-latest-restorable-time
```

---

## Export and Import

### 81. Export Table to S3

```bash
aws dynamodb export-table-to-point-in-time \
  --table-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable \
  --s3-bucket my-export-bucket \
  --s3-prefix dynamodb-exports/MyTable/ \
  --export-format DYNAMODB_JSON
```
**Formats:** DYNAMODB_JSON, ION.
**Note:** Requires PITR to be enabled. Export uses backup data (no impact on table performance).

### 82. Export with Incremental Option

```bash
aws dynamodb export-table-to-point-in-time \
  --table-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable \
  --s3-bucket my-export-bucket \
  --s3-prefix dynamodb-exports/MyTable/ \
  --export-format DYNAMODB_JSON \
  --export-type INCREMENTAL_EXPORT \
  --incremental-export-specification '{
    "ExportFromTime": "2025-03-14T00:00:00Z",
    "ExportToTime": "2025-03-15T00:00:00Z",
    "ExportViewType": "NEW_AND_OLD_IMAGES"
  }'
```

### 83. List Exports

```bash
aws dynamodb list-exports --table-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable
```

### 84. Describe Export

```bash
aws dynamodb describe-export --export-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable/export/01234567890
```
**Key output fields:**
- `ExportDescription.ExportStatus` -- IN_PROGRESS, COMPLETED, FAILED
- `ExportDescription.ItemCount`
- `ExportDescription.BilledSizeBytes`

### 85. Import Table from S3

```bash
aws dynamodb import-table \
  --s3-bucket-source '{
    "S3Bucket": "my-import-bucket",
    "S3KeyPrefix": "dynamodb-imports/MyTable/"
  }' \
  --input-format DYNAMODB_JSON \
  --table-creation-parameters '{
    "TableName": "MyTable-imported",
    "KeySchema": [
      {"AttributeName": "PK", "KeyType": "HASH"},
      {"AttributeName": "SK", "KeyType": "RANGE"}
    ],
    "AttributeDefinitions": [
      {"AttributeName": "PK", "AttributeType": "S"},
      {"AttributeName": "SK", "AttributeType": "S"}
    ],
    "BillingMode": "PAY_PER_REQUEST"
  }'
```
**Formats:** DYNAMODB_JSON, ION, CSV.

### 86. List Imports

```bash
aws dynamodb list-imports
```

### 87. Describe Import

```bash
aws dynamodb describe-import --import-arn arn:aws:dynamodb:us-east-1:123456789012:import/01234567890
```
**Key output fields:**
- `ImportTableDescription.ImportStatus` -- IN_PROGRESS, COMPLETED, FAILED, CANCELLING, CANCELLED
- `ImportTableDescription.ProcessedItemCount`
- `ImportTableDescription.ErrorCount`
- `ImportTableDescription.ProcessedSizeBytes`

---

## CloudWatch Metrics -- DynamoDB

### 88. Consumed Read Capacity Units

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=MyTable \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum Average Maximum
```
**Concerning:** Sum/period consistently > 80% of provisioned RCU (approaching throttling).
**Remediation:** Increase RCU, enable auto-scaling, or optimize read patterns.

### 89. Consumed Write Capacity Units

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedWriteCapacityUnits \
  --dimensions Name=TableName,Value=MyTable \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum Average Maximum
```

### 90. Read Throttle Events

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ReadThrottleEvents \
  --dimensions Name=TableName,Value=MyTable \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum
```
**Concerning:** Any Sum > 0 sustained over multiple periods.
**Remediation:** Check hot partitions (Contributor Insights), increase capacity, improve partition key design.

### 91. Write Throttle Events

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name WriteThrottleEvents \
  --dimensions Name=TableName,Value=MyTable \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum
```

### 92. Throttled Requests (Combined Read + Write)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ThrottledRequests \
  --dimensions Name=TableName,Value=MyTable Name=Operation,Value=PutItem \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```
**Available Operation dimensions:** PutItem, GetItem, UpdateItem, DeleteItem, Query, Scan, BatchWriteItem, BatchGetItem, TransactWriteItems, TransactGetItems.

### 93. System Errors (5xx)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name SystemErrors \
  --dimensions Name=TableName,Value=MyTable Name=Operation,Value=GetItem \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```
**Concerning:** Any persistent SystemErrors indicate DynamoDB service issues.
**Remediation:** Check AWS Service Health Dashboard. SDK should auto-retry.

### 94. User Errors (4xx)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```
**Concerning:** Spikes indicate application bugs (validation errors, missing table, etc.).
**Remediation:** Check application logs for specific error messages.

### 95. Successful Request Latency

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name SuccessfulRequestLatency \
  --dimensions Name=TableName,Value=MyTable Name=Operation,Value=GetItem \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average p50 p99
```
**Baseline:** GetItem p99 < 10ms, Query p99 < 20ms for small result sets.
**Concerning:** p99 > 50ms for GetItem, p99 > 100ms for Query.
**Remediation:** Check item sizes, reduce projection, use DAX for caching.

### 96. Returned Item Count

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ReturnedItemCount \
  --dimensions Name=TableName,Value=MyTable Name=Operation,Value=Query \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum
```
**Concerning:** Very high average (thousands+) may indicate missing GSIs or inefficient queries.

### 97. Conditional Check Failed Requests

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConditionalCheckFailedRequests \
  --dimensions Name=TableName,Value=MyTable \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```
**Concerning:** High rate indicates contention or race conditions.

### 98. Transaction Conflict Metric

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name TransactionConflict \
  --dimensions Name=TableName,Value=MyTable \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```
**Concerning:** Any persistent conflicts. Remediation: reduce transaction scope, add jitter.

### 99. GSI Throttle Events

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name WriteThrottleEvents \
  --dimensions Name=TableName,Value=MyTable Name=GlobalSecondaryIndexName,Value=GSI1 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum
```
**Concerning:** GSI throttling causes base table write throttling (back-pressure).
**Remediation:** Increase GSI provisioned capacity or switch to on-demand.

### 100. GSI Consumed Write Capacity

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedWriteCapacityUnits \
  --dimensions Name=TableName,Value=MyTable Name=GlobalSecondaryIndexName,Value=GSI1 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum Average Maximum
```

### 101. Account-Level Capacity Utilization

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name AccountProvisionedReadCapacityUtilization \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum
```
**Concerning:** > 80%. Remediation: Request account limit increase.

### 102. Account Max Reads/Writes Metric

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name AccountMaxReads \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum
```

### 103. Online Index Progress (GSI Creation)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name OnlineIndexPercentageProgress \
  --dimensions Name=TableName,Value=MyTable Name=GlobalSecondaryIndexName,Value=GSI1 \
  --start-time $(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum
```
**Concerning:** Stalled at a percentage for extended time. Check throttling on the table.

---

## Contributor Insights

### 104. Describe Contributor Insights

```bash
aws dynamodb describe-contributor-insights --table-name MyTable
```
**Key output:**
- `ContributorInsightsStatus` -- ENABLED, DISABLED, ENABLING, DISABLING, FAILED

### 105. Describe Contributor Insights for GSI

```bash
aws dynamodb describe-contributor-insights --table-name MyTable --index-name GSI1
```

### 106. Enable Contributor Insights

```bash
aws dynamodb update-contributor-insights \
  --table-name MyTable \
  --contributor-insights-action ENABLE
```

### 107. Enable Contributor Insights for GSI

```bash
aws dynamodb update-contributor-insights \
  --table-name MyTable \
  --index-name GSI1 \
  --contributor-insights-action ENABLE
```

### 108. Disable Contributor Insights

```bash
aws dynamodb update-contributor-insights \
  --table-name MyTable \
  --contributor-insights-action DISABLE
```

### 109. Get Top Accessed Keys (CloudWatch Insights Rule)

```bash
aws cloudwatch get-insight-rule-report \
  --rule-name "DynamoDB-Contributor-Insights-MyTable-PKC" \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --max-contributor-count 10
```
**Shows:** Top 10 most accessed partition keys. Identify hot partitions.

### 110. Get Top Throttled Keys

```bash
aws cloudwatch get-insight-rule-report \
  --rule-name "DynamoDB-Contributor-Insights-MyTable-PKT" \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --max-contributor-count 10
```
**Shows:** Top 10 most throttled partition keys. These are the hot keys causing throttling.
**Rule name convention:**
- `*-PKC` = Partition Key Capacity (most consumed)
- `*-PKT` = Partition Key Throttle (most throttled)
- `*-SKC` = Sort Key Capacity (most consumed)
- `*-SKT` = Sort Key Throttle (most throttled)

---

## PartiQL Operations

### 111. Execute PartiQL Statement

```bash
aws dynamodb execute-statement \
  --statement "SELECT * FROM \"MyTable\" WHERE PK = 'USER#alice' AND SK = 'PROFILE#alice'" \
  --return-consumed-capacity TOTAL
```

### 112. Execute PartiQL INSERT

```bash
aws dynamodb execute-statement \
  --statement "INSERT INTO \"MyTable\" VALUE {'PK': 'USER#charlie', 'SK': 'PROFILE#charlie', 'name': 'Charlie'}"
```

### 113. Execute PartiQL UPDATE

```bash
aws dynamodb execute-statement \
  --statement "UPDATE \"MyTable\" SET name = 'Alice Updated' WHERE PK = 'USER#alice' AND SK = 'PROFILE#alice'"
```

### 114. Execute PartiQL DELETE

```bash
aws dynamodb execute-statement \
  --statement "DELETE FROM \"MyTable\" WHERE PK = 'USER#old' AND SK = 'PROFILE#old'"
```

### 115. Batch Execute PartiQL Statements

```bash
aws dynamodb batch-execute-statement --statements '[
  {"Statement": "SELECT * FROM \"MyTable\" WHERE PK = '\''USER#alice'\'' AND SK = '\''PROFILE#alice'\''"},
  {"Statement": "SELECT * FROM \"MyTable\" WHERE PK = '\''USER#bob'\'' AND SK = '\''PROFILE#bob'\''"}
]'
```
**Limit:** 25 statements per batch.

### 116. PartiQL Query on GSI

```bash
aws dynamodb execute-statement \
  --statement "SELECT * FROM \"MyTable\".\"GSI1\" WHERE GSI1PK = 'alice@example.com'"
```

---

## Transactions (CLI)

### 117. TransactWriteItems

```bash
aws dynamodb transact-write-items --transact-items '[
  {
    "Put": {
      "TableName": "MyTable",
      "Item": {"PK": {"S": "ORDER#002"}, "SK": {"S": "META"}, "status": {"S": "placed"}, "total": {"N": "99.99"}},
      "ConditionExpression": "attribute_not_exists(PK)"
    }
  },
  {
    "Update": {
      "TableName": "MyTable",
      "Key": {"PK": {"S": "INVENTORY#sku-123"}, "SK": {"S": "META"}},
      "UpdateExpression": "SET stock = stock - :qty",
      "ConditionExpression": "stock >= :qty",
      "ExpressionAttributeValues": {":qty": {"N": "1"}}
    }
  },
  {
    "ConditionCheck": {
      "TableName": "MyTable",
      "Key": {"PK": {"S": "USER#alice"}, "SK": {"S": "PROFILE#alice"}},
      "ConditionExpression": "#s = :active",
      "ExpressionAttributeNames": {"#s": "status"},
      "ExpressionAttributeValues": {":active": {"S": "active"}}
    }
  }
]' --return-consumed-capacity TOTAL
```

### 118. TransactWriteItems with Idempotency Token

```bash
aws dynamodb transact-write-items --transact-items '[
  {
    "Put": {
      "TableName": "MyTable",
      "Item": {"PK": {"S": "ORDER#003"}, "SK": {"S": "META"}, "status": {"S": "placed"}}
    }
  }
]' --client-request-token "unique-idempotency-token-12345" \
  --return-consumed-capacity TOTAL
```
**Note:** Same token within 10 minutes returns the same result without re-executing.

### 119. TransactGetItems

```bash
aws dynamodb transact-get-items --transact-items '[
  {"Get": {"TableName": "MyTable", "Key": {"PK": {"S": "USER#alice"}, "SK": {"S": "PROFILE#alice"}}}},
  {"Get": {"TableName": "MyTable", "Key": {"PK": {"S": "ORDER#001"}, "SK": {"S": "META"}}}},
  {"Get": {"TableName": "Inventory", "Key": {"SKU": {"S": "sku-123"}}}}
]' --return-consumed-capacity TOTAL
```
**Shows:** Consistent snapshot across all items (even across tables).

---

## Tag Management

### 120. List Tags on a Table

```bash
aws dynamodb list-tags-of-resource \
  --resource-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable
```

### 121. Tag a Table

```bash
aws dynamodb tag-resource \
  --resource-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable \
  --tags Key=Environment,Value=production Key=Team,Value=backend Key=CostCenter,Value=12345
```

### 122. Untag a Table

```bash
aws dynamodb untag-resource \
  --resource-arn arn:aws:dynamodb:us-east-1:123456789012:table/MyTable \
  --tag-keys Environment Team
```

---

## TTL Management

### 123. Enable TTL

```bash
aws dynamodb update-time-to-live --table-name MyTable \
  --time-to-live-specification Enabled=true,AttributeName=expiry_time
```
**Note:** TTL attribute must be a Number type containing Unix epoch timestamps (seconds).

### 124. Disable TTL

```bash
aws dynamodb update-time-to-live --table-name MyTable \
  --time-to-live-specification Enabled=false,AttributeName=expiry_time
```
**Note:** Takes up to 1 hour to fully disable. Cannot re-enable for 1 hour after disabling.

---

## Table Management Operations

### 125. Create Table

```bash
aws dynamodb create-table \
  --table-name MyNewTable \
  --key-schema '[
    {"AttributeName": "PK", "KeyType": "HASH"},
    {"AttributeName": "SK", "KeyType": "RANGE"}
  ]' \
  --attribute-definitions '[
    {"AttributeName": "PK", "AttributeType": "S"},
    {"AttributeName": "SK", "AttributeType": "S"}
  ]' \
  --billing-mode PAY_PER_REQUEST \
  --tags '[{"Key": "Environment", "Value": "production"}]'
```

### 126. Create Table with Provisioned Capacity and GSI

```bash
aws dynamodb create-table \
  --table-name MyNewTable \
  --key-schema '[
    {"AttributeName": "PK", "KeyType": "HASH"},
    {"AttributeName": "SK", "KeyType": "RANGE"}
  ]' \
  --attribute-definitions '[
    {"AttributeName": "PK", "AttributeType": "S"},
    {"AttributeName": "SK", "AttributeType": "S"},
    {"AttributeName": "GSI1PK", "AttributeType": "S"},
    {"AttributeName": "GSI1SK", "AttributeType": "S"}
  ]' \
  --billing-mode PROVISIONED \
  --provisioned-throughput ReadCapacityUnits=100,WriteCapacityUnits=50 \
  --global-secondary-indexes '[{
    "IndexName": "GSI1",
    "KeySchema": [
      {"AttributeName": "GSI1PK", "KeyType": "HASH"},
      {"AttributeName": "GSI1SK", "KeyType": "RANGE"}
    ],
    "Projection": {"ProjectionType": "ALL"},
    "ProvisionedThroughput": {"ReadCapacityUnits": 100, "WriteCapacityUnits": 50}
  }]'
```

### 127. Delete Table

```bash
aws dynamodb delete-table --table-name MyOldTable
```
**Warning:** Irreversible. Ensure backups exist before deleting.

### 128. Enable Deletion Protection

```bash
aws dynamodb update-table --table-name MyTable \
  --deletion-protection-enabled
```

### 129. Disable Deletion Protection

```bash
aws dynamodb update-table --table-name MyTable \
  --no-deletion-protection-enabled
```

### 130. Change Table Class

```bash
aws dynamodb update-table --table-name MyTable \
  --table-class STANDARD_INFREQUENT_ACCESS
```

### 131. Wait for Table to Become Active

```bash
aws dynamodb wait table-exists --table-name MyNewTable
```
**Blocks until the table status is ACTIVE. Useful in automation scripts.**

---

## Cost Analysis

### 132. Get DynamoDB Cost (AWS Cost Explorer)

```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-03-01,End=2025-03-31 \
  --granularity MONTHLY \
  --metrics "BlendedCost" "UnblendedCost" "UsageQuantity" \
  --filter '{
    "Dimensions": {
      "Key": "SERVICE",
      "Values": ["Amazon DynamoDB"]
    }
  }'
```

### 133. Get DynamoDB Cost by Usage Type

```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-03-01,End=2025-03-31 \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by '[{"Type": "DIMENSION", "Key": "USAGE_TYPE"}]' \
  --filter '{
    "Dimensions": {
      "Key": "SERVICE",
      "Values": ["Amazon DynamoDB"]
    }
  }'
```
**Shows:** Cost breakdown by usage type (ReadCapacityUnit-Hrs, WriteCapacityUnit-Hrs, TimedStorage-ByteHrs, etc.).

### 134. Get Daily DynamoDB Cost Trend

```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-03-01,End=2025-03-31 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --filter '{
    "Dimensions": {
      "Key": "SERVICE",
      "Values": ["Amazon DynamoDB"]
    }
  }'
```
**Concerning:** Sudden cost increases indicate traffic spikes or capacity changes.

### 135. Get Reserved Capacity Utilization

```bash
aws ce get-reservation-utilization \
  --time-period Start=2025-03-01,End=2025-03-31 \
  --filter '{
    "Dimensions": {
      "Key": "SERVICE",
      "Values": ["Amazon DynamoDB"]
    }
  }'
```
**Concerning:** Utilization < 80% means reserved capacity is being wasted.

---

## Automation and Health Check Scripts

### 136. Health Check Script -- Table Status

```bash
#!/bin/bash
# Check all DynamoDB tables are ACTIVE
TABLES=$(aws dynamodb list-tables --query 'TableNames[]' --output text)
for TABLE in $TABLES; do
  STATUS=$(aws dynamodb describe-table --table-name "$TABLE" --query 'Table.TableStatus' --output text)
  if [ "$STATUS" != "ACTIVE" ]; then
    echo "WARNING: Table $TABLE status is $STATUS"
  else
    echo "OK: $TABLE is ACTIVE"
  fi
done
```

### 137. Health Check -- PITR Status for All Tables

```bash
#!/bin/bash
# Check PITR is enabled on all tables
TABLES=$(aws dynamodb list-tables --query 'TableNames[]' --output text)
for TABLE in $TABLES; do
  PITR=$(aws dynamodb describe-continuous-backups --table-name "$TABLE" \
    --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus' \
    --output text 2>/dev/null)
  if [ "$PITR" != "ENABLED" ]; then
    echo "WARNING: PITR disabled on $TABLE"
  else
    echo "OK: PITR enabled on $TABLE"
  fi
done
```

### 138. Health Check -- Throttling Detection

```bash
#!/bin/bash
# Check for throttling in the last hour on all tables
TABLES=$(aws dynamodb list-tables --query 'TableNames[]' --output text)
START=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)
END=$(date -u +%Y-%m-%dT%H:%M:%S)
for TABLE in $TABLES; do
  READ_THROTTLE=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/DynamoDB \
    --metric-name ReadThrottleEvents \
    --dimensions Name=TableName,Value="$TABLE" \
    --start-time "$START" --end-time "$END" \
    --period 3600 --statistics Sum \
    --query 'Datapoints[0].Sum' --output text 2>/dev/null)
  WRITE_THROTTLE=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/DynamoDB \
    --metric-name WriteThrottleEvents \
    --dimensions Name=TableName,Value="$TABLE" \
    --start-time "$START" --end-time "$END" \
    --period 3600 --statistics Sum \
    --query 'Datapoints[0].Sum' --output text 2>/dev/null)
  if [ "$READ_THROTTLE" != "None" ] && [ "$READ_THROTTLE" != "0.0" ] && [ -n "$READ_THROTTLE" ]; then
    echo "ALERT: $TABLE had $READ_THROTTLE read throttle events in the last hour"
  fi
  if [ "$WRITE_THROTTLE" != "None" ] && [ "$WRITE_THROTTLE" != "0.0" ] && [ -n "$WRITE_THROTTLE" ]; then
    echo "ALERT: $TABLE had $WRITE_THROTTLE write throttle events in the last hour"
  fi
done
```

### 139. Capacity Monitoring -- Utilization Report

```bash
#!/bin/bash
# Report read/write utilization for a table
TABLE="MyTable"
START=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)
END=$(date -u +%Y-%m-%dT%H:%M:%S)

# Get provisioned capacity
PROVISIONED=$(aws dynamodb describe-table --table-name "$TABLE" \
  --query 'Table.ProvisionedThroughput.{RCU:ReadCapacityUnits,WCU:WriteCapacityUnits}' --output json)
PROV_RCU=$(echo "$PROVISIONED" | python3 -c "import sys,json;print(json.load(sys.stdin)['RCU'])")
PROV_WCU=$(echo "$PROVISIONED" | python3 -c "import sys,json;print(json.load(sys.stdin)['WCU'])")

# Get consumed capacity
CONSUMED_RCU=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value="$TABLE" \
  --start-time "$START" --end-time "$END" --period 3600 --statistics Average \
  --query 'Datapoints[0].Average' --output text)
CONSUMED_WCU=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB --metric-name ConsumedWriteCapacityUnits \
  --dimensions Name=TableName,Value="$TABLE" \
  --start-time "$START" --end-time "$END" --period 3600 --statistics Average \
  --query 'Datapoints[0].Average' --output text)

echo "Table: $TABLE"
echo "Provisioned RCU: $PROV_RCU | Consumed RCU (avg): $CONSUMED_RCU"
echo "Provisioned WCU: $PROV_WCU | Consumed WCU (avg): $CONSUMED_WCU"
```

### 140. Hot Partition Detection Script

```bash
#!/bin/bash
# Identify hot partitions using Contributor Insights
TABLE="MyTable"
START=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)
END=$(date -u +%Y-%m-%dT%H:%M:%S)

echo "=== Top Accessed Keys (Last Hour) ==="
aws cloudwatch get-insight-rule-report \
  --rule-name "DynamoDB-Contributor-Insights-${TABLE}-PKC" \
  --start-time "$START" --end-time "$END" \
  --period 3600 --max-contributor-count 10 \
  --query 'Contributors[].{Key:Keys[0],Count:ApproximateAggregateValue}' \
  --output table 2>/dev/null || echo "Contributor Insights not enabled. Enable with:"
echo "  aws dynamodb update-contributor-insights --table-name $TABLE --contributor-insights-action ENABLE"

echo ""
echo "=== Top Throttled Keys (Last Hour) ==="
aws cloudwatch get-insight-rule-report \
  --rule-name "DynamoDB-Contributor-Insights-${TABLE}-PKT" \
  --start-time "$START" --end-time "$END" \
  --period 3600 --max-contributor-count 10 \
  --query 'Contributors[].{Key:Keys[0],Count:ApproximateAggregateValue}' \
  --output table 2>/dev/null || echo "Contributor Insights not enabled."
```

### 141. GSI Health Check

```bash
#!/bin/bash
# Check all GSIs on a table for throttling and status
TABLE="MyTable"
START=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)
END=$(date -u +%Y-%m-%dT%H:%M:%S)

GSIS=$(aws dynamodb describe-table --table-name "$TABLE" \
  --query 'Table.GlobalSecondaryIndexes[].IndexName' --output text 2>/dev/null)

if [ -z "$GSIS" ]; then
  echo "No GSIs found on $TABLE"
  exit 0
fi

for GSI in $GSIS; do
  STATUS=$(aws dynamodb describe-table --table-name "$TABLE" \
    --query "Table.GlobalSecondaryIndexes[?IndexName=='$GSI'].IndexStatus" --output text)
  THROTTLE=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/DynamoDB --metric-name WriteThrottleEvents \
    --dimensions Name=TableName,Value="$TABLE" Name=GlobalSecondaryIndexName,Value="$GSI" \
    --start-time "$START" --end-time "$END" --period 3600 --statistics Sum \
    --query 'Datapoints[0].Sum' --output text 2>/dev/null)
  echo "GSI: $GSI | Status: $STATUS | Write Throttle Events (1hr): ${THROTTLE:-0}"
done
```

### 142. Backup Compliance Check

```bash
#!/bin/bash
# Verify all production tables have recent backups
TABLES=$(aws dynamodb list-tables --query 'TableNames[]' --output text)
CUTOFF=$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S)

for TABLE in $TABLES; do
  LATEST_BACKUP=$(aws dynamodb list-backups --table-name "$TABLE" \
    --query 'BackupSummaries | sort_by(@, &BackupCreationDateTime) | [-1].BackupCreationDateTime' \
    --output text 2>/dev/null)
  if [ "$LATEST_BACKUP" = "None" ] || [ -z "$LATEST_BACKUP" ]; then
    echo "WARNING: No backups found for $TABLE"
  elif [[ "$LATEST_BACKUP" < "$CUTOFF" ]]; then
    echo "WARNING: $TABLE last backup is older than 7 days ($LATEST_BACKUP)"
  else
    echo "OK: $TABLE last backup: $LATEST_BACKUP"
  fi
done
```

### 143. Comprehensive Table Report

```bash
#!/bin/bash
# Generate a comprehensive report for a DynamoDB table
TABLE="MyTable"

echo "============================================"
echo "DynamoDB Table Report: $TABLE"
echo "Generated: $(date -u)"
echo "============================================"

# Table info
aws dynamodb describe-table --table-name "$TABLE" \
  --query 'Table.{Status:TableStatus,ItemCount:ItemCount,SizeBytes:TableSizeBytes,BillingMode:BillingModeSummary.BillingMode,TableClass:TableClassSummary.TableClass,DeletionProtection:DeletionProtectionEnabled,StreamEnabled:StreamSpecification.StreamEnabled}' \
  --output table

# Key schema
echo ""
echo "--- Key Schema ---"
aws dynamodb describe-table --table-name "$TABLE" \
  --query 'Table.KeySchema[]' --output table

# GSIs
echo ""
echo "--- Global Secondary Indexes ---"
aws dynamodb describe-table --table-name "$TABLE" \
  --query 'Table.GlobalSecondaryIndexes[].{Name:IndexName,Status:IndexStatus,KeySchema:KeySchema[].AttributeName,Projection:Projection.ProjectionType}' \
  --output table 2>/dev/null || echo "No GSIs"

# TTL
echo ""
echo "--- TTL Settings ---"
aws dynamodb describe-time-to-live --table-name "$TABLE" --output table

# PITR
echo ""
echo "--- Point-in-Time Recovery ---"
aws dynamodb describe-continuous-backups --table-name "$TABLE" \
  --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription' --output table

# Tags
echo ""
echo "--- Tags ---"
TABLE_ARN=$(aws dynamodb describe-table --table-name "$TABLE" --query 'Table.TableArn' --output text)
aws dynamodb list-tags-of-resource --resource-arn "$TABLE_ARN" --output table

# Contributor Insights
echo ""
echo "--- Contributor Insights ---"
aws dynamodb describe-contributor-insights --table-name "$TABLE" \
  --query '{Status:ContributorInsightsStatus}' --output table 2>/dev/null

echo ""
echo "============================================"
echo "Report complete."
```

---

## Troubleshooting Playbooks

### Playbook: ProvisionedThroughputExceededException

**Step 1: Identify scope**
```bash
# Is it reads or writes?
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
  --metric-name ReadThrottleEvents --dimensions Name=TableName,Value=MyTable \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Sum

aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
  --metric-name WriteThrottleEvents --dimensions Name=TableName,Value=MyTable \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Sum
```

**Step 2: Is it a GSI?**
```bash
# Check each GSI for throttling
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
  --metric-name WriteThrottleEvents \
  --dimensions Name=TableName,Value=MyTable Name=GlobalSecondaryIndexName,Value=GSI1 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Sum
```

**Step 3: Hot partition?**
```bash
# Enable Contributor Insights and check
aws dynamodb update-contributor-insights --table-name MyTable --contributor-insights-action ENABLE
# Wait 5 minutes, then:
aws cloudwatch get-insight-rule-report \
  --rule-name "DynamoDB-Contributor-Insights-MyTable-PKT" \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --max-contributor-count 10
```

**Step 4: Immediate relief**
```bash
# Option A: Increase provisioned capacity
aws dynamodb update-table --table-name MyTable \
  --provisioned-throughput ReadCapacityUnits=1000,WriteCapacityUnits=500

# Option B: Switch to on-demand
aws dynamodb update-table --table-name MyTable --billing-mode PAY_PER_REQUEST
```

**Step 5: Long-term fix** -- Redesign partition key if hot partition detected. See write sharding strategies in best-practices.md.

### Playbook: High Latency (SuccessfulRequestLatency)

**Step 1: Identify which operations are slow**
```bash
for OP in GetItem PutItem UpdateItem DeleteItem Query Scan; do
  echo "--- $OP ---"
  aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
    --metric-name SuccessfulRequestLatency \
    --dimensions Name=TableName,Value=MyTable Name=Operation,Value=$OP \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 \
    --statistics Average p99 --query 'Datapoints | sort_by(@, &Timestamp) | [-1]'
done
```

**Step 2: Check item sizes (large items = more latency)**
```bash
aws dynamodb get-item --table-name MyTable \
  --key '{"PK": {"S": "suspect-key"}, "SK": {"S": "suspect-sk"}}' \
  --return-consumed-capacity TOTAL \
  --query 'ConsumedCapacity'
```

**Step 3: Check if scans are involved**
```bash
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
  --metric-name ReturnedItemCount \
  --dimensions Name=TableName,Value=MyTable Name=Operation,Value=Scan \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum Average
```

**Step 4: Consider DAX for read-heavy patterns or optimize query patterns.**

### Playbook: GSI Propagation Lag

**Step 1: Verify GSI is active and not backfilling**
```bash
aws dynamodb describe-table --table-name MyTable \
  --query 'Table.GlobalSecondaryIndexes[?IndexName==`GSI1`].{Status:IndexStatus,Backfilling:Backfilling}'
```

**Step 2: Check GSI throttling (the most common cause)**
```bash
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
  --metric-name WriteThrottleEvents \
  --dimensions Name=TableName,Value=MyTable Name=GlobalSecondaryIndexName,Value=GSI1 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 60 --statistics Sum
```

**Step 3: Compare base table writes vs. GSI writes**
```bash
# Base table writes
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
  --metric-name ConsumedWriteCapacityUnits --dimensions Name=TableName,Value=MyTable \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum

# GSI writes
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
  --metric-name ConsumedWriteCapacityUnits \
  --dimensions Name=TableName,Value=MyTable Name=GlobalSecondaryIndexName,Value=GSI1 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum
```

**Step 4: Increase GSI capacity or switch to on-demand.**

### Playbook: Transaction Failures

**Step 1: Identify conflict rate**
```bash
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
  --metric-name TransactionConflict --dimensions Name=TableName,Value=MyTable \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum
```

**Step 2: Check conditional check failures**
```bash
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
  --metric-name ConditionalCheckFailedRequests --dimensions Name=TableName,Value=MyTable \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum
```

**Step 3: Review application logic**
- Are multiple processes writing to the same items?
- Can transactions be scoped to fewer items?
- Is exponential backoff with jitter implemented?

**Step 4: Mitigations**
- Use idempotency tokens (ClientRequestToken)
- Reduce transaction scope
- Use UpdateExpression ADD/SET instead of read-modify-write
- Implement optimistic locking with version numbers
