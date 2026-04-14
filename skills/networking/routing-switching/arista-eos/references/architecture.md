# Arista EOS Architecture Reference

## Sysdb (System Database)

In-memory centralized key-value store -- the authoritative source of all switch state:
- All agents read/write through Sysdb; publish/subscribe model with automatic notifications
- State survives agent crashes; agent restarts re-read from Sysdb
- Hardware abstraction: ASIC driver reads Sysdb, protocol agents never touch hardware

## Multi-Process Architecture

100+ independent agents (Bgp, Ospf, Isis, Stp, Mlag, Vxlanctl, etc.) as separate Linux processes. ProcMgr monitors health and enforces restart policies.

ISSU: new agent binary staged, old stopped (Sysdb retains state), new starts and resumes. MLAG ISSU: one peer upgrades while other forwards, then swap.

## eAPI (JSON-RPC 2.0)

```
management api http-commands
   protocol https
   no shutdown
```

POST to `https://<switch>/command-api`:
```json
{"jsonrpc":"2.0","method":"runCmds","params":{"version":1,"cmds":["show version"],"format":"json"},"id":"1"}
```

Libraries: pyeapi (Python), curl, NAPALM (eos driver uses eAPI).

## CloudVision (CVP / CVaaS)

Core services: Telemetry (streaming gRPC), Config Management (configlets), Change Control (approval workflows), Studios (intent-based provisioning), Image Management, Compliance.

Studios: L3 Leaf-Spine, Campus, Static Configuration Studio (AVD cv_deploy integration).

API: gRPC-based Resource API with service account token auth.

## gNMI Telemetry

```
management api gnmi
   transport grpc openmgmt
      port 6030
   provider eos-native
```

OpenConfig models: interfaces, bgp, isis, ospfv2, network-instance, platform, lldp, mpls.

Pipeline: EOS --> Telegraf/gNMIc --> InfluxDB/Prometheus --> Grafana, or EOS --> CloudVision directly.

## MLAG Architecture

Two switches present single logical LAG to downstream devices:
- Domain-ID: shared identifier
- Peer-link: port-channel for control and backup data traffic
- Peer-keepalive: L3 heartbeat (management network)
- Virtual MAC: shared MAC for ARP/MAC stability
- MLAG interfaces: port-channels with matching MLAG IDs on both peers

## VXLAN/EVPN Architecture

- VTEP: each leaf (or MLAG pair) is a VTEP
- VNI: 24-bit identifier mapping VLANs to overlay segments
- Symmetric IRB: both ingress/egress VTEPs route; per-VRF L3 VNI
- ARP suppression: Type-2 MAC+IP routes eliminate ARP flooding
- EVPN Multihoming (ESI-LAG): standards-based alternative to MLAG

## EOS SDK

High-performance event-driven API (C++/Python) for custom agents that interact with Sysdb. Agents get notified of state changes and can modify switch state.

## On-Box Linux

Unmodified Linux kernel (AlmaLinux base). Direct bash access, tcpdump, Python 3, standard GNU tools. Custom daemons and containers supported (EOS 4.28+).
