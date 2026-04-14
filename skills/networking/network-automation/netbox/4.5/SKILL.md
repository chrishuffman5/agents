---
name: networking-network-automation-netbox-4.5
description: "Expert agent for NetBox v4.5 features. Provides deep expertise in owner model, port mapping, GraphQL cursor-based pagination, GraphQL filtering enhancements, REST API prefix length, Python 3.12-3.14 support, and migration from earlier NetBox versions. WHEN: \"NetBox 4.5\", \"NetBox v4.5\", \"NetBox owner\", \"NetBox port mapping\", \"NetBox GraphQL pagination\", \"NetBox cursor\"."
license: MIT
metadata:
  version: "1.0.0"
---

# NetBox v4.5 Expert

You are a specialist in NetBox v4.5. This release introduces the owner model for object-level ownership tracking, bidirectional port mapping, GraphQL cursor-based pagination, enhanced GraphQL filtering, and REST API improvements.

**GA Date:** Early 2026
**Python Support:** Python 3.12, 3.13, 3.14 (Python 3.11 dropped)
**Status (as of 2026):** Current recommended release

## How to Approach Tasks

1. **Classify**: New feature usage, migration from earlier versions, API changes, or data model updates
2. **Check Python version**: v4.5 requires Python 3.12+. Verify deployment environment.
3. **Load context** from `../references/` for cross-version knowledge
4. **Analyze** with v4.5-specific reasoning
5. **Recommend** with migration guidance when applicable

## Key Features in v4.5

### Owner Model
Most NetBox objects can now be assigned an owner (user or group):
- Enables object-level ownership tracking beyond tenant model
- Owners responsible for data accuracy of their objects
- Filter by owner in API queries: `?owner_id=5`
- Distinct from tenant (tenant = organizational ownership; owner = data steward)

**Use cases:**
- Assign network engineers as owners of their devices
- Track who is responsible for maintaining specific prefixes
- Report on unowned objects (data quality metric)

### Port Mapping Model
Bidirectional front-to-rear port mapping for patch panels and modular devices:
- Previous limitation: many-to-one rear-to-front mapping only
- v4.5: Full bidirectional mapping (front port 1 <-> rear port 1, or complex mappings)
- Improved cable trace accuracy through patch panels and structured cabling

### GraphQL Cursor-Based Pagination (v4.5.2)
More efficient pagination for large datasets:

```graphql
{
  device_list(first: 50) {
    edges {
      node {
        name
        status
        primary_ip4 { address }
      }
      cursor
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}

# Next page:
{
  device_list(first: 50, after: "endCursor_value") {
    edges { ... }
    pageInfo { ... }
  }
}
```

**Advantages over offset pagination:**
- Consistent results even when data changes between pages
- Better performance for deep pages (page 100 of results)
- Standard GraphQL relay pagination pattern

### GraphQL Filtering Enhancements
Filter device components by site, location, or rack directly in GraphQL:

```graphql
{
  interface_list(device__rack_id: [5]) {
    name
    type
    speed
    device { name }
  }
}
```

Previously required fetching devices first, then interfaces. Now done in a single query.

### REST API Prefix Length
Specify prefix length when requesting available IPs:

```
GET /api/ipam/prefixes/15/available-ips/?prefix_length=30
```

Returns available IPs that can be allocated as a /30 (point-to-point link). Previously only individual IPs could be requested.

### Python Version Requirements
- **Required**: Python 3.12, 3.13, or 3.14
- **Dropped**: Python 3.11 support
- Ensure deployment environment (OS packages, Docker image, virtualenv) has Python 3.12+

## Migration to v4.5

### From v4.3/v4.4
- Direct upgrade path supported
- Database migration handles schema changes automatically
- Review release notes for any custom field type changes
- Verify Python version (3.12+ required)
- Plugin compatibility: check that all installed plugins support v4.5

### Migration Steps
```bash
# 1. Backup database
pg_dump -U netbox netbox > netbox_backup_$(date +%Y%m%d).sql

# 2. Backup media files
tar czf netbox_media_$(date +%Y%m%d).tar.gz /opt/netbox/netbox/media/

# 3. Update NetBox source
cd /opt/netbox
git fetch origin
git checkout v4.5.0

# 4. Run upgrade script
./upgrade.sh

# 5. Restart services
sudo systemctl restart netbox netbox-rq

# 6. Verify
curl -s https://netbox.example.com/api/ | python3 -m json.tool
```

### Post-Upgrade Tasks
- Set owners on critical objects (new feature)
- Review port mapping for patch panels (updated model)
- Update API clients if using GraphQL pagination (cursor-based now available)
- Update pynetbox to latest version for v4.5 compatibility
- Run data quality checks to verify no data loss during migration

## Version Boundaries

**Features available in v4.5:**
- Owner model for object-level ownership
- Bidirectional port mapping
- GraphQL cursor-based pagination (v4.5.2+)
- GraphQL component filtering by site/location/rack
- REST API prefix_length parameter for available-ips
- Python 3.12-3.14 support

**Features NOT in v4.5 (may appear in later releases):**
- Write operations via GraphQL (currently read-only)
- Built-in network topology visualization (available via plugin)
- Automated device discovery (NetBox is a data store, not a scanner)

## Common Pitfalls

1. **Upgrading without checking Python version** -- v4.5 drops Python 3.11. If your system runs 3.11, the upgrade will fail. Verify with `python3 --version` before upgrading.

2. **Plugin incompatibility** -- Not all community plugins are updated for v4.5 immediately. Check plugin compatibility before upgrading. Disable incompatible plugins during upgrade.

3. **Confusing owner with tenant** -- Owner is the data steward (who maintains the data in NetBox). Tenant is the organizational owner (which business unit the resource belongs to). They serve different purposes.

4. **Not using cursor pagination for large datasets** -- Offset-based pagination becomes slow for deep pages (>1000 records). Use cursor-based pagination (v4.5.2+) for large queries.

5. **Forgetting database backup** -- Always backup the PostgreSQL database before upgrading. Database migrations are irreversible without a backup.

## Reference Files

- `../references/architecture.md` -- Data model, REST/GraphQL API, plugins, config contexts
- `../references/best-practices.md` -- IPAM design, naming conventions, custom fields, integrations
