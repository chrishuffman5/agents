# Mail & Collaboration Domain Concepts

## Email Protocols

### SMTP -- Simple Mail Transfer Protocol (RFC 5321)

SMTP transmits email between servers (MTA-to-MTA) and from clients to servers (submission).

**Port assignments:**

| Port | Use | TLS Mode |
|------|-----|----------|
| 25 | MTA-to-MTA relay | Opportunistic STARTTLS |
| 587 | Client submission (RFC 6409) | STARTTLS required |
| 465 | SMTPS implicit TLS (RFC 8314) | Implicit TLS |

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

**Key ESMTP extensions:**
- `SIZE` -- Maximum message size advertisement
- `STARTTLS` -- Upgrade to TLS mid-session (RFC 3207)
- `AUTH` -- Client authentication (PLAIN, LOGIN, XOAUTH2)
- `PIPELINING` -- Multiple commands without per-command response
- `8BITMIME` -- 8-bit data in message body (required for UTF-8)
- `SMTPUTF8` -- Internationalized email addresses (RFC 6531)
- `CHUNKING` -- Large messages in chunks (BDAT command)

**Submission vs. relay distinction:**
- Port 25: MTA relay. Must reject AUTH from end clients. Accept only from authenticated peers or `mynetworks`.
- Port 587: Client submission. Requires AUTH before accepting. Enables per-user tracking and rate limiting.
- Mixing submission and relay on port 25 is the classic "open relay" misconfiguration.

### IMAP -- Internet Message Access Protocol (RFC 9051)

IMAP4rev2 (RFC 9051) supersedes RFC 3501. Clients access mailboxes stored on the server without downloading all messages.

**Key capabilities:**
- Folder hierarchy with namespace separation (personal, shared, public)
- Server-side search (SEARCH/SORT/THREAD)
- Partial fetch -- headers or specific MIME parts without full download
- IDLE -- server push notifications without polling
- CONDSTORE/QRESYNC -- efficient sync, tracks changes since last session
- MOVE -- atomic server-side move (RFC 6851)

**Ports:** 143 (STARTTLS), 993 (IMAPS implicit TLS)

### POP3 -- Post Office Protocol v3 (RFC 1939)

Legacy download-and-delete protocol. Relevant only for legacy client compatibility or compliance scenarios where server-side storage is forbidden.

**Ports:** 110 (STARTTLS), 995 (POP3S implicit TLS)

No folder support, no server-side flags, no partial fetch. Do not design new systems around POP3.

### JMAP -- JSON Meta Application Protocol (RFC 8620, RFC 8621)

Modern HTTP/JSON-based replacement for IMAP and SMTP client-server communication.

**Advantages over IMAP:**
- HTTP/2 transport -- multiplexed, proxy-friendly
- JSON instead of custom text protocol
- Push via HTTP SSE or WebSocket
- Batch operations in one HTTP request
- Efficient delta sync

**Adoption:** Fastmail (primary), Cyrus IMAP, Apache James. Not supported in Exchange/M365 or Google Workspace natively.

### Message Format (RFC 5322, MIME)

**Core headers:**

| Header | Purpose | Required |
|--------|---------|----------|
| From | Author address | Yes |
| To | Primary recipients | Yes (or Cc/Bcc) |
| Date | Origination timestamp | Yes |
| Message-ID | Unique identifier | Yes |
| Subject | Topic | Strongly recommended |
| MIME-Version | MIME encoding (1.0) | When using MIME |
| Content-Type | Body media type | Required for MIME |

**MIME structure (typical):**
```
multipart/mixed
  multipart/alternative
    text/plain
    text/html
  application/pdf         (attachment)
  image/png               (inline)
```

**Content-Transfer-Encoding:** `7bit`, `quoted-printable` (mostly-ASCII), `base64` (binary), `8bit` (requires 8BITMIME).

---

## DNS Records for Email

### MX Records

MX records specify which servers accept mail for a domain. Lower preference = higher priority.

```dns
; On-premises with failover
example.com.    IN  MX  10  mail1.example.com.
example.com.    IN  MX  20  mail2.example.com.

; Microsoft 365
example.com.    IN  MX  0   example-com.mail.protection.outlook.com.

; Google Workspace
example.com.    IN  MX  1   aspmx.l.google.com.
example.com.    IN  MX  5   alt1.aspmx.l.google.com.
example.com.    IN  MX  5   alt2.aspmx.l.google.com.
example.com.    IN  MX  10  alt3.aspmx.l.google.com.
example.com.    IN  MX  10  alt4.aspmx.l.google.com.
```

**Design rules:**
- MX must point to a hostname, never an IP
- MX hostname must have an A/AAAA record (no CNAME chain)
- Multiple MX records provide failover (tried in preference order)
- TTL: 300-3600 for active domains; lower before planned changes

### SPF, DKIM, DMARC

For complete SPF/DKIM/DMARC mechanics, see `skills/security/email-security/SKILL.md`. Key DNS records:

```dns
; SPF for M365
example.com. IN TXT "v=spf1 include:spf.protection.outlook.com -all"

; SPF for Google Workspace
example.com. IN TXT "v=spf1 include:_spf.google.com -all"

; DKIM (M365 uses CNAME delegation)
selector1._domainkey.example.com. IN CNAME selector1-example-com._domainkey.example.onmicrosoft.com.

; DMARC enforcement
_dmarc.example.com. IN TXT "v=DMARC1; p=reject; rua=mailto:dmarc@example.com; adkim=s; aspf=r"
```

### ARC -- Authenticated Received Chain (RFC 8617)

ARC preserves authentication results through forwarding and mailing lists, solving SPF/DKIM breakage in forwarding chains. Each mail handler adds three ARC headers (AAR, AMS, AS). Final receiver evaluates the chain. Gmail and M365 both validate and generate ARC headers.

### BIMI -- Brand Indicators for Message Identification

Displays brand logo in email clients when DMARC passes at `p=quarantine` or `p=reject`.

```dns
default._bimi.example.com. IN TXT "v=BIMI1; l=https://example.com/logo.svg; a=https://example.com/vmc.pem"
```

**Requirements:** DMARC at quarantine/reject, SVG Tiny P/S logo, VMC from DigiCert/Entrust (for Gmail/Apple Mail).

**Supported:** Gmail, Yahoo Mail, Apple Mail (iOS 16+), Fastmail. Not supported in Outlook (as of 2025).

### DANE -- DNS-Based Authentication of Named Entities (RFC 7671, 7672)

DANE pins TLS certificates via TLSA records in DNSSEC-signed zones.

```dns
_25._tcp.mail.example.com. IN TLSA 3 1 1 <sha256-of-public-key>
```

**Requires DNSSEC.** Postfix supports DANE natively (`smtp_tls_security_level = dane`). Limited adoption outside European ISPs.

### MTA-STS (RFC 8461)

Enforces TLS for SMTP without DNSSEC. Two components:

```dns
_mta-sts.example.com. IN TXT "v=STSv1; id=20240101T000000"
```

Policy file at `https://mta-sts.example.com/.well-known/mta-sts.txt`:
```
version: STSv1
mode: enforce
mx: mail.example.com
max_age: 604800
```

**Modes:** `testing` (report only), `enforce` (reject non-TLS), `none` (withdraw policy). Use `testing` first with TLS-RPT monitoring.

### TLS-RPT (RFC 8460)

Daily JSON reports on MTA-STS and DANE policy failures.

```dns
_smtp._tls.example.com. IN TXT "v=TLSRPTv1; rua=mailto:tls-reports@example.com"
```

Essential during MTA-STS testing phase to identify senders that cannot establish TLS.

---

## Mail Flow Architecture

### Core Components

| Component | Role | Examples |
|-----------|------|---------|
| **MTA** (Mail Transfer Agent) | Routes and relays email via SMTP | Postfix, Exchange Transport, Google Mailer Daemon |
| **MDA** (Mail Delivery Agent) | Delivers to user's mailbox store | Dovecot LDA, Cyrus deliver, Exchange Mailbox Transport |
| **MUA** (Mail User Agent) | Client application | Outlook, Thunderbird, Gmail web, mobile mail apps |
| **MSA** (Mail Submission Agent) | Accepts from authenticated clients on port 587 | Postfix submission, Exchange Client Frontend |

### Canonical Mail Flow

```
[MUA] --587/TLS--> [MSA/MTA (Outbound)]
                         |
                    DKIM sign
                    SPF authorize
                         |
                   MX lookup for recipient domain
                         |
                  --25/TLS--> [Receiving MTA]
                                   |
                              SPF check
                              DKIM verify
                              DMARC evaluate
                              Content filter
                                   |
                              [MDA / LMTP]
                                   |
                           [Mailbox Store]
                                   |
                             --IMAP/993--> [MUA]
```

### Content Filtering Pipeline (Typical Inbound)

1. **Connection-level:** IP reputation, rate limiting, TLS enforcement
2. **Envelope-level:** Recipient validation, SPF check
3. **Header-level:** DKIM verification, DMARC evaluation
4. **Message-level:** Anti-spam scoring (Bayesian, heuristic, ML)
5. **Attachment-level:** Anti-malware, file type blocking, sandboxing
6. **URL-level:** Reputation check, detonation sandbox
7. **Content policy:** DLP rules, keyword scanning
8. **Delivery decision:** Accept / quarantine / reject / tag

### Smart Host / Relay Patterns

A smart host is an intermediate MTA that handles outbound delivery on behalf of another MTA. Used when:
- Sending MTA cannot perform direct MX delivery (ISP blocks port 25)
- Centralized egress logging, filtering, or DLP is required
- On-prem servers route outbound through a cloud hygiene service

### Edge Transport / Perimeter Architecture

```
Internet
    |
[DNS / IP Reputation Block]     DNSBLs (Spamhaus, Barracuda)
    |
[Edge MTA / SEG]                Proofpoint, Mimecast, Exchange Edge, Postscreen
    |  SPF/DKIM/DMARC, anti-spam, anti-malware, URL rewrite
    |
[Internal MTA / Hub Transport]
    |
[Mailbox Server / Cloud Tenant]
    |
[MDA --> Mailbox]
```

---

## Compliance & Governance

### Regulatory Retention Minimums

| Regulation | Sector | Retention Period |
|-----------|--------|-----------------|
| SEC Rule 17a-4 | Financial services | 3 years (broker-dealer), 6 years (investment advisors) |
| FINRA Rule 4511 | Financial services | 6 years |
| HIPAA | Healthcare | 6 years |
| Sarbanes-Oxley (SOX) | Public companies | 7 years |
| GDPR | EU organizations | Minimum necessary (retention limitation principle) |
| IRS / Tax records | All US businesses | 7 years |

### Retention vs. Legal Hold

- **Retention:** Routine lifecycle -- keep for N years, then delete
- **Legal hold:** Legal preservation -- override retention, keep until released by legal team
- Items under hold are preserved in Recoverable Items (M365) or Vault (Google), invisible to user but discoverable

### Journaling vs. Archiving

- **Journaling:** Real-time copy of every message to an external system. Immutable. Required for SEC/FINRA compliance.
- **Archiving:** Messages moved/copied within the platform. Subject to platform controls. Sufficient for general litigation readiness.

### eDiscovery

Electronic discovery workflow: create case, add custodians, place holds, search across locations, review results, export for legal review. Both M365 (Purview eDiscovery) and Google (Vault) provide native eDiscovery capabilities.

### DLP (Data Loss Prevention)

DLP policies inspect message content for sensitive data (credit cards, SSNs, PHI) and enforce actions (block, quarantine, encrypt, notify). Available in both M365 Purview and Google Workspace Enterprise.
