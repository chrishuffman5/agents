# Dell Unity XT Best Practices

## Pool Design

- Use a single pool per system for maximum flexibility. Separate only when SLA/compliance requires strict isolation.
- Maintain 10%+ free physical capacity. Below 10%: FAST VP inefficient. Below 5%: health degrades. At 95%: critical alert + auto snapshot deletion.
- Use thin provisioning for all objects. Required for most Unity features.
- Start with enough drives for maximum RAID width: RAID 5 = 13 drives, RAID 6 = 16, RAID 1/0 = 8.
- Single drive size within AFA pool. Single RAID type per pool.
- RAID 5 (12+1): recommended for AFA (negligible performance difference vs 1/0, better capacity). RAID 6 (14+2): for large NL-SAS hybrid pools. RAID 1/0: only for extreme write-intensive workloads.

## FAST VP Configuration

- Default policy: Start High then Auto-tier — use for all general workloads.
- Schedule outside peak hours (default 22:00-06:00 UTC). For 24/7 workloads: run continuously.
- Avoid overlap with backup windows. Set windows in multiples of 60 minutes.
- Size flash tier at 20-30% of active working set.
- FAST VP and FAST Cache can run simultaneously on hybrid pools.

## NAS Server Design

- Load balance across both SPs (alternate NAS server ownership).
- Configure front-end ports symmetrically on both SPs for failover.
- Use link aggregation (LACP) and FSN for network HA.
- Define 2+ DNS servers per NAS server (DNS on I/O path for SMB).
- Disable SMB1 (default). Consider SMB2 disable for high-security (OE 5.4+).
- Enable SMB encryption for sensitive shares. Use NFSv4.1 where client supports.
- For multiprotocol: configure both AD and UNIX directory service, test both access paths.

## Replication

- Async replication for most DR (RPO from 5 minutes). Sync requires Metro Node (FC).
- Group related LUNs into Consistency Groups before replicating — ensures write-order consistency.
- Replicate NAS servers at NAS server level (captures network identity + all file systems).
- Use dedicated replication interfaces/VLANs.
- Pre-seed large initial syncs via offline seeding to avoid WAN saturation.
- Test DR failover quarterly with planned failover (no data loss).
- Before OE upgrades: verify replication health check passes. Failed replication blocks NDU.
- To unblock NDU: pause sessions from source (`uemcli /prot/rep/session pause -async`), or update/recreate connections in error state.

## Migration to PowerStore

### Assessment
1. Inventory all LUNs, CGs, file systems, NAS servers, hosts, protocols, sizes
2. Map applications to storage objects; identify consistency requirements
3. Assess if hosts can be zoned to both arrays simultaneously
4. Estimate post-migration capacity using PowerStore sizing tools
5. Plan maintenance windows (block is online; file needs brief cutover)

### PowerStore Universal Storage Import (USI)

**Block** (3.0+): Connect Unity to PowerStore via FC/iSCSI. PowerStore pulls data online. Cutover: final sync then rezone hosts. Minutes of downtime.

**File** (4.0+): Configure migration interfaces on both arrays. PowerStore creates destination NAS server and file systems. Cold data copied in background. Cutover: redirect DNS/mount points. SMB clients may need remount.

### Recommendations
- Begin 18-24 months before support expiration
- Migrate dev/test first, then production in phases
- Keep Unity in parallel 30 days post-cutover as fallback
- Engage Dell Professional Services for complex environments
