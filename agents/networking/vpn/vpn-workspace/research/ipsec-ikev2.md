# IPsec / IKEv2 Deep Dive

## Overview

IPsec (Internet Protocol Security) is a suite of protocols that provides security at the IP layer. IKEv2 (Internet Key Exchange version 2, RFC 7296) is the key management protocol used to negotiate Security Associations (SAs). Together they form the foundation of most enterprise VPN deployments.

---

## Protocol Architecture

### IKE SA vs. IPsec SA (Child SA)

IPsec uses two layers of Security Associations:

1. **IKE SA** — The control channel. Protects IKE messages themselves. Established by IKE_SA_INIT + IKE_AUTH exchanges. One IKE SA per peer pair.
2. **IPsec SA / Child SA** — The data plane. Protects actual user traffic using ESP or AH. Multiple Child SAs can exist under a single IKE SA. Established by IKE_AUTH (first) and CREATE_CHILD_SA (subsequent).

### IKE Phase 1: IKE SA Establishment

**IKE_SA_INIT Exchange (messages 1 & 2):**
- Initiator proposes IKE SA crypto algorithms (encryption, integrity, PRF, DH group)
- DH (Diffie-Hellman) key exchange — both sides contribute half of the DH material
- Nonces (Ni, Nr) exchanged for randomness
- NAT detection: `NAT_DETECTION_SOURCE_IP` and `NAT_DETECTION_DESTINATION_IP` notify payloads (hashes of IP:port) detect NAT between peers
- Result: shared keying material (`SKEYSEED`) derived; child keys `SK_e` (encryption), `SK_a` (auth/integrity), `SK_p` (PRF) derived per RFC 7296 Section 2.14

**IKE_AUTH Exchange (messages 3 & 4):**
- Messages are encrypted and integrity-protected using IKE SA keys from Phase 1
- Authenticates the identities of both peers (certificate, PSK, or EAP)
- Establishes the **first Child SA** (the initial IPsec SA)
- Exchanges: IDi, IDr (identities), AUTH payload, optional CERT/CERTREQ, SA/TSi/TSr (traffic selectors)
- Result: IKE SA fully established + first Child SA (IPsec SA) up

Total message count for basic site-to-site: **4 messages** (2 for IKE_SA_INIT, 2 for IKE_AUTH).

### IKE Phase 2: Child SA Management

**CREATE_CHILD_SA Exchange:**
- Used to create additional Child SAs (e.g., multiple traffic selectors require separate SAs)
- Used to rekey existing IKE SA or Child SAs (lifetime expiry)
- Optional additional DH exchange provides PFS (Perfect Forward Secrecy)
- Payload: SA proposal, nonces, optional KEi/KEr (new DH keys for PFS)

**INFORMATIONAL Exchange:**
- Used for DELETE (teardown), NOTIFY (errors, keepalives), and configuration payloads
- DPD (Dead Peer Detection) uses empty INFORMATIONAL requests/responses as liveliness checks

---

## ESP vs. AH

### ESP (Encapsulating Security Payload) — Protocol 50
- **Provides:** Confidentiality (encryption), data origin authentication, connectionless integrity, anti-replay, optional traffic flow confidentiality
- **Header structure:** SPI (32-bit) + Sequence Number (32-bit) + Payload Data (variable) + Padding + Next Header + optional ICV (Integrity Check Value)
- **Recommended in all modern deployments** — AH provides no encryption
- With AES-GCM (AEAD): no separate integrity algorithm needed

### AH (Authentication Header) — Protocol 51
- **Provides:** Data origin authentication, connectionless integrity, anti-replay
- **Does NOT provide** confidentiality (no encryption)
- **Problem with NAT:** AH authenticates the IP header including source/destination addresses, which NAT modifies — breaks AH. AH is essentially incompatible with NAT.
- Modern deployments: AH is rarely used; ESP with null encryption achieves same integrity without NAT issues

### Tunnel Mode vs. Transport Mode

**Tunnel Mode:**
- Entire original IP packet (header + payload) is encapsulated as ESP payload
- New outer IP header added with gateway addresses
- **Use case:** Site-to-site VPN between gateways; remote access VPN
- Both gateways' addresses appear in outer header; inner header has private addresses

**Transport Mode:**
- Only the IP payload (TCP/UDP/etc.) is protected; original IP header is retained
- ESP/AH header inserted between original IP header and transport layer
- **Use case:** Host-to-host encryption; must be used with GRE for gateway deployments (GRE+IPsec transport mode)
- Typically used in conjunction with GRE tunnels for DMVPN deployments

---

## Crypto Suites

### IKEv2 Proposal Components

An IKEv2 proposal negotiates four algorithm types:

| Component | Purpose | Recommended | Acceptable | Deprecated |
|-----------|---------|-------------|------------|------------|
| Encryption | Protect IKE messages | AES-256-GCM (AEAD), AES-256-CBC | AES-128-GCM, AES-192-GCM | 3DES, DES, NULL |
| Integrity/PRF | MAC + Key derivation | SHA-384 (PRF_HMAC_SHA2_384), SHA-512 | SHA-256 | MD5, SHA-1 |
| DH Group | Key exchange | Group 20 (P-384), Group 21 (P-521) | Group 19 (P-256), Group 14 (modp2048) | Groups 1-5, 22-24 |
| PRF | Key derivation (explicit with AEAD) | PRF_HMAC_SHA2_384, PRF_HMAC_SHA2_512 | PRF_HMAC_SHA2_256 | PRF_MD5, PRF_SHA1 |

**Note on AEAD (e.g., AES-GCM):** When using AEAD encryption, a separate integrity algorithm MUST NOT be included in the same proposal — instead, an explicit PRF must be specified. AES-GCM provides both encryption and integrity in a single operation.

### IPsec / Child SA Transforms

| Transform Type | Recommended | Notes |
|----------------|-------------|-------|
| Encryption | AES-256-GCM-16, AES-256-CBC | GCM preferred — AEAD, no separate integrity needed |
| Integrity | SHA-256, SHA-384 (with CBC) | Not used with GCM |
| PFS DH Group | Group 20, Group 19 | Must match peer; renegotiated in CREATE_CHILD_SA |
| ESN | ESN (Extended Sequence Numbers) | Required for high-throughput (>2^32 packets) |

### DH Group Reference

| Group | Algorithm | Key Size | NIST/NSA Status |
|-------|-----------|----------|----------------|
| 14 | MODP-2048 | 2048-bit | Acceptable (transition) |
| 19 | ECP-256 (P-256) | 256-bit | CNSA 1.0 minimum |
| 20 | ECP-384 (P-384) | 384-bit | CNSA 1.0/2.0 preferred |
| 21 | ECP-521 (P-521) | 521-bit | Highest classic security |
| 31 | Curve25519 | 256-bit | Not NSA Suite B; widely used |
| mlkem768 | ML-KEM-768 | Post-quantum | CNSA 2.0 transition (strongSwan) |
| mlkem1024 | ML-KEM-1024 | Post-quantum | CNSA 2.0 (256-bit PQ security) |

### Perfect Forward Secrecy (PFS)

PFS ensures that compromise of long-term keys does not compromise past session keys. In IKEv2:
- Phase 1 (IKE SA): DH is always performed — provides inherent forward secrecy for the IKE SA
- Phase 2 (Child SA): PFS is **optional** and disabled by default on many platforms
- With PFS enabled: a new DH exchange is performed in every CREATE_CHILD_SA, resulting in independent session keys
- **Best practice:** Always enable PFS for Child SAs; use DH Group 20 or higher

---

## Vendor Configuration Patterns

### Cisco IOS/IOS-XE

**Modern approach: IKEv2 Profile + VTI (Virtual Tunnel Interface)**

```
! Step 1: IKEv2 Proposal (algorithms)
crypto ikev2 proposal PROPOSAL-1
  encryption aes-cbc-256
  integrity sha384
  group 20

! Step 2: IKEv2 Policy (binds proposal to address)
crypto ikev2 policy POLICY-1
  proposal PROPOSAL-1

! Step 3: IKEv2 Keyring (authentication material)
crypto ikev2 keyring KEYRING-1
  peer PEER-SITE2
    address 203.0.113.2
    pre-shared-key local SECRETKEY123
    pre-shared-key remote SECRETKEY123

! Step 4: IKEv2 Profile (identity + auth)
crypto ikev2 profile IKEv2-PROFILE-1
  match identity remote address 203.0.113.2 255.255.255.255
  authentication remote pre-share
  authentication local pre-share
  keyring local KEYRING-1
  dpd 30 5 periodic

! Step 5: IPsec Transform Set
crypto ipsec transform-set TS-AES256-GCM esp-aes-gcm-256
  mode tunnel

! Step 6: IPsec Profile (for VTI)
crypto ipsec profile IPSEC-PROFILE-1
  set transform-set TS-AES256-GCM
  set ikev2-profile IKEv2-PROFILE-1
  set pfs group20

! Step 7: Tunnel Interface (VTI)
interface Tunnel1
  ip address 10.255.0.1 255.255.255.252
  tunnel source GigabitEthernet0/0
  tunnel destination 203.0.113.2
  tunnel mode ipsec ipv4
  tunnel protection ipsec profile IPSEC-PROFILE-1
```

**Legacy approach: Crypto Map (policy-based)**
```
crypto map CMAP 10 ipsec-isakmp
  set peer 203.0.113.2
  set transform-set TS-AES256-GCM
  set ikev2-profile IKEv2-PROFILE-1
  set pfs group20
  match address ACL-INTERESTING-TRAFFIC

interface GigabitEthernet0/1
  crypto map CMAP
```

**Key difference:** VTI (route-based) is preferred — supports dynamic routing protocols, simpler ACL management, and per-packet QoS. Crypto map (policy-based) uses ACLs to define interesting traffic and is harder to scale.

### Cisco ASA

```
! IKEv2 policy
crypto ikev2 policy 10
  encryption aes-256
  integrity sha384
  group 20
  prf sha384
  lifetime seconds 86400

! IKEv2 enable on interface
crypto ikev2 enable outside

! IPsec proposal
crypto ipsec ikev2 ipsec-proposal PROP-SITE2
  protocol esp encryption aes-256
  protocol esp integrity sha-256

! Tunnel group (connection profile)
tunnel-group 203.0.113.2 type ipsec-l2l
tunnel-group 203.0.113.2 ipsec-attributes
  ikev2 remote-authentication pre-shared-key SECRETKEY123
  ikev2 local-authentication pre-shared-key SECRETKEY123

! Crypto map
crypto map OUTSIDE-MAP 10 match address ACL-VPN
crypto map OUTSIDE-MAP 10 set peer 203.0.113.2
crypto map OUTSIDE-MAP 10 set ikev2 ipsec-proposal PROP-SITE2
crypto map OUTSIDE-MAP 10 set pfs group20
crypto map OUTSIDE-MAP interface outside
```

### Palo Alto Networks (PAN-OS)

Configuration is GUI-driven under Network > IPsec Tunnels, but CLI equivalents:

```
# IKE Crypto Profile (Phase 1)
set network ike crypto-profiles ike-crypto-profiles IKE-PROF-256 \
  dh-group [ group19 group20 ] \
  encryption [ aes-256-gcm aes-256-cbc ] \
  hash [ sha384 sha256 ] \
  lifetime seconds 28800

# IKE Gateway (peer definition)
set network ike gateway IKE-GW-SITE2 \
  authentication pre-shared-key key SECRETKEY123 \
  protocol ikev2 ike-crypto-profile IKE-PROF-256 \
  protocol-common nat-traversal enable yes \
  local-address interface ethernet1/1 \
  peer-address ip 203.0.113.2

# IPsec Crypto Profile (Phase 2)
set network ike crypto-profiles ipsec-crypto-profiles IPSEC-PROF-256 \
  esp encryption [ aes-256-gcm ] \
  esp authentication none \
  dh-group group20 \
  lifetime seconds 3600

# IPsec Tunnel
set network tunnel ipsec IPSEC-SITE2 \
  auto-key ike-gateway IKE-GW-SITE2 \
  auto-key ipsec-crypto-profile IPSEC-PROF-256 \
  tunnel-interface tunnel.1
```

To invoke the IKE Crypto Profile, attach it to the IKE Gateway configuration. The IPsec Tunnel object ties the IKE Gateway and IPsec Crypto Profile together. PAN-OS uses separate **IKE Crypto Profile** (Phase 1 params) and **IPsec Crypto Profile** (Phase 2 params).

### FortiGate (FortiOS)

**GUI:** VPN > IPsec Wizard or VPN > IPsec Tunnels

**CLI (Route-based VPN):**
```
# Phase 1 (IKE SA)
config vpn ipsec phase1-interface
  edit "VPN-SITE2"
    set interface "wan1"
    set ike-version 2
    set keylife 86400
    set peertype any
    set proposal aes256gcm-prfsha384
    set dhgrp 20
    set remote-gw 203.0.113.2
    set psksecret SECRETKEY123
    set dpd on-idle
    set dpd-retrycount 3
    set dpd-retryinterval 30
    set nattraversal enable
  next
end

# Phase 2 (Child SA / IPsec SA)
config vpn ipsec phase2-interface
  edit "VPN-SITE2-P2"
    set phase1name "VPN-SITE2"
    set proposal aes256gcm
    set dhgrp 20
    set pfs enable
    set keylifeseconds 3600
    set src-subnet 10.1.0.0/24
    set dst-subnet 10.2.0.0/24
  next
end

# Tunnel interface
config system interface
  edit "VPN-SITE2"
    set vdom "root"
    set type tunnel
    set ip 10.255.0.1 255.255.255.252
    set allowaccess ping
    set interface "wan1"
  next
end
```

### StrongSwan (Linux/Open Source)

**Modern configuration: swanctl.conf** (replaces legacy ipsec.conf + ipsec.secrets)

```
# /etc/swanctl/swanctl.conf

connections {
  site-to-site {
    # IKE SA parameters (Phase 1)
    version = 2
    proposals = aes256gcm16-prfsha384-ecp384     # AEAD: explicit PRF required
    rekey_time = 86400s
    dpd_delay = 30s
    dpd_timeout = 150s

    remote_addrs = 203.0.113.2

    local {
      auth = psk
      id = @site1.example.com
    }
    remote {
      auth = psk
      id = @site2.example.com
    }

    children {
      net-net {
        # Child SA parameters (Phase 2)
        esp_proposals = aes256gcm16-ecp384        # PFS via DH group 20 equivalent
        rekey_time = 3600s
        local_ts  = 10.1.0.0/24
        remote_ts = 10.2.0.0/24
        start_action = trap                        # auto-initiate on traffic match
        dpd_action = restart
      }
    }
  }
}

secrets {
  ike-site2 {
    id = @site2.example.com
    secret = "SECRETKEY123"
  }
}
```

**Legacy ipsec.conf** (still functional, deprecated in favor of swanctl):
```
conn site-to-site
  keyexchange=ikev2
  ike=aes256gcm16-prfsha384-ecp384!
  esp=aes256gcm16-ecp384!
  left=%defaultroute
  leftsubnet=10.1.0.0/24
  right=203.0.113.2
  rightsubnet=10.2.0.0/24
  authby=secret
  auto=route
  dpdaction=restart
  dpddelay=30s
  dpdtimeout=150s
```

---

## Deployment Topologies

### Site-to-Site (Point-to-Point)
- Two gateways, fixed peer IPs, static routing or BGP over tunnel
- Each end configures the other as a peer with matching proposals
- Route-based (VTI/tunnel interface) preferred over policy-based for operational simplicity

### Hub-and-Spoke
- Central hub with multiple spoke sites
- Hub maintains individual IKE SA and IPsec SAs per spoke
- Routing: static routes or OSPF/BGP over individual tunnel interfaces
- Spoke-to-spoke traffic traverses the hub unless shortcuts are configured
- Scalability limit: large spoke counts increase hub state and rekey load

### DMVPN (Dynamic Multipoint VPN) — Cisco
- **Phase 1:** All traffic via hub; spokes register with NHRP (Next Hop Resolution Protocol)
- **Phase 2:** Spoke-to-spoke shortcuts via NHRP redirect; hub-initiated dynamic tunnels
- **Phase 3:** NHRP shortcut routing; spokes route directly once shortcut is established
- Uses: mGRE (multipoint GRE) tunnels + IPsec protection + NHRP + dynamic routing (EIGRP/OSPF/BGP)
- IKEv2 support: `crypto ikev2 profile` used instead of ISAKMP profile for Phase 3
- Scales to thousands of spokes; hub is only needed for initial contact and route discovery

### ADVPN (Auto Discovery VPN) — Fortinet/Juniper
- Fortinet's equivalent of DMVPN
- Hub informs spokes of better paths via IKEv2 extensions (ADVPN_SUPPORTED notification in IKEv2 Notify payload)
- Spokes establish direct IPsec SAs (shortcut tunnels) without hub involvement after initial discovery
- FortiGate config: `set auto-discovery-sender enable` on hub, `set auto-discovery-receiver enable` on spokes

---

## Troubleshooting

### Common Failure Modes

**Phase 1 (IKE SA) Failures:**
- **Proposal mismatch:** Initiator and responder have no overlapping encryption/integrity/DH proposal. Check both sides have at least one common set.
- **Authentication failure:** PSK mismatch (case-sensitive), certificate not trusted, wrong identity (ID_FQDN vs. IP address)
- **Reachability:** UDP/500 blocked by firewall; UDP/4500 blocked when behind NAT
- **Clock skew:** Certificate validation fails if time differs by >5 minutes (NTP critical)
- **Cookie notification:** Responder sends COOKIE notify under DoS load; initiator must retry with cookie

**Phase 2 (Child SA) Failures:**
- **PFS mismatch:** One side requires PFS (specific DH group), other side sends `PFS = none` — negotiation fails silently or with TS_UNACCEPTABLE
- **Traffic selector mismatch:** Initiator proposes `10.1.0.0/24` but responder expects `10.0.0.0/8`; look for `TS_UNACCEPTABLE` notify
- **Transform mismatch:** Phase 2 proposal (ESP) mismatch after Phase 1 succeeds
- **Anti-replay issues:** Out-of-order packets causing replay window drops in high-throughput/asymmetric routing environments; increase replay window to 1024

**NAT-T Issues:**
- NAT-T detected via `NAT_DETECTION_*` hashes in IKE_SA_INIT; both sides switch to UDP/4500
- Four-byte Non-ESP Marker (0x00000000) prepended to ESP-in-UDP to distinguish from IKE on port 4500
- Keepalives every 20 seconds (strongSwan default) maintain NAT mappings
- Problem: NAT device with aggressive timeout drops mapping; increase NAT keepalive or enable keepalives on peer

**Certificate Issues:**
- Certificate must include `digitalSignature` in Key Usage extension
- Server cert needs `serverAuth` in Extended Key Usage; client needs `clientAuth`
- Certificate expiry: ensure NTP is synchronized; expired certificates cause AUTH_FAILED
- OCSP/CRL: revocation check failures cause connection drops; verify connectivity to CRL distribution point

### Debug Commands by Vendor

**Cisco IOS/IOS-XE:**
```
debug crypto ikev2 protocol          ! IKEv2 message exchange detail
debug crypto ikev2 error             ! Errors only (less verbose)
debug crypto ipsec                   ! IPsec SA negotiation
debug crypto pki transactions        ! Certificate processing

show crypto ikev2 sa                 ! Active IKE SAs
show crypto ikev2 sa detail          ! SA detail including counters
show crypto ipsec sa                 ! Active IPsec SAs, packet counters
show crypto ipsec sa detail          ! Full SA detail
show crypto ikev2 proposal           ! Configured proposals
show crypto ikev2 session            ! Session summary
```

**Cisco ASA:**
```
debug crypto ikev2 protocol 255      ! Full protocol debug
debug crypto ikev2 platform 255      ! Platform events
debug crypto ipsec 255               ! IPsec debug

show crypto ikev2 sa                 ! IKE SAs
show crypto ipsec sa                 ! IPsec SAs
show vpn-sessiondb l2l               ! L2L VPN session summary
```

**FortiGate (FortiOS):**
```
# Filter and enable IKE debug
diagnose vpn ike log filter rem-addr4 203.0.113.2
diagnose debug application ike -1
diagnose debug console timestamp enable
diagnose debug enable

# Tunnel operations
execute vpn ipsec tunnel up <phase2-name>
execute vpn ipsec tunnel down <phase2-name>
diagnose vpn tunnel list              ! Active IPsec tunnels
diagnose vpn ike list                 ! Active IKE SAs
get vpn ipsec tunnel details          ! Tunnel detail

# Traffic sniff (NAT-T)
diagnose sniffer packet any "udp port 4500" 4
diagnose sniffer packet any "udp port 500" 4
```

**Palo Alto Networks:**
```
test vpn ike-sa gateway <gw-name>      ! Test IKE SA
test vpn ipsec-sa tunnel <tunnel-name> ! Test IPsec SA
show vpn ike-sa                        ! IKE SA table
show vpn ipsec-sa                      ! IPsec SA table
show vpn flow                          ! Traffic statistics
debug ike global on debug              ! Enable IKE debug logging (CLI)
```

**StrongSwan:**
```
swanctl --list-sas                    ! Active IKE and Child SAs
swanctl --list-conns                  ! Loaded connections
swanctl --log                         ! Stream log
swanctl --initiate --child net-net    ! Initiate specific child SA
swanctl --terminate --ike site-to-site ! Terminate IKE SA
ipsec statusall                        ! Legacy: full status
journalctl -u strongswan              ! systemd logs
```

---

## Best Practices

### Algorithm Recommendations (2025/2026)

**CNSA 1.0 (Current NSA Commercial Suite — Use Today):**
- IKE Encryption: AES-256-GCM or AES-256-CBC
- IKE/IPsec Integrity: SHA-384
- PRF: PRF_HMAC_SHA2_384
- DH Group: Group 20 (ECP-384/P-384), Group 19 minimum
- IPsec: AES-256-GCM-16 (ESP)

**CNSA 2.0 (Transition by 2033 — Post-Quantum):**
- Key Exchange: ML-KEM-1024 (FIPS 203) — post-quantum KEM
- Hybrid mode during transition: ML-KEM-1024 + ECP-384 (combined)
- Digital Signatures: ML-DSA-87 (FIPS 204)
- Hash/PRF: SHA-384 (still compliant)
- Note: RFC 9206 defines CNSA suite for IPsec; strongSwan 6.x adds ML-KEM support

**Avoid:**
- DH Groups 1, 2, 5, 22, 23, 24 (all weak/broken)
- MD5 or SHA-1 for integrity/PRF
- DES or 3DES encryption
- IKEv1 (ISAKMP) — should be disabled where possible

### Lifetime Settings
- **IKE SA lifetime:** 86400 seconds (24 hours) is standard; 28800 (8 hours) for higher security
- **IPsec SA lifetime:** 3600 seconds (1 hour) recommended; never set below 300s
- **Rekeying:** Occurs at ~90% of lifetime; platforms differ (FortiGate rekeys at 80%)
- **Byte-based rekeying:** Some platforms support byte limits (e.g., 4GB) in addition to time-based

### DPD (Dead Peer Detection)
- Sends empty INFORMATIONAL request/response when idle to verify peer liveness
- **Cisco:** `dpd 30 5 periodic` — sends every 30s, retries 5 times, periodic mode
- **FortiGate:** `set dpd on-idle` — only sends when traffic needs to flow
- **Modes:** `on-demand` (send only when traffic queued), `periodic` (always), `on-idle` (FortiGate)
- Action on failure: `clear` (delete SA), `restart` (re-initiate), `hold` (wait for peer)
- **Recommendation:** Enable DPD on all tunnels; `restart` or clear action; interval 30-60s

### Anti-Replay
- Default replay window: 64 packets (sequence number range)
- For high-throughput or asymmetric routing: increase to 512 or 1024
- Cisco: `crypto ipsec security-association replay window-size 1024`
- FortiGate: `set anti-replay loose` (or `strict`)
- ESN (Extended Sequence Numbers): Enable for >2^32 packet tunnels; requires peer support

### General Recommendations
- Use IKEv2 exclusively; disable IKEv1/ISAKMP where not required
- Route-based VPN (VTI) over policy-based (crypto map) for scalability and dynamic routing
- Enable NAT-T on all configurations even if NAT is not currently present
- Use certificate authentication over PSK for large deployments
- Rotate PSKs periodically; use long (32+ character) random strings
- Enable PFS on all Child SAs (Phase 2); use same DH group as Phase 1 or higher
- Monitor SA lifetimes and rekey events; unexpected rekeying may indicate instability
- Use unique traffic selectors per Child SA to simplify troubleshooting
- Test DPD behavior: simulate peer failure to verify cleanup and re-initiation

---

## Reference RFCs

- RFC 7296 — IKEv2 (current standard, obsoletes RFC 5996)
- RFC 4303 — ESP (Encapsulating Security Payload)
- RFC 4302 — AH (Authentication Header)
- RFC 3948 — UDP Encapsulation of IPsec ESP (NAT-T)
- RFC 9206 — CNSA Suite Cryptography for IPsec
- NIST SP 800-77r1 — Guide to IPsec VPNs
- NSA CNSA 2.0 Advisory (September 2022) — Post-quantum transition guidance
