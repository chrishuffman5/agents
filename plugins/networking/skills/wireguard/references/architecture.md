# WireGuard Architecture Reference

## Noise Protocol Framework

WireGuard implements Noise_IKpsk2_25519_ChaChaPoly_BLAKE2s:
- **IK pattern**: Initiator's static key sent immediately; responder's key pre-known
- 1-RTT handshake (one round-trip)
- Key-compromise impersonation (KCI) resistance
- Forward secrecy (session keys rotate every 180 seconds)
- Identity hiding (initiator's static key encrypted)
- Replay resistance (timestamp + counter nonces)

## Cryptographic Primitives (Fixed, No Negotiation)

| Primitive | Algorithm | Purpose |
|---|---|---|
| Key exchange | Curve25519 (X25519 ECDH) | Static and ephemeral DH |
| Encryption | ChaCha20-Poly1305 (AEAD) | Session data |
| Hashing | BLAKE2s | General hashing, keyed MAC |
| Hash table | SipHash24 | DoS prevention |
| KDF | HKDF | Derive keys from DH output |
| MAC fields | HMAC-BLAKE2s | mac1 and mac2 in handshakes |

## Handshake Flow

**Message 1 (Initiator -> Responder):**
1. Generate ephemeral keypair
2. DH: ephemeral_i x static_r, static_i x static_r
3. Chain into HKDF chaining key (ck)
4. Encrypt initiator's static public key under ck
5. Encrypt timestamp under ck
6. Compute mac1 (DoS protection)

**Message 2 (Responder -> Initiator):**
1. Generate ephemeral keypair
2. DH: ephemeral_r x ephemeral_i, ephemeral_r x static_i
3. Derive final session keys: send_key, recv_key
4. Zero all ephemeral keys (forward secrecy)

**Data packets:** ChaCha20-Poly1305 with 64-bit counter nonces. Sliding window ~2000 for out-of-order UDP delivery.

## DoS Protection (Cookie Mechanism)

Under load, responder avoids expensive DH:
1. Responder sends encrypted Cookie Reply (HMAC of sender IP)
2. Initiator retries with mac2 = HMAC(cookie, message)
3. Only after validation does responder perform DH

## Key Timers

| Timer | Default | Description |
|---|---|---|
| REKEY_AFTER_TIME | 180s | New handshake after this |
| REJECT_AFTER_TIME | 180s | Stop using session keys |
| REKEY_TIMEOUT | 5s | Retry handshake with jitter |
| KEEPALIVE_TIMEOUT | 10s | Keepalive if no data |
| MAX_TIMER_HANDSHAKES | 90 | Give up after this many |

## Implementations

| Implementation | Platform | Performance |
|---|---|---|
| Linux kernel module | Linux 5.6+ | Near-wire-speed (kernel space) |
| wireguard-go | Cross-platform | ~400-600 Mbps |
| NT kernel driver | Windows | Native Windows client |
| Network Extension | macOS/iOS | Apple clients |
| BoringTun | Cross-platform (Rust) | Cloudflare userspace |

## Performance Benchmarks

| Protocol | Throughput | Connection Time |
|---|---|---|
| WireGuard (kernel) | ~940 Mbps - 8+ Gbps | <100ms |
| WireGuard (userspace) | ~400-600 Mbps | <100ms |
| OpenVPN (UDP) | ~480 Mbps | ~300ms |
| IPsec/IKEv2 | ~900 Mbps+ | ~200ms |
| Tailscale (userspace WG) | ~300-500 Mbps | ~200ms |

## Container Deployment

### Docker
```bash
docker run -d --name=wireguard --cap-add=NET_ADMIN --cap-add=SYS_MODULE \
  -p 51820:51820/udp -v /opt/wireguard:/config -v /lib/modules:/lib/modules \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" linuxserver/wireguard
```

### Kubernetes CNI
- **Calico**: `calicoctl patch felixconfiguration default --patch='{"spec":{"wireguardEnabled":true}}'`
- **Flannel**: Backend type `wireguard` for pod-to-pod encryption
- Each node gets WireGuard keypair; control plane distributes keys

## WireGuard over TCP (Firewall Bypass)

### udp2raw (fake TCP)
```bash
# Server: TCP 4443 -> WG UDP 51820
udp2raw -s -l 0.0.0.0:4443 -r 127.0.0.1:51820 -k PASSWORD --raw-mode faketcp
# Client: local UDP 51820 -> server TCP 4443
udp2raw -c -l 0.0.0.0:51820 -r SERVER:4443 -k PASSWORD --raw-mode faketcp
```

### wstunnel (WebSocket)
```bash
# Server
wstunnel server --restrict-to 127.0.0.1:51820 wss://0.0.0.0:443
# Client
wstunnel client -L udp://51820:127.0.0.1:51820?timeout_sec=0 wss://SERVER:443
```

## systemd Integration
```bash
systemctl enable wg-quick@wg0    # Enable at boot
systemctl start wg-quick@wg0     # Start interface
systemctl status wg-quick@wg0    # Check status
```

For granular control, use systemd-networkd .netdev and .network files.
