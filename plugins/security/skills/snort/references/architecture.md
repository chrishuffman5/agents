# Snort 3 Architecture Reference

## Design Philosophy

Snort 3 is a complete rewrite of Snort 2, addressing fundamental architectural limitations. The design goals were:

1. **Multi-threading** -- Snort 2 was single-threaded; Snort 3 runs multiple packet processing threads
2. **Modularity** -- Inspectors, codecs, and portscan are pluggable modules with defined APIs
3. **Lua configuration** -- Replace the custom snort.conf language with Lua for programmatic config
4. **Better protocol inspection** -- Separate codec layer from inspector layer; clean pipeline
5. **Application awareness** -- OpenAppID integrated for protocol/application identification
6. **Lua rules** -- Native Lua scripting for rules that cannot be expressed in the rule language

## Core Architecture Components

### Packet Processing Pipeline

```
NIC/DAQ Input
     |
     v
[DAQ Module]      -- Kernel packet capture (AF_PACKET, DPDK, NFQ, PCAP)
     |
     v
[Codec Layer]     -- Protocol decoding (Ethernet > IP > TCP > etc.)
     |
     v
[Stream Engine]   -- TCP/UDP stream tracking and reassembly
     |
     v
[Inspectors]      -- Application layer protocol parsing (HTTP, DNS, TLS, SMB, etc.)
     |
     v
[Detection Engine] -- Rule evaluation against decoded/parsed traffic
     |
     v
[Output Plugins]  -- Alerts (fast, JSON, syslog), logging, pcap
```

### DAQ Layer (Data Acquisition)

The DAQ layer abstracts packet capture from the detection engine. This allows Snort 3 to run on different capture mechanisms without changing core code.

**Available DAQ modules:**
| Module | Use Case | Mode Support |
|---|---|---|
| `afpacket` | Linux high-performance capture | passive, inline |
| `pcap` | Standard libpcap (testing, low throughput) | passive, read-file |
| `nfq` | Linux netfilter queue (iptables integration) | inline |
| `dpdk` | DPDK for 10-100+ Gbps | passive, inline |
| `fst` | File-based offline analysis | read-file |
| `gwlb` | AWS Gateway Load Balancer (cloud IPS) | inline |

**DAQ configuration in Lua:**
```lua
daq = {
    module_dirs = { '/usr/lib/daq', '/usr/local/lib/daq' },
    modules = {
        {
            name = 'afpacket',
            mode = 'passive',
            variables = {
                fanout_type = 'hash',  -- Flow-based distribution across threads
                fanout_flag = '',
                use_tx_ring = 'yes'
            }
        }
    },
    inputs = { 'eth0' },
    snaplen = 65535,
    timeout = 1000    -- Milliseconds
}
```

**Inline AF_PACKET (bump-in-wire):**
```lua
daq = {
    modules = {
        {
            name = 'afpacket',
            mode = 'inline'
        }
    },
    inputs = { 'eth0:eth1' }  -- Colon syntax specifies inline pair
}
```

### Codec Layer

Codecs decode packets at each protocol layer. The codec layer is separate from application inspection, enabling clean separation of concerns and extensibility.

**Built-in codecs:**
- Ethernet, 802.1Q VLAN, QinQ (802.1ad), MPLS, PPPoE
- IPv4, IPv6, IPv6 extension headers, IP fragmentation
- TCP, UDP, ICMP, ICMPv6
- GRE, VXLAN, GENEVE (tunnel codecs)
- ARP

**Codec interaction with inspectors:**
After the codec stack decodes each layer, the packet with all layer pointers is passed to the stream engine and then to inspectors. Inspectors only see reassembled, normalized data -- not raw packets.

### Stream Engine

Manages stateful tracking of TCP and UDP "sessions" (flows). Critical for application-layer inspection:

- **TCP reassembly** -- Reassembles out-of-order TCP segments into ordered stream
- **TCP normalization** -- Normalizes anomalous TCP behavior (overlapping segments, bad timestamps)
- **UDP tracking** -- Groups UDP packets into "sessions" by 5-tuple for stateful inspection
- **Session timeout** -- Aged-out sessions are flushed and freed

```lua
stream = {
    ip_frags_only = false,
    max_flows = 2000000      -- Maximum concurrent flows (scale with RAM)
}

stream_tcp = {
    policy = 'windows',       -- OS policy for TCP normalization
    session_timeout = 180,
    max_pdu = 16384,
    reassemble_async = true,
    ignore_any_rules = false
}

-- TCP policy options:
-- 'bsd', 'linux', 'macos', 'solaris', 'irix', 'hpux', 'windows', 'vista', 'first', 'last'
```

### Inspectors (Replacing Preprocessors)

Inspectors are Snort 3's replacement for Snort 2's preprocessors. They parse application-layer protocols and extract fields for rule matching.

**Inspector types:**
1. **Network inspectors** -- Operate on decoded packets (scan detection, IP defrag)
2. **Service inspectors** -- Operate on identified application protocols (http_inspect, dns, etc.)
3. **Passive inspectors** -- Observe traffic without modifying it (appid)

**Key inspectors:**

*http_inspect (HTTP/1.x and HTTP/2):*
```lua
http_inspect = {
    request_depth = 1460,       -- Max bytes of request body to inspect
    response_depth = 65535,     -- Max bytes of response body
    normalize_utf = true,
    decompress_pdf = false,
    decompress_swf = false,
    script_detection = false,
    max_header_line_length = 0,
    max_headers = 200,
    max_uri_length = 2048
}
```

*DNS inspector:*
```lua
dns = {
    max_rdata_len = 255,
    enable_rdata_overflow = false
}
```

*TLS/SSL inspector:*
```lua
ssl = {
    max_heartbeat_length = 0,   -- 0 = unlimited
    trust_servers = false        -- Don't trust server-side certificates by default
}
```

*Appid (OpenAppID):*
```lua
appid = {
    app_detector_dir = '/usr/lib/snort/appid',
    app_stats_filename = '/var/log/snort/appid-stats.log',
    log_stats = false,
    list_odp_detectors = false
}
```

*Binder (maps protocols to inspectors by port/service):*
```lua
binder = {
    { when = { proto = 'tcp', ports = '80 8080 8000 8008' }, use = { type = 'http_inspect' } },
    { when = { proto = 'tcp', ports = '443' }, use = { type = 'ssl' } },
    { when = { proto = 'tcp', ports = '53' }, use = { type = 'dns' } },
    { when = { proto = 'udp', ports = '53' }, use = { type = 'dns' } },
    { when = { proto = 'tcp', ports = '25 587 465' }, use = { type = 'smtp' } },
    { when = { proto = 'tcp', ports = '22' }, use = { type = 'ssh' } },
    { when = { service = 'http' }, use = { type = 'http_inspect' } },   -- Service-based binding
}
```

### OpenAppID Engine

OpenAppID provides application identification beyond port-based protocol detection. It identifies applications using behavioral fingerprinting, traffic patterns, and protocol signatures.

**Architecture:**
- **ODP (Open Detection Packages)** -- Lua scripts that define detection patterns per application
- **AppID Framework** -- Engine that runs ODP scripts against traffic
- **Integration with Inspectors** -- Identified service activates the appropriate inspector

**Detection methods:**
1. **Port-based** -- Initial detection by port (80 = HTTP candidate)
2. **Protocol detection** -- HTTP inspector confirms it's actually HTTP
3. **Pattern matching** -- ODP scripts match application-specific patterns (headers, handshakes)
4. **Service confirmation** -- AppID finalizes the application identity

**App detector structure (ODP Lua script):**
```lua
-- Example: simplified detector for a custom app
AppIdDetector = {}

function AppIdDetector:init()
    -- Declare patterns this detector uses
    self.ptype = DC.prototype.HTTP
    self.pname = "MyCustomApp"
    self.appid = 10001  -- Must be unique ID
    
    -- HTTP patterns to match
    self:addHttpPattern(DC.HTTP.HTTP_HEADER_CONTENT_TYPE, 
                        "application/x-mycustomapp")
end

function AppIdDetector:getPacketSize()
    return 1000  -- Inspect first 1000 bytes
end

function AppIdDetector:validate(pkt, context)
    -- Custom Lua detection logic
    local header = pkt:getHttpHeader("User-Agent")
    if header and header:find("MyCustomApp/") then
        self:addApp(DC.ipProtocol.TCP, DC.prototype.HTTP, self.appid, self.appid)
        return DC.confidence.HIGHEST
    end
    return DC.confidence.NONE
end
```

### Lua Scripting in Rules

Snort 3 supports Lua scripts embedded in rules for detection logic that cannot be expressed in the rule DSL:

**Lua detection function:**
```lua
-- /etc/snort/lua/detect_custom.lua
function init(args)
    -- Called once per rule initialization
    local required_args = { "threshold" }
    for _, arg in ipairs(required_args) do
        if not args[arg] then
            return "Missing argument: " .. arg
        end
    end
    return nil  -- no error
end

function eval(pkt, args)
    local threshold = tonumber(args.threshold) or 100
    local payload = pkt:get_payload()
    
    if not payload then
        return false
    end
    
    -- Example: detect if payload contains more than threshold repeated characters
    local max_run = 0
    local current_run = 1
    local prev_char = nil
    
    for i = 1, #payload do
        local char = payload:sub(i, i)
        if char == prev_char then
            current_run = current_run + 1
            if current_run > max_run then
                max_run = current_run
            end
        else
            current_run = 1
        end
        prev_char = char
    end
    
    return max_run >= threshold
end
```

**Rule using Lua:**
```
alert tcp any any -> any any (
    msg:"Custom Lua Detection - Repeated Character Sequence";
    luajit:/etc/snort/lua/detect_custom.lua,init,eval,threshold=50;
    sid:1000100; rev:1;
)
```

## Detection Engine

### Multi-Pattern Matching

Snort 3 uses a multi-pattern matching algorithm to efficiently evaluate thousands of rules:

1. **Content extraction** -- From each rule, the "fast pattern" content is extracted
2. **Aho-Corasick or Hyperscan** -- All fast patterns are compiled into a single state machine
3. **Packet scan** -- Single pass through packet/stream data finds all matching patterns
4. **Rule candidates** -- Only rules whose pattern matched are fully evaluated
5. **Rule evaluation** -- Full rule option chain is evaluated for candidate rules

**Hyperscan vs. Aho-Corasick:**
- Hyperscan (Intel) -- SIMD-accelerated; 2-5x faster than Aho-Corasick for large rulesets
- Aho-Corasick -- Software-only; available everywhere; good performance for smaller rulesets
- Enable hyperscan: `detection = { hyperscan_literals = true }`
- Verify with: `snort --version` (shows `Hyperscan version X.X`)

### Rule Groups

Snort 3 organizes rules into groups for efficient evaluation. Rules are grouped by:
- Protocol (tcp, udp, icmp, http, dns, etc.)
- Direction (to_server, to_client, both)
- Port (specific port groups)
- Service (OpenAppID-identified application)

This means rules for `http` protocol are never evaluated against DNS traffic, dramatically reducing evaluation scope.

## Snort 2 to Snort 3 Migration

### Configuration Migration

**Snort 2 snort.conf equivalents in Snort 3:**

| Snort 2 (snort.conf) | Snort 3 (snort.lua) |
|---|---|
| `var HOME_NET 10.0.0.0/8` | `HOME_NET = '10.0.0.0/8'` |
| `preprocessor stream5_global:` | `stream = { ... }` |
| `preprocessor http_inspect:` | `http_inspect = { ... }` |
| `preprocessor dns:` | `dns = { ... }` |
| `preprocessor sfportscan:` | `port_scan = { ... }` |
| `preprocessor ftp_telnet:` | `ftp_server = { ... }` |
| `output unified2:` | `unified2 = { ... }` (or use alert_json) |
| `include rules/local.rules` | `ips = { rules = 'include local.rules' }` |

**Automated migration tool:**
Cisco provides `snort2lua` to convert snort.conf files to snort.lua format:
```bash
snort2lua -c /etc/snort/snort.conf -r /etc/snort/rules/ -o snort.lua

# Review the output and warnings
# Some preprocessor configs require manual adjustment
```

### Rule Migration

Most Snort 2 rules are compatible with Snort 3 but some syntax changes are required:

**Changed syntax:**
```
# Snort 2: flags:S+
alert tcp any any -> any any (flags:S+; sid:1;)

# Snort 3: flags:S (the + modifier was removed)
alert tcp any any -> any any (flags:S; sid:1;)
```

**Deprecated keywords removed from Snort 3:**
- `resp` (active response) -- Use `react` inspector instead
- `tag` (packet tagging) -- Removed
- `threshold` in rule body -- Use suppression configuration
- `detection_filter` -- Use rate filter

**Testing rule compatibility:**
```bash
# Load rules in test mode to find syntax errors
snort -c snort.lua -T --rule-path /etc/snort/rules/ 2>&1 | grep -E "ERROR|WARNING"
```

### Output Migration

Snort 2 unified2 binary format is still supported but deprecated:
```lua
-- Unified2 (backward compatible with Barnyard2)
unified2 = {
    filename = '/var/log/snort/snort.u2',
    limit = 128
}

-- Preferred Snort 3 JSON output
alert_json = {
    file = true,
    limit = 100,
    fields = 'timestamp action msg pkt_num proto src_ap dst_ap sid'
}
```

## Performance Tuning

### Multi-Threading Configuration

```lua
-- Configure thread count
-- threads = number of packet processing threads
-- Default: auto (one per CPU core)
snort = {
    -- Most threading settings are CLI flags:
    -- --max-pkt-threads N
}
```

**CLI thread options:**
```bash
# Set number of packet threads
snort -c snort.lua -i eth0 --max-pkt-threads 8

# Bind threads to CPUs
snort -c snort.lua -i eth0 --max-pkt-threads 8 --thread-affinity 0:0,1:1,2:2,3:3
```

### Performance Monitoring

```lua
perf_monitor = {
    modules = {
        base = {
            perf_flags = 0x3f,   -- Enable all base stats
            pkt_cnt = 10000
        },
        flow = {
            max_port_to_track = 1024
        }
    },
    format = 'csv',              -- 'text' or 'csv'
    output = 'file',             -- 'stdout' or 'file'
    filename = '/var/log/snort/perf.csv'
}
```

**Key metrics to monitor:**
- `Total packets` vs `Total dropped` -- Packet loss indicator
- `Total sessions` -- Active flow count
- `Pkts/Sec` -- Throughput
- `Mbits/Sec` -- Bandwidth processed
- `CPU (usr/sys)` -- CPU utilization per thread
