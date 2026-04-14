# Zeek Architecture Reference

## Core Architecture

Zeek's architecture is built around an event-driven model. Network traffic flows through several processing layers before events are delivered to user scripts:

```
Network Traffic (raw packets via libpcap/AF_PACKET)
       |
       v
[Packet Filter (BPF)]     -- Optional pre-filter at kernel level
       |
       v
[Packet Source]           -- Raw packet ingestion
       |
       v
[Packet Decoder]          -- Layer 2/3/4 protocol decoding
       |
       v
[Timer Manager]           -- Handles connection timeouts, scheduled events
       |
       v
[Protocol Analyzers]      -- Application-layer protocol parsing (DPD)
       |                     Generates protocol-specific events
       v
[Event Engine]            -- Dispatches events to registered handlers
       |
       v
[Script Layer]            -- Zeek scripts execute event handlers
       |
       v
[Logging Framework]       -- Writes structured logs
       |
       v
[Notice Framework]        -- Generates notice.log entries
```

## Event Engine

The event engine is the core of Zeek's processing model:

1. **Event generation** -- Protocol analyzers, the packet decoder, and Zeek scripts generate events
2. **Event queue** -- Events are placed in a queue with associated connection/packet context
3. **Event dispatch** -- The engine processes events sequentially (single-threaded within an event handler)
4. **Handler execution** -- Registered `event` functions are called in priority order

**Event priorities:**
```zeek
# Higher priority = executed first (default priority = 0)
event http_request(c: connection, method: string, original_URI: string,
                   unescaped_URI: string, version: string) &priority=5
{
    # This runs before default priority handlers
}
```

**Event overloading:** Multiple scripts can handle the same event. All handlers are called in priority order. This enables modular script design.

## Dynamic Protocol Detection (DPD)

Zeek identifies protocols dynamically without relying solely on port numbers. DPD works by:

1. A new connection starts; Zeek knows it's TCP/UDP but not the application protocol
2. DPD sends initial packets through signature-based detectors for each protocol
3. When a signature matches, the corresponding protocol analyzer is activated
4. Once the protocol is identified, the analyzer generates protocol-specific events

**Why this matters:** A web server running on port 8888 is detected as HTTP. SSH on a non-standard port is identified as SSH. DPD failures are logged to `dpd.log`.

## Cluster Deployment

For high-throughput environments, Zeek supports a cluster architecture that distributes load across multiple processes.

### Cluster Node Types

**Manager:**
- Central coordination process
- Receives summarized data from workers
- Handles cluster-wide state
- Does NOT process raw traffic
- Typically one per cluster

**Logger:**
- Receives log records from workers and manager
- Writes unified log files to disk
- Handles log rotation
- Typically one or two per cluster (redundancy)

**Proxy:**
- Handles state synchronization between workers
- Workers can communicate cluster-wide state through proxies
- Required for scripts that need cross-worker state (e.g., Scan::, etc.)
- Typically one or two per cluster

**Workers:**
- Process raw network traffic
- Each worker handles a subset of flows
- Most CPU-intensive nodes
- Number of workers = number of CPU cores available for traffic processing

### Cluster Configuration

**`/etc/zeek/node.cfg`:**
```
# Manager
[manager]
type=manager
host=127.0.0.1

# Logger
[logger]
type=logger
host=127.0.0.1

# Proxy
[proxy-1]
type=proxy
host=127.0.0.1

# Workers (one per NIC queue / CPU core)
[worker-1]
type=worker
host=127.0.0.1
interface=eth0
lb_method=pf_ring    # or af_packet
lb_procs=4           # Number of worker threads using this interface

[worker-2]
type=worker
host=127.0.0.1
interface=eth1
lb_method=pf_ring
lb_procs=4
```

**`/etc/zeek/networks.cfg`** -- Networks considered "local":
```
10.0.0.0/8          Private RFC1918
172.16.0.0/12       Private RFC1918
192.168.0.0/16      Private RFC1918
```

**`/etc/zeek/zeekctl.cfg`** -- Cluster-wide settings:
```
LogDir = /var/log/zeek/current
SpoolDir = /var/spool/zeek
LogRotationInterval = 3600
LogExpireInterval = 0
StatsLogEnable = 1
StatsLogExpireInterval = 0
SitePolicyScripts = local.zeek
```

### zeekctl Operations

```bash
# Check cluster status
zeekctl status

# Start all nodes
zeekctl deploy   # = install + start (recommended)
# or
zeekctl start

# Stop cluster
zeekctl stop

# Restart after configuration change
zeekctl deploy

# Check for errors
zeekctl check   # Validate configuration without starting

# View logs for specific node
zeekctl logs

# Cleanup old logs
zeekctl cleanup

# Process a PCAP with cluster config
zeekctl process /path/to/capture.pcap
```

### Load Balancing Methods

**AF_PACKET load balancing:**
```
[worker-1]
type=worker
host=127.0.0.1
interface=eth0
lb_method=af_packet
lb_procs=8              # 8 workers share one interface
af_packet_fanout_id=77  # All workers use same fanout group
af_packet_fanout_mode=FANOUT_HASH  # Flow-based distribution
```

**PF_RING load balancing:**
```
[worker-1]
type=worker
host=127.0.0.1
interface=eth0
lb_method=pf_ring
lb_procs=8
pin_cpus=0,1,2,3,4,5,6,7   # Pin each worker to a CPU
```

**Custom (for hardware load balancers/packet brokers):**
```
[worker-1]
type=worker
host=127.0.0.1
interface=eth0   # TAP feed 1

[worker-2]
type=worker
host=127.0.0.1
interface=eth1   # TAP feed 2
```

## Script Layer Architecture

### Script Loading Order

Zeek loads scripts in this order:
1. Base scripts (shipped with Zeek) -- `${ZEEK_INSTALL}/share/zeek/base/`
2. Package scripts (from zkg) -- `${ZEEK_INSTALL}/share/zeek/site/packages.zeek`
3. Site scripts -- `/etc/zeek/site/local.zeek` (or as configured)

**`local.zeek`** is the primary customization point:
```zeek
# /etc/zeek/site/local.zeek

# Load all default scripts
@load misc/scan
@load misc/detect-traceroute
@load misc/find-checksum-offloading
@load frameworks/software/vulnerable
@load frameworks/software/version-changes
@load frameworks/files/hash-all-files  # Compute SHA1 for all files
@load frameworks/files/detect-MHR     # Hash lookup against Team Cymru Malware Hash Registry
@load protocols/ftp/software
@load protocols/smtp/software
@load protocols/ssh/software
@load protocols/http/detect-webapps

# Load packages (installed by zkg)
@load packages

# Custom site scripts
@load site/custom-detections
@load site/intel

# Tune settings
redef Site::local_nets += { 10.100.0.0/16 };  # Add additional local network
redef LogAscii::use_json = T;                  # Use JSON output format
redef Log::default_rotation_interval = 1hr;   # Rotate logs hourly
```

### Namespacing and Modules

Scripts use the `module` keyword to namespace globals:
```zeek
module MyDetections;

export {
    ## Custom notice type
    redef enum Notice::Type += {
        Suspicious_DNS_Query,
        LargeOutboundTransfer
    };
}

# Handler is in MyDetections namespace
event dns_request(c: connection, msg: dns_msg, query: string, qtype: count, qclass: count)
{
    if ( |query| > 100 ) {
        NOTICE([$note=MyDetections::Suspicious_DNS_Query,
                $msg=fmt("Long DNS query: %s (%d chars)", query, |query|),
                $conn=c]);
    }
}
```

### Notice Framework

The Notice framework generates high-signal events that appear in `notice.log`. More important than raw log entries for alerting:

```zeek
# Generate a notice
NOTICE([$note=Notice::Policy,        # Notice type (required)
        $msg="Suspicious activity",  # Human-readable message
        $conn=c,                     # Associated connection
        $src=c$id$orig_h,           # Source IP
        $dst=c$id$resp_h,           # Destination IP
        $sub="additional context",   # Sub-message
        $identifier=cat(c$id$orig_h, c$id$resp_h)]);  # Dedup key
```

**Notice suppression (deduplication):**
```zeek
# Suppress same notice+identifier for 1 hour
redef Notice::policy += {
    [$pred(n: Notice::Info) = { return n$note == MyDetections::Suspicious_DNS_Query; },
     $action = Notice::ACTION_LOG,
     $suppress_for = 1hr]
};
```

## Log Rotation and Management

**Zeek log rotation:**
- Default: rotate logs every hour
- Creates subdirectories by date: `/var/log/zeek/2024-01-15/`
- Logs are compressed with gzip after rotation
- Old logs can be automatically deleted with `LogExpireInterval`

**Custom rotation commands:**
```zeek
# In zeekctl.cfg
LogRotationInterval = 3600  # Seconds (3600 = 1 hour)
LogExpireInterval = 604800  # Delete logs older than 7 days (0 = never)
```

**Log format: JSON vs TSV:**
```zeek
# local.zeek: switch to JSON output
redef LogAscii::use_json = T;
redef LogAscii::json_timestamps = JSON::TS_ISO8601;
```

JSON output example:
```json
{"ts":"2024-01-15T14:23:45.123456Z","uid":"CXfbCm1ABCDEF123","id.orig_h":"10.1.2.3","id.orig_p":54321,"id.resp_h":"1.2.3.4","id.resp_p":80,"proto":"tcp","service":"http","duration":0.234,"orig_bytes":1234,"resp_bytes":5678,"conn_state":"SF","history":"ShADadfFRR"}
```

## Spicy: Custom Protocol Parsers

Spicy is Zeek's domain-specific language for writing protocol parsers. It generates Zeek analyzers from high-level descriptions of protocol formats.

### Why Spicy

- Write parsers for proprietary or obscure protocols without modifying Zeek source
- Safer than C++ parsers (bounds checking, type safety)
- Generates both parsing logic and Zeek script bindings automatically

### Basic Spicy Parser Example

```spicy
# custom_proto.spicy
module CustomProto;

public type Message = unit {
    header: Header;
    payload: bytes &size=self.header.length;
};

type Header = unit {
    magic: bytes &size=4 {
        if ( $$ != b"CUST" )
            throw "Not a CustomProto packet";
    }
    version: uint8;
    length: uint16;
};
```

```zeek
# custom_proto.evt (event definitions)
import CustomProto;

protocol analyzer CustomProto over TCP:
    parse with CustomProto::Message;

on CustomProto::Message -> event custom_proto_message(
    $conn,
    self.header.version,
    self.payload
);
```

```zeek
# custom_proto.zeek (event handler)
event custom_proto_message(c: connection, version: count, payload: string)
{
    print fmt("CustomProto message: version=%d, payload_len=%d", version, |payload|);
}
```

**Building and loading:**
```bash
# Compile Spicy parser
spicyz -o custom_proto.hlto custom_proto.spicy custom_proto.evt

# Load in zeekctl
# Add to local.zeek:
# @load ./custom_proto.zeek
# And place custom_proto.hlto in Zeek's library path
```

## SIEM Integration

### Elastic Stack (ELK)

**Filebeat configuration for Zeek:**
```yaml
# filebeat.yml
filebeat.inputs:
  - type: log
    paths:
      - /var/log/zeek/current/conn.log
      - /var/log/zeek/current/dns.log
      - /var/log/zeek/current/http.log
      - /var/log/zeek/current/ssl.log
      - /var/log/zeek/current/files.log
    json.keys_under_root: true
    json.add_error_key: true
    fields:
      source: zeek
      environment: production

# Use Zeek module for automatic parsing
filebeat.modules:
  - module: zeek
    connection: { enabled: true }
    dns: { enabled: true }
    http: { enabled: true }
    ssl: { enabled: true }
    files: { enabled: true }
    notice: { enabled: true }
    weird: { enabled: true }
    kerberos: { enabled: true }
    smb: { enabled: true }

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  index: "zeek-%{+yyyy.MM.dd}"
```

### Kafka (High-Volume Pipeline)

```zeek
# local.zeek: stream logs to Kafka
@load packages/kafka

redef Kafka::topic_name = "zeek";
redef Kafka::logs_to_send = set(Conn::LOG, DNS::LOG, HTTP::LOG, SSL::LOG, Files::LOG);
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "kafka-broker:9092",
    ["client.id"] = "zeek-cluster"
);
```

### Splunk (via Cribl or direct)

**Using Cribl Stream:**
- Configure Zeek to output JSON to Unix socket or file
- Cribl Worker reads Zeek JSON logs
- Cribl routes to Splunk HEC with proper sourcetype

**Direct Splunk Universal Forwarder:**
```ini
# inputs.conf
[monitor:///var/log/zeek/current/conn.log]
disabled = false
index = network
sourcetype = zeek:conn

[monitor:///var/log/zeek/current/dns.log]
disabled = false
index = network
sourcetype = zeek:dns
```

## Performance Tuning

### Packet Loss Detection

Check for packet loss:
```bash
# capture_loss.log indicates packet loss
cat /var/log/zeek/current/capture_loss.log | zeek-cut ts percent_lost

# Reporter log shows internal errors
tail /var/log/zeek/current/reporter.log
```

### Performance Optimization Settings

```zeek
# local.zeek performance tuning

# Reduce maximum payload analysis for non-critical protocols
redef HTTP::max_response_body_size = 1024 * 100;   # 100KB max HTTP body
redef HTTP::max_request_body_size = 1024 * 100;

# Disable file extraction for all files (enable only for specific MIME types)
# Do not load frameworks/files/hash-all-files on high-throughput links

# Increase connection table size
redef Connection::max_entries = 5000000;

# Reduce TCP content gap logging (reduce noise on high-loss segments)
redef ignore_checksums = T;   # Skip checksum validation
```

### Memory Tuning

```bash
# Check Zeek memory usage per process
ps aux | grep zeek | awk '{print $6, $11}'

# Zeek per-worker memory is affected by:
# - Number of concurrent flows tracked
# - HTTP/TLS body buffering limits
# - Intelligence framework table sizes
# - Script-level global table sizes
```

## Zeek 6.x Features (Current)

- **Improved cluster communication** -- More efficient inter-node messaging
- **Enhanced Spicy integration** -- More stable and production-ready custom parsers
- **WebSocket support** -- Native WebSocket protocol analysis
- **Improved HTTP/2** -- Better coverage of HTTP/2 protocol features
- **JA4 support** -- JA4 TLS fingerprinting (via package or built-in in newer versions)
- **Improved DNS** -- Better handling of DNS-over-HTTPS detection indicators
- **OpenTelemetry** -- Optional metrics export for observability
