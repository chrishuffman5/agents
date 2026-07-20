# CoreDNS Architecture Reference

## Plugin Chain Architecture

```
                    Corefile
                       │
              ┌────────┴────────┐
              │  Server Block   │
              │  .:53 { ... }   │
              └────────┬────────┘
                       │
    ┌──────────────────┼──────────────────┐
    │                  │                  │
┌───┴───┐        ┌────┴────┐       ┌─────┴─────┐
│errors │───────►│kubernetes│──────►│  forward  │
└───────┘        └─────────┘       └───────────┘
                       │
                  ┌────┴────┐
                  │  cache  │
                  └─────────┘
```

### Plugin Execution Model

- Plugins are compiled into the CoreDNS binary at build time
- Plugin execution order is defined by `plugin.cfg` at compile time, NOT by Corefile order
- Corefile determines which plugins are loaded for each server block
- Each query traverses the plugin chain; plugins either handle the query or pass to next
- A plugin calls `plugin.NextOrFailure()` to pass the query downstream

### Server Blocks

Each server block binds to an address:port and zone:
```
# Zone-specific block
cluster.local:53 {
    kubernetes cluster.local
}

# Catch-all block
.:53 {
    forward . 8.8.8.8
}
```

Zone matching: longest suffix match wins. `cluster.local:53` handles `foo.cluster.local` before `.:53`.

### Plugin.cfg (Compile-Time Order)

Default plugin order (abridged):
```
metadata
cancel
tls
reload
nsid
bufsize
root
bind
debug
trace
ready
health
pprof
prometheus
errors
log
dnstap
local
dns64
acl
any
chaos
loadbalance
cache
rewrite
dnssec
autopath
template
transfer
hosts
route53
clouddns
k8s_external
kubernetes
file
auto
secondary
etcd
loop
forward
grpc
```

Plugins earlier in the list execute first. This order is fixed at compile time.

## Kubernetes DNS Specification

### Service Resolution

**ClusterIP Service:**
```
my-service.my-namespace.svc.cluster.local → ClusterIP (A record)
```

**Headless Service (clusterIP: None):**
```
my-headless.my-namespace.svc.cluster.local → Pod IP 1, Pod IP 2, ... (multiple A records)
```

**ExternalName Service:**
```
my-external.my-namespace.svc.cluster.local → external.example.com (CNAME)
```

### Pod Resolution

```
10-244-1-5.my-namespace.pod.cluster.local → 10.244.1.5 (A record)
```

Pod IP dashes replace dots. Available when `pods insecure` or `pods verified` is set.

### SRV Records

For services with named ports:
```
_http._tcp.my-service.my-namespace.svc.cluster.local → SRV records
```

SRV response includes port number and target hostname for each endpoint.

### Search Domains

Kubernetes configures pod DNS with search domains:
```
search my-namespace.svc.cluster.local svc.cluster.local cluster.local
```

This allows short names: `my-service` resolves via search domain expansion.

### ndots Problem

Default ndots=5 in Kubernetes. Queries with fewer than 5 dots try all search domains before external lookup. For external DNS queries (e.g., `api.example.com` has 2 dots), this generates 4 failed queries before the real one.

Mitigation options:
- Set `dnsConfig.options.ndots: 1` on pods that primarily query external DNS
- Use FQDN with trailing dot: `api.example.com.` (bypasses search domains)
- Deploy NodeLocal DNSCache to handle the extra queries efficiently

## NodeLocal DNSCache

### Architecture

```
┌──────────────┐     ┌──────────────────────┐
│     Pod      │────►│ NodeLocal DNSCache    │
│ (resolv.conf │     │ (DaemonSet per node)  │
│  169.254.20. │     │ IP: 169.254.20.10    │
│  10)         │     │                      │
└──────────────┘     │  ┌────────────┐      │
                     │  │ Local Cache│      │
                     │  └─────┬──────┘      │
                     │        │ miss        │
                     │  ┌─────┴──────┐      │
                     │  │ Forward to │      │
                     │  │ kube-dns   │      │
                     │  │ ClusterIP  │      │
                     │  └────────────┘      │
                     └──────────────────────┘
```

### Why NodeLocal DNSCache

In standard Kubernetes DNS:
1. Pod sends DNS query to kube-dns ClusterIP
2. kube-proxy iptables DNAT rewrites destination to CoreDNS pod IP
3. Conntrack table tracks the NAT mapping
4. Response follows reverse path

**Problems at scale:**
- Conntrack table exhaustion: each DNS query consumes a conntrack entry
- UDP conntrack race conditions: simultaneous queries to same ClusterIP cause drops
- Cross-node latency: DNS pod may be on a different node

**NodeLocal DNSCache fixes:**
- Local cache on every node eliminates cross-node queries for cached entries
- TCP to upstream eliminates UDP conntrack issues
- No iptables DNAT for cached queries
- Measured improvement: 5-10x reduction in p99 DNS latency

### Configuration

NodeLocal DNSCache Corefile:
```
cluster.local:53 {
    errors
    cache {
        success 9984 30
        denial 9984 5
    }
    reload
    loop
    bind 169.254.20.10
    forward . __PILLAR__CLUSTER__DNS__ {
        force_tcp
    }
    prometheus :9253
    health 169.254.20.10:8080
}

in-addr.arpa:53 {
    errors
    cache 30
    reload
    loop
    bind 169.254.20.10
    forward . __PILLAR__CLUSTER__DNS__ {
        force_tcp
    }
    prometheus :9253
}

.:53 {
    errors
    cache 30
    reload
    loop
    bind 169.254.20.10
    forward . __PILLAR__UPSTREAM__SERVERS__
    prometheus :9253
}
```

`__PILLAR__CLUSTER__DNS__` is replaced with actual kube-dns ClusterIP during deployment.

## Corefile Patterns

### Conditional Forwarding for Hybrid DNS

```
# Kubernetes services
cluster.local:53 {
    kubernetes cluster.local
    cache 30
}

# Corporate DNS (Active Directory)
corp.contoso.com:53 {
    forward . 10.0.0.53 10.0.0.54
    cache 60
}

# AWS VPC DNS
aws.internal:53 {
    forward . 10.0.0.2
    cache 30
}

# Everything else
.:53 {
    forward . 8.8.8.8 1.1.1.1 {
        max_concurrent 1000
    }
    cache 30
    loop
    loadbalance
}
```

### Query Logging for Debugging

```
.:53 {
    log
    errors
    kubernetes cluster.local
    forward . 8.8.8.8
    cache 30
}
```

Warning: `log` plugin generates one log line per query. Disable after debugging to avoid log volume issues.

### Rewrite for Migration

```
.:53 {
    rewrite name suffix .old-cluster.local .cluster.local answer auto
    kubernetes cluster.local
    forward . 8.8.8.8
    cache 30
}
```

### Custom Hosts

```
.:53 {
    hosts {
        10.0.0.1 gateway.local
        10.0.0.10 db.local
        fallthrough
    }
    forward . 8.8.8.8
    cache 30
}
```

## Metrics and Monitoring

### Prometheus Plugin

Default endpoint: `:9153/metrics`

Key metrics:
| Metric | Description |
|---|---|
| `coredns_dns_requests_total` | Total queries by server, zone, type |
| `coredns_dns_responses_total` | Total responses by rcode |
| `coredns_dns_request_duration_seconds` | Query latency histogram |
| `coredns_cache_hits_total` | Cache hits |
| `coredns_cache_misses_total` | Cache misses |
| `coredns_cache_size` | Current cache size |
| `coredns_forward_requests_total` | Forwarded queries |
| `coredns_forward_responses_total` | Forwarded responses |
| `coredns_kubernetes_dns_programming_duration` | Time for DNS programming after API change |

### Health and Readiness

- Health: `:8080/health` -- returns 200 when CoreDNS is running
- Ready: `:8181/ready` -- returns 200 when all plugins report ready
- Kubernetes probes:
  ```yaml
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
  readinessProbe:
    httpGet:
      path: /ready
      port: 8181
  ```

## Custom Plugin Development

### Interface

```go
type Handler interface {
    ServeDNS(context.Context, dns.ResponseWriter, *dns.Msg) (int, error)
    Name() string
}
```

### Registration

```go
func init() {
    plugin.Register("myplugin", setup)
}

func setup(c *caddy.Controller) error {
    // Parse Corefile configuration
    // Return plugin handler
}
```

### Build System

1. Clone CoreDNS repository
2. Add plugin to `plugin.cfg` in desired order position
3. `go generate` to update imports
4. `go build` to compile custom CoreDNS binary
5. Distribute as custom container image for Kubernetes deployment
