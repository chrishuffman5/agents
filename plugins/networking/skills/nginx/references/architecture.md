# NGINX Architecture Reference

## Master/Worker Process Model

### Master Process
- Runs as root (requires privileged ports 80/443)
- Reads and validates configuration files
- Creates, manages, and destroys worker processes
- Handles signals: `reload`, `stop`, `quit`, `reopen`
- Performs binary upgrade (hot swap of NGINX binary)

### Worker Processes
- Run as unprivileged user (typically `nginx` or `www-data`)
- Each worker is single-threaded
- Handle all client connections via non-blocking I/O event loop
- Number of workers: `worker_processes auto` (1 per CPU core, recommended)
- Workers do not share memory directly; communication via shared memory zones

### Event Loop (epoll/kqueue)

Each worker uses the OS event notification mechanism:
- **Linux**: `epoll` (O(1) event notification)
- **FreeBSD/macOS**: `kqueue`
- **Solaris**: `eventport`

The event loop:
```
1. Worker calls epoll_wait() -- blocks until events are ready
2. OS notifies worker of ready file descriptors (sockets with data)
3. Worker processes ALL ready events in a single iteration
4. Worker calls epoll_wait() again
```

This allows a single worker to handle thousands of concurrent connections without thread context switching overhead.

### Connection Handling

```
worker_connections 1024;    # max connections per worker (default)
# Total max connections = worker_processes * worker_connections
# With 4 workers: 4 * 1024 = 4,096 connections
# For reverse proxy: each client connection uses 2 fds (client + upstream)
# Effective max: worker_connections / 2 = 512 proxied connections per worker
```

For high-traffic servers, increase `worker_connections` to 4096 or higher. Monitor with `stub_status` to track active connections vs limits.

### Shared Memory Zones

Shared memory zones allow data sharing across worker processes:
- **`limit_req_zone`**: Rate limiting counters shared across workers
- **`limit_conn_zone`**: Connection count shared across workers
- **`proxy_cache_path ... keys_zone`**: Cache metadata shared across workers
- **`upstream ... zone`**: Upstream state (health, connections) shared across workers (Plus)

Zone sizing: `zone=name:size` where size is the shared memory allocation. 1MB typically stores ~8,000 to 16,000 keys.

## NGINX Plus Architecture

### Runtime State Management

NGINX Plus adds a real-time API that exposes and modifies internal state:

**API Architecture**:
```
/api/{version}/          # API root
  /http/upstreams/       # HTTP upstream groups and servers
  /stream/upstreams/     # TCP/UDP upstream groups
  /connections/          # Active connections
  /ssl/                  # SSL session statistics
  /http/server_zones/    # Per-server-block statistics
  /http/caches/          # Cache zone statistics
  /resolvers/            # DNS resolver statistics
```

**Write API** (`api write=on`):
- Add/remove upstream servers dynamically
- Modify server parameters (weight, max_conns, down)
- Drain servers gracefully
- Changes persist until next reload (not saved to config file)

### Active Health Check Architecture

NGINX Plus health checks run inside the worker processes:
- Each worker independently probes upstream servers
- Health state stored in shared memory zone (consistent across workers)
- Probe runs on configurable interval regardless of client traffic
- Server marked down after `fails` consecutive failures
- Server marked up after `passes` consecutive successes

**Health check types**:
- HTTP: Send request, check status code and/or body content
- TCP: TCP connection establishment
- gRPC: gRPC health checking protocol
- Match block: Custom response validation

```nginx
# Custom health check with match block
match app_healthy {
    status 200;
    header Content-Type ~ "application/json";
    body ~ '"status":"ok"';
}

location / {
    proxy_pass http://app_backend;
    health_check match=app_healthy interval=5s;
}
```

### Session Persistence Architecture

NGINX Plus session persistence is implemented in the upstream module:

**Cookie Insert** (`sticky cookie`):
1. First request from client: no session cookie present
2. NGINX selects upstream server via configured algorithm
3. NGINX inserts cookie in response identifying the selected server
4. Subsequent requests from client include cookie
5. NGINX reads cookie and routes to the same server
6. If server is down: re-assign and update cookie

**Learn** (`sticky learn`):
1. NGINX observes upstream server setting a cookie (e.g., `JSESSIONID`)
2. NGINX creates a mapping: cookie value -> upstream server
3. Subsequent requests with same cookie value go to same server

**Route** (`sticky route`):
1. NGINX evaluates variables (`$cookie_route`, `$request_uri`, etc.)
2. Variable value used as routing key to select server
3. Consistent routing for same key value

### Key-Value Store Architecture

NGINX Plus provides an in-memory key-value store:
- Stored in shared memory zone (accessible by all workers)
- Read/write via REST API (no reload needed)
- Read from NGINX configuration via `keyval` directive
- Use cases: dynamic blocklists, feature flags, A/B testing

## NGINX Ingress Controller Architecture

### Controller Design

```
+-----------------------+
| NGINX Ingress Pod     |
| +-------------------+ |
| | Controller (Go)   | |  <-- Watches K8s API for Ingress/CRD changes
| |   |               | |
| |   v               | |
| | nginx.conf        | |  <-- Generates config from K8s resources
| |   |               | |
| |   v               | |
| | NGINX worker(s)   | |  <-- Handles traffic
| +-------------------+ |
+-----------------------+
```

1. Controller (written in Go) watches Kubernetes API server
2. When Ingress, VirtualServer, ConfigMap resources change, controller generates new nginx.conf
3. Controller reloads NGINX with new configuration
4. NGINX workers handle incoming traffic based on generated config

### Resource Types

**Standard Ingress**: Basic host/path routing, TLS termination. Limited features.

**VirtualServer CRD** (NGINX-specific):
- Traffic splitting (canary, blue-green)
- Custom error pages
- Per-route health checks
- Rate limiting per route
- WAF integration (App Protect)

**VirtualServerRoute CRD**: Delegated routing for multi-team ownership of paths under a single hostname.

**TransportServer CRD**: TCP/UDP load balancing (Layer 4 in Kubernetes).

### Configuration Sources

NGINX Ingress Controller configuration comes from multiple sources (in priority order):
1. **VirtualServer/VirtualServerRoute CRDs**: Per-resource configuration
2. **Ingress annotations**: Per-Ingress resource configuration
3. **ConfigMap**: Global default configuration
4. **Command-line arguments**: Controller startup options

### Current Stable Version (5.x)

NGINX Ingress Controller 5.x features:
- IPv6 support for VirtualServer/VirtualServerRoute CRDs
- Overwriting default client proxy headers in VirtualServer
- WAF (NGINX App Protect) integration
- mTLS and JWT/OIDC auth with NGINX Plus
- Gateway API support (evolving)

## Performance Characteristics

### Connection Capacity

NGINX can handle 10,000+ concurrent connections per worker process with typical workloads:
- Limiting factor: available file descriptors and memory
- Set `worker_rlimit_nofile` to at least 2x `worker_connections`
- Monitor with `stub_status` (OSS) or `/api/` (Plus)

### Throughput

NGINX throughput is typically limited by:
1. **SSL handshake CPU**: TLS 1.3 is faster than 1.2; ECDSA certs faster than RSA
2. **Upstream response time**: NGINX waits for backend; slow backends reduce throughput
3. **Buffering**: `proxy_buffering on` (default) buffers upstream responses in memory/disk
4. **Compression**: `gzip on` adds CPU load but reduces bandwidth

### Memory Usage

- Base process: ~5-10 MB per worker
- Each connection: ~256 bytes (varies with buffers and modules)
- Shared zones: Explicitly sized in config
- Cache: Disk-based with memory keys zone for metadata
- SSL session cache: Configured explicitly (`ssl_session_cache shared:SSL:10m`)
