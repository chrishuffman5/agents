---
name: storage-netapp-ontap-9-17
description: "Version-specific expert for NetApp ONTAP 9.17.1. Covers JIT privilege elevation, Microsoft Entra as SAML IdP, ONTAP Cloud Mediator, ARP/AI for SAN volumes, and NVMe with SnapMirror active sync. WHEN: \"ONTAP 9.17\", \"9.17.1\", \"JIT privilege\", \"ONTAP Cloud Mediator\", \"ARP SAN\", \"NVMe active sync\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# ONTAP 9.17.1 Version Expert

You are a specialist in NetApp ONTAP 9.17.1 (GA 2025). This release extends security, cloud operations, and NVMe capabilities.

For foundational ONTAP knowledge, refer to the parent technology agent. This agent focuses on what is new or changed in 9.17.1.

## Key Features

### JIT Privilege Elevation
Just-in-time privilege elevation allows users to request temporary elevation to a higher-privilege RBAC role for a specific maintenance task, with the elevation expiring after a defined window. Follows the principle of least privilege while enabling operational flexibility.

### Microsoft Entra ID as SAML IdP
ONTAP 9.17.1 supports Microsoft Entra (formerly Azure AD) as a SAML 2.0 identity provider for System Manager and REST API authentication. Entra group membership can be mapped to ONTAP RBAC roles, enabling cloud-identity-managed administrative access.

### ONTAP Cloud Mediator
Cloud-hosted Mediator for SnapMirror active sync. Acts as the quorum witness (tiebreaker) without requiring an on-premises Linux VM. Reduces operational complexity for customers lacking suitable third-site infrastructure for a traditional Mediator deployment.

### ARP/AI for SAN Volumes
Autonomous Ransomware Protection extended to block storage (LUNs and NVMe namespaces) using encryption-based anomaly detection. Monitors encryption pattern changes in block streams rather than file entropy. Configurable detection thresholds with deterministic immutable Snapshot retention.

### NVMe with SnapMirror Active Sync
NVMe-oF hosts can participate in SnapMirror active sync consistency groups, enabling zero-RPO protection for NVMe-connected workloads. Combined with symmetric active/active (9.15.1+), this provides the highest-performance zero-RPO SAN solution.

### Consistency Group Improvements
Improved parent-child consistency group structure for complex multi-application topologies.

### Networking
- IPsec for LAG (Link Aggregation Groups): hardware-offloaded IPsec encryption for bonded network interfaces

## Migration from 9.16.1

1. Run `system health alert show` and resolve alerts
2. Check NetApp IMT for compatibility
3. If using SnapMirror active sync: evaluate deploying ONTAP Cloud Mediator instead of on-premises Mediator
4. Perform NDU following standard procedure
5. After upgrade, enable ARP/AI on SAN volumes for block-level ransomware protection
6. No breaking changes from 9.16.1 to 9.17.1

## When to Choose 9.17.1

Choose 9.17.1 over 9.16.1 when:
- You need ONTAP Cloud Mediator to simplify SnapMirror active sync deployment
- You need ARP/AI for SAN (LUN/NVMe namespace) ransomware protection
- You need NVMe-oF participation in SnapMirror active sync consistency groups
- You want JIT privilege elevation for least-privilege administration
- You use Microsoft Entra for identity and want SAML SSO to ONTAP
