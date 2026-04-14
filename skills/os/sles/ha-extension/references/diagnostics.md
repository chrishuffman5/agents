# HA Extension Diagnostics Reference

Diagnostic procedures for the SUSE Linux Enterprise High Availability Extension on SLES 15+.

---

## Cluster Status Commands

### crm_mon

Primary real-time monitoring tool:

```bash
crm_mon -1                  # One-shot output
crm_mon -r                  # Include inactive/stopped resources
crm_mon -f                  # Include failed actions
crm_mon -A                  # Include node attributes
crm_mon -1 -r -f -A         # Most comprehensive view
```

Key fields: Stack (corosync), Current DC, node states (Online/OFFLINE/Standby/Maintenance), resource assignments, Failed Resource Actions.

### Additional Status Commands

```bash
crm status                               # Alias for crm_mon -1
corosync-cfgtool -s                      # Ring/link status
corosync-quorumtool -s                   # Quorum votes and membership
crm node list                            # Cluster nodes
crm resource list                        # All resources
crm_verify -L -V                         # Verify CIB for errors
systemctl status corosync pacemaker sbd hawk  # Service status
sbd -d /dev/sdb dump                     # SBD device header
sbd -d /dev/sdb list                     # SBD node slot status
```

---

## Cluster Logs

### Primary Log Files

| File | Content |
|---|---|
| `/var/log/pacemaker/pacemaker.log` | PE decisions, resource operations, DC elections |
| `/var/log/cluster/corosync.log` | Membership events, ring status, token activity |
| `/var/log/messages` | System syslog with cluster events |
| `/var/log/hawk/hawk.log` | HAWK web service access and errors |

### Log Analysis

```bash
# PE transition logs (WHY resources moved)
grep "pacemaker-schedulerd\|pengine" /var/log/pacemaker/pacemaker.log | tail -50

# Fencing events
grep -i "fence\|stonith\|sbd" /var/log/pacemaker/pacemaker.log | tail -20

# DC election events
grep "crmd.*DC\|Elected" /var/log/pacemaker/pacemaker.log | tail -10

# Resource failures
grep "ERROR\|error.*rsc_" /var/log/pacemaker/pacemaker.log | tail -30
```

### crm_report

Comprehensive cluster diagnostic bundle from all nodes:

```bash
crm_report -f "2026-04-07 08:00:00" -t "2026-04-07 10:00:00" /tmp/cluster-report
# Creates tarball with pacemaker.log, corosync.log, CIB snapshot from all nodes
```

Requires passwordless SSH between cluster nodes (typically pre-configured for hacluster user).

---

## Troubleshooting Workflows

### Resource Won't Start

1. Check failure state: `crm_mon -1 -r -f`
2. Check operation history: `crm resource history <id>`
3. Run resource agent manually:
   ```bash
   OCF_ROOT=/usr/lib/ocf OCF_RESKEY_ip=192.168.1.100 \
     /usr/lib/ocf/resource.d/heartbeat/IPaddr2 validate-all
   ```
4. Check constraints: `crm resource locate <id>`
5. Clean up: `crm resource cleanup <id>`
6. Re-enable: `crm resource start <id>`

### Unexpected Failover

1. Note failover timestamp: `crm_mon -1 -f`
2. Search pacemaker log for transition reason
3. Check if node was fenced: `grep stonith pacemaker.log`
4. Check corosync membership: `grep "processing node" corosync.log`
5. Check network: NIC counters, switch logs
6. Check SBD: `sbd -d /dev/sdb dump`

### Split-Brain Investigation

1. Check corosync ring: `corosync-cfgtool -s`
2. Check quorum: `corosync-quorumtool -s`
3. Check fencing: did STONITH work? (pacemaker.log)
4. Only ONE partition should show `partition with quorum`
5. Verify SBD reachable: `sbd -d /dev/sdb list`

### Fencing Failure

1. Check what was attempted: `grep "stonith\|fence" pacemaker.log`
2. Verify STONITH resource running: `crm_mon -1 -r`
3. Test fence agent: `stonith_admin -I`
4. For SBD: verify devices: `sbd -d /dev/sdb -d /dev/sdc dump`
5. For IPMI: test connectivity: `ipmitool -H <bmc-ip> chassis status`
6. Check watchdog: `ls -l /dev/watchdog`

### Node Won't Join Cluster

1. Verify corosync running: `systemctl status corosync`
2. Check ring connectivity: `corosync-cfgtool -s`
3. Check firewall: UDP 5405 must be open
4. Check time sync: `chronyc tracking`
5. Verify `corosync.conf` nodelist matches actual addresses
6. Check authkey: `md5sum /etc/corosync/authkey` (must match all nodes)
7. Check corosync.log on both nodes

---

## Quick Diagnostic Reference

```bash
# Is the cluster healthy?
crm_mon -1 -r -f

# Is quorum present?
corosync-quorumtool -s | grep Quorate

# Are all rings/links healthy?
corosync-cfgtool -s | grep "no faults"

# Is fencing configured and working?
crm configure show | grep stonith-enabled
stonith_admin -I

# Any CIB errors?
crm_verify -L -V

# What changed recently?
cibadmin -Q | grep cib-last-written
```
