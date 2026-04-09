# NGINX + HAProxy — Deep Dive Reference

> Last updated: April 2026 | NGINX Plus R33 / NGINX Ingress Controller 5.x / HAProxy 3.2 LTS / HAProxy 3.3

---

## Part 1: NGINX

---

## 1. NGINX Architecture

### 1.1 Master/Worker Process Model

NGINX uses a single-threaded, event-driven, non-blocking architecture:

```
Master Process
  ├── Worker Process 1  (handles thousands of connections via epoll/kqueue)
  ├── Worker Process 2
  ├── Worker Process N  (typically: worker_processes auto = 1 per CPU core)
  └── Cache Manager / Cache Loader (if caching enabled)
```

**Master Process:**
- Reads and validates configuration
- Creates/destroys worker processes
- Performs hot reload (`nginx -s reload`) — spawns new workers with new config, drains old workers gracefully

**Worker Process:**
- Handles all network I/O using non-blocking system calls (epoll on Linux, kqueue on BSD)
- Each worker is single-threaded; no shared memory between workers (except for shared zones)
- Processes: HTTP, TCP/UDP proxying, SSL, FastCGI, gzip, cache

### 1.2 Connection Model

NGINX is fully asynchronous: one worker handles thousands of simultaneous connections using event loop. This differs from Apache's thread-per-connection model and is highly efficient for high-concurrency, I/O-bound workloads.

---

## 2. Reverse Proxy and Load Balancing

### 2.1 proxy_pass and Upstream

```nginx
upstream app_backend {
    # Load balancing method (default: round_robin)
    least_conn;        # alternatives: ip_hash; hash $request_uri; random;
    
    server 192.168.10.11:8080 weight=3;
    server 192.168.10.12:8080 weight=2;
    server 192.168.10.13:8080 backup;  # only used when primaries are down
    
    keepalive 32;      # persistent connections to upstream
}

server {
    listen 80;
    server_name app.example.com;
    
    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout    60s;
        proxy_send_timeout    60s;
    }
}
```

### 2.2 Load Balancing Methods (OSS)

| Method | Directive | Description |
|---|---|---|
| Round Robin | (default) | Sequential distribution |
| Least Connections | `least_conn` | Send to server with fewest active connections |
| IP Hash | `ip_hash` | Client IP → consistent server (basic session affinity) |
| Generic Hash | `hash $key` | Hash of any variable (URI, cookie, etc.) |
| Random | `random` | Random selection; `random two least_conn` for improved distribution |

---

## 3. SSL/TLS Termination

```nginx
server {
    listen 443 ssl;
    server_name secure.example.com;
    
    ssl_certificate      /etc/ssl/certs/example.crt;
    ssl_certificate_key  /etc/ssl/private/example.key;
    
    # Protocol and cipher configuration
    ssl_protocols        TLSv1.2 TLSv1.3;
    ssl_ciphers          HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Session cache (performance)
    ssl_session_cache    shared:SSL:10m;
    ssl_session_timeout  10m;
    
    # OCSP stapling
    ssl_stapling         on;
    ssl_stapling_verify  on;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
```

---

## 4. Rate Limiting, Caching, Monitoring

**Rate Limiting** uses `limit_req_zone` to define a shared memory zone keyed on `$binary_remote_addr` with a rate (e.g., `rate=10r/s`). Applied per-location with `limit_req zone=X burst=20 nodelay;` — burst allows temporary spikes; `nodelay` returns 429 immediately rather than queueing excess.

**Caching** is configured with `proxy_cache_path` (disk path, key zone, max size) and enabled per-location with `proxy_cache`, `proxy_cache_valid` (per-status TTL), and `proxy_cache_use_stale` (serve stale on error/timeout). `$upstream_cache_status` header reports HIT/MISS/BYPASS.

**stub_status** (OSS monitoring endpoint): exposes active connections, accepts/handled/requests, and reading/writing/waiting counters. Restricted to localhost. NGINX Plus replaces this with the full `/api/` endpoint.

---

## 7. NGINX Plus

NGINX Plus is the commercial version with enterprise features.

### 7.1 Active Health Checks

NGINX Plus proactively probes upstream servers (NGINX OSS only has passive):
```nginx
upstream app_backend {
    server 192.168.10.11:8080;
    server 192.168.10.12:8080;
    
    # NGINX Plus active health check
    zone backend 64k;
}

server {
    location / {
        proxy_pass http://app_backend;
        health_check interval=5s fails=3 passes=2 uri=/health;
    }
}
```

### 7.2 Session Persistence (Sticky Sessions)

```nginx
upstream app_backend {
    server 192.168.10.11:8080;
    server 192.168.10.12:8080;
    zone backend 64k;
    
    # Cookie-based persistence (NGINX Plus)
    sticky cookie srv_id expires=1h domain=.example.com path=/;
    # OR: sticky learn create=$upstream_cookie_session
    #         lookup=$cookie_session zone=client_sessions:1m;
    # OR: sticky route $cookie_route $request_uri;
}
```

### 7.3 Live Activity Monitoring API

NGINX Plus exposes a real-time status API at `/api/` (replaces older `/status`):
```nginx
server {
    listen 8080;
    location /api/ {
        api write=on;
        allow 10.0.0.0/8;
        deny all;
    }
    location /dashboard.html {
        root /usr/share/nginx/html;
    }
}
```

API endpoints: `/api/8/http/upstreams`, `/api/8/stream/upstreams`, `/api/8/connections`, `/api/8/ssl`

### 7.4 Key-Value Store

NGINX Plus provides a shared in-memory key-value store accessible from configuration and API:
```nginx
keyval_zone zone=blocklist:1m;
keyval $remote_addr $blocked zone=blocklist;

server {
    if ($blocked) { return 403; }
}
```
Keys can be set/updated via the REST API dynamically without reload.

### 7.5 JWT Authentication

NGINX Plus validates JWTs natively:
```nginx
server {
    auth_jwt "API Access";
    auth_jwt_key_file /etc/nginx/jwk.json;
    
    location /api/v1/ {
        auth_jwt_claim_set $user sub;
        proxy_set_header X-User $user;
    }
}
```

---

## 8. NGINX Ingress Controller for Kubernetes

NGINX Ingress Controller (nginx/kubernetes-ingress) manages L7 routing for Kubernetes workloads.

> Note: Kubernetes community ingress-nginx (kubernetes/ingress-nginx) was [retired in November 2025](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/). The official F5 NGINX Ingress Controller is the recommended replacement.

### 8.1 Standard Ingress Resources

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.org/proxy-connect-timeout: "10s"
    nginx.org/proxy-read-timeout: "60s"
    nginx.org/client-max-body-size: "10m"
spec:
  ingressClassName: nginx
  tls:
  - hosts: [app.example.com]
    secretName: app-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

### 8.2 VirtualServer CRD (NGINX-specific)

VirtualServer and VirtualServerRoute CRDs enable advanced routing not possible with standard Ingress:

```yaml
apiVersion: k8s.nginx.org/v1
kind: VirtualServer
metadata:
  name: app-vs
spec:
  host: app.example.com
  tls:
    secret: app-tls
  upstreams:
  - name: app-v1
    service: app-v1-service
    port: 80
  - name: app-v2
    service: app-v2-service
    port: 80
  routes:
  - path: /
    splits:
    - weight: 90
      action:
        pass: app-v1
    - weight: 10
      action:
        pass: app-v2     # 10% canary traffic to v2
  - path: /api
    action:
      pass: app-v1
    errorPages:
    - codes: [502, 503]
      return:
        code: 200
        body: '{"error":"service unavailable"}'
```

### 8.3 ConfigMap Global Configuration

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: nginx-config
  namespace: nginx-ingress
data:
  proxy-connect-timeout: "10s"
  keepalive-timeout: "75s"
  worker-processes: "auto"
  log-format: '{"time":"$time_iso8601","remote_addr":"$remote_addr","status":"$status"}'
  ssl-protocols: "TLSv1.2 TLSv1.3"
  hsts: "true"
```

### 8.4 NGINX Ingress Controller (current stable: 5.4.x)

Version 5.x features:
- IPv6 support for VirtualServer/VirtualServerRoute CRDs
- Support for overwriting default client proxy headers in VirtualServer
- WAF (NGINX App Protect) integration for advanced security policies
- mTLS, JWT/OIDC auth with NGINX Plus

---

## Part 2: HAProxy

---

## 10. HAProxy Architecture

### 10.1 Core Design

HAProxy is a high-performance, event-driven, single-process TCP/HTTP load balancer:
- **Single process** (no master/worker split in core design)
- **Multi-threaded since version 2.x**: `nbthread` directive scales across CPU cores; threads share a single process
- **Event-driven**: uses epoll (Linux) / kqueue (BSD) for non-blocking I/O
- **No file I/O in data path**: All logging is async; no blocking writes during proxying

### 10.2 Configuration Structure

```
global          # Process-level settings
defaults        # Default settings inherited by all sections
frontend        # Listener (accepts connections)
backend         # Server pool (sends traffic to servers)
listen          # Combined frontend+backend (shorthand)
```

---

## 11. Frontend, Backend, Listen

### 11.1 Full Example

```haproxy
global
    maxconn 50000
    log /dev/log local0
    nbthread 4
    tune.ssl.default-dh-param 2048

defaults
    mode http
    option httplog
    option dontlognull
    timeout connect  5s
    timeout client   30s
    timeout server   30s
    retries 3

frontend http_front
    bind *:80
    bind *:443 ssl crt /etc/ssl/example.pem alpn h2,http/1.1
    http-request redirect scheme https unless { ssl_fc }
    default_backend app_backend

backend app_backend
    balance leastconn
    option httpchk GET /health HTTP/1.1\r\nHost:\ app.internal
    server app1 192.168.10.11:8080 check weight 10
    server app2 192.168.10.12:8080 check weight 10
    server app3 192.168.10.13:8080 check weight 5 backup

listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats auth admin:password
```

---

## 12. ACLs (Access Control Lists)

ACLs match conditions and are used in routing, blocking, and forwarding decisions:

```haproxy
frontend http_front
    # Define ACLs
    acl is_api          path_beg /api/
    acl is_admin        path_beg /admin/
    acl is_mobile       hdr_sub(User-Agent) -i Mobile
    acl internal_src    src 10.0.0.0/8 192.168.0.0/16
    acl has_auth_header req.hdr(Authorization) -m found

    # Route based on ACLs
    use_backend api_backend     if is_api
    use_backend admin_backend   if is_admin internal_src
    http-request deny           if is_admin !internal_src
    default_backend web_backend
```

---

## 13. Stick Tables

Stick tables are in-memory data stores used for session tracking, rate limiting, and state sharing across HAProxy instances.

### 13.1 Stick Table Definition

```haproxy
backend STICK_RATE_LIMIT
    # Store per-IP: connection count + HTTP request rate (10 min expiry)
    stick-table type ip size 100k expire 10m store conn_cur,http_req_rate(1m),http_err_rate(1m)
```

### 13.2 Rate Limiting Example

```haproxy
frontend http_front
    # Track client IP in stick table
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    
    # Update rate counter for every request
    http-request track-sc0 src
    
    # Deny if more than 100 requests in 10 seconds
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }
```

### 13.3 HAProxy 3.0 Stick Table Improvements

HAProxy 3.0 changed the stick-table locking mechanism to **sharded trees**: the table is divided across multiple tree heads, each with its own lock. This dramatically reduces lock contention under high concurrency — approximately 6x performance improvement measured on 80-thread systems.

HAProxy 3.0 also allows configuring stick tables to track specific HTTP status codes (e.g., 403 errors per client IP) for abuse detection:
```haproxy
stick-table type ip size 50k expire 1m store http_err_rate(1m),http_req_rate(1m)
```

### 13.4 HAProxy 3.2 Stick Table Enhancements

HAProxy 3.2 introduced:
- **Arrays for GPT and GPC data types** in stick tables
- **Dedicated sync thread** for stick-table peer synchronization: 5-8M updates/second (up from 500k-1M) on 128-thread systems
- **Array index access** in configuration: `data.gpt[1]` accesses a specific array element

---

## 14. Health Checks

```haproxy
backend app_backend
    # TCP check (basic)
    option tcp-check
    
    # HTTP check with expected status
    option httpchk GET /health HTTP/1.1\r\nHost:\ app.internal
    http-check expect status 200
    
    # Custom HTTP response check
    http-check expect string "healthy"
    
    server app1 192.168.10.11:8080 check inter 2s rise 2 fall 3
    #    inter: check interval
    #    rise: consecutive successes to mark UP
    #    fall: consecutive failures to mark DOWN
```

External checks are supported via `option external-check` + `external-check command /path/script.sh` for custom application-level health validation.

---

## 15. SSL Offload and L4/L7 Mode

**SSL Offload**: `bind *:443 ssl crt /etc/ssl/certs/bundle.pem` terminates TLS at HAProxy. Use a directory path to support per-SNI certificates. Set `ssl-min-ver TLSv1.2` and cipher suites in `global`. Post-termination, inject `X-Forwarded-Proto: https` and optionally pass the client certificate CN via `ssl_c_s_dn(cn)`.

**L4 (TCP) mode**: `mode tcp` in frontend/backend — passes raw TCP; used for database proxying (MySQL, PostgreSQL), SMTP, arbitrary TCP. No HTTP awareness; `option tcp-check` for health checks.

**L7 (HTTP) mode**: `mode http` — full HTTP parsing; enables ACLs, header manipulation, HTTP health checks, content-based routing. Default mode for web proxying.

---

## 17. Runtime API

The HAProxy Runtime API (formerly "stats socket") allows dynamic reconfiguration without reload.

### 17.1 Enable Runtime API

```haproxy
global
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
```

### 17.2 Common Runtime Commands

```bash
# Via socat or haproxy client
echo "show info" | socat stdio /run/haproxy/admin.sock
echo "show stat" | socat stdio /run/haproxy/admin.sock

# Disable server (drain connections)
echo "disable server app_backend/app1" | socat stdio /run/haproxy/admin.sock

# Enable server
echo "enable server app_backend/app1" | socat stdio /run/haproxy/admin.sock

# Set server weight
echo "set weight app_backend/app1 50" | socat stdio /run/haproxy/admin.sock

# Show stick table contents
echo "show table STICK_RATE_LIMIT" | socat stdio /run/haproxy/admin.sock

# Clear all stick table entries
echo "clear table STICK_RATE_LIMIT" | socat stdio /run/haproxy/admin.sock

# Show events (3.2+: supports -0 delimiter for multi-line events)
echo "show events" | socat stdio /run/haproxy/admin.sock
```

---

## 18. HAProxy Versions

| Version | Type | Status | Notes |
|---|---|---|---|
| **3.0** | LTS | Active maintenance | Long-term support; stick table sharding; requires Python 3.6+ for build |
| **3.1** | Standard | EOL | Short lifecycle; between LTS releases |
| **3.2** | LTS | Active maintenance | Stick table peer sync thread; array stick table types; enhanced show events |
| **3.3** | Current stable | Active | Latest features; standard maintenance lifecycle |

**HAProxy LTS policy**: Every other major release (3.0, 3.2, 3.4...) is LTS with ~3 year support. Standard releases get ~1 year of support.

---

## 20. HAProxy Kubernetes Ingress Controller

HAProxy Technologies provides an official Kubernetes Ingress Controller:
- Supports standard Ingress resources plus HAProxy-specific annotations
- Native integration with HAProxy Enterprise features (WAF, JWT, etc.)
- Dynamic reconfiguration via ConfigMap + CRD without pod restart
- Stick table support for session persistence in Kubernetes
- Load balancing algorithms: roundrobin, leastconn, source, uri, hdr

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    haproxy.org/load-balance: "leastconn"
    haproxy.org/timeout-connect: "5s"
    haproxy.org/rate-limit-requests: "100"
    haproxy.org/rate-limit-period: "1m"
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

---

## References

- [NGINX Ingress Controller Documentation](https://docs.nginx.com/nginx-ingress-controller/)
- [NGINX Ingress Controller Releases](https://docs.nginx.com/nginx-ingress-controller/releases/)
- [Kubernetes ingress-nginx Retirement (Nov 2025)](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)
- [NGINX Ingress vs ingress-nginx Migration Guide](https://blog.nginx.org/blog/migrating-ingress-controllers-part-one)
- [Announcing HAProxy 3.0](https://www.haproxy.com/blog/announcing-haproxy-3-0)
- [HAProxy 3.0 New Features](https://www.haproxy.com/blog/reviewing-every-new-feature-in-haproxy-3-0)
- [Announcing HAProxy 3.2](https://www.haproxy.com/blog/announcing-haproxy-3-2)
- [HAProxy Runtime API — Dynamic Configuration](https://www.haproxy.com/blog/dynamic-configuration-haproxy-runtime-api)
- [HAProxy Stick Tables Tutorial](https://www.haproxy.com/documentation/haproxy-configuration-tutorials/proxying-essentials/custom-rules/stick-tables/)
- [HAProxy show table Runtime API Reference](https://www.haproxy.com/documentation/haproxy-runtime-api/reference/show-table/)
