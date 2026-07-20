# Azure DNS Architecture Reference

## Public Zone Infrastructure

### Anycast Nameservers

Azure DNS uses a globally distributed anycast network:
- Four nameservers per zone from different TLDs for resilience:
  - `ns1-0x.azure-dns.com`
  - `ns2-0x.azure-dns.net`
  - `ns3-0x.azure-dns.org`
  - `ns4-0x.azure-dns.info`
- BGP anycast routes queries to nearest Azure PoP
- 100% SLA for valid DNS queries
- No infrastructure to manage; fully serverless

### Record Types

| Type | Description | Zone Apex |
|---|---|---|
| A | IPv4 address | Yes (direct or alias) |
| AAAA | IPv6 address | Yes (direct or alias) |
| CNAME | Canonical name | No (use alias instead) |
| MX | Mail exchange | No alias |
| NS | Nameserver (auto-managed) | Auto |
| PTR | Reverse lookup | N/A |
| SOA | Start of authority (auto-managed) | Auto |
| SRV | Service locator | No alias |
| TXT | Text (SPF, DKIM, verification) | No alias |
| CAA | Certificate authority authorization | No alias |

### Alias Records

```
┌─────────────────┐      auto-update      ┌────────────────────┐
│  Alias Record   │◄─────────────────────►│  Azure Resource    │
│  example.com A  │                        │  (Public IP, LB,   │
│  (zone apex)    │                        │   CDN, Front Door) │
└─────────────────┘                        └────────────────────┘
```

Supported alias targets:
- Azure Public IP (A/AAAA)
- Azure Traffic Manager profile (A/AAAA/CNAME)
- Azure CDN endpoint (A/AAAA/CNAME)
- Azure Front Door (A/AAAA/CNAME)
- Another DNS record set in the same zone (A/AAAA/CNAME)

Key properties:
- Zone apex support (solves CNAME-at-apex limitation)
- Auto-updating: IP changes on target resource reflected automatically
- No TTL override: TTL inherited from target resource
- Free queries to Azure resource targets (no per-query charge for alias)

### DNSSEC

```
Zone ──► Azure DNSSEC Signing ──► Signed responses
                 │
            Auto-managed:
            - Key generation
            - Key rotation
            - Signing operations
```

- Enable per-zone via Portal or CLI
- Algorithms: ECDSAP256SHA256, ECDSAP384SHA384, ED25519
- Azure manages all key operations (generation, rotation, signing)
- Admin responsibility: publish DS record at parent registrar
- Not available for private zones

## Private Zone Architecture

### VNet Links

```
┌──────────────────┐
│ Private Zone     │
│ internal.corp    │
├──────────────────┤
│ VNet Link 1      │───► VNet-A (auto-registration ON)
│ VNet Link 2      │───► VNet-B (auto-registration OFF)
│ VNet Link 3      │───► VNet-C (auto-registration OFF)
└──────────────────┘
```

- A private zone can be linked to multiple VNets
- Auto-registration creates A records for VMs automatically (one VNet per zone max)
- Resolution-only links allow DNS queries without auto-registration
- Cross-subscription linking supported (with appropriate RBAC)

### Auto-Registration

When enabled on a VNet link:
- New VMs: A record created automatically (`vm-name.zone-name`)
- Deleted VMs: A record removed automatically
- NIC IP changes: A record updated automatically
- Only one auto-registration link per VNet

### Private Endpoint DNS Integration

Azure services use a `privatelink` subdomain pattern:

| Service | Private DNS Zone |
|---|---|
| SQL Database | privatelink.database.windows.net |
| Blob Storage | privatelink.blob.core.windows.net |
| Key Vault | privatelink.vaultcore.azure.net |
| Cosmos DB | privatelink.documents.azure.com |
| App Service | privatelink.azurewebsites.net |
| Azure Monitor | privatelink.monitor.azure.com |
| ACR | privatelink.azurecr.io |

Resolution chain:
```
mydb.database.windows.net
  → CNAME: mydb.privatelink.database.windows.net
  → A: 10.0.1.5 (from private DNS zone)
```

Without private DNS zone, the public IP is returned instead.

## Azure DNS Private Resolver

### Component Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Azure VNet                            │
│                                                         │
│  ┌─────────────────────┐  ┌───────────────────────┐    │
│  │ Inbound Subnet      │  │ Outbound Subnet       │    │
│  │ (dedicated /28+)    │  │ (dedicated /28+)      │    │
│  │                     │  │                       │    │
│  │ Inbound Endpoint    │  │ Outbound Endpoint     │    │
│  │ IP: 10.0.1.4        │  │ IP: 10.0.2.4          │    │
│  └──────────┬──────────┘  └──────────┬────────────┘    │
│             │                        │                  │
│             │              ┌─────────┴────────┐        │
│             │              │ DNS Forwarding   │        │
│             │              │ Ruleset          │        │
│             │              │                  │        │
│             │              │ corp.internal →  │        │
│             │              │   10.10.0.53     │        │
│             │              │   10.10.0.54     │        │
│             │              │                  │        │
│             │              │ ad.contoso.com → │        │
│             │              │   10.10.0.53     │        │
│             │              └──────────────────┘        │
└─────────────┴──────────────────────────────────────────┘
```

### Inbound Endpoint

- Provides private IP in VNet for external DNS forwarding targets
- On-prem DNS servers conditionally forward specific zones to this IP
- Resolves using Azure Private DNS zones linked to the resolver's VNet
- Supports up to 10,000 queries per second per endpoint
- High availability: zone-redundant deployment

### Outbound Endpoint

- Sends conditional forwarding queries to external DNS servers
- Must be associated with a DNS Forwarding Ruleset
- Supports up to 10,000 queries per second per endpoint
- Source IP for forwarded queries comes from the outbound subnet

### DNS Forwarding Ruleset

- Container for forwarding rules
- Each rule: domain name pattern → target DNS server IP(s)
- Up to 1,000 rules per ruleset
- Up to 2 rulesets per outbound endpoint
- Ruleset can be linked to multiple VNets
- Most specific domain match wins

### Hybrid DNS Patterns

**Pattern 1: On-Premises to Azure Private Endpoints**
```
On-prem client → On-prem DNS
  → Conditional forwarder: *.privatelink.database.windows.net → 10.0.1.4
  → Inbound Endpoint resolves via linked Private DNS zone
  → Returns: 10.0.1.5 (private endpoint IP)
```

**Pattern 2: Azure VMs to On-Premises Active Directory**
```
Azure VM → 168.63.129.16 (Azure DNS wire server)
  → Outbound Endpoint → Forwarding Ruleset
  → Rule: ad.contoso.com → 10.10.0.53
  → On-prem DC responds with AD DNS records
```

**Pattern 3: Hub-Spoke with Centralized DNS**
```
Spoke VNets → Hub VNet (DNS Forwarding Ruleset linked)
  → Private Resolver handles:
    - Azure private zones (inbound)
    - On-prem forwarding (outbound)
    - Internet DNS (Azure default)
```

## Traffic Manager Architecture

### DNS-Based Routing

```
Client DNS query: myapp.trafficmanager.net
  → Traffic Manager evaluates:
    1. Routing method (Priority/Weighted/Performance/...)
    2. Endpoint health (probe results)
    3. Returns: CNAME or A record for selected endpoint
  → Client connects directly to endpoint (no proxy)
```

Traffic Manager is DNS-only -- no data plane proxy. Client connects directly to the selected endpoint.

### Routing Methods

**Priority:**
- Ordered endpoint list; highest priority healthy endpoint selected
- Use case: primary/secondary failover

**Weighted:**
- Distribute traffic by weight (1-1000)
- Use case: canary deployments, gradual migration

**Performance:**
- Route to closest endpoint (measured by DNS resolution latency)
- Azure maintains latency tables for client IP ranges
- Use case: multi-region low-latency

**Geographic:**
- Map geographic regions to specific endpoints
- Use case: data sovereignty, regional content

**Subnet:**
- Map client IP CIDR ranges to endpoints
- Use case: enterprise network-based routing

**Multivalue:**
- Return up to 8 healthy endpoint IPs
- Client performs random selection
- Use case: simple client-side load balancing

### Health Probes

- HTTP/HTTPS: check status code (200) and optional body content match
- TCP: check port connectivity
- Custom headers supported for host-based routing
- Probe interval: 10-30 seconds
- Tolerated failures: 0-9 consecutive failures before marking unhealthy
- Nested profiles: child profile health aggregated into parent

### Nesting

Combine routing methods:
```
Parent: Performance routing (select region)
  └── Child-EastUS: Weighted routing (canary split)
        ├── v1: weight 90
        └── v2: weight 10
  └── Child-WestEU: Priority routing (failover)
        ├── primary: priority 1
        └── secondary: priority 2
```

## Azure Firewall DNS Proxy

### Architecture

```
Azure VM ──► Azure Firewall (DNS Proxy) ──► Custom DNS / Azure DNS
  (VNet DNS = FW IP)        │
                        DNS Logging
                        (diagnostic logs)
```

### Configuration Requirements

1. Azure Firewall with DNS Proxy enabled
2. VNet DNS servers configured to Azure Firewall private IP
3. Firewall DNS servers configured (custom DNS and/or Azure DNS 168.63.129.16)

### FQDN-Based Rules

DNS proxy is **required** for:
- Network rules with FQDN targets (e.g., allow TCP 443 to `*.database.windows.net`)
- Application rules with FQDN targets
- Without DNS proxy, Azure Firewall cannot resolve FQDNs in rules

### DNS Logging

Azure Firewall diagnostic logs capture:
- Source IP and port
- Queried FQDN
- Resolved IP addresses
- DNS response code
- Use case: compliance auditing, security monitoring, troubleshooting

## Terraform Resources

### Public Zone

```hcl
resource "azurerm_dns_zone" "public" {
  name                = "example.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_dns_a_record" "www" {
  name                = "www"
  zone_name           = azurerm_dns_zone.public.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = ["10.1.1.1"]
}
```

### Private Zone

```hcl
resource "azurerm_private_dns_zone" "internal" {
  name                = "internal.example.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  name                  = "vnet-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = true
}
```

### Private Resolver

```hcl
resource "azurerm_private_dns_resolver" "resolver" {
  name                = "my-resolver"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  virtual_network_id  = azurerm_virtual_network.main.id
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "inbound" {
  name                    = "inbound"
  private_dns_resolver_id = azurerm_private_dns_resolver.resolver.id
  location                = azurerm_resource_group.main.location
  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = azurerm_subnet.inbound.id
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "outbound" {
  name                    = "outbound"
  private_dns_resolver_id = azurerm_private_dns_resolver.resolver.id
  location                = azurerm_resource_group.main.location
  subnet_id               = azurerm_subnet.outbound.id
}

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "ruleset" {
  name                                       = "corp-forwarding"
  resource_group_name                        = azurerm_resource_group.main.name
  location                                   = azurerm_resource_group.main.location
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.outbound.id]
}

resource "azurerm_private_dns_resolver_forwarding_rule" "corp" {
  name                      = "corp-internal"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.ruleset.id
  domain_name               = "corp.internal."
  enabled                   = true
  target_dns_servers {
    ip_address = "10.10.0.53"
    port       = 53
  }
  target_dns_servers {
    ip_address = "10.10.0.54"
    port       = 53
  }
}
```
