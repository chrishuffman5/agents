# On-Premises Mail Paradigm

## When On-Premises Mail Makes Sense

On-premises mail infrastructure is appropriate when:
- **Regulatory mandate** requires physical data control (government, defense, classified environments)
- **Air-gapped networks** have no internet connectivity
- **Custom mail flow** requires capabilities beyond cloud platform limits (high-volume transactional mail, complex routing, ISP-scale operations)
- **Hybrid coexistence** is an ongoing architectural choice, not a migration waypoint
- **Cost optimization** at scale where per-user cloud licensing exceeds self-hosted TCO

On-premises is NOT appropriate when the primary motivation is "we've always done it this way." Cloud platforms have achieved compliance certifications (FedRAMP, HIPAA BAA, SOC 2, ISO 27001) that satisfy most regulatory requirements.

## Exchange Server Architecture

### Server Role Model

Exchange 2019 and Exchange Server SE use a two-role architecture:

- **Mailbox Server** -- The single consolidated role containing transport services, mailbox databases, client access proxy, and Exchange Admin Center
- **Edge Transport Server** -- Optional DMZ role for perimeter SMTP filtering (antispam, attachment filtering, EdgeSync from internal AD)

Every Mailbox server is self-contained. Client connections hit the frontend proxy layer, which routes to the backend service on the server holding the active database copy.

### Transport Pipeline

Three transport services run on each Mailbox server:

1. **Front End Transport** -- Listens on port 25, stateless proxy, no content inspection
2. **Transport Service** (Hub Transport) -- Message categorization, routing, transport rules, shadow redundancy, Safety Net
3. **Mailbox Transport** -- Submission (mailbox to transport) and Delivery (transport to mailbox) via RPC

```
Inbound: Internet --> Frontend (port 25) --> Transport --> Mailbox Transport Delivery --> Database
Outbound: Database --> Mailbox Transport Submission --> Transport --> Send Connector --> Internet
```

**Shadow Redundancy:** Transport keeps redundant copies of in-transit messages. If the next-hop fails, the shadow copy resubmits.

**Safety Net:** After delivery, Transport retains copies of delivered messages for a configurable period (default 2 days). Enables resubmission after database failover.

### Database Availability Groups (DAG)

DAG is the core high-availability mechanism:
- Up to 16 Mailbox servers per DAG
- Automatic database-level failover
- Built on Windows Failover Clustering
- Quorum: Node and File Share Majority (even members) or Node Majority (odd members)
- Witness server in a third location enables automatic datacenter failover

**Preferred Architecture:** 4 copies per database (2 per datacenter), one lagged copy for logical corruption recovery, AutoReseed for automatic disk failure recovery.

### Exchange Server SE (Subscription Edition)

Released Q3 2025, Exchange SE replaces Exchange 2019:
- Annual subscription licensing (replaces perpetual)
- RTM functionally identical to Exchange 2019 CU15
- TLS 1.2 and 1.3 only (legacy protocols disabled)
- Supports Windows Server 2019, 2022, 2025
- In-place upgrade from Exchange 2019 CU14/CU15

### Hybrid Deployment

The Hybrid Configuration Wizard (HCW) establishes coexistence between on-prem Exchange and Exchange Online:
- TLS-encrypted Send/Receive connectors for cross-premises mail flow
- OAuth for cross-premises features (eDiscovery, In-Place Archive)
- Organization relationships for free/busy calendar sharing
- Migration endpoints for mailbox moves

**Topology options:**
- **Classic Hybrid** -- Full features, requires published endpoints (Autodiscover, EWS, MAPI)
- **Minimal Hybrid** -- Subset of features, faster deployment
- **Hybrid Agent** -- No inbound firewall rules needed, but no Hybrid Modern Authentication

### On-Premises Compliance

- **Retention policies** via Messaging Records Management (MRM) with retention tags
- **Litigation Hold** per-mailbox via `Set-Mailbox -LitigationHoldEnabled $true`
- **Journaling** with journal rules targeting specific recipients or global scope
- **Transport rules** for DLP, disclaimers, and content inspection

## Postfix as Mail Infrastructure

### Postfix Relay/Gateway

Postfix is the dominant open-source MTA for Linux. Common on-premises roles:

- **Internet-facing MTA** -- Receives inbound SMTP, applies antispam/milter processing, delivers to mailbox server via LMTP
- **Outbound relay** -- Accepts mail from internal applications, routes to the internet or a smart host
- **Edge transport** -- DMZ gateway in front of Exchange or a cloud platform, applying postscreen and DNSBL filtering
- **Satellite relay** -- Internal servers relay through a central Postfix instance for egress control

### Postfix + Dovecot Stack

The classic on-premises Linux mail stack:
- **Postfix** handles SMTP (receiving, routing, submission)
- **Dovecot** handles IMAP/POP3 (mailbox access) and SASL authentication
- **Rspamd** or **SpamAssassin** handles antispam scoring
- **ClamAV** handles antimalware scanning
- **OpenDKIM/OpenDMARC** handle email authentication
- **Let's Encrypt** provides TLS certificates via certbot

### When to Use Postfix vs. Exchange

| Factor | Postfix | Exchange Server |
|--------|---------|----------------|
| **OS** | Linux | Windows Server |
| **Mailbox storage** | Requires Dovecot/Cyrus | Built-in |
| **Calendar/contacts** | Requires SOGo/CalDAV | Built-in Exchange Calendar |
| **Management** | CLI + config files | EAC + PowerShell |
| **Licensing** | Free (open-source) | Per-server + per-CAL or subscription |
| **Best for** | Relay, gateway, custom routing, transactional mail | Full-featured enterprise groupware |
| **HA** | HAProxy/keepalived + multiple instances | DAG with automatic failover |
| **AD integration** | LDAP lookups | Native |

## Hybrid Architecture Patterns

### Exchange Hybrid + Cloud SEG

```
Internet --> [Cloud SEG (Proofpoint/Mimecast)] --> [Exchange On-Prem] <--> [Exchange Online]
```

MX points to the SEG. SEG filters inbound and routes to on-prem or cloud based on recipient location. On-prem Exchange maintains hybrid connectors with Exchange Online.

### Postfix Edge + Exchange Internal

```
Internet --> [Postfix + Postscreen + Milters] --> [Exchange Mailbox Server]
```

Postfix handles connection filtering, DNSBL checks, DKIM/DMARC via milters. Clean mail is relayed to Exchange for delivery. Postfix acts as a cost-effective alternative to the Exchange Edge Transport role.

### Split-Domain Routing

During migration, mail for a single domain routes to different systems based on recipient:
- Recipient in cloud --> MX points to cloud, cloud delivers locally
- Recipient on-prem --> Cloud forwards to on-prem via hybrid connector

Exchange hybrid natively supports this. For Postfix-to-cloud scenarios, transport maps route specific recipients to the cloud endpoint.

## Operational Considerations

### Patching and Updates

- **Exchange Server:** Cumulative Updates (CUs) quarterly, Security Updates (SUs) monthly. Both require downtime per server (DAG rolling updates minimize impact).
- **Postfix:** Package manager updates (`apt upgrade postfix`), followed by `postfix reload`. No downtime required for most config changes.

### Monitoring

- **Exchange:** Performance counters, Event Viewer, Exchange Health Checker script (`HealthChecker.ps1`), managed availability
- **Postfix:** `mailq` for queue depth, `postconf -n` for config audit, syslog analysis, tools like Pflogsumm for log summaries

### Backup

- **Exchange:** DAG provides database redundancy but is not backup. Use Windows Server Backup or third-party (Veeam, Commvault) for database + transaction log backup. Test restore regularly.
- **Postfix:** Configuration files (`/etc/postfix/`), lookup tables, and TLS certificates. Mailbox data backed up at the Dovecot/storage layer.
