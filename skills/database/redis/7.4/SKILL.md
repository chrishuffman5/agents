---
name: database-redis-7.4
description: "Redis 7.4 version-specific expert. Deep knowledge of hash field expiration (per-field TTL), new cluster commands, performance improvements, and enhanced ACL capabilities. WHEN: \"Redis 7.4\", \"hash field expiration\", \"hash field TTL\", \"HEXPIRE\", \"HPEXPIRE\", \"HTTL\", \"HPTTL\", \"HPERSIST\", \"HEXPIREAT\", \"HEXPIRETIME\", \"Redis 7.4 features\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Redis 7.4 Expert

You are a specialist in Redis 7.4, released January 2024. You have deep knowledge of the features introduced in this version, particularly hash field expiration (per-field TTL), new cluster management commands, and performance improvements.

**Support status:** Supported. EOL November 2026.

## Key Features Introduced in Redis 7.4

### Hash Field Expiration (Per-Field TTL)

The headline feature of Redis 7.4. Previously, TTL could only be set on entire keys. Now individual hash fields can have independent expiration:

```bash
# Set expiration on hash fields (seconds)
HEXPIRE myhash 3600 FIELDS 2 field1 field2
# Returns array: 1=set, 0=field doesn't exist, -2=key doesn't exist

# Set expiration with milliseconds precision
HPEXPIRE myhash 60000 FIELDS 1 temp_field

# Set expiration at specific Unix timestamp
HEXPIREAT myhash 1735689600 FIELDS 3 session token refresh_token

# Set expiration at specific Unix timestamp (milliseconds)
HPEXPIREAT myhash 1735689600000 FIELDS 1 field1

# Get remaining TTL for hash fields (seconds)
HTTL myhash FIELDS 2 field1 field2
# Returns array: TTL per field, -1=no expiry, -2=field doesn't exist

# Get remaining TTL (milliseconds)
HPTTL myhash FIELDS 2 field1 field2

# Get absolute expiration timestamp (Unix seconds)
HEXPIRETIME myhash FIELDS 1 field1

# Get absolute expiration timestamp (Unix milliseconds)
HPEXPIRETIME myhash FIELDS 1 field1

# Remove expiration from hash fields (make persistent)
HPERSIST myhash FIELDS 2 field1 field2
# Returns array: 1=removed, -1=no expiry existed, -2=field doesn't exist
```

**Conditional expiration flags:**
```bash
# NX: set expiration only if field has no expiration
HEXPIRE myhash 3600 NX FIELDS 1 field1

# XX: set expiration only if field already has an expiration
HEXPIRE myhash 7200 XX FIELDS 1 field1

# GT: set expiration only if new expiry > current expiry
HEXPIRE myhash 7200 GT FIELDS 1 field1

# LT: set expiration only if new expiry < current expiry
HEXPIRE myhash 1800 LT FIELDS 1 field1
```

**Use cases for hash field expiration:**

**Session management with selective field expiry:**
```bash
# User session with different field lifetimes
HSET session:user:1000 user_id 1000 username "john" email "john@example.com"
HSET session:user:1000 auth_token "abc123" csrf_token "xyz789" temp_otp "445566"

# Auth token expires in 24 hours
HEXPIRE session:user:1000 86400 FIELDS 1 auth_token

# CSRF token expires in 1 hour
HEXPIRE session:user:1000 3600 FIELDS 1 csrf_token

# OTP expires in 5 minutes
HEXPIRE session:user:1000 300 FIELDS 1 temp_otp

# User profile fields never expire (no HEXPIRE called)
```

**Feature flags with automatic rollback:**
```bash
HSET features:app new_ui "enabled" beta_search "enabled" experiment_x "enabled"

# New UI: permanent
# Beta search: expire in 30 days
HEXPIRE features:app 2592000 FIELDS 1 beta_search

# Experiment X: expire in 7 days
HEXPIRE features:app 604800 FIELDS 1 experiment_x
# After expiry, HGET returns nil -- feature automatically disabled
```

**Cache with per-field freshness:**
```bash
HSET product:5000 name "Widget" price "29.99" inventory "150" reviews_summary "4.5 stars"

# Price and inventory update frequently; short TTL
HEXPIRE product:5000 300 FIELDS 2 price inventory

# Reviews summary cached longer
HEXPIRE product:5000 3600 FIELDS 1 reviews_summary

# Product name rarely changes; no expiry
```

**Internal implementation:**
- Expired fields are removed lazily (on access) and actively (periodic sampling)
- Same hybrid expiry mechanism as key-level TTL but at the field level
- Memory overhead: additional metadata per field with TTL (~16 bytes per expiring field)
- Encoding impact: hashes with field-level TTLs cannot use listpack encoding; they convert to hashtable

**Important limitations:**
- Fields with TTL consume more memory (hashtable encoding forced)
- Not all hash commands report expired fields -- HGETALL, HKEYS, HVALS skip expired fields
- HSCAN may or may not include expired-but-not-yet-cleaned fields
- Replication: field expiration is replicated as explicit HDEL commands

### Cluster Improvements

**CLUSTER LINKS command:**
```bash
redis-cli -c CLUSTER LINKS
# Returns details about all cluster bus connections:
# - Direction (to/from)
# - Node ID
# - Create time
# - Events (readable/writable)
# - Send/recv buffer sizes
# Useful for diagnosing cluster communication issues
```

**CLUSTER SLOT-STATS (experimental):**
```bash
redis-cli -c CLUSTER SLOT-STATS SLOTSRANGE 0 100
# Returns per-slot statistics: key count, average TTL
# Useful for understanding slot-level data distribution
```

**Improved slot migration:**
- Faster MIGRATE command for large keys
- Better handling of blocked clients during slot migration
- Improved error messages for cross-slot operations

### Performance Improvements

**Optimized encoding conversions:**
- Faster listpack-to-hashtable conversion when thresholds are exceeded
- Reduced memory allocation overhead during encoding upgrades
- Better memory efficiency for hashes near the listpack/hashtable boundary

**Improved active expiry:**
- More efficient sampling for hash field expiration
- Reduced CPU overhead for databases with many expiring fields
- Better distribution of expiry processing across event loop cycles

**I/O threading improvements:**
- Reduced contention between I/O threads and main thread
- Better throughput for write-heavy workloads with io-threads enabled
- Improved socket read buffering

### Enhanced ACL Capabilities

```bash
# Selector-based ACL rules (refined in 7.4)
ACL SETUSER analytics on >pass ~analytics:* +@read +info resetkeys

# More granular command permissions
ACL SETUSER writer on >pass ~data:* +set +get +del +hset +hget +hexpire +httl
# Note: HEXPIRE and HTTL are new commands that need explicit ACL grants
```

### New INFO Sections

```bash
# New fields in INFO persistence
redis-cli INFO persistence
# hash_field_expiry_hit:  hash field expired on access (lazy)
# hash_field_expiry_miss: hash field checked but not expired

# New fields in INFO stats
redis-cli INFO stats
# expired_hash_fields: total hash fields expired (active + lazy)
```

## Configuration Changes

**New configuration parameters:**
```
# Hash field expiration active expiry effort (0-100, like key expiry)
hash-field-expiry-active-percent 50

# Default listpack thresholds still apply but:
# Hashes with ANY field-level TTL automatically use hashtable encoding
```

**Modified defaults:**
```
# No default changes from 7.2; all new features are opt-in
```

## Version Boundaries

**This version introduced:**
- HEXPIRE, HPEXPIRE, HEXPIREAT, HPEXPIREAT commands
- HTTL, HPTTL, HEXPIRETIME, HPEXPIRETIME commands
- HPERSIST command
- NX/XX/GT/LT flags for hash field expiration
- CLUSTER LINKS command
- Experimental CLUSTER SLOT-STATS
- Performance improvements for I/O threading and encoding conversions

**Not available in this version (added later):**
- Features introduced in 7.8+
- Features introduced in 8.0+

**Available from previous versions:**
- WAITAOF (7.2)
- CLIENT NO-TOUCH (7.2)
- Sharded pub/sub (7.0)
- Functions API (7.0)
- Multi-part AOF (7.0)

## Migration Guidance

### Migrating from 7.2 to 7.4

**Backward compatible:** No breaking changes. All 7.2 commands and configurations continue to work.

**Recommended steps:**
1. Upgrade replicas first, then failover and upgrade masters
2. For cluster: rolling upgrade node by node
3. After upgrade: no immediate action required
4. Gradually adopt hash field expiration where beneficial

**Testing hash field expiration:**
```bash
# Test on staging first
HSET test:hash field1 "value1" field2 "value2" field3 "value3"
HEXPIRE test:hash 10 FIELDS 1 field1
# Wait 10 seconds
HGETALL test:hash
# field1 should be gone
```

### Migrating from 7.4 to 7.8

- Review 7.8 SKILL.md for new features
- Test cluster improvements
- No breaking changes expected

### Impact on Memory

**Hash field expiration memory impact:**
- Hashes using field TTL are forced to hashtable encoding (no listpack)
- For small hashes (<128 fields): this increases memory by 2-5x per hash
- For large hashes (>128 fields): minimal impact (already using hashtable)
- Additional ~16 bytes per field with TTL for expiration metadata
- Trade-off: use only when per-field expiry provides significant application benefit

**Recommendation:** Do not add field-level TTL to all hashes by default. Use selectively where the application logic requires independent field lifetimes.

### Client Library Compatibility

- **redis-py** >= 5.0.3: full 7.4 support including HEXPIRE/HTTL
- **Jedis** >= 5.1: full 7.4 support
- **go-redis** >= 9.4: full 7.4 support
- **node-redis** >= 4.6.12: full 7.4 support
- **Lettuce** >= 6.3.1: full 7.4 support
- **StackExchange.Redis** >= 2.7: full 7.4 support
