# IPsec/IKEv2 Architecture Reference

## IKEv2 Exchange Details

### IKE_SA_INIT (Messages 1-2)
- Initiator proposes IKE SA crypto (encryption, integrity, PRF, DH group)
- DH key exchange; nonces exchanged
- NAT detection via hash payloads
- Result: SKEYSEED derived; child keys (SK_e, SK_a, SK_p)

### IKE_AUTH (Messages 3-4)
- Encrypted with IKE SA keys
- Identity authentication (cert, PSK, EAP)
- First Child SA (IPsec SA) established
- Traffic selectors (TSi, TSr) negotiated

### CREATE_CHILD_SA
- Additional Child SAs or rekey existing
- Optional DH for PFS
- Payload: SA proposal, nonces, optional KE

### INFORMATIONAL
- DELETE (teardown), NOTIFY (errors/keepalives)
- DPD: empty request/response for liveness

## ESP Header
```
SPI (32-bit) | Sequence Number (32-bit) | Payload Data | Padding | Next Header | ICV
```
- Protocol 50
- AES-GCM: AEAD (combined encryption + authentication)

## Vendor Configuration Reference

### Cisco IOS-XE (VTI)
```
crypto ikev2 proposal PROP
  encryption aes-cbc-256
  integrity sha384
  group 20

crypto ikev2 keyring KR
  peer SITE2
    address <peer-ip>
    pre-shared-key local <key>
    pre-shared-key remote <key>

crypto ikev2 profile PROF
  match identity remote address <peer-ip>
  authentication remote pre-share
  authentication local pre-share
  keyring local KR
  dpd 30 5 periodic

crypto ipsec transform-set TS esp-aes-gcm-256
  mode tunnel

crypto ipsec profile IPSEC
  set transform-set TS
  set ikev2-profile PROF
  set pfs group20

interface Tunnel1
  ip address 10.255.0.1 255.255.255.252
  tunnel source GigabitEthernet0/0
  tunnel destination <peer-ip>
  tunnel mode ipsec ipv4
  tunnel protection ipsec profile IPSEC
```

### Cisco ASA
```
crypto ikev2 policy 10
  encryption aes-256
  integrity sha384
  group 20
  prf sha384
  lifetime seconds 86400

crypto ikev2 enable outside

crypto ipsec ikev2 ipsec-proposal PROP
  protocol esp encryption aes-256
  protocol esp integrity sha-256

tunnel-group <peer-ip> type ipsec-l2l
tunnel-group <peer-ip> ipsec-attributes
  ikev2 remote-authentication pre-shared-key <key>
  ikev2 local-authentication pre-shared-key <key>

crypto map MAP 10 match address VPN-ACL
crypto map MAP 10 set peer <peer-ip>
crypto map MAP 10 set ikev2 ipsec-proposal PROP
crypto map MAP 10 set pfs group20
crypto map MAP interface outside
```

### PAN-OS
```
# IKE Crypto Profile
set network ike crypto-profiles ike-crypto-profiles IKE-PROF \
  dh-group [group20] encryption [aes-256-gcm] hash [sha384] lifetime seconds 28800

# IKE Gateway
set network ike gateway GW \
  authentication pre-shared-key key <key> \
  protocol ikev2 ike-crypto-profile IKE-PROF \
  protocol-common nat-traversal enable yes \
  local-address interface ethernet1/1 \
  peer-address ip <peer-ip>

# IPsec Crypto Profile
set network ike crypto-profiles ipsec-crypto-profiles IPSEC-PROF \
  esp encryption [aes-256-gcm] dh-group group20 lifetime seconds 3600

# IPsec Tunnel
set network tunnel ipsec TUNNEL \
  auto-key ike-gateway GW \
  auto-key ipsec-crypto-profile IPSEC-PROF \
  tunnel-interface tunnel.1
```

### FortiOS
```
config vpn ipsec phase1-interface
  edit "VPN-SITE2"
    set interface "wan1"
    set ike-version 2
    set proposal aes256gcm-prfsha384
    set dhgrp 20
    set remote-gw <peer-ip>
    set psksecret <key>
    set dpd on-idle
    set dpd-retrycount 3
    set dpd-retryinterval 30
    set nattraversal enable
  next
end

config vpn ipsec phase2-interface
  edit "VPN-SITE2-P2"
    set phase1name "VPN-SITE2"
    set proposal aes256gcm
    set dhgrp 20
    set pfs enable
    set keylifeseconds 3600
  next
end
```

### StrongSwan (swanctl.conf)
```
connections {
  site-to-site {
    version = 2
    proposals = aes256gcm16-prfsha384-ecp384
    rekey_time = 86400s
    dpd_delay = 30s
    remote_addrs = <peer-ip>
    local { auth = psk; id = @site1.example.com }
    remote { auth = psk; id = @site2.example.com }
    children {
      net-net {
        esp_proposals = aes256gcm16-ecp384
        rekey_time = 3600s
        local_ts = 10.1.0.0/24
        remote_ts = 10.2.0.0/24
        start_action = trap
        dpd_action = restart
      }
    }
  }
}
secrets {
  ike-site2 { id = @site2.example.com; secret = "<key>" }
}
```

## Deployment Topologies

### DMVPN (Cisco)
- mGRE + IPsec + NHRP + dynamic routing
- Phase 3: NHRP shortcut routing; direct spoke-to-spoke
- `crypto ikev2 profile` replaces ISAKMP for Phase 3

### ADVPN (Fortinet)
- Hub: `set auto-discovery-sender enable`
- Spoke: `set auto-discovery-receiver enable`
- IKEv2 extensions for spoke-to-spoke shortcut establishment
- ADVPN 2.0 (7.6+): Multiple underlay paths
