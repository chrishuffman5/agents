# HAProxy Architecture Reference

## Core Design

HAProxy is a high-performance, event-driven TCP/HTTP load balancer designed for maximum reliability and throughput.

### Single-Process Model
- HAProxy runs as a single process (not master/worker like NGINX)
- Multi-threaded since version 2.x: `nbthread` directive scales across CPU cores
- Threads share a single process address space with fine-grained locking
- No inter-process communication overhead (vs multi-process models)

### Event-Driven I/O
- Uses epoll (Linux) / kqueue (BSD) for non-blocking I/O
- Single event loop per thread; each thread handles its share of connections
- No file I/O in the data path: all logging is asynchronous (syslog over UDP/TCP or local socket)
- This design principle ensures predictable latency even under heavy load

### Memory Architecture
- Pre-allocates buffers at startup based on `tune.bufsize` and `maxconn`
- Memory formula: `(tune.bufsize * 2 + ~17kB) * maxconn` per process
- Buffer pool eliminates runtime allocation overhead
- Stick tables use dedicated memory with configurable size limits

## Frontend / Backend Model

### Frontend (Listener)

A frontend defines how HAProxy accepts incoming connections:
- **bind**: IP address, port, SSL parameters
- **ACLs**: Named conditions for routing decisions
- **use_backend**: Conditional backend selection based on ACLs
- **default_backend**: Fallback when no ACL matches
- **http-request**: Request manipulation rules (headers, redirect, deny)

```
Client -> [bind *:443 ssl] -> [ACL evaluation] -> [use_backend] -> Backend
```

Multiple frontends can coexist, each listening on different ports or IPs.

### Backend (Server Pool)

A backend defines a group of servers and how traffic is distributed:
- **balance**: Load balancing algorithm
- **server**: Individual backend server with health check and weight
- **option httpchk**: HTTP-based health checking
- **stick-table**: Session tracking and rate limiting
- **cookie**: Session persistence via cookie

```
Frontend -> Backend -> [balance algorithm] -> [health check filter] -> Server
```

### Listen (Combined)

The `listen` section combines frontend and backend:
- Simpler configuration for straightforward deployments
- Same capabilities as separate frontend/backend
- Commonly used for the stats page

## ACL System Internals

### ACL Processing

ACLs are evaluated in order within `use_backend` directives:

```
frontend http_front
    acl is_api path_beg /api/         # ACL 1
    acl is_admin path_beg /admin/     # ACL 2
    acl is_internal src 10.0.0.0/8    # ACL 3
    
    use_backend api_backend if is_api           # Rule 1 (checked first)
    use_backend admin_backend if is_admin is_internal  # Rule 2
    default_backend web_backend                 # Rule 3 (fallback)
```

Evaluation:
1. Check Rule 1: is_api? If yes -> api_backend. Stop.
2. Check Rule 2: is_admin AND is_internal? If yes -> admin_backend. Stop.
3. No rule matched -> default_backend -> web_backend.

### ACL Fetch Methods

HAProxy provides extensive fetch methods for ACL conditions:

**Layer 3/4 fetches**:
- `src`: Client source IP
- `dst`: Destination IP
- `src_port`, `dst_port`: Port numbers
- `ssl_fc`: Boolean, true if SSL/TLS connection

**Layer 7 fetches (HTTP mode only)**:
- `path`, `path_beg`, `path_end`, `path_reg`: URL path
- `url_param(name)`: URL query parameter
- `hdr(name)`, `hdr_beg()`, `hdr_sub()`, `hdr_reg()`: HTTP headers
- `method`: HTTP method (GET, POST, etc.)
- `req.body`: Request body content
- `cookie(name)`: Cookie value

**Sample fetches (stick table)**:
- `sc_http_req_rate(0)`: HTTP request rate for tracked source
- `sc_conn_cur(0)`: Current connections for tracked source
- `sc_http_err_rate(0)`: HTTP error rate for tracked source
- `sc_gpc0_rate(0)`: General purpose counter rate

## Stick Table Architecture

### How Stick Tables Work

Stick tables are in-memory hash tables storing per-key data:

```
Key (e.g., client IP) -> Data Stores (conn_cur, http_req_rate, gpc0, ...)
                       -> Expiration timer
                       -> Sticky server assignment (optional)
```

### Data Types

| Type | Description | Use Case |
|---|---|---|
| `conn_cur` | Current concurrent connections | Connection limiting |
| `conn_rate(period)` | Connection rate | Connection rate limiting |
| `http_req_rate(period)` | HTTP request rate | Request rate limiting |
| `http_err_rate(period)` | HTTP error rate | Error detection |
| `bytes_in_rate(period)` | Incoming bandwidth rate | Bandwidth limiting |
| `bytes_out_rate(period)` | Outgoing bandwidth rate | Bandwidth monitoring |
| `gpc0`, `gpc1` | General purpose counters | Custom counters (failed logins, etc.) |
| `gpt0` | General purpose tag | Marking (blocklist, whitelist) |
| `server_id` | Server assignment | Session persistence |

### Key Types

| Type | Description | Size |
|---|---|---|
| `ip` | IPv4 address | 4 bytes |
| `ipv6` | IPv6 address | 16 bytes |
| `integer` | 32-bit integer | 4 bytes |
| `string len N` | String up to N bytes | Variable |
| `binary len N` | Binary data up to N bytes | Variable |

### Stick Table Peer Synchronization

Stick tables can be synchronized between HAProxy instances:
```haproxy
peers HAPROXY_PEERS
    peer haproxy1 192.168.1.10:10000
    peer haproxy2 192.168.1.11:10000

backend app_backend
    stick-table type ip size 100k expire 10m store http_req_rate(1m) peers HAPROXY_PEERS
```

**HAProxy 3.0**: Sharded tree structure -- table divided across multiple tree heads with separate locks. ~6x performance improvement on 80-thread systems.

**HAProxy 3.2**: Dedicated sync thread for peer synchronization -- 5-8 million updates/second (up from 500k-1M) on 128-thread systems.

## Runtime API Architecture

### How the Runtime API Works

The runtime API operates through a Unix domain socket:
```
haproxy process <-> Unix socket <-> socat/haproxy-cli client
```

- All commands are text-based (line-oriented protocol)
- Commands are processed synchronously (blocking until complete)
- Changes modify the running process state but do NOT update haproxy.cfg
- After a reload, runtime API changes are lost (config file is authoritative)

### Command Categories

**Information commands** (read-only):
- `show info`: Process-level information
- `show stat`: Per-frontend/backend/server statistics
- `show backend`: List all backends
- `show servers state`: Server states and health
- `show table`: Stick table contents
- `show errors`: Recent error details

**Management commands** (state-changing):
- `disable server`: Stop sending new connections (drain)
- `enable server`: Resume traffic
- `set weight`: Change server weight dynamically
- `set maxconn server`: Change server connection limit
- `clear table`: Remove all stick table entries
- `clear counters`: Reset statistics counters

**3.2 enhancements**:
- `show events`: Event stream with `-0` delimiter for multi-line events
- Array index access: `data.gpt[1]` for stick table array data

### Socket Configuration
```haproxy
global
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats socket ipv4@127.0.0.1:9999 level operator
    stats timeout 30s
```

**Access levels**:
- `user`: Read-only statistics
- `operator`: Read + server enable/disable
- `admin`: Full access including weight changes and table manipulation

**`expose-fd listeners`**: Critical for zero-downtime reloads. Allows the new HAProxy process to inherit listener file descriptors from the old process.

## Multi-Threading Architecture

### Thread Model (HAProxy 2.x+)

```haproxy
global
    nbthread 4    # 4 threads
```

- All threads share the same process address space
- Each thread runs its own event loop
- Connections are distributed across threads via accept queue
- Shared data (stick tables, DNS cache) uses fine-grained locking

### Thread-Local vs Shared State

**Thread-local** (no contention):
- Connection handling
- Buffer management
- Most per-connection state

**Shared** (requires locking):
- Stick tables (sharded locks in 3.0+)
- Server health state
- Statistics counters
- DNS resolver cache
- Peers synchronization

### Thread Scaling

Practical thread count guidelines:
- Start with `nbthread` equal to CPU core count
- Monitor per-thread CPU usage with `show info per-thread`
- For SSL-heavy workloads, threads scale nearly linearly up to ~16 cores
- Beyond 16 cores, stick table locking becomes the bottleneck (improved in 3.0/3.2)

## Zero-Downtime Reload Architecture

### How Reload Works

```
1. Signal: systemctl reload haproxy (sends SIGUSR2 or equivalent)
2. New process starts with new configuration
3. New process inherits listener sockets via expose-fd
4. Old process stops accepting new connections
5. Old process drains existing connections
6. Old process exits after all connections complete (or hard-stop-after timeout)
```

**Key requirement**: `expose-fd listeners` on the stats socket. Without it, the new process cannot inherit sockets, causing a brief connection reset window.

### hard-stop-after

```haproxy
global
    hard-stop-after 30s    # Force-kill old process after 30 seconds
```

If the old process has long-lived connections (WebSocket, streaming), they would keep the old process alive indefinitely. `hard-stop-after` sets a maximum drain time.

## Logging Architecture

### No File I/O in Data Path

HAProxy's logging is deliberately asynchronous and avoids file writes in the traffic processing path:
- All logs sent via syslog protocol (UDP to local syslogd, or TCP to remote)
- No `fwrite()`, `fprintf()`, or similar blocking calls during request processing
- This guarantees consistent latency even when the log destination is slow

### Log Format

```haproxy
defaults
    option httplog          # Detailed HTTP log format
    option dontlognull      # Don't log health check probes
    log /dev/log local0     # Syslog destination
```

**HTTP log format includes**: timestamp, frontend, backend, server, response time (Tq/Tw/Tc/Tr/Tt), status code, bytes, termination flags, session/backend/server connection counts.

### Termination Flags

HAProxy's termination flags in logs indicate how and why a connection ended:
- `--`: Normal completion
- `CD`: Client disconnected
- `SD`: Server disconnected
- `sH`: Server timeout (read)
- `cD`: Client timeout
- `SC`: Server connection refused
- `PH`: Proxy protocol error

These flags are invaluable for diagnosing connection issues.
