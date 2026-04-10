# Dell Unity XT Best Practices

## Pool Design

### General Pool Principles

**Use a single storage pool where possible.**
Dell's official best practices guidance recommends minimizing the number of pools to reduce complexity and increase flexibility. A single pool allows all storage objects to draw from the same capacity reserve, simplifying capacity planning and avoiding the risk of one pool being full while another has available space.

**Maintain at least 10% free physical capacity in every pool.**
- Below 10%: FAST VP relocations become inefficient or unable to run
- Below 5%: Pool health degrades; thin-provisioned objects may fail to allocate
- At 95%: Unisphere generates a critical alert; automatic snapshot deletion policies may be invoked
- Pool full condition: New I/O to thin LUNs or file systems will fail

**Use thin provisioning for all storage objects.**
- Thin provisioning provides better capacity utilization by allocating physical space on write
- Required for most Unity features (snapshots, FAST VP, replication, data reduction)
- Minimum recommended thin object size: 100 GB; ideally 1 TB or larger for efficiency

**Separate workload types by pool only when technically justified.**
- Mix block and file objects freely in the same pool — Unity handles this natively
- Consider separate pools only when SLA or compliance requires strict capacity isolation

---

### Dynamic Pool Design

Dynamic pools (Mapped RAID) are the recommended pool type for all new Unity XT deployments.

**Start with enough drives to achieve maximum RAID width.**

| RAID Type | Maximum Width | Minimum Drives for Max Width |
|-----------|-------------|---------------------------|
| RAID 5 | 12+1 (13 drives) | 13 drives |
| RAID 6 | 14+2 (16 drives) | 16 drives |
| RAID 1/0 | 4+4 (8 drives) | 8 drives |

Starting with fewer drives results in narrower initial RAID widths, which wastes capacity for the same level of protection. Once the pool contains enough drives for the maximum width, all subsequent drive additions automatically use maximum-width extents.

**Use a single drive size within an AFA pool.**
Mixing drive sizes in a pool is supported but creates complexity in capacity calculation and RAID extent distribution. Dell recommends homogeneous drive sizes per pool, particularly for AFA configurations.

**Use a single RAID type per pool.**
Mixing RAID 5 and RAID 6 within one pool is possible but increases management complexity. Choose RAID 6 if the pool will exceed 16 drives and higher fault tolerance is desired.

**RAID selection guidance:**
- **RAID 5 (12+1)**: Recommended default for AFA pools; internal testing shows negligible performance difference vs. RAID 1/0 for most workloads; best capacity efficiency
- **RAID 6 (14+2)**: Recommended for pools with large-capacity NL-SAS drives in hybrid configurations; better protection during rebuild of a failed drive on large drives
- **RAID 1/0 (4+4)**: Consider only for sustained extremely write-intensive workloads where the capacity penalty is acceptable

**Spare capacity allocation (dynamic pools):**
- Spare space is automatically reserved at ~1 drive equivalent per 32 drives
- No dedicated hot spare drives needed; spare extents are distributed across all drives

---

## FAST VP Configuration

### Enabling and Configuring FAST VP

FAST VP is licensed separately and must be enabled on the system. Once enabled, tiering policies apply at the individual storage object level (LUN, file system, CG).

**Default policy: Start High then Auto-tier** — use this for all general-purpose workloads.
- New allocations go to the highest available tier (Extreme Performance flash)
- Data is demoted to lower tiers as it ages and access frequency drops
- This policy provides the best initial performance for new data and predictable cost efficiency over time

**Scheduling recommendations:**
1. Configure the relocation window to run outside peak business hours (default: 22:00–06:00 UTC)
2. For continuously active workloads (24/7 databases, always-on applications), set FAST VP to run continuously rather than on a schedule
3. Schedule FAST VP relocation to complete before nightly backups begin; FAST VP and backup running simultaneously causes I/O contention
4. Set relocation windows in multiples of 60 minutes to minimize partial relocation cycles
5. Each pool can override the system schedule and run independently if different workloads on different pools have conflicting scheduling needs

**Tier sizing guidance:**
- Extreme Performance (flash) tier: Size to hold at least 20–30% of the pool's active working set
- If the flash tier is too small, FAST VP will not be able to promote all hot data; performance improvement will be limited
- Monitor the FAST VP relocation statistics in Unisphere to validate tier efficiency

**FAST VP and FAST Cache interaction:**
- Both can run simultaneously on the same pool
- FAST Cache provides fine-grained (64 KB) caching of random hot I/O at sub-second response times
- FAST VP handles coarse-grained (256 MB) tier migration on an hourly-to-daily basis
- For hybrid pools with large HDD capacity tiers, enabling both maximizes TCO and performance

---

## NAS Server Design

### Sizing and Distribution

**Load balance NAS servers across both SPs.**
- Create NAS servers alternately on SPA and SPB so that NAS file I/O is distributed evenly across both processors
- Rule of thumb: divide the total number of NAS servers evenly between SPs; each SP should own roughly half the NAS workload
- Monitor per-SP CPU utilization in Unisphere to validate balance; rebalance by migrating NAS server ownership if one SP is persistently >70% utilized

**Dedicate NAS servers by workload or business unit when practical.**
- Separate NAS servers for general-purpose shares vs. databases vs. backups allows independent failover, protocol configuration, and quota management
- Avoid creating too many NAS servers; each adds management overhead and consumes SP resources

### Network Interface Configuration

**Configure front-end ports symmetrically across both SPs.**
- Each NAS server interface should have a corresponding port on the peer SP for failover continuity
- Symmetrical port assignment ensures that after an SP failover, the surviving SP has ports available to service the migrated NAS server's traffic

**Use link aggregation for throughput and availability.**
- Bond multiple 10/25 GbE ports into LACP link aggregates on each SP
- Link aggregation protects against individual port/cable failures and increases available bandwidth

**Use Fail-Safe Networking (FSN) for switch-redundancy.**
- FSN bonds ports from two different switches into a single logical interface
- Provides switch-level redundancy in addition to port-level link aggregation
- Required for environments with zero-tolerance for switch failure

**Configure multiple DNS servers.**
- NAS server DNS lookup is on the I/O path for CIFS/SMB operations
- Always define at least two DNS servers to avoid a DNS single point of failure affecting SMB shares

### Protocol Configuration

**SMB (CIFS) best practices:**
- Join each NAS server to Active Directory during initial configuration
- Enable SMB encryption for sensitive shares (supported from SMB 3.0 clients)
- Disable SMB1 entirely (Unity OE default); consider disabling SMB2 if required by security policy (available from OE 5.4)
- Enable continuous availability (CA) for file shares accessed by Hyper-V VMs or SQL Server via SMB

**NFS best practices:**
- Use NFSv4.1 for production workloads where client OS support allows; better security and performance than NFSv3
- Configure Kerberos authentication for NFS where security policy requires it
- For multiprotocol environments, configure LDAPS for secure directory service lookups
- Verify NFS client mount options: `rsize` and `wsize` of 65536 bytes (64 KB) or 1048576 bytes (1 MB) for throughput-intensive workloads

**Multiprotocol (SMB + NFS) best practices:**
- Join the NAS server to Active Directory AND configure a UNIX Directory Service (LDAP or NIS) or local user/group files
- Configure user mapping so Windows SIDs map to UNIX UIDs/GIDs consistently
- Test access from both Windows and Linux clients before production cutover
- Use LDAPS (secure LDAP) for directory service connections to the NAS server

---

## Replication Best Practices

### Replication Architecture

**Use asynchronous replication for most DR scenarios.**
- Async replication RPO starts at 5 minutes; adjust based on RTO/RPO requirements and WAN bandwidth
- Supported objects: LUNs, Consistency Groups, file systems, NAS servers, VMware VMFS and NFS datastores
- Both source and destination systems must have replication licenses

**Use synchronous replication only for zero-RPO requirements.**
- Sync replication requires Metro Node (external appliance) for FC environments
- Sync replication adds write latency proportional to round-trip time to the remote site; keep inter-site latency under 5 ms for best results

### Replication Session Configuration

**Group related LUNs into Consistency Groups before replicating.**
- CGs ensure that all members are replicated to a consistent point-in-time
- Critical for multi-LUN applications (databases with separate data/log/temp LUNs, Exchange database + log)
- Replicate the entire CG as a unit, not individual LUNs

**Replicate NAS servers at the NAS server level (not individual file systems) when possible.**
- NAS server-level replication captures the server configuration (network interfaces, DNS, AD join) plus all file systems in a single session
- Simplifies DR failover: recovering the NAS server also restores network identity and shares
- File system-level replication is available for more granular control but requires separate DR procedures for the NAS server configuration

**Configure dedicated replication network interfaces.**
- Replication traffic competes with host I/O on shared interfaces
- Use dedicated Ethernet ports or VLANs for replication traffic to prevent saturation of host-facing interfaces
- If separate physical ports are not available, configure replication to use a separate VLAN and QoS policy

**Pre-seed initial replication for large datasets.**
- For large initial sync over WAN, use the offline pre-seeding method: replicate to a local seed drive, ship the drive to the DR site, import to the destination array, then establish incremental replication
- This avoids sending terabytes over WAN for the initial baseline

### Replication Health Maintenance

- Monitor replication lag in Unisphere under Data Protection > Replication Sessions
- Set alert thresholds for replication lag exceeding 2x the configured RPO
- Test replication failover on a quarterly basis using planned failover (no data loss) to validate DR readiness
- Before OE upgrades, verify replication health check passes; upgrade will block if replication sessions are in error state

---

## Migration to PowerStore

### Pre-Migration Assessment

1. **Inventory all storage objects**: Document all LUNs, consistency groups, file systems, NAS servers, and their associated hosts, protocols, and sizes
2. **Identify application dependencies**: Map applications to storage objects; identify multi-LUN consistency requirements
3. **Assess network topology**: Determine if hosts can be zoned/connected to PowerStore in parallel with Unity
4. **Evaluate data reduction**: Use CloudIQ or PowerStore sizing tools to estimate post-migration capacity on PowerStore
5. **Plan maintenance windows**: Block migration is online (non-disruptive) but requires host-side steps; file migration requires a brief cutover window per NAS server

### Dell PowerStore Universal Storage Import (USI)

PowerStore's native import capability (available from PowerStoreOS 3.0+ for block, 4.0+ for file) supports Unity XT as a source system.

**Block Import Process:**
1. Connect Unity XT to PowerStore via FC or iSCSI (Unity is the "source", PowerStore is the "destination")
2. In PowerStore Manager: Storage > Import > Create Import Session; select Unity XT source
3. PowerStore pulls data online in background (non-disruptive; Unity continues serving I/O)
4. At cutover: PowerStore issues a final sync, then hosts are rezoned/reconnected to PowerStore LUNs
5. Total downtime is typically minutes for the host reconnection step

**File Import Process (PowerStoreOS 4.0+):**
1. Configure migration interfaces on both Unity and PowerStore (dedicated migration network recommended)
2. In PowerStore Manager: Create File Import Session; specify source NAS server on Unity
3. PowerStore automatically creates the destination NAS server and file systems
4. Cold data is copied in background; PowerStore and Unity operate in parallel during this phase
5. At cutover: Redirect DNS/mount points to PowerStore NAS server; clients experience a brief reconnection
6. SMB clients may need to remount shares; NFS clients with NFSv3 reconnect transparently

### Migration Planning Recommendations

- **Migrate during the support window**: Complete migration before Unity's software update eligibility expires (approximately 3 years from purchase for pre-EOS systems)
- **Migrate by workload tier**: Start with dev/test systems to validate process; then move production workloads in phases
- **Use parallel operation period**: Import sessions allow Unity and PowerStore to coexist during migration; no forced cutover deadline
- **Validate with application teams**: Confirm application performance on PowerStore before decommissioning Unity LUNs
- **Keep Unity in place for 30 days post-cutover**: Allows emergency rollback if post-migration issues emerge; then decommission Unity
- **Engage Dell Professional Services** for large or complex environments; Dell offers Unity-to-PowerStore migration assessment and execution services
