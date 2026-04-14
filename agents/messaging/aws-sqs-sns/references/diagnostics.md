# AWS SQS/SNS Diagnostics Reference

## Visibility Timeout Issues

### Messages Reappearing After Processing
**Cause:** Processing takes longer than visibility timeout. Message becomes visible before deletion.

**Resolution:**
1. Increase visibility timeout: `aws sqs set-queue-attributes --attributes '{"VisibilityTimeout":"300"}'`
2. Extend dynamically: `aws sqs change-message-visibility --visibility-timeout 300 --receipt-handle "..."`
3. For Lambda: set visibility timeout >= 6x Lambda function timeout

### Messages Never Reappearing
**Cause:** Visibility timeout too long; consumer crashed without deleting; message stuck invisible.

**Resolution:** Check `ApproximateNumberOfMessagesNotVisible` metric. If consistently high, consumers are crashing without deleting. Fix consumer error handling.

## DLQ Analysis

### Investigate DLQ Messages
```bash
# Check DLQ depth
aws sqs get-queue-attributes --queue-url ... --attribute-names ApproximateNumberOfMessagesVisible

# Read DLQ messages (peek without deleting)
aws sqs receive-message --queue-url DLQ_URL --max-number-of-messages 10 \
  --attribute-names All --message-attribute-names All --visibility-timeout 0
```

### Common DLQ Causes
| Symptom | Cause | Resolution |
|---|---|---|
| Consistent message failures | Bug in consumer processing logic | Fix code; test with sample DLQ message |
| Transient failures during outage | Downstream service was unavailable | Redrive after service recovery |
| Serialization errors | Message format changed; consumer cannot parse | Update consumer; implement versioned parsing |
| Permission errors | Consumer lost IAM permissions | Restore permissions |

### DLQ Redrive
```bash
# Move messages back to source queue
aws sqs start-message-move-task \
  --source-arn arn:aws:sqs:...:MyQueue-DLQ \
  --destination-arn arn:aws:sqs:...:MyQueue

# Check move task status
aws sqs list-message-move-tasks --source-arn arn:aws:sqs:...:MyQueue-DLQ
```

## FIFO Throughput Issues

### Low Throughput Despite High-Throughput Mode
| Cause | Resolution |
|---|---|
| Single MessageGroupId | Use many distinct group IDs per entity |
| Content-based dedup with identical bodies | Use explicit MessageDeduplicationId |
| Consumer not deleting fast enough | Increase consumer count; reduce processing time |
| Region does not support high-throughput | Use supported region (us-east-1, us-west-2, eu-west-1) |

### Deduplication Rejects
**Symptom:** Messages accepted (200 OK) but not delivered -- they are duplicates within 5-minute window.

**Diagnosis:** Check if same `MessageDeduplicationId` was sent within 5 minutes.

**Resolution:** Ensure unique dedup IDs per unique message. After 5 minutes, same ID is treated as new message.

## Lambda ESM Failures

### Lambda Not Processing Messages
```bash
# Check event source mapping
aws lambda list-event-source-mappings --function-name MyFunction

# Check mapping state
aws lambda get-event-source-mapping --uuid <UUID>
```

| Symptom | Cause | Resolution |
|---|---|---|
| Mapping state: Disabled | Manual or error disable | Re-enable; check for sustained failures |
| No invocations | Mapping paused or no messages | Check queue depth; verify mapping is enabled |
| Throttled invocations | Lambda concurrency limit reached | Increase reserved concurrency; reduce batch size |
| All messages going to DLQ | Lambda timeout or crash | Increase Lambda timeout; check memory; fix code |

### Batch Processing Failures
Without `ReportBatchItemFailures`, a single failed message causes entire batch retry:

```python
# Enable partial batch response
def handler(event, context):
    failures = []
    for record in event['Records']:
        try:
            process(record)
        except Exception:
            failures.append({"itemIdentifier": record['messageId']})
    return {"batchItemFailures": failures}
```

## CloudWatch Metrics

### SQS Metrics

| Metric | Alert On | Description |
|---|---|---|
| `ApproximateNumberOfMessagesVisible` | Growing trend | Backlog depth |
| `ApproximateNumberOfMessagesNotVisible` | Near in-flight limit | Messages being processed |
| `ApproximateAgeOfOldestMessage` | > SLA threshold | Processing delay |
| `NumberOfMessagesSent` | Drop to 0 | Producer stopped sending |
| `NumberOfMessagesReceived` | Drop to 0 | Consumer stopped polling |
| `NumberOfMessagesDeleted` | Drop to 0 | Consumer not completing |
| `NumberOfEmptyReceives` | High count | Not using long polling |
| `SentMessageSize` | Approaching 256 KB | Consider Extended Client |

### SNS Metrics

| Metric | Alert On | Description |
|---|---|---|
| `NumberOfNotificationsDelivered` | Drop in rate | Delivery failures |
| `NumberOfNotificationsFailed` | > 0 | Subscription endpoint failures |
| `NumberOfNotificationsFilteredOut` | Unexpected count | Filter policy mismatch |

### CloudWatch Alarm (DLQ)
```yaml
DLQAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmDescription: Messages in DLQ
    Namespace: AWS/SQS
    MetricName: ApproximateNumberOfMessagesVisible
    Dimensions:
      - Name: QueueName
        Value: !GetAtt MyDLQ.QueueName
    Statistic: Sum
    Period: 60
    EvaluationPeriods: 1
    Threshold: 1
    ComparisonOperator: GreaterThanOrEqualToThreshold
```

## Throughput Troubleshooting

### Standard Queue Not Scaling
Standard queues have virtually unlimited throughput. If throughput seems limited:
- Check consumer count (more consumers = more throughput)
- Verify `MaxNumberOfMessages` in `ReceiveMessage` (batch up to 10)
- Check for throttling in consumer downstream systems

### FIFO Queue Bottleneck
```bash
# Check queue attributes
aws sqs get-queue-attributes --queue-url ... --attribute-names All
```

Verify `FifoThroughputLimit` is set to `perMessageGroupId` and `DeduplicationScope` is `messageGroup` for high-throughput mode.

## CLI Diagnostic Commands

```bash
# Queue overview
aws sqs get-queue-attributes --queue-url ... --attribute-names All

# Message peek (without removing)
aws sqs receive-message --queue-url ... --visibility-timeout 0

# Purge queue (irreversible)
aws sqs purge-queue --queue-url ...

# List all queues
aws sqs list-queues

# Check DLQ redrive progress
aws sqs list-message-move-tasks --source-arn ...

# SNS subscription status
aws sns list-subscriptions-by-topic --topic-arn ...
```
