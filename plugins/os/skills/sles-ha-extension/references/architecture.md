# HA Extension Architecture Reference

Architecture reference for the SUSE Linux Enterprise High Availability Extension on SLES 15+.

---

## Corosync — Cluster Communication Layer

Corosync is the messaging and membership layer beneath Pacemaker. It tracks which nodes are alive, delivers ordered messages, and provides quorum information.

### Totem Protocol

Corosync uses the Totem Single Ring Order (TSRO) protocol:
- A token circulates around a virtual ring of nodes
- Only the token holder may transmit messages
- Guarantees total ordering and virtual synchrony

Key parameters in `corosync.conf`:
- `token`: ms before token loss declared (default 1000)
- `consensus`: ms for consensus before reconfiguration (default token * 1.2)
- `join`: ms node waits for join messages

### Transport Modes

| Transport | Description | Use Case |
|---|---|---|
| knet | Kernel net, default SLES 15 SP2+ | Multiple redundant links, encryption |
| udpu | UDP unicast, explicit node list | Cloud, NAT environments |
| udp | UDP multicast | Simple on-premises clusters |

knet replaces the deprecated Redundant Ring Protocol (RRP) with native multi-link support.

### Membership and Quorum

Corosync tracks membership via the CPG (Closed Process Group) API. Membership changes are delivered to all subscribers including Pacemaker's CRMd. The `votequorum` plugin provides quorum calculation.

---

## Pacemaker — Cluster Resource Manager

### Cluster Information Base (CIB)

The CIB is the single source of truth: an XML document replicated across all nodes containing the `configuration` section (resources, constraints, properties) and `status` section (current assignments, operation history).

CIB epoch tracks configuration versions. Highest epoch wins on conflict.

### Policy Engine (PE)

Runs on the Designated Controller (DC). Calculates desired cluster state from CIB, node health, and resource states. Produces a transition graph (DAG of actions). Use `crm_simulate` for offline testing.

### CRMd (Cluster Resource Manager Daemon)

Receives the transition graph from PE and coordinates action execution. On DC: distributes actions to remote LRMd instances. Handles DC election on DC failure.

### LRMd (Local Resource Manager Daemon)

Runs on every node. Directly executes resource agent scripts with appropriate environment variables (OCF_RESOURCE_INSTANCE, OCF_RESKEY_*).

### Designated Controller (DC)

One Pacemaker node acts as DC. Runs PE and coordinates decisions. DC election: highest Pacemaker version wins, ties broken by corosync node ID.

---

## Resource Types

### Primitive

Single instance managed by one node. All other types are composed of primitives.

### Group

Ordered set that always runs on the same node. Members start/stop in order. If any member fails, the entire group fails over.

### Clone

Runs simultaneously on multiple or all nodes. Used for: cluster filesystems, SBD daemons, network bonding.

### Promotable Clone (Multi-state)

Clone with Master (promoted) and Slave (unpromoted) states. Used for: DRBD replication, SAP HANA System Replication.

### Resource Agent Classes

| Class | Location | Examples |
|---|---|---|
| ocf:\<provider\>:\<type\> | /usr/lib/ocf/resource.d/ | IPaddr2, Filesystem, SAPHana |
| systemd:\<unit\> | systemd units | systemd:httpd |
| lsb:\<name\> | SysV init scripts | lsb:apache2 |
| stonith:\<type\> | /usr/sbin/fence_* | fence_sbd, fence_ipmilan |

---

## Fencing (STONITH)

### Why Fencing Is Mandatory

If a node loses network but continues running, it may write to shared storage. The surviving partition cannot assume the unresponsive node has stopped. Fencing provides verified confirmation.

### SBD Architecture

- SBD daemon (`sbdd`) runs on every node, continuously reading the SBD device
- Shared SBD disk contains a header and one slot per node
- To fence: write a POISON PILL to the target node's slot
- Target's sbdd reads the poison pill and calls `sbd --notime reboot`
- Hardware watchdog guarantees reboot even if OS hangs

SBD device count: 1 (SPOF), 3 (majority vote, recommended), diskless (watchdog-only, 3+ nodes).

### Fencing Topology

Multiple fencing methods in priority sequence. If level 1 fails, level 2 is tried:
```
fencing_topology \
    node1: stonith_sbd stonith_ipmi \
    node2: stonith_sbd stonith_ipmi
```

---

## Quorum

### votequorum

Each node has a configurable vote count (default 1). Quorum: votes present > total_expected_votes / 2.

### Two-Node Mode

`two_node: 1` changes quorum so 1 of 2 nodes is sufficient. Split-brain risk increases -- fencing becomes critical.

### wait_for_all

`wait_for_all: 1` prevents quorum until all expected nodes have joined at least once. Prevents a single node from starting resources during cluster restart.

### Quorum Device (qdevice)

External tiebreaker vote for 2-node clusters without SBD:
```bash
zypper install corosync-qdevice corosync-qnetd
```

### no-quorum-policy

| Policy | Behavior |
|---|---|
| stop (default) | All resources stopped -- safest |
| freeze | Resources stay but no new starts |
| ignore | Operates without quorum -- dangerous |
| suicide | Surviving nodes fence themselves |
