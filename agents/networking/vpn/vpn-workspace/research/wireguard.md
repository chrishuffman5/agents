# WireGuard Deep Dive

## Overview

WireGuard is a modern, high-performance VPN protocol and implementation designed for simplicity and security. Originally written by Jason A. Donenfeld, it was merged into the Linux kernel 5.6 (March 2020). The reference Linux kernel implementation is approximately **4,000 lines of code** — orders of magnitude smaller than OpenVPN (~600K LoC) or IPsec implementations. This small codebase enables meaningful security audits and reduces attack surface.

WireGuard operates at Layer 3, creating virtual network interfaces. It is **stateless** from a connection perspective — there is no "connection" to maintain; peers either have valid session keys or they don't.

---

## Architecture

### Kernel Module vs. User Space

| Implementation | Platform | Notes |
|----------------|----------|-------|
| Linux kernel module | Linux 5.6+ | Native, highest performance |
| wireguard-go | Cross-platform | Go user-space implementation |
| NT kernel driver | Windows | Used in official Windows client |
| Network Extension | macOS/iOS | Used in official Apple clients |
| BoringTun | Cross-platform (Rust) | Cloudflare's user-space implementation |

The kernel implementation achieves near-wire-speed performance for encrypted traffic because encryption/decryption happens in kernel space, avoiding user/kernel context switches.

### Cryptokey Routing

WireGuard's central design concept is **Cryptokey Routing**: the routing table maps public keys to allowed IP ranges. There is **no cipher negotiation** — algorithms are fixed and hardcoded into the protocol. This eliminates an entire class of downgrade and negotiation attacks.

```
Interface: wg0 — private key: <interface_privkey>
  Peer: <pubkey_A> → AllowedIPs: 10.0.0.2/32
  Peer: <pubkey_B> → AllowedIPs: 10.0.0.3/32, 192.168.10.0/24
```

When sending a packet to 10.0.0.2, WireGuard looks up the peer whose AllowedIPs covers that destination, encrypts it with that peer's public key material, and sends it to that peer's endpoint.

When receiving a packet, WireGuard decrypts it and verifies the source IP matches the AllowedIPs for that peer's public key. Packets from unexpected IPs are silently dropped.

---

## Noise Protocol Framework

WireGuard implements the **Noise_IKpsk2_25519_ChaChaPoly_BLAKE2s** handshake pattern from the Noise Protocol Framework (Trevor Perrin, 2016).

**Noise IK Pattern breakdown:**
- `I` — Initiator's static key is sent immediately (known to responder via out-of-band key exchange)
- `K` — Responder's static key is already known to initiator (same reason)
- Result: 1-RTT handshake (one round-trip)

**Pattern provides:**
- **Key-compromise impersonation (KCI) resistance** — Compromising the initiator's static key does not allow impersonating the responder
- **Forward secrecy** — Session keys rotate every few minutes (REKEY_AFTER_TIME = 180 seconds); compromise of current keys does not expose past traffic
- **Identity hiding** — Initiator's static public key is transmitted encrypted, protecting the initiator's identity from passive observers
- **Replay attack resistance** — Timestamp mechanism + counter-based nonces prevent replay

**Builds upon research from:** CurveCP, NaCl, KEA+, SIGMA, FHMQV, HOMQV

---

## Cryptographic Primitives

All primitives are fixed — no negotiation, no algorithm agility:

| Primitive | Algorithm | Purpose |
|-----------|-----------|---------|
| Key exchange | **Curve25519** (X25519 ECDH) | Both static and ephemeral DH operations in handshake |
| Symmetric encryption | **ChaCha20-Poly1305** (RFC 7539 AEAD) | Session data encryption and authentication |
| Hashing | **BLAKE2s** (RFC 7693) | General-purpose hashing, keyed MAC |
| Hash table security | **SipHash24** | Hashtable key to prevent DoS via hash collision |
| Key derivation | **HKDF** (RFC 5869) | Derives multiple keys from DH output |
| MAC fields | **HMAC-BLAKE2s** | `mac1` and `mac2` fields in handshake messages |

**Why these choices:**
- Curve25519 is fast, has a simple implementation, and avoids NIST curve parameter concerns
- ChaCha20-Poly1305 is constant-time (no timing side-channels), faster than AES on devices without AES-NI
- BLAKE2s is faster than SHA-2/SHA-3 while providing equivalent security for its use cases
- Fixed primitives mean no "weakest common denominator" negotiation

### Handshake Cryptographic Flow

**Initiator → Responder (Message 1):**
1. Generate ephemeral keypair `(epriv_i, epub_i)`
2. DH operations: `DH(epriv_i, responder_static_pub)`, `DH(static_i, responder_static_pub)`
3. These DH values are chained into a HKDF-based chaining key (`ck`)
4. Encrypt initiator's static public key under current `ck` context
5. Encrypt timestamp (to prevent replays) under current `ck` context
6. Compute `mac1` using responder's public key (enables DoS protection)
7. Optionally compute `mac2` if responder sent a cookie challenge

**Responder → Initiator (Message 2):**
1. Generate ephemeral keypair `(epriv_r, epub_r)`
2. DH operations: `DH(epriv_r, epub_i)`, `DH(epriv_r, static_i)` 
3. Continue chaining into `ck`
4. Derive final session keys: `send_key`, `recv_key` from final `ck`
5. Zero all ephemeral keys and intermediate values (forward secrecy)
6. Both sides can now send encrypted data

**Data packets:**
- Use ChaCha20-Poly1305 with counter-based nonces (64-bit counter, cannot wrap backward)
- Sliding window ~2,000 prior counter values for out-of-order UDP delivery
- DSCP value 0x88 (AF41) for handshake packets; DSCP 0 for data packets (no info leakage)

### DoS Protection (Cookie Mechanism)

Under load, the responder can avoid processing expensive DH operations:
1. Responder sends encrypted **Cookie Reply** containing a cookie (HMAC of sender's IP)
2. Initiator retries with `mac2` = HMAC(cookie, message) to prove IP ownership
3. Only after validation does responder perform DH operations

---

## Configuration

### Key Generation

```bash
# Generate private key
wg genkey > private.key

# Derive public key from private key
wg pubkey < private.key > public.key

# One-liner
wg genkey | tee private.key | wg pubkey > public.key

# Generate preshared key (PSK) for post-quantum protection
wg genpsk > preshared.key

# View current interface config
wg show wg0

# View all interfaces
wg show
```

**Key properties:**
- Private key: 32 bytes (256-bit), encoded in base64 (44 characters)
- Public key: 32 bytes, derived via Curve25519 `X25519(private, 9)` (base point multiplication)
- PSK: 32 bytes random, adds symmetric layer on top of asymmetric exchange

### Interface Configuration (wg-quick format)

**Server / Hub (`/etc/wireguard/wg0.conf`):**
```ini
[Interface]
Address = 10.0.0.1/24           # VPN interface IP and subnet
ListenPort = 51820               # UDP port to listen on
PrivateKey = <server_private>    # Never share this
MTU = 1420                       # Recommended: 1420 for most cases, 1280 for IPv6 tunnels

# Enable IP forwarding and NAT (server acting as VPN gateway)
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Peer: Road Warrior Client 1
[Peer]
PublicKey = <client1_public>
PresharedKey = <psk_client1>     # Optional: post-quantum layer
AllowedIPs = 10.0.0.2/32        # Only accept traffic claiming to be from this IP

# Peer: Road Warrior Client 2
[Peer]
PublicKey = <client2_public>
AllowedIPs = 10.0.0.3/32

# Peer: Remote Site (site-to-site)
[Peer]
PublicKey = <site2_public>
AllowedIPs = 10.0.0.10/32, 192.168.2.0/24   # VPN IP + remote LAN
Endpoint = 203.0.113.50:51820   # Fixed endpoint for site-to-site
PersistentKeepalive = 25        # Maintain NAT mapping; use only when behind NAT
```

**Client / Road Warrior (`/etc/wireguard/wg0.conf`):**
```ini
[Interface]
Address = 10.0.0.2/32           # Client's VPN IP (/32 for point-to-point)
PrivateKey = <client_private>
DNS = 10.0.0.1, 8.8.8.8         # DNS servers pushed to client (wg-quick resolvconf)
MTU = 1420

[Peer]
PublicKey = <server_public>
PresharedKey = <psk_client1>
Endpoint = vpn.example.com:51820    # Server's public address
AllowedIPs = 0.0.0.0/0, ::/0       # Full tunnel: route all traffic through VPN
# AllowedIPs = 10.0.0.0/24, 192.168.1.0/24  # Split tunnel: only specific subnets
PersistentKeepalive = 25            # Required when behind NAT for keepalive
```

### AllowedIPs Routing Logic

AllowedIPs serves dual purpose:
1. **Outbound:** Cryptokey routing table — determines which peer to encrypt a packet for
2. **Inbound:** Source IP filter — packets from peer are only accepted if source IP is in AllowedIPs

Split tunnel vs. full tunnel:
```
AllowedIPs = 0.0.0.0/0        # Full tunnel — all traffic via VPN (replaces default route)
AllowedIPs = 10.0.0.0/8       # Split tunnel — only RFC 1918 private space
AllowedIPs = 10.0.0.2/32      # Minimal — only the peer's VPN IP
```

### MTU Considerations

WireGuard adds overhead to each packet:
- IPv4 outer header: 20 bytes
- UDP header: 8 bytes  
- WireGuard header: 4 bytes (type) + 4 (reserved) + 8 (counter) = 32 bytes overhead
- Poly1305 authentication tag: 16 bytes
- **Total overhead: ~60 bytes**

MTU calculation:
```
Standard Ethernet MTU: 1500
WireGuard overhead: ~60 bytes
Recommended WireGuard interface MTU: 1420 (standard) or 1280 (safe for IPv6 over IPv4)

# If outer link has smaller MTU (e.g., PPPoE at 1492):
1492 - 60 = 1432 → set MTU = 1432
```

### systemd Integration

```bash
# Enable WireGuard interface at boot
systemctl enable wg-quick@wg0

# Start interface
systemctl start wg-quick@wg0

# Status
systemctl status wg-quick@wg0

# Reload configuration without reconnecting peers
wg syncconf wg0 <(wg-quick strip wg0)
```

For more granular control, use native systemd-networkd with `.netdev` and `.network` files:
```ini
# /etc/systemd/network/99-wg0.netdev
[NetDev]
Name=wg0
Kind=wireguard

[WireGuard]
ListenPort=51820
PrivateKeyFile=/etc/wireguard/private.key

[WireGuardPeer]
PublicKey=<peer_pubkey>
AllowedIPs=10.0.0.2/32
```

---

## Deployment Patterns

### Point-to-Point (Minimal)

```
Host A ←──── WireGuard tunnel ──────→ Host B
10.0.0.1/30                          10.0.0.2/30
```

Each end has the other as a Peer. Endpoint must be set on at least one side. Both can have Endpoint set for bidirectional initiation.

### Hub-and-Spoke (Remote Access / Road Warrior)

```
          Hub: wg0 10.0.0.1/24
         /      |      \
        /       |       \
Client1      Client2    Site2
10.0.0.2    10.0.0.3   10.0.0.10
                        +192.168.2.0/24
```

Hub configuration: one `[Peer]` block per client/spoke. No routing between spokes unless hub is configured to forward traffic. Hub requires `net.ipv4.ip_forward = 1`.

Spoke-to-spoke communication: traffic must route through the hub (hub forwards; add `AllowedIPs` for other spoke IPs). Direct spoke-to-spoke is not possible without hub configuration or additional tooling.

### Site-to-Site with Routing

```
LAN-A: 192.168.1.0/24            LAN-B: 192.168.2.0/24
GW-A: wg0 10.0.0.1/30     ←──→  GW-B: wg0 10.0.0.2/30
```

GW-A peer block for GW-B:
```ini
[Peer]
PublicKey = <gwb_pub>
AllowedIPs = 10.0.0.2/32, 192.168.2.0/24
Endpoint = gwb.example.com:51820
```

GW-B peer block for GW-A:
```ini
[Peer]
PublicKey = <gwa_pub>
AllowedIPs = 10.0.0.1/32, 192.168.1.0/24
Endpoint = gwa.example.com:51820
```

Static routes or dynamic routing (e.g., Bird, FRR/OSPF, BGP) can be run over the WireGuard tunnel interface for more complex topologies.

### Container-Based Deployment

**Docker:**
```bash
# Run WireGuard in Docker container (linuxserver/wireguard image)
docker run -d \
  --name=wireguard \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e PUID=1000 -e PGID=1000 \
  -p 51820:51820/udp \
  -v /opt/wireguard:/config \
  -v /lib/modules:/lib/modules \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  linuxserver/wireguard
```

**Kubernetes:**
- WireGuard used as CNI (Container Network Interface) plugin (e.g., Flannel with WireGuard backend, Calico with WireGuard encryption)
- Calico: `calicoctl patch felixconfiguration default --patch='{"spec": {"wireguardEnabled": true}}'`
- Flannel: Backend type `wireguard` for pod-to-pod encryption across nodes
- Each node gets a WireGuard keypair; control plane distributes keys

---

## Key Management

### Manual Key Exchange
WireGuard has **no built-in key distribution or discovery**. Keys must be exchanged out-of-band:
1. Generate keypair on each peer
2. Exchange public keys securely (email, configuration management, secrets manager)
3. Add each peer's public key to the other's configuration

### PSK (Preshared Key) for Post-Quantum Protection
```bash
wg genpsk > psk.key
# Add to both peers:
PresharedKey = <psk_value>
```
PSK adds a 256-bit symmetric key into the handshake derivation, providing protection against quantum computers breaking Curve25519. This is a **symmetric layer** — even if asymmetric cryptography is broken, an attacker still needs the PSK. Recommended for sensitive deployments now as a hedge against future quantum attacks.

### Key Rotation Strategy
WireGuard does not mandate key rotation — static keypairs can be long-lived. However, best practices:
- **Session key rotation:** Automatic — new session keys every 180 seconds (`REKEY_AFTER_TIME`); provides forward secrecy
- **Identity key rotation:** Manual; recommend periodic rotation (e.g., annually or on security events)
- Rotation process: generate new keypair, distribute new public key to all peers, update configuration, reload interface
- Tools like Ansible, Terraform, or secrets managers (Vault, AWS Secrets Manager) can automate distribution

### Key Timers (Protocol Constants)
| Timer | Default | Description |
|-------|---------|-------------|
| `REKEY_AFTER_TIME` | 180 seconds | Initiate new handshake after this time |
| `REJECT_AFTER_TIME` | 180 seconds | Stop using session keys after this time |
| `REKEY_TIMEOUT` | 5 seconds | Retry handshake after this time with jitter |
| `KEEPALIVE_TIMEOUT` | 10 seconds | Send keepalive if no data received |
| `MAX_TIMER_HANDSHAKES` | 90 retries | Give up after this many handshake attempts |

---

## Advanced Topics

### WireGuard over TCP

WireGuard is **UDP-only** natively. To tunnel over TCP (for firewall bypass):

**udp2raw** (fake TCP):
```bash
# Server side (TCP port 4443 → WireGuard UDP 51820)
udp2raw -s -l 0.0.0.0:4443 -r 127.0.0.1:51820 -k PASSWORD --raw-mode faketcp

# Client side
udp2raw -c -l 0.0.0.0:51820 -r SERVER_IP:4443 -k PASSWORD --raw-mode faketcp
# Then configure WireGuard Endpoint to 127.0.0.1:51820
```

**wstunnel** (WebSocket tunneling):
```bash
# Server: forwards WebSocket → WireGuard UDP
wstunnel server --restrict-to 127.0.0.1:51820 wss://0.0.0.0:443

# Client: WebSocket client → local UDP
wstunnel client -L udp://51820:127.0.0.1:51820?timeout_sec=0 wss://SERVER_IP:443
```

**Use cases:** Restrictive corporate firewalls blocking UDP, countries blocking WireGuard traffic by signature detection, ISPs requiring TCP only.

### Management Platforms

**wg-access-server:**
- Open-source web UI for WireGuard
- Provides user authentication (LDAP/OIDC/SAML), self-service client config download
- Generates QR codes for mobile clients
- GitHub: `freifunkMUC/wg-access-server`

**Firezone:**
- Open-source VPN + network firewall based on WireGuard
- Web UI + REST API; user/group management; per-user access policies
- Supports SSO (OIDC/SAML); split tunneling per user group
- Self-hosted with Docker Compose; commercial cloud version available

**Tailscale:**
- Managed mesh VPN built on WireGuard
- Uses WireGuard in **user space** (wireguard-go / BoringTun) for cross-platform support
- Control plane: Tailscale coordination server handles key distribution, NAT traversal (DERP relay)
- Peer-to-peer direct tunnels where possible; DERP (Detoured Encrypted Routing Protocol) relay over TCP as fallback
- MagicDNS: automatic DNS for nodes; ACL policies via HuJSON
- Performance: slightly lower than kernel WireGuard due to user space, but still much faster than OpenVPN
- License: proprietary (free tier available); 100 devices free

**Headscale:**
- Open-source, self-hosted replacement for Tailscale's coordination server
- Compatible with Tailscale clients (iOS, Android, Windows, macOS, Linux)
- Self-host for full control; suitable for enterprises that cannot use Tailscale's cloud
- GitHub: `juanfont/headscale`

**Netmaker:**
- Open-source WireGuard mesh network orchestrator
- Uses **kernel-space WireGuard** for maximum performance
- Automated mesh network creation; supports full-mesh and hub-and-spoke
- REST API; web dashboard; egress/ingress gateway support
- ACL-based access control; DNS integration
- Performance: ~8 Gbps in benchmarks (kernel WireGuard, near bare-metal speed)

**NetBird (formerly Wiretrustee):**
- Open-source peer-to-peer VPN with zero-config mesh networking
- Automatic NAT traversal (STUN/TURN); SSO integration
- GitHub: `netbirdio/netbird`

---

## Performance

### Benchmarks (representative figures)

| Protocol | Throughput | CPU Usage | Connection Time |
|----------|-----------|-----------|-----------------|
| WireGuard (kernel) | ~940 Mbps–8+ Gbps | Very low (AES-NI equivalent via ChaCha20) | <100ms handshake |
| WireGuard (user space) | ~400–600 Mbps | Low-medium | <100ms handshake |
| OpenVPN (UDP) | ~480 Mbps | Medium-high | ~300ms |
| IPsec/IKEv2 | ~900 Mbps+ | Low (hardware acceleration common) | ~200ms |
| Tailscale (user space WG) | ~300–500 Mbps direct | Medium | ~200ms |

WireGuard's performance advantage:
- **Small kernel code** means tight CPU cache usage
- **ChaCha20-Poly1305** is constant-time; no timing attacks, no AES-NI required
- **Minimal state** — no connection table to maintain
- **Batched operations** — kernel can batch encrypt multiple packets

Handshake timing: WireGuard achieves **under 100ms** for a full 1-RTT handshake from the first packet, after which encrypted data flows immediately.

---

## Limitations

| Limitation | Detail | Workaround |
|-----------|--------|------------|
| **UDP only** | WireGuard sends all traffic over UDP; no TCP support natively | udp2raw, wstunnel, or Tailscale DERP for TCP fallback |
| **Blockable** | UDP traffic identifiable; no built-in obfuscation | wstunnel (WebSocket), domain-fronting |
| **No user authentication** | Key-based only — no username/password | wg-access-server, Firezone, Tailscale (add SSO layer) |
| **No built-in key distribution** | Keys must be exchanged out-of-band manually | Tailscale/Headscale, Netmaker, config management tools |
| **No dynamic IP client support** | `Endpoint` not updated automatically when client IP changes | PersistentKeepalive + `wg set` scripts; Tailscale handles this |
| **No built-in logging** | WireGuard is intentionally silent about traffic | Network monitoring at the OS level |
| **IPv6 in IPv4 MTU** | IPv6 fragmentation can be tricky | Set MTU = 1280 for IPv6 connectivity |
| **No access control** | AllowedIPs is binary — full access to subnet | Pair with firewall rules; use per-user subnets |
| **PSK distribution** | PSKs must also be distributed out-of-band | Same tools as key distribution; automate with secrets managers |

---

## Quick Reference Commands

```bash
# Interface management
wg-quick up wg0                        # Bring up interface from /etc/wireguard/wg0.conf
wg-quick down wg0                      # Tear down interface

# Status and monitoring
wg show                                # All interfaces: peers, endpoints, traffic
wg show wg0                            # Specific interface
wg show wg0 peers                      # List peer public keys
wg show wg0 endpoints                  # Current peer endpoints (including dynamic)
wg show wg0 transfer                   # RX/TX bytes per peer
wg show wg0 latest-handshakes          # Last handshake timestamp per peer

# Live configuration changes (without restarting interface)
wg set wg0 peer <pubkey> endpoint 1.2.3.4:51820  # Update peer endpoint
wg set wg0 peer <pubkey> allowed-ips 10.0.0.2/32
wg set wg0 peer <pubkey> remove        # Remove a peer

# Key operations
wg genkey                              # Generate new private key (to stdout)
wg pubkey                              # Derive public key from private key (stdin → stdout)
wg genpsk                              # Generate preshared key

# Sync config file to running interface (reload without full restart)
wg syncconf wg0 <(wg-quick strip wg0)
```
