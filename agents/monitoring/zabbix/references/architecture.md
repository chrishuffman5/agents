# Zabbix Architecture Reference

> Server, proxy, agents, frontend, database backends, monitoring methods, HA, and security.

---

## Core Components

### Zabbix Server

Central process performing active polling and passive receiving. Responsible for trigger evaluation, alert generation, and storing data to the database. Runs as `zabbix_server` daemon configured via `/etc/zabbix/zabbix_server.conf`. Key process types: pollers, trappers, discoverers, escalators, timers, housekeepers. Default listen port: 10051.

### Zabbix Proxy

Optional intermediary collecting data on behalf of the server. Reduces load and enables distributed monitoring across network segments, DMZs, and remote locations. Buffers data locally and forwards to server.

**Two modes:**
- **Active proxy:** Initiates connection to server, fetches configuration, pushes data. Preferred for firewalled environments.
- **Passive proxy:** Server connects to proxy to retrieve data.

Proxies maintain local SQLite, MySQL, or PostgreSQL database for buffering. Tunable sync intervals: `ConfigFrequency`, `DataSenderFrequency`.

**Proxy groups (Zabbix 7.0+):** Multiple proxies in a group share load and provide failover. Hosts assigned to a proxy group are distributed across available proxies. If a proxy fails, hosts redistributed automatically.

### Zabbix Agent (C-based)

Lightweight daemon on monitored hosts. Supports active and passive checks. Default port: 10050.

Key config directives: `Server`, `ServerActive`, `Hostname`, `RefreshActiveChecks`.

Custom metrics via `UserParameter`:
```
UserParameter=app.connections,netstat -an | grep ESTABLISHED | wc -l
```

### Zabbix Agent2 (Go-based)

Modern replacement (introduced in Zabbix 5.0). Advantages:
- Plugin architecture with native plugins for MySQL, PostgreSQL, Redis, MongoDB, Docker, Kubernetes
- Fewer TCP connections via multiplexing
- Scheduled checks with cron-like syntax
- Active-only model with persistent connections
- Loadable plugins extend functionality without recompilation

Plugin configuration via `Plugins.*` directives in agent config.

### Zabbix Frontend

PHP-based web interface served via Apache or Nginx with PHP-FPM. Requires PHP 8.0+ in Zabbix 7.x. Supports RBAC, audit logging, 2FA (TOTP). Full JSON-RPC 2.0 API at `/api_jsonrpc.php`.

### Database Backend

| Backend | Notes |
|---------|-------|
| PostgreSQL (recommended) | Best performance for large deployments |
| PostgreSQL + TimescaleDB | Hypertables with auto-partitioning, 5-10x compression |
| MySQL / MariaDB | Widely used, InnoDB engine required |
| Oracle / DB2 | Supported in enterprise contexts (less common) |

Key tables: `hosts`, `items`, `triggers`, `history`, `history_uint`, `history_str`, `history_log`, `trends`, `trends_uint`, `events`, `alerts`.

---

## Monitoring Methods

### Agent-Based

Native agents provide richest metrics with minimal overhead. Both active and passive check modes.

### Agentless

| Method | Use Case |
|--------|----------|
| SNMP (v1/v2c/v3) | Network devices, UPS, servers via MIB OIDs |
| IPMI | Server hardware (temperature, fan speed, power) |
| SSH | Remote command execution, key-based or password auth |
| HTTP Agent | HTTP/HTTPS requests, response body, status codes, timing |
| JMX | Java applications via JMX gateway (`zabbix_java_gateway`) |
| Telnet | Legacy command execution |

### Trapper (Push Monitoring)

Hosts push data to Zabbix using `zabbix_sender` CLI. Item type "Zabbix trapper" receives values. Useful for batch jobs and application instrumentation.

```bash
zabbix_sender -z zabbix-server -s "webhost01" -k app.users.active -o 142
```

### Prometheus Integration

Zabbix 7.x supports native Prometheus endpoint scraping via HTTP Agent items combined with Prometheus preprocessing. Items scrape `/metrics` endpoints and extract metrics using Prometheus pattern syntax. Enables monitoring any Prometheus-compatible exporter without a separate Prometheus server.

### Internal Monitoring

Built-in `zabbix[*]` item keys expose internal metrics: queue depths, process busy %, data gathering rates, cache hit ratios. Essential for monitoring the monitoring system itself.

---

## High Availability

Zabbix 6.0+ provides native active-passive HA for the server. Multiple nodes share a database; only the active node processes data. On failure, standby promotes automatically within seconds.

Configure via `HANodeName` in `zabbix_server.conf`. Frontend detects active node via database. Requires shared PostgreSQL or MySQL (not SQLite).

---

## Security Hardening

### Encryption

TLS between all components. Agent-to-server and proxy-to-server support PSK or certificate-based TLS.

```ini
TLSConnect=cert
TLSAccept=cert
TLSCAFile=/etc/zabbix/ca.crt
TLSCertFile=/etc/zabbix/agent.crt
TLSKeyFile=/etc/zabbix/agent.key
```

### API Security

Restrict API access to trusted networks. Use RBAC for per-host-group permissions. Audit log tracks all configuration changes.

### Agent Security

- `AllowRoot=0` (run as unprivileged user)
- Restrict `Server` and `ServerActive` to specific IPs
- Use `HostMetadata` for auto-registration with group assignment

### Frontend Hardening

Run behind reverse proxy (Nginx) with HTTPS only. Set `X_FRAME_OPTIONS`, `Content-Security-Policy`, `Strict-Transport-Security` headers.
