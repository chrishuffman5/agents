# Suricata Architecture Reference

## Multi-Threaded Design

Suricata is designed from the ground up for multi-core processors. Unlike Snort 2 (single-threaded), Suricata distributes packet processing across multiple threads, with each thread handling a subset of traffic flows.

### Thread Architecture

Suricata uses a pipeline of worker threads:

```
NIC/Capture --> [Receive Thread(s)] --> [Decode Thread] --> [Detect Thread(s)] --> [Output Thread(s)]
```

In practice with AF_PACKET workers mode, each CPU core runs a combined capture+decode+detect loop:

```
CPU Core 0: AF_PACKET Worker --> Decode --> Detect --> EVE Output
CPU Core 1: AF_PACKET Worker --> Decode --> Detect --> EVE Output
CPU Core 2: AF_PACKET Worker --> Decode --> Detect --> EVE Output
...
```

**Flow hashing ensures same-flow packets go to same thread:**
Traffic is distributed using a hash of the 5-tuple (src IP, dst IP, src port, dst port, protocol), ensuring all packets of a single TCP stream are processed by the same thread. This is critical for stream reassembly and stateful protocol inspection.

### Runmodes

Runmodes define how Suricata's internal thread pools are configured:

| Runmode | Description | Use When |
|---|---|---|
| `autofp` | Auto-detect, flow-pinning | Default for most deployments |
| `workers` | Single thread per CPU, combined packet processing | Best performance for AF_PACKET |
| `single` | Single thread for all processing | Development/testing only |

Configure in `suricata.yaml`:
```yaml
threading:
  set-cpu-affinity: yes
  cpu-affinity:
    - management-cpu-set:
        cpu: [ 0 ]
    - receive-cpu-set:
        cpu: [ 0 ]
    - worker-cpu-set:
        cpu: [ "all" ]
        mode: "exclusive"
        prio:
          default: "high"
```

## Capture Layer

### AF_PACKET (Primary Linux Capture Method)

AF_PACKET is the recommended capture method for Linux. It uses Linux kernel ring buffers to pass packets directly to userspace without system call overhead per packet.

**Configuration:**
```yaml
af-packet:
  - interface: eth0
    threads: auto          # Auto-detect based on NIC queues
    cluster-id: 99
    cluster-type: cluster_flow    # Hash-based flow distribution
    defrag: yes
    use-mmap: yes          # Memory-mapped ring buffer
    mmap-locked: yes       # Lock buffer in RAM (prevent swap)
    tpacket-v3: yes        # Use TPACKET_V3 (batch processing, better performance)
    ring-size: 200000      # Number of slots in ring buffer
    block-size: 32768      # Block size in bytes
    buffer-size: 134217728 # Ring buffer size (128MB per thread)
    checksum-checks: no    # Skip checksum validation (TAP copies may have invalid checksums)
```

**AF_PACKET cluster types:**
- `cluster_flow` -- Hash by 5-tuple; all packets of a flow to same thread (required for stream reassembly)
- `cluster_cpu` -- RSS-based distribution; NIC assigns packets to CPU queues
- `cluster_qm` -- Queue-mapped; each NIC queue to dedicated thread

**Increasing NIC queue count (for more threads):**
```bash
# Check current queues
ethtool -l eth0

# Set queues (max varies by NIC)
ethtool -L eth0 combined 16

# RSS hash configuration (ensure flow-based hashing)
ethtool -X eth0 hfunc toeplitz
```

### DPDK (High Performance, 10-100+ Gbps)

DPDK (Data Plane Development Kit) bypasses the kernel entirely. Suricata 7.0+ has integrated DPDK support.

**Requirements:** DPDK-compatible NIC (Intel i40e/ixgbe/ice, Mellanox ConnectX), hugepages configured.

```yaml
dpdk:
  eal-params:
    proc-type: primary

dpdk-interfaces:
  - interface: 0000:03:00.0    # PCI address of DPDK-bound NIC
    threads: 8
    promisc: yes
    multicast: yes
    checksum-checks: no
    copy-mode: none            # Set to "ips" for inline mode
    copy-iface: 0000:03:00.1   # Paired interface for inline
```

**Hugepages setup (required for DPDK):**
```bash
echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
echo "vm.nr_hugepages = 1024" >> /etc/sysctl.conf
```

### PF_RING (Alternative High-Performance Capture)

PF_RING ZC (Zero Copy) provides similar performance to DPDK using kernel module approach. Less common in new deployments now that DPDK is supported natively.

```yaml
pfring:
  - interface: eth0
    threads: 4
    cluster-id: 99
    cluster-type: cluster_flow
```

### NFQ (Netfilter Queue -- IPS Mode)

NFQ intercepts packets via Linux netfilter/iptables before they are forwarded by the kernel. Used for IPS mode where inline AF_PACKET is not available.

**Performance note:** NFQ has higher latency than AF_PACKET inline due to kernel context switches. For high-throughput IPS, prefer AF_PACKET copy-mode.

```yaml
nfq:
  mode: accept             # accept | repeat | route
  batchcount: 20           # Process packets in batches for performance
  fail-open: yes           # If Suricata overwhelmed, accept traffic rather than drop
  queue-maxlen: 10000      # Max packets in kernel queue
```

## Packet Processing Pipeline

### Decode Layer

After capture, packets are decoded through Suricata's codec stack:

1. **Link layer** -- Ethernet, VLAN (802.1Q), 802.1ad QinQ, MPLS, PPPoE
2. **Network layer** -- IPv4, IPv6, IP fragmentation reassembly
3. **Transport layer** -- TCP (stream reassembly), UDP, ICMP
4. **Application layer** -- Protocol detection and deep inspection

**Defragmentation:** Suricata reassembles fragmented IP packets before protocol inspection.

**TCP stream reassembly:** Suricata maintains TCP stream state and reassembles out-of-order segments. This is essential for detecting attacks that split payloads across multiple packets.

### Application Layer Parsers

Suricata includes parsers for 50+ application-layer protocols. Parsers extract structured fields that are available to detection rules via sticky buffers and logged in EVE.

**Protocol parser status:**
```bash
suricata --list-app-layer-protos
```

**Key parsers and their sticky buffers:**

*HTTP/HTTP2:*
- `http.uri`, `http.uri.raw`
- `http.method`
- `http.host`
- `http.user_agent`
- `http.request_body`, `http.response_body`
- `http.header`, `http.cookie`
- `http.status`

*TLS:*
- `tls.sni` -- Server Name Indication
- `tls.cert_subject`, `tls.cert_issuer`
- `tls.cert_serial`
- `ja3.hash`, `ja3.string` -- Client fingerprint
- `ja3s.hash`, `ja3s.string` -- Server fingerprint
- `ja4.hash` -- JA4 fingerprint (8.0+)

*DNS:*
- `dns.query` -- Query name
- `dns.answer` -- Response records

*SMB:*
- `smb.named_pipe`
- `smb.share`

*SSH:*
- `ssh.software` -- Client/server software version
- `ssh.proto` -- Protocol version
- `ssh.hassh` -- Client fingerprint
- `ssh.hassh.server` -- Server fingerprint

### Rule Evaluation

Rules are evaluated against each packet/stream segment after the decode and parse stage:

1. **Fast pattern matching** -- Suricata extracts the "fast pattern" content from each rule and uses a multi-pattern matching algorithm (Aho-Corasick, or hyperscan if compiled in) to quickly identify candidate rules
2. **Rule evaluation** -- Only rules whose fast pattern matched are fully evaluated
3. **Action execution** -- `alert` (log to EVE), `drop` (IPS mode only), `reject` (send TCP RST/ICMP unreachable), `pass` (skip remaining rules)

**Fast pattern selection:**
Suricata automatically selects the best (longest, most unique) content as the fast pattern. Override with `fast_pattern` keyword:
```suricata
alert http any any -> any any (
    msg:"Example";
    content:"short";
    content:"this-is-the-longer-unique-string"; fast_pattern;
    sid:1; rev:1;
)
```

### Rule Loading Pipeline

1. Rules are loaded from files specified in `suricata.yaml` (`rule-files` section)
2. Parsed and validated
3. Group-optimized: rules are grouped by protocol, port, and direction for efficient evaluation
4. Multi-pattern matcher is compiled from all content keywords

**Rule file configuration:**
```yaml
default-rule-path: /var/lib/suricata/rules
rule-files:
  - suricata.rules          # Main rules file (from suricata-update)
  - /etc/suricata/custom.rules  # Custom local rules
```

## EVE JSON Schema

EVE is Suricata's structured logging output. All events are JSON objects with a common envelope:

```json
{
  "timestamp": "ISO8601",
  "flow_id": 123456789,      // Unique flow identifier (correlates related events)
  "in_iface": "eth0",        // Capture interface
  "event_type": "alert|dns|http|tls|flow|fileinfo|anomaly|...",
  "src_ip": "...",
  "src_port": 0,
  "dest_ip": "...",
  "dest_port": 0,
  "proto": "TCP|UDP|ICMP",
  "app_proto": "http|tls|dns|...",  // Detected application protocol
  // Event-type-specific fields follow
}
```

**flow_id is critical for correlation:** All EVE events related to the same network connection share a `flow_id`. Use this to correlate an alert with the DNS lookup that preceded it, the HTTP session, and the file download within the same investigation.

**EVE output destinations:**
```yaml
outputs:
  - eve-log:
      filetype: regular           # Regular file
      filename: /var/log/suricata/eve.json

  - eve-log:
      filetype: syslog            # Syslog (for SIEM direct ingest)
      facility: local5
      level: Info

  - eve-log:
      filetype: redis             # Redis pub/sub (for Logstash/Vector)
      server: 127.0.0.1
      port: 6379
      mode: rpush
      key: suricata

  - eve-log:
      filetype: unix_dgram        # Unix socket
      filename: /var/run/suricata/eve.socket
```

## Memory Architecture

Suricata uses several configurable memory pools to manage resources:

**Host table** (per-host state):
```yaml
host:
  hash-size: 4096
  prealloc: 1000
  memcap: 33554432   # 32MB
```

**Flow engine** (per-flow state):
```yaml
flow:
  memcap: 134217728  # 128MB
  hash-size: 65536
  prealloc: 10000
  emergency-recovery: 30
```

**Stream engine** (TCP reassembly):
```yaml
stream:
  memcap: 67108864   # 64MB
  checksum-validation: yes
  inline: no
  reassembly:
    memcap: 268435456  # 256MB -- largest consumer
    depth: 1048576     # 1MB max reassembly depth
    toserver-chunk-size: 2560
    toclient-chunk-size: 2560
    randomize-chunk-size: yes
```

**App-layer parser memory:**
```yaml
app-layer:
  protocols:
    http:
      memcap: 67108864  # 64MB for HTTP request/response body buffering
```

## Stats and Counters

Suricata outputs periodic stats to `stats.log` (default every 8 seconds):

**Key counters:**
```
capture.kernel_packets      -- Packets seen by kernel
capture.kernel_drops        -- Packets dropped before Suricata (ring buffer full)
decoder.pkts               -- Packets decoded
decoder.bytes              -- Total bytes decoded
detect.alert               -- Total alerts generated
flow.tcp                   -- Active TCP flows
flow.udp                   -- Active UDP flows
tcp.sessions               -- TCP sessions tracked
tcp.reassembly_gap         -- Gaps in TCP stream (packet loss indicator)
dns.memuse                 -- DNS parser memory usage
http.memuse                -- HTTP parser memory usage
```

**Accessing stats live:**
```bash
# Via Unix socket
suricatasc -c dump-counters | python3 -m json.tool

# Live stats stream
suricatasc -c iface-stat eth0
```

## Suricata 8.0 Features

Notable additions in Suricata 8.0:

- **JA4 fingerprinting** -- Improved TLS client fingerprinting replacing JA3 in many use cases
- **DPDK improvements** -- Stable DPDK support, including DPDK inline IPS mode
- **DHCP parser improvements** -- Better DHCP logging in EVE
- **HTTP/2 full support** -- Complete HTTP/2 application layer inspection
- **DNS over HTTPS detection** -- Detection of DoH traffic patterns
- **Rust-based parsers** -- Several parsers rewritten in Rust for memory safety
- **Improved anomaly detection** -- Enhanced protocol anomaly logging
- **Performance improvements** -- Reduced CPU usage for high-throughput deployments
