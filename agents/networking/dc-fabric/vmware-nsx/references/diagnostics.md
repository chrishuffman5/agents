# VMware NSX Diagnostics Reference

## Central CLI

NSX provides a unified CLI accessible via SSH to NSX Manager or Edge nodes.

### NSX Manager CLI

```bash
# Cluster status
get cluster status                          # Manager cluster health
get cluster node-status                     # Per-node status

# Transport nodes
get transport-nodes                         # List all transport nodes
get transport-node <node-id> status         # Specific node status
get host-switch-state                       # Virtual switch state on hosts

# Logical switching
get logical-switches                        # List all segments (policy: segments)
get logical-switch <ls-id>                  # Specific segment details
get logical-switch <ls-id> vtep             # VTEP table for segment

# Logical routing
get logical-routers                         # List all T0/T1 gateways
get logical-router <lr-id> route-table      # Routing table
get logical-router <lr-id> interface        # Router interfaces

# Firewall
get firewall status                         # DFW status
get firewall rule-stats <section-id>        # Rule hit counts

# Edge node (SSH to Edge)
get interfaces                              # Edge interfaces
get route                                   # Edge routing table
get bgp neighbor summary                    # BGP peer status
get bgp neighbor <ip> received-routes       # Routes from specific peer
get bgp neighbor <ip> advertised-routes     # Routes sent to peer
get firewall status                         # Gateway firewall status
get nat rules                               # NAT rules on Edge
```

### ESXi Host CLI (nsxcli)

```bash
# Access NSX CLI on ESXi host
nsxcli

# Transport node status
get transport-node status                   # Overall TEP/tunnel status
get logical-switches                        # Segments on this host

# DFW on host
get firewall rules                          # All DFW rules on this host
get firewall <vm-uuid> ruleset rules        # Rules for specific VM
get firewall status                         # DFW module status

# TEP connectivity
esxcli network ip interface list            # List interfaces including vmk (TEP)
ping ++netstack=vxlan <remote-tep-ip>       # Ping remote TEP using overlay netstack
vmkping -S vxlan <remote-tep-ip> -d -s 8972  # Jumbo ping test for MTU validation
```

## NSX Manager REST API Debugging

### Common API Calls for Troubleshooting

```bash
# Transport node realization state
GET /api/v1/transport-nodes/<id>/state
# Response includes: state (SUCCESS, IN_PROGRESS, FAILED, PARTIAL_SUCCESS)

# Transport node status
GET /api/v1/transport-nodes/<id>/status
# Response includes: control_connection_status, pnic_bond_status

# Segment port status
GET /policy/api/v1/infra/segments/<segment-id>/ports
# Shows all ports (VMs) attached to a segment

# Realized state of a policy object
GET /policy/api/v1/infra/realized-state/status?intent_path=/infra/segments/<segment-id>
# Shows if intent has been realized on all transport nodes

# DFW rule statistics
GET /policy/api/v1/infra/domains/default/security-policies/<policy-id>/rules/<rule-id>/statistics
# Shows hit count, byte count, session count per rule

# Group membership
GET /policy/api/v1/infra/domains/default/groups/<group-id>/members/virtual-machines
# Shows which VMs are currently in a group

# Edge cluster status
GET /api/v1/edge-clusters/<id>/status
# Shows per-Edge-node status within the cluster
```

### API Error Interpretation

| HTTP Code | Meaning | Common Cause |
|---|---|---|
| 400 | Bad Request | Invalid JSON body, missing required field |
| 403 | Forbidden | Insufficient role permissions |
| 404 | Not Found | Object does not exist or wrong API path |
| 409 | Conflict | Object already exists or concurrent modification |
| 412 | Precondition Failed | Revision mismatch (stale object version) |
| 500 | Internal Server Error | Manager cluster issue, check manager logs |
| 503 | Service Unavailable | Manager cluster not ready or losing quorum |

### Revision-Based Concurrency

NSX uses `_revision` field for optimistic concurrency control:
- Every GET returns a `_revision` number
- PUT/PATCH must include the current `_revision`
- If another client modified the object, `_revision` mismatches and API returns 412
- Solution: re-GET the object, merge changes, re-submit with updated `_revision`

## DFW Troubleshooting

### Rule Not Matching

1. **Check Applied-To scope**: Verify the policy or rule is scoped to include the affected VM
2. **Verify group membership**: 
   ```
   GET /policy/api/v1/infra/domains/default/groups/<group-id>/members/virtual-machines
   ```
   Confirm the VM appears in the source/destination group
3. **Check rule statistics**: 
   ```
   Security > Distributed Firewall > [Policy] > [Rule] > Stats icon
   ```
   If hit count is 0, the rule is not matching traffic
4. **Verify VM vNIC is on a segment**: DFW only applies to VMs connected to NSX segments (not VLAN-backed port groups unless configured)
5. **Check rule order**: Higher-priority policies may be matching first. A permit rule above may be allowing traffic before a deny rule is evaluated.

### DFW Rule Debugging on Host

```bash
# SSH to ESXi host, enter nsxcli
nsxcli

# Get VM UUID
get firewall status
# Note the VM UUID from the output

# Get rules applied to specific VM
get firewall <vm-uuid> ruleset rules

# Get connection tracking table for VM
get firewall <vm-uuid> connection-table

# Packet trace (captures DFW decision per packet)
set firewall <vm-uuid> rule <rule-id> packetlog enable
# Check /var/log/dfwpktlogs.log on the ESXi host
```

### DFW Performance Issues

Symptoms: High CPU on ESXi host, latency spikes for VM traffic

Check:
- Rule count per host: `get firewall status` -- look for total rule count
- Connection table utilization: `get firewall connection-table-stats`
- If rule count exceeds 10,000 per host, optimize Applied-To scoping
- If connection table is >80% full, review idle timeouts and session volume

## Overlay Connectivity Troubleshooting

### TEP Connectivity Failure

Symptoms: VMs on different hosts cannot communicate, but same-host VMs work fine

1. **Verify TEP IPs are reachable**:
   ```bash
   # On ESXi host
   ping ++netstack=vxlan <remote-tep-ip>
   ```
2. **Check MTU**:
   ```bash
   vmkping -S vxlan <remote-tep-ip> -d -s 8972
   ```
   If jumbo ping fails but regular ping works, physical switch MTU is too low
3. **Check transport node state**:
   ```
   GET /api/v1/transport-nodes/<id>/state
   ```
   Look for `state: SUCCESS`
4. **Verify VTEP bindings**:
   ```bash
   # On Manager CLI
   get logical-switch <ls-id> vtep
   ```
   Confirm both hosts appear in the VTEP table for the segment
5. **Check physical switch**: Verify VLAN tagging on TEP uplinks, no ACLs blocking UDP 6081 (Geneve)

### Segment Issues

```bash
# Verify segment exists and has correct VNI
get logical-switches

# Check segment port bindings (which VMs are on which segment)
GET /policy/api/v1/infra/segments/<segment-id>/ports

# Verify segment is realized on transport nodes
GET /policy/api/v1/infra/realized-state/status?intent_path=/infra/segments/<segment-id>
```

## Edge BGP Troubleshooting

### BGP Not Establishing

1. **Check T0 uplink interface**:
   ```bash
   # SSH to Edge node
   get interfaces
   ```
   Verify uplink interface is UP with correct IP
2. **Check BGP neighbor state**:
   ```bash
   get bgp neighbor summary
   ```
   Look for state: `Established`. If `Active` or `Connect`, peering is failing.
3. **Verify BGP configuration**:
   ```bash
   get bgp neighbor <ip>
   ```
   Check local AS, remote AS, source IP, hold timer
4. **Check physical router**: Verify matching AS number, neighbor IP, and that BGP is enabled on the correct interface
5. **BFD status** (if enabled):
   ```bash
   get bfd-session
   ```

### Routes Not Advertising

```bash
# Check what routes T0 is advertising to upstream
get bgp neighbor <ip> advertised-routes

# Check route redistribution
get route-redistribution

# Verify T1 subnets are being advertised to T0
get logical-router <t0-id> route-table
```

## NSX Manager Log Locations

| Component | Log Location |
|---|---|
| NSX Manager | `/var/log/proton/nsxapi.log` (API), `/var/log/proton/nsxmp.log` (management plane) |
| Control Plane | `/var/log/cloudnet/nsx-ccp.log` |
| Edge datapath | `/var/log/syslog` on Edge node |
| DFW (ESXi) | `/var/log/dfwpktlogs.log` (packet log), `/var/log/vmware/vsfwd/vsfwd.log` |
| Transport node agent | `/var/log/vmware/nsx/nsx-mpa.log` |

## Troubleshooting Workflow

1. **Identify the traffic path**: Source VM -> DFW -> DR -> Geneve tunnel -> Destination host -> DR -> DFW -> Destination VM
2. **Check DFW**: Is the correct rule matching? Are hit counts incrementing? Is the action correct?
3. **Check routing**: Is the T1 DR routing correctly? Does the T0 have a route to the destination?
4. **Check overlay**: Can TEPs ping each other? Is MTU correct? Is the segment realized?
5. **Check Edge**: Is BGP established? Are routes being advertised/received?
6. **Check physical**: Are physical switch uplinks up? Is VLAN tagging correct? Is MTU 9000+?
