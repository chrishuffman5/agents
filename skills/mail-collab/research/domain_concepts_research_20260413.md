# Mail & Collaboration Domain Concepts — Research Reference

> This file is a research artifact for writer agents building mail/collaboration skill files.
> For email security specifics (SPF/DKIM/DMARC/BEC/threat taxonomy), see `agents/security/email-security/references/concepts.md`.
> This document covers the broader domain: protocols, architecture, compliance, migration, and platform comparison.

---

## 1. Email Protocols

### 1.1 SMTP — Simple Mail Transfer Protocol (RFC 5321)

SMTP is the protocol used to transmit email between servers (MTA-to-MTA) and from clients to servers (submission).

**Key port assignments:**
| Port | Use | TLS Mode |
|------|-----|----------|
| 25   | MTA-to-MTA relay | Opportunistic STARTTLS |
| 587  | Client submission (RFC 6409) | STARTTLS required |
| 465  | SMTPS implicit TLS (RFC 8314) | Implicit TLS |

**SMTP session anatomy:**
```
220 mail.example.com ESMTP Postfix
EHLO client.example.net
250-mail.example.com
250-PIPELINING
250-SIZE 52428800
250-STARTTLS
250-AUTH PLAIN LOGIN
250 8BITMIME
STARTTLS
220 2.0.0 Ready to start TLS
[TLS handshake]
MAIL FROM:<sender@example.net>
250 2.1.0 Ok
RCPT TO:<recipient@example.com>
250 2.1.5 Ok
DATA
354 End data with <CR><LF>.<CR><LF>
[message headers and body]
.
250 2.0.0 Ok: queued as ABC123
QUIT
221 2.0.0 Bye
```

**ESMTP extensions relevant to modern deployments:**
- `SIZE` — Advertise maximum message size; client checks before sending large messages
- `STARTTLS` — Upgrade to TLS mid-session (RFC 3207)
- `AUTH` — Client authentication mechanisms (PLAIN, LOGIN, XOAUTH2)
- `PIPELINING` — Send multiple commands without waiting for each response
- `8BITMIME` — Allow 8-bit data in message body (required for UTF-8 headers)
- `SMTPUTF8` — Internationalized email addresses (RFC 6531)
- `CHUNKING` — Send large messages in chunks (BDAT command)

**Submission vs. relay distinction:**
- Port 25 relay must reject AUTH from end clients; should only accept mail from authenticated peers or local networks
- Port 587 requires AUTH before accepting mail; enables per-user tracking and rate limiting
- Mixing submission and relay on port 25 is the classic "open relay" misconfiguration

### 1.2 IMAP — Internet Message Access Protocol (RFC 9051)

IMAP4rev2 (RFC 9051, 2021) supersedes RFC 3501. Allows clients to access mailboxes stored on the server without downloading all messages.

**Key IMAP capabilities:**
- Folder hierarchy with namespace separation (personal, shared, public)
- Server-side search (SEARCH/SORT/THREAD commands)
- Partial fetch — retrieve headers or specific MIME parts without full message download
- IDLE extension — server pushes notifications without polling
- CONDSTORE/QRESYNC — efficient mailbox synchronization, tracks changes since last sync
- OBJECTID — stable identifiers for messages across sessions
- MOVE command (RFC 6851) — atomic server-side move, no copy+delete

**IMAP vs. POP3 architectural difference:**
IMAP keeps mail on the server as the authoritative store; POP3 downloads and (typically) deletes from server. Modern deployments universally prefer IMAP for multi-device access.

**Port assignments:**
- 143: IMAP with STARTTLS
- 993: IMAPS (implicit TLS)

### 1.3 POP3 — Post Office Protocol v3 (RFC 1939)

Legacy download-and-delete protocol. Relevant only for:
- Legacy client compatibility
- Simple mailbox-to-mailbox migration (POP3 harvest)
- Firewall/compliance scenarios where server-side storage is forbidden

**Port assignments:**
- 110: POP3 with STARTTLS
- 995: POP3S (implicit TLS)

POP3 has no folder support, no server-side flags (read/unread), no partial fetch. Do not design new systems around POP3.

### 1.4 JMAP — JSON Meta Application Protocol (RFC 8620, RFC 8621)

JMAP is a modern HTTP/JSON-based protocol designed to replace IMAP and SMTP for client-server communication.

**Key advantages over IMAP:**
- HTTP/2 transport — multiplexed, works through HTTP proxies and CDNs
- JSON instead of a custom text protocol
- Push via HTTP SSE or WebSocket instead of IDLE polling
- Batch operations — multiple mailbox changes in one HTTP request
- Efficient sync — only changed state is transmitted
- Native blob handling for attachments

**JMAP request structure:**
```json
{
  "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
  "methodCalls": [
    ["Email/query", {
      "accountId": "account1",
      "filter": {"inMailbox": "inbox_id"},
      "sort": [{"property": "receivedAt", "isAscending": false}],
      "limit": 50
    }, "call1"],
    ["Email/get", {
      "accountId": "account1",
      "#ids": {"resultOf": "call1", "name": "Email/query", "path": "/ids"}
    }, "call2"]
  ]
}
```

**Adoption:** Fastmail (primary driver), some open-source servers (Cyrus IMAP, Apache James). Not yet supported in Exchange/M365 or Google Workspace natively.

### 1.5 Message Format (RFC 5322, MIME)

**RFC 5322** defines the message format: headers, body, line length limits.

**Core headers:**
| Header | Purpose | Required |
|--------|---------|----------|
| From | Author address | Yes |
| To | Primary recipients | Yes (or Cc/Bcc) |
| Date | Origination timestamp | Yes |
| Message-ID | Unique identifier (`<local@domain>`) | Yes |
| Subject | Human-readable topic | Strongly recommended |
| Reply-To | Override reply destination | Optional |
| In-Reply-To | Thread linking (parent Message-ID) | Optional |
| References | Full thread chain | Optional |
| MIME-Version | Signals MIME encoding (1.0) | When using MIME |
| Content-Type | Body media type | Required for MIME |

**MIME (RFC 2045–2049)** extends RFC 5322 to support binary attachments, multiple body parts, and non-ASCII content.

**MIME Content-Type hierarchy:**
```
multipart/mixed              ← Top-level: text + attachments
├── multipart/alternative    ← Text: plain + HTML versions
│   ├── text/plain
│   └── text/html
├── application/pdf          ← Attachment
└── image/png                ← Inline image (Content-Disposition: inline)
```

**Content-Transfer-Encoding:**
- `7bit` — ASCII only, no encoding needed
- `quoted-printable` — For mostly-ASCII with some non-ASCII (email body text)
- `base64` — For binary data (attachments, images)
- `8bit` — Raw 8-bit (requires 8BITMIME ESMTP extension)

**Internationalization:**
- RFC 2047 encoded-words for non-ASCII in headers: `=?UTF-8?B?base64data?=`
- RFC 6532 (SMTPUTF8) for UTF-8 in headers directly
- RFC 6531 for internationalized email addresses (IDN domains, non-ASCII local parts)

---

## 2. DNS Records for Email

### 2.1 MX Records

MX records specify which servers accept mail for a domain. Lower preference values = higher priority.

```dns
; Multiple MX records with failover
example.com.    IN  MX  10  mail1.example.com.
example.com.    IN  MX  20  mail2.example.com.
example.com.    IN  MX  30  mail-backup.example.com.

; M365 MX record (tenant-specific)
example.com.    IN  MX  0   example-com.mail.protection.outlook.com.

; Google Workspace MX records
example.com.    IN  MX  1   aspmx.l.google.com.
example.com.    IN  MX  5   alt1.aspmx.l.google.com.
example.com.    IN  MX  5   alt2.aspmx.l.google.com.
example.com.    IN  MX  10  alt3.aspmx.l.google.com.
example.com.    IN  MX  10  alt4.aspmx.l.google.com.
```

**MX record design considerations:**
- Never point MX directly to an IP address (only hostnames)
- MX hostname must have a corresponding A/AAAA record (no CNAME chain)
- Multiple MX records provide load balancing and failover, not both simultaneously — all are tried in preference order before failing
- TTL: 300–3600 for active domains; lower TTL before planned changes

### 2.2 SPF (TXT Record)

```dns
; Basic SPF for M365
example.com.    IN  TXT  "v=spf1 include:spf.protection.outlook.com -all"

; Google Workspace
example.com.    IN  TXT  "v=spf1 include:_spf.google.com -all"

; Complex multi-sender SPF
example.com.    IN  TXT  "v=spf1 include:spf.protection.outlook.com include:_spf.google.com include:sendgrid.net ip4:203.0.113.0/24 -all"

; SPF with subdomain delegation (reduces main record lookups)
mail.example.com.  IN  TXT  "v=spf1 ip4:203.0.113.10 ip4:203.0.113.11 -all"
```

See `agents/security/email-security/references/concepts.md` for full SPF mechanism details and lookup limit management.

### 2.3 DKIM (TXT Record)

```dns
; Standard RSA 2048-bit DKIM record
selector1._domainkey.example.com.  IN  TXT  (
  "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA"
  "2mX3MvPlaceholder0GCSqGSIb3DQEBAQUAA4IBDAAMI..."
  "AQAB" )

; Ed25519 DKIM record (smaller key)
ed25519._domainkey.example.com.  IN  TXT  "v=DKIM1; k=ed25519; p=11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo="

; M365 auto-provisioned DKIM (CNAME-based delegation)
selector1._domainkey.example.com.  IN  CNAME  selector1-example-com._domainkey.example.onmicrosoft.com.
selector2._domainkey.example.com.  IN  CNAME  selector2-example-com._domainkey.example.onmicrosoft.com.

; Revoked/disabled key (empty p= removes key from service)
old-selector._domainkey.example.com.  IN  TXT  "v=DKIM1; p="
```

### 2.4 DMARC (TXT Record)

```dns
; Stage 1: Monitor only
_dmarc.example.com.  IN  TXT  "v=DMARC1; p=none; rua=mailto:dmarc-agg@example.com; ruf=mailto:dmarc-forensic@example.com; fo=1"

; Stage 2: Quarantine with pct rollout
_dmarc.example.com.  IN  TXT  "v=DMARC1; p=quarantine; pct=25; rua=mailto:dmarc-agg@example.com; adkim=r; aspf=r"

; Stage 3: Full enforcement
_dmarc.example.com.  IN  TXT  "v=DMARC1; p=reject; pct=100; rua=mailto:dmarc@example.com; ruf=mailto:dmarc-forensic@example.com; adkim=s; aspf=r; fo=1"

; Subdomain policy override (stricter than parent)
_dmarc.marketing.example.com.  IN  TXT  "v=DMARC1; p=reject; sp=reject; rua=mailto:dmarc@example.com"
```

**DMARC tag reference:**
| Tag | Values | Description |
|-----|--------|-------------|
| `p=` | none / quarantine / reject | Policy for From domain |
| `sp=` | none / quarantine / reject | Policy for subdomains (overrides p= for subs) |
| `pct=` | 0–100 | Percentage of messages to apply policy to |
| `rua=` | mailto: URI list | Aggregate report destinations |
| `ruf=` | mailto: URI list | Forensic/failure report destinations |
| `adkim=` | r (relaxed) / s (strict) | DKIM alignment mode |
| `aspf=` | r (relaxed) / s (strict) | SPF alignment mode |
| `fo=` | 0 / 1 / d / s | Forensic report trigger (1 = any failure) |
| `ri=` | seconds (default 86400) | Aggregate report interval |

### 2.5 ARC — Authenticated Received Chain (RFC 8617)

ARC preserves authentication results through mail forwarders and mailing lists, solving the SPF/DKIM breakage problem in forwarding chains.

**How ARC works:**
1. Each mail handler that modifies a message adds three ARC headers:
   - `ARC-Authentication-Results` (AAR) — Authentication results seen at this hop
   - `ARC-Message-Signature` (AMS) — DKIM-like signature over the message at this point
   - `ARC-Seal` (AS) — Signature over the full ARC chain to date
2. Final receiver evaluates the ARC chain and may trust authentication results from an ARC-trusted intermediary

**ARC DNS record (for ARC signing key):**
```dns
; ARC signing is done with a DKIM-format key
arc._domainkey.forwarder.example.com.  IN  TXT  "v=DKIM1; k=rsa; p=MIIBIjAN..."
```

**ARC headers in a forwarded message:**
```
ARC-Seal: i=1; a=rsa-sha256; cv=none; d=forwarder.example.com; s=arc;
  t=1704067200; b=base64signature...
ARC-Message-Signature: i=1; a=rsa-sha256; c=relaxed/relaxed;
  d=forwarder.example.com; s=arc; h=From:To:Subject:Date;
  bh=bodyhash; b=signature...
ARC-Authentication-Results: i=1; mx.forwarder.example.com;
  dkim=pass header.d=original.com;
  spf=pass smtp.mailfrom=original.com;
  dmarc=pass
```

**Adoption:** Gmail and M365 both validate and generate ARC headers. Required for mailing list operators and forwarding services to avoid DMARC failures.

### 2.6 BIMI (TXT Record)

```dns
; BIMI with Verified Mark Certificate (VMC)
default._bimi.example.com.  IN  TXT  "v=BIMI1; l=https://example.com/logo.svg; a=https://example.com/vmc.pem"

; BIMI without VMC (works with Yahoo Mail, not Gmail)
default._bimi.example.com.  IN  TXT  "v=BIMI1; l=https://example.com/logo.svg"

; Per-selector BIMI (for subdomains)
marketing._bimi.example.com.  IN  TXT  "v=BIMI1; l=https://example.com/marketing-logo.svg; a=https://example.com/marketing-vmc.pem"
```

**BIMI requirements:**
1. DMARC at `p=quarantine` or `p=reject` (p=none is insufficient)
2. Logo: SVG Tiny P/S format, hosted at HTTPS (no redirects)
3. Verified Mark Certificate (VMC): Required for Gmail, Apple Mail; issued by DigiCert or Entrust
4. VMC process: Trademark registration required (USPTO, EUIPO, etc.) → CA validates trademark → issues VMC certificate

**Client support matrix:**
| Client | BIMI Support | VMC Required |
|--------|-------------|-------------|
| Gmail | Yes (2021) | Yes |
| Yahoo Mail | Yes (2021) | No |
| Apple Mail (iOS 16+/macOS Ventura+) | Yes | Yes |
| Fastmail | Yes | No |
| Outlook.com | No (as of 2025) | N/A |
| Exchange/M365 (desktop Outlook) | No | N/A |

### 2.7 DANE — DNS-Based Authentication of Named Entities (RFC 7671, RFC 7672)

DANE uses TLSA records in DNSSEC-signed zones to pin expected TLS certificates for SMTP connections, preventing downgrade attacks without relying on public CAs.

```dns
; DANE TLSA record for SMTP
; Usage: 3 = DANE-EE (domain-issued certificate)
; Selector: 1 = SubjectPublicKeyInfo
; Matching type: 1 = SHA-256
_25._tcp.mail.example.com.  IN  TLSA  3 1 1  abc123def456...sha256hash...

; Usage field values:
; 0 = PKIX-TA (CA constraint)
; 1 = PKIX-EE (certificate constraint)
; 2 = DANE-TA (trust anchor — your own CA)
; 3 = DANE-EE (domain-issued — most common for SMTP)
```

**DANE vs. MTA-STS comparison:**
| Feature | DANE | MTA-STS |
|---------|------|---------|
| Requires DNSSEC | Yes (mandatory) | No |
| Certificate pinning | Yes (specific cert/key) | No (any valid cert) |
| Policy caching | DNSSEC TTL | Up to max_age (weeks) |
| Deployment complexity | High (DNSSEC + TLSA) | Low (DNS TXT + HTTPS file) |
| Adoption | Limited (mostly European ISPs) | Growing (M365, Google support) |
| Prevents downgrade | Yes | Yes |

**DANE deployment prerequisite:** The sending domain must have DNSSEC signed, AND the receiving domain must publish TLSA records. Both sides must support DANE validation. Postfix supports DANE natively with `smtp_tls_security_level = dane`.

### 2.8 MTA-STS (RFC 8461)

MTA-STS enforces TLS for SMTP without DNSSEC. Two components: a DNS TXT record and a policy file hosted over HTTPS.

```dns
; DNS TXT record (signals policy exists, with change ID)
_mta-sts.example.com.  IN  TXT  "v=STSv1; id=20240101T000000"
```

**Policy file** (hosted at `https://mta-sts.example.com/.well-known/mta-sts.txt`):
```
version: STSv1
mode: enforce
mx: mail.example.com
mx: *.example.com
max_age: 604800
```

**Policy modes:**
- `testing` — Report failures but deliver anyway
- `enforce` — Reject delivery if TLS cannot be established with a valid certificate
- `none` — Withdraw a previously published policy

**MTA-STS operational notes:**
- The `id` value in the DNS record signals policy changes; sending MTAs check this to know when to re-fetch the policy
- `max_age` defines how long sending MTAs cache the policy (up to ~31,557,600 seconds / 1 year)
- Certificate must be valid (trusted CA chain, matching hostname), not self-signed
- Use `mode: testing` first to identify failures via TLS-RPT before switching to `enforce`

### 2.9 SMTP TLS Reporting — TLS-RPT (RFC 8460)

```dns
; TLS-RPT DNS record
_smtp._tls.example.com.  IN  TXT  "v=TLSRPTv1; rua=mailto:tls-reports@example.com"

; Multiple report destinations
_smtp._tls.example.com.  IN  TXT  "v=TLSRPTv1; rua=mailto:tls-reports@example.com,https://tlsrpt.example.com/v1"
```

TLS-RPT sends JSON reports daily showing MTA-STS and DANE policy failures. Essential during MTA-STS testing phase to identify senders that cannot establish TLS.

---

## 3. Email Security — Authentication Chain & TLS

> For complete SPF/DKIM/DMARC mechanics, threat taxonomy, and BEC patterns, see `agents/security/email-security/references/concepts.md`. This section covers the integrative view.

### 3.1 The Authentication Chain

```
SMTP MAIL FROM (envelope sender)
         ↓
    [SPF Check]  ←── DNS TXT for envelope domain
         ↓
    SPF result: pass / fail / softfail / neutral / none / permerror
         ↓
DKIM-Signature header in message
         ↓
    [DKIM Check]  ←── DNS TXT for selector._domainkey.signing-domain
         ↓
    DKIM result: pass / fail / none / policy / neutral / temperror / permerror
         ↓
RFC5322.From (visible From header)
         ↓
    [DMARC Check]  ←── DNS TXT for _dmarc.from-domain
         ↓
    Alignment: Does SPF MAIL FROM or DKIM d= align with From domain?
         ↓
    Policy decision: none / quarantine / reject
         ↓
    ARC (if present)  ←── Can rescue DMARC fails from trusted forwarders
```

### 3.2 TLS Encryption in SMTP

**STARTTLS (opportunistic):**
- Client connects to port 25, exchanges EHLO
- Server advertises `STARTTLS` in EHLO capabilities
- Client issues `STARTTLS` command; both parties perform TLS handshake
- Connection continues encrypted, but fallback to plaintext is possible if TLS fails
- Vulnerable to STARTTLS stripping (attacker removes STARTTLS from EHLO response)

**Implicit TLS (port 465):**
- TLS negotiated immediately before any SMTP commands
- No STARTTLS downgrade possible
- Preferred for submission (client-to-server)

**STARTTLS stripping mitigation:**
- MTA-STS: Prevents delivery if TLS cannot be established
- DANE: Pins specific certificate, prevents interception
- HSTS-style preloading: Google Safe Browsing HTTPS preload for domains (limited SMTP application)

### 3.3 Certificate Management for Mail Servers

**Certificate types for mail:**
- Public CA certificate (Let's Encrypt, DigiCert, Sectigo) — required for MTA-STS
- Self-signed — acceptable only for internal relay hops where you control both ends
- Wildcard — `*.example.com` covers `mail.example.com`, `smtp.example.com`, etc.

**SAN requirements:** Certificate CN or SAN must match the MX hostname (not just the domain). If MX record points to `mail.example.com`, certificate must include `mail.example.com`.

**Certificate rotation for SMTP:**
- Renew before expiry (Let's Encrypt: every 60–75 days; commercial: annually or every 2 years)
- Reload SMTP service after renewal (Postfix: `postfix reload`; Exchange: restart transport services)
- Monitor expiry with alerting (PRTG, Nagios, Datadog, custom scripts)

---

## 4. Mail Flow Architecture

### 4.1 Core Components

**MTA — Mail Transfer Agent:**
The server that routes and relays email between domains using SMTP. Responsible for queue management, retry scheduling, and delivery.
- Examples: Postfix, Exim, Sendmail, Microsoft Exchange Transport, Google's Mailer Daemon

**MDA — Mail Delivery Agent:**
Delivers messages into the user's mailbox store. Runs after the MTA has accepted a message destined for a local user.
- Examples: Procmail (legacy), Dovecot LDA/LMTP, Cyrus deliver, Exchange Mailbox Transport

**MUA — Mail User Agent:**
The client application the end user interacts with to compose, read, and manage email.
- Examples: Outlook, Thunderbird, Apple Mail, Gmail web interface, mobile mail apps

**MSA — Mail Submission Agent:**
Accepts outbound mail from authenticated clients on port 587. Often integrated with the MTA but logically distinct — applies per-user policies, requires AUTH.

### 4.2 Canonical Mail Flow Diagram

```
[MUA] ──587/TLS──> [MSA/MTA (Outbound)]
                          │
                     DKIM sign
                     SPF authorize
                          │
                    MX lookup for recipient domain
                          │
                   ──25/TLS──> [Receiving MTA]
                                    │
                               SPF check
                               DKIM verify
                               DMARC evaluate
                               Content filter
                                    │
                               [MDA / LMTP]
                                    │
                            [Mailbox Store]
                                    │
                              ──IMAP/993──> [MUA]
```

### 4.3 Smart Host / Relay Configuration

A **smart host** is an intermediate MTA that handles outbound delivery on behalf of another MTA. Used when:
- The sending MTA cannot perform direct MX delivery (ISP blocking port 25)
- Centralized egress logging, filtering, or DLP is required
- On-prem servers route outbound through a cloud hygiene service (Proofpoint, Mimecast)

**Postfix smart host configuration:**
```ini
# /etc/postfix/main.cf
relayhost = [smtp.provider.example.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
```

**M365 connector for on-prem smart host:**
- Inbound connector: Accept from on-prem MTA IP range
- Outbound connector: Route to on-prem (hybrid) or to external service

### 4.4 Edge Transport / Perimeter Architecture

In enterprise deployments, the perimeter architecture layers protection before messages reach the primary mail server:

```
Internet
    │
[DNS / IP Reputation Block]  ← DNSBLs (Spamhaus, Barracuda, etc.)
    │
[Edge MTA / SEG]             ← Proofpoint, Mimecast, or Exchange Edge Transport
    │  ├── SPF/DKIM/DMARC check
    │  ├── Anti-spam scoring
    │  ├── Anti-malware scanning
    │  ├── URL rewriting
    │  └── Content policy
    │
[Internal MTA / Hub Transport]
    │
[Mailbox Server / Cloud Tenant]
    │
[MDA → Mailbox]
```

**Exchange Edge Transport role:**
- Deployed in the DMZ, not domain-joined
- Subscribes to hub transport via Edge Sync (one-way AD replication)
- Handles connection filtering, recipient filtering, content filtering
- In modern Exchange/M365 hybrid, often replaced by third-party SEG

### 4.5 Content Filtering Pipeline

Content filtering processes messages in a defined order. The exact pipeline varies by platform:

**Typical inbound filtering order:**
1. Connection-level: IP reputation, rate limiting, TLS enforcement
2. Envelope-level: Recipient validation, SPF check
3. Header-level: DKIM verification, DMARC evaluation
4. Message-level: Anti-spam scoring (Bayesian, heuristic, ML models)
5. Attachment-level: Anti-malware scan, file type blocking, sandboxing
6. URL-level: Reputation check, detonation sandbox
7. Content policy: DLP rules, keyword scanning, regex patterns
8. Delivery decision: Accept/quarantine/reject, tag/route

**Content filtering outcomes:**
- **Accept**: Deliver to mailbox as normal
- **Quarantine**: Hold in spam/quarantine folder or admin quarantine
- **Tag**: Modify subject or add header, deliver to inbox (allows end-user decision)
- **Reject (550)**: Permanent failure; sender receives NDR
- **Defer (421/450)**: Temporary failure; sender will retry
- **Drop (blackhole)**: Accept message but discard silently (use sparingly — hides problems)

### 4.6 Milter Interface

**Milter** (mail filter) is the interface between an MTA (Postfix, Sendmail) and external content filters. Filters connect as daemons over a Unix socket or TCP socket.

```ini
# Postfix milter configuration
smtpd_milters = inet:127.0.0.1:8891,unix:/var/run/clamav-milter/clamav-milter.ctl
non_smtpd_milters = inet:127.0.0.1:8891
milter_default_action = accept
milter_protocol = 6
```

**Common milter implementations:**
- **OpenDKIM** — DKIM signing and verification
- **OpenDMARC** — DMARC evaluation and reporting
- **ClamAV Milter** — Anti-malware scanning
- **SpamAssassin (SpamD)** — Anti-spam scoring via spamd and spamc
- **Rspamd** — Modern all-in-one milter (anti-spam, DKIM, DMARC, SPF, greylisting)

**Milter actions:** Accept, reject (with custom SMTP error code), discard, quarantine, add/remove/change headers, add/remove recipients.

---

## 5. Compliance & Governance

### 5.1 Retention Policies

Retention policies define how long email is kept and when it is deleted. Requirements differ by regulation and organization type.

**Regulatory retention minimums (common):**
| Regulation | Sector | Retention Period |
|-----------|--------|-----------------|
| SEC Rule 17a-4 | Financial services | 3 years (broker-dealer), 6 years (investment advisors) |
| FINRA Rule 4511 | Financial services | 6 years |
| HIPAA | Healthcare | 6 years (medical records; email containing PHI) |
| Sarbanes-Oxley (SOX) | Public companies | 7 years (audit-related communications) |
| GDPR | EU organizations | Minimum necessary; retention limitation principle |
| CIPA | Education | Varies; typically 3–5 years |
| IRS / Tax records | All US businesses | 7 years |

**Retention policy implementation:**
- **M365**: Retention policies and retention labels in Microsoft Purview Compliance. Policies apply to Exchange Online mailboxes, Teams, SharePoint. Retention tags with Managed Folder Assistant enforcement.
- **Google Workspace**: Google Vault retention rules, custom retention by OU, retention by search query (holds are separate from retention).
- **On-prem Exchange**: Messaging Records Management (MRM), retention tags, managed folders, retention policy applied to mailbox.

### 5.2 Legal Hold / Litigation Hold

Legal hold preserves all content for a custodian (user) regardless of retention policies. Content cannot be deleted while hold is active, even by the user.

**M365 Litigation Hold:**
```powershell
# Enable litigation hold on a mailbox
Set-Mailbox -Identity "user@example.com" -LitigationHoldEnabled $true -LitigationHoldDuration 2555

# Verify hold status
Get-Mailbox "user@example.com" | Select LitigationHoldEnabled, LitigationHoldDuration, LitigationHoldDate
```

**Google Vault Hold:**
- Vault > Matters > Holds: Apply by account, OU, or search criteria
- Hold preserves all Drive, Gmail, Chat, Meet recordings for covered users
- Holds override Vault retention rules (hold takes precedence)

**Key distinction — retention vs. hold:**
- Retention: Routine lifecycle management — keep for N years, then delete
- Hold: Legal preservation — override retention, keep until hold released by legal team
- Items under hold are preserved in recoverable items / Vault, invisible to user but discoverable

### 5.3 eDiscovery

eDiscovery (electronic discovery) is the process of searching, collecting, and producing electronically stored information (ESI) for litigation, regulatory investigation, or audit.

**M365 eDiscovery workflow:**
1. Create eDiscovery case in Microsoft Purview
2. Add custodians (users) — places hold automatically
3. Define search: keywords, date range, senders/recipients, locations (Exchange, Teams, SharePoint, OneDrive)
4. Review set: Export results, review in built-in viewer or import to review platform
5. Export: PST, loose files, or review platform export format

**Google Vault eDiscovery workflow:**
1. Create Matter in Google Vault
2. Add accounts or entire OUs to Matter
3. Search Gmail, Drive, Chat, Groups, Voice, Meet with boolean operators
4. Export: MBOX (Gmail), JSON (Chat), individual files (Drive)

**GDPR and eDiscovery tension:** GDPR's right to erasure conflicts with litigation hold obligations. Legal holds take precedence over erasure requests when litigation is reasonably anticipated (documented legal hold notice required).

### 5.4 Journaling

Journaling captures a copy of every message (or a filtered subset) and sends it to an external archive. Differs from retention policies — creates an immutable copy outside the primary mailbox.

**Exchange/M365 journaling:**
```powershell
# Create journal rule in Exchange Online
New-JournalRule -Name "All Messages Journal" `
  -JournalEmailAddress archive@vault.example.com `
  -Scope Global `
  -Enabled $true
```

**Journaling targets:**
- Third-party archiving platforms (Mimecast Archive, Smarsh, Global Relay, Veritas Enterprise Vault)
- On-prem journal mailbox
- Compliance SMTP endpoint with encryption

**Journal vs. archive distinction:**
- Journal: Real-time copy of every message, stored externally, immutable
- Archive: Moved or copied messages, stored within the platform (Exchange Online Archiving, Google Vault), subject to the platform's controls

**Envelope journaling:** Captures the full SMTP envelope (all BCC recipients, original routing) plus the message. Required for regulatory compliance where BCC recipients must be captured.

### 5.5 Data Loss Prevention (DLP)

DLP policies inspect message content and attachments for sensitive data patterns and enforce actions.

**Common DLP sensitive information types:**
- Credit card numbers (Luhn algorithm validation)
- SSN / national ID numbers
- IBAN / financial account numbers
- Protected Health Information (PHI): ICD codes, medical record numbers, drug names in context
- Passport numbers
- Driver's license numbers (state-specific patterns)
- Custom regex patterns: internal project codes, part numbers, classification markings

**DLP policy actions:**
| Action | M365 | Google Workspace |
|--------|------|-----------------|
| Block send | Yes | Yes |
| Quarantine | Yes | Limited |
| Encrypt | Yes (OME) | Yes (CSE/S/MIME) |
| Notify sender | Yes | Yes |
| Notify compliance officer | Yes | Yes |
| Apply label/classification | Yes (sensitivity labels) | Yes (classification) |
| Allow with business justification | Yes (override workflow) | Limited |

**DLP false positive management:**
- Use confidence levels (medium vs. high) — require multiple pattern matches
- Combine patterns: SSN pattern + proximity to "social security" keyword
- User-reported overrides with audit trail
- Regular policy tuning based on reported false positives

### 5.6 Email Archiving

**Native platform archiving:**
- **M365**: Exchange Online Archiving (EOA) — In-place archive mailbox, accessible from Outlook; auto-expanding archive for large mailboxes; integrated with Purview compliance
- **Google Vault**: Integrated Vault for Gmail; search/export/hold; not a separate mailbox, operates on all Gmail data

**Third-party archiving:**
| Vendor | Strengths | Typical Use Case |
|--------|-----------|-----------------|
| Mimecast Archive | Journaling + compliance search | Financial services, legal |
| Smarsh | SEC/FINRA compliance, social media archiving | Broker-dealers |
| Global Relay | FINRA-tested, supervision workflows | Capital markets |
| Veritas Enterprise Vault | On-prem/hybrid, Exchange-native, PST elimination | Large enterprises |
| Barracuda Message Archiver | SMB-friendly, on-prem or cloud | Mid-market |
| Proofpoint Essentials Archive | Bundled with Proofpoint SEG | Security-first orgs |

**Archive strategy decision framework:**
- Regulatory requirement mandates immutable external copy → Third-party archiving with journaling
- Need supervision/review workflows (FINRA 3110) → Smarsh, Global Relay, Mimecast
- Simple litigation readiness → Native (M365 Purview / Google Vault) sufficient
- PST elimination + archive migration → Veritas Enterprise Vault, Mimecast

---

## 6. Migration Patterns

### 6.1 On-Premises to Cloud Migration

**Common source environments:** Exchange Server 2010/2013/2016/2019, Lotus Notes, GroupWise, on-prem hosted solutions

**Migration types:**

| Type | Description | Best For |
|------|-------------|----------|
| Cutover | All mailboxes migrated in one batch; MX cut simultaneously | <150 mailboxes, no coexistence needed |
| Staged | Batches over weeks/months; hybrid coexistence during migration | 150–2000 mailboxes |
| Hybrid (Express or Full) | HCR (Hybrid Configuration Wizard) sets up coexistence; RBAC, free/busy, calendar sharing work cross-premise | >2000 mailboxes, complex requirements |
| IMAP migration | Generic protocol; no calendar/contacts, limited to email | Non-Exchange source (Lotus Notes, Dovecot, Cyrus) |
| PST import | Bulk import of PST files to cloud mailboxes | Archive migration, PST elimination projects |

**Hybrid migration technical components:**
- Hybrid Configuration Wizard (HCW) — automates connector setup, certificate sharing, federation trust
- Exchange Hybrid Agent — allows hybrid without on-prem inbound connectors (outbound only)
- OAuth authentication — enables modern auth for hybrid free/busy, cross-premises delegation
- Mailbox Replication Service (MRS) — handles the actual mailbox move, batched

**Hybrid mail flow options:**
- **Centralized transport**: All outbound routes through on-prem (for SEG, DLP, compliance)
- **Decentralized transport**: Cloud mailboxes send direct; on-prem sends through on-prem MTA
- Split transport is possible but complex — avoid unless required

### 6.2 Cloud-to-Cloud Migration (M365 ↔ Google Workspace)

**M365 to Google Workspace:**
- Tools: Google Workspace Migration for Microsoft Exchange (GWMME), Google Workspace Migration for Microsoft Outlook (GWMMO), third-party (BitTitan MigrationWiz, CloudM, Cloudficient)
- Migrates: Email (IMAP), Calendar (Exchange Web Services/EWS or Graph API), Contacts
- Does NOT migrate: Tasks (no 1:1 equivalent), Notes, PST archives (separate process), Team mailboxes to Groups (manual)
- Coexistence via SMTP relay and calendar sharing during migration window

**Google Workspace to M365:**
- Tools: Microsoft FastTrack (free for >150 seats), BitTitan MigrationWiz, CloudM, Quadrotech
- Migrates: Gmail (IMAP), Calendar (Google API), Contacts (Google API)
- Does NOT migrate: Google Chat history, Google Meet recordings, Google Sites (require separate handling)
- Coexistence: Limited; Google Workspace → M365 calendar sharing requires Workspace-side configuration

### 6.3 Tenant-to-Tenant Migration (M365 to M365)

Tenant-to-tenant migrations occur during mergers, acquisitions, divestitures, or rebranding.

**Native tooling limitations:**
- No Microsoft-native tenant-to-tenant email migration tool
- Cross-tenant mailbox migration (CTMM) exists for Exchange Online in M365 but requires:
  - Organizational relationship established between tenants
  - Admin consent from both tenants
  - Azure AD setup in target tenant

**Third-party tools for T2T:**
- BitTitan MigrationWiz — widely used; supports mailbox, Teams, SharePoint, OneDrive
- Cloudficient — specializes in large M365 migrations; pre-migration analysis
- Quest On Demand Migration — AD + M365; strong identity migration
- AvePoint Fly — M365 + Google; includes governance

**T2T coexistence challenges:**
- UPN conflicts: same username exists in both tenants
- SMTP namespace conflicts: same email addresses in both tenants (e.g., @company.com)
- Calendar/free-busy: Requires federation trust or manual sharing configuration
- Teams: No native migration; teams/channels/chat must be recreated or migrated with third-party tooling

**Address space coexistence options:**
1. **Subdomain split**: Source uses @company.com, target uses @newcompany.com during transition
2. **Alias-based routing**: User has @company.com alias in both tenants; routing determined by MX
3. **Shared address space**: Both tenants accept @company.com; requires cross-tenant connector configuration

### 6.4 Hybrid Coexistence — Split Delivery and Shared Namespace

**Split delivery** (shared SMTP namespace): Both on-prem and cloud servers host mailboxes under the same domain (e.g., @contoso.com). Inbound MX routes to one location, which must route to the other.

**Exchange-based split delivery routing:**
```
External sender → MX → Exchange Online Protection (EOP)
    → If mailbox in cloud: deliver
    → If mailbox on-prem: cross-premises routing via hybrid send connector → Exchange on-prem
```

```
External sender → MX → On-prem Exchange
    → If mailbox on-prem: deliver
    → If mailbox in cloud: route via Send Connector → Exchange Online
```

**Hybrid coexistence features (Exchange hybrid):**
| Feature | Requires | Notes |
|---------|---------|-------|
| Free/busy cross-premises | Hybrid auth (OAuth) | Works after HCW + federation |
| Cross-premises calendar delegation | OAuth + hybrid | Limited; proxy access works better |
| Mailbox move without disruption | MRS + hybrid | Users keep same email address |
| Unified Global Address List | AD sync (Entra Connect) | On-prem AD replicated to Entra ID |
| Cross-premises mail flow | Hybrid connectors | Secure channel, no re-authentication |
| Cross-premises OWA redirect | Hybrid auth | Redirect to cloud/on-prem OWA |

**Google Workspace hybrid with on-prem:**
Google does not have a native "hybrid" mode equivalent to Exchange. Options:
- Dual delivery: Email delivered to both on-prem and Google simultaneously (for migration testing)
- Split delivery: Route based on recipient — some to on-prem, some to Google
- SMTP relay: On-prem routes outbound through Google; inbound via Google MX to on-prem SMTP relay

---

## 7. Collaboration Platforms Comparison: M365 vs. Google Workspace

### 7.1 Feature Mapping

| Capability | M365 | Google Workspace |
|-----------|------|-----------------|
| **Email** | Exchange Online | Gmail |
| **Calendar** | Outlook Calendar | Google Calendar |
| **Contacts** | Outlook Contacts / Entra ID | Google Contacts |
| **Chat/IM** | Microsoft Teams | Google Chat |
| **Video Conferencing** | Teams Meetings | Google Meet |
| **File Storage** | OneDrive (personal) | Google Drive (personal) |
| **Team File Storage** | SharePoint / Teams channel | Shared Drives (Team Drives) |
| **Office Suite (online)** | Office for the web | Google Docs/Sheets/Slides |
| **Office Suite (desktop)** | Microsoft 365 Apps (Windows/Mac) | No native desktop apps |
| **Email Client (desktop)** | Outlook (Windows/Mac/mobile) | No native client (web + mobile) |
| **Whiteboard** | Microsoft Whiteboard | Google Jamboard (discontinued 2024) / Miro integration |
| **Task Management** | Microsoft To Do / Planner / Project | Google Tasks / Google Workspace Frontline |
| **Forms/Surveys** | Microsoft Forms | Google Forms |
| **Notes** | Microsoft OneNote | Google Keep |
| **Wiki/Pages** | SharePoint / Loop | Google Sites / Notion (third-party) |
| **Directory** | Entra ID (Azure Active Directory) | Google Cloud Identity / Cloud Directory |
| **SSO/IdP** | Entra ID | Google Identity (Cloud Identity) |
| **MDM/Device Management** | Microsoft Intune / Entra ID Join | Google Endpoint Management (MDM) |
| **Email Security (native)** | Exchange Online Protection + Defender for Office 365 | Google's anti-spam/anti-phishing (no advanced tier by default) |
| **Email Archive/Compliance** | Microsoft Purview (Exchange Online Archiving, Purview Compliance) | Google Vault |
| **DLP** | Microsoft Purview DLP | Google Workspace DLP |
| **eDiscovery** | Microsoft Purview eDiscovery | Google Vault |
| **SIEM Integration** | Microsoft Sentinel (native) | Chronicle (native via Google SecOps) |

### 7.2 Licensing Comparison

**Microsoft 365 Business tiers:**
| Plan | Price/user/mo (2025) | Key Inclusions |
|------|---------------------|----------------|
| M365 Business Basic | $6 | Web/mobile Office, Exchange 50GB, Teams, SharePoint, 1TB OneDrive |
| M365 Business Standard | $12.50 | + Desktop Office apps, Bookings, Webinars |
| M365 Business Premium | $22 | + Intune, Entra ID P1, Defender for Business, Azure Information Protection P1 |
| M365 E3 | $36 | + Compliance (Purview E3), no desktop Office audio conferencing |
| M365 E5 | $57 | + Defender for O365 P2, Purview E5, Power BI Pro, Phone System |

**Google Workspace tiers:**
| Plan | Price/user/mo (2025) | Key Inclusions |
|------|---------------------|----------------|
| Business Starter | $6 | Gmail, 30GB pooled storage, Meet (100 participants), Docs/Sheets/Slides |
| Business Standard | $12 | + 2TB pooled storage, Meet (150+recording), Shared Drives |
| Business Plus | $18 | + 5TB pooled storage, Vault, Advanced Meet (500 participants, attendance tracking) |
| Enterprise Standard | $23 | + eDiscovery, audit, S/MIME, DLP, advanced security |
| Enterprise Plus | Custom pricing | + Data regions, client-side encryption, advanced compliance |

**Licensing decision factors:**
- Desktop Office apps required → M365 (Business Standard+); Google has no desktop equivalent
- Advanced email security included → M365 E5 includes Defender for Office 365 P2; Google requires add-on
- eDiscovery/compliance → M365 E3/E5 Purview vs. Google Vault (Vault included in Business Plus+)
- Cost sensitivity, simplicity, all-web workforce → Google Workspace

### 7.3 Hybrid Scenarios

**M365 + Google Workspace coexistence:**
Rare but occurs during long migrations or in organizations that acquired companies on different platforms.

- **Mail routing**: Use a routing MTA (Postfix or Exchange) to split delivery by domain/user
- **Calendar sharing**: No native free/busy federation between M365 and Google; requires CalDAV bridges (not officially supported) or migration
- **GAL sync**: Use Azure AD Connect + Google Directory Sync for dual-directory, or Tools4ever / Okta for bidirectional sync
- **SSO**: Federate both platforms to a common IdP (Okta, PingFederate) for unified SSO

**Exchange on-prem + M365 hybrid (most common enterprise hybrid):**
Described in Section 6.4. This is the standard Microsoft hybrid with full coexistence support.

**Exchange on-prem + Google Workspace (migration scenario):**
- On-prem Exchange as source; Google Workspace as destination
- Use GWMME (Google Workspace Migration for Microsoft Exchange) — reads from Exchange via EWS/MAPI
- Mail routing: Point MX to Google, configure Google inbound routing to pass through on-prem during pilot
- Coexistence: Limited; maintain split MX or dual delivery during migration window

### 7.4 Collaboration Platform Decision Framework

```
Is desktop Microsoft Office required?
├── Yes → Microsoft 365 (Business Standard or above)
└── No → Evaluate both

Is deep Microsoft ecosystem integration required?
(Azure, Intune, Entra ID, Dynamics, Power Platform)
├── Yes → Microsoft 365
└── No → Evaluate both

Is advanced compliance/eDiscovery a requirement?
├── M365 Purview E3/E5 → Microsoft 365 Enterprise
├── Google Vault (Business Plus+) sufficient → Google Workspace
└── Third-party regardless → Either platform

Primary use case: document collaboration and real-time editing?
├── Multiple simultaneous editors, browser-first → Google Workspace (superior real-time co-authoring)
├── Rich formatting, complex documents, Excel power users → Microsoft 365

Team size and IT maturity?
├── <300 seats, limited IT staff → Google Workspace (simpler admin)
├── >300 seats, enterprise IT → Microsoft 365 (deeper controls, complexity justified)

Security posture?
├── Need advanced anti-phishing, safe links, sandbox → Microsoft Defender for O365 (M365 E5)
├── Neutral → Both platforms have baseline security; add third-party SEG as needed
```

---

## 8. Cross-Reference Guide

### 8.1 What's Covered Here vs. Email Security Domain

| Topic | This File (domain_concepts_research.md) | Email Security (`agents/security/email-security/`) |
|-------|----------------------------------------|-----------------------------------------------------|
| SPF record syntax and mechanisms | Summary + DNS examples | Full deep dive, lookup counting, flattening |
| DKIM key management | Summary + DNS examples | Full signature anatomy, rotation strategy |
| DMARC policy and reporting | Summary + DNS examples | XML report analysis, aggregate report workflow |
| ARC | Full coverage | Referenced briefly |
| BIMI | Full coverage | Mentioned in SKILL.md |
| MTA-STS | Full coverage | Full coverage (protocol reference) |
| TLS-RPT | Full coverage | Mentioned |
| DANE | Full coverage | Mentioned |
| BEC taxonomy and detection | Not covered | Full coverage |
| SEG vs. API-based security products | Not covered | Full coverage |
| Phishing types | Not covered | Full coverage |
| Email header forensics | Not covered | Full coverage |
| Anti-phishing platforms (Defender, Proofpoint, Mimecast, Abnormal, Sublime) | Not covered | Platform-specific agents |

### 8.2 Technology-Specific Agents (Expected)

These technology-specific agents will reference this domain concepts file for foundational knowledge:

- `mail-collab/exchange/` — Exchange Server (on-prem) versions
- `mail-collab/exchange-online/` — Exchange Online / M365 mail
- `mail-collab/m365/` — Microsoft 365 broader platform
- `mail-collab/google-workspace/` — Google Workspace
- `mail-collab/postfix/` — Postfix MTA
- `mail-collab/postfix/postfix-3/` — Postfix version-specific

### 8.3 Related Domain Overlaps

| Capability | Also Covered In |
|-----------|----------------|
| LDAP/Active Directory for mail (GAL, address book) | `agents/iam/` |
| TLS certificate management | `agents/security/` or `agents/networking/` |
| DNS management (MX, SPF, DKIM records) | `agents/networking/dns/` |
| SIEM integration for mail logs | `agents/monitoring/siem/` |
| DLP as security control | `agents/security/dlp/` |
| Backup and recovery of mailboxes | `agents/storage/backup/` |
| Microsoft 365 identity (Entra ID) | `agents/iam/` |
| Google Cloud Identity | `agents/iam/` |

---

## 9. Quick Reference — Decision Frameworks

### 9.1 Port and Protocol Selection

```
Client submitting outbound email:
  → Port 587 + STARTTLS + SMTP AUTH (preferred)
  → Port 465 + Implicit TLS + SMTP AUTH (acceptable, legacy clients)
  → Port 25: NEVER for client submission

Server-to-server relay (MTA-to-MTA):
  → Port 25 + Opportunistic STARTTLS (standard)
  → Port 25 + STARTTLS + DANE (enforced TLS, requires DNSSEC)
  → Port 25 + MTA-STS policy (enforced TLS, no DNSSEC)

Client accessing mailbox:
  → IMAP on port 993 (Implicit TLS) — preferred
  → IMAP on port 143 (STARTTLS) — acceptable
  → POP3 on port 995 (Implicit TLS) — legacy only
  → HTTP/JSON (JMAP) — modern, where supported (Fastmail, Cyrus)
```

### 9.2 DMARC Deployment Decision Tree

```
No DMARC record?
→ Start: p=none + rua= (monitor for 4+ weeks)

DMARC reports showing >95% pass rate from all senders?
→ Advance: p=quarantine; pct=10
→ Increase pct weekly: 10 → 25 → 50 → 100

At p=quarantine; pct=100 for 2+ weeks without issues?
→ Advance: p=reject

Have subdomains sending legitimate mail?
→ Verify each subdomain has SPF and DKIM configured
→ Set sp=quarantine or sp=reject once subs are clean

Need strict brand protection for non-mail subdomains?
→ Publish _dmarc.subdomain.example.com with p=reject for subdomains that never send mail
```

### 9.3 Migration Method Selection

```
Source: Exchange on-prem or hosted Exchange
├── <150 mailboxes, all migrate at once → Cutover migration
├── 150–2000 mailboxes, batch over 2-8 weeks → Staged migration
└── >500 mailboxes, complex environment, long timeline → Hybrid migration (HCW)

Source: Non-Exchange (Lotus Notes, GroupWise, Dovecot, Cyrus)
├── Email only → IMAP migration
├── Email + calendar/contacts → Third-party tool (MigrationWiz, CloudM)

Destination: M365
├── Microsoft FastTrack available for >150 seats (free)
├── Complex/large → Third-party: BitTitan MigrationWiz, Quest, Cloudficient

Destination: Google Workspace
├── From Exchange → GWMME (Google's free tool)
├── Complex/large → Third-party: CloudM, BitTitan

Tenant-to-tenant (M365 → M365):
├── Native: Cross-Tenant Mailbox Migration (mailbox only, limited)
└── Complex: BitTitan MigrationWiz, Quest ODM, Cloudficient
```

---

## 10. Glossary of Key Terms

| Term | Definition |
|------|-----------|
| **MTA** | Mail Transfer Agent — routes email between servers via SMTP |
| **MDA** | Mail Delivery Agent — delivers messages into a mailbox store |
| **MUA** | Mail User Agent — end-user email client (Outlook, Gmail, Thunderbird) |
| **MSA** | Mail Submission Agent — accepts authenticated outbound mail from clients (port 587) |
| **MX** | Mail Exchange — DNS record specifying inbound mail server |
| **SPF** | Sender Policy Framework — DNS-based list of authorized sending IPs |
| **DKIM** | DomainKeys Identified Mail — cryptographic message signature |
| **DMARC** | Domain-based Message Authentication, Reporting & Conformance — policy + reporting layer over SPF/DKIM |
| **ARC** | Authenticated Received Chain — preserves auth results through forwarders |
| **BIMI** | Brand Indicators for Message Identification — logo display in email clients |
| **DANE** | DNS-Based Authentication of Named Entities — DNSSEC-based TLS certificate pinning |
| **MTA-STS** | MTA Strict Transport Security — enforces TLS for SMTP without DNSSEC |
| **TLS-RPT** | TLS Reporting (RFC 8460) — failure reporting for MTA-STS/DANE |
| **SEG** | Secure Email Gateway — inline, MX-based email filtering appliance/service |
| **SMTP** | Simple Mail Transfer Protocol — email relay protocol |
| **IMAP** | Internet Message Access Protocol — mailbox access protocol (server-side storage) |
| **POP3** | Post Office Protocol 3 — download-and-delete email protocol |
| **JMAP** | JSON Meta Application Protocol — modern HTTP-based email protocol |
| **Milter** | Mail filter — interface between MTA and external filter daemons |
| **Smart host** | Relay MTA through which outbound mail is routed |
| **Litigation hold** | Preservation of all user data pending legal proceedings |
| **Journaling** | Real-time copy of all messages sent to an external archive |
| **eDiscovery** | Search and export of electronic records for legal purposes |
| **DLP** | Data Loss Prevention — policy enforcement on sensitive content |
| **HCW** | Hybrid Configuration Wizard — Microsoft tool for Exchange hybrid setup |
| **MRS** | Mailbox Replication Service — handles mailbox moves in Exchange |
| **EWS** | Exchange Web Services — SOAP-based API for Exchange (legacy) |
| **Graph API** | Microsoft Graph — REST API for M365 services (modern replacement for EWS) |
| **VMC** | Verified Mark Certificate — cryptographic proof of trademark ownership for BIMI |
| **GWMME** | Google Workspace Migration for Microsoft Exchange — Google's free migration tool |
