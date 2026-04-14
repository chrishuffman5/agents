# AD DS Architecture Internals

Deep technical reference for Active Directory Domain Services internal architecture and operation.

---

## NTDS.dit Database

The AD DS database uses the Extensible Storage Engine (ESE), also known as JET Blue. The same engine underlies Exchange Server's mailbox database.

### Database Files

| File | Purpose | Default Location |
|---|---|---|
| `NTDS.dit` | Main database (schema, objects, links, security descriptors) | `C:\Windows\NTDS\` |
| `edb.log` | Transaction log (current) | `C:\Windows\NTDS\` |
| `edb.chk` | Checkpoint file (tracks flushed transactions) | `C:\Windows\NTDS\` |
| `edbres00001.jrs` | Reserve log space (ensures clean shutdown if disk is full) | `C:\Windows\NTDS\` |
| `temp.edb` | Temporary table storage for ESE operations | `C:\Windows\NTDS\` |

### Database Structure

NTDS.dit contains several logical tables:

- **Data table** -- All AD objects. Each row is an object. Columns are attributes defined in the schema. Indexed by DNT (Distinguished Name Tag, internal row ID).
- **Link table** -- Forward and backward links between objects (e.g., member/memberOf). Indexed by link ID and DNT.
- **Security Descriptor table** -- Stores unique security descriptors. Objects reference SDs by index, enabling deduplication (SD refcounting).
- **Hidden table** -- Internal metadata (database version, replication state, invocation ID).

### Database Size and Performance

- Default page size: 8KB (pre-2025). 32KB in Server 2025 (functional level 10).
- Typical database size: 1-10 GB for most organizations (millions of objects).
- ESE uses a buffer pool (database cache) in RAM. Size is auto-tuned but can be constrained via `dsamain` registry settings.
- Transaction logs are 10 MB each. Circular logging is NOT used -- logs are truncated after checkpoint advance and backup.

### Defragmentation

- **Online defragmentation** -- Runs automatically every 12 hours. Reclaims space within the database file but does not shrink the file.
- **Offline defragmentation** -- Requires DSRM boot. Compacts the database file: `ntdsutil "activate instance NTDS" "files" "compact to C:\temp\ntds"`. Rarely needed.

---

## Replication Internals

### Replication Model

AD DS uses **multi-master, pull-based** replication. Each DC holds a writable copy (except RODCs). Changes are pulled by destination DCs from source DCs.

### Update Sequence Numbers (USNs)

Each DC maintains a local USN counter. Every change increments the USN. DCs track replication state using:

- **highestCommittedUSN** -- Current USN of the local DC
- **Up-to-dateness vector (UTDV)** -- Table of (originating DC GUID, highest USN received from that DC). Used to avoid re-replicating already-seen changes.
- **High watermark table** -- Per-replication-partner, the highest USN received from that partner. Used to efficiently request only new changes.

### Change Tracking

Every attribute change records:
- **Originating DC** -- Which DC first wrote the change
- **Originating USN** -- The USN on the originating DC at the time of change
- **Version number** -- Incremented with each change to the attribute
- **Timestamp** -- When the change occurred

### Conflict Resolution

When the same attribute is modified on two DCs before replication:
1. **Higher version number wins**
2. If version numbers tie: **later timestamp wins**
3. If timestamps tie: **higher originating DC GUID wins** (deterministic tiebreaker)

### Replication Topology (KCC)

The Knowledge Consistency Checker (KCC) runs on every DC every 15 minutes and generates the replication topology:

**Intra-site:**
- Creates a bidirectional ring topology ensuring at most 3 hops between any two DCs
- Adds shortcut connections when >7 DCs in a site (replication latency optimization)
- Replication triggered by change notification (15-second delay, configurable)

**Inter-site:**
- Inter-Site Topology Generator (ISTG) role on one DC per site creates connections
- Uses site link cost to compute spanning tree (lowest cost path)
- Replication is schedule-based (default: every 180 minutes)
- Uses site link bridges if enabled (transitive site links)

### Replication Protocols

| Protocol | Transport | Use Case | Compression |
|---|---|---|---|
| RPC over IP | TCP/135 + dynamic ports | All partitions, intra-site and inter-site | Yes (inter-site always, intra-site >50KB) |
| SMTP | SMTP (port 25) | Schema and Configuration partitions only (inter-site) | Yes |

SMTP replication is rarely used and requires an Enterprise CA for message signing.

### Urgent Replication

Certain changes trigger immediate replication (bypass the 15-second notification delay):
- Account lockout
- Change to account lockout policy
- Change to domain password policy
- LSASS secret changes
- RID Manager state changes

---

## Sites and Subnets

Sites represent the physical topology of the network. Subnets are associated with sites to enable clients to find the nearest DC.

### DC Locator Process

When a client needs to find a DC:
1. Client queries DNS for `_ldap._tcp.dc._msdcs.example.com` SRV records
2. If site-aware: queries `_ldap._tcp.SiteName._sites.dc._msdcs.example.com`
3. Client determines its site by presenting its IP to a DC (DsGetSiteName)
4. If the client is in a different site than the responding DC, the DC refers the client to a DC in the client's site

### Site Link Configuration

```powershell
# Create a site link
New-ADReplicationSiteLink -Name "NYC-LON" -SitesIncluded "NYC","LON" `
    -Cost 500 -ReplicationFrequencyInMinutes 60

# Configure site link schedule (restrict replication to off-hours)
Set-ADReplicationSiteLink -Identity "NYC-LON" `
    -ReplicationSchedule @{DayOfWeek="Saturday";StartHour=0;EndHour=6}
```

### Site-Aware Services

Services that use AD sites for topology-aware behavior:
- **DFS** -- Namespace referrals prefer same-site targets
- **SCCM/MECM** -- Boundary groups for content distribution
- **Exchange** -- DAG witness and transport routing
- **DNS** -- Site-aware DNS registration (DCs register SRV records per site)

---

## Global Catalog

The Global Catalog (GC) is a partial, read-only copy of all objects in every domain in the forest. Stored on DCs designated as GC servers.

**Contents:** All objects from all domains, but only a subset of attributes (those marked in the schema with `isMemberOfPartialAttributeSet = TRUE`). Approximately 200 attributes out of the full schema.

**Port:** LDAP 3268 (unencrypted) / LDAPS 3269 (TLS)

**Use cases:**
- Universal group membership resolution during Kerberos authentication
- Forest-wide LDAP searches (e.g., Exchange address book, login with UPN)
- Object lookup across domain boundaries

**When to make a DC a GC:**
- All DCs should be GCs unless there is a specific reason not to (e.g., single Infrastructure Master in a multi-domain forest without all DCs as GCs).
- Microsoft's current recommendation: make all DCs Global Catalog servers.

---

## Schema

The schema partition defines all object classes and attributes in the forest. It is the blueprint for every object stored in AD.

### Schema Master Role

Only the Schema Master DC can write to the schema partition. Schema modifications are rare and significant:
- Adding a new attribute or object class
- Modifying an existing attribute (limited changes allowed)
- Deactivating an attribute or object class (cannot truly delete)

### Schema Extension Guidelines

- Schema changes are forest-wide and **irreversible** (attributes/classes can be deactivated but not deleted)
- Test in a lab forest first. Always.
- Use OID registration for custom attributes (IANA or Microsoft OID namespace)
- Common schema extensions: Exchange Server, SCCM, Lync/Skype, LAPS, FIM/MIM

---

## Trust Authentication Flow

### Cross-Forest Authentication (Forest Trust)

```
User@DomainA --> DC in DomainA
  |-- User presents credentials to local DC
  |-- DC verifies authentication locally
  |-- User requests access to resource in DomainB (different forest)
  |-- DC in DomainA creates referral ticket (TGT for DomainB's KDC)
  |-- Referral follows trust path: DomainA --> ForestRootA --> ForestRootB --> DomainB
  |-- Each DC in the chain validates and re-issues referral
  |-- DC in DomainB issues service ticket for the target resource
  |-- SID filtering applies at the trust boundary
```

### Name Suffix Routing

Forest trusts use name suffix routing to determine which forest owns a UPN suffix or DNS name:
- Enabled by default for all DNS namespaces in the trusted forest
- Can be disabled per suffix to prevent routing conflicts
- Essential for selective authentication trusts

### Selective Authentication

When enabled on a trust, users from the trusted domain/forest must be explicitly granted the "Allowed to Authenticate" permission on resources in the trusting domain/forest. Provides fine-grained control over cross-trust access.

---

## RODC (Read-Only Domain Controller)

RODCs are DCs that hold a read-only copy of the AD database. Designed for branch offices with limited physical security.

**Key characteristics:**
- No outbound replication (changes must be made on writable DCs)
- Credential caching controlled by Password Replication Policy (PRP)
- Filtered attribute set (FAS) excludes sensitive attributes from RODC
- Each RODC has a unique `krbtgt_XXXXX` account for Kerberos ticket signing
- Admin role separation: RODC-specific admin roles without domain-wide privileges

**Password Replication Policy:**
- `Allowed RODC Password Replication Group` -- Accounts whose passwords CAN be cached
- `Denied RODC Password Replication Group` -- Accounts whose passwords MUST NOT be cached (default includes Domain Admins, Enterprise Admins, Schema Admins)
- If a password is not cached and the writable DC is unreachable, authentication fails

---

## DFS-R (Distributed File System Replication) for SYSVOL

SYSVOL contains Group Policy templates, logon scripts, and other domain-wide files. DFS-R replaced FRS (File Replication Service) for SYSVOL replication starting with Windows Server 2008.

**Migration states (FRS to DFS-R):**
1. **Start (State 0)** -- FRS active
2. **Prepared (State 1)** -- DFS-R copies created alongside FRS
3. **Redirected (State 2)** -- DFS-R is authoritative, FRS still running
4. **Eliminated (State 3)** -- FRS removed

```powershell
# Check SYSVOL replication state
dfsrmig /getmigrationstate

# Advance migration state
dfsrmig /setglobalstate 1  # Prepare
dfsrmig /setglobalstate 2  # Redirect
dfsrmig /setglobalstate 3  # Eliminate
```

**Important:** FRS-to-DFSR migration must be completed before raising functional level to 2016+.
