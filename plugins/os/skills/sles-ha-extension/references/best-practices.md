# HA Extension Best Practices Reference

Best practices for the SUSE Linux Enterprise High Availability Extension on SLES 15+.

---

## Cluster Design

### Node Count Considerations

| Nodes | Quorum | Fencing | Use Case |
|---|---|---|---|
| 2 | `two_node: 1` required | SBD or qdevice mandatory | Basic HA |
| 3 | Natural majority | Diskless SBD viable | SAP HANA recommended minimum |
| 4+ | Standard majority | Even counts need witness | Scale-out workloads |

### Network Architecture

- Cluster communication (corosync) and application traffic: separate NICs/VLANs
- Redundant cluster network paths: two NICs bonded, or knet with two links
- Each corosync link on a different physical path (different switches if possible)
- Required firewall ports: corosync UDP 5405-5406, pacemaker TCP 2224, HAWK HTTPS 7630

### Time Synchronization

Accurate time is required across all nodes. Time skew causes certificate validation failures, log correlation problems, and SBD timing issues. Maximum recommended skew: < 1 second.

```bash
chronyc tracking                          # Verify NTP sync
```

### SBD Shared Storage

- SBD devices must be accessible by all nodes simultaneously (shared iSCSI, FC, or DRBD)
- SBD disk is small (1 MB sufficient)
- Multipath (multipathd) recommended for SBD disks
- With 3 SBD devices, all three should be on independent paths/targets

---

## Resource Configuration

### crm Shell (crm configure)

```bash
crm configure show                        # Display all config
crm configure primitive <id> <class>:<provider>:<type> params <params>
crm configure group <id> <primitives>
crm configure clone <id> <resource>
crm configure ms <id> <resource>          # Multi-state (master/slave)
crm configure location <id> <resource> <score>: <node>
crm configure colocation <id> <score>: <rsc1> <rsc2>
crm configure order <id> <kind>: <rsc1> <rsc2>
crm configure property stonith-enabled=true no-quorum-policy=stop
crm configure verify                      # Validate without applying
crm configure commit                      # Apply staged changes
```

### Constraints

- **Location**: Prefer or avoid specific nodes. INFINITY = mandatory.
- **Colocation**: Resources on same node. INFINITY = mandatory co-location.
- **Order**: Start/stop ordering. `Mandatory` = hard dependency, `Optional` = prefer, `Serialize` = never simultaneous.

### Resource Stickiness

Prevent unnecessary failback after recovery:

```bash
crm configure property default-resource-stickiness=1000
# Or per-resource: meta resource-stickiness=200
```

### migration-threshold and failure-timeout

```bash
# After 3 failures within 600s, migrate away
meta migration-threshold=3 failure-timeout=600s
```

---

## Maintenance Operations

### Cluster-Wide Maintenance

```bash
crm configure property maintenance-mode=true    # Resources unmanaged
crm configure property maintenance-mode=false   # Resume management
```

Use for: patching all nodes, storage maintenance, testing changes.

### Node Standby

```bash
crm node standby node1                   # Resources migrate away
crm node online node1                    # Return to active
```

Use for: individual node maintenance (kernel patching, hardware).

### Resource Unmanage

```bash
crm resource unmanage rsc_ip             # Cluster stops managing (keeps running)
crm resource manage rsc_ip               # Return to managed
```

### Cleanup and Refresh

```bash
crm resource cleanup rsc_ip              # Clear failure count
crm resource cleanup rsc_ip node1        # Clear on specific node
crm resource refresh                     # Force re-probe all states
```

---

## SAP HANA High Availability

### SAPHanaTopology

Clone on all nodes, discovers SR topology. Does NOT manage HANA directly.

```
primitive rsc_SAPHanaTopology_HDB ocf:suse:SAPHanaTopology \
    params SID=HDB InstanceNumber=00 \
    op monitor interval=10s timeout=600s

clone cl_SAPHanaTopology_HDB rsc_SAPHanaTopology_HDB \
    meta clone-node-max=1 interleave=true
```

### SAPHana

Promotable clone managing HANA primary/secondary.

```
primitive rsc_SAPHana_HDB ocf:suse:SAPHana \
    params SID=HDB InstanceNumber=00 \
           PREFER_SITE_TAKEOVER=true \
           AUTOMATED_REGISTER=true \
           DUPLICATE_PRIMARY_TIMEOUT=7200 \
    op start timeout=3600s \
    op stop timeout=3600s \
    op promote timeout=3600s \
    op monitor interval=60s role=Master timeout=700s \
    op monitor interval=61s role=Slave timeout=700s

ms msl_SAPHana_HDB rsc_SAPHana_HDB \
    meta notify=true clone-max=2 clone-node-max=1 interleave=true
```

### Deployment Models

- **Performance-Optimized**: Both nodes fully loaded, fastest takeover (< 60s)
- **Cost-Optimized**: Secondary runs non-production workload, longer takeover

### Constraint Set

```bash
crm configure colocation col_ip_master INFINITY: rsc_ip msl_SAPHana_HDB:Master
crm configure order ord_topology_first Optional: cl_SAPHanaTopology_HDB msl_SAPHana_HDB
```

---

## HAWK Web Console

### Setup

```bash
systemctl enable --now hawk
firewall-cmd --permanent --add-port=7630/tcp
firewall-cmd --reload
# Access: https://<node>:7630
```

### Certificate Management

```bash
# Replace self-signed cert for production
cp /path/to/cert.pem /etc/hawk/hawk.pem
cp /path/to/key.pem /etc/hawk/hawk.key
systemctl restart hawk
```

### Security

- HTTPS only (HTTP redirected)
- Authentication via PAM
- `haclient` group for full management access
- HAWK talks to local `cib.sock` -- must run on a cluster node

---

## Pre-Production Checklist

1. Fencing tested and verified (`stonith_admin -t fence_sbd -n node2`)
2. Quorum configuration matches node count
3. SBD devices reachable from all nodes
4. Hardware watchdog confirmed (`ls -l /dev/watchdog`)
5. NTP synchronized across all nodes
6. Corosync authentication key identical on all nodes
7. Firewall rules open for corosync, pacemaker, HAWK
8. Resource stickiness configured to prevent unnecessary failback
9. `crm_verify -L -V` reports no errors
10. Failover tested in non-production environment
