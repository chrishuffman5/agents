# Proofpoint Email Protection — Architecture Reference

## Platform Overview

Proofpoint's email security platform consists of integrated but separately licensed modules:

```
Proofpoint Platform
├── Email Protection (SEG) — Core gateway, anti-spam, anti-malware
├── Targeted Attack Protection (TAP) — Sandbox, URL Defense
├── Email Fraud Defense (EFD) — DMARC management, supplier risk
├── Threat Response Auto-Pull (TRAP) — Post-delivery remediation
├── Nexus People Risk Explorer — VAP, attack index, human risk
├── Security Awareness Training (PSAT) — Phishing simulations, training
├── Email DLP — Outbound data loss prevention
├── Email Encryption — On-demand and policy-based encryption
└── Archiving (Proofpoint Archive) — Compliance archiving
```

## SEG Deployment Models

### Cloud (SaaS) — Proofpoint Hosted

Most customers use Proofpoint's hosted cloud infrastructure.

**Data centers:** Proofpoint operates regional clusters in US, EU, APAC, Canada, Australia.

**MX record pattern:**
- US: `mail.pphosted.com`
- EU: `eu-mail.pphosted.com`
- APAC: `ap-mail.pphosted.com`

**Data residency:** Customer data processed and stored in their selected region. Important for GDPR compliance.

**Throughput and HA:**
- Active-active cluster design
- Automatic failover between nodes
- No single point of failure in Proofpoint's infrastructure
- Customer SLA: 99.999% availability guaranteed

### On-Premises (PPS — Proofpoint Protection Server)

Some regulated customers deploy Proofpoint on-premises.

**Appliance or VM options:**
- Physical appliances (Proofpoint M400, M600, M1000 series)
- Virtual appliances for VMware ESXi, Hyper-V
- Hardware requirements scale with mail volume

**Architecture:**
```
Inbound MTA → Proofpoint PPS cluster → Downstream MTA
                    ↕
             Proofpoint Spam Labs
             (cloud intelligence feeds)
```

On-prem deployments still receive cloud-based threat intelligence updates from Proofpoint Spam Labs (~5-minute update cycles).

### Hybrid

Some customers use on-prem Proofpoint for inbound and cloud for outbound, or vice versa.

## TAP Nexus Threat Intelligence

TAP is powered by Proofpoint's Nexus Threat Intelligence, a threat research infrastructure that processes billions of messages daily.

### Nexus Intelligence Sources

**NexusAI:** Machine learning models trained on:
- Millions of malicious samples analyzed daily
- Global email telemetry (Proofpoint's 83% Fortune 100 customer base)
- Proofpoint Threat Research (ET Intelligence) feeds
- URL/domain reputation scoring

**Emerging Threats (ET Intelligence):**
- Proofpoint acquired Emerging Threats in 2015
- ET Pro ruleset used in Snort/Suricata IDS/IPS
- Feed integrated into TAP for URL and attachment reputation
- Used by major network security vendors

**Dynamic Reputation (DR):**
IP and domain reputation scored in real time. Updated every 5 minutes based on:
- Spam trap hits
- Malware C2 connections
- Phishing page detections
- Botnet participation indicators

### TAP Threat Intelligence Dashboard

The TAP dashboard provides threat visibility into:

**Campaigns view:**
- Aggregate campaigns targeting the organization
- Attack volume over time
- Malware family breakdown (emotet, trickbot, qakbot, etc.)
- Phishing kit attribution

**Indicators of Compromise (IOCs):**
- IPs, domains, URLs, file hashes associated with campaigns
- Exportable for firewall and proxy blocking
- Integration with threat intel platforms (MISP, ThreatConnect, Anomali)

**People risk (Nexus PRE):**
- Very Attacked People (VAP) list with attack index scores
- Privilege Escalation risk (corporate accounts with high access + high VAP)
- CISO dashboard view for board reporting

## URL Defense — Technical Deep Dive

### URL Encoding Schemes

**Version 2 URL format (legacy):**
```
https://urldefense.proofpoint.com/v2/url?
  u=<base64url-encoded-original>
  &d=<domain-info>
  &c=<campaign-id>
  &r=<recipient-info>
  &m=<message-id>
  &s=<signature>
```

**Version 3 URL format (current):**
```
https://urldefense.com/v3/__<original-url>__;<tracking-token>*
```
More readable, preserves original URL structure better.

### Decoding Proofpoint URLs

For investigation purposes, URL Defense-wrapped URLs can be decoded:
- Version 2: Decode the `u=` parameter from base64url
- Version 3: Extract the portion between `__` delimiters
- Proofpoint provides a URL decoder tool in the TAP portal

### Click Time Protection Flow

```
User clicks URL Defense link
            ↓
Proofpoint URL Defense service receives request
            ↓
Authenticate: Is this a valid Proofpoint-wrapped URL for this tenant?
            ↓
Check URL reputation cache (fast path, sub-100ms)
    ↓ Hit                       ↓ Miss
Return cached verdict       Submit to NexusAI analysis
    ↓                               ↓
Block/Allow                 Follow redirect chain
                            Analyze final destination
                            Browser emulation if needed
                                    ↓
                            Cache verdict
                                    ↓
                            Block/Allow/Warn
```

**Redirect chain analysis:**
Proofpoint follows all redirects (including JavaScript redirects) to find the final destination. Detects:
- URL shortener abuse (bit.ly → malicious page)
- Multi-hop redirect chains
- Time-delayed redirects (page redirects to malware after initial scan)

**Geo-based page serving:**
Some phishing kits serve malicious content only to victims in specific countries. Proofpoint's click-time analysis can use geolocation-appropriate request headers to expose this behavior.

## TRAP Integration Architecture

### M365 Integration (Microsoft Graph API)

```
TRAP Service (Proofpoint Cloud)
    ↓
Azure App Registration
- Tenant ID, Client ID, Client Secret
- API Permissions: Mail.ReadWrite (application level, all mailboxes)
    ↓
Microsoft Graph API
    ↓
Exchange Online Mailboxes
```

**Required app registration permissions:**
- `Mail.ReadWrite` — Application permission (not delegated)
- `Mail.Read` — Application permission
- `MailboxSettings.Read` — For detecting forwarding rules
- `User.Read.All` — For user enumeration during search

**TRAP search query (Graph API):**
```
POST /v1.0/users/{userId}/messages/delta
Filter: internetMessageId eq '<message-id@example.com>'
```

**Remediation action:**
```
DELETE /v1.0/users/{userId}/messages/{messageId}   (permanent delete)
POST /v1.0/users/{userId}/messages/{messageId}/move  (move to Deleted Items)
```

### Google Workspace Integration

```
TRAP Service (Proofpoint Cloud)
    ↓
Google Service Account (domain-wide delegation)
- Service Account Key (JSON)
- Gmail API, Directory API scopes
    ↓
Gmail API
    ↓
Google Workspace Mailboxes
```

**Required scopes:**
- `https://www.googleapis.com/auth/gmail.modify` — Move/label messages
- `https://www.googleapis.com/auth/admin.directory.user.readonly` — Enumerate users

### TRAP Automation Rules

TRAP can be configured with automation rules that apply actions based on threat characteristics:

```
Rule: Auto-remediate TAP malicious (high confidence)
Condition: TAP verdict = Malicious AND confidence >= 90
Action: Move to Deleted Items (all mailboxes)
Notification: Alert to security@example.com

Rule: Analyst queue for medium confidence
Condition: TAP verdict = Malicious AND confidence 60-89
Action: Create alert for analyst review
SLA: 4 hours

Rule: Auto-release not phish (abuse mailbox)
Condition: Abuse mailbox report AND TAP verdict = Clean
Action: Move message back to inbox
Reporter notification: "Message reviewed, not phishing"
```

## Proofpoint Smart Search Database

Smart Search indexes all message metadata for the retention period (default 30 days; up to 90 days or longer with archiving add-on).

**Indexed fields:**
- Envelope sender (MAIL FROM)
- Header From
- Recipients (To, CC, BCC)
- Subject
- Message-ID
- Date/time
- Attachment filenames, types, hashes
- URLs extracted from message body
- Filtering verdicts, scores, policy matches
- Disposition (delivered, quarantined, blocked)
- Spam score, phish score, malware verdict

**Message details view includes:**
- Full routing headers
- SPF/DKIM/DMARC authentication results
- Policy route and rules that matched
- Spam score breakdown (which factors contributed)
- TAP verdict (if applicable)
- URL Defense click data (if applicable)
- All recipients of the same message

## Email Fraud Defense (EFD) — DMARC Management

EFD is Proofpoint's DMARC management module.

### DMARC Report Processing

EFD ingests `rua=` aggregate reports from all receiving mail services (Google, Microsoft, Yahoo, etc.) and:
- Normalizes reports from different providers
- Identifies all email streams sending on behalf of the domain
- Maps sending sources to known services (ESP fingerprinting)
- Tracks authentication pass rates per source over time

### Supplier Risk Module

EFD includes supplier/vendor email risk analysis:
- Monitor DMARC authentication for key suppliers and partners
- Alert when supplier DMARC degrades (may indicate supplier compromise)
- Track lookalike domains registered that could impersonate suppliers

**Lookalike domain monitoring:**
EFD monitors DNS for newly registered domains that resemble the customer's domain or key supplier domains. Alerts on:
- Character substitution registrations
- New TLD registrations for similar names
- Subdomain-based lookalikes

## Performance and Scalability

### Processing Architecture

**Message throughput:**
- Proofpoint cloud handles billions of messages per day across all customers
- Per-tenant throughput scales automatically
- No customer-side rate limits under normal conditions

**Latency:**
- Target: < 60 seconds average processing time (filtering + delivery)
- TAP sandbox adds variable time: 2-8 minutes typical
- Dynamic Delivery eliminates user-perceived latency for Safe Attachments equivalent

**Burst handling:**
- Proofpoint queues inbound mail during downstream mail server outages
- Default queue time: 5 days (configurable)
- Spam queue can be configured to hold or discard during outage

### Proofpoint Email Continuity

Add-on product that provides mailbox access during Exchange/M365 outages:
- Proofpoint spools and delivers mail to an emergency inbox
- Users access email via Proofpoint's web portal or mobile app
- When primary mail server comes back online, Proofpoint syncs held messages
- Provides RTO/RPO guarantees for email continuity SLAs
