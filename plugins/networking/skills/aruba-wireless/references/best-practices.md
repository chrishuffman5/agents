# Aruba Wireless Best Practices Reference

## SSID Design

### Minimize SSID Count
Each SSID adds management frame overhead (beacons, probe responses). Limit to 3-4 SSIDs per AP:
- **Corporate** (802.1X with ClearPass, WPA3-Enterprise): Employee and managed device access
- **IoT** (MAB with ClearPass profiling, WPA2/WPA3): Sensors, cameras, printers, HVAC
- **Guest** (ClearPass guest portal, OWE or open with captive portal): Visitor internet access
- **BYOD** (optional, 802.1X with ClearPass OnBoard certificate provisioning): Employee personal devices with conditional access

### SSID-to-Role Mapping
Do not create separate SSIDs for each user group. Use dynamic segmentation instead:
- Single corporate SSID for all employees
- ClearPass assigns role based on user identity + device type + posture
- Different roles get different firewall policies on the gateway
- Avoids SSID proliferation while maintaining per-group access control

### WPA3 Migration Strategy
1. **Phase 1**: Enable WPA2+WPA3 transition mode on existing corporate SSID
2. **Phase 2**: Create WPA3-only SSID for 6 GHz band (required by standard)
3. **Phase 3**: Once client fleet supports WPA3, convert corporate SSID to WPA3-only
4. **Phase 4**: Disable WPA2 transition mode
- Monitor ClearPass authentication logs for WPA2 vs WPA3 client distribution during transition

## Segmentation Strategy

### Role Design
Define roles based on access requirements, not organizational structure:

| Role | Access | Example Devices |
|---|---|---|
| Employee | Full internal + internet | Corporate laptops, phones |
| Contractor | Limited internal (project resources only) + internet | Contractor laptops |
| IoT-Camera | NVR subnet only (port 554/443) | IP cameras |
| IoT-Sensor | IoT platform API only (HTTPS) | Environmental sensors |
| Guest | Internet only (DNS, HTTP, HTTPS) | Visitor devices |
| Quarantine | Remediation portal only | Non-compliant endpoints |

### Firewall Policy Design
- Start with deny-all, then add explicit permits per role
- Log denied traffic for initial policy tuning (disable verbose logging after stabilization)
- Use application-based rules where possible (gateway DPI identifies applications)
- Group related services into service aliases for readable policies
- Review and update policies quarterly or after application changes

### VLAN Strategy with Dynamic Segmentation
Even with dynamic segmentation, VLANs are still used for IP addressing:
- Assign VLANs for IP management (DHCP scope, subnet routing)
- Do not use VLANs for security segmentation (roles handle that)
- Minimize VLAN count: one user VLAN per floor/building is sufficient
- ClearPass can dynamically assign VLANs if needed (but roles are preferred for security)

## Central Management Best Practices

### Group Hierarchy
Organize devices in Central groups:
- **Template groups**: Use configuration templates with variables for scalable management
- **UI groups**: Use Central GUI for per-device configuration (simple deployments)
- Recommended: template groups for sites with more than 10 APs (repeatability and consistency)

### Configuration Templates
- Use Jinja2-style variables in templates for per-device customization (site name, VLAN IDs, RADIUS server IPs)
- Store templates in Central or version-control externally (export via API, track in Git)
- Test template changes on a staging group before applying to production
- Use Central's "compare" feature to diff proposed changes before push

### Firmware Management
- **Compliance**: Define firmware baseline per device type; Central flags non-compliant devices
- **Staged rollouts**: Upgrade one site or AP group at a time; validate before proceeding
- **Schedule upgrades**: Use Central's scheduled upgrade feature for off-peak deployment
- **Rollback plan**: Central retains previous firmware; rollback via GUI or API if issues detected

### Monitoring and Alerting
Configure alerts for:
- AP down (immediate)
- Gateway down (immediate)
- High channel utilization (>70% sustained for >15 minutes)
- Authentication failures spike (>10% failure rate over 5 minutes)
- Rogue AP detected (matching corporate SSID name)
- ClearPass unreachable from gateway (authentication will fail)

## ClearPass Integration Best Practices

### High Availability
- Deploy ClearPass in publisher/subscriber cluster (minimum 2 nodes)
- Publisher handles database writes; subscribers handle authentication
- Place subscribers close to gateways/APs for low-latency RADIUS
- Configure gateway/AP with primary and backup RADIUS server (publisher + subscriber)

### Authentication Policy Design
Order enforcement policies from most specific to most general:
1. Certificate-based (EAP-TLS) for managed devices -> Employee role
2. Username/password (PEAP) for unmanaged devices -> BYOD role + OnBoard redirect
3. MAB for IoT devices -> IoT role (based on profiling result)
4. Guest portal redirect for unknown devices -> Guest role
5. Default deny for everything else

### Profiling Best Practices
- Enable all available profiling sources (DHCP, HTTP, MAC OUI, SNMP)
- Create custom fingerprints for organization-specific devices (medical equipment, specialized IoT)
- Use ClearPass Device Insight for AI-driven profiling of unknown devices
- Regularly review "Unknown" device category and create profiles for recurring types

### Guest Access
- Self-registration with email/SMS verification for casual visitors
- Sponsor approval for vendor/contractor access (sponsor receives email, approves via portal)
- Configure guest session timeout (4-8 hours typical; 24 hours for multi-day visitors)
- Isolate guest traffic: bridge to dedicated VLAN or tunnel to gateway with guest role
- Enable HTTPS-only captive portal (avoid insecure HTTP redirect issues with modern browsers)
- Configure acceptable use policy (AUP) acceptance before access

## RF Design and Tuning

### AirMatch Configuration
- **Enable AirMatch** for all production sites (default in AOS 10)
- **Maintenance window**: Schedule AirMatch plan application during off-peak hours (e.g., 2:00-4:00 AM)
- **Exclude APs**: If specific APs require static channel/power (e.g., in regulated environments), exclude them from AirMatch
- **Monitor AirMatch effectiveness**: Check Central > RF Health dashboard after each daily optimization

### Channel Width Strategy
- **2.4 GHz**: 20 MHz only (always)
- **5 GHz**: 40 MHz for balanced density/performance; 80 MHz for high-throughput areas with low AP density
- **6 GHz**: 80 MHz or 160 MHz; abundant spectrum allows wider channels without reuse problems
- AirMatch automatically selects optimal channel width based on RF analysis

### Data Rate Optimization
- Disable 802.11b rates (1, 2, 5.5, 11 Mbps) on 2.4 GHz
- Set minimum mandatory rate to 12 or 24 Mbps on 5 GHz
- Higher minimum rates = smaller cell sizes = less co-channel interference = requires more APs
- Validate coverage after changing minimum rates

### Band Steering
- Enable band steering to push dual-band clients to 5/6 GHz
- Configure "prefer 5 GHz" or "force 5 GHz" based on environment
- Monitor 2.4 GHz client count; if still high, check for IoT/legacy devices that are 2.4 GHz-only

## Upgrade Procedures

### AOS 10 AP Upgrade (via Central)
1. Upload firmware to Central firmware repository
2. Define compliance baseline (target version per AP model)
3. Schedule upgrade for maintenance window
4. Central pushes firmware to APs in staged groups
5. APs download, reboot, rejoin Central with new firmware (3-5 minutes per AP)
6. Monitor Central dashboard for successful rejoin and client recovery
7. Validate: check AP list, client counts, RF health post-upgrade

### AOS 8 to AOS 10 Migration
This is a platform migration, not an upgrade:
1. Verify AP hardware supports AOS 10 (check compatibility matrix)
2. Provision APs in Aruba Central (create site, add licenses)
3. Convert APs from AOS 8 to AOS 10 firmware:
   - Factory reset AP or push AOS 10 image via Mobility Controller
   - AP discovers Central via DHCP option or DNS
4. Recreate WLAN configuration in Central (does not migrate from MC)
5. Recreate ClearPass policies for AOS 10 role names (may differ from AOS 8)
6. Migrate site-by-site; validate before proceeding to next site
7. Decommission Mobility Controllers after all APs migrated

### Pre-Migration Checklist
- [ ] Verify AP hardware compatibility with AOS 10
- [ ] Procure Central subscription licenses (per-AP subscription)
- [ ] Verify ClearPass version compatibility with AOS 10
- [ ] Document existing AOS 8 configuration (SSIDs, VLANs, ACLs, roles)
- [ ] Create equivalent configuration in Central (templates or UI groups)
- [ ] Test in a pilot site before full rollout
- [ ] Plan for client disruption during AP conversion (5-10 minutes per AP)
