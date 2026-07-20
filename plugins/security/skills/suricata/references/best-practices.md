# Suricata Best Practices Reference

## Rule Writing Guidelines

### Rule Efficiency Principles

1. **Always include a fast pattern content match** -- Rules that rely only on PCRE or non-content keywords cannot use the multi-pattern matcher and evaluate against every packet. Always anchor with a `content` keyword.

2. **Make the fast pattern as specific as possible** -- Longer, more unique content strings reduce false candidate evaluations:
   ```suricata
   # POOR: Short, common string as fast pattern
   alert tcp any any -> any any (content:"GET"; sid:1;)
   
   # BETTER: Specific, longer string
   alert http any any -> any 80 (http.user_agent; content:"Mozilla/5.0 (compatible; EvilScanner/1.0)"; sid:1;)
   ```

3. **Use protocol-specific rules** -- Using `http` as the protocol instead of `tcp` restricts the rule to HTTP traffic only, dramatically reducing evaluation scope:
   ```suricata
   # Evaluated against all TCP traffic
   alert tcp any any -> any 80 (content:"evil.exe"; sid:1;)
   
   # Evaluated only against HTTP-parsed traffic
   alert http any any -> any any (http.uri; content:"/evil.exe"; sid:1;)
   ```

4. **Anchor PCRE with content pre-filter** -- PCRE is expensive. Always precede PCRE with a content match that must be true first:
   ```suricata
   alert http any any -> any any (
       http.uri;
       content:"/api/";         # Fast pattern pre-filter
       pcre:"/\/api\/v[0-9]+\/admin/";  # Only evaluated if "/api/" matched
       sid:1; rev:1;
   )
   ```

5. **Use `flow` direction keywords** -- Restricting by flow direction reduces evaluations:
   ```suricata
   alert http $HOME_NET any -> $EXTERNAL_NET any (
       flow:established,to_server;  # Only outbound established connections
       http.method; content:"POST";
       sid:1; rev:1;
   )
   ```

### Rule Metadata Best Practices

Always include complete metadata for operational management:
```suricata
alert http $HOME_NET any -> $EXTERNAL_NET any (
    msg:"CUSTOM Suspicious PowerShell Download via HTTP";
    flow:established,to_server;
    http.user_agent; content:"PowerShell"; nocase;
    http.uri; content:".ps1";
    classtype:trojan-activity;
    sid:9100001;
    rev:1;
    metadata:
        affected_product Windows,
        attack_target Client_Endpoint,
        created_at 2024_01_15,
        deployment Perimeter,
        performance_impact Low,
        signature_severity Major,
        tag Execution;
)
```

### Writing Detection for Specific Techniques

**C2 beaconing (regular interval connections):**
```suricata
# Detect Cobalt Strike default beacon user-agent
alert http $HOME_NET any -> $EXTERNAL_NET any (
    msg:"CUSTOM Cobalt Strike Default Malleable C2 User-Agent";
    flow:established,to_server;
    http.user_agent; content:"Mozilla/5.0 (compatible|3b| MSIE 9.0|3b| Windows NT 6.1|3b| WOW64|3b| Trident/5.0)";
    classtype:trojan-activity; sid:9100002; rev:1;
)
```

**DNS tunneling:**
```suricata
# Long DNS query (potential tunneling)
alert dns any any -> any any (
    msg:"CUSTOM Potential DNS Tunneling - Long Query";
    dns.query; pcre:"/^[a-zA-Z0-9+\/=]{30,}\./";
    threshold:type limit, track by_src, count 1, seconds 60;
    classtype:bad-unknown; sid:9100003; rev:1;
)
```

**SMB lateral movement:**
```suricata
# Admin share access from workstation to workstation
alert smb $HOME_NET any -> $HOME_NET any (
    msg:"CUSTOM SMB Admin Share Access - Potential Lateral Movement";
    flow:established,to_server;
    smb.named_pipe; content:"svcctl";
    classtype:suspicious-login; sid:9100004; rev:1;
)
```

## Performance Tuning

### Initial Tuning Checklist

After first deployment, before going to full enforcement:

1. **Baseline performance metrics** -- Capture `capture.kernel_drops` and CPU usage at peak traffic
2. **Disable high-noise categories** -- Immediately disable rule categories that generate high volume with low value for your environment
3. **Set HOME_NET correctly** -- Incorrect HOME_NET causes rules to evaluate in wrong direction
4. **Tune stream memory** -- Increase `stream.reassembly.memcap` if seeing `tcp.reassembly_gap` events
5. **Verify NIC queue count** -- Ensure NIC has as many queues as CPU cores assigned to Suricata

### suricata.yaml Performance Configuration

```yaml
# Increase thread count to match NIC queues
threading:
  set-cpu-affinity: yes
  detect-thread-ratio: 1.0

# Flow table sizing (scale with expected concurrent flows)
flow:
  memcap: 268435456    # 256MB for large environments
  hash-size: 131072    # Power of 2; larger = less hash collisions
  prealloc: 50000

# Stream reassembly
stream:
  memcap: 134217728    # 128MB
  reassembly:
    memcap: 536870912  # 512MB for high-throughput
    depth: 1048576     # 1MB -- reduce to 262144 (256KB) if CPU-bound

# Application layer limits
app-layer:
  protocols:
    http:
      memcap: 134217728  # 128MB
      request-body-limit: 102400    # 100KB body inspection limit
      response-body-limit: 102400
      double-decode-path: yes
      double-decode-query: yes

# Detection engine
detect:
  profile: high           # high | medium | low -- affects group-size splitting
  custom-values:
    toclient-groups: 3
    toserver-groups: 25   # More server-directed rules typically
```

### Rule Tuning for Performance

**Profile which rules consume the most CPU:**
```bash
# Enable rule profiling in suricata.yaml
profiling:
  rules:
    enabled: yes
    filename: /var/log/suricata/rule_perf.log
    append: yes
    limit: 100      # Report top 100 rules by CPU time
    sort: avgticks  # Sort by average CPU ticks per evaluation

# After running for 10 minutes, check the output
sort -t',' -k5 -rn /var/log/suricata/rule_perf.log | head -20
```

**Strategies for expensive rules:**
- Add a more specific `content` pre-filter before the expensive keyword
- Convert wide-range PCRE to content + PCRE with anchors
- Apply threshold to limit re-evaluation frequency
- Suppress on known-good sources that frequently trigger evaluation

### NIC and Kernel Tuning

**Increase NIC ring buffer:**
```bash
ethtool -G eth0 rx 4096 tx 4096
```

**Increase kernel socket buffer:**
```bash
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.rmem_default=134217728
echo "net.core.rmem_max=134217728" >> /etc/sysctl.conf
```

**Disable NIC offloading (prevents Suricata from seeing large offloaded frames):**
```bash
ethtool -K eth0 gro off lro off
ethtool -K eth0 rx off tx off
```

**IRQ affinity (assign NIC interrupts to specific CPUs):**
```bash
# Set NIC IRQs to CPUs 0-7 (non-Suricata CPUs)
for i in $(ls /proc/irq/*/eth0 2>/dev/null | cut -d/ -f4); do
    echo "0f" > /proc/irq/$i/smp_affinity  # CPUs 0-3 (hex bitmask)
done
```

## suricata-update Workflow

### Initial Setup

```bash
# Install suricata-update (usually included with Suricata package)
pip3 install suricata-update  # Or apt/yum install

# Fetch list of available rulesets
suricata-update update-sources

# Enable free rulesets
suricata-update enable-source et/open             # Emerging Threats Open (recommended baseline)
suricata-update enable-source oisf/trafficid      # Protocol identification rules
suricata-update enable-source ptresearch/attack-detection  # PT Research attack detection
suricata-update enable-source sslbl/ssl-fp-blacklist  # SSLBL certificate blacklist
suricata-update enable-source abuse.ch/urlhaus    # URLhaus malware URLs
suricata-update enable-source abuse.ch/threatfox-recent  # ThreatFox IOCs

# For ET Pro (paid, contact proofpoint.com)
suricata-update enable-source et/pro --set-setting secret-code YOUR_KEY_HERE

# Initial update
suricata-update
```

### Customization Files

**`/etc/suricata/disable.conf`** -- Rules to never load:
```
# Disable by regex on signature message
re:POLICY Protocols-Prohibited           # Policy rules not relevant to us
re:P2P                                   # P2P detection
re:emerging-games.rules                  # Gaming rules

# Disable entire rule files
group:emerging-trojan-*.rules            # Too noisy; using EDR for this
group:emerging-scan.rules                # Replace with our custom scanning rules

# Disable specific SIDs
sid:2013028                              # FP-prone rule in our environment
sid:2018959                              # Conflicts with legitimate application
```

**`/etc/suricata/enable.conf`** -- Enable disabled-by-default rules:
```
# Enable specific SIDs that are disabled in source ruleset
sid:2402000
group:emerging-info.rules               # Enable info category
```

**`/etc/suricata/modify.conf`** -- Modify existing rules:
```
# Convert high-confidence rules from alert to drop (IPS mode)
2019401 "alert" "drop"
2019402 "alert" "drop"

# Add threshold to noisy rules instead of disabling
2027865 "noalert" "threshold:type limit,track by_src,count 1,seconds 300"

# Modify severity in metadata
2018959 "severity 1" "severity 3"

# Restrict to internal hosts only (reduce noise from external scanners)
2009582 "alert tcp any any" "alert tcp $HOME_NET any"
```

### Automation and CI/CD

```bash
#!/bin/bash
# Cron job: /etc/cron.d/suricata-update
# Run daily at 2am
# 0 2 * * * root /usr/local/bin/suricata-update-cron.sh

set -e
LOG=/var/log/suricata/update.log

echo "[$(date)] Starting suricata-update" >> $LOG
suricata-update >> $LOG 2>&1

echo "[$(date)] Testing new rules" >> $LOG
suricata -T -c /etc/suricata/suricata.yaml >> $LOG 2>&1

echo "[$(date)] Reloading rules" >> $LOG
suricatasc -c ruleset-reload-nonblocking >> $LOG 2>&1

echo "[$(date)] Update complete" >> $LOG
```

## EVE Log Analysis Patterns

### Jq Reference Queries

```bash
# Alert summary: count by signature, last 1000 alerts
jq -r 'select(.event_type=="alert") | .alert.signature' /var/log/suricata/eve.json \
  | sort | uniq -c | sort -rn | head -30

# Top external destinations in alerts
jq -r 'select(.event_type=="alert" and (.dest_ip | startswith("10.") | not)) | .dest_ip' \
  /var/log/suricata/eve.json | sort | uniq -c | sort -rn | head -20

# DNS queries for high-entropy domain names (potential DGA)
jq -r 'select(.event_type=="dns" and .dns.type=="query") | .dns.rrname' \
  /var/log/suricata/eve.json | grep -E '^[a-z0-9]{15,}\.' | sort | uniq -c | sort -rn

# TLS connections without SNI (suspicious)
jq 'select(.event_type=="tls" and (.tls.sni == null or .tls.sni == ""))' \
  /var/log/suricata/eve.json

# File downloads with executable MIME type
jq 'select(.event_type=="fileinfo" and (.fileinfo.mimetype == "application/x-dosexec" or .fileinfo.mimetype == "application/x-msdownload"))' \
  /var/log/suricata/eve.json

# Correlate alert with full flow (using flow_id)
FLOW_ID=1234567890
jq "select(.flow_id == $FLOW_ID)" /var/log/suricata/eve.json

# HTTP connections where response body is large (potential exfil or staging)
jq 'select(.event_type=="http" and .http.length > 10000000)' \
  /var/log/suricata/eve.json
```

### SIEM Integration

**Elastic/Opensearch (via Filebeat):**
```yaml
# filebeat.yml
filebeat.inputs:
  - type: log
    paths:
      - /var/log/suricata/eve.json
    json.keys_under_root: true
    json.add_error_key: true
    fields:
      source: suricata
      environment: production

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  index: "suricata-%{+yyyy.MM.dd}"
```

**Splunk (via Splunk Universal Forwarder):**
```ini
# inputs.conf
[monitor:///var/log/suricata/eve.json]
disabled = false
index = network_security
sourcetype = suricata:json

# props.conf
[suricata:json]
KV_MODE = none
TRUNCATE = 0
TIME_FORMAT = %Y-%m-%dT%H:%M:%S.%6N%z
TIME_PREFIX = "timestamp":"
```

**Kafka (for high-throughput pipelines):**
```yaml
# suricata.yaml direct Kafka output
outputs:
  - eve-log:
      enabled: yes
      filetype: unix_dgram
      filename: /var/run/suricata/eve.socket

# Then use Vector or Logstash to forward from socket to Kafka
```

## threshold.config Reference

### Configuration Location

Default: `/etc/suricata/threshold.config` (or as specified in `suricata.yaml`).

### Configuration Types

```
# LIMIT: Maximum one alert per time window (suppress repeated alerts)
threshold gen_id 1, sig_id 2019401, type limit, track by_src, count 1, seconds 300

# THRESHOLD: Alert after N occurrences within time window
threshold gen_id 1, sig_id 2027250, type threshold, track by_src, count 5, seconds 60

# BOTH: Require N events to trigger, then limit to 1 alert per window  
threshold gen_id 1, sig_id 2008578, type both, track by_src, count 10, seconds 60

# SUPPRESS: Never generate alert for this combination
suppress gen_id 1, sig_id 2019401, track by_src, ip 10.0.0.50
suppress gen_id 1, sig_id 2019401, track by_src, ip 192.168.1.0/24
suppress gen_id 1, sig_id 0, track by_src, ip 10.0.0.1  # All rules from this IP
```

### Operational Workflow

1. **Monitor for high-volume SIDs** -- Any SID generating >100 alerts/hour from a single source is a tuning candidate
2. **Investigate before suppressing** -- Verify the alert is a false positive before suppressing; don't just quiet the noise
3. **Prefer source-specific suppression** over global -- Suppress FP from known scanner IP, not globally
4. **Document all suppression entries** -- Include comment with reason, date, and owner in threshold.config
5. **Review quarterly** -- Remove suppressions for decommissioned systems or fixed FP rules

## Common Operational Procedures

### Health Check

```bash
# Check Suricata process status
systemctl status suricata

# Check for drops in last 60 seconds
suricatasc -c dump-counters | python3 -c "
import sys, json
c = json.load(sys.stdin)
drops = c.get('message', {}).get('capture.kernel_drops', {}).get('value', 0)
print(f'Kernel drops: {drops}')
"

# Verify EVE is actively writing
ls -la /var/log/suricata/eve.json
tail -1 /var/log/suricata/eve.json | python3 -m json.tool | grep timestamp
```

### Rule Reload Without Restart

```bash
# Method 1: suricatasc (preferred)
suricatasc -c ruleset-reload-nonblocking

# Method 2: Signal
kill -USR2 $(pidof suricata)

# Verify reload completed
tail /var/log/suricata/suricata.log | grep -i "rule"
```

### Responding to Alert Volume Spike

```bash
# 1. Identify top SIDs in last 5 minutes
jq -r 'select(.event_type=="alert") | [.timestamp, .alert.signature_id, .alert.signature, .src_ip, .dest_ip] | @csv' \
  /var/log/suricata/eve.json | tail -1000 | cut -d',' -f2 | sort | uniq -c | sort -rn | head -20

# 2. Check if alert is genuine or FP
# Look at actual traffic, not just the alert

# 3. If FP: add suppress entry or update disable.conf + suricata-update

# 4. If genuine: escalate to incident response, consider adding drop rule in IPS mode
```
