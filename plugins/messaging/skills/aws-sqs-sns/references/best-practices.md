# AWS SQS/SNS Best Practices Reference

## Long Polling (Always Enable)

Set `ReceiveMessageWaitTimeSeconds` to 20 at queue level. Reduces empty responses, lowers API costs, improves latency.

```bash
aws sqs create-queue --queue-name MyQueue \
  --attributes '{"ReceiveMessageWaitTimeSeconds":"20","VisibilityTimeout":"300"}'
```

## FIFO Throughput Optimization

### High-Throughput Mode
```yaml
FifoQueue:
  Type: AWS::SQS::Queue
  Properties:
    QueueName: orders.fifo
    FifoQueue: true
    DeduplicationScope: messageGroup
    FifoThroughputLimit: perMessageGroupId
```

### Maximize Parallelism
- Use many distinct MessageGroupIds (per order, per customer, per entity)
- Avoid single group ID for all messages (serializes everything)
- Different groups process in parallel

## Lambda Integration

### Event Source Mapping Configuration

| Parameter | Recommendation |
|---|---|
| `BatchSize` | 10+ for throughput (max 10,000 standard; 10 FIFO) |
| `MaximumBatchingWindowInSeconds` | 0 for latency-sensitive; 5-60 for throughput |
| `ReportBatchItemFailures` | Always enable |
| Visibility timeout | >= 6x Lambda timeout |
| `maxReceiveCount` | Min 5 |
| Reserved concurrency | Min 5 for SQS source |

### Partial Batch Response
```python
def handler(event, context):
    batch_item_failures = []
    for record in event['Records']:
        try:
            process(record)
        except Exception:
            batch_item_failures.append({"itemIdentifier": record['messageId']})
    return {"batchItemFailures": batch_item_failures}
```

## SNS Filtering Best Practices

- Use attribute-based filtering (`MessageAttributes` scope) when possible -- no scanning cost
- Body-based filtering (`MessageBody` scope) incurs ~$0.09/GB scanning cost
- Filter policy changes take up to 15 minutes to propagate
- Prefer specific filters over broad ones to reduce message volume per consumer
- Combine with raw message delivery to avoid double JSON parsing

## DLQ Configuration

- DLQ of FIFO must be FIFO; DLQ of standard must be standard
- Set DLQ retention period >= source queue retention
- `maxReceiveCount` minimum 5 (allows transient failure recovery)
- Set up CloudWatch alarm on `ApproximateNumberOfMessagesVisible` for DLQ

```bash
aws sqs create-queue --queue-name MyQueue-DLQ --attributes '{"MessageRetentionPeriod":"1209600"}'
aws sqs set-queue-attributes --queue-url ... --attributes '{
  "RedrivePolicy":"{\"deadLetterTargetArn\":\"arn:aws:sqs:...:MyQueue-DLQ\",\"maxReceiveCount\":\"5\"}"
}'
```

## CloudFormation Patterns

### SNS + SQS Fan-Out with Filtering
```yaml
Resources:
  OrderTopic:
    Type: AWS::SNS::Topic
    Properties: { TopicName: order-events }

  FulfillmentQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: fulfillment
      VisibilityTimeout: 300
      ReceiveMessageWaitTimeSeconds: 20
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt FulfillmentDLQ.Arn
        maxReceiveCount: 5

  FulfillmentDLQ:
    Type: AWS::SQS::Queue
    Properties: { MessageRetentionPeriod: 1209600 }

  FulfillmentQueuePolicy:
    Type: AWS::SQS::QueuePolicy
    Properties:
      Queues: [!Ref FulfillmentQueue]
      PolicyDocument:
        Statement:
          - Effect: Allow
            Principal: { Service: sns.amazonaws.com }
            Action: sqs:SendMessage
            Resource: !GetAtt FulfillmentQueue.Arn
            Condition: { ArnEquals: { "aws:SourceArn": !Ref OrderTopic } }

  FulfillmentSubscription:
    Type: AWS::SNS::Subscription
    Properties:
      TopicArn: !Ref OrderTopic
      Protocol: sqs
      Endpoint: !GetAtt FulfillmentQueue.Arn
      FilterPolicy: { event_type: [order_placed] }
      RawMessageDelivery: true
```

## Cost Optimization

- Use long polling to reduce empty responses
- Batch operations (SendMessageBatch, DeleteMessageBatch) up to 10 messages
- Enable SSE-SQS (free) instead of SSE-KMS unless compliance requires KMS
- Small messages (< 1 KB) billed as 1 request -- batch to reduce cost
- Each 64 KB chunk counts as 1 request for billing

## Security

- Use IAM policies (identity + resource-based) for access control
- VPC endpoints for SQS/SNS to avoid public internet traffic
- Enable SSE for encryption at rest
- Use `Condition` elements in resource policies for least-privilege
- Never embed credentials in code; use IAM roles

## CLI Quick Reference

```bash
# Create queues
aws sqs create-queue --queue-name MyQueue --attributes '{"ReceiveMessageWaitTimeSeconds":"20"}'
aws sqs create-queue --queue-name MyQueue.fifo --attributes '{"FifoQueue":"true"}'

# Send/receive
aws sqs send-message --queue-url ... --message-body "Hello"
aws sqs receive-message --queue-url ... --max-number-of-messages 10 --wait-time-seconds 20
aws sqs delete-message --queue-url ... --receipt-handle "..."

# SNS
aws sns create-topic --name MyTopic
aws sns subscribe --topic-arn ... --protocol sqs --notification-endpoint ...
aws sns publish --topic-arn ... --message "Hello" --message-attributes '{"event":{"DataType":"String","StringValue":"created"}}'

# DLQ redrive
aws sqs start-message-move-task --source-arn ... --destination-arn ...
```
