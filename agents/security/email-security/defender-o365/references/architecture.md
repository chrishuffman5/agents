# Microsoft Defender for Office 365 — Architecture Reference

## Protection Stack Overview

MDO processes email in multiple sequential stages. Understanding the order matters — later stages depend on earlier ones.

```
Inbound Email Flow (Simplified)

Internet → EOP Connection Filtering → EOP Anti-Malware → EOP Anti-Spam
         → Safe Attachments (Plan 1+) → Safe Links (delivery rewrite)
         → Anti-Phishing Policies → Mailbox Intelligence
         → Delivery to Exchange Online Mailbox
         → ZAP (post-delivery, continuous)
```

## EOP Architecture

### Data Centers and Routing

Exchange Online Protection runs on Microsoft's global infrastructure. Inbound mail flows through regional EOP clusters before reaching Exchange Online mailboxes in the tenant's home region.

MX record for Exchange Online:
```
tenant-name.mail.protection.outlook.com
```

All inbound internet mail must flow through this address (which resolves to EOP IPs). Organizations using a third-party SEG must configure an M365 inbound connector to restrict mail acceptance to SEG IPs only — otherwise direct-to-tenant attacks bypass the SEG.

### Connection Filtering

Connection filtering is the first line of defense, operating at the IP/connection level before content inspection.

**IP Block List:** Explicitly blocked IPs. Messages rejected at SMTP with 550 error.
**IP Allow List:** Bypass content filtering (use cautiously — skips spam/malware scanning).
**Safe List:** Microsoft-curated list of known-good IPs (Outlook.com, Gmail, Yahoo). Mail from these IPs skips some checks.

**Configuring bypass for third-party SEG:**
```powershell
# Create enhanced filtering connector to pass SEG IP
Set-InboundConnector -Identity "From SEG" -EFSkipLastIP $true
```
Enhanced filtering (skip listing) allows EOP to see original sender IP through the SEG, preserving IP-based filtering accuracy.

### Anti-Malware Engine

EOP uses multiple anti-malware engines in parallel (Microsoft + third-party). Scanning occurs before anti-spam to ensure malware is never placed in the Junk folder.

**Common Attachments Filter:**
File types blocked without scanning (extension-based):
`.ace`, `.ani`, `.apk`, `.app`, `.appx`, `.arj`, `.bat`, `.cab`, `.cmd`, `.com`, `.deb`, `.dex`, `.dll`, `.docm`, `.elf`, `.exe`, `.hta`, `.img`, `.iso`, `.jar`, `.jnlp`, `.kext`, `.lha`, `.lib`, `.library`, `.lnk`, `.lzh`, `.macho`, `.msc`, `.msi`, `.msix`, `.msp`, `.mst`, `.pif`, `.ppa`, `.ppam`, `.reg`, `.rev`, `.scf`, `.scr`, `.sct`, `.sys`, `.uif`, `.vb`, `.vbe`, `.vbs`, `.vxd`, `.wsc`, `.wsf`, `.wsh`, `.xll`, `.xz`, `.z`

This list is Microsoft-managed and periodically updated. Organizations can add custom extensions.

## Safe Attachments Detonation Pipeline

```
Email arrives with attachment
        ↓
EOP malware scan (signature/heuristics)
        ↓
If unknown/suspicious → Safe Attachments detonation
        ↓
Clone message, strip attachment
        ↓
Dynamic Delivery: Send message with placeholder
Static modes: Hold message entirely
        ↓
Detonation in isolated VM (Windows 10 + Office)
Behavioral analysis: file system changes, network calls, registry modifications
        ↓
Verdict: Clean / Malicious / Error
        ↓
Clean: Replace placeholder with original attachment (Dynamic Delivery)
       Or deliver original message (Static mode)
Malicious: Quarantine attachment, notify admin
Error: Deliver original (safe-on-error behavior)
```

**Detonation VM environment:**
- Windows 10 with latest patches
- Office applications installed and activated
- Common PDF readers, archive tools
- Network connectivity for multi-stage download detection
- Behavioral monitoring agent

**Supported file types for detonation:**
- Office: `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`, `.one` (OneNote)
- PDF: `.pdf`
- Archives: `.zip`, `.rar`, `.7z` (one level deep)
- Executables: `.exe`, `.dll` (if not blocked by Common Attachments Filter)
- Scripts: `.ps1`, `.vbs`, `.js`

**Limitations:**
- Password-protected archives cannot be detonated (deliver clean, flag for review)
- Files > 200 MB may time out detonation
- Certain obfuscation techniques can evade behavioral analysis

## Safe Links URL Analysis

### Rewriting and Click Processing

**Delivery-time rewriting:**
All URLs in message body are rewritten to Safe Links proxy URL. This happens in the EOP pipeline before delivery.

**Click-time processing pipeline:**
```
User clicks Safe Links URL
        ↓
Request hits safelinks.protection.outlook.com
        ↓
Authenticate user identity (tied to tenant)
        ↓
Real-time URL scan:
  - Check URL reputation database
  - Follow redirects (resolve redirect chains)
  - If unknown: Detonate in sandbox
        ↓
Safe: Redirect to original URL
Malicious: Block page (customizable message)
Unknown/scanning: Hold for detonation result
```

**Click tracking:**
User clicks are logged and available in Threat Explorer → URL clicks view. Shows: user, URL, click time, verdict, action (allowed/blocked).

**URL detonation (Plan 1+):**
When a URL is unknown, Safe Links can request detonation (similar to Safe Attachments but for web content). Analyzes page content, scripts, download behavior.

### Safe Links in Office Applications

When Safe Links is enabled for Office apps, URLs in documents opened in Word, Excel, PowerPoint (desktop 16.x+) are checked on click. Requires:
- Microsoft 365 Apps for Enterprise (not standalone Office)
- Policy: "Safe Links in Office 365 desktop apps" enabled
- User signed in with their M365 identity in Office

## Anti-Phishing Policy Architecture

### Impersonation Protection

**User impersonation:**
Policy-specified users (up to 60 per policy) are monitored. When an inbound message appears to impersonate one of these users (similar display name, lookalike domain), the policy action applies.

Detection methods:
- Display name match with different From address
- Domain lookalike (Unicode homoglyph, character substitution, addition/removal of characters)
- First-time sender from domain similar to protected user's domain

**Domain impersonation:**
Protected domains list. Messages appearing to come from lookalike domains trigger the action.

Similarity algorithms used:
- Character substitution: `microsoft.com` → `m1crosoft.com`
- Character addition: `microsoft.com` → `microsoftt.com`
- Character deletion: `microsoft.com` → `microsof.com`
- Subdomain addition: `microsoft.com` → `mail.microsoft.com.attacker.com`
- Unicode homoglyphs: Cyrillic `а` vs. Latin `a`

**Mailbox intelligence:**
Plan 1+ feature. Machine learning model that builds a graph of each user's typical communication patterns (who they normally email, communication frequency, response patterns). Messages that deviate significantly from established patterns receive higher phishing scores.

**Tips displayed to users:**
- "?": Sender failed SPF/DKIM/DMARC (unauthenticated sender indicator)
- "via" tag: Display name sender doesn't match From domain
- First contact safety tip: First time receiving email from this sender
- Unusual characters safety tip: Display name contains lookalike characters

### Spoof Intelligence

**Composite authentication (`compauth`):**
Microsoft's meta-authentication verdict combines:
- SPF result
- DKIM result
- DMARC result
- Microsoft-proprietary reputation signals (sending history, infrastructure patterns)

When a domain lacks proper SPF/DKIM/DMARC but Microsoft's signals indicate legitimate mail (e.g., a large established sender), compauth may pass despite missing formal authentication.

**Spoof intelligence insight:**
Automatically categorizes domain pairs that are spoofing your domain. Accessible at: Security portal → Email & collaboration → Policies & rules → Threat policies → Tenant Allow/Block Lists → Spoofed senders.

**Allow/block spoofed senders:**
Add legitimate forwarding scenarios to the allow list (e.g., partner who uses your domain in display name, bulk mail providers). Block known spoofing sources.

## Threat Explorer Data Model

### Data Retention and Availability

| Feature | Retention | Notes |
|---|---|---|
| Real-Time Detections (Plan 1) | 7 days | Read-only; no remediation actions |
| Threat Explorer (Plan 2) | 30 days | Full remediation capability |
| Message Trace | 90 days | Summary; 10 days for full trace |
| Advanced Hunting (Defender XDR) | 30 days | Kusto queries |

### Explorer Views and Data Fields

**All email view — key fields:**
- `SenderFromAddress` — RFC5322.From (visible From header)
- `SenderMailFromAddress` — RFC5321.MailFrom (envelope sender, Return-Path)
- `SenderIPv4` — Sending IP address
- `RecipientEmailAddress` — Delivery recipient
- `Subject` — Email subject
- `DeliveryAction` — Delivered, Blocked, Replaced, Quarantine
- `DeliveryLocation` — Inbox, JunkEmail, Quarantine, DeletedItems, External
- `DetectionMethods` — Which detection technology flagged the message
- `SpamVerdict` — Spam confidence level (SCL)
- `PhishVerdict` — Phishing confidence
- `BulkComplaintLevel` — BCL score (1-9)
- `AuthenticationDetails` — SPF/DKIM/DMARC/compauth results

**Detection method values:**
- `MalwareFilter` — EOP anti-malware
- `HighConfPhish` — High-confidence phishing detection
- `Spoof` — Spoof intelligence
- `Impersonation` — User/domain impersonation
- `SafeAttachment` — Safe Attachments detonation
- `SafeLinks` — Safe Links URL verdict
- `AdvancedPhishingFilter` — Mailbox intelligence
- `CampaignFilter` — Campaign detection
- `AIR` — Automated investigation action

## AIR Playbooks

AIR uses predefined investigation playbooks triggered by different alert types.

### Phishing Email Reported by User Playbook

**Trigger:** User clicks "Report Message" → Phishing

**Investigation steps:**
1. Analyze reported message (headers, URLs, attachments)
2. Search for identical or similar messages across all mailboxes (same sender, subject, attachment hash, URL)
3. Check URL reputation and detonation results
4. Check file hash reputation
5. Analyze sender IP and domain reputation
6. Review affected users — who received similar messages

**Evidence types collected:**
- Email messages (related)
- Email URLs
- Email attachments
- Mailbox accounts (recipients)
- IP addresses
- Users (click-through, interaction)

**Remediation actions generated:**
- Soft delete malicious email from all affected mailboxes
- Block sender domain/IP in Tenant Allow/Block List
- Trigger Safe Attachments detonation for similar attachments
- Mark URLs as malicious in Safe Links

### Malware Detected Playbook

**Trigger:** High-confidence malware detected by EOP or Safe Attachments

**Additional investigation steps:**
- Device correlation (if Defender for Endpoint integrated): Was the attachment opened on a device?
- User activity review: Was the user's account subsequently compromised?
- Lateral movement check: Did the user send internal mail with similar attachments?

## Integration with Microsoft Defender XDR

When MDO is part of a Defender XDR deployment:

**Incident correlation:** MDO alerts are correlated with Defender for Endpoint (device), Defender for Identity (Active Directory), and Entra ID alerts into unified incidents.

**Advanced Hunting (Kusto):**
```kusto
// Find all emails with blocked URLs in last 7 days
EmailUrlInfo
| where UrlVerdict == "Blocked"
| join kind=inner EmailEvents on NetworkMessageId
| where Timestamp > ago(7d)
| project Timestamp, RecipientEmailAddress, SenderFromAddress, Url, UrlVerdict
| order by Timestamp desc

// Find users who clicked malicious Safe Links URLs
UrlClickEvents
| where ActionType == "ClickBlocked"
| where Timestamp > ago(30d)
| summarize ClickCount = count() by AccountUpn, Url
| order by ClickCount desc

// Find emails that evaded filters (delivered + later ZAPped)
EmailEvents
| where DeliveryAction == "Delivered"
| join kind=inner EmailPostDeliveryEvents on NetworkMessageId
| where Action == "Zap"
| project Timestamp, RecipientEmailAddress, SenderFromAddress, Subject, ThreatTypes
```

**Microsoft Sentinel integration:**
MDO alerts and hunting data can be streamed to Microsoft Sentinel via the Microsoft Defender XDR connector for long-term retention and SIEM correlation.

## EOP vs. Plan 1 vs. Plan 2 Capability Matrix

| Feature | EOP | Plan 1 | Plan 2 |
|---|---|---|---|
| Anti-spam | Yes | Yes | Yes |
| Anti-malware | Yes | Yes | Yes |
| Spoof intelligence | Yes | Yes | Yes |
| Anti-phishing (basic) | Yes | Yes | Yes |
| Safe Attachments (email) | No | Yes | Yes |
| Safe Links (email) | No | Yes | Yes |
| Safe Attachments (SPO/ODB/Teams) | No | Yes | Yes |
| User/domain impersonation | No | Yes | Yes |
| Mailbox intelligence | No | Yes | Yes |
| Real-Time Detections | No | Yes (read) | No |
| Threat Explorer | No | No | Yes |
| Automated Investigation (AIR) | No | No | Yes |
| Attack Simulation Training | No | No | Yes |
| Campaign Views | No | No | Yes |
| Threat Trackers | No | No | Yes |
| Priority Account Protection | No | No | Yes |
| Advanced Hunting (MDO tables) | No | No | Yes |

**License mapping:**
- EOP: Exchange Online Plan 1/2, Microsoft 365 Business Basic/Standard/Premium (via Exchange)
- Plan 1: Microsoft 365 Business Premium, E3 + Defender for O365 P1 add-on
- Plan 2: Microsoft 365 E5, E5 Security, Defender for O365 P2 add-on (E3 base required)
