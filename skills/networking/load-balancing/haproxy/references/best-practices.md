# HAProxy Best Practices Reference

## SSL/TLS Offload Configuration

### Production SSL Setup

```haproxy
global
    # SSL settings
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets
    tune.ssl.default-dh-param 2048
    
    # SSL cache
    tune.ssl.cachesize 50000
    tune.ssl.lifetime 300

frontend https_front
    bind *:443 ssl crt /etc/ssl/certs/bundle.pem alpn h2,http/1.1
    
    # Security headers
    http-response set-header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
    http-response set-header X-Content-Type-Options "nosniff"
    http-response set-header X-Frame-Options "DENY"
    
    # Forward client info
    http-request set-header X-Forwarded-Proto https
    http-request set-header X-Real-IP %[src]
    
    default_backend app_backend
```

### Certificate Bundle Format
HAProxy expects the PEM bundle in a single file, in this order:
1. Server certificate
2. Intermediate certificate(s)
3. Private key

```
-----BEGIN CERTIFICATE-----
(server certificate)
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
(intermediate certificate)
-----END CERTIFICATE-----
-----BEGIN PRIVATE KEY-----
(private key)
-----END PRIVATE KEY-----
```

### Multi-Domain SSL (SNI)

Use a directory of certificate files:
```haproxy
frontend https_front
    bind *:443 ssl crt /etc/ssl/certs/ strict-sni alpn h2,http/1.1
```

HAProxy auto-loads all PEM files in the directory and selects the correct certificate based on SNI.

### HTTP to HTTPS Redirect
```haproxy
frontend http_front
    bind *:80
    http-request redirect scheme https code 301 unless { ssl_fc }
```

## Health Check Design

### HTTP Health Check Best Practices

```haproxy
backend app_backend
    option httpchk
    http-check send meth GET uri /health ver HTTP/1.1 hdr Host app.internal
    http-check expect status 200
    
    server app1 192.168.10.11:8080 check inter 5s rise 2 fall 3
    server app2 192.168.10.12:8080 check inter 5s rise 2 fall 3
```

### Advanced Health Check (Response Body Validation)

```haproxy
backend app_backend
    option httpchk
    http-check send meth GET uri /health ver HTTP/1.1 hdr Host app.internal
    http-check expect status 200
    http-check expect string "status.*ok"    # regex match on body
    
    server app1 192.168.10.11:8080 check inter 5s rise 2 fall 3
```

### Health Check Timing Strategy

| Parameter | Value | Rationale |
|---|---|---|
| `inter` | 5s (standard) | Balance detection speed vs backend load |
| `inter` | 2s (critical) | Faster detection for mission-critical services |
| `rise` | 2 | Require 2 successes before marking UP (prevent flapping) |
| `fall` | 3 | Require 3 failures before marking DOWN (tolerate transient errors) |
| `fastinter` | 1s | Faster check during UP->DOWN or DOWN->UP transition |
| `downinter` | 10s | Slower check when server is already DOWN (reduce load) |

### External Health Check

For complex application health validation:
```haproxy
backend app_backend
    option external-check
    external-check path "/usr/bin:/bin"
    external-check command /usr/local/bin/check_app.sh
    
    server app1 192.168.10.11:8080 check inter 10s
```

Script receives: server IP, server port, server state. Returns 0 for healthy, non-zero for unhealthy.

## Rate Limiting Patterns

### Basic Per-IP Rate Limiting

```haproxy
frontend http_front
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }
    
    default_backend app_backend
```

### Login Endpoint Protection

```haproxy
frontend http_front
    stick-table type ip size 50k expire 5m store gpc0,http_req_rate(1m)
    
    http-request track-sc0 src
    
    # Rate limit login attempts (10 per minute)
    acl login_page path_beg /login
    acl too_many_logins sc_http_req_rate(0) gt 10
    http-request deny deny_status 429 if login_page too_many_logins
    
    default_backend app_backend
```

### Graduated Rate Limiting

```haproxy
frontend http_front
    stick-table type ip size 100k expire 10m store http_req_rate(10s),conn_cur
    
    http-request track-sc0 src
    
    # Soft limit: add delay (tarpit) above 50 req/10s
    http-request tarpit if { sc_http_req_rate(0) gt 50 }
    
    # Hard limit: deny above 200 req/10s
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 200 }
    
    # Connection limit: deny if more than 100 concurrent connections
    http-request deny deny_status 429 if { sc_conn_cur(0) gt 100 }
```

### Abuse Detection (Error-Based)

```haproxy
frontend http_front
    stick-table type ip size 50k expire 1m store http_err_rate(1m),http_req_rate(1m)
    
    http-request track-sc0 src
    
    # Block IPs generating more than 50% error rate with significant traffic
    acl high_error_rate sc_http_err_rate(0) gt 50
    acl significant_traffic sc_http_req_rate(0) gt 20
    http-request deny deny_status 403 if high_error_rate significant_traffic
```

## Connection Management

### Cookie-Based Persistence

```haproxy
backend app_backend
    balance roundrobin
    cookie SERVERID insert indirect nocache httponly secure
    
    server app1 192.168.10.11:8080 check cookie s1
    server app2 192.168.10.12:8080 check cookie s2
```

**Cookie options**:
- `insert`: HAProxy inserts the cookie
- `indirect`: Cookie not passed to backend server
- `nocache`: Adds Cache-Control headers to prevent caching
- `httponly`: Prevents JavaScript access
- `secure`: Cookie only sent over HTTPS

### Connection Reuse

```haproxy
defaults
    http-reuse safe    # reuse backend connections for different clients
```

**http-reuse modes**:
- `never`: No connection reuse (one connection per request)
- `safe`: Reuse only idle connections (safe default)
- `aggressive`: Reuse connections even with pending responses
- `always`: Maximum reuse

### Timeout Configuration

```haproxy
defaults
    timeout connect  5s     # time to establish connection to server
    timeout client   30s    # max inactivity time on client side
    timeout server   30s    # max inactivity time on server side
    timeout http-request 10s  # max time to receive complete HTTP request
    timeout http-keep-alive 5s  # max time for keep-alive between requests
    timeout queue    30s    # max time in server queue
    timeout tunnel   1h     # for WebSocket / tunnel connections
    retries 3               # connection retry attempts
```

**Timeout guidelines**:
- `timeout connect`: Keep short (3-5s); indicates server overload or network issue
- `timeout client/server`: Set based on application behavior; longer for file uploads/downloads
- `timeout http-request`: Protects against slowloris attacks
- `timeout tunnel`: Use for WebSocket connections (set to expected max session duration)

## Kubernetes Integration

### HAProxy Ingress Controller Configuration

**Key annotations**:
```yaml
annotations:
  haproxy.org/load-balance: "leastconn"       # LB algorithm
  haproxy.org/timeout-connect: "5s"            # Connect timeout
  haproxy.org/timeout-server: "30s"            # Server timeout
  haproxy.org/rate-limit-requests: "100"        # Rate limit per source
  haproxy.org/rate-limit-period: "1m"           # Rate limit window
  haproxy.org/cookie-persistence: "SERVERID"    # Session persistence
  haproxy.org/ssl-redirect: "true"              # HTTP->HTTPS redirect
  haproxy.org/check: "true"                     # Enable health checks
  haproxy.org/check-http: "/health"             # Health check URI
```

### ConfigMap Global Settings
```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: haproxy-config
  namespace: haproxy-controller
data:
  maxconn: "50000"
  nbthread: "4"
  ssl-min-ver: "TLSv1.2"
  timeout-connect: "5s"
  timeout-client: "30s"
  timeout-server: "30s"
  syslog-server: "address:10.0.0.5:514, facility:local0"
```

## Performance Tuning

### Global Settings
```haproxy
global
    maxconn 50000           # max total connections
    nbthread 4              # threads (1 per CPU core)
    cpu-map auto:1/1-4 0-3  # pin threads to CPU cores
    
    # Tune buffers
    tune.bufsize 16384      # default 16384; increase for large headers
    tune.maxrewrite 1024    # space reserved for header rewrites
    
    # Tune SSL
    tune.ssl.cachesize 50000
    tune.ssl.lifetime 300
    tune.ssl.maxrecord 0    # auto-tune SSL record size
```

### Backend Tuning
```haproxy
backend app_backend
    # Connection limits per server
    server app1 192.168.10.11:8080 check maxconn 500 maxqueue 100
    
    # Queue timeout (time waiting for a free connection slot)
    timeout queue 10s
    
    # Retry on connection failure
    retries 3
    option redispatch      # retry on a different server after failure
```

### Monitoring with Stats Page
```haproxy
listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats auth admin:secure_password
    stats admin if TRUE    # enable admin actions via stats page
```

**Key stats to monitor**:
- **Scur/Smax**: Current/max sessions per server
- **Slim**: Session limit per server
- **SessRate**: Sessions per second
- **Bin/Bout**: Bytes in/out
- **Dreq/Dresp**: Denied requests/responses
- **Ereq/Econ/Eresp**: Error counts (request/connection/response)
- **Status**: Server health status (UP/DOWN/NOLB/MAINT)
- **Chkfail/Chkdown**: Health check failures / down events

## Common Configuration Patterns

### API Gateway

```haproxy
frontend api_gateway
    bind *:443 ssl crt /etc/ssl/api.pem
    
    # Versioned API routing
    acl is_v1 path_beg /api/v1/
    acl is_v2 path_beg /api/v2/
    
    # Rate limiting
    stick-table type ip size 100k expire 1m store http_req_rate(10s)
    http-request track-sc0 src
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }
    
    # CORS headers
    http-response set-header Access-Control-Allow-Origin "*"
    http-response set-header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
    
    use_backend api_v1 if is_v1
    use_backend api_v2 if is_v2
    default_backend api_v2
```

### Database Load Balancing

```haproxy
listen mysql_cluster
    mode tcp
    bind *:3306
    balance leastconn
    
    option tcp-check
    tcp-check connect
    tcp-check send-binary 00    # MySQL handshake
    
    server db1 192.168.10.20:3306 check inter 5s
    server db2 192.168.10.21:3306 check inter 5s backup
```

### WebSocket Support

```haproxy
frontend ws_front
    bind *:443 ssl crt /etc/ssl/ws.pem
    
    acl is_websocket hdr(Upgrade) -i websocket
    
    use_backend ws_backend if is_websocket
    default_backend web_backend

backend ws_backend
    balance source
    timeout tunnel 1h
    timeout server 1h
    
    server ws1 192.168.10.30:8080 check
    server ws2 192.168.10.31:8080 check
```

## Operational Checklist

### Daily
- [ ] Check stats page for server health (all servers UP)
- [ ] Review error counts (Ereq, Econ, Eresp trending)
- [ ] Verify session rates are within expected range

### Weekly
- [ ] Review stick table utilization (table fill percentage)
- [ ] Check SSL certificate expiration dates
- [ ] Review queue depths (sustained queuing indicates capacity issue)
- [ ] Check log volume and log destination health

### Monthly
- [ ] Review and prune unused backends/servers
- [ ] Capacity planning: maxconn utilization trending
- [ ] Test configuration reload (verify zero-downtime)
- [ ] Review and update rate limiting thresholds based on traffic patterns
