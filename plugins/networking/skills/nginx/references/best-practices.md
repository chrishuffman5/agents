# NGINX Best Practices Reference

## Upstream Configuration

### Connection Management

**Keepalive connections to upstream**:
```nginx
upstream app_backend {
    server 192.168.10.11:8080;
    server 192.168.10.12:8080;
    
    keepalive 32;              # idle keepalive connections per worker
    keepalive_requests 1000;   # max requests per keepalive connection
    keepalive_timeout 60s;     # idle timeout for keepalive connections
}

server {
    location / {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;                  # required for keepalive
        proxy_set_header Connection "";           # clear Connection header
    }
}
```

**Critical**: `proxy_http_version 1.1` and `proxy_set_header Connection ""` are required for upstream keepalive to work. HTTP/1.0 defaults to `Connection: close`.

### Timeout Configuration

```nginx
location / {
    proxy_connect_timeout 5s;    # time to establish connection to upstream
    proxy_read_timeout    60s;   # time to read response from upstream
    proxy_send_timeout    60s;   # time to send request to upstream
    
    # For WebSocket:
    proxy_read_timeout    3600s;
    proxy_send_timeout    3600s;
}
```

**Timeout guidance**:
- `proxy_connect_timeout`: Keep short (3-5s); if upstream cannot accept connection quickly, it is overloaded
- `proxy_read_timeout`: Set based on application response time; API: 30-60s; file upload: 300s+; WebSocket: 3600s+
- `proxy_send_timeout`: Usually matches `proxy_read_timeout`

### Header Forwarding

Always set these headers for backend visibility:
```nginx
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Port  $server_port;
```

### Buffering

```nginx
location / {
    proxy_buffering on;              # buffer upstream responses (default)
    proxy_buffer_size 4k;            # buffer for first part of response (headers)
    proxy_buffers 8 8k;              # number and size of buffers for response body
    proxy_busy_buffers_size 16k;     # max size of busy buffers
}
```

- **Buffering ON** (default): NGINX reads entire response from upstream, then sends to client. Frees upstream connection quickly.
- **Buffering OFF**: NGINX forwards response chunks as received. Use for streaming/real-time responses.
- For large file uploads, increase `client_max_body_size` and `proxy_request_buffering`.

## SSL/TLS Configuration

### Production SSL Configuration

```nginx
server {
    listen 443 ssl http2;
    server_name secure.example.com;
    
    # Certificate and key
    ssl_certificate      /etc/ssl/certs/fullchain.pem;
    ssl_certificate_key  /etc/ssl/private/privkey.pem;
    
    # Protocol configuration
    ssl_protocols        TLSv1.2 TLSv1.3;
    ssl_ciphers          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;    # TLS 1.3 ignores this; let client choose
    
    # Performance
    ssl_session_cache    shared:SSL:10m;
    ssl_session_timeout  1d;
    ssl_session_tickets  off;    # disable for forward secrecy
    
    # OCSP stapling
    ssl_stapling         on;
    ssl_stapling_verify  on;
    ssl_trusted_certificate /etc/ssl/certs/chain.pem;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
}
```

### HTTP to HTTPS Redirect
```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    return 301 https://$host$request_uri;
}
```

### SNI (Multiple Domains)
```nginx
# Each server block handles its own domain with its own certificate
server {
    listen 443 ssl;
    server_name app1.example.com;
    ssl_certificate /etc/ssl/app1.pem;
    ssl_certificate_key /etc/ssl/app1.key;
}

server {
    listen 443 ssl;
    server_name app2.example.com;
    ssl_certificate /etc/ssl/app2.pem;
    ssl_certificate_key /etc/ssl/app2.key;
}
```

## Rate Limiting Patterns

### API Rate Limiting
```nginx
# Zone definition (in http block)
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $http_authorization zone=api_user:10m rate=100r/s;

# Application (in location)
location /api/ {
    limit_req zone=api burst=20 nodelay;
    limit_req zone=api_user burst=50 nodelay;
    limit_req_status 429;
    
    proxy_pass http://api_backend;
}
```

### Login Endpoint Protection
```nginx
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

location /login {
    limit_req zone=login burst=3 nodelay;
    limit_req_status 429;
    proxy_pass http://app_backend;
}
```

### Rate Limiting Best Practices
- Use `$binary_remote_addr` (16 bytes) instead of `$remote_addr` (7-15 bytes variable) for IP-based limiting
- Set `burst` to handle legitimate traffic spikes
- Use `nodelay` for APIs (fail fast); omit for web pages (queue and serve slowly)
- Monitor rate limiting with access log custom format including `$limit_req_status`

## Caching Design

### Proxy Cache Configuration
```nginx
# Cache path definition (in http block)
proxy_cache_path /var/cache/nginx 
    levels=1:2 
    keys_zone=app_cache:10m 
    max_size=1g 
    inactive=60m 
    use_temp_path=off;

# Cache application (in location)
location / {
    proxy_cache app_cache;
    proxy_cache_valid 200 10m;
    proxy_cache_valid 301 302 1h;
    proxy_cache_valid 404 1m;
    proxy_cache_valid any 1m;
    
    proxy_cache_use_stale error timeout updating http_500 http_502 http_503;
    proxy_cache_background_update on;
    proxy_cache_lock on;
    
    add_header X-Cache-Status $upstream_cache_status always;
    
    proxy_pass http://app_backend;
}
```

### Cache Key Design
```nginx
# Default cache key (sufficient for most cases)
proxy_cache_key "$scheme$request_method$host$request_uri";

# Cache key with cookie (for user-specific content)
proxy_cache_key "$scheme$request_method$host$request_uri$cookie_session";

# Cache bypass for authenticated users
proxy_cache_bypass $cookie_session;
proxy_no_cache $cookie_session;
```

### Cache Best Practices
- Use `proxy_cache_use_stale` for resilience (serve stale on backend failure)
- Enable `proxy_cache_lock` to prevent cache stampede (only one request fetches from upstream)
- Use `proxy_cache_background_update` to refresh cache asynchronously
- Set `inactive` timeout to automatically purge unused cache entries
- Monitor `$upstream_cache_status` (HIT/MISS/BYPASS/STALE/UPDATING/REVALIDATED)

## Kubernetes Ingress Patterns

### Canary Deployment
```yaml
apiVersion: k8s.nginx.org/v1
kind: VirtualServer
spec:
  host: app.example.com
  upstreams:
  - name: stable
    service: app-stable
    port: 80
  - name: canary
    service: app-canary
    port: 80
  routes:
  - path: /
    splits:
    - weight: 95
      action:
        pass: stable
    - weight: 5
      action:
        pass: canary
```

### Blue-Green Deployment
```yaml
# Switch between blue and green by updating the service reference
apiVersion: k8s.nginx.org/v1
kind: VirtualServer
spec:
  host: app.example.com
  upstreams:
  - name: active
    service: app-green    # change to app-blue for switch
    port: 80
  routes:
  - path: /
    action:
      pass: active
```

### Multiple Teams (VirtualServerRoute)
```yaml
# Main VirtualServer (platform team)
apiVersion: k8s.nginx.org/v1
kind: VirtualServer
spec:
  host: app.example.com
  routes:
  - path: /api
    route: api-team/api-routes    # delegates to api-team namespace
  - path: /web
    route: web-team/web-routes    # delegates to web-team namespace
```

### Ingress Migration (community to F5 NGINX)

When migrating from retired community ingress-nginx to F5 NGINX Ingress Controller:
1. Install F5 NGINX Ingress Controller alongside existing ingress
2. Create equivalent VirtualServer CRDs for each Ingress resource
3. Update `ingressClassName` from `nginx` to the F5 controller class name
4. Map community annotations to F5 annotations (similar but not identical)
5. Test each service with the new controller
6. Switch DNS/service to point to the new controller
7. Remove old community ingress-nginx deployment

## Performance Tuning

### Worker Configuration
```nginx
worker_processes auto;              # 1 per CPU core
worker_rlimit_nofile 65535;         # max open files per worker
events {
    worker_connections 4096;        # max connections per worker
    multi_accept on;                # accept all pending connections at once
    use epoll;                      # Linux event mechanism
}
```

### Buffer Tuning
```nginx
# For large headers (cookies, auth tokens)
large_client_header_buffers 4 16k;

# For file uploads
client_max_body_size 10m;
client_body_buffer_size 128k;

# For upstream responses
proxy_buffer_size 8k;
proxy_buffers 16 8k;
```

### Logging Optimization
```nginx
# Reduce logging overhead
access_log /var/log/nginx/access.log combined buffer=32k flush=5s;

# Disable access logging for health checks
location /health {
    access_log off;
    return 200 "ok";
}
```

## Monitoring

### stub_status (OSS)
```nginx
server {
    listen 127.0.0.1:8080;
    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}
```

Exposes: Active connections, accepts, handled, requests, reading, writing, waiting.

### NGINX Plus API (Plus)
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

Exposes detailed per-upstream, per-server-zone, per-cache, per-SSL, per-resolver metrics in JSON format.

### Key Metrics to Monitor

| Metric | Source | Alert Threshold |
|---|---|---|
| Active connections | stub_status / API | > 80% of worker_connections * workers |
| Waiting connections | stub_status | High waiting = many idle keepalive |
| 5xx responses | Access log / API | > 1% of total responses |
| Upstream response time | API (Plus) | > application SLA |
| Upstream server health | API (Plus) | Any server down |
| SSL handshake failures | API (Plus) | Any sustained failures |
| Cache hit rate | $upstream_cache_status | < 80% for cacheable content |
