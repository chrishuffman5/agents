# Postfix MTA Research: Versions 3.9 and 3.10
*Research document for skill file authoring — April 2026*

---

## 1. Architecture Overview

### 1.1 Design Philosophy

Postfix uses a modular, privilege-separated architecture. Small processes with limited privileges are launched by a master daemon, each performing a specific mail-handling task. Processes run in a changed-root environment to limit the blast radius of attacks. No single large process handles all mail operations.

### 1.2 Master Daemon (master(8))

The `master` process is the supervisor of the entire Postfix system. Responsibilities:
- Starts all Postfix server processes
- Monitors process health and restarts crashed servers
- Enforces per-service process count limits defined in `master.cf`
- Reads `master.cf` at startup; `postfix reload` re-reads it

The master daemon does **not** handle mail itself — it only orchestrates the daemons that do.

### 1.3 Queue Manager (qmgr(8))

The queue manager is the heart of Postfix mail delivery. It:
- Maintains the active queue as a limited window into the full queue
- Contacts delivery agents with delivery requests
- Schedules retries for deferred messages using exponential backoff
- Implements per-destination concurrency limits and rate controls

**Four queue directories:**

| Queue | Purpose |
|-------|---------|
| `incoming` | Newly arrived or re-injected messages |
| `active` | Messages opened for delivery (limited window) |
| `deferred` | Messages pending retry |
| `hold` | Messages administratively held |
| `corrupt` | Damaged or malformed queue files |

The active queue size is deliberately limited to prevent memory exhaustion under peak load. The queue manager never lets all deferred mail flood the active queue simultaneously.

### 1.4 Delivery Agents

| Agent | Purpose |
|-------|---------|
| `local(8)` | Local UNIX mailboxes, Maildir, aliases, .forward files |
| `virtual(8)` | Virtual mailbox delivery (multi-domain, no UNIX accounts needed) |
| `smtp(8)` | Remote SMTP/ESMTP delivery |
| `lmtp(8)` | Local Mail Transfer Protocol (optimized for mailbox servers like Cyrus) |
| `pipe(8)` | Interface to external programs (Procmail, Dovecot LDA, etc.) |
| `discard(8)` | Silently discards mail (for blackhole addresses) |
| `error(8)` | Returns mail with a configurable error message |

### 1.5 Supporting Daemons

| Daemon | Role |
|--------|------|
| `smtpd(8)` | Receives inbound SMTP connections |
| `pickup(8)` | Monitors maildrop queue for locally submitted mail |
| `cleanup(8)` | Final processing before queueing: header rewriting, content inspection |
| `trivial-rewrite(8)` | Address rewriting and recipient classification |
| `bounce(8)`, `defer(8)`, `trace(8)` | Generate delivery status notifications |
| `tlsmgr(8)` | TLS session cache and PRNG management |
| `tlsproxy(8)` | TLS encryption/decryption proxy |
| `anvil(8)` | Connection and rate limiting |
| `postscreen(8)` | Pre-SMTP connection filtering (zombie/spambot blocking) |
| `verify(8)` | Address verification probing |
| `proxymap(8)` | Shared lookup table access |
| `scache(8)` | SMTP connection caching |
| `flush(8)` | Moves deferred mail back to incoming |
| `showq(8)` | Queue listing for `mailq` and `postqueue` |
| `postlogd(8)` | Alternative logging (file or stdout; Postfix 3.4+) |

### 1.6 Mail Flow: Inbound (Receiving)

```
Internet SMTP client
    → smtpd(8)              [access checks, milters, TLS]
    → cleanup(8)            [header rewriting, content inspection, normalization]
    → incoming queue
    → qmgr(8)              [scheduling, concurrency control]
    → delivery agent        [local/virtual/smtp/lmtp/pipe]
```

For locally submitted mail:
```
sendmail(1) / postdrop(1)
    → maildrop queue
    → pickup(8)
    → cleanup(8)
    → incoming queue
    → qmgr(8) → delivery agent
```

### 1.7 Milter Interface

Milters (mail filters) plug into the smtpd pipeline via the Sendmail Milter API. Postfix supports both smtpd milters and non-smtpd milters:

- `smtpd_milters` — filters for mail arriving via SMTP
- `non_smtpd_milters` — filters for locally submitted mail (pipe(8), sendmail)

Milter socket formats:
- `inet:host:port` — TCP socket
- `unix:pathname` — UNIX domain socket (relative to queue directory if chroot)

Per-milter configuration (Postfix 3.0+):
```
smtpd_milters = {
    inet:127.0.0.1:8891,
    connect_timeout=10s,
    default_action=accept
}
```

`milter_default_action` controls behavior when a milter is unavailable: `accept`, `reject`, `tempfail` (default), or `quarantine`.

---

## 2. Configuration Files

### 2.1 main.cf

The primary configuration file. All parameters use `key = value` format. Lines beginning with whitespace continue the previous line.

**Core identity parameters:**

```ini
# /etc/postfix/main.cf

myhostname = mail.example.com
mydomain = example.com
myorigin = $mydomain

# Interfaces to listen on (default: all)
inet_interfaces = all
inet_protocols = ipv4, ipv6

# Domains for which local delivery occurs
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain

# Networks trusted to relay without authentication
mynetworks = 127.0.0.0/8, 192.168.1.0/24

# Relay via smarthost (empty = direct delivery)
relayhost = [smtp.provider.com]:587

# Mail size limit (bytes; 0 = unlimited)
message_size_limit = 52428800

# Mailbox size limit per user (0 = unlimited)
mailbox_size_limit = 0
```

**Key parameters explained:**

| Parameter | Description |
|-----------|-------------|
| `myhostname` | FQDN of this server; used in SMTP HELO |
| `mydomain` | Parent domain; derived from myhostname by default |
| `myorigin` | Domain appended to unqualified sender addresses |
| `mydestination` | Domains delivered locally (never list virtual domains here) |
| `mynetworks` | IPs/networks permitted to relay without SASL auth |
| `relayhost` | Upstream MTA for outbound mail; brackets skip MX lookup |
| `relay_domains` | Domains this server relays for external clients |
| `inet_interfaces` | Interfaces smtpd listens on |

**Checking effective configuration:**
```bash
postconf myhostname mydomain mydestination mynetworks
postconf -d smtp_tls_security_level   # show default value
postconf -n                            # show non-default settings only
postconf -e 'myhostname = mail.new.com'  # edit in-place
```

### 2.2 master.cf

Defines all Postfix services. Each logical line has 8 fields:

```
# service  type  private  unpriv  chroot  wakeup  maxproc  command + args
smtp        inet  n        -       y       -       -        smtpd
submission  inet  n        -       y       -       -        smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_sasl_type=dovecot
  -o smtpd_sasl_path=private/auth
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
smtps       inet  n        -       y       -       -        smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
pickup      unix  n        90      n       60      1        pickup
cleanup     unix  n        -       y       -       0        cleanup
qmgr        unix  n        n       n       300     1        qmgr
tlsmgr      unix  -        -       y       1000?   1        tlsmgr
rewrite     unix  -        -       y       -       -        trivial-rewrite
bounce      unix  -        -       y       -       0        bounce
defer       unix  -        -       y       -       0        bounce
trace       unix  -        -       y       -       0        bounce
verify      unix  -        -       y       -       1        verify
flush       unix  n        n       y       1000?   0        flush
proxymap    unix  -        -       n       -       -        proxymap
proxywrite  unix  -        -       n       -       1        proxymap
smtp        unix  -        -       y       -       -        smtp
relay       unix  -        -       y       -       -        smtp
showq       unix  n        n       y       -       -        showq
error       unix  -        -       y       -       -        error
retry       unix  -        -       y       -       -        error
discard     unix  -        -       y       -       -        discard
local       unix  -        n       n       -       -        local
virtual     unix  -        n       n       -       -        virtual
lmtp        unix  -        -       y       -       -        lmtp
anvil       unix  -        -       y       -       1        anvil
scache      unix  -        -       y       -       1        scache
postlog     unix-dgram n   -       n       -       1        postlogd
```

**Column meanings:**
- `private` — y: only accessible to Postfix processes (inet = always n)
- `unpriv` — y: runs as unprivileged user
- `chroot` — y: runs in chroot jail (default n in Postfix ≥ 3.0)
- `wakeup` — seconds between automatic wakeups (0 = on-demand, ? = optional)
- `maxproc` — maximum simultaneous processes (0 = $default_process_limit)

---

## 3. Virtual Domains

### 3.1 Domain Classes

Postfix has four recipient address classes processed in order:

1. **Local** (`$mydestination`) — delivered by `local(8)`
2. **Virtual alias** (`$virtual_alias_domains`) — mapped to other addresses
3. **Virtual mailbox** (`$virtual_mailbox_domains`) — delivered to mailboxes by `virtual(8)`
4. **Relay** (`$relay_domains`) — forwarded to another MTA

**Critical rule:** Never list the same domain in more than one class, and never list virtual domains in `$mydestination`.

### 3.2 Virtual Alias Domains

All addresses at an alias domain map to real addresses elsewhere:

```ini
# main.cf
virtual_alias_domains = alias-domain.com
virtual_alias_maps = lmdb:/etc/postfix/virtual
```

```
# /etc/postfix/virtual
postmaster@alias-domain.com   postmaster@example.com
info@alias-domain.com         admin@example.com
@alias-domain.com             catchall@example.com
```

```bash
postmap /etc/postfix/virtual
postfix reload
```

### 3.3 Virtual Mailbox Domains

Recipients have their own mailboxes, no UNIX accounts required:

```ini
# main.cf
virtual_mailbox_domains = example.com, example.net
virtual_mailbox_base = /var/mail/vhosts
virtual_mailbox_maps = lmdb:/etc/postfix/vmailbox
virtual_alias_maps = lmdb:/etc/postfix/virtual
virtual_minimum_uid = 100
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000
```

```
# /etc/postfix/vmailbox
user1@example.com    example.com/user1/
user2@example.com    example.com/user2/
info@example.net     example.net/info/
```

Trailing slash means Maildir format; no slash means mbox.

```
# /etc/postfix/virtual (alias exceptions within virtual domain)
postmaster@example.com   postmaster@localhost
abuse@example.com        postmaster@localhost
```

```bash
postmap /etc/postfix/vmailbox
postmap /etc/postfix/virtual
postfix reload
```

### 3.4 Transport Maps

Override delivery method per domain or address:

```ini
# main.cf
transport_maps = lmdb:/etc/postfix/transport
```

```
# /etc/postfix/transport
example.com     lmtp:[dovecot.internal]:24
oldmail.com     error:mailbox has moved
slow.net        smtp:[relay.slow.net]:25
```

```bash
postmap /etc/postfix/transport
```

---

## 4. Access Control and Restrictions

### 4.1 SMTP Restriction Lists

Restrictions are evaluated left-to-right; first PERMIT or REJECT wins.

**smtpd_client_restrictions** — evaluated at connection time:
```ini
smtpd_client_restrictions =
    permit_mynetworks,
    reject_unknown_client_hostname
```

**smtpd_helo_restrictions** — evaluated at HELO/EHLO:
```ini
smtpd_helo_restrictions =
    permit_mynetworks,
    reject_invalid_helo_hostname,
    reject_non_fqdn_helo_hostname,
    reject_unknown_helo_hostname
```

**smtpd_sender_restrictions** — evaluated at MAIL FROM:
```ini
smtpd_sender_restrictions =
    permit_mynetworks,
    reject_non_fqdn_sender,
    reject_unknown_sender_domain,
    check_policy_service unix:private/policyd-spf
```

**smtpd_relay_restrictions** — controls relaying (Postfix 2.10+; evaluated at RCPT TO):
```ini
smtpd_relay_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination
```

**smtpd_recipient_restrictions** — spam blocking at RCPT TO:
```ini
smtpd_recipient_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination,
    reject_rbl_client zen.spamhaus.org,
    reject_rhsbl_sender dsn.rfc-ignorant.org,
    reject_unverified_recipient
```

**Important:** `reject_unauth_destination` must appear in `smtpd_relay_restrictions` (Postfix 2.10+) or early in `smtpd_recipient_restrictions` to prevent open relay.

### 4.2 Common Restriction Actions

| Restriction | Effect |
|-------------|--------|
| `permit_mynetworks` | Allow if client IP in $mynetworks |
| `permit_sasl_authenticated` | Allow if SASL authentication succeeded |
| `reject_unauth_destination` | Reject if not local or relay domain |
| `reject_unknown_client_hostname` | Reject if client has no valid FCrDNS |
| `reject_non_fqdn_helo_hostname` | Reject non-FQDN HELO strings |
| `reject_rbl_client zen.spamhaus.org` | Reject if client IP in DNSBL |
| `reject_rhsbl_sender dsn.rfc-ignorant.org` | Reject based on sender domain RHSBL |
| `check_policy_service unix:private/policyd-spf` | Delegate to policy daemon |
| `reject_unverified_recipient` | Reject if recipient cannot be verified |

### 4.3 Access Tables

Fine-grained access control via lookup tables:

```ini
# main.cf
smtpd_client_restrictions =
    check_client_access lmdb:/etc/postfix/client_access,
    permit_mynetworks,
    ...
```

```
# /etc/postfix/client_access
192.168.1.100    REJECT spammer
10.0.0.0/8       OK
spammy.tld       REJECT
```

```bash
postmap /etc/postfix/client_access
```

---

## 5. TLS Configuration

### 5.1 Server-Side TLS (smtpd_tls_*)

Modern certificate configuration (Postfix ≥ 3.4, preferred):

```ini
# main.cf — TLS for inbound SMTP
smtpd_tls_chain_files =
    /etc/postfix/rsa.pem,
    /etc/postfix/ecdsa.pem
smtpd_tls_security_level = may          # opportunistic
smtpd_tls_loglevel = 1                  # 0=none, 1=summary, 2=handshake, 3=packets
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = medium
smtpd_tls_exclude_ciphers = aNULL, eNULL, EXPORT, RC4, DES, 3DES, MD5
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_mandatory_ciphers = high
smtpd_tls_auth_only = yes              # require TLS before SASL AUTH
```

The PEM file order for `smtpd_tls_chain_files`: private key, then leaf cert, then intermediates (bottom-up).

Legacy configuration (Postfix < 3.4):
```ini
smtpd_tls_cert_file = /etc/ssl/certs/mail.crt
smtpd_tls_key_file  = /etc/ssl/private/mail.key
smtpd_tls_CAfile    = /etc/ssl/certs/ca-bundle.crt
```

### 5.2 Client-Side TLS (smtp_tls_*)

```ini
# main.cf — TLS for outbound SMTP
smtp_tls_security_level = may           # opportunistic; use dane for DNSSEC
smtp_tls_loglevel = 1
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_ciphers = medium
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
```

### 5.3 TLS Security Levels

| Level | Description |
|-------|-------------|
| `none` | TLS disabled |
| `may` | Opportunistic; try TLS but deliver in plaintext if unavailable |
| `encrypt` | Mandatory encryption; reject if TLS not available |
| `dane` | DNSSEC + TLSA records required (client side only) |
| `dane-only` | Like dane but never deliver without valid TLSA |
| `fingerprint` | Verify by certificate fingerprint |
| `verify` | Verify certificate chain against trust anchors |
| `secure` | Like verify but also check hostname |

### 5.4 DANE (DNS-Based Authentication of Named Entities)

DANE is built into Postfix. Requires DNSSEC-validating resolver.

```ini
# main.cf
smtp_dns_support_level = dnssec
smtp_tls_security_level = dane
smtp_host_lookup = dns
```

Postfix supports TLSA certificate usage types 2 (trust-anchor) and 3 (end-entity). Recommended TLSA record (SHA-256 of SPKI):

```
_25._tcp.mail.example.com. 3600 IN TLSA 3 1 1 <sha256-of-public-key>
```

TLSA key rollover procedure:
1. Publish new TLSA record with new key digest (alongside existing)
2. Wait for DNS cache TTL to expire (minimum 24-48h)
3. Deploy new certificate/key
4. Remove old TLSA digest after another TTL period

Check TLSA records: `posttls-finger -l secure -T 25 mail.example.com`

### 5.5 MTA-STS

Postfix does not natively support MTA-STS. External tools are required:

- **postfix-tlspol** — Lightweight MTA-STS + DANE/TLSA resolver prioritizing DANE (recommended when both are deployed)
- **postfix-mta-sts-resolver** — Pure MTA-STS resolver (cannot resolve DANE simultaneously)

```ini
# main.cf (with postfix-tlspol)
smtp_tls_policy_maps = socketmap:inet:127.0.0.1:8642:postfix
```

### 5.6 Submission Port (587) TLS Configuration

In `master.cf`:
```
submission inet n - y - - smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_sasl_type=dovecot
  -o smtpd_sasl_path=private/auth
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
```

### 5.7 TLSRPT (New in Postfix 3.10)

Postfix 3.10 adds RFC 8460 TLSRPT support. Domains publish a DNS record requesting daily TLS connection summaries:

```
_smtp._tls.example.com. IN TXT "v=TLSRPTv1; rua=mailto:tlsrpt@example.com"
```

See `TLSRPT_README` in Postfix documentation.

---

## 6. SASL Authentication

### 6.1 Dovecot SASL (Recommended)

Dovecot configuration (`/etc/dovecot/conf.d/10-master.conf`):
```
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
```

Postfix `main.cf`:
```ini
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_tls_security_options = noanonymous
broken_sasl_auth_clients = yes    # for old Outlook/Exchange clients
```

### 6.2 Cyrus SASL

```ini
smtpd_sasl_type = cyrus
smtpd_sasl_path = smtpd
smtpd_sasl_auth_enable = yes
```

Cyrus SASL config in `/etc/postfix/sasl/smtpd.conf`:
```
pwcheck_method: saslauthd
mech_list: plain login
```

### 6.3 SASL for Outbound Relay

```ini
# main.cf — authenticate to upstream smarthost
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = lmdb:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
relayhost = [smtp.provider.com]:587
```

```
# /etc/postfix/sasl_passwd
[smtp.provider.com]:587   username:password
```

```bash
postmap /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.lmdb
```

---

## 7. Anti-Spam Integration

### 7.1 Postscreen

Postscreen pre-filters inbound connections before handing off to smtpd, blocking zombie spambots (responsible for ~90% of spam) with a single process:

```ini
# main.cf
postscreen_access_list = permit_mynetworks, cidr:/etc/postfix/postscreen_access.cidr
postscreen_cache_map = lmdb:$data_directory/postscreen_cache
postscreen_greet_wait = 6s
postscreen_greet_action = drop             # drop pre-greeting talkers
postscreen_dnsbl_threshold = 3
postscreen_dnsbl_sites =
    zen.spamhaus.org*3,
    bl.spamcop.net*2,
    b.barracudacentral.org*2,
    dnsbl.sorbs.net*1
postscreen_dnsbl_action = enforce          # temp-fail DNSBL hits
postscreen_dnsbl_reply_map = lmdb:/etc/postfix/postscreen_dnsbl_reply
# Deep protocol tests (cause client reconnect):
postscreen_pipelining_enable = yes
postscreen_pipelining_action = drop
postscreen_non_smtp_command_enable = yes
postscreen_non_smtp_command_action = drop
postscreen_bare_newline_enable = yes
postscreen_bare_newline_action = ignore
```

In `master.cf`:
```
smtp      inet  n       -       y       -       1       postscreen
smtpd     pass  -       -       y       -       -       smtpd
dnsblog   unix  -       -       y       -       0       dnsblog
tlsproxy  unix  -       -       y       -       0       tlsproxy
```

DNSBL action values: `ignore` (log only), `enforce` (temp-fail new clients), `drop` (disconnect).

### 7.2 SPF with policyd-spf

Install: `apt install postfix-policyd-spf-python`

```
# /etc/postfix/master.cf
policyd-spf  unix  -  n  n  -  0  spawn
    user=policyd-spf argv=/usr/bin/policyd-spf
```

```ini
# main.cf
policyd-spf_time_limit = 3600
smtpd_recipient_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination,
    check_policy_service unix:private/policyd-spf
```

SPF DNS record example:
```
example.com. IN TXT "v=spf1 mx a:mail.example.com -all"
```

### 7.3 DKIM with OpenDKIM

Install: `apt install opendkim opendkim-tools`

Generate keys:
```bash
opendkim-genkey -s mail -d example.com -D /etc/opendkim/keys/example.com/
chmod 640 /etc/opendkim/keys/example.com/mail.private
chown opendkim:opendkim /etc/opendkim/keys/example.com/mail.private
```

`/etc/opendkim.conf`:
```
Mode                sv
Syslog              yes
UMask               002
UserID              opendkim
Socket              inet:8891@127.0.0.1
PidFile             /run/opendkim/opendkim.pid
Domain              example.com
KeyFile             /etc/opendkim/keys/example.com/mail.private
Selector            mail
InternalHosts       /etc/opendkim/trusted.hosts
```

Postfix `main.cf`:
```ini
milter_default_action = accept
milter_protocol = 6
smtpd_milters = inet:127.0.0.1:8891
non_smtpd_milters = $smtpd_milters
```

DKIM DNS record:
```
mail._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=<base64-public-key>"
```

### 7.4 DMARC with OpenDMARC

```ini
# main.cf (add OpenDMARC milter)
smtpd_milters = inet:127.0.0.1:8891, inet:127.0.0.1:8893
```

DMARC DNS record:
```
_dmarc.example.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com; ruf=mailto:dmarc@example.com; pct=100"
```

DMARC policies: `none` (monitor), `quarantine`, `reject`.

### 7.5 ARC (Authenticated Received Chain)

ARC preserves authentication results across forwarding hops. OpenARC or Rspamd provide ARC signing. Postfix integration is the same milter mechanism.

### 7.6 Full Milter Pipeline Example

```ini
# main.cf — complete milter chain
milter_default_action = accept
milter_protocol = 6
smtpd_milters =
    inet:127.0.0.1:8891,    # OpenDKIM (sign + verify)
    inet:127.0.0.1:8893,    # OpenDMARC (DMARC verification)
    inet:127.0.0.1:11332    # Rspamd (spam scoring + ARC)
non_smtpd_milters =
    inet:127.0.0.1:8891     # DKIM signing for local submissions only
```

### 7.7 Rspamd Integration

Rspamd proxy worker provides milter protocol on port 11332.

```ini
# main.cf
smtpd_milters = inet:127.0.0.1:11332
milter_default_action = accept
```

Rspamd handles: spam scoring, DKIM signing/verification, DMARC, ARC, URL blocklists, Bayes filtering.

### 7.8 Amavis + ClamAV + SpamAssassin

After-queue content filter pattern:

```ini
# main.cf
content_filter = scan:[127.0.0.1]:10024
receive_override_options = no_address_mappings
```

```
# master.cf (re-injection service)
127.0.0.1:10025 inet  n  -  n  -  -  smtpd
  -o content_filter=
  -o receive_override_options=no_header_body_checks
  -o smtpd_authorized_xforward_hosts=127.0.0.0/8
```

Amavis listens on 10024, scans, then re-injects clean mail to port 10025.

---

## 8. Header and Body Checks

Quick in-process content inspection using regexp or pcre tables:

```ini
# main.cf
header_checks = regexp:/etc/postfix/header_checks
body_checks = regexp:/etc/postfix/body_checks
mime_header_checks = regexp:/etc/postfix/mime_header_checks
```

```
# /etc/postfix/header_checks
/^Subject:.*\[SPAM\]/       PREPEND X-Spam-Flag: YES
/^X-Mailer: The Bat!/       REJECT Known spam client
/^Received:.*from.*spammer\.tld/   REJECT
```

Actions: `REJECT`, `HOLD`, `DISCARD`, `WARN`, `PREPEND`, `REPLACE`, `REDIRECT`, `FILTER`, `DUNNO`, `OK`.

Body checks are limited to the first body segment to avoid scanning huge attachments.

---

## 9. Address Rewriting

### 9.1 Canonical Maps

```ini
sender_canonical_maps = lmdb:/etc/postfix/sender_canonical
recipient_canonical_maps = lmdb:/etc/postfix/recipient_canonical
```

```
# /etc/postfix/sender_canonical
jdoe     John.Doe@example.com
```

### 9.2 Masquerading

Hide internal hostnames behind the gateway domain:

```ini
masquerade_domains = example.com
masquerade_exceptions = root, postmaster
```

Applies to headers and envelope sender only (not envelope recipient by default).

### 9.3 Generic Maps (Outbound Address Rewriting)

```ini
smtp_generic_maps = lmdb:/etc/postfix/generic
```

```
# /etc/postfix/generic
root@internal.lab    admin@example.com
@internal.lab        noreply@example.com
```

### 9.4 Relocated Maps

```ini
relocated_maps = lmdb:/etc/postfix/relocated
```

```
# /etc/postfix/relocated
olduser@example.com    newuser@newdomain.com
```

Client receives: `550 user has moved to newuser@newdomain.com`

---

## 10. Lookup Table Types

```ini
# Common examples
alias_maps = hash:/etc/postfix/aliases          # Berkeley DB hash
virtual_alias_maps = lmdb:/etc/postfix/virtual  # OpenLDAP LMDB (preferred in modern Postfix)
transport_maps = btree:/etc/postfix/transport    # Berkeley DB btree
header_checks = pcre:/etc/postfix/header_checks # Perl regex
recipient_canonical_maps = ldap:/etc/postfix/ldap-recipients.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual.cf
```

| Type | Usage | Notes |
|------|-------|-------|
| `hash` | General key-value | Requires Berkeley DB; postmap required |
| `lmdb` | General key-value | Preferred on modern systems; atomic updates |
| `btree` | Sorted key-value | Berkeley DB; good for ordered lookups |
| `cdb` | Read-optimized | No incremental updates; atomic replacement |
| `pcre` | Regex matching | Read-only; full file loaded into memory |
| `regexp` | POSIX regex | Read-only; less powerful than pcre |
| `tcp` | Remote TCP service | Custom protocol |
| `ldap` | LDAP directory | No reload needed after changes |
| `mysql` | MySQL/MariaDB | No reload needed after changes |
| `pgsql` | PostgreSQL | No reload needed after changes |
| `mongodb` | MongoDB | Added in Postfix 3.9 |
| `static` | Fixed value | e.g., `static:5000` for uid/gid maps |
| `socketmap` | Socket map protocol | Used for MTA-STS resolvers |

---

## 11. Rate Limiting and Throttling

### 11.1 Anvil Rate Controls

```ini
# main.cf
anvil_rate_time_unit = 60s
smtpd_client_connection_rate_limit = 10    # connections per time unit per IP
smtpd_client_connection_count_limit = 10   # simultaneous connections per IP
smtpd_client_message_rate_limit = 100      # message deliveries per time unit per IP
smtpd_client_recipient_rate_limit = 200    # recipients per time unit per IP
smtpd_client_new_tls_session_rate_limit = 20
```

Clients in `$mynetworks` are exempt from rate limits by default.

Log entry when limit hit:
```
warning: Connection rate limit reached (10/60s) by 192.0.2.10
```

### 11.2 Delivery Concurrency

```ini
default_destination_concurrency_limit = 20
smtp_destination_concurrency_limit = 5     # per-transport override
local_destination_concurrency_limit = 2
virtual_destination_concurrency_limit = 5
```

### 11.3 Message and Recipient Limits

```ini
message_size_limit = 52428800              # 50 MB
mailbox_size_limit = 1073741824            # 1 GB (local only)
smtpd_recipient_limit = 1000              # recipients per message session
```

---

## 12. Queue Management

### 12.1 Queue Inspection

```bash
# List all queued messages
mailq
postqueue -p

# Example output:
# -Queue ID-  --Size-- ----Arrival Time---- -Sender/Recipient-------
# 3C9A12345    1234   Fri Apr 10 14:23:01  sender@example.com
#                                           recipient@other.com
# -- 1 Kbytes in 1 Request.

# View a specific queued message
postcat -q 3C9A12345        # queue ID only
postcat -qv 3C9A12345       # verbose with headers
```

### 12.2 Queue Operations

```bash
# Flush the entire queue (retry all deferred mail)
postqueue -f
postfix flush

# Retry a single message
postqueue -i 3C9A12345

# Delete a specific message
postsuper -d 3C9A12345

# Delete all deferred mail
postsuper -d ALL deferred

# Delete all queued mail (dangerous!)
postsuper -d ALL

# Put a message on hold
postsuper -h 3C9A12345

# Release a held message
postsuper -H 3C9A12345

# Requeue a message (re-process through cleanup)
postsuper -r 3C9A12345
postsuper -r ALL
```

Queue status characters in `postqueue -p`:
- `*` — message is in active queue (being delivered)
- `!` — message is in hold queue

### 12.3 Queue Timing Parameters

```ini
queue_run_delay = 300s          # how often to scan deferred queue
minimal_backoff_time = 300s     # minimum retry interval
maximal_backoff_time = 4000s    # maximum retry interval
maximal_queue_lifetime = 5d     # when to bounce undeliverable mail
bounce_queue_lifetime = 5d      # lifetime for bounces to MAILER-DAEMON
```

---

## 13. Management Commands

### 13.1 Postfix Service Control

```bash
postfix start                   # start Postfix
postfix stop                    # stop gracefully (finish active deliveries)
postfix abort                   # stop immediately
postfix reload                  # re-read main.cf and master.cf
postfix check                   # check config and permissions
postfix status                  # show running status
postfix set-permissions         # fix file permissions
postfix upgrade-configuration   # update config after package upgrade
```

### 13.2 postconf

```bash
postconf myhostname              # show parameter value
postconf -n                      # show all non-default parameters
postconf -d smtp_tls_security_level  # show compiled-in default
postconf -m                      # list available lookup table types
postconf -a                      # list available SASL server plugins
postconf -A                      # list available SASL client plugins
postconf -e 'param = value'      # edit main.cf in place
postconf -P submission/inet/smtpd_tls_security_level  # master.cf params
```

### 13.3 postmap and postalias

```bash
# Create or rebuild a lookup table
postmap /etc/postfix/virtual
postmap lmdb:/etc/postfix/transport

# Query a lookup table
postmap -q user@example.com lmdb:/etc/postfix/virtual
postmap -q "192.168.1.1" cidr:/etc/postfix/postscreen_access.cidr

# Rebuild the alias database
newaliases
postalias /etc/aliases
postalias -q root hash:/etc/aliases
```

### 13.4 Multi-Instance Management (postmulti)

```bash
# Initialize multi-instance support
postmulti -e init

# Create a new instance
postmulti -I postfix-inbound -G mx-inbound -e create

# List all instances
postmulti -l -a

# Enable autostart
postmulti -i postfix-inbound -e enable

# Start/stop specific instance
postmulti -i postfix-inbound -p start
postmulti -i postfix-inbound -p stop

# Run command on all instances in a group
postmulti -g mx-inbound -x postconf queue_directory
```

---

## 14. Diagnostics and Troubleshooting

### 14.1 Log Locations and Format

| Distribution | Log file |
|--------------|----------|
| Debian/Ubuntu | `/var/log/mail.log` |
| RHEL/CentOS/AlmaLinux | `/var/log/maillog` |
| systemd journal | `journalctl -u postfix` |

Postfix severity levels:
- `panic` — software bug, needs developer attention
- `fatal` — fixable issue (missing files, wrong permissions)
- `error` — process terminates after 13+ occurrences
- `warning` — non-fatal issue
- `info` — normal operation

Quick error scan:
```bash
grep -E '(warning|error|fatal|panic):' /var/log/mail.log
grep 'status=bounced\|status=deferred' /var/log/mail.log
grep 'reject:' /var/log/mail.log | tail -50
```

### 14.2 Typical Log Messages

**Successful delivery:**
```
postfix/smtp[12345]: 3C9A12345: to=<user@remote.com>, relay=mx.remote.com[1.2.3.4]:25,
  delay=0.5, delays=0.1/0/0.2/0.2, dsn=2.0.0, status=sent (250 OK)
```

**Deferred delivery:**
```
postfix/smtp[12346]: 3C9A12345: to=<user@slow.com>, relay=none, delay=300,
  status=deferred (connect to mx.slow.com[5.6.7.8]:25: Connection timed out)
```

**Relay denied:**
```
postfix/smtpd[12347]: NOQUEUE: reject: RCPT from unknown[9.8.7.6]: 554 5.7.1
  <user@other.com>: Relay access denied; from=<bad@spam.com> to=<user@other.com>
```

**DNSBL rejection:**
```
postfix/smtpd[12348]: NOQUEUE: reject: RCPT from unknown[1.2.3.4]: 550 5.7.1
  Service unavailable; Client host [1.2.3.4] blocked using zen.spamhaus.org
```

**TLS log (loglevel=1):**
```
postfix/smtp[12349]: Untrusted TLS connection established to mx.example.com:25:
  TLSv1.3 with cipher TLS_AES_256_GCM_SHA384 (256/256 bits)
```

**SASL auth failure:**
```
postfix/smtpd[12350]: warning: 192.168.1.50: SASL LOGIN authentication failed: UGFzc3dvcmQ6
```

### 14.3 Debugging Tools

**Verbose logging for specific peer:**
```ini
# main.cf
debug_peer_list = 192.0.2.10, problem.example.com
debug_peer_level = 2
```

**Simulate delivery without sending:**
```bash
sendmail -bv user@example.com
```

**Test address rewriting:**
```bash
postmap -q user@example.com lmdb:/etc/postfix/virtual
```

**SMTP session testing (swaks):**
```bash
swaks --to user@example.com --from test@myserver.com --server localhost
swaks --to user@example.com --tls --auth LOGIN --auth-user myuser --server mail.example.com:587
swaks --to user@example.com --tlsc --server mail.example.com:465  # SMTPS
```

**SMTP testing with openssl:**
```bash
openssl s_client -connect mail.example.com:25 -starttls smtp
openssl s_client -connect mail.example.com:465    # SMTPS
```

**SMTP testing with telnet:**
```bash
telnet localhost 25
EHLO testclient.example.com
MAIL FROM:<test@example.com>
RCPT TO:<user@example.com>
DATA
Subject: Test

Test body.
.
QUIT
```

**Check DANE/TLS connectivity:**
```bash
posttls-finger -l secure -T 25 mail.example.com
posttls-finger -l dane mail.example.com
```

**Packet capture:**
```bash
tcpdump -w /tmp/smtp.pcap -s 0 host mail.example.com and port 25
```

**Network-level SMTP test:**
```bash
nmap -p 25,465,587 mail.example.com
nc -zv mail.example.com 25
```

### 14.4 Common Problems and Solutions

| Problem | Likely Cause | Solution |
|---------|-------------|----------|
| `Relay access denied` | Not in mynetworks, not authenticated | Check smtpd_relay_restrictions |
| `Connection timed out` | Port 25 blocked by ISP/firewall | Use port 587 submission or relay |
| `TLS handshake failure` | Protocol/cipher mismatch | Check smtpd_tls_protocols, cipher list |
| `SASL auth failed` | Wrong credentials or plugin mismatch | Check Dovecot socket, smtpd_sasl_type |
| `User unknown` | Recipient not in virtual or local maps | Check virtual_mailbox_maps, aliases |
| `open database ... No such file` | postmap not run after editing | Run postmap on the changed file |
| `warning: dict_lmdb_close` | LMDB file corruption | Remove .lmdb file and rerun postmap |

---

## 15. Multi-Instance Support

### 15.1 Architecture

Multiple Postfix instances share executables but have separate:
- Configuration directories (main.cf, master.cf)
- Queue directories
- Data directories

Typical deployment: border mail server with 3 instances:
1. **Primary** — local submission to hub
2. **Input** (`postfix-inbound`) — receives from Internet, routes to content filter
3. **Output** (`postfix-outbound`) — re-injects filtered mail, delivers to Internet

### 15.2 Setup Example

```bash
# Initialize framework
postmulti -e init

# Create inbound instance
postmulti -I postfix-inbound -G mx-inbound -e create

# Configure inbound instance (edit /etc/postfix-inbound/main.cf)
postmulti -i postfix-inbound -x postconf -e \
    'inet_interfaces = all' \
    'content_filter = scan:[127.0.0.1]:10024'

# Enable and start
postmulti -i postfix-inbound -e enable
postmulti -i postfix-inbound -p start
```

### 15.3 Key Parameters

```ini
multi_instance_wrapper = ${command_directory}/postmulti
multi_instance_directories = /etc/postfix-inbound /etc/postfix-outbound
multi_instance_name = postfix-inbound    # in each instance's main.cf
multi_instance_group = mx-inbound
multi_instance_enable = yes
```

---

## 16. High-Availability Patterns

### 16.1 Active-Passive

- Postfix persists all state to the filesystem
- Use replicated storage (DRBD, Pacemaker/Corosync, or cloud block storage)
- Virtual IP (keepalived, Pacemaker) fails over to standby node
- No shared state between active and passive — just shared storage

### 16.2 Active-Active

- Multiple MX records with equal or different priorities
- Shared mailbox storage (NFS, GlusterFS, Ceph, GFS2 over FC)
- DNS round-robin or hardware load balancer for inbound SMTP
- Per-node local queue; shared data (MySQL, LDAP) for lookups
- Anti-spam services (Rspamd) run on each node independently

### 16.3 DNS Round-Robin Example

```
example.com. IN MX 10 mail1.example.com.
example.com. IN MX 10 mail2.example.com.
```

---

## 17. Performance Tuning

```ini
# main.cf — tuning for higher volume
default_process_limit = 100
smtpd_client_connection_count_limit = 50
smtp_destination_concurrency_limit = 10
default_destination_concurrency_limit = 20

# Queue timing
queue_run_delay = 300s
minimal_backoff_time = 300s
maximal_backoff_time = 4000s

# Reduce timeouts for fast network
smtp_connect_timeout = 5s
smtp_helo_timeout = 30s
smtp_mail_timeout = 30s
smtp_rcpt_timeout = 30s
smtp_data_init_timeout = 120s
smtp_data_done_timeout = 600s

# SMTP error tuning
smtpd_error_sleep_time = 0
smtpd_soft_error_limit = 10
smtpd_hard_error_limit = 20
```

---

## 18. Standard Configuration Patterns

### 18.1 Null Client (Send Only)

```ini
myhostname = workstation.internal.example.com
myorigin = $mydomain
relayhost = [mail.example.com]
inet_interfaces = loopback-only
mydestination =
```

### 18.2 Internet Mail Server

```ini
myhostname = mail.example.com
mydomain = example.com
myorigin = $mydomain
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
mynetworks = 127.0.0.0/8
relayhost =
relay_domains =
```

### 18.3 Email Gateway / Firewall

```ini
myhostname = gateway.example.com
myorigin = example.com
mydestination =
local_recipient_maps =
local_transport = error:local mail delivery is disabled
relay_domains = example.com
relay_recipient_maps = lmdb:/etc/postfix/relay_recipients
transport_maps = lmdb:/etc/postfix/transport
```

---

## 19. Postfix 3.9 — New Features (Released March 6, 2024)

### 19.1 Security

- **SMTP Smuggling Defense**: `smtpd_forbid_bare_newline = normalize` (default) — normalizes bare newlines in message content to prevent SMTP smuggling attacks
- **Unauthorized Pipelining**: `smtpd_forbid_unauth_pipelining = yes` (default) — disconnects clients that pipeline before EHLO/PIPELINING is negotiated
- **CR/LF Normalization**: `cleanup_replace_stray_cr_lf = yes` (default) — replaces stray CR or LF in message content with a space
- **DNS Limits**: DNS lookup results capped at 100 records to prevent DoS attacks

### 19.2 New Features

- **MongoDB support** — query MongoDB databases for lookups (contributed by Hamid Maadani)
- **RFC 3461 ENVID** — envelope ID exported via `ENVID` environment variable and `${envid}` attribute in pipe delivery agent
- **MySQL/PostgreSQL timers** — configurable idle and retry timers for faster recovery
- **Raw Public Key TLS** — optional RFC 7250 raw public key support instead of X.509 (requires OpenSSL 3.2+)
- **OpenSSL configuration files** — preliminary support via `tls_config_file` and `tls_config_name` parameters

### 19.3 Removed Features

After 20-year deprecation periods:
- `permit_naked_ip_address`
- `check_relay_domains`
- `reject_maps_rbl`
- MySQL client no longer supports MySQL < 4.0

### 19.4 Changed Behaviors

- SMTP date headers now use two-digit day format (e.g., `01 Apr` not ` 1 Apr`)
- MySQL default charset changed to `utf8mb4` for MySQL 8.0 compatibility
- SMTP clients failing to send proper End-of-DATA sequence now time out
- `permit_mx_backup` flagged as deprecated (future removal planned)

---

## 20. Postfix 3.10 — New Features (Released February 16, 2025)

### 20.1 TLS and Cryptography

- **Post-Quantum Cryptography** — Support for OpenSSL 3.5 PQC algorithms (ML-KEM, ML-DSA) via `tls_eecdh_auto_curves` and `tls_ffdhe_auto_groups` parameters
- **RFC 8689 TLS-Required Header** — Support for `TLS-Required: no` message header to request delivery even when preferred TLS policy cannot be enforced (important for TLSRPT reports reaching receivers with MTA-STS)
- **TLSRPT Protocol** — RFC 8460 support: domains receive daily summary reports for successful and failed SMTP-over-TLS connections

### 20.2 Privacy and Protocol

- **Client Session Privacy** — `smtpd_hide_client_session = yes` removes client session info from Received: headers (useful on submission services)
- **RFC 2047 Encoding** — Non-ASCII "full name" parts in generated From: headers encoded properly to avoid SMTPUTF8 conflicts
- **Internal Protocol Update** — Delivery agent protocol change requires `postfix reload` after upgrade (prevents attribute warnings)

### 20.3 Database and Logging

- **MySQL/PostgreSQL Resilience** — Single-host configurations now reconnect immediately after failure instead of waiting 60 seconds
- **Quarantine Logging** — Quarantine action reasons now explicitly logged
- **Abnormal Connection Logging** — Queue IDs logged for unexpected connection drops
- **SASL Logging** — Authentication mechanism names and usernames now logged

---

## 21. Postfix 3.11 (Released Early 2026 — Quick Note)

- Postfix 3.11 was released in early 2026. Review `postfix.org/announcements` for specifics if targeting this version.

---

## 22. Key DNS Records Summary

| Record Type | Example | Purpose |
|-------------|---------|---------|
| MX | `example.com. IN MX 10 mail.example.com.` | Inbound mail routing |
| A/AAAA | `mail.example.com. IN A 1.2.3.4` | Server IP resolution |
| PTR | `4.3.2.1.in-addr.arpa. IN PTR mail.example.com.` | Reverse DNS (required) |
| SPF | `example.com. IN TXT "v=spf1 mx -all"` | Sender authorization |
| DKIM | `mail._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=..."` | DKIM public key |
| DMARC | `_dmarc.example.com. IN TXT "v=DMARC1; p=reject; rua=..."` | DMARC policy |
| TLSA | `_25._tcp.mail.example.com. IN TLSA 3 1 1 <hash>` | DANE certificate pinning |
| MTA-STS | `_mta-sts.example.com. IN TXT "v=STSv1; id=20240101"` | MTA-STS policy identifier |
| TLSRPT | `_smtp._tls.example.com. IN TXT "v=TLSRPTv1; rua=mailto:..."` | TLS report recipient |

---

## 23. Complete Hardened main.cf Example

```ini
# /etc/postfix/main.cf — production hardened configuration

# Identity
myhostname = mail.example.com
mydomain = example.com
myorigin = $mydomain
mynetworks = 127.0.0.0/8

# Reception
inet_interfaces = all
inet_protocols = ipv4, ipv6
mydestination = $myhostname, localhost.$mydomain, localhost
virtual_mailbox_domains = example.com, example.net
virtual_mailbox_base = /var/mail/vhosts
virtual_mailbox_maps = lmdb:/etc/postfix/vmailbox
virtual_alias_maps = lmdb:/etc/postfix/virtual
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000

# Relay
relayhost =
relay_domains =

# TLS — inbound
smtpd_tls_chain_files = /etc/postfix/ssl/mail.pem
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = medium
smtpd_tls_mandatory_ciphers = high
smtpd_tls_loglevel = 1
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache

# TLS — outbound
smtp_tls_security_level = dane
smtp_dns_support_level = dnssec
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_loglevel = 1
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt

# SASL
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients = yes

# Access control
smtpd_relay_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination

smtpd_recipient_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination,
    check_policy_service unix:private/policyd-spf,
    reject_unknown_recipient_domain,
    reject_rbl_client zen.spamhaus.org,
    reject_rhsbl_sender dbl.spamhaus.org

smtpd_helo_restrictions =
    permit_mynetworks,
    reject_non_fqdn_helo_hostname,
    reject_invalid_helo_hostname

smtpd_sender_restrictions =
    permit_mynetworks,
    reject_non_fqdn_sender,
    reject_unknown_sender_domain

# Postscreen
postscreen_access_list = permit_mynetworks
postscreen_greet_wait = 6s
postscreen_greet_action = drop
postscreen_dnsbl_threshold = 3
postscreen_dnsbl_sites = zen.spamhaus.org*3, bl.spamcop.net*2
postscreen_dnsbl_action = enforce

# Anti-spam milters
milter_default_action = accept
milter_protocol = 6
smtpd_milters = inet:127.0.0.1:8891, inet:127.0.0.1:11332
non_smtpd_milters = inet:127.0.0.1:8891

# SMTP smuggling defense (3.9+)
smtpd_forbid_bare_newline = normalize
smtpd_forbid_unauth_pipelining = yes
cleanup_replace_stray_cr_lf = yes

# Limits
message_size_limit = 52428800
mailbox_size_limit = 0
smtpd_client_connection_rate_limit = 60
smtpd_client_message_rate_limit = 100

# Queue
queue_run_delay = 300s
maximal_queue_lifetime = 5d
bounce_queue_lifetime = 5d

# Policy daemon timing
policyd-spf_time_limit = 3600

# Logging
maillog_file = /var/log/postfix.log  # postlogd alternative; or use syslog
```

---

## 24. References

- Postfix Architecture Overview: https://www.postfix.org/OVERVIEW.html
- Postfix Basic Configuration: https://www.postfix.org/BASIC_CONFIGURATION_README.html
- Postfix Standard Configuration: https://www.postfix.org/STANDARD_CONFIGURATION_README.html
- Postfix TLS Support: https://www.postfix.org/TLS_README.html
- Postfix Virtual Domain Howto: http://www.postfix.org/VIRTUAL_README.html
- Postfix SMTPD Access Control: https://www.postfix.org/SMTPD_ACCESS_README.html
- Postfix Postscreen README: https://www.postfix.org/POSTSCREEN_README.html
- Postfix Milter README: https://www.postfix.org/MILTER_README.html
- Postfix Address Rewriting: https://www.postfix.org/ADDRESS_REWRITING_README.html
- Postfix Address Verification: https://www.postfix.org/ADDRESS_VERIFICATION_README.html
- Postfix Multi-Instance: https://www.postfix.org/MULTI_INSTANCE_README.html
- Postfix Database Types: https://www.postfix.org/DATABASE_README.html
- Postfix Content Filter (After-Queue): https://www.postfix.org/FILTER_README.html
- Postfix Content Filter (Before-Queue): https://www.postfix.org/SMTPD_PROXY_README.html
- Postfix Tuning: https://www.postfix.org/TUNING_README.html
- Postfix Debug README: https://www.postfix.org/DEBUG_README.html
- Postfix 3.9.0 Announcement: https://www.postfix.org/announcements/postfix-3.9.0.html
- Postfix 3.10.0 Announcement: http://www.postfix.org/announcements/postfix-3.10.0.html
- DANE + MTA-STS Setup: https://fenghe.vivaldi.net/2024/06/25/how-to-setup-smtp-dane-and-mta-sts/
- postfix-tlspol (DANE+MTA-STS): https://github.com/Zuplu/postfix-tlspol
- OpenDKIM + Postfix: https://easydmarc.com/blog/how-to-configure-dkim-opendkim-with-postfix/
- Rspamd Integration: https://linuxize.com/post/install-and-integrate-rspamd/
- Dovecot SASL for Postfix: https://doc.dovecot.org/main/howto/sasl/postfix.html
- TLS-RPT, DANE, MTA-STS (ArchWiki): https://wiki.archlinux.org/title/TLS-RPT,_DANE_and_MTA-STS
- Postfix 3.10 PQC support: https://linuxiac.com/postfix-3-10-mta-arrives-with-openssl-3-5-support/
