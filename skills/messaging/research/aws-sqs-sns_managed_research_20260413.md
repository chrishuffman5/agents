# AWS SQS and SNS — Managed Research Document

**Research Date:** 2026-04-13  
**Purpose:** Reference for building technology skill files on AWS SQS and SNS  
**Coverage:** Architecture, features, patterns, management, best practices, diagnostics

---

## Table of Contents

1. [SQS Architecture](#sqs-architecture)
2. [SQS Features](#sqs-features)
3. [SNS Architecture](#sns-architecture)
4. [SNS Features](#sns-features)
5. [Patterns](#patterns)
6. [Management — CLI, IaC, Monitoring](#management)
7. [Best Practices](#best-practices)
8. [Diagnostics and Troubleshooting](#diagnostics)

---

## 1. SQS Architecture

### Overview

Amazon Simple Queue Service (SQS) is a fully managed message queuing service that decouples and scales microservices, distributed systems, and serverless applications. Producers send messages; consumers poll and process them; consumers explicitly delete messages after successful processing.

### Standard Queues

- **Delivery guarantee:** At-least-once delivery — a message is delivered at least once, but occasionally more than once
- **Ordering:** Best-effort ordering — messages are generally delivered in the order sent, but order is not guaranteed due to the distributed architecture
- **Throughput:** Nearly unlimited — designed for massively parallel workloads
- **Use when:** Order and exactly-once delivery are not required; high throughput is a priority

Standard queues have an in-flight message limit of approximately 120,000 messages. Messages that exceed this limit cause a `OverLimit` error.

### FIFO Queues

- **Delivery guarantee:** Exactly-once processing — duplicates are not introduced into the queue
- **Ordering:** Strict FIFO within each message group
- **Naming:** Queue name **must** end with `.fifo` (e.g., `orders.fifo`)
- **Default throughput:** 300 messages/second (send, receive, delete) without batching; 3,000 messages/second with batching (batch of 10)
- **High throughput mode:** Up to 70,000 transactions per second per API action in supported regions (us-east-1, us-west-2, eu-west-1 and others). Enable via console or SetQueueAttributes.
- **Use when:** Order matters, financial transactions, inventory management, command sequencing

#### Message Group ID

- `MessageGroupId` is a mandatory attribute for FIFO queues
- Messages with the same group ID are processed strictly in order, one at a time
- Different group IDs are processed in parallel — a key throughput lever
- Best practice: use many distinct group IDs to distribute load across partitions

#### Deduplication

Two methods, mutually exclusive per message:

1. **Content-based deduplication** (`ContentBasedDeduplication: true`): SQS generates a SHA-256 hash of the message body. Identical bodies within the 5-minute deduplication window are de-duplicated.
2. **Explicit `MessageDeduplicationId`**: Caller provides a unique token per `SendMessage` call. Any message with the same deduplication ID sent within 5 minutes of the first successful send is accepted but not delivered.

Deduplication window: **5 minutes**. After 5 minutes, an identical message is treated as a new message.

### Visibility Timeout

When a consumer receives a message, SQS makes it temporarily invisible to other consumers for the **visibility timeout** duration.

| Parameter | Value |
|-----------|-------|
| Default | 30 seconds |
| Minimum | 0 seconds |
| Maximum | 12 hours (43,200 seconds) |
| Maximum total (from first receive) | 12 hours — not reset by extensions |

**Key behaviors:**
- If the consumer does not delete the message before the timeout expires, the message becomes visible again and can be received by another consumer
- Setting visibility timeout to 0 makes a message immediately available (effectively a poison-pill test)
- Use `ChangeMessageVisibility` to extend the timeout programmatically during long processing
- The 12-hour cap is absolute from the time of first receipt — extensions do not reset the clock

```bash
# Extend visibility timeout via CLI
aws sqs change-message-visibility \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue \
  --receipt-handle "AQEBsX..." \
  --visibility-timeout 300
```

### Dead-Letter Queues (DLQ)

A DLQ is a separate SQS queue where messages are moved after a configurable number of failed processing attempts.

**Redrive Policy:**
```json
{
  "deadLetterTargetArn": "arn:aws:sqs:us-east-1:123456789012:MyQueue-DLQ",
  "maxReceiveCount": 5
}
```

- `maxReceiveCount`: How many times a message can be received before being moved to the DLQ. Recommended minimum: 5
- The DLQ of a FIFO queue must also be a FIFO queue
- The DLQ of a standard queue must also be a standard queue
- Keep source queue and DLQ in the same AWS account and region

**Message retention in DLQ:**
- Standard queues: Enqueue timestamp is preserved from the source queue. Messages expire based on original enqueue time, not when they were moved.
- FIFO queues: Enqueue timestamp **resets** when moved to DLQ.
- Best practice: Set DLQ retention period longer than source queue retention period to avoid messages expiring before investigation.

**DLQ Redrive (recovery):** Messages in the DLQ can be moved back to the source queue for reprocessing using the SQS console or `StartMessageMoveTask` API.

**Redrive Allow Policy:** Controls which source queues can use this queue as a DLQ:
```json
{
  "redrivePermission": "byQueue",
  "sourceQueueArns": ["arn:aws:sqs:us-east-1:123456789012:SourceQueue"]
}
```
Options: `allowAll` (default), `denyAll`, `byQueue` (up to 10 ARNs)

### Message Retention

| Setting | Min | Default | Max |
|---------|-----|---------|-----|
| MessageRetentionPeriod | 60 seconds | 4 days (345,600 s) | 14 days (1,209,600 s) |

After the retention period expires, the message is automatically deleted from the queue.

### Long Polling vs. Short Polling

**Short polling** (default, `WaitTimeSeconds=0`):
- Queries a subset of servers immediately
- May return empty responses even when messages exist
- Higher API call costs

**Long polling** (`WaitTimeSeconds=1–20`):
- Queries all servers
- Returns response only when at least one message is available or wait time expires
- Reduces empty receives, lowers cost, improves latency

Best practice: Always use long polling (set `ReceiveMessageWaitTimeSeconds` to 20 at the queue level or per `ReceiveMessage` call).

```bash
# Enable long polling at queue level
aws sqs set-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue \
  --attributes '{"ReceiveMessageWaitTimeSeconds":"20"}'

# Long polling per receive call
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue \
  --wait-time-seconds 20 \
  --max-number-of-messages 10
```

---

## 2. SQS Features

### Message Attributes

Each message can carry up to 10 metadata attributes (not counted toward message body size limit). Each attribute has:
- **Name**: String, 1–256 chars
- **Type**: `String`, `Number`, `Binary`, or custom types (e.g., `String.json`, `Number.int`)
- **Value**: Corresponding data

```bash
aws sqs send-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue \
  --message-body "Order placed" \
  --message-attributes '{
    "OrderId": {"DataType":"String","StringValue":"ORD-12345"},
    "Amount":  {"DataType":"Number","StringValue":"99.99"},
    "Priority":{"DataType":"String","StringValue":"high"}
  }'
```

### Message Timers (Per-Message Delay)

Individual messages can be delayed up to 15 minutes (900 seconds) using `DelaySeconds` in `SendMessage`. This overrides the queue-level delay for that specific message.

```bash
aws sqs send-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue \
  --message-body "Delayed message" \
  --delay-seconds 60
```

Note: Per-message delay is not supported on FIFO queues.

### Delay Queues

Set a default delay for all messages in a queue using `DelaySeconds` on the queue itself (0–900 seconds). Messages are invisible to consumers for the delay period after being sent.

```bash
aws sqs create-queue \
  --queue-name MyDelayedQueue \
  --attributes '{"DelaySeconds":"30"}'
```

### Server-Side Encryption (SSE)

Two options:

**SSE-SQS (SQS-managed keys):**
- Free, managed automatically by AWS
- Enable: `SqsManagedSseEnabled: true`
- Default for new queues (as of 2023)
- No additional configuration required

**SSE-KMS (customer-managed keys):**
- Uses AWS KMS CMK for envelope encryption
- `KmsMasterKeyId`: Key ARN or alias (e.g., `alias/aws/sqs` for AWS-managed KMS key)
- `KmsDataKeyReusePeriodSeconds`: 60–86,400 seconds (default 300) — how long SQS reuses a data key before requesting a new one from KMS
- Supports key rotation, cross-account, CloudTrail audit logs

```bash
aws sqs create-queue \
  --queue-name MyEncryptedQueue \
  --attributes '{
    "KmsMasterKeyId": "arn:aws:kms:us-east-1:123456789012:key/abc123",
    "KmsDataKeyReusePeriodSeconds": "3600"
  }'
```

### Resource Policies (Queue Policies)

SQS supports resource-based policies separate from IAM identity policies. Required for cross-account access.

```json
{
  "Version": "2012-10-17",
  "Id": "QueuePolicy",
  "Statement": [
    {
      "Sid": "Allow-SNS-SendMessage",
      "Effect": "Allow",
      "Principal": {"Service": "sns.amazonaws.com"},
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:us-east-1:123456789012:MyQueue",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:sns:us-east-1:123456789012:MyTopic"
        }
      }
    }
  ]
}
```

For cross-account access, the principal account also needs an IAM policy granting the relevant SQS actions. Both the resource policy AND the IAM policy must allow the action.

### Temporary Queues (Virtual Queues)

The **Amazon SQS Temporary Queue Client** (Java library) allows lightweight request-response patterns using virtual queues:

- Virtual queues are local data structures — no SQS API calls to create them
- Multiple virtual queues multiplex onto a single host SQS queue (reducing cost and API calls)
- URL format: `https://sqs.us-east-1.amazonaws.com/123456789012/HostQueue#VirtualQueueName`
- Background thread polls the host queue and routes messages to the correct virtual queue

**Request-Response pattern (Java):**
```java
// Requester side
AmazonSQSRequester requester = AmazonSQSRequesterClientBuilder.defaultClient();
SendMessageRequest req = new SendMessageRequest()
    .withMessageBody("ping")
    .withQueueUrl(requestQueueUrl);
Message reply = requester.sendMessageAndGetResponse(req, 20, TimeUnit.SECONDS);

// Responder side
AmazonSQSResponder responder = AmazonSQSResponderClientBuilder.defaultClient();
responder.sendResponseMessage(
    MessageContent.fromMessage(inboundMessage),
    new MessageContent("pong"));
```

Cleanup: host queues are tagged every 5 minutes; orphaned queues are automatically deleted.

### Large Message Support (Extended Client Library)

SQS has a hard message size limit of **256 KB**. For larger payloads:

- Use the **Amazon SQS Extended Client Library** (Java, Python)
- Payloads > threshold are stored in S3; SQS message contains a reference pointer
- Default threshold: 256 KB (configurable lower)
- The S3 bucket must be accessible to both producer and consumer

```java
// Java Extended Client
AmazonS3 s3 = AmazonS3ClientBuilder.defaultClient();
ExtendedClientConfiguration config = new ExtendedClientConfiguration()
    .withPayloadSupportEnabled(s3, "my-sqs-payloads-bucket");
AmazonSQS sqsExtended = new AmazonSQSExtendedClient(
    AmazonSQSClientBuilder.defaultClient(), config);

sqsExtended.sendMessage(queueUrl, largePayload); // Auto-stored in S3
```

---

## 3. SNS Architecture

### Overview

Amazon Simple Notification Service (SNS) is a fully managed pub/sub messaging service. Publishers send messages to **topics**; SNS fans out to all **subscriptions**. It is push-based (unlike SQS, which is pull-based).

### Topics

- **Standard Topics:** High throughput, at-least-once delivery, best-effort ordering across subscribers
- **FIFO Topics:** Strict ordering, exactly-once delivery, must use `.fifo` suffix. Only SQS FIFO queues can subscribe to FIFO topics.

Topic ARN format: `arn:aws:sns:us-east-1:123456789012:MyTopic`

### Subscriptions

Subscriptions link a topic to an endpoint. Each subscription has a protocol and endpoint:

| Protocol | Endpoint Type | Notes |
|----------|--------------|-------|
| `sqs` | SQS Queue ARN | Most common for fan-out |
| `lambda` | Lambda Function ARN | Synchronous invoke by SNS |
| `https` / `http` | URL | Must confirm subscription |
| `email` | Email address | Human-readable, requires confirmation |
| `email-json` | Email address | JSON-wrapped message |
| `sms` | Phone number | E.164 format (+12125551212) |
| `application` | Mobile push endpoint ARN | ADM, APNs, FCM, Baidu |
| `firehose` | Kinesis Data Firehose ARN | Direct streaming |

Subscriptions require confirmation (except SQS and Lambda which auto-confirm).

### Fan-Out Pattern

One SNS topic → multiple SQS queues = fan-out. Each queue receives an independent copy of every message (unless filtered). Classic architecture:

```
Producer → SNS Topic → [SQS Queue A (Service A consumer)]
                     → [SQS Queue B (Service B consumer)]
                     → [SQS Queue C (Service C consumer)]
```

Benefits:
- Producers only publish to one endpoint
- Queues provide durability and buffering
- Each consumer scales independently
- Subscriptions can be added/removed without changing producers

### Message Filtering (Filter Policies)

By default, every subscriber receives every message. Use filter policies to deliver only matching messages to a subscription.

**Filter Policy Scope (set on subscription):**
- `MessageAttributes` (default): Matches against message attributes
- `MessageBody`: Matches against JSON message body fields (incurs payload scanning cost ~$0.09/GB)

**Filter operators:**

```json
{
  "event_type": ["order_placed", "order_updated"],
  "amount": [{"numeric": [">=", 100, "<", 1000]}],
  "region": [{"prefix": "us-"}],
  "status": [{"anything-but": ["cancelled"]}],
  "vip_flag": [{"exists": true}],
  "category": [{"equals-ignore-case": "electronics"}]
}
```

**Logic:**
- Multiple conditions in a policy = AND logic (all must match)
- Multiple values for one key = OR logic (any can match)
- Filter policy changes take **up to 15 minutes** to fully propagate

**Limits:**
- Default: 200 filter policies per topic, 10,000 per AWS account
- Filter policy JSON must be ≤ 256 KB

### SNS FIFO Topics

- Strict message ordering within message groups
- Exactly-once delivery to subscribed SQS FIFO queues
- `MessageGroupId` is propagated from the topic to subscribed queues
- Deduplication: content-based (SHA-256 of message body) or explicit `MessageDeduplicationId`
- Deduplication window: 5 minutes (same as SQS FIFO)
- Messages from different groups delivered in parallel; messages within same group delivered in order
- Only SQS FIFO queues can subscribe (no Lambda, HTTP, email, SMS from FIFO topics)

---

## 4. SNS Features

### Subscription Protocols in Depth

**SQS Subscriptions:**
- SQS queue policy must allow `sns:Publish` from the SNS topic (resource policy)
- SNS wraps the message in a JSON envelope unless raw message delivery is enabled

**Lambda Subscriptions:**
- SNS invokes Lambda synchronously
- If Lambda returns an error, SNS retries based on retry policy (up to 100,015 attempts over 23 days for managed endpoints)
- Lambda concurrency limits apply — throttled invocations may cause delivery failures

**HTTP/HTTPS Subscriptions:**
- Endpoint must handle subscription confirmation (GET with `SubscribeURL`)
- Custom retry/backoff policies are supported only for HTTP/S endpoints
- SNS sends `x-amz-sns-message-type` header to identify message type

**SMS:**
- Requires SMS sandbox for new accounts
- Costs per SMS — monitor `SMSMonthlySpendLimit`
- Supports transactional (critical, higher delivery priority) and promotional (lower cost) message types

### Message Attributes

SNS messages can carry up to 10 message attributes (similar to SQS). Used for filter policy matching.

```json
{
  "MessageAttributes": {
    "event_type": {
      "DataType": "String",
      "StringValue": "order_placed"
    },
    "amount": {
      "DataType": "Number",
      "StringValue": "250.00"
    }
  }
}
```

### Raw Message Delivery

By default, SNS wraps published messages in a JSON envelope with metadata (MessageId, Timestamp, Subject, etc.). Enable raw message delivery on a per-subscription basis so the consumer receives the original message body directly.

Supported for: SQS and HTTP/HTTPS subscriptions

```bash
aws sns set-subscription-attributes \
  --subscription-arn arn:aws:sns:us-east-1:123456789012:MyTopic:abc123 \
  --attribute-name RawMessageDelivery \
  --attribute-value true
```

Without raw delivery, SQS consumers receive:
```json
{
  "Type": "Notification",
  "MessageId": "...",
  "TopicArn": "arn:aws:sns:...",
  "Message": "your actual message body",
  "Timestamp": "2024-01-15T10:00:00.000Z",
  "SignatureVersion": "1",
  "Signature": "...",
  "MessageAttributes": {}
}
```

### Dead-Letter Queues for Subscriptions

SNS DLQs are configured at the **subscription** level (not topic level). They capture messages that SNS fails to deliver after all retry attempts.

**Failure types:**
- **Client errors** (e.g., endpoint deleted, policy changed): **No retries** — message goes directly to DLQ (or is dropped if no DLQ)
- **Server errors** (e.g., endpoint unavailable, 5xx): Retried per delivery policy, then DLQ

**Configure DLQ on a subscription:**
```bash
aws sns set-subscription-attributes \
  --subscription-arn arn:aws:sns:us-east-1:123456789012:MyTopic:abc123 \
  --attribute-name RedrivePolicy \
  --attribute-value '{"deadLetterTargetArn":"arn:aws:sqs:us-east-1:123456789012:MyDLQ"}'
```

Requirements:
- SNS subscription and SQS DLQ must be in the same AWS account and region
- If DLQ is KMS-encrypted, the KMS key policy must grant access to the SNS service principal
- Monitor using `ApproximateNumberOfMessagesVisible` on the DLQ (not `NumberOfMessagesSent`)

### Delivery Retry Policies

SNS defines per-protocol retry policies. Only HTTP/HTTPS supports customization.

**AWS-managed endpoints (SQS, Lambda):**
- 3 immediate retries (no delay)
- 2 pre-backoff retries (1 second apart)
- 10 backoff retries (exponential, 1–20 seconds)
- 100,000 post-backoff retries (20 seconds apart)
- **Total: 100,015 attempts over 23 days**

**Customer-managed endpoints (HTTP, SMTP, SMS, push):**
- 0 immediate retries
- 2 pre-backoff retries (10 seconds apart)
- 10 backoff retries (exponential, 10–600 seconds)
- 38 post-backoff retries (600 seconds apart)
- **Total: 50 attempts over 6 hours**

**Custom HTTP/S retry policy:**
```json
{
  "healthyRetryPolicy": {
    "minDelayTarget": 1,
    "maxDelayTarget": 60,
    "numRetries": 50,
    "numNoDelayRetries": 3,
    "numMinDelayRetries": 2,
    "numMaxDelayRetries": 35,
    "backoffFunction": "exponential"
  },
  "throttlePolicy": {
    "maxReceivesPerSecond": 10
  }
}
```

Backoff functions: `exponential`, `linear`, `arithmetic`, `geometric`

SNS applies jitter to all retry delays. Maximum total retry duration for HTTP/S is 3,600 seconds.

---

## 5. Patterns

### SNS + SQS Fan-Out

The canonical pattern for distributing messages to multiple downstream services:

```
[Producer] → SNS Topic → SQS Queue A → [Consumer A]
                       → SQS Queue B → [Consumer B]
                       → SQS Queue C → [Consumer C]
```

**Setup requirements:**
1. Create SNS topic
2. Create SQS queues
3. Add resource policy to each SQS queue allowing SNS to send:
   ```json
   {"Action": "sqs:SendMessage", "Principal": {"Service": "sns.amazonaws.com"},
    "Condition": {"ArnEquals": {"aws:SourceArn": "<topic-arn>"}}}
   ```
4. Subscribe each queue to the topic

**Benefits over direct point-to-point:**
- Decoupled: producer doesn't know about consumers
- New consumers can subscribe without changing producer
- Each queue independently buffers and retries
- Consumers fail independently

### SNS Message Filtering (Targeted Fan-Out)

Rather than delivering all messages to all subscribers, use filter policies to route specific events to specific queues:

```
[Order Events SNS Topic]
  → SQS Queue (Fulfillment) — filter: {"event": ["order_placed"]}
  → SQS Queue (CRM) — filter: {"buyer_class": ["vip"]}
  → SQS Queue (Analytics) — no filter (receives all)
```

Apply filter policy via CLI:
```bash
aws sns set-subscription-attributes \
  --subscription-arn arn:aws:sns:us-east-1:123456789012:OrderEvents:abc123 \
  --attribute-name FilterPolicy \
  --attribute-value '{"event": ["order_placed", "order_updated"]}'
```

### SQS as Lambda Event Source

Lambda polls SQS on behalf of the function using an Event Source Mapping:

```
SQS Queue → [Lambda ESM Poller] → Lambda Function → DeleteMessageBatch
                                                   → (on failure) messages become visible
```

**Key configuration parameters:**

| Parameter | Description | Recommendation |
|-----------|-------------|---------------|
| `BatchSize` | Messages per invocation (1–10,000 for standard; 1–10 for FIFO) | 10+ for throughput |
| `MaximumBatchingWindowInSeconds` | How long to wait to fill a batch (0–300s) | 0 for latency-sensitive |
| `ReportBatchItemFailures` | Partial batch responses | Enable to avoid reprocessing successes |
| Visibility timeout (queue) | Must be ≥ 6x Lambda timeout | Prevents timeout-before-delete |
| `maxReceiveCount` (redrive) | Min 5 recommended | Allows Lambda retries before DLQ |
| Reserved concurrency | Minimum 5 for SQS source | Prevents cold-start throttling |

**Partial batch response (Python Lambda):**
```python
def handler(event, context):
    batch_item_failures = []
    for record in event['Records']:
        try:
            process(record)
        except Exception as e:
            batch_item_failures.append({"itemIdentifier": record['messageId']})
    return {"batchItemFailures": batch_item_failures}
```

### FIFO Ordering with Message Group IDs

Use multiple message group IDs for parallelism while maintaining per-group order:

```python
import boto3
sqs = boto3.client('sqs')

# Each order ID = its own group = independent ordering
sqs.send_message(
    QueueUrl='https://sqs.us-east-1.amazonaws.com/123456789012/orders.fifo',
    MessageBody='{"action": "create", "amount": 100}',
    MessageGroupId='ORDER-12345',           # Order-level ordering
    MessageDeduplicationId='create-12345'   # Explicit dedup
)
```

Use many distinct group IDs to avoid concentration on a single partition (throughput bottleneck).

### Request Buffering Pattern

SQS acts as a buffer to absorb traffic spikes before downstream services:

```
[HTTP API] → SQS Queue → [Workers] → [Database / Downstream Service]
```

Benefits:
- Downstream service protected from burst traffic
- Messages retained during downstream maintenance
- Workers scale independently of producers

### Competing Consumers Pattern

Multiple consumers reading from the same standard queue for parallel processing:

- SQS visibility timeout ensures only one consumer processes a message at a time
- Scale consumer count based on `ApproximateNumberOfMessagesVisible`
- Works naturally with Auto Scaling Groups or Lambda concurrency

---

## 6. Management

### AWS CLI — SQS Commands

**Queue management:**
```bash
# Create standard queue
aws sqs create-queue \
  --queue-name MyQueue \
  --attributes '{
    "VisibilityTimeout": "60",
    "MessageRetentionPeriod": "86400",
    "ReceiveMessageWaitTimeSeconds": "20"
  }'

# Create FIFO queue with deduplication
aws sqs create-queue \
  --queue-name MyQueue.fifo \
  --attributes '{
    "FifoQueue": "true",
    "ContentBasedDeduplication": "true"
  }'

# List queues
aws sqs list-queues
aws sqs list-queues --queue-name-prefix "Order"

# Get queue URL
aws sqs get-queue-url --queue-name MyQueue

# Get queue attributes
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue \
  --attribute-names All

# Delete queue
aws sqs delete-queue \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue
```

**Message operations:**
```bash
# Send message
aws sqs send-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue \
  --message-body "Hello World"

# Send message to FIFO queue
aws sqs send-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue.fifo \
  --message-body "Order event" \
  --message-group-id "ORDER-123" \
  --message-deduplication-id "uuid-abc-123"

# Receive messages (long poll)
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue \
  --max-number-of-messages 10 \
  --wait-time-seconds 20 \
  --attribute-names All \
  --message-attribute-names All

# Delete message
aws sqs delete-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue \
  --receipt-handle "AQEBsX..."

# Batch send (up to 10 messages, up to 256KB total)
aws sqs send-message-batch \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue \
  --entries '[
    {"Id":"1","MessageBody":"Message 1"},
    {"Id":"2","MessageBody":"Message 2","DelaySeconds":10}
  ]'

# Purge queue (irreversible — deletes all messages)
aws sqs purge-queue \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue

# Set queue attributes (e.g., visibility timeout)
aws sqs set-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue \
  --attributes '{"VisibilityTimeout":"120"}'

# Start DLQ message move (redrive back to source)
aws sqs start-message-move-task \
  --source-arn arn:aws:sqs:us-east-1:123456789012:MyQueue-DLQ \
  --destination-arn arn:aws:sqs:us-east-1:123456789012:MyQueue
```

### AWS CLI — SNS Commands

```bash
# Create topic
aws sns create-topic --name MyTopic

# Create FIFO topic
aws sns create-topic \
  --name MyTopic.fifo \
  --attributes '{"FifoTopic":"true","ContentBasedDeduplication":"true"}'

# List topics
aws sns list-topics

# Subscribe SQS queue to topic
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:MyTopic \
  --protocol sqs \
  --notification-endpoint arn:aws:sqs:us-east-1:123456789012:MyQueue

# Subscribe Lambda to topic
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:MyTopic \
  --protocol lambda \
  --notification-endpoint arn:aws:lambda:us-east-1:123456789012:function:MyFunction

# Subscribe email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:MyTopic \
  --protocol email \
  --notification-endpoint admin@example.com

# Publish message to topic
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:123456789012:MyTopic \
  --message "Hello from SNS" \
  --subject "Test notification" \
  --message-attributes '{
    "event_type": {"DataType":"String","StringValue":"order_placed"}
  }'

# Set filter policy on subscription
aws sns set-subscription-attributes \
  --subscription-arn arn:aws:sns:us-east-1:123456789012:MyTopic:abc123 \
  --attribute-name FilterPolicy \
  --attribute-value '{"event_type":["order_placed","order_updated"]}'

# Set filter policy scope (MessageBody)
aws sns set-subscription-attributes \
  --subscription-arn arn:aws:sns:us-east-1:123456789012:MyTopic:abc123 \
  --attribute-name FilterPolicyScope \
  --attribute-value MessageBody

# Enable raw message delivery
aws sns set-subscription-attributes \
  --subscription-arn arn:aws:sns:us-east-1:123456789012:MyTopic:abc123 \
  --attribute-name RawMessageDelivery \
  --attribute-value true

# Set DLQ on subscription
aws sns set-subscription-attributes \
  --subscription-arn arn:aws:sns:us-east-1:123456789012:MyTopic:abc123 \
  --attribute-name RedrivePolicy \
  --attribute-value '{"deadLetterTargetArn":"arn:aws:sqs:us-east-1:123456789012:MyDLQ"}'

# List subscriptions for a topic
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:123456789012:MyTopic

# Delete subscription
aws sns unsubscribe \
  --subscription-arn arn:aws:sns:us-east-1:123456789012:MyTopic:abc123

# Delete topic
aws sns delete-topic \
  --topic-arn arn:aws:sns:us-east-1:123456789012:MyTopic
```

### CloudFormation / IaC

**Complete SQS + SNS fan-out stack:**
```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: SNS topic with SQS fan-out, DLQ, and CloudWatch alarm

Resources:
  # Dead letter queues
  OrdersDLQ:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: orders-dlq
      MessageRetentionPeriod: 1209600  # 14 days

  FulfillmentDLQ:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: fulfillment-dlq
      MessageRetentionPeriod: 1209600

  # Main queues
  OrdersQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: orders
      VisibilityTimeout: 300
      ReceiveMessageWaitTimeSeconds: 20
      MessageRetentionPeriod: 345600
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt OrdersDLQ.Arn
        maxReceiveCount: 5

  FulfillmentQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: fulfillment
      VisibilityTimeout: 300
      ReceiveMessageWaitTimeSeconds: 20
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt FulfillmentDLQ.Arn
        maxReceiveCount: 5

  # SNS Topic
  OrderEventsTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: order-events

  # Queue policies allowing SNS to send
  OrdersQueuePolicy:
    Type: AWS::SQS::QueuePolicy
    Properties:
      Queues: [!Ref OrdersQueue]
      PolicyDocument:
        Statement:
          - Effect: Allow
            Principal:
              Service: sns.amazonaws.com
            Action: sqs:SendMessage
            Resource: !GetAtt OrdersQueue.Arn
            Condition:
              ArnEquals:
                aws:SourceArn: !Ref OrderEventsTopic

  FulfillmentQueuePolicy:
    Type: AWS::SQS::QueuePolicy
    Properties:
      Queues: [!Ref FulfillmentQueue]
      PolicyDocument:
        Statement:
          - Effect: Allow
            Principal:
              Service: sns.amazonaws.com
            Action: sqs:SendMessage
            Resource: !GetAtt FulfillmentQueue.Arn
            Condition:
              ArnEquals:
                aws:SourceArn: !Ref OrderEventsTopic

  # Subscriptions with filter policies
  OrdersSubscription:
    Type: AWS::SNS::Subscription
    Properties:
      TopicArn: !Ref OrderEventsTopic
      Protocol: sqs
      Endpoint: !GetAtt OrdersQueue.Arn
      FilterPolicy:
        event_type:
          - order_placed
          - order_updated
          - order_cancelled
      RawMessageDelivery: true

  FulfillmentSubscription:
    Type: AWS::SNS::Subscription
    Properties:
      TopicArn: !Ref OrderEventsTopic
      Protocol: sqs
      Endpoint: !GetAtt FulfillmentQueue.Arn
      FilterPolicy:
        event_type:
          - order_placed
      RawMessageDelivery: false

  # CloudWatch alarm on DLQ
  OrdersDLQAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmDescription: Messages in Orders DLQ
      Namespace: AWS/SQS
      MetricName: ApproximateNumberOfMessagesVisible
      Dimensions:
        - Name: QueueName
          Value: !GetAtt OrdersDLQ.QueueName
      Statistic: Sum
      Period: 60
      EvaluationPeriods: 1
      Threshold: 1
      ComparisonOperator: GreaterThanOrEqualToThreshold
      TreatMissingData: notBreaching

Outputs:
  TopicArn:
    Value: !Ref OrderEventsTopic
  OrdersQueueUrl:
    Value: !Ref OrdersQueue
  FulfillmentQueueUrl:
    Value: !Ref FulfillmentQueue
```

**FIFO queue with high throughput (CloudFormation):**
```yaml
FifoQueue:
  Type: AWS::SQS::Queue
  Properties:
    QueueName: high-throughput.fifo
    FifoQueue: true
    ContentBasedDeduplication: false
    DeduplicationScope: messageGroup
    FifoThroughputLimit: perMessageGroupId  # enables high throughput mode
    VisibilityTimeout: 300
    RedrivePolicy:
      deadLetterTargetArn: !GetAtt FifoDLQ.Arn
      maxReceiveCount: 5

FifoDLQ:
  Type: AWS::SQS::Queue
  Properties:
    QueueName: high-throughput-dlq.fifo
    FifoQueue: true
```

### Terraform Examples

**SQS with DLQ:**
```hcl
resource "aws_sqs_queue" "dlq" {
  name                      = "my-queue-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "main" {
  name                       = "my-queue"
  visibility_timeout_seconds = 300
  receive_wait_time_seconds  = 20
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })

  sqs_managed_sse_enabled = true
}
```

**SNS to SQS fan-out with filter:**
```hcl
resource "aws_sns_topic" "events" {
  name = "order-events"
}

resource "aws_sqs_queue" "fulfillment" {
  name = "fulfillment-queue"
}

resource "aws_sqs_queue_policy" "fulfillment" {
  queue_url = aws_sqs_queue.fulfillment.id
  policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.fulfillment.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.events.arn }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "fulfillment" {
  topic_arn            = aws_sns_topic.events.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.fulfillment.arn
  raw_message_delivery = true
  filter_policy = jsonencode({
    event_type = ["order_placed"]
  })
  filter_policy_scope = "MessageAttributes"
}
```

### Python (boto3) SDK Examples

**Producer (standard queue):**
```python
import boto3
import json

sqs = boto3.client('sqs', region_name='us-east-1')
QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue'

# Single message
response = sqs.send_message(
    QueueUrl=QUEUE_URL,
    MessageBody=json.dumps({'order_id': 'ORD-123', 'amount': 99.99}),
    MessageAttributes={
        'event_type': {'DataType': 'String', 'StringValue': 'order_placed'}
    }
)
print(f"MessageId: {response['MessageId']}")

# Batch send
entries = [
    {'Id': str(i), 'MessageBody': f'Message {i}'} for i in range(10)
]
response = sqs.send_message_batch(QueueUrl=QUEUE_URL, Entries=entries)
if response.get('Failed'):
    print(f"Failed: {response['Failed']}")
```

**Consumer (with delete):**
```python
while True:
    response = sqs.receive_message(
        QueueUrl=QUEUE_URL,
        MaxNumberOfMessages=10,
        WaitTimeSeconds=20,
        MessageAttributeNames=['All']
    )
    messages = response.get('Messages', [])
    if not messages:
        continue
    
    delete_entries = []
    for msg in messages:
        try:
            body = json.loads(msg['Body'])
            process(body)
            delete_entries.append({
                'Id': msg['MessageId'],
                'ReceiptHandle': msg['ReceiptHandle']
            })
        except Exception as e:
            print(f"Failed to process {msg['MessageId']}: {e}")
            # Message will reappear after visibility timeout
    
    if delete_entries:
        sqs.delete_message_batch(QueueUrl=QUEUE_URL, Entries=delete_entries)
```

**FIFO producer:**
```python
import uuid

response = sqs.send_message(
    QueueUrl='https://sqs.us-east-1.amazonaws.com/123456789012/orders.fifo',
    MessageBody=json.dumps({'action': 'create', 'order_id': 'ORD-123'}),
    MessageGroupId='ORD-123',          # Per-order ordering
    MessageDeduplicationId=str(uuid.uuid4())  # Explicit dedup
)
```

### CloudWatch Monitoring

**Key SQS metrics (namespace: `AWS/SQS`):**

| Metric | Alert Condition | Diagnostic Value |
|--------|----------------|-----------------|
| `ApproximateNumberOfMessagesVisible` | Growing consistently | Consumer backlog |
| `ApproximateNumberOfMessagesNotVisible` | Exceeds 100k (standard) or 18k (FIFO) | In-flight message saturation |
| `ApproximateAgeOfOldestMessage` | Exceeds retention threshold | Processing lag |
| `ApproximateNumberOfMessagesDelayed` | Unexpectedly high | Delay misconfiguration |
| `NumberOfEmptyReceives` | Very high % of total receives | Switch to long polling |
| `NumberOfMessagesSent` | Sudden drop | Producer failure |
| `NumberOfMessagesDeleted` | Much lower than Received | Delete failing or consumers crashing |

**Create CloudWatch alarm on DLQ (CLI):**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "OrdersDLQ-Messages" \
  --alarm-description "Messages landing in Orders DLQ" \
  --namespace "AWS/SQS" \
  --metric-name "ApproximateNumberOfMessagesVisible" \
  --dimensions Name=QueueName,Value=orders-dlq \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:OpsAlerts \
  --treat-missing-data notBreaching
```

**Note:** CloudWatch SQS metrics may be delayed up to 15 minutes when a queue transitions from inactive to active state.

### X-Ray Tracing

X-Ray propagates trace context through SQS via the `AWSTraceHeader` system attribute (reserved by SQS). Enable at the producer, and Lambda consumers automatically receive the linked trace.

```python
# X-Ray SDK for Python automatically injects AWSTraceHeader
from aws_xray_sdk.core import xray_recorder, patch_all
patch_all()  # Patches boto3 to auto-inject trace headers

sqs.send_message(QueueUrl=QUEUE_URL, MessageBody="traced message")
```

Enable active tracing on Lambda ESM for end-to-end distributed traces.

---

## 7. Best Practices

### Queue Design: Standard vs. FIFO

| Concern | Standard | FIFO |
|---------|---------|------|
| Throughput | Near unlimited | 300/s (3,000/s batched); 70,000/s high-throughput |
| Ordering | Best-effort | Strict per message group |
| Duplicates | Possible | Eliminated (5 min window) |
| Cost | Lower | Slightly higher |
| Lambda ESM | Max 10,000 batch | Max 10 batch |
| Use case | Analytics, notifications, high-volume events | Financial txns, ordering systems |

### Batch Operations

- Always prefer batch send/delete/changeVisibility (up to 10 messages per request)
- Batch operations cost the same as single requests — 10x cost savings
- Check `Failed` items in batch responses and retry them individually
- Batch size >10 for Lambda ESM requires `MaximumBatchingWindowInSeconds >= 1`

### Visibility Timeout Tuning

1. Set queue visibility timeout to **at least 6x the Lambda function timeout** (for Lambda ESM)
2. For non-Lambda consumers, set to the 99th percentile processing time + buffer
3. Implement a heartbeat that calls `ChangeMessageVisibility` for long-running tasks
4. Never set timeout to 12 hours as default — messages are invisible if consumer crashes

### DLQ Configuration Best Practices

- Always configure a DLQ for production queues
- Set `maxReceiveCount` to at least 5 (gives consumers multiple attempts)
- Set DLQ retention period to 14 days (maximum)
- Set a CloudWatch alarm on `ApproximateNumberOfMessagesVisible` (threshold: 1)
- Implement a DLQ analysis process: inspect messages, fix root cause, redrive
- For FIFO queues: DLQ must also be FIFO with a compatible queue policy

### Message Size Limits

- Hard limit: **256 KB per message** (including message body + attributes)
- For larger payloads: use SQS Extended Client Library (stores in S3)
- Keep messages small; pass references (S3 keys, DynamoDB IDs) rather than large blobs
- Monitor `SentMessageSize` metric for size distribution

### IAM and Security Best Practices

- Grant least-privilege IAM permissions to producers and consumers
- Use resource policies (queue policies) for cross-service access (SNS → SQS)
- Always include `aws:SourceArn` condition when allowing SNS to send to SQS
- Avoid wildcards (`sqs:*`) in production policies
- Enable SSE-SQS at minimum; use SSE-KMS for sensitive data with audit requirements

**IAM policy for consumer role:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:DeleteMessageBatch",
        "sqs:ChangeMessageVisibility",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:us-east-1:123456789012:MyQueue"
    }
  ]
}
```

**IAM policy for producer role:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:SendMessageBatch",
        "sqs:GetQueueUrl"
      ],
      "Resource": "arn:aws:sqs:us-east-1:123456789012:MyQueue"
    }
  ]
}
```

### Cost Optimization

- First 1 million requests/month are free; then ~$0.40 per million (standard), ~$0.50 per million (FIFO)
- Use long polling to reduce empty receive API calls (major cost reducer)
- Use batch operations — 10 messages = 1 API call
- Right-size message retention periods (don't use 14 days if 1 day suffices)
- Delete messages promptly after successful processing to reduce in-flight counts
- Use SSE-SQS instead of SSE-KMS unless KMS audit logs are required (KMS incurs additional charges)

### SNS Best Practices

- Use raw message delivery for SQS subscriptions when consumers only need the payload
- Use filter policies to avoid sending unnecessary messages to downstream queues
- Configure DLQs on all production SNS subscriptions
- Monitor SNS-specific CloudWatch metrics: `NumberOfNotificationsDelivered`, `NumberOfNotificationsFailed`, `NumberOfNotificationsFilteredOut`
- Test filter policies against sample messages before deploying (use console or SDK)
- For FIFO topics: ensure all subscribers are SQS FIFO queues

---

## 8. Diagnostics and Troubleshooting

### Problem: Messages Stuck In-Flight (`ApproximateNumberOfMessagesNotVisible` high)

**Symptoms:** `ApproximateNumberOfMessagesNotVisible` is high; messages don't become visible; consumers appear stalled.

**Causes and fixes:**

1. **Visibility timeout too long:** Consumer crashed; messages are hidden for hours
   - Diagnosis: Check `ApproximateNumberOfMessagesNotVisible` vs. `NumberOfMessagesDeleted` — large gap indicates processing failures
   - Fix: Reduce visibility timeout; implement health checks; use heartbeat to extend only when actively processing

2. **In-flight limit reached:** Standard queue hit ~120,000 in-flight limit
   - Error: `AWS.SimpleQueueService.OverLimit: Too many messages in flight`
   - Fix: Scale consumers; increase deletion rate; check for processing failures

3. **Missing delete calls:** Consumer processes message but fails to delete
   - Fix: Ensure `delete_message` / `DeleteMessage` is called in the happy path; check for uncaught exceptions before delete

4. **FIFO queue: blocked message group**
   - A failing message in a group blocks all subsequent messages in that group
   - Fix: Increase `maxReceiveCount` to trigger DLQ move; or investigate and fix root cause; or use different message group ID

### Problem: Messages Going to DLQ

**Diagnosis steps:**
1. Inspect DLQ messages: `aws sqs receive-message --queue-url <dlq-url>`
2. Check CloudWatch Lambda logs for exception details
3. Look for `ApproximateReceiveCount` attribute (how many times received before DLQ)
4. Check if `maxReceiveCount` is set too low (e.g., 1 — move after single failure)

**Common causes:**
- Lambda function timeout (set queue visibility to 6x Lambda timeout)
- Lambda exceptions causing message to become visible repeatedly
- Message format invalid — JSON parsing errors
- Downstream dependency unavailable — connection timeouts
- Permission errors — Lambda cannot access downstream resources

**DLQ analysis command:**
```bash
# Receive and inspect DLQ messages (non-destructive)
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue-DLQ \
  --max-number-of-messages 10 \
  --attribute-names All \
  --message-attribute-names All

# Move DLQ messages back to source for reprocessing
aws sqs start-message-move-task \
  --source-arn arn:aws:sqs:us-east-1:123456789012:MyQueue-DLQ \
  --destination-arn arn:aws:sqs:us-east-1:123456789012:MyQueue \
  --max-number-of-messages-per-second 10
```

### Problem: FIFO Deduplication Not Working (Duplicate Messages)

**Symptoms:** Same message appears multiple times despite FIFO queue.

**Causes:**
1. **Deduplication ID reused after 5-minute window:** Re-send with a different ID if retrying after 5+ minutes
2. **Content-based deduplication enabled, but attributes differ:** SHA-256 only covers message body, not attributes — attribute-only changes are not deduplicated
3. **Different message bodies, same intent:** Deduplication is purely hash/ID based — application-level deduplication required for semantic deduplication

**Diagnosis:**
```bash
# Check if ContentBasedDeduplication is enabled
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue.fifo \
  --attribute-names ContentBasedDeduplication
```

### Problem: FIFO Throttling (ThrottlingException)

**Error:** `ThrottlingException: Rate exceeded for queue MyQueue.fifo`

**Default limit:** 300 TPS (send/receive/delete) without batching; 3,000 TPS with batching.

**Solutions:**
1. Switch to batch API calls (`SendMessageBatch`, `DeleteMessageBatch`)
2. Enable high throughput mode: Set `DeduplicationScope=messageGroup` and `FifoThroughputLimit=perMessageGroupId`
3. Use more distinct `MessageGroupId` values to spread load across partitions
4. Check current TPS via CloudWatch metric `NumberOfMessagesSent` + `NumberOfMessagesDeleted`

```bash
# Enable high throughput FIFO
aws sqs set-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/MyQueue.fifo \
  --attributes '{
    "DeduplicationScope": "messageGroup",
    "FifoThroughputLimit": "perMessageGroupId"
  }'
```

### Problem: SNS Message Delivery Failures

**Symptoms:** Messages published to SNS topic not arriving at SQS queue.

**Diagnosis:**
1. Check SNS CloudWatch metrics: `NumberOfNotificationsFailed`, `NumberOfNotificationsFilteredOut`
2. Enable SNS delivery logging to CloudWatch Logs (configure on topic)
3. Check SQS queue resource policy — does it allow `sqs:SendMessage` from the SNS service principal with correct source ARN?
4. Check subscription filter policy — is the message matching the filter?

**Filter policy not matching — common mistakes:**
- Message attribute name case sensitivity (filter policies are case-sensitive)
- Numeric values sent as strings vs. Number type
- Filter policy scope set to `MessageBody` but attributes checked in `MessageAttributes`
- Filter policy change still propagating (up to 15 minutes)

**Enable SNS delivery status logging:**
```bash
aws sns set-topic-attributes \
  --topic-arn arn:aws:sns:us-east-1:123456789012:MyTopic \
  --attribute-name SQSSuccessFeedbackRoleArn \
  --attribute-value arn:aws:iam::123456789012:role/SNSFeedbackRole

aws sns set-topic-attributes \
  --topic-arn arn:aws:sns:us-east-1:123456789012:MyTopic \
  --attribute-name SQSFailureFeedbackRoleArn \
  --attribute-value arn:aws:iam::123456789012:role/SNSFeedbackRole
```

### Problem: Lambda ESM Not Processing Messages

**Symptoms:** Messages sit in queue; Lambda not triggered; `NumberOfMessagesReceived` stays at 0 from Lambda perspective.

**Causes:**
1. **Lambda ESM disabled:** Check event source mapping state
2. **Lambda concurrency exhausted:** Reserved concurrency set too low
3. **Lambda function errors causing ESM to disable itself:** Check for function errors; ESM may enter error state
4. **Cross-account permissions missing:** Lambda ESM requires both IAM role permissions AND SQS queue resource policy

**Diagnosis commands:**
```bash
# List Lambda event source mappings
aws lambda list-event-source-mappings \
  --function-name MyFunction

# Check ESM state and error details
aws lambda get-event-source-mapping \
  --uuid <esm-uuid>

# Expected output fields to check:
# "State": "Enabled" | "Disabled" | "Enabling" | "Disabling" | "Creating" | "Updating" | "Deleting"
# "StateTransitionReason": description if in error state
# "LastProcessingResult": "OK" or error message
```

### Common Error Messages Reference

| Error | Cause | Resolution |
|-------|-------|-----------|
| `AWS.SimpleQueueService.OverLimit` | 120k in-flight limit hit (standard) | Scale consumers; fix processing failures |
| `ThrottlingException` | FIFO >300 TPS or API rate limit | Use batch operations; enable high-throughput FIFO |
| `InvalidParameterValue: Must use ...fifo suffix` | FIFO queue name missing `.fifo` | Rename queue to end with `.fifo` |
| `InvalidMessageContents` | Message contains unsupported characters | Validate message body characters |
| `MessageTooLong` | Message exceeds 256KB | Use Extended Client Library with S3 |
| `ReceiptHandleIsInvalid` | Receipt handle expired or wrong queue | Re-receive message; check processing time vs visibility timeout |
| `QueueDeletedRecently` | Attempted to create queue within 60s of deletion | Wait 60 seconds before recreating |
| `AWS.SimpleQueueService.NonExistentQueue` | Queue URL is wrong or queue was deleted | Verify queue URL and region |

---

## Key Limits Reference

| Resource | Limit |
|----------|-------|
| Message size | 256 KB (body + attributes) |
| Message retention | 60 sec – 14 days (default 4 days) |
| Visibility timeout | 0 sec – 12 hours (default 30 sec) |
| Delay seconds (queue/message) | 0 – 900 seconds (15 minutes) |
| Long poll wait time | 1 – 20 seconds |
| Batch size | 10 messages or 256 KB total |
| In-flight messages (standard) | ~120,000 |
| In-flight messages (FIFO) | 20,000 per message group |
| Standard queue throughput | Nearly unlimited |
| FIFO throughput (default) | 300 TPS / 3,000 TPS batched |
| FIFO throughput (high-throughput mode) | 70,000 TPS (region-dependent) |
| Deduplication window (FIFO) | 5 minutes |
| Message attributes | 10 per message |
| Queues per account | Default 1,000 (soft limit, increasable) |
| SNS subscriptions per topic | 12,500,000 |
| SNS filter policies per topic | 200 |
| SNS filter policies per account | 10,000 |
| SNS message size | 256 KB |
| SNS delivery retry (SQS/Lambda) | 100,015 attempts over 23 days |
| SNS delivery retry (HTTP/other) | 50 attempts over 6 hours |

---

*Sources: AWS SQS Developer Guide, AWS SNS Developer Guide, AWS CLI Reference, AWS CloudFormation Reference, AWS Lambda Developer Guide, AWS Compute Blog, AWS News Blog*
