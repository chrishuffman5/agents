# IPsec/IKEv2 Best Practices Reference

## Algorithm Recommendations

### CNSA 1.0 (Current, Use Today)
- IKE Encryption: AES-256-GCM or AES-256-CBC
- IKE/IPsec Integrity: SHA-384 (with CBC; not with GCM)
- PRF: PRF_HMAC_SHA2_384
- DH Group: Group 20 (ECP-384/P-384) minimum; Group 19 acceptable
- IPsec: AES-256-GCM-16 (ESP)
- PFS: Always enable; DH Group 20

### CNSA 2.0 (Post-Quantum, Transition by 2033)
- Key Exchange: ML-KEM-1024 (FIPS 203) -- hybrid with ECP-384 during transition
- Digital Signatures: ML-DSA-87 (FIPS 204)
- Hash/PRF: SHA-384 (still compliant)
- StrongSwan 6.x adds ML-KEM support

### Deprecated (Do Not Use)
- DH Groups 1-5, 22-24
- MD5, SHA-1 for integrity/PRF
- DES, 3DES encryption
- IKEv1 (ISAKMP)

## AEAD Note
When using AES-GCM (AEAD encryption), do NOT include a separate integrity algorithm in the same IKE proposal. Include an explicit PRF instead. AES-GCM provides both encryption and integrity.

## Lifetime Settings

| SA Type | Recommended | Notes |
|---|---|---|
| IKE SA | 86400s (24h) | 28800s (8h) for higher security |
| IPsec SA | 3600s (1h) | Never below 300s |
| Rekeying | ~90% of lifetime | Platforms differ (FortiGate rekeys at 80%) |
| Byte-based | 4GB (optional) | Some platforms support byte limits |

## DPD (Dead Peer Detection)
- Enable on all tunnels
- Interval: 30-60s
- Action: restart (re-initiate) or clear (delete SA)
- Cisco: `dpd 30 5 periodic`
- FortiGate: `set dpd on-idle`
- Test DPD by simulating peer failure

## Anti-Replay
- Default window: 64 packets
- High-throughput or asymmetric routing: increase to 512 or 1024
- Cisco: `crypto ipsec security-association replay window-size 1024`
- FortiGate: `set anti-replay loose` or `strict`
- ESN for >2^32 packet tunnels

## General Recommendations
1. IKEv2 exclusively; disable IKEv1 where possible
2. Route-based (VTI) over policy-based (crypto map) for scalability and dynamic routing
3. Enable NAT-T even without current NAT
4. Certificate auth over PSK for >10 tunnels
5. Enable PFS on all Child SAs; same or higher DH group as Phase 1
6. Unique traffic selectors per Child SA for simpler troubleshooting
7. Rotate PSKs periodically; 32+ character random strings
8. Monitor SA lifetimes and rekey events

## Interoperability Notes
- Verify proposal overlap between vendors before deployment
- Test with real traffic (not just IKE negotiation) to catch traffic selector issues
- Some vendors default to IKEv1; explicitly configure IKEv2 on both sides
- Cisco uses `group 20` = ECP-384; FortiGate uses `dhgrp 20`; PAN-OS uses `group19/group20`
- PRF handling differs between vendors; some auto-derive PRF from integrity algorithm
