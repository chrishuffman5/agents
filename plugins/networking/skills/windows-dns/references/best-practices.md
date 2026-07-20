# Windows DNS Best Practices Reference

## Forwarder Design

- Use conditional forwarders for specific namespaces (partner, Azure, AWS)
- Use global forwarders for internet resolution
- Set forwarder timeout appropriately (default 3 seconds)
- Enable "Use root hints if no forwarders are available" as fallback
- In hybrid: forward Azure private zones to Azure DNS Resolver endpoints

```powershell
Set-DnsServerForwarder -IPAddress "8.8.8.8","8.8.4.4" -UseRootHint $True
Add-DnsServerConditionalForwarderZone -Name "privatelink.database.windows.net" -MasterServers "10.0.0.4" -ReplicationScope "Forest"
```

## Split-Brain DNS

### DNS Policies + Zone Scopes (Server 2016+)
```powershell
Add-DnsServerClientSubnet -Name "InternalSubnet" -IPv4Subnet "10.0.0.0/8"
Add-DnsServerZoneScope -ZoneName "contoso.com" -Name "InternalScope"
Add-DnsServerResourceRecord -ZoneName "contoso.com" -A -Name "www" -IPv4Address "10.0.0.10" -ZoneScope "InternalScope"
Add-DnsServerQueryResolutionPolicy -Name "InternalPolicy" -Action ALLOW -ClientSubnet "eq,InternalSubnet" -ZoneScope "InternalScope,1" -ZoneName "contoso.com" -ProcessingOrder 1
Add-DnsServerQueryResolutionPolicy -Name "ExternalPolicy" -Action ALLOW -ZoneScope "ExternalScope,1" -ZoneName "contoso.com" -ProcessingOrder 2
```

## Secure Dynamic Updates

- Always configure AD-integrated zones for "Secure only" dynamic updates
- Prevents unauthenticated computers from registering arbitrary records
- Use DHCP server credentials for DHCP-registered records

## Scavenging Best Practices

- Set scavenging period = DHCP lease duration + 1 day
- Enable on the primary zone AND the server
- Do not enable on zones with purely static records unless understood
- Use `dnscmd /ageallrecords` when converting standard to AD-integrated
- Configure one server per zone as the scavenging server

```powershell
Set-DnsServerScavenging -ScavengingState $True -ScavengingInterval 7.00:00:00
Set-DnsServerZoneAging -ZoneName "contoso.com" -Aging $True -NoRefreshInterval 7.00:00:00 -RefreshInterval 7.00:00:00
```

## DNSSEC Best Practices

- Use ECDSAP256/SHA-256 for new zone signings
- Enable NSEC3 (prevents zone walking)
- Distribute trust anchors to all validating resolvers in forest
- Monitor key rollover events and DS record synchronization
- Consider hardware KSP (TPM) for KSK in high-security environments

## General Best Practices

- At least two DNS servers per domain (typically two AD DCs per site)
- Configure site-local DNS as primary for clients
- Use AD-integrated zones over standard primary wherever possible
- Enable debug logging in lab; monitor Events 4000-4019 in production
- Regularly audit stale records via aging/scavenging
- Use PowerShell consistently (avoid mixing dnscmd and PowerShell)

## Debug Logging

```powershell
Set-DnsServerDiagnostics -All $True -LogFilePath "C:\DNS_Debug.log" -MaxMBFileSize 500
# Or selective:
Set-DnsServerDiagnostics -Queries $True -Answers $True -SendPackets $True -ReceivePackets $True
```
