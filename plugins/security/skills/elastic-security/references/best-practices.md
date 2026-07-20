# Elastic Security Best Practices Reference

## Detection Engineering

### Rule Enablement Strategy

Don't enable all 1,300+ prebuilt rules at once. Phase approach:

**Phase 1 -- Foundation (Week 1-2):**
- Enable high-confidence, low-false-positive rules
- Focus on: credential access, execution, persistence
- Target: 50-100 rules with known-good ECS data

**Phase 2 -- Expansion (Week 3-4):**
- Enable medium-confidence rules
- Add: lateral movement, defense evasion, discovery
- Tune Phase 1 rules based on alert volume

**Phase 3 -- Custom (Ongoing):**
- Write custom EQL/ES|QL rules for environment-specific threats
- Build indicator match rules with threat intelligence
- Add ML anomaly detection jobs

### EQL Optimization

**Keep sequences narrow:**
```eql
// Bad: wide span, no partition, scans everything
sequence with maxspan=24h
  [process where event.type == "start"]
  [network where event.type == "start"]

// Good: narrow span, partitioned by host, specific conditions
sequence by host.name with maxspan=5m
  [process where event.type == "start" and process.name == "certutil.exe"]
  [network where event.type == "start" and destination.port == 443]
```

**Use `until` to bound sequences:**
```eql
// End the sequence if the user logs out (prevents unbounded tracking)
sequence by user.name with maxspan=30m
  [authentication where event.outcome == "failure"] with runs=5
  [authentication where event.outcome == "success"]
until [authentication where event.action == "logged-out"]
```

**EQL pipe operations:**
```eql
// Filter sequence results
sequence by host.name with maxspan=10m
  [process where event.type == "start" and process.name == "cmd.exe"]
  [file where event.type == "creation" and file.extension == "exe"]
| filter process.parent.name != "explorer.exe"
| head 100
```

### ES|QL Detection Patterns

**Brute force detection:**
```esql
FROM logs-*
| WHERE event.category == "authentication" AND event.outcome == "failure"
| WHERE @timestamp > NOW() - 1 HOUR
| STATS failure_count = COUNT(*), target_users = COUNT_DISTINCT(user.name)
    BY source.ip
| WHERE failure_count > 50 OR target_users > 10
| SORT failure_count DESC
```

**Rare process detection:**
```esql
FROM logs-endpoint.events.process-*
| WHERE event.type == "start"
| WHERE @timestamp > NOW() - 24 HOURS
| STATS host_count = COUNT_DISTINCT(host.name), exec_count = COUNT(*)
    BY process.name
| WHERE host_count == 1 AND exec_count < 3
| SORT exec_count ASC
```

**Data exfiltration detection:**
```esql
FROM logs-*
| WHERE event.category == "network"
| WHERE @timestamp > NOW() - 1 HOUR
| STATS total_bytes = SUM(destination.bytes)
    BY source.ip, destination.ip
| WHERE total_bytes > 1000000000  // > 1 GB
| SORT total_bytes DESC
```

### Custom Rule Development Workflow

1. **Hypothesis** -- What threat behavior are we detecting?
2. **Data validation** -- Verify ECS fields exist in the target data stream
3. **Query development** -- Write and test in Kibana Discover or Timeline
4. **Rule creation** -- Security > Rules > Create new rule
5. **Severity and risk** -- Assign based on ATT&CK technique and confidence
6. **Entity mapping** -- Map host.name, user.name, source.ip to alert entities
7. **Investigation guide** -- Write triage steps in the rule's investigation guide
8. **Testing** -- Use Elastic's rule testing framework or manual simulation
9. **Monitoring** -- Track false-positive rate and tune

### Detection Rule Testing

```json
// Rule unit test (JSON-based)
{
  "rule_id": "custom-powershell-encoded",
  "test_data": [
    {
      "@timestamp": "2026-04-08T12:00:00Z",
      "event.type": "start",
      "process.name": "powershell.exe",
      "process.args": ["-EncodedCommand", "SQBFAFgA"],
      "host.name": "WORKSTATION-01",
      "user.name": "jsmith"
    }
  ],
  "expected_result": "alert"
}
```

## ML Anomaly Detection

### Job Configuration Best Practices

1. **Bucket span** -- 15m for real-time detection, 1h for daily behavioral analysis
2. **Influencers** -- Add fields that help explain anomalies (user.name, host.name, source.ip)
3. **Model memory limit** -- Start at 256 MB, increase for high-cardinality fields
4. **Dedicated ML nodes** -- Run ML jobs on dedicated nodes to avoid impacting search performance

### Prebuilt Security ML Jobs

| Job | Detects | Data Required |
|---|---|---|
| `auth_high_count_logon_fails` | Brute force | Authentication logs (ECS) |
| `auth_rare_source_ip_for_a_user` | Impossible travel | Authentication logs with GeoIP |
| `suspicious_login_activity` | Anomalous login patterns | Authentication logs |
| `rare_process_by_host` | Unusual process execution | Process events (Elastic Defend) |
| `v3_dns_tunneling` | DNS exfiltration | DNS logs (ECS) |
| `high_count_network_events` | Port scanning | Network events |
| `high_sent_bytes_destination_ip` | Data exfiltration | Network flow data |

### Anomaly Score Interpretation

| Score Range | Meaning | Action |
|---|---|---|
| 0-25 | Minor anomaly | Usually benign; review if repeated |
| 25-50 | Moderate anomaly | Worth investigating if correlated with other signals |
| 50-75 | Significant anomaly | Investigate promptly |
| 75-100 | Critical anomaly | Investigate immediately; likely true threat or major change |

## Response Action Workflows

### Host Isolation Playbook

```
1. Alert triggers (e.g., malware detected on host)
    |
2. Analyst reviews alert in Security app
    |
3. Analyst clicks "Isolate host" from alert or host detail page
    |
4. Elastic Defend agent isolates host (blocks all network except Fleet Server)
    |
5. Analyst uses Osquery to investigate isolated host:
   - SELECT * FROM processes WHERE name LIKE '%malware%';
   - SELECT * FROM file WHERE path LIKE '/tmp/%';
   - SELECT * FROM network_interfaces;
    |
6. Analyst retrieves suspicious files using "Get file" action
    |
7. After investigation:
   - If compromised: reimage and release
   - If false positive: release isolation, tune detection
```

### Case Management

```
Alert --> Triage --> Case (if true positive)
                       |
                       ├── Add related alerts
                       ├── Add investigation notes
                       ├── Track response actions taken
                       ├── Attach IOCs and evidence
                       └── Close with resolution
```

## Operational Best Practices

### Monitoring Cluster Health

```json
// Key APIs to monitor
GET _cluster/health
GET _cluster/stats
GET _nodes/stats
GET _cat/shards?v&h=index,shard,prirep,state,docs,store,node&s=store:desc
GET _cat/thread_pool?v&h=node_name,name,active,rejected,completed
```

**Critical metrics:**
- Cluster status: green (all shards allocated), yellow (replicas missing), red (primary shards missing)
- Heap usage: alert above 75%, investigate above 85%
- Search latency: p99 should be < 1s for security searches
- Indexing rate: monitor for unexpected drops (data source outage)
- Thread pool rejections: search, write, or bulk rejections indicate capacity issues

### Index Template Management

```json
{
  "index_patterns": ["logs-custom-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 1,
      "index.lifecycle.name": "security-default-policy",
      "index.lifecycle.rollover_alias": "logs-custom"
    },
    "mappings": {
      "properties": {
        "@timestamp": {"type": "date"},
        "event.category": {"type": "keyword"},
        "source.ip": {"type": "ip"},
        "destination.ip": {"type": "ip"},
        "user.name": {"type": "keyword"}
      }
    }
  },
  "composed_of": ["ecs-mappings", "logs-settings"],
  "priority": 200
}
```

### Snapshot and Restore

```json
// Register snapshot repository (S3)
PUT _snapshot/security-backups
{
  "type": "s3",
  "settings": {
    "bucket": "elastic-snapshots",
    "region": "us-east-1",
    "base_path": "security"
  }
}

// Create SLM policy
PUT _slm/policy/nightly-security
{
  "schedule": "0 0 1 * * ?",
  "name": "<security-snap-{now/d}>",
  "repository": "security-backups",
  "config": {
    "indices": ["logs-*", ".alerts-*", ".cases-*"],
    "include_global_state": false
  },
  "retention": {
    "expire_after": "90d",
    "min_count": 7,
    "max_count": 90
  }
}
```

### Security Hardening

- **Enable TLS** -- Encrypt all inter-node and client-node communications
- **RBAC** -- Use Elastic Security's built-in roles (superuser, kibana_admin, security_analyst)
- **API keys** -- Use API keys instead of basic auth for integrations
- **Audit logging** -- Enable `xpack.security.audit.enabled: true`
- **Minimal privileges** -- Fleet agents should use dedicated service accounts, not superuser
- **Network isolation** -- Elasticsearch cluster should not be exposed to the internet; use Kibana as the gateway
