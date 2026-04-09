# MISP Architecture Reference

## Server Architecture

### Components

```
MISP Web Application (PHP / CakePHP)
    ↓
MISP REST API (same PHP application, JSON responses)
    ↓
MySQL / MariaDB Database (persistent storage)
    ↓
Redis (caching, background job queue)
    ↓
Background Workers (CakeResque workers for async jobs)
    ↓
Optional: misp-modules (Python enrichment service)
```

### Process Architecture

**Web/API process:**
- PHP-FPM running the MISP CakePHP application
- Handles all HTTP requests (web UI and API)
- Writes to MySQL, reads from Redis cache

**Background workers:**
- **Default worker**: General tasks (feed fetching, event publishing)
- **Email worker**: Send notifications
- **Scheduler worker**: Cron-style recurring tasks (feed caching, correlation updates)
- **Prio worker**: High-priority tasks (real-time correlation on new attributes)

**Worker monitoring:**
`Administration > Workers` -- Shows which workers are running; restart stuck workers here.

### Database (MySQL/MariaDB)

**Key tables:**

| Table | Content |
|---|---|
| `events` | Event metadata (info, date, distribution, threat_level, analysis) |
| `attributes` | All attributes (type, value, to_ids, event_id, object_id) |
| `tags` | Tag definitions |
| `event_tags` | Mapping of tags to events |
| `attribute_tags` | Mapping of tags to attributes |
| `correlations` | Pre-computed correlation pairs |
| `objects` | MISP objects (containers for attributes) |
| `object_references` | Relationships between objects |
| `feeds` | Feed configurations |
| `sharing_groups` | Sharing group definitions |
| `organisations` | Organization registry |
| `users` | User accounts |
| `servers` | Remote MISP instance connections |

**Database sizing:**
- Small deployment (< 100K events): 10-50 GB
- Medium (100K-1M events): 50-500 GB
- Large (> 1M events): 500+ GB; consider partitioning attribute table by event_id or type

### Performance Tuning

**MySQL tuning for MISP:**
```ini
# /etc/mysql/my.cnf
[mysqld]
innodb_buffer_pool_size = 4G  # 70-80% of available RAM
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 2  # Performance tradeoff: less durable but faster
max_connections = 200
query_cache_size = 128M
```

**Redis tuning:**
```ini
maxmemory 2gb
maxmemory-policy allkeys-lru
```

**PHP-FPM:**
- `pm.max_children = 20` (adjust per available CPU/memory)
- `request_terminate_timeout = 300` (allow long API requests to complete)

---

## Correlation Engine (Internals)

### Correlation Process

When a new attribute is added:
1. PHP adds attribute to `attributes` table
2. Worker picks up `attribute_added` event from Redis queue
3. Worker queries `attributes` table for all attributes with same value AND same type (or types in correlation group)
4. For each match found: Insert row into `correlations` table (event_id_1, attribute_id_1, event_id_2, attribute_id_2, value)
5. Correlation count updated in `events` table

**Correlation groups:** MISP correlates across related types, not just identical types:
- `ip-src` correlates with `ip-dst` (both are IP addresses)
- `md5`, `sha1`, `sha256` correlate within the file hash group
- `domain`, `hostname` correlate together

### Correlation Performance

Correlation is the most expensive operation:
- Adding one attribute: Query against potentially millions of rows in `attributes` table
- High-volume feed ingestion: Can create correlation backlog

**Optimizations:**
1. **Correlation blocklist**: Add common/benign values (8.8.8.8, 1.1.1.1, etc.) to the correlation blocklist so they're never correlated
2. **Disable correlation for specific types**: Types like `text` or `comment` rarely produce useful correlations; disable per-type
3. **Attribute limit per event**: Very large events (10,000+ attributes) slow correlation; split large events
4. **Database index**: Ensure `attributes` table has indexes on `value`, `type`, `event_id`

**Correlation blocklist management:**
`Administration > Correlation Exclusions > Add Exclusion`
- Add Alexa Top 1M, RFC1918 ranges, CDN IPs, public DNS IPs

### Over-Correlation Problem

Over-correlation occurs when a very common value (e.g., a CDN IP shared by thousands of legitimate and malicious sites) correlates everything to everything.

Signs of over-correlation:
- Event showing hundreds of correlated events (suspicious -- too many)
- Performance slowdown on event view (rendering thousands of correlation links)

Solution:
1. Add the problematic value to correlation exclusions
2. For existing correlations: `Tools > Recalculate Correlations` (resource-intensive; run off-hours)

---

## Feed Architecture

### Feed Types and Data Flow

**MISP JSON feed:**
```
Remote URL (HTTPS)
  → Manifest.json (list of event UUIDs + last-modified timestamps)
  → Per-event JSON files (one per event UUID)
  → MISP parses and imports as events or caches for attribute lookup
```

**CSV feed:**
```
Remote URL (HTTPS)
  → Single CSV file (columns: value, type, comment, tags, etc.)
  → MISP creates attributes or caches for lookup
```

**TAXII feed:**
```
TAXII 2.1 server
  → MISP polls /collections/{id}/objects/?added_after={last_poll_time}
  → STIX objects converted to MISP events/attributes
  → Imported or cached
```

### Feed Caching Architecture

Feed caching stores attribute values locally for fast lookup without creating full events.

**Cache storage:** Redis (for fast in-memory lookup)

**Cache structure:**
- Key: `misp:feed:{feed_id}:{attribute_type}:{value_hash}`
- Value: JSON with feed metadata (feed name, feed source, seen count)

**When cache is checked:**
- When a new attribute is added to any event: MISP checks the cache for a hit
- Result: Attribute detail view shows "This value was seen in [feed name]"

**Cache refresh:**
- Manual: `Sync Actions > Feeds > [Feed] > Fetch Now`
- Automated via cron: `exec php /var/www/MISP/app/Console/cake Server cacheFeed all`
- Recommended: Daily cron for all feeds

---

## User and Organization Model

### Roles

| Role | Permissions |
|---|---|
| Admin | Full access to all MISP functions, including admin panel |
| Org Admin | Full access within own organization; manage org users |
| Sync User | Can sync events (used for machine-to-machine sync) |
| Publisher | Can publish events (make them visible to others) |
| User | Standard analyst; can create, edit own events |
| Read Only | Can view events they have access to; cannot create |

**Sync User accounts:** Create a dedicated Sync User account for machine-to-machine API access and server synchronization. Use role-specific API keys; do not use admin credentials for automation.

### Multi-Organization Model

MISP supports multiple organizations on one instance:

**Use case:** An ISAC host running MISP for multiple member organizations
- Each member organization has its own set of users
- Org-level isolation: Events marked "Your Organisation Only" are visible only to that org's users
- Community sharing: Events marked "This Community Only" visible to all orgs on the instance
- Sharing groups: Explicitly name which orgs can see specific events

**Global admin vs. Org admin:**
- Global admin: Can see all events on the instance (regardless of distribution)
- Org admin: Can only see events their org has access to

---

## Synchronization Protocol

### Event UUID Deduplication

Every MISP event has a UUID (RFC 4122). When syncing:
1. Source instance sends event UUIDs and modification timestamps
2. Target instance checks: "Do I have this UUID? Is my copy newer?"
3. If target has older copy (or no copy): Pull the full event
4. If target has same or newer: Skip (no update needed)

This ensures:
- Same event shared by multiple paths (A→B→C and A→C) only creates one copy
- Updates are idempotent; re-syncing doesn't duplicate events

### Push Synchronization

When a publisher triggers "Publish" on an event:
1. MISP background worker picks up the publish task
2. Worker iterates over all configured sync servers
3. For each server: Filter events by server-specific sync rules
4. If event passes filters: POST event to remote server's API
5. Remote server imports event; runs correlation

**Selective push:**
Configure per-server push filters:
`Administration > Servers > [Server] > Edit > Push Rules`
- Only push events tagged with specific tags
- Don't push events below certain threat level

### Pull Synchronization

Manual or scheduled pull:
1. MISP requests manifest from remote server (`GET /events/index.json`)
2. Compare manifest against local index
3. Pull events that are new or updated
4. Import and correlate

**Scheduled pull:**
```bash
# Cron entry for hourly pull from server ID 1
0 * * * * php /var/www/MISP/app/Console/cake Server pull 1
```

---

## STIX Export Pipeline

### Event → STIX 2.1 Conversion

MISP to STIX mapping:

| MISP | STIX 2.1 |
|---|---|
| Event | `report` (containing all objects) + `bundle` |
| Attribute (ip-dst, to_ids=true) | `indicator` (with STIX pattern) |
| Attribute (ip-dst, to_ids=false) | `observed-data` + `network-traffic` SCO |
| Object (file) | `file` observable object |
| Galaxy (Threat Actor) | `threat-actor` |
| Galaxy (ATT&CK technique) | `attack-pattern` |
| Tag (tlp:amber) | `marking-definition` (TLP:AMBER) |
| Attribute association | `relationship` |

**STIX Pattern generation:**
For `to_ids=True` attributes, MISP generates STIX patterns:
- `ip-dst: 198.51.100.42` → `[ipv4-addr:value = '198.51.100.42']`
- `domain: evil.com` → `[domain-name:value = 'evil.com']`
- `sha256: abc123...` → `[file:hashes.SHA-256 = 'abc123...']`
- `url: http://evil.com/path` → `[url:value = 'http://evil.com/path']`

### TAXII Server Setup

MISP can expose a TAXII 2.1 server (requires misp-taxii module):

1. Install misp-taxii: `pip install misp-taxii`
2. Configure in MISP: `Administration > Server Settings > Plugins > Taxii`
3. Define collections (which MISP events/attributes to expose)
4. Authenticate consumers via API key

---

## Performance and Scaling

### Horizontal Scaling

MISP does not natively support horizontal scaling (no built-in clustering). Options:

**For high availability:**
- Primary/replica MySQL setup (MISP writes to primary, can read from replica for some queries)
- Load balancer with session persistence (all requests from one user go to same PHP-FPM server)
- Redis Sentinel for Redis HA

**For high ingestion throughput:**
- Increase background worker count
- Separate worker instances (dedicated VM for workers vs. web)
- Adjust Redis max memory and worker concurrency

### Feed Import Performance

Large feed imports (1M+ attributes) can saturate workers.

**Optimization strategy:**
1. Schedule large feed imports during off-hours
2. Use feed caching mode (cache-only, don't create events) for high-volume OSINT feeds
3. Increase worker concurrency for feed processing: `Administration > Workers > Add Worker`

### Database Partitioning (Large Deployments)

For > 100M attributes (enterprise-scale):
- Partition `attributes` table by `event_id` range or by `type`
- MySQL partitioning: `ALTER TABLE attributes PARTITION BY RANGE (event_id) (...)` 
- Requires planned partitioning strategy before data growth becomes an issue
- Consider: Moving to PostgreSQL (experimental MISP support) for better partition handling

---

## Security Hardening

### API Key Management

- API keys are stored hashed in the database
- Rotate API keys regularly: `My Profile > Auth Key > Add Authentication Key`
- Create separate API keys per integration (not one shared key for all tools)
- Set key expiry dates for integration keys

### Network Hardening

MISP web interface should NOT be publicly accessible:
- Place behind VPN or IP allowlist
- TLS with valid certificate (Let's Encrypt acceptable)
- Reverse proxy (nginx recommended) in front of PHP-FPM
- Rate limiting on API endpoints (nginx rate limiting)

### Instance Hardening

```bash
# Disable unused features in MISP config
# /var/www/MISP/app/Config/config.php
'MISP' => [
    'disable_emailing' => false,  # Enable for production
    'block_event_alert' => false,
    'block_old_event_alert' => false,
]
```

Key settings to review:
- `allow_complex_filters`: If not needed, disable to reduce DoS attack surface
- `disable_emailing`: Keep enabled for alert notifications
- `disable_auto_logout`: Set to false (auto logout after inactivity)
- `session_timeout`: Set to reasonable value (1800 = 30 minutes)
