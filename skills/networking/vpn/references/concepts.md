# VPN Fundamentals Reference

## IPsec Protocol Suite

### Two Layers of Security Associations
1. **IKE SA** -- Control channel protecting IKE messages. One per peer pair. Established by IKE_SA_INIT + IKE_AUTH.
2. **IPsec SA / Child SA** -- Data plane protecting user traffic using ESP. Multiple Child SAs per IKE SA. Established by IKE_AUTH (first) and CREATE_CHILD_SA (subsequent).

### IKEv2 Exchange (RFC 7296)

**IKE_SA_INIT (messages 1-2):**
- Propose crypto algorithms (encryption, integrity, PRF, DH group)
- DH key exchange (both sides contribute DH material)
- Nonce exchange for randomness
- NAT detection (hash of IP:port detects NAT between peers)
- Result: shared SKEYSEED; derived keys SK_e, SK_a, SK_p

**IKE_AUTH (messages 3-4):**
- Encrypted with IKE SA keys
- Authenticate identities (certificate, PSK, or EAP)
- Establish first Child SA (IPsec SA)
- Exchange: IDi, IDr, AUTH, optional CERT/CERTREQ, SA/TSi/TSr

Total: 4 messages for basic setup.

**CREATE_CHILD_SA:** Create additional Child SAs, rekey existing IKE/Child SAs. Optional DH for PFS.

**INFORMATIONAL:** DELETE, NOTIFY, DPD keepalives.

## ESP (Encapsulating Security Payload) -- Protocol 50

Provides: confidentiality (encryption), authentication, integrity, anti-replay.
- Header: SPI (32-bit) + Sequence Number (32-bit) + Payload + Padding + ICV
- With AES-GCM (AEAD): no separate integrity algorithm needed
- Recommended in all modern deployments

## AH (Authentication Header) -- Protocol 51
- Authentication and integrity only (no encryption)
- Incompatible with NAT (authenticates IP header including addresses)
- Rarely used; ESP with null encryption achieves same integrity without NAT issues

## Tunnel Mode vs Transport Mode

**Tunnel Mode:**
- Entire original IP packet encapsulated as ESP payload
- New outer IP header with gateway addresses
- Use case: site-to-site VPN, remote access

**Transport Mode:**
- Only IP payload protected; original IP header retained
- ESP header between IP header and transport layer
- Use case: host-to-host, GRE+IPsec (DMVPN)

## DH Group Reference

| Group | Algorithm | Key Size | Status |
|---|---|---|---|
| 14 | MODP-2048 | 2048-bit | Acceptable (transition) |
| 19 | ECP-256 (P-256) | 256-bit | CNSA 1.0 minimum |
| 20 | ECP-384 (P-384) | 384-bit | CNSA 1.0/2.0 preferred |
| 21 | ECP-521 (P-521) | 521-bit | Highest classic security |
| 31 | Curve25519 | 256-bit | Widely used; not NSA Suite B |
| mlkem768 | ML-KEM-768 | Post-quantum | CNSA 2.0 transition |
| mlkem1024 | ML-KEM-1024 | Post-quantum | CNSA 2.0 (256-bit PQ) |

## Perfect Forward Secrecy (PFS)

Compromise of long-term keys does not compromise past session keys:
- Phase 1 (IKE SA): DH always performed (inherent forward secrecy)
- Phase 2 (Child SA): PFS optional, disabled by default on many platforms
- With PFS: new DH exchange in every CREATE_CHILD_SA
- Best practice: always enable PFS on Child SAs; DH Group 20+

## NAT Traversal (NAT-T)

- Detected via NAT_DETECTION_SOURCE_IP / NAT_DETECTION_DESTINATION_IP in IKE_SA_INIT
- Both sides switch to UDP/4500
- 4-byte Non-ESP Marker prepended to ESP-in-UDP
- Keepalives (~20s) maintain NAT mappings
- Enable on all configurations even if NAT not currently present

## Dead Peer Detection (DPD)

- Empty INFORMATIONAL request/response for peer liveness
- Modes: on-demand (only when traffic queued), periodic (always), on-idle (FortiGate)
- Action on failure: clear (delete SA), restart (re-initiate), hold (wait)
- Recommendation: enable on all tunnels; 30-60s interval

## Anti-Replay

- Default window: 64 packets (sequence number range)
- High-throughput/asymmetric routing: increase to 512 or 1024
- ESN (Extended Sequence Numbers): for >2^32 packet tunnels

## Lifetime Settings

- IKE SA: 86400s (24h) standard; 28800s (8h) for higher security
- IPsec SA: 3600s (1h) recommended; never below 300s
- Rekeying at ~90% of lifetime (platforms differ)

## Common Failure Modes

### Phase 1 (IKE SA)
- Proposal mismatch (no overlapping crypto)
- Authentication failure (PSK mismatch, cert not trusted, wrong identity)
- Reachability (UDP/500 or UDP/4500 blocked)
- Clock skew (certificate validation >5 min)

### Phase 2 (Child SA)
- PFS mismatch (one side requires, other disables)
- Traffic selector mismatch (subnet disagreement)
- Transform mismatch (ESP proposal mismatch)
- Anti-replay drops (out-of-order packets)

### Certificate Issues
- Must include digitalSignature in Key Usage
- Server: serverAuth EKU; Client: clientAuth EKU
- Expired certificates (NTP sync critical)
- OCSP/CRL check failures

## Reference RFCs

- RFC 7296 -- IKEv2
- RFC 4303 -- ESP
- RFC 3948 -- NAT-T (UDP encapsulation of ESP)
- RFC 9206 -- CNSA Suite for IPsec
- NIST SP 800-77r1 -- Guide to IPsec VPNs
