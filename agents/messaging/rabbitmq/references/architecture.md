# RabbitMQ Architecture Reference

## Broker Model

RabbitMQ is a message broker implementing a store-and-forward model. Publishers send messages to exchanges; exchanges route to queues or streams via bindings; consumers receive from queues/streams.

### Core Components

- **Node**: Single RabbitMQ server process (Erlang VM / BEAM)
- **Cluster**: Multiple nodes sharing metadata; queue replicas distributed based on queue type
- **Virtual host (vhost)**: Logical isolation boundary with its own exchanges, queues, bindings, users, policies
- **Exchange**: Routing entity receiving messages from publishers
- **Queue**: Storage entity holding messages for consumers
- **Stream**: Append-only log storage entity (consuming does not remove messages)
- **Binding**: Routing rule linking exchange to queue/stream/exchange
- **Connection**: TCP connection between client and broker
- **Channel**: Lightweight virtual connection multiplexed over a TCP connection

## Exchange Types

### Direct Exchange
Exact routing key match. Default exchange (`""`) is a pre-declared direct exchange; every queue is automatically bound with its name as routing key.

### Fanout Exchange
Ignores routing key. Routes a copy of every message to every bound destination. Use for broadcast and event fan-out. 4.2 includes up to 42% throughput optimization for fanout.

### Topic Exchange
Routing key segments separated by `.`. Wildcards: `*` (one segment), `#` (zero or more). Example: `orders.*.shipped` matches `orders.us.shipped` but not `orders.shipped`.

### Headers Exchange
Routes based on message header attributes. `x-match: all` requires all headers to match; `x-match: any` requires at least one. Routing key ignored.

### Alternate Exchanges
Unroutable messages forwarded to configured alternate exchange instead of being dropped:
```bash
rabbitmqctl set_policy AE ".*" '{"alternate-exchange":"my-ae"}' --apply-to exchanges
```

### Exchange-to-Exchange (E2E) Bindings
Exchanges can be bound to other exchanges. Messages route through combined bindings without republishing.

## Queue Types

### Quorum Queues (Production Default)

Replicated via Raft consensus (Multi-Raft). Default replication factor: 3 (or cluster size if smaller).

**Features:** Durable, delivery limits (default 20), DLX (at-least-once), two-tier priority (normal/high in 4.0+), checkpoints for sub-linear recovery.

**Does NOT support:** Non-durable, exclusive, global QoS, server-named queues, full priority levels.

**Declaration:**
```python
channel.queue_declare(
    queue='orders.processing',
    durable=True,
    arguments={'x-queue-type': 'quorum'}
)
```

**Membership management:**
```bash
rabbitmq-queues add_member -p /myvhost my.queue rabbit@node3
rabbitmq-queues delete_member -p /myvhost my.queue rabbit@node3
rabbitmq-queues rebalance quorum
```

**Continuous Membership Reconciliation (CMR):**
```ini
quorum_queue.continuous_membership_reconciliation.enabled = true
quorum_queue.continuous_membership_reconciliation.target_group_size = 3
```

**Memory:** ~32 bytes metadata per message. Allocate 3-4x WAL file size (default 512 MiB WAL = ~2 GiB RAM for queue operations).

### Classic Queues (Non-Replicated)

**Not replicated** in 4.x (mirroring removed in 4.0). CQv2 storage only. Supports full priority levels (`x-max-priority`, 1-10 in practice), per-message TTL, queue TTL, DLX, max-length. Best for scratch queues and short-lived data.

### Streams

Append-only, immutable log. Consuming does not remove messages. Multiple consumers read same data at different offsets.

```python
channel.queue_declare(
    queue='events.audit',
    durable=True,
    arguments={
        'x-queue-type': 'stream',
        'x-max-length-bytes': 10737418240,   # 10 GB
        'x-max-age': '7D',                   # 7 days retention
        'x-stream-max-segment-size-bytes': 524288000  # 500 MB segments
    }
)
```

**Consumer offset options** (`x-stream-offset`): `first`, `last`, `next`, specific integer offset, POSIX timestamp, relative interval.

**Super streams** (partitioned streams):
```bash
rabbitmq-streams add_super_stream invoices --partitions 3
```

**Message deduplication:** Named producers with stable identity and strictly increasing publishing IDs. Broker tracks highest ID per producer.

## Khepri Metadata Store

Raft-based, tree-structured replicated database replacing Mnesia.

**Status timeline:** 3.13 (experimental) -> 4.0 (stable, opt-in) -> 4.1 (stable) -> 4.2 (default for new deployments) -> 4.3+ (Mnesia dropped)

**Advantages over Mnesia:** Unified Raft consensus (same as quorum queues), well-defined partition behavior, eliminates binding inconsistency bugs, hierarchical data model.

**Migration:** Runs in parallel with normal operations. Brief pause near end. Irreversible.

```bash
rabbitmqctl enable_feature_flag khepri_db
rabbitmq-diagnostics metadata_store_status
```

## Clustering

### Peer Discovery Backends

| Backend | Configuration Key | Notes |
|---|---|---|
| Classic config (static) | `rabbit_peer_discovery_classic_config` | Hardcoded node list |
| DNS | `rabbit_peer_discovery_dns` | A/AAAA records |
| Kubernetes (4.1+) | `rabbit_peer_discovery_k8s` | Pod `-0` as seed; no K8s API calls |
| AWS EC2 | `rabbit_peer_discovery_aws` | Auto-scaling group |
| Consul | `rabbit_peer_discovery_consul` | Service discovery |

### Network Partition Handling

| Strategy | Behavior | Use Case |
|---|---|---|
| `ignore` | No action; nodes diverge | Same rack, reliable network |
| `pause_minority` | Minority pauses | Cross-rack/AZ, 3+ nodes |
| `autoheal` | Restart losing partition | Prioritize continuity |
| `pause_if_all_down` | Pause if specified nodes unreachable | Custom topology |

**Do NOT use `pause_minority` with 2-node clusters** -- any failure pauses both.

### Manual Cluster Operations
```bash
rabbitmqctl cluster_status
rabbitmqctl stop_app
rabbitmqctl join_cluster rabbit@node1
rabbitmqctl start_app
rabbitmqctl forget_cluster_node rabbit@dead-node
```

## Connections and Channels

**Connection:** Long-lived TCP connection. One per application instance (or connection pool). Separate connections for publishing and consuming (flow control is per-connection).

**Channel:** Lightweight virtual connection multiplexed over TCP. One channel per thread. Cheap to create and close.

**Heartbeats:** Configure >= 5 seconds (`heartbeat = 60` in rabbitmq.conf).

## Virtual Hosts

Each vhost is a completely isolated namespace:
```bash
rabbitmqctl add_vhost my-app-prod --description "Production"
rabbitmqctl set_permissions -p my-app-prod my-user ".*" ".*" ".*"
rabbitmqctl set_vhost_limits -p my-app-prod '{"max-connections": 100, "max-queues": 500}'
```

## Protocols

### AMQP 1.0 (4.0+ Core)
Native core protocol (no longer a plugin). Single Erlang process per session (was 15 in 3.13). Throughput doubled, memory reduced 56% vs 3.13. 4.1 adds filter expressions for stream consumers. 4.2 adds SQL filters and Direct Reply-To.

**Breaking (4.2):** Messages without explicit durable headers default to non-durable (spec compliance).

### MQTT 5.0
Plugin `rabbitmq_mqtt`. Native routing since 3.12 (no AMQP 0-9-1 proxy). Topics map to AMQP routing keys (`.` to `/`). QoS 0 (at-most-once) and QoS 1 (at-least-once). 4.1: max packet size reduced to 16 MiB default.

## Message Reliability

### Publisher Confirms
```python
channel.confirm_delivery()
for msg in messages:
    channel.basic_publish(exchange='', routing_key='queue', body=msg)
channel.wait_for_confirms_or_die()
```

### Consumer Acknowledgments
```python
channel.basic_qos(prefetch_count=50)
# Manual ack after processing
channel.basic_ack(delivery_tag=method.delivery_tag)
# Reject to DLX
channel.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
```

### Dead Letter Exchange (DLX)
Messages dead-letter on: reject with `requeue=False`, TTL expiry, queue overflow (max-length), delivery limit exceeded (quorum queues).

**At-least-once dead lettering** (quorum queues): requires `dead-letter-strategy=at-least-once`, `overflow=reject-publish`, target must be quorum queue or stream.
