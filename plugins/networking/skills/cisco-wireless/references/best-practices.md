# Cisco Wireless Best Practices Reference

## RF Design

### AP Placement
- **Height**: Mount APs at 3-4 meters (10-13 feet) above floor level. Too high reduces signal quality due to antenna pattern dispersion; too low creates coverage holes in adjacent areas.
- **Orientation**: APs with internal antennas should be mounted flat (horizontal, antenna plane parallel to floor). External antenna APs should have antennas oriented per manufacturer recommendation.
- **Density**: Design for capacity, not just coverage. High-density areas (conference rooms, auditoriums, trading floors) need more APs at lower power rather than fewer APs at high power.
- **Cell overlap**: Target -67 dBm at cell edge for voice/video. Adjacent AP coverage should overlap at -67 dBm for seamless roaming.
- **Avoid co-channel interference**: Minimum 19 dB separation between co-channel APs. RRM/DCA handles this dynamically but proper AP placement provides the foundation.

### Band Strategy
- **2.4 GHz**: Use for legacy device coverage only. Minimize power and consider disabling on a subset of APs in high-density areas. Only channels 1, 6, 11 (20 MHz only).
- **5 GHz**: Primary band for most clients. 40 or 80 MHz channels. Use all available channels including DFS (unless radar events are frequent at the site).
- **6 GHz**: Dedicated band for Wi-Fi 6E/7 capable clients. Enable AFC for standard power operation. 80 or 160 MHz channels viable due to abundant spectrum.
- **Band steering**: Enable on the WLC to push dual-band clients to 5/6 GHz. Configure aggressive band steering for environments with high 2.4 GHz contention.

### Data Rate Configuration
Disable low data rates to improve airtime efficiency:
- **2.4 GHz**: Disable 1, 2, 5.5 Mbps. Set 11 Mbps as minimum mandatory. Consider 12 or 24 Mbps mandatory in dense environments.
- **5 GHz**: Disable rates below 12 Mbps. Set 12 or 24 Mbps as minimum mandatory.
- **6 GHz**: All clients support 802.11ax rates; default rates are appropriate.
- **Caution**: Raising minimum data rates shrinks effective cell size. Ensure coverage is maintained via survey.

## WLAN Configuration

### SSID Design
- **Minimize SSID count**: Each SSID adds a beacon per AP per channel. Maximum 3-4 SSIDs per radio. More SSIDs = more overhead.
- **Recommended SSIDs**:
  - Corp (802.1X, WPA3-Enterprise): Employee devices
  - IoT (MAC auth or 802.1X with EAP-TLS certificates): Sensors, cameras, printers
  - Guest (CWA with ISE guest portal, WPA3-OWE or open): Visitor access
- **WPA3 migration path**: Use WPA2+WPA3 transition mode on existing SSIDs. Create a WPA3-only SSID for 6 GHz band.

### QoS Configuration
- Enable WMM (Wi-Fi Multimedia) on all SSIDs
- Map voice traffic to Platinum (UP 6, AC_VO)
- Map video traffic to Gold (UP 5, AC_VI)
- Map best-effort data to Silver (UP 0, AC_BE)
- Map background traffic to Bronze (UP 1, AC_BK)
- Enable AVC (Application Visibility and Control) to classify traffic by application
- Configure per-client bandwidth contracts if needed (ISE can return rate limits via RADIUS)

### Client Limits and Timeouts
- **Max clients per SSID**: Default is adequate for most deployments. Reduce for guest SSIDs.
- **Idle timeout**: 300 seconds (5 minutes) is typical. Reduce for guest SSIDs (120 seconds).
- **Session timeout**: 28800 seconds (8 hours) for corporate, 3600 seconds (1 hour) for guest.
- **Exclusion timer**: 60 seconds default. Clients failing authentication are excluded for this period. Adjust based on tolerance for authentication retries.

## FlexConnect vs Centralized Selection

### Choose Centralized When:
- WLC is in the same campus LAN as APs (low latency, high bandwidth)
- Centralized policy enforcement is required (all traffic inspected at WLC)
- SD-Access fabric is not deployed
- Simple management: all configuration and policy on WLC

### Choose FlexConnect When:
- APs are at remote branch offices connected via WAN
- WAN bandwidth is limited or expensive
- Local data switching is needed (traffic stays at the branch)
- WAN survivability is required (branch wireless must survive WAN outage)
- C9800-CL is deployed in public cloud (FlexConnect with local switching is required)

### FlexConnect Design Considerations
- Configure FlexConnect groups for VLAN consistency across branch APs
- Enable split tunneling: corporate traffic centrally switched, guest/internet traffic locally switched
- Pre-download AP images to reduce WAN traffic during upgrades
- Enable OKC (Opportunistic Key Caching) within FlexConnect groups for fast roaming
- Test standalone mode behavior: verify APs continue servicing clients during WAN outage

## Security Best Practices

### Authentication
- **WPA3-Enterprise (802.1X)** for all corporate SSIDs. Use EAP-TLS (certificate-based) where possible; PEAP as fallback.
- **WPA3-Personal (SAE)** only for personal/small-office deployments. Not recommended for enterprise due to shared password.
- **MAC Authentication Bypass (MAB)** for IoT devices that cannot perform 802.1X. Combine with ISE profiling for dynamic VLAN/SGT assignment.
- **Central Web Authentication (CWA)** for guest access via ISE guest portal.

### 802.11w (PMF / Protected Management Frames)
- **Required** for WPA3 SSIDs
- **Optional** for WPA2 SSIDs in transition mode (allows both WPA2 and WPA3 clients)
- Prevents deauthentication attacks and management frame spoofing
- Some legacy clients do not support PMF -- test before enabling as "required" on WPA2 SSIDs

### 802.11r (Fast BSS Transition)
- Enable for voice/video SSIDs where roaming latency must be < 50 ms
- Enable with "FT over-the-Air" for most deployments (simpler than over-the-DS)
- **Test with client devices first**: Some legacy clients fail to connect when 802.11r is enabled
- Enable alongside OKC as fallback for clients that do not support 802.11r

### Rogue AP Detection
- Enable rogue AP detection on all WLANs
- Configure rogue containment for SSIDs that match your corporate SSID name but are not managed
- Integrate with ISE/Catalyst Center for rogue correlation and alerting
- Set classification rules: friendly (known), malicious (impersonating), unclassified

## RRM Tuning

### When to Tune RRM (and When Not To)
- **Start with defaults**: RRM defaults are well-tuned for most environments. Do not customize unless you have measured a specific problem.
- **Tune TPC thresholds**: If coverage is too hot (high co-channel interference) or too cold (coverage holes), adjust TPC target power range.
- **DCA channel list**: If specific DFS channels cause problems (frequent radar events), remove them from the DCA allowed list.
- **FRA**: Enable Flexible Radio Assignment to auto-convert underutilized 2.4 GHz radios to 5 GHz in dual-radio APs. Reduces 2.4 GHz noise while adding 5 GHz capacity.

### RRM Monitoring
```
! Check RRM group leader
show ap dot11 5ghz group

! Check DCA channel assignments
show ap dot11 5ghz channel

! Check TPC power levels
show ap dot11 5ghz power

! Check RRM events (channel/power changes)
show ap dot11 5ghz monitor
```

### Common RRM Issues
- **All APs on same channel**: RRM group leader may not be functioning. Check RRM group membership.
- **Excessive power on some APs**: TPC may be compensating for coverage holes caused by poor AP placement. Fix placement, do not override power.
- **Frequent channel changes**: May indicate high interference. Check CleanAir for non-Wi-Fi sources. Consider adjusting DCA sensitivity.

## Upgrade Procedures

### Rolling AP Upgrade
C9800 supports upgrading APs without WLC downtime:
1. Stage the new image on WLC: `ap image predownload`
2. Configure AP upgrade groups (stagger by floor, building, or AP group)
3. Initiate rolling upgrade: APs download new image, reboot sequentially
4. Each AP is offline 3-5 minutes during reboot; neighboring APs provide coverage overlap
5. Monitor upgrade progress: `show ap image`
6. Validate: Check AP join state, client counts, RF metrics post-upgrade

### WLC Upgrade (HA)
1. Pre-download image to standby WLC
2. Upgrade standby WLC first (reboot)
3. Verify standby comes up healthy with new version
4. Force switchover (failover) to upgraded standby (now active)
5. Upgrade original active (now standby) WLC
6. Verify both WLCs running new version in HA SSO state

### Pre-Upgrade Checklist
- [ ] Review release notes for known issues and caveats
- [ ] Verify hardware compatibility with target IOS-XE version
- [ ] Back up running configuration: `copy running-config bootflash:backup_<date>.cfg`
- [ ] Back up AP preimage: note current AP image version
- [ ] Verify maintenance window has adequate time (WLC reboot: 10-15 min; AP upgrade: 3-5 min per stagger group)
- [ ] Notify stakeholders of expected wireless downtime per area
- [ ] Test rollback procedure: confirm you can boot previous image if needed
