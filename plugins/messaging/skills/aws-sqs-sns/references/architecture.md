# AWS SQS/SNS Architecture Reference

## SQS Standard Queues

- At-least-once delivery (occasional duplicates)
- Best-effort ordering (generally FIFO, not guaranteed)
- Nearly unlimited throughput
- 120,000 in-flight message limit
- Message retention: 60 seconds to 14 days (default 4 days)
- Max message size: 256 KB (Extended Client Library for S3 overflow)

## SQS FIFO Queues

- Exactly-once processing via deduplication
- Strict FIFO within each MessageGroupId
- Queue name must end with `.fifo`
- Default: 300 msg/s (send/receive/delete) without batching, 3,000 with batching (batch of 10)
- High-throughput mode: up to 70,000 transactions/s (supported regions)
- 20,000 in-flight message limit

### MessageGroupId
Mandatory for FIFO. Same group ID = strict order, one-at-a-time processing. Different groups process in parallel. Key throughput lever: use many distinct group IDs.

### Deduplication
- **Content-based** (`ContentBasedDeduplication: true`): SHA-256 of message body
- **Explicit** `MessageDeduplicationId`: caller-provided unique token
- 5-minute deduplication window

## Visibility Timeout

When consumer receives a message, it becomes invisible for the visibility timeout duration.

| Setting | Value |
|---|---|
| Default | 30 seconds |
| Minimum | 0 seconds |
| Maximum | 12 hours |

If consumer does not delete before timeout, message reappears. Extend with `ChangeMessageVisibility`. 12-hour absolute cap from first receipt.

## Dead-Letter Queues

```json
{
  "deadLetterTargetArn": "arn:aws:sqs:...:MyQueue-DLQ",
  "maxReceiveCount": 5
}
```

- FIFO queue DLQ must also be FIFO
- Standard queue DLQ must also be standard
- Same account and region
- Standard: enqueue timestamp preserved. FIFO: timestamp resets on move.
- Set DLQ retention longer than source retention

### DLQ Redrive
```bash
aws sqs start-message-move-task \
  --source-arn arn:aws:sqs:...:MyQueue-DLQ \
  --destination-arn arn:aws:sqs:...:MyQueue
```

### Redrive Allow Policy
```json
{"redrivePermission": "byQueue", "sourceQueueArns": ["arn:..."]}
```

## Long Polling vs Short Polling

**Long polling (recommended):** `WaitTimeSeconds=1-20`. Queries all servers. Reduces empty responses, lowers cost.

**Short polling (default):** `WaitTimeSeconds=0`. May return empty even when messages exist.

```bash
aws sqs set-queue-attributes --queue-url ... \
  --attributes '{"ReceiveMessageWaitTimeSeconds":"20"}'
```

## SNS Topics

### Standard Topics
High throughput. At-least-once delivery. Best-effort ordering. Fan-out to SQS, Lambda, HTTP/S, email, SMS, Firehose.

### FIFO Topics
Strict ordering. Exactly-once delivery. Name must end with `.fifo`. Only SQS FIFO queues can subscribe.

### Subscriptions
Require confirmation (except SQS and Lambda which auto-confirm). Raw message delivery available for SQS and HTTP/S.

## SNS Message Filtering

Filter policies on subscription attributes or body:

```json
{
  "event_type": ["order_placed", "order_updated"],
  "amount": [{"numeric": [">=", 100]}],
  "region": [{"prefix": "us-"}],
  "status": [{"anything-but": ["cancelled"]}]
}
```

- Multiple conditions = AND. Multiple values per key = OR.
- Changes take up to 15 minutes to propagate.
- Filter policy scope: `MessageAttributes` (default) or `MessageBody`.

## SNS Delivery Retry

**AWS-managed endpoints (SQS, Lambda):** 100,015 attempts over 23 days.
**HTTP/HTTPS:** 50 attempts over 6 hours (customizable backoff).

### SNS DLQ
Configured per subscription (not per topic):
```bash
aws sns set-subscription-attributes --subscription-arn ... \
  --attribute-name RedrivePolicy \
  --attribute-value '{"deadLetterTargetArn":"arn:aws:sqs:...:MyDLQ"}'
```

## Encryption

**SSE-SQS:** AWS-managed keys. Free. Default for new queues.
**SSE-KMS:** Customer-managed keys. Audit via CloudTrail. `KmsDataKeyReusePeriodSeconds`: 60-86,400s (default 300s).

## Resource Policies

Required for cross-account access and SNS-to-SQS integration:
```json
{
  "Effect": "Allow",
  "Principal": {"Service": "sns.amazonaws.com"},
  "Action": "sqs:SendMessage",
  "Resource": "arn:aws:sqs:...:MyQueue",
  "Condition": {"ArnEquals": {"aws:SourceArn": "arn:aws:sns:...:MyTopic"}}
}
```

## Message Attributes

Up to 10 metadata attributes per message. Types: String, Number, Binary. Used for SNS filter policy matching.

## Delay Queues

Queue-level delay: `DelaySeconds` (0-900s). Per-message delay: `DelaySeconds` in `SendMessage` (not supported on FIFO).

## Extended Client Library

For payloads > 256 KB. Stores in S3; SQS message contains pointer. Available for Java and Python.
