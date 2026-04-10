# Performance & Scalability

## Connection Pooling

### Why Pooling Matters
Database connections are expensive: TCP handshake, TLS negotiation, auth handshake, memory allocation on DB server (PostgreSQL: ~5-10MB per connection). Without pooling, each request opens/closes a connection — latency spikes and DB is connection-exhausted long before it's CPU-exhausted.

### Database Connection Pool Configuration

**Pool sizing**: The correct pool size is smaller than intuition suggests.
```
# PostgreSQL rule of thumb: 2-4 connections per CPU core on DB server
# For a 4-core DB server: 8-16 connections total across all app instances

# Wrong: large pool thinking more = faster
pool_size = 100  # Causes DB-side context switching, memory pressure

# Right: right-sized pool with queueing
pool_size = 10   # Per app instance
pool_timeout = 30  # Wait up to 30s for available connection
pool_max_overflow = 5  # Allow 5 extra connections in burst
```

**SQLAlchemy (Python)**:
```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

engine = create_async_engine(
    "postgresql+asyncpg://user:pass@localhost/db",
    pool_size=10,           # Core pool size
    max_overflow=5,         # Additional connections allowed
    pool_timeout=30,        # Seconds to wait for connection
    pool_recycle=3600,      # Recycle connections after 1 hour (prevents stale connections)
    pool_pre_ping=True,     # Validate connection before use (detect dropped connections)
    echo=False,             # Don't log all SQL in production
)

AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
```

**PgBouncer**: Connection pooler that sits between app and PostgreSQL. Essential for high-connection-count scenarios.
```
# pgbouncer.ini
[databases]
mydb = host=db-server port=5432 dbname=production

[pgbouncer]
pool_mode = transaction  # One of: session, transaction, statement
                          # transaction mode recommended for most apps
max_client_conn = 1000   # App-side connections (from app servers)
default_pool_size = 25   # Actual PostgreSQL connections
```

Pool modes:
- `session`: Connection held for entire client session — one-to-one, no savings
- `transaction`: Connection returned to pool after each transaction — best for most apps
- `statement`: Connection returned after each statement — incompatible with transactions

**Connection pooling for HTTP clients**:
```python
# Python: httpx with connection pooling
import httpx

# Shared client across requests (reuses connections)
client = httpx.AsyncClient(
    limits=httpx.Limits(
        max_connections=100,
        max_keepalive_connections=20,
        keepalive_expiry=30.0
    ),
    timeout=httpx.Timeout(5.0, connect=2.0)
)

# JavaScript: axios with keep-alive
const https = require('https');
const agent = new https.Agent({ 
  keepAlive: true,
  maxSockets: 50,
  keepAliveMsecs: 3000
});
```

---

## Request Lifecycle and Middleware Overhead

### Middleware Pipeline Cost
Each middleware adds latency. In high-RPS scenarios, even 1ms per middleware × 10 middlewares = 10ms overhead.

```javascript
// Express middleware order matters for performance
app.use(helmet());          // ~0.1ms: security headers
app.use(compression());     // ~1-5ms: response compression (CPU cost)
app.use(morgan('combined')); // ~0.5ms: logging (I/O can be async)
app.use(cors(corsOptions));  // ~0.1ms: CORS headers
app.use(rateLimit(config));  // ~0.5ms: Redis lookup
app.use(authenticate);       // ~1-2ms: JWT verification (CPU)
app.use(express.json());     // ~0.5ms: body parsing
```

**Optimization**: Apply expensive middleware only to routes that need it.
```javascript
// Wrong: auth runs on every request including /health
app.use(authenticate);

// Right: auth only on protected routes
app.get('/health', healthHandler);
app.use('/api', authenticate, apiRouter);
```

### Request Tracing
Propagate trace context through the system:
```
# W3C Trace Context standard
traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
#            version-traceId(16 bytes hex)-spanId(8 bytes hex)-flags

tracestate: rojo=00f067aa0ba902b7,congo=t61rcWkgMzE

# OpenTelemetry auto-instruments popular libraries
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

FastAPIInstrumentor.instrument_app(app)
SQLAlchemyInstrumentor().instrument()
HTTPXClientInstrumentor().instrument()
```

---

## Serialization/Deserialization

### JSON Performance

JSON is human-readable but slow to parse at scale. Alternatives:

| Format          | Size    | Speed    | Human-Readable | Schema Required |
|-----------------|---------|----------|----------------|-----------------|
| JSON            | 100%    | Baseline | Yes            | No              |
| MessagePack     | ~50-70% | 2-4x     | No             | No              |
| Protocol Buffers| ~30-50% | 5-10x    | No             | Yes             |
| FlatBuffers     | ~50-70% | 10-50x   | No             | Yes             |
| CBOR            | ~50-70% | 2-3x     | No             | No              |
| Avro            | ~30-50% | 3-5x     | No             | Yes (registry)  |

**When to switch from JSON**:
- High-volume internal service communication (thousands of calls/second)
- Large payloads where bandwidth is a concern
- Latency-sensitive paths where parsing overhead is measurable
- Kafka/message queue where schema evolution is needed (Avro with Schema Registry)

**JSON optimization before switching**:
```python
# Python: ujson / orjson (5-10x faster than stdlib json)
import orjson

# Pydantic v2 uses Rust-based serializer internally — fast enough for most cases
# FastAPI uses Pydantic v2 by default

# Selective serialization
@app.get("/users")
async def get_users() -> list[UserResponse]:
    users = await db.execute(select(User))
    # Use model_validate (not dict()) for performance
    return [UserResponse.model_validate(u) for u in users.scalars()]
```

```javascript
// Node.js: fast-json-stringify (pre-compiled schema)
const fastJson = require('fast-json-stringify')
const stringify = fastJson({
  type: 'object',
  properties: {
    id: { type: 'string' },
    name: { type: 'string' },
    created_at: { type: 'string' }
  }
})

// 10x faster than JSON.stringify for known schemas
app.get('/users/:id', async (req, res) => {
  const user = await getUser(req.params.id);
  res.send(stringify(user));
});
```

### Protocol Buffers Example
```protobuf
// order.proto
syntax = "proto3";

message Order {
  string id = 1;
  string user_id = 2;
  int32 total_cents = 3;
  OrderStatus status = 4;
  repeated OrderItem items = 5;
}

enum OrderStatus {
  PENDING = 0;
  CONFIRMED = 1;
  SHIPPED = 2;
}

message OrderItem {
  string product_id = 1;
  int32 quantity = 2;
  int32 unit_price_cents = 3;
}
```

Use Protobuf for: gRPC services, Kafka messages, data lakes. Avoid for: public APIs (tooling burden on clients), APIs where schema changes are frequent.

---

## Async vs Sync Processing Models

### When Async Wins

**I/O-bound workloads**: If a request spends 80% of time waiting for DB/external API:
```
Thread model: 100 threads × 200ms DB wait = 100 RPS
Async model:  1 thread × 200ms DB wait × 1000 concurrent = 5000 RPS
```

```python
# Concurrent I/O with asyncio (Python)
async def get_dashboard_data(user_id: str):
    # All three execute concurrently — not sequentially
    profile, orders, notifications = await asyncio.gather(
        user_service.get_profile(user_id),
        order_service.get_recent(user_id, limit=5),
        notification_service.get_unread(user_id),
    )
    # Total time = max(t_profile, t_orders, t_notifications)
    # Not sum of all three
    return {profile, orders, notifications}
```

### When Sync Wins

**CPU-bound workloads**:
```python
# Image processing, ML inference, compression, encryption
# Async yields no benefit; blocking is the right call
def process_image(image_data: bytes) -> bytes:
    img = PIL.Image.open(io.BytesIO(image_data))
    img = img.resize((800, 600), PIL.Image.LANCZOS)
    output = io.BytesIO()
    img.save(output, format='JPEG', quality=85)
    return output.getvalue()
# This is CPU-bound; async adds complexity without benefit
# Run in thread pool (ThreadPoolExecutor) if in async context
```

**Sync with worker process model** (Gunicorn/uWSGI):
```
# Gunicorn pre-forks N worker processes
# Each worker handles one request at a time
# Total concurrency = N workers × 1
# Works fine when requests are fast (< 50ms)
gunicorn app:app --workers 4 --worker-class sync

# For async
gunicorn app:app --workers 4 --worker-class uvicorn.workers.UvicornWorker
```

### Thread Pool vs Process Pool
```python
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
import asyncio

# ThreadPoolExecutor: for I/O-bound blocking libraries
# (shares memory, GIL-limited for CPU work in Python)
async def call_blocking_sdk(params):
    loop = asyncio.get_event_loop()
    with ThreadPoolExecutor(max_workers=10) as pool:
        result = await loop.run_in_executor(pool, blocking_sdk_call, params)
    return result

# ProcessPoolExecutor: for CPU-bound work
# (separate memory space, true parallelism, bypasses GIL)
async def heavy_computation(data):
    loop = asyncio.get_event_loop()
    with ProcessPoolExecutor(max_workers=4) as pool:
        result = await loop.run_in_executor(pool, cpu_intensive_fn, data)
    return result
```

---

## Background Job Processing

### Queue-Based Architecture
```
                ┌─────────────┐
  HTTP Request  │  Web Server │
  POST /orders  │             │── enqueue job ──► Queue (Redis/SQS/RabbitMQ)
                └──────┬──────┘                         │
                       │                                 ▼
                   201 Accepted              ┌──────────────────────┐
                   {job_id: "xyz"}           │  Worker Process(es)  │
                                             │  - Process jobs       │
                                             │  - Retry on failure   │
                                             └──────────────────────┘
```

### Job Queue Implementations

**Redis-based (Celery/RQ for Python, BullMQ for Node)**:
```python
# Celery task definition
from celery import Celery
from kombu import Queue

app = Celery('tasks', broker='redis://localhost:6379/0')

app.conf.task_queues = [
    Queue('high', routing_key='high'),
    Queue('default', routing_key='default'),
    Queue('low', routing_key='low'),
]

@app.task(
    bind=True,
    max_retries=3,
    default_retry_delay=60,  # seconds
    queue='default',
    acks_late=True,          # Acknowledge after processing (not before)
    reject_on_worker_lost=True
)
def send_order_confirmation(self, order_id: str):
    try:
        order = Order.objects.get(id=order_id)
        email_service.send_confirmation(order)
    except Exception as exc:
        raise self.retry(exc=exc, countdown=2 ** self.request.retries * 60)

# Enqueue from web handler
send_order_confirmation.apply_async(
    args=[order.id],
    countdown=0,      # Delay in seconds
    expires=3600,     # Expire if not consumed in 1 hour
    priority=5,       # 0-9, higher = more important
)
```

```javascript
// BullMQ (Node.js)
import { Queue, Worker } from 'bullmq';

const orderQueue = new Queue('orders', { 
  connection: { host: 'localhost', port: 6379 },
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 1000 },
    removeOnComplete: 100,  // Keep last 100 completed jobs
    removeOnFail: 1000,
  }
});

// Enqueue
await orderQueue.add('send-confirmation', { orderId: '123' });

// Worker
const worker = new Worker('orders', async (job) => {
  await sendOrderEmail(job.data.orderId);
}, { connection, concurrency: 5 });
```

### Job Processing Patterns

**Fan-out**: One trigger, many parallel jobs
```python
# Order placed → parallel jobs
order_placed.si(order_id).apply_async()

# Triggers fan-out via Celery chord
chord([
    send_confirmation_email.s(order_id),
    update_inventory.s(order_id),
    notify_warehouse.s(order_id),
    update_analytics.s(order_id),
])(order_processing_complete.s(order_id))
```

**Deduplication**:
```python
# Prevent duplicate jobs with idempotency
@app.task
def process_payment(order_id: str):
    task_id = f"payment:{order_id}"
    if redis.set(task_id, "1", nx=True, ex=3600):  # nx=only set if not exists
        # Process payment
        pass
    else:
        # Already processing or processed
        pass
```

**Dead Letter Queue (DLQ)**: Failed jobs that exceed retry limit go to DLQ for manual inspection/replay.

---

## Horizontal Scaling Patterns

### Stateless Design (12-Factor App principle)
Application instances share no local state. All state in external stores.

```
# Wrong: state in process memory
user_sessions = {}  # Lost on restart, not shared with other instances

# Right: state in Redis
redis.setex(f"session:{session_id}", 3600, json.dumps(session_data))

# Wrong: uploaded files on local disk
# /uploads/user_123.jpg — only on instance 1

# Right: shared object storage
s3.upload_file(file_data, bucket='uploads', key=f'user_{user_id}/avatar.jpg')
```

**Checklist for stateless service**:
- No in-memory session storage
- No local file system writes (except ephemeral/temp)
- No local cache that isn't sharable (use Redis)
- Config from environment variables, not files
- Logs to stdout (not files), collected by log aggregator

### Shared-Nothing Architecture
Each service instance is fully independent. No shared mutable state between instances at the application layer.

```
Instance 1: handles request, reads from DB, writes to DB
Instance 2: handles request, reads from DB, writes to DB
# Coordination only through the database (and queues, cache)
# Optimistic locking prevents conflicts
```

### Sticky Sessions
When state is unavoidable at instance level, load balancer routes same user to same instance:
```nginx
# Nginx upstream with sticky sessions
upstream backend {
    ip_hash;  # Route by client IP (crude)
    server app1:8080;
    server app2:8080;
}

# Better: cookie-based sticky (requires nginx-sticky-module or commercial)
# Best: eliminate need for sticky sessions entirely
```

Sticky sessions break horizontal scaling — one overloaded instance doesn't shedload. Prefer shared state (Redis) over sticky.

### Database Scaling

**Read replicas**:
```python
# Route reads to replica, writes to primary
class SmartSession:
    primary = create_engine(PRIMARY_DB_URL)
    replica = create_engine(REPLICA_DB_URL)
    
    def get_session(self, readonly=False):
        engine = self.replica if readonly else self.primary
        return Session(engine)

# DJango: DATABASE_ROUTERS
class ReadWriteRouter:
    def db_for_read(self, model, **hints):
        return 'replica'
    def db_for_write(self, model, **hints):
        return 'primary'
```

**Vertical (scale up) vs Horizontal (scale out)**:
- Database: scale up (vertical) first — easier, PostgreSQL scales well on large instances
- Application layer: scale out (horizontal) easily if stateless
- Cache layer: horizontal (Redis Cluster)

---

## Load Testing

### Tools Comparison

**k6 (Grafana)**:
```javascript
// k6 script
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Ramp up to 50 users
    { duration: '2m', target: 50 },    // Hold for 2 minutes
    { duration: '30s', target: 200 },  // Spike to 200
    { duration: '1m', target: 200 },   // Hold
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests under 500ms
    http_req_failed: ['rate<0.01'],    // Less than 1% failure rate
  },
};

export default function () {
  const res = http.post('http://api.example.com/orders', 
    JSON.stringify({ item_id: 'abc', qty: 1 }),
    { headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${TOKEN}` } }
  );
  
  check(res, {
    'status is 201': (r) => r.status === 201,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
}
```

**Locust (Python)**:
```python
from locust import HttpUser, task, between

class OrderUser(HttpUser):
    wait_time = between(1, 3)
    
    def on_start(self):
        response = self.client.post('/auth/login', json={
            'username': 'test@example.com', 'password': 'password'
        })
        self.token = response.json()['access_token']
    
    @task(3)  # Weight: runs 3x more than other tasks
    def list_orders(self):
        self.client.get('/orders', headers={'Authorization': f'Bearer {self.token}'})
    
    @task(1)
    def create_order(self):
        self.client.post('/orders',
            json={'item_id': 'abc', 'quantity': 1},
            headers={'Authorization': f'Bearer {self.token}'}
        )
```

**wrk** (HTTP benchmarking, not scripted):
```bash
# 12 threads, 400 connections, 30 second test
wrk -t12 -c400 -d30s --latency http://api.example.com/health

# With Lua script for complex requests
wrk -t4 -c100 -d60s -s post_order.lua http://api.example.com/orders
```

**hey** (Apache Bench replacement):
```bash
hey -n 10000 -c 100 -m POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"item_id": "abc", "qty": 1}' \
  http://api.example.com/orders
```

### Load Testing Methodology

**Types of tests**:
- **Load test**: Normal expected load — verify P95/P99 within SLA
- **Stress test**: Beyond expected load — find breaking point
- **Soak test**: Extended normal load — find memory leaks, connection leaks
- **Spike test**: Sudden burst — verify auto-scaling, graceful degradation
- **Capacity test**: Find maximum throughput before failure

**What to measure**:
```
P50 (median) — typical user experience
P95 — 1 in 20 requests slower than this
P99 — 1 in 100 requests slower than this
P99.9 — tail latency (often outliers from GC, lock contention)

Error rate — target < 0.1% at expected load
Throughput — RPS at sustainable load
Resource saturation — CPU, memory, connections at peak
```

**Key metrics to instrument**:
```python
# Use Prometheus + Grafana for production metrics
from prometheus_client import Histogram, Counter, Gauge

REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint', 'status_code'],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)

DB_POOL_AVAILABLE = Gauge(
    'db_connection_pool_available',
    'Available database connections'
)

# Alert thresholds
# P99 > 1s: investigate
# Error rate > 1%: page on-call
# DB pool available < 2: imminent connection exhaustion
```

### Common Bottleneck Patterns

1. **N+1 queries**: Loading list of 100 items, then querying DB for each item's related data = 101 queries
   - Fix: `select_related()` (Django), `.include()` (Sequelize), DataLoader (GraphQL)

2. **Missing indexes**: Full table scan on large tables
   - Fix: `EXPLAIN ANALYZE` to identify, add composite index

3. **Serialization overhead**: Converting ORM models to JSON on every request
   - Fix: Cache serialized responses, use faster JSON library

4. **Synchronous external calls in critical path**: Payment gateway call blocking request thread
   - Fix: Async external calls, circuit breaker pattern, timeout + fallback

5. **Lock contention**: High-write endpoints competing for row locks
   - Fix: Optimistic locking, queue-based processing, partitioning writes

6. **Connection pool exhaustion**: More concurrent requests than DB connections
   - Fix: Right-size pool, reduce query time, add read replicas, PgBouncer

7. **Memory allocation rate**: Excessive object creation causing GC pressure
   - Fix: Object pooling, streaming large responses, reducing allocations in hot paths
