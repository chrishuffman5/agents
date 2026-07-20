# Cisco Wireless Diagnostics Reference

## Radioactive Tracing

Radioactive Tracing (RA Trace) provides detailed per-client event logging without enabling broad debug that impacts all clients. It is the primary troubleshooting tool for C9800.

### Enabling via WLC GUI
```
Troubleshooting → Radioactive Trace
  → Add client MAC address
  → Start trace
  → Reproduce the issue
  → Stop trace → Generate log → Download
```

### Enabling via CLI
```
! Enable trace for a specific client MAC
debug wireless mac <client-mac-address>

! Optional: set monitoring time (default: no time limit)
debug wireless mac <client-mac-address> monitor-time 300

! Reproduce the issue, then collect:
show logging process wncd internal filter mac <client-mac-address>

! Or collect from flash:
dir bootflash:ra_trace/
more bootflash:ra_trace/ra_trace_MAC_<mac>_<timestamp>.log

! Disable trace when done
no debug wireless mac <client-mac-address>
```

### Reading RA Trace Output
Key events to look for in the trace log:
- `[client-orch-sm]` -- Client state machine transitions (authenticate, associate, run)
- `[dot11]` -- 802.11 association/authentication events
- `[dot1x]` -- 802.1X/EAP authentication events
- `[aaa]` -- RADIUS request/response events
- `[dhcp]` -- DHCP discovery/offer/request/ACK
- `[mobility]` -- Roaming events (L2 roam, L3 roam, anchor/foreign)
- `[policy]` -- Policy profile application, VLAN assignment, ACL
- `[webauth]` -- CWA/LWA web authentication events

### Common Trace Patterns

**Successful client join:**
```
dot11 -> association request
dot1x -> EAP identity request sent
dot1x -> EAP method negotiation (PEAP/TLS)
aaa -> RADIUS Access-Request sent
aaa -> RADIUS Access-Accept received
dot1x -> 4-way handshake complete
client-orch-sm -> state: RUN
dhcp -> DHCP DISCOVER/OFFER/REQUEST/ACK
```

**Authentication failure:**
```
aaa -> RADIUS Access-Reject received
dot1x -> EAP failure sent to client
client-orch-sm -> state: DELETE
```

**Roaming failure:**
```
mobility -> reassociation from old AP
dot11 -> reassociation request
[error] -> FT (Fast Transition) key mismatch OR PMK cache miss
client-orch-sm -> state: DELETE (client disconnected)
```

## Essential Show Commands

### AP Management
```
! List all APs and their state
show ap summary

! Detailed AP information
show ap name <ap-name> config general
show ap name <ap-name> config slot 0
show ap name <ap-name> config slot 1

! AP join statistics
show wireless stats ap join summary

! AP image status
show ap image

! AP uptime and last reboot
show ap uptime
```

### Client Monitoring
```
! All connected clients
show wireless client summary

! Detailed client information
show wireless client mac-address <mac> detail

! Client statistics (data rates, RSSI, SNR)
show wireless client mac-address <mac> stats

! Client deletion reasons (why clients disconnected)
show wireless stats client delete reason

! Client count by WLAN
show wlan summary
```

### RF and Radio Monitoring
```
! 5 GHz radio summary (channel, power, clients per AP)
show ap dot11 5ghz summary

! 2.4 GHz radio summary
show ap dot11 24ghz summary

! 6 GHz radio summary
show ap dot11 6ghz summary

! RRM channel assignment
show ap dot11 5ghz channel

! RRM transmit power
show ap dot11 5ghz power

! CleanAir interference
show ap dot11 5ghz cleanair air-quality summary

! Noise and interference per AP
show ap name <ap-name> dot11 5ghz cleanair device type all
```

### WLAN and Policy
```
! WLAN configuration summary
show wlan summary

! Detailed WLAN configuration
show wlan name <wlan-name>

! Policy profile details
show wireless profile policy detailed <policy-name>

! Tag assignments
show ap tag summary
show ap name <ap-name> tag
```

### WLC Health
```
! CPU and memory utilization
show processes cpu sorted
show platform software status control-processor brief

! CAPWAP tunnel statistics
show capwap client rcb

! WLC HA status
show redundancy
show wireless management trustpoint

! Data plane utilization
show platform hardware throughput level
```

## AP Join Troubleshooting

When APs fail to join the WLC:

### Discovery Phase Issues
```
! Check DHCP option 43 configuration on DHCP server
! Check DNS resolution: CISCO-CAPWAP-CONTROLLER.localdomain
! Verify AP and WLC are in same L2 domain (broadcast discovery) or L3 reachable

! On WLC, check for AP join attempts:
show wireless stats ap discovery
show wireless stats ap join summary
```

### Certificate Issues
```
! Verify WLC management trustpoint
show wireless management trustpoint

! Check AP certificate validity
! APs manufactured before certain dates may have expired MICs (Manufacturing Installed Certificates)
! Solution: Install device certificate via CLI or use LSC (Locally Significant Certificate)
```

### Image Mismatch
```
! Check if AP is downloading image after join
show ap image

! AP will download matching image from WLC automatically
! If download fails, verify:
!   - Adequate flash space on AP
!   - Image pre-download completed successfully
!   - Network path between AP and WLC allows large file transfer
```

### Common AP Join Failures
| Symptom | Likely Cause | Fix |
|---|---|---|
| AP not discovered | DHCP option 43 missing or DNS not resolving | Configure option 43 or DNS |
| AP stuck in "Downloading" | Image mismatch, slow link | Wait; check image pre-download |
| AP joins then drops | Certificate expired, DTLS failure | Check certs, check MTU (CAPWAP needs 1500+ MTU) |
| AP in wrong WLC | Primary/secondary/tertiary WLC misconfigured on AP | Set correct WLC priority via `ap name <name> controller <wlc>` |

## Client Troubleshooting Workflow

### Step 1: Identify the Client
```
show wireless client mac-address <mac> detail
```
Key fields to check: state (run/authenticate/associate), WLAN, AP name, channel, RSSI, SNR, data rate.

### Step 2: Check Client Statistics
```
show wireless client mac-address <mac> stats
```
Look for: high retry rates (>10% indicates RF issues), low data rates (client far from AP), packet errors.

### Step 3: Enable Radioactive Trace
```
debug wireless mac <mac>
```
Reproduce the issue, then review trace output for error events.

### Step 4: Check RF Environment
```
show ap name <ap-name> dot11 5ghz cleanair air-quality summary
show ap name <ap-name> auto-rf dot11 5ghz
```
Look for: channel utilization >50%, non-Wi-Fi interference, low SNR.

### Step 5: Verify Infrastructure
```
! RADIUS reachability
test aaa group <server-group> <username> <password> new-code

! DHCP reachability
show ip dhcp pool (if WLC is DHCP relay)

! Upstream switch trunk
show interfaces trunk (on connected switch)
```

## Packet Capture

### Over-the-Air Capture
C9800 supports AP-based packet capture (requires AP in sniffer mode):
```
! Set AP to sniffer mode
ap name <ap-name> mode sniffer

! Configure capture parameters
ap name <ap-name> sniff dot11a <channel> <IP-of-Wireshark-PC>
```
AP sends captured frames to a remote Wireshark PC via UDP. Captures 802.11 management, control, and data frames.

### WLC Embedded Packet Capture (EPC)
Capture packets at the WLC level (CAPWAP tunnel ingress/egress):
```
monitor capture <name> interface <interface> both
monitor capture <name> match ipv4 host <client-ip>
monitor capture <name> start
! Reproduce issue
monitor capture <name> stop
monitor capture <name> export bootflash:<filename>.pcap
```

## Performance Monitoring

### Key Metrics to Monitor
- **Client RSSI**: Should be > -67 dBm for voice/video, > -72 dBm for data
- **Client SNR**: Should be > 25 dB for reliable operation
- **Channel utilization**: Alert if > 50% sustained, critical if > 70%
- **Retry rate**: Alert if > 10% per AP
- **Client data rate**: Low rates indicate poor RF conditions
- **AP uptime**: Monitor for unexpected reboots
- **WLC CPU**: Alert if > 70% sustained
