# Wireless Fundamentals Reference

## 802.11 Standards Evolution

### 802.11ax (Wi-Fi 6 / Wi-Fi 6E)

**Wi-Fi 6 (2.4 GHz and 5 GHz)**

802.11ax was designed for high-density environments. Unlike 802.11ac which focused on peak throughput, 802.11ax optimizes for aggregate network efficiency -- getting more total data through the airspace when many clients are competing.

Key PHY/MAC improvements:
- **OFDMA** (Orthogonal Frequency Division Multiple Access): Subdivides each channel into resource units (RUs) that can be allocated to different clients simultaneously. A single OFDM symbol can serve multiple clients. This is the single most important improvement for dense environments.
- **MU-MIMO**: Up to 8x8 downlink and 8x8 uplink MU-MIMO (802.11ac was 4x4 DL only). Uplink MU-MIMO is new in 802.11ax.
- **BSS Coloring**: Tags each BSS with a 6-bit color identifier (0-63). Clients can identify same-color (own BSS) vs different-color (other BSS) transmissions and adjust CCA (Clear Channel Assessment) thresholds. Reduces co-channel interference by allowing spatial reuse.
- **Target Wake Time (TWT)**: Clients negotiate specific wake schedules with the AP. Critical for IoT devices -- reduces battery consumption by 5-10x for low-duty-cycle sensors. Also reduces contention by spreading client wake times.
- **1024-QAM**: 25% throughput improvement over 256-QAM (802.11ac) but requires excellent SNR (>35 dB). Only benefits clients very close to the AP with clean RF.
- **Longer OFDM symbol duration**: 12.8 microseconds (4x longer than 802.11ac). Reduces guard interval overhead and improves efficiency in multipath environments.
- Max theoretical PHY rate: 9.6 Gbps (8x8, 160 MHz, 1024-QAM)

**Wi-Fi 6E (extends 802.11ax to 6 GHz)**

Wi-Fi 6E uses identical 802.11ax PHY/MAC technology but operates in the 6 GHz band (5.925-7.125 GHz in the US, varying internationally):
- 1.2 GHz of new spectrum (compared to 500 MHz total in 5 GHz)
- Up to 59 non-overlapping 20 MHz channels (US)
- 14 non-overlapping 80 MHz channels, 7 non-overlapping 160 MHz channels
- No legacy clients -- only 802.11ax and newer devices operate on 6 GHz
- No DFS requirements -- no radar coexistence needed on 6 GHz
- WPA3 mandatory -- no WPA2 permitted in 6 GHz band

**6 GHz Regulatory Modes:**
- **Low Power Indoor (LPI)**: Default mode for indoor APs. Lower transmit power. No AFC required.
- **Standard Power (SP)**: Higher transmit power permitted when using Automated Frequency Coordination (AFC). AFC is a cloud service that checks AP location against incumbent user databases (fixed satellite, point-to-point links) and authorizes specific channels/power levels.
- **Very Low Power (VLP)**: For portable/mobile devices. Lowest power. No AFC required.

### 802.11be (Wi-Fi 7)

802.11be is the most significant wireless standard evolution since 802.11n introduced MIMO. Key innovations:

- **Multi-Link Operation (MLO)**: The headline feature. A single client maintains simultaneous connections across multiple bands (2.4 + 5 + 6 GHz) or multiple channels within a band. Benefits:
  - **Aggregation**: Combine bandwidth across links for higher throughput
  - **Low latency**: Steer latency-sensitive frames to the least-congested link in real-time
  - **Seamless band steering**: No disassociation/reassociation when moving traffic between bands
  - **Reliability**: If one link experiences interference, traffic shifts to another without handoff delay
  - MLO replaces traditional band steering, which was always a vendor-specific hack

- **320 MHz channels**: Available in 6 GHz band only. Doubles the channel width from Wi-Fi 6E's maximum 160 MHz. Requires very clean RF environment and is practical only in the 6 GHz band where sufficient spectrum exists.

- **4096-QAM (12-bit)**: 20% throughput improvement over 1024-QAM. Requires SNR > 40 dB -- only practical at very short range with line-of-sight.

- **16x16 MU-MIMO**: Doubled from Wi-Fi 6's 8x8. In practice, most enterprise APs will implement 4x4 or 8x8 per radio.

- **Multi-Resource Unit (MRU)**: Enhancement to OFDMA allowing a single client to be allocated non-contiguous resource units within a channel. Improves spectral efficiency when some RUs are blocked by incumbents or interference (preamble puncturing).

- **Preamble Puncturing**: Allows a wide channel (160 or 320 MHz) to continue operating even if a portion of the channel is occupied by interference or an incumbent. The punctured sub-channel is excluded while the rest continues. Critical for 320 MHz operation where finding completely clean 320 MHz blocks is difficult.

**Wi-Fi 7 Security Requirements:**
- WPA3-Enterprise: mandatory for enterprise deployments
- WPA3-Personal: SAE with Extended Key (SAE-EXT-KEY) using GCMP-256
- WPA2 not permitted in Wi-Fi 7 certified deployments
- Transition mode (WPA2+WPA3 mixed) not available on Wi-Fi 7 SSIDs

## Channel Planning

### 2.4 GHz Band (2.400-2.4835 GHz)

Only three non-overlapping 20 MHz channels in the Americas: **1, 6, 11**.

Rules:
- **Never use 40 MHz channels** in enterprise. The resulting 1.5 non-overlapping channels destroy capacity.
- Maximum 3 APs can operate on non-overlapping channels in the same coverage area.
- 2.4 GHz penetrates walls better than 5/6 GHz -- both a blessing (coverage) and a curse (interference).
- Legacy devices (IoT sensors, barcode scanners, older medical devices) often only support 2.4 GHz.
- Consider disabling 2.4 GHz radios on high-density deployments and using 2.4 GHz only on a subset of APs for legacy device coverage.
- In EMEA: channels 1, 5, 9, 13 (four non-overlapping with 5 MHz spacing) may be used depending on regulatory domain.

### 5 GHz Band (5.150-5.850 GHz)

| Sub-band | Channels (20 MHz) | DFS Required | Notes |
|---|---|---|---|
| UNII-1 (5.150-5.250) | 36, 40, 44, 48 | No | Indoor only in some regions; most reliable |
| UNII-2 (5.250-5.350) | 52, 56, 60, 64 | Yes | Radar detection required |
| UNII-2 Extended (5.470-5.725) | 100-144 | Yes | Large channel pool; DFS radar events common near airports |
| UNII-3 (5.725-5.850) | 149, 153, 157, 161, 165 | No | Higher power allowed; good for outdoor |

**DFS (Dynamic Frequency Selection):**
- Required on UNII-2 and UNII-2e channels to protect radar systems
- AP must scan for radar before transmitting (Channel Availability Check, 60 seconds)
- If radar is detected during operation, AP must vacate the channel within 10 seconds (Channel Move Time)
- AP cannot return to the channel for 30 minutes (Non-Occupancy Period)
- Near airports, military bases, or weather radar: DFS channels may be frequently vacated. Design with sufficient non-DFS channel capacity.

**Channel Width Guidance:**
- 20 MHz: Maximum channel reuse; best for very high-density
- 40 MHz: Good balance for most enterprise deployments
- 80 MHz: Higher throughput per client; fewer non-overlapping channels (5 channels in UNII-1/3)
- 160 MHz: Only 2 non-overlapping channels without DFS; use selectively for specific high-bandwidth SSIDs

### 6 GHz Band (5.925-7.125 GHz)

The 6 GHz band provides 1.2 GHz of clean spectrum (US; varies by country):
- 59 non-overlapping 20 MHz channels
- 29 non-overlapping 40 MHz channels
- 14 non-overlapping 80 MHz channels
- 7 non-overlapping 160 MHz channels
- 3 non-overlapping 320 MHz channels (Wi-Fi 7 only)

**Preferred Starting Channels (PSC):** Channels 5, 21, 37, 53, 69, 85, 101, 117, 133, 149, 165, 181, 197, 213, 229. Wi-Fi 6E/7 clients scan PSCs first during discovery to reduce scan time.

**No DFS required:** No radar coexistence needed in 6 GHz. Channels are always available (subject to AFC for standard power).

**Propagation characteristics:** 6 GHz has higher free-space path loss than 5 GHz (~2 dB more at 6.5 GHz vs 5.5 GHz). Wall penetration loss is also higher. Plan for more APs or accept smaller cell sizes compared to 5 GHz.

## MIMO, MU-MIMO, and OFDMA

### MIMO (Multiple-Input Multiple-Output)
Uses multiple antennas at both transmitter and receiver to improve throughput and reliability:
- **Spatial multiplexing**: Send different data streams on each antenna simultaneously (increases throughput linearly with stream count)
- **Spatial diversity**: Send the same data on multiple antennas for reliability (beamforming)
- **Notation**: NxM (N transmit antennas x M receive antennas), e.g., 4x4 MIMO = 4 spatial streams

### MU-MIMO (Multi-User MIMO)
Extends MIMO to serve multiple clients simultaneously:
- **Downlink MU-MIMO** (802.11ac Wave 2+): AP transmits to multiple clients at the same time using beamforming to spatially separate streams. A 4x4 AP can serve four 1x1 clients simultaneously.
- **Uplink MU-MIMO** (802.11ax+): Multiple clients transmit to the AP simultaneously. AP uses trigger frames to coordinate uplink transmissions.
- **Limitation**: MU-MIMO requires spatial separation between clients. If clients are physically close, beamforming cannot separate them effectively.

### OFDMA (Orthogonal Frequency Division Multiple Access)
Introduced in 802.11ax, OFDMA divides a channel into sub-carriers grouped into Resource Units (RUs):

| Channel Width | Total Sub-carriers | Minimum RU | Max Simultaneous Users |
|---|---|---|---|
| 20 MHz | 256 | 26-tone RU | 9 users |
| 40 MHz | 512 | 26-tone RU | 18 users |
| 80 MHz | 1024 | 26-tone RU | 37 users |
| 160 MHz | 2048 | 26-tone RU | 74 users |

**OFDMA vs MU-MIMO:**
- OFDMA divides the channel in the **frequency domain** (different sub-carriers to different clients)
- MU-MIMO divides the channel in the **spatial domain** (different beams to different clients)
- They are complementary and can operate simultaneously
- OFDMA excels for small packets (IoT, voice, ACKs); MU-MIMO excels for large data transfers

### BSS Coloring (Spatial Reuse)
Each BSS is assigned a color (6-bit value, 0-63). When a client detects a frame:
- **Same color (intra-BSS)**: Apply standard CCA threshold (-82 dBm). Defer transmission.
- **Different color (inter-BSS)**: Apply relaxed OBSS-PD (Overlapping BSS Packet Detection) threshold (up to -62 dBm). May transmit concurrently if inter-BSS signal is weak enough.
- Effect: Increases spatial reuse in dense deployments by allowing concurrent transmissions on the same channel when inter-BSS interference is below the OBSS-PD threshold.

## Roaming Protocols

### The Roaming Problem
When a client moves between APs, it must:
1. Detect that current AP signal is degrading
2. Scan for better APs (time-consuming -- scanning each channel)
3. Authenticate to new AP (802.1X: full EAP exchange = 200-500 ms)
4. Associate to new AP
5. Obtain IP (or confirm existing via DHCP)

Without optimization, a roam can take 500-1000 ms -- unacceptable for voice (>50 ms noticeable) and real-time applications.

### 802.11r (Fast BSS Transition / FT)
Pre-computes the PMK (Pairwise Master Key) at neighboring APs before roaming:
- Reduces 4-way handshake to 2 messages during reassociation
- Roam time drops to ~20-50 ms (from 200-500 ms with full 802.1X)
- **Over-the-Air (OTA)**: Client negotiates directly with target AP
- **Over-the-DS (ODS)**: Client negotiates via current AP's distribution system (DS) backhaul
- **Compatibility warning**: Some older clients (Windows 7, older iOS, legacy VoIP phones, barcode scanners) do not support 802.11r and may fail to connect. Test before enabling.
- Best practice: enable 802.11r with a fallback mechanism or on a per-SSID basis for compatible clients only.

### 802.11k (Neighbor Report)
AP provides client with a list of neighboring APs and their channels:
- Client does not need to scan all channels to find roaming targets
- Reduces scan time from ~200 ms (full scan) to ~20 ms (targeted scan)
- AP populates neighbor list dynamically based on RRM data
- Universally supported by modern clients; safe to enable everywhere

### 802.11v (BSS Transition Management)
AP can suggest or direct clients to roam:
- **BSS Transition Management Request**: AP tells client "move to AP X on channel Y"
- **Disassociation Imminent**: AP warns client it will be disconnected (load balancing, AP reboot)
- Enables AP-directed load balancing across APs
- Client may ignore the suggestion (advisory, not mandatory in most implementations)
- Useful for sticky clients that stay on a distant AP too long

### OKC (Opportunistic Key Caching)
A vendor-specific fast roaming mechanism (predates 802.11r):
- Client caches the PMK-R0 and derives PMK-R1 for new APs in the same mobility domain
- Avoids full 802.1X reauthentication during roam
- Widely supported by Cisco, Aruba, and most enterprise platforms
- Functions as a fallback when 802.11r is not supported by the client

### Roaming Best Practices
1. Enable 802.11k on all SSIDs (safe, widely supported)
2. Enable 802.11v on all SSIDs (safe, improves sticky client behavior)
3. Enable 802.11r selectively -- test with your client device fleet first
4. Maintain OKC as fallback for clients that do not support 802.11r
5. Design AP placement for -67 dBm overlap at roaming boundaries
6. Validate roaming with active survey tools (Ekahau, actual client devices)

## WPA3 Security

### WPA3-Personal (SAE)
Replaces WPA2-Personal (PSK) with Simultaneous Authentication of Equals (SAE):
- **Dragonfly key exchange**: Replaces 4-way handshake vulnerability to offline dictionary attacks
- **Forward secrecy**: Compromised password does not decrypt previously captured traffic
- **Resistance to offline attacks**: Each authentication attempt requires an active exchange with the AP; attacker cannot capture handshake and brute-force offline
- **SAE-EXT-KEY** (Wi-Fi 7): Extended key variant using stronger cryptographic groups

### WPA3-Enterprise
Builds on WPA2-Enterprise (802.1X) with mandatory protections:
- **Protected Management Frames (PMF / 802.11w)**: Required. Prevents deauthentication attacks and management frame spoofing.
- **Suite B cryptography** (192-bit mode): GCMP-256 encryption, HMAC-SHA-384, ECDSA-384 certificates. Required for government/high-security. Demands compatible RADIUS infrastructure and client supplicants.
- **Standard mode** (128-bit): CCMP-128 encryption with mandatory PMF. Easier to deploy; appropriate for most enterprise networks.

### OWE (Opportunistic Wireless Encryption)
Replaces open (unencrypted) networks with encrypted connections:
- No password required -- client and AP negotiate encryption transparently
- Uses Diffie-Hellman key exchange to establish per-client encryption
- Prevents passive eavesdropping on guest/public networks
- Does not provide authentication -- only encryption
- Ideal for guest SSIDs where password-free access is needed but eavesdropping protection is desired

### WPA3 Transition Mode
Allows WPA2 and WPA3 clients on the same SSID:
- SSID advertises both WPA2-PSK and WPA3-SAE (or WPA2-Enterprise and WPA3-Enterprise)
- Legacy clients connect with WPA2; capable clients use WPA3
- Security trade-off: WPA2 clients remain vulnerable to offline dictionary attacks
- **Not available on 6 GHz** -- 6 GHz SSIDs are WPA3-only

### PMF (Protected Management Frames / 802.11w)
- **Required** for WPA3 (both Personal and Enterprise)
- **Optional** for WPA2 (can be set to "capable" for transition)
- Protects: deauthentication, disassociation, action frames
- Prevents: deauth flood attacks, evil twin forced disconnection
- Setting: Required (WPA3-only SSID), Optional (transition SSID), Disabled (WPA2-only)

## Site Survey Methodology

### Phase 1: Requirements Gathering
- Number of concurrent users and device types per area
- Application requirements (voice: <50 ms roam, <100 ms jitter; video: >5 Mbps per stream; data: varies)
- Coverage requirements by area type (office, conference room, warehouse, outdoor)
- Security requirements (WPA3 mandate, NAC, guest isolation)
- Regulatory domain and local regulations (FCC, ETSI, etc.)
- Budget and timeline constraints

### Phase 2: Predictive Design
- Import floor plans with accurate scale into survey tool (Ekahau, Hamina, iBwave)
- Define wall materials and attenuation values:

| Material | Approximate Attenuation (dB per wall) |
|---|---|
| Drywall (standard) | 3-4 dB |
| Glass (standard) | 2-3 dB |
| Glass (low-e / tinted) | 6-8 dB |
| Concrete block | 12-15 dB |
| Brick | 8-12 dB |
| Metal (elevator, server room) | 20+ dB |
| Wood (door) | 3-4 dB |
| Floor/ceiling (concrete) | 15-20 dB |

- Place APs at recommended density for capacity requirements
- Target coverage: -67 dBm RSSI for voice/video, -72 dBm for data, -75 dBm for basic connectivity
- Target SNR: >25 dB for reliable operation, >35 dB for 1024-QAM
- Validate channel plan: assign non-overlapping channels, confirm co-channel interference levels

### Phase 3: On-Site Validation (Passive Survey)
- Walk the facility with survey equipment measuring actual RF environment
- Identify noise sources: microwave ovens (2.4 GHz), Bluetooth, ZigBee, cordless phones, radar
- Measure neighboring AP interference (co-channel and adjacent channel)
- Verify wall attenuation matches predictive model (adjust if needed)
- Document areas with poor coverage or high interference

### Phase 4: Active Survey (Post-Deployment)
- Connect to the deployed network and measure actual performance
- Test throughput at representative locations (iPerf or survey tool throughput test)
- Test roaming along expected movement paths (conference room to conference room, hallway walk)
- Measure DHCP/DNS response times
- Validate application performance (voice call quality, video streaming, business application latency)

### Phase 5: Ongoing Optimization
- Monitor RRM/AirMatch changes and validate effectiveness
- Review client connection statistics (retry rates, data rates, roaming failures)
- Re-survey after significant building changes (renovation, furniture moves, new walls)
- Adjust AP placement and channel/power settings based on real-world data
