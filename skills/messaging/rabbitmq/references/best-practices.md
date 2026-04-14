# RabbitMQ Best Practices Reference

## Queue Type Selection

| Scenario | Recommended Queue Type |
|---|---|
| Production workload requiring durability | Quorum queue |
| Replicated, high-availability message storage | Quorum queue |
| Temporary, scratch, or exclusive queues | Classic queue |
| Event sourcing, audit log, fan-out replay | Stream |
| Multi-consumer replay at different offsets | Stream |
| Priority queues (more than 2 levels) | Classic queue (x-max-priority) |
| High-throughput partitioned streaming | Super stream |

**Default queue type in 4.2:** Quorum (Amazon MQ for RabbitMQ 4.2 uses quorum as default).

## Producer Tuning

### Publisher Confirms (Always Enable)

```python
channel.confirm_delivery()
# Publish and wait for confirm
channel.basic_publish(
    exchange='my-exchange',
    routing_key='my.key',
    body=msg_body,
    properties=pika.BasicProperties(delivery_mode=2)  # persistent
)
```

**Batch confirms** for throughput: publish multiple messages, then `wait_for_confirms_or_die()`.

**Async confirms** for maximum throughput: register confirm callback, track delivery tags, handle nacks.

### Message Persistence

Set `delivery_mode=2` for persistent messages. Combined with durable queues and publisher confirms, this provides the strongest durability guarantee.

### Connection Management

- One connection per application instance (or connection pool)
- Separate connections for publishing and consuming
- One channel per thread/coroutine
- Close channels when no longer needed
- Never create a connection per publish operation

### Compression

RabbitMQ does not compress messages. Compress at the application level (gzip, snappy, zstd) for large payloads. Set `content_encoding` header for consumer awareness.

## Consumer Tuning

### Prefetch (QoS)

```python
channel.basic_qos(prefetch_count=50)
```

| Processing Type | Recommended Prefetch |
|---|---|
| CPU-bound tasks | 1-5 |
| I/O-bound tasks | 10-50 |
| Fast consumers | 100-300 |
| Very fast consumers | Up to 1000 |
| Unlimited (dangerous) | 0 (avoid in production) |

Quorum queues do NOT support global QoS (`global=True`). Use per-consumer QoS only.

### Acknowledgment Modes

**Manual ack (recommended):** Explicit `basic.ack` after successful processing. Unacked messages requeue on disconnect.

**Auto ack (avoid for critical work):** Message acked on TCP delivery. Lost if consumer crashes before processing.

**Bulk ack:** `basic.ack(delivery_tag, multiple=True)` acknowledges all up to and including the tag.

### Consumer Concurrency

Multiple consumers on the same queue distribute load. RabbitMQ dispatches round-robin across consumers with available prefetch slots.

For ordered processing per entity: use single consumer per queue, or implement consumer-side ordering with correlation ID grouping.

## Dead Letter Exchange Patterns

### Basic DLX Setup

```bash
# Via policy (recommended -- applies to all matching queues)
rabbitmqctl set_policy DLX "^orders\." \
  '{"dead-letter-exchange":"dlx.exchange","dead-letter-routing-key":"dlx.orders"}' \
  --apply-to queues

# Via queue arguments (at declaration time)
channel.queue_declare(
    queue='orders.processing',
    durable=True,
    arguments={
        'x-queue-type': 'quorum',
        'x-dead-letter-exchange': 'dlx.exchange',
        'x-dead-letter-routing-key': 'dlx.orders'
    }
)
```

### Retry with Exponential Backoff

Chain delay queues using TTL and DLX:

```
Main Queue (DLX -> retry-exchange)
  --> on failure: message goes to retry-exchange
  --> retry-exchange routes to delay-queue-30s (TTL=30s, DLX -> main-exchange)
  --> after 30s, message returns to main queue
  --> after N retries, route to final DLQ
```

Track retry count in message headers (`x-death` array). Route to final DLQ when count exceeds threshold.

### Delivery Limits (Quorum Queues)

Default: 20 redeliveries. Configure via policy:
```bash
rabbitmqctl set_policy delivery-limit "^qq\." \
  '{"delivery-limit": 50}' \
  --priority 123 --apply-to quorum_queues
```

Messages exceeding limit are dead-lettered or dropped (if no DLX configured).

## TTL Strategies

### Queue-Wide TTL
```bash
rabbitmqctl set_policy TTL "^temp\." '{"message-ttl": 60000}' --apply-to queues
```

### Per-Message TTL
```python
channel.basic_publish(
    exchange='', routing_key='my.queue', body='data',
    properties=pika.BasicProperties(expiration='30000')  # ms as string
)
```

When both are set, the lower value applies. Expired messages at queue head are dead-lettered.

### Queue Expiry
```python
channel.queue_declare(queue='temp.queue', arguments={'x-expires': 1800000})  # 30 min
```

## Security

### TLS Setup
```ini
# rabbitmq.conf
listeners.ssl.default = 5671
ssl_options.cacertfile = /path/to/ca.pem
ssl_options.certfile   = /path/to/server.pem
ssl_options.keyfile    = /path/to/server.key
ssl_options.verify     = verify_peer
ssl_options.fail_if_no_peer_cert = true
ssl_options.versions.1 = tlsv1.3
ssl_options.versions.2 = tlsv1.2
```

### Authentication
- Username/password (default): change `guest` password immediately; `guest` only works from localhost
- LDAP: `rabbitmq_auth_backend_ldap` plugin
- OAuth 2.0: `rabbitmq_auth_backend_oauth2` plugin
- x.509 client certificates: mutual TLS

### Authorization
Per-vhost permissions: configure (create/delete resources), write (publish), read (consume).
```bash
rabbitmqctl set_permissions -p /prod app-user "^app\." "^app\." "^app\."
```

## Monitoring

### Prometheus Metrics

```bash
rabbitmq-plugins enable rabbitmq_prometheus
```

Endpoints on port 15692:
- `/metrics` -- aggregated (recommended for most deployments)
- `/metrics/per-object` -- per-entity (expensive for large deployments)
- `/metrics/detailed?family=queue_coarse_metrics` -- filtered per-object

### Critical Alerts

| Metric | Alert Threshold |
|---|---|
| `rabbitmq_detailed_queue_messages` | Growing trend |
| `rabbitmq_detailed_queue_messages_unacked` | Exceeds prefetch * consumers |
| Memory alarm | Any trigger |
| Disk alarm | Any trigger |
| Connection count | Near vhost limit |
| Erlang process count | > 80% of limit |

### Definitions Export/Import
```bash
rabbitmqctl export_definitions /path/to/definitions.json
rabbitmqctl import_definitions /path/to/definitions.json
```

Definitions capture topology (exchanges, queues, bindings, users, vhosts, policies) but NOT messages.

## Migration from 3.13 to 4.x

### Pre-Migration Checklist
1. Remove `classic_queue.default_version = 1` (CQv1 removed; blocks startup)
2. Migrate mirrored classic queues to quorum queues (mirroring removed in 4.0)
3. Upgrade Erlang to 26.2+
4. Test Khepri migration in staging (irreversible)
5. Update client libraries (amqplib Node.js users: upgrade to 0.10.7+ for 4.1)
6. Review AMQP 1.0 durable header defaults (4.2 breaking change)

### Version-Specific Considerations

| Version | Key Changes |
|---|---|
| 4.0 | AMQP 1.0 core, CQ mirroring removed, CQv1 removed, delivery limit default 20 |
| 4.1 | New K8s peer discovery, rabbitmqadmin v2, `force_reset` deprecated |
| 4.2 | Khepri default, SQL stream filters, fanout optimization, quorum default queue type |

## Kubernetes Deployment (4.1+)

```ini
cluster_formation.peer_discovery_backend = rabbit_peer_discovery_k8s
```

- Pod with `-0` suffix acts as seed node
- No Kubernetes API calls required
- Set `publishNotReadyAddresses: true` on headless service
- Reduce CoreDNS caching to 5-10 seconds
- Use StatefulSet with persistent volumes for data durability
