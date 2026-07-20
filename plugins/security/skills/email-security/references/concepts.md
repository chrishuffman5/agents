# Email Security Fundamentals

## Email Authentication Chain

The full email authentication chain involves multiple cooperating standards, each addressing a different attack vector.

```
Sending MTA                     DNS                      Receiving MTA
    |                             |                            |
    |-- MAIL FROM: bounce@a.com --|-- SPF lookup: a.com ------>|
    |                             |   "v=spf1 ip4:..." <-------|
    |-- DKIM-Signature: v=1 ------|-- selector._domainkey.a --->|
    |                             |   "v=DKIM1; p=..." <--------|
    |                             |-- _dmarc.a.com ------------>|
    |                             |   "v=DMARC1; p=reject" <---|
    |                                                           |
    |                           Result: SPF pass + DKIM pass   |
    |                           DMARC alignment check          |
    |                           Policy: deliver / quarantine / reject
```

### Authentication Chain Step-by-Step

1. **Sending MTA** signs message with DKIM private key; adds `DKIM-Signature` header
2. **Sending MTA** transmits with MAIL FROM (envelope sender) specifying bounce address
3. **Receiving MTA** performs SPF lookup on MAIL FROM domain — checks if sending IP is authorized
4. **Receiving MTA** retrieves DKIM public key from DNS using selector in `DKIM-Signature` header
5. **Receiving MTA** verifies DKIM signature over specified headers and body
6. **Receiving MTA** retrieves DMARC policy from `_dmarc.from-domain.com`
7. **DMARC alignment check:** Does the From header domain align with SPF MAIL FROM domain? Does it align with DKIM signing domain?
8. **Policy enforcement:** If neither alignment passes, apply `p=` policy (none/quarantine/reject)
9. **Reporting:** Receiving MTA accumulates authentication results for aggregate report

## SPF Deep Dive

### DNS Lookup Mechanism Count

RFC 7208 limits SPF processing to 10 DNS-resolving mechanisms. Exceeding this causes `permerror`.

Mechanisms that count toward the limit:
- `include:` (1 per include, plus nested lookups in the included record)
- `a` / `a:domain` (1 per)
- `mx` / `mx:domain` (1 per)
- `ptr` (deprecated; 1 per)
- `exists:` (1 per)
- `redirect=` (1 per, replaces record)

Mechanisms that do NOT count:
- `ip4:` / `ip6:` — No DNS lookup
- `all` — No DNS lookup
- `v=spf1` itself

**Counting example:**
```
v=spf1 include:spf.protection.outlook.com    <- 1 (+ Microsoft's nested lookups)
       include:_spf.google.com               <- 2 (+ Google's nested lookups)
       include:sendgrid.net                  <- 3 (+ SendGrid's nested lookups)
       ip4:203.0.113.10                      <- 0 (no lookup)
       -all
```
Microsoft's `spf.protection.outlook.com` internally uses 3-4 lookups; Google similar. This can easily exceed 10.

**Flattening:** Replace `include:` entries with explicit `ip4:` ranges by resolving the included domains to IPs. Flattening services automate this but require ongoing maintenance.

### SPF Return Codes

| Result | Meaning | DMARC treatment |
|---|---|---|
| pass | Sending IP is authorized | SPF pass |
| fail | Sending IP is explicitly not authorized (`-all`) | SPF fail |
| softfail | Not authorized but not hard fail (`~all`) | SPF fail (for DMARC) |
| neutral | Domain makes no assertion (`?all`) | SPF fail (for DMARC) |
| none | No SPF record found | SPF fail (for DMARC) |
| temperror | Temporary DNS error | Typically treated as pass for delivery |
| permerror | Permanent error (lookup limit, syntax) | Typically treated as fail |

### SPF and Forwarding

SPF breaks with email forwarding because:
1. Original message: From: user@sender.com, MAIL FROM: user@sender.com, delivered from sender.com's IP → SPF passes
2. Forwarder receives message and re-transmits: MAIL FROM unchanged (user@sender.com), but now delivered from forwarder's IP → SPF fails

Solutions:
- **DKIM** — Forwarding-resilient because signature is in the message, not tied to transport IP
- **SRS (Sender Rewriting Scheme)** — Forwarding server rewrites MAIL FROM to its own domain, preserving bounce routing
- **ARC (Authenticated Received Chain)** — Stamps authentication results at each hop, allows final receiver to trust forwarded auth

## DKIM Deep Dive

### Signature Header Anatomy

```
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed; d=example.com;
  s=selector1; t=1704067200; x=1704672000;
  h=From:To:Subject:Date:Message-ID:Content-Type;
  bh=2jUSOH9NhtIAm47/I0lGPOFpHgKWUNB0mxuIAHW7LXE=;
  b=AuUoFEfDxTDkHlLXSZEpZj79LHZnxkCU... (base64 signature)
```

**Fields:**
- `v=1` — Version
- `a=rsa-sha256` — Signing algorithm (also: `ed25519-sha256`)
- `c=relaxed/relaxed` — Header/body canonicalization (relaxed tolerates whitespace normalization)
- `d=example.com` — Signing domain (must align with From domain for DMARC)
- `s=selector1` — Selector (DNS lookup: `selector1._domainkey.example.com`)
- `t=` — Signature timestamp (Unix)
- `x=` — Signature expiration (optional)
- `h=` — Signed headers (colon-separated list)
- `bh=` — Body hash
- `b=` — Signature over headers

### What DKIM Signs

DKIM signs a hash of:
1. **Canonicalized headers** — Headers listed in `h=`, in order, with `DKIM-Signature` header itself (minus `b=` value)
2. **Canonicalized body** — Full message body (or truncated to `l=` bytes, if specified — avoid `l=`)

**Canonicalization modes:**
- `simple` — Strict byte-for-byte matching; breaks on minor whitespace changes
- `relaxed` — Normalizes whitespace in headers (folds long lines, reduces runs to single space); compresses whitespace in body; recommended

### DKIM Key Management

**Key sizes:**
- 1024-bit: Deprecated, weak. Many receivers now reject or warn.
- 2048-bit: Current minimum recommendation
- 4096-bit: Not universally supported in DNS (UDP packet size limits)
- Ed25519: Smaller, faster, not yet universally supported

**Selector strategy:**
- Use multiple selectors for different senders (e.g., `mkt1._domainkey` for marketing platform)
- Date-based selectors for rotation: `2024q1._domainkey`
- Key rotation: Publish new selector → transition sending systems → retire old selector (keep old DNS record for 7+ days to cover delayed delivery)

**Third-party senders:**
For ESPs (Mailchimp, Salesforce, HubSpot), either:
- **Subdomain delegation:** Delegate `em.example.com` — ESP controls DKIM for that subdomain
- **CNAME-based:** Provider publishes key under their domain; you add CNAME from your selector

## DMARC Deep Dive

### DMARC Alignment Rules

DMARC alignment compares the **RFC5322.From** (visible From address) with:
1. **SPF alignment:** RFC5321.MailFrom (envelope sender) domain
2. **DKIM alignment:** `d=` domain in DKIM-Signature

**Relaxed alignment (default):** Organizational domain match. `mail.example.com` aligns with `example.com` (same organizational domain per public suffix list).

**Strict alignment:** Exact domain match. `mail.example.com` does NOT align with `example.com`.

**Common alignment failures:**
- Marketing platform sends From: ceo@example.com but MAIL FROM: bounce@sendgrid.net — SPF misalignment
- Subdomain mismatch with strict alignment: DKIM signs `mail.example.com`, From: user@example.com
- Forwarding with SPF fail and no DKIM: neither aligns

### DMARC Aggregate Report (RUA) Analysis

Aggregate reports are XML files, typically sent by receiving mail services daily. Fields to analyze:

```xml
<record>
  <row>
    <source_ip>209.85.220.41</source_ip>      <!-- Google outbound IP -->
    <count>1247</count>                         <!-- Messages from this IP -->
    <policy_evaluated>
      <disposition>none</disposition>           <!-- Policy applied -->
      <dkim>pass</dkim>
      <spf>fail</spf>
    </policy_evaluated>
  </row>
  <identifiers>
    <header_from>example.com</header_from>
    <envelope_from>bounce.example.com</envelope_from>  <!-- Different from header_from -->
  </identifiers>
  <auth_results>
    <spf>
      <domain>bounce.example.com</domain>
      <result>pass</result>
    </spf>
    <dkim>
      <domain>example.com</domain>
      <selector>selector1</selector>
      <result>pass</result>
    </dkim>
  </auth_results>
</record>
```

**Analysis workflow:**
1. Identify all source IPs sending on behalf of your domain
2. Check which are legitimate (your mail servers, authorized ESPs)
3. For legitimate sources with failures: fix SPF/DKIM configuration
4. For unknown sources: potential unauthorized use or phishing — investigate
5. Track pass rates over time before tightening policy

**DMARC report parsers/services:** Valimail, Dmarcian, EasyDMARC, Postmark, Google Postmaster Tools, Microsoft DMARC reports in M365.

## BEC Taxonomy and Detection

### Financial BEC Patterns

**Wire Transfer Fraud (most common):**
- Timing: Near quarter-end, during mergers/acquisitions, around real vendor negotiations
- Playbook: Attacker monitors email (post-ATO or OSINT) → identifies upcoming wire → sends fake invoice or change of banking instruction
- Technical indicators: Reply-to address mismatch, domain lookalike, no DKIM signature

**Vendor Email Compromise (VEC):**
- Attacker compromises a real vendor's email account (not just impersonates)
- Emails appear to come from a legitimate, trusted address with valid DKIM
- Authentication-based detection fails — behavioral AI required
- Detection: Communication pattern deviation, unusual payment change timing, request from new device/location on vendor side

**Payroll/HR Fraud:**
- Employee impersonation or HR system access
- Requests direct deposit change to attacker-controlled account
- HR processes without verification

**CEO Fraud Chain:**
1. Research: LinkedIn, press releases, earnings calls (find CEO/CFO names)
2. Registration: Domain lookalike or display name trick
3. First contact: Urgency signal, request for employee list, gift cards, or wire instructions
4. Escalation: Reference to acquisitions, legal pressure, confidentiality

### Account Takeover (ATO) Indicators

**Initial compromise:**
- Credential phishing landing page (often passes initial URL scanning)
- Password spray against O365 (common: `Password1`, seasonal passwords)
- Credential stuffing from breached databases

**Post-compromise behaviors:**
- Inbox rules: Forward copies to external address, delete security alerts
- Mailbox delegation: Add attacker-controlled account
- Consent phishing: Grant OAuth application with mail read permissions
- Password/MFA change attempt

**Detection signals for API-based tools:**
- Impossible travel (login from New York + London within 1 hour)
- New ASN/country not seen in last 90 days
- Unusual send volume spike
- First-time external recipient for forwarding rule
- Login from VPN/Tor exit node

## SEG vs. API Architecture — Full Comparison

### SEG Deployment Architecture

```
Internet MX      →    SEG Cluster      →    Mail Server (Exchange/M365)
(Evil Corp)           (Proofpoint/          (Mailboxes)
                       Mimecast)
                       
- IP Reputation       - URL Rewriting       - Final delivery
- Anti-spam           - Sandbox             - ZAP (M365)
- Anti-malware        - Header injection
- Rate limiting       - Policy enforcement
```

**MX record configuration (SEG):**
```
; Point MX to SEG, not directly to M365
example.com.  IN  MX  10  mail.pphosted.com.    ; Proofpoint
; M365 connector locked to SEG IP range to prevent bypass
```

**Direct-to-inbox bypass (common misconfiguration):**
Attackers discover the tenant's direct MX record (e.g., `example-com.mail.protection.outlook.com`) and send directly, bypassing the SEG entirely. Mitigation: Connector restrictions in M365 or Google to only accept mail from SEG IP ranges.

### API-Based Architecture

```
M365/Google Workspace  ←→  API-based product (Abnormal/Sublime)
        ↓                         ↓
   Message delivered         Post-delivery analysis
   to mailbox                     ↓
                            Behavioral scoring
                                  ↓
                        Retroactive removal (TRAP/API delete)
```

**Microsoft Graph API permissions used by API security products:**
- `Mail.ReadWrite` — Read and modify messages (for removal)
- `Mail.Read` — Read messages (for analysis)
- `MailboxSettings.Read` — Detect inbox rules
- `User.Read.All` — Enumerate users, roles
- `AuditLog.Read.All` — Sign-in logs for ATO detection

### Layered Email Security Stack

| Layer | Technology | Catches |
|---|---|---|
| DNS-based blocking | DNSBL/IP reputation | Known spam/malware IPs |
| SPF/DKIM/DMARC | Standards | Spoofed/unauthenticated mail |
| SEG or EOP | Gateway scanning | Known malware, spam, some phishing |
| Sandbox | MDO/Proofpoint TAP | Zero-day attachments, detonation |
| URL analysis | Safe Links / URL Defense | Malicious URLs, time-of-click |
| Behavioral AI | Abnormal / Sublime | BEC, VEC, ATO, novel phishing |
| Post-delivery remediation | ZAP / TRAP / API pull | Threats not caught pre-delivery |
| User training | KnowBe4 / Proofpoint SAT | Human last line of defense |

## SMTP Security Standards

### STARTTLS and Opportunistic TLS

**Opportunistic TLS:** Most SMTP servers support STARTTLS, upgrading plain-text connections to TLS. However, it is opportunistic — if TLS fails, most servers fall back to plaintext (downgrade attack).

**DANE (DNS-Based Authentication of Named Entities):**
- Uses TLSA records in DNSSEC-signed zones to specify expected TLS certificate
- Requires DNSSEC deployment on both sending and receiving sides
- Prevents downgrade attacks at SMTP layer
- Adoption limited by DNSSEC complexity

**MTA-STS Policy File (full reference):**
```
version: STSv1
mode: enforce
mx: mail.example.com
mx: *.example.com
max_age: 604800
```

**TLS-RPT (RFC 8460):** Reporting standard for MTA-STS failures, similar to DMARC rua.
```
_smtp._tls.example.com TXT "v=TLSRPTv1; rua=mailto:tls-reports@example.com"
```

### SMTP AUTH and Submission

- **Port 25:** SMTP relay (server-to-server). Should not accept AUTH from clients.
- **Port 587:** Submission (client-to-server). Requires STARTTLS + AUTH.
- **Port 465:** SMTPS (implicit TLS). Deprecated then reinstated (RFC 8314).

Modern recommendation: Clients should use port 587 with STARTTLS or port 465 with implicit TLS. Disable open relay on port 25.

## Email Header Analysis

Key headers for security analysis:

```
Received: from mail.attacker.com (mail.attacker.com [192.0.2.1])
          by mx.victim.com (Postfix) with ESMTP id ABC123
          for <user@victim.com>; Mon, 1 Jan 2024 10:00:00 +0000

Authentication-Results: mx.victim.com;
  dkim=fail reason="signature verification failed" header.d=example.com;
  spf=softfail (sender not permitted) smtp.mailfrom=bounce@example.com;
  dmarc=fail action=none header.from=example.com

Return-Path: <bounce@example.com>
From: CEO Name <ceo@example.com>
Reply-To: external-attacker@gmail.com      ← BEC signal
X-Originating-IP: 192.0.2.1               ← Webmail client IP
X-Mailer: The Bat! 9.3                     ← Unusual client
```

**Analysis checklist:**
1. Trace `Received` headers bottom-to-top (oldest first)
2. Check `Authentication-Results` for SPF/DKIM/DMARC outcomes
3. Compare `From` vs. `Reply-To` — mismatch is a major BEC signal
4. Check `Return-Path` alignment with `From` domain (DMARC check)
5. Review `X-Originating-IP` / `X-Forwarded-For` for geographic anomalies
6. Look for timezone inconsistencies between `Date` and `Received` timestamps
