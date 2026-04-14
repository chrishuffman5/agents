# Postfix Architecture Deep Reference

## Master Daemon (master(8))

The `master` process supervises the entire Postfix system:
- Starts all server processes on demand
- Monitors process health, restarts crashed servers
- Enforces per-service process count limits from `master.cf`
- Reads `master.cf` at startup; `postfix reload` re-reads it
- Does NOT handle mail itself -- only orchestrates daemons

## Queue Manager (qmgr(8))

Heart of Postfix mail delivery:
- Maintains the active queue as a limited window into the full queue
- Contacts delivery agents with delivery requests
- Schedules retries with exponential backoff
- Implements per-destination concurrency limits and rate controls

### Queue Directories

| Queue | Purpose |
|-------|---------|
| `incoming` | Newly arrived or re-injected messages |
| `active` | Messages opened for delivery (limited window) |
| `deferred` | Messages pending retry |
| `hold` | Administratively held messages |
| `corrupt` | Damaged or malformed queue files |

The active queue size is deliberately limited to prevent memory exhaustion. The queue manager never lets all deferred mail flood active simultaneously.

## Delivery Agents

| Agent | Purpose |
|-------|---------|
| `local(8)` | Local UNIX mailboxes, Maildir, aliases, .forward |
| `virtual(8)` | Virtual mailbox delivery (multi-domain, no UNIX accounts) |
| `smtp(8)` | Remote SMTP/ESMTP delivery |
| `lmtp(8)` | LMTP to mailbox servers (Dovecot, Cyrus) |
| `pipe(8)` | External programs (Procmail, Dovecot LDA) |
| `discard(8)` | Silent discard (blackhole addresses) |
| `error(8)` | Return with configurable error message |

## Supporting Daemons

| Daemon | Role |
|--------|------|
| `smtpd(8)` | Inbound SMTP connections |
| `pickup(8)` | Monitors maildrop for local submissions |
| `cleanup(8)` | Header rewriting, content inspection, normalization |
| `trivial-rewrite(8)` | Address rewriting and recipient classification |
| `bounce(8)`, `defer(8)`, `trace(8)` | DSN generation |
| `tlsmgr(8)` | TLS session cache and PRNG |
| `tlsproxy(8)` | TLS encryption/decryption proxy |
| `anvil(8)` | Connection and rate limiting |
| `postscreen(8)` | Pre-SMTP zombie/spambot blocking |
| `verify(8)` | Address verification probing |
| `proxymap(8)` | Shared lookup table access |
| `scache(8)` | SMTP connection caching |
| `postlogd(8)` | Alternative logging (file or stdout; 3.4+) |

## Mail Flow

### Inbound (SMTP)

```
Internet SMTP client
    --> smtpd(8)              [access checks, milters, TLS]
    --> cleanup(8)            [header rewriting, content inspection]
    --> incoming queue
    --> qmgr(8)              [scheduling, concurrency control]
    --> delivery agent        [local/virtual/smtp/lmtp/pipe]
```

### Local Submission

```
sendmail(1) / postdrop(1)
    --> maildrop queue
    --> pickup(8)
    --> cleanup(8)
    --> incoming queue
    --> qmgr(8) --> delivery agent
```

---

## Virtual Domain Classes

Postfix has four recipient address classes processed in order:

1. **Local** (`$mydestination`) -- Delivered by `local(8)`
2. **Virtual alias** (`$virtual_alias_domains`) -- Mapped to other addresses
3. **Virtual mailbox** (`$virtual_mailbox_domains`) -- Delivered by `virtual(8)`
4. **Relay** (`$relay_domains`) -- Forwarded to another MTA

**Critical rule:** Never list the same domain in more than one class. Never list virtual domains in `$mydestination`.

### Virtual Alias Domains

All addresses map to real addresses elsewhere:

```ini
virtual_alias_domains = alias-domain.com
virtual_alias_maps = lmdb:/etc/postfix/virtual
```

```
# /etc/postfix/virtual
postmaster@alias-domain.com   postmaster@example.com
info@alias-domain.com         admin@example.com
@alias-domain.com             catchall@example.com
```

### Virtual Mailbox Domains

Own mailboxes, no UNIX accounts:

```ini
virtual_mailbox_domains = example.com, example.net
virtual_mailbox_base = /var/mail/vhosts
virtual_mailbox_maps = lmdb:/etc/postfix/vmailbox
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000
```

Trailing slash in path means Maildir; no slash means mbox.

### Transport Maps

Override delivery method per domain:

```ini
transport_maps = lmdb:/etc/postfix/transport
```

```
# /etc/postfix/transport
example.com     lmtp:[dovecot.internal]:24
oldmail.com     error:mailbox has moved
slow.net        smtp:[relay.slow.net]:25
```

---

## Milter Interface

Milters plug into the smtpd pipeline via the Sendmail Milter API:

```ini
smtpd_milters = inet:127.0.0.1:8891    # SMTP-received mail
non_smtpd_milters = inet:127.0.0.1:8891 # Locally submitted mail
```

**Socket formats:**
- `inet:host:port` -- TCP socket
- `unix:pathname` -- UNIX domain socket

**Per-milter configuration (3.0+):**
```ini
smtpd_milters = {
    inet:127.0.0.1:8891,
    connect_timeout=10s,
    default_action=accept
}
```

`milter_default_action` controls behavior when milter is unavailable: `accept`, `reject`, `tempfail` (default), `quarantine`.

**Milter actions:** Accept, reject (with custom error), discard, quarantine, add/remove/change headers, add/remove recipients.

---

## Access Control and Restrictions

Restrictions are evaluated left-to-right; first PERMIT or REJECT wins.

### Restriction Lists

```ini
# Connection time
smtpd_client_restrictions = permit_mynetworks, reject_unknown_client_hostname

# HELO/EHLO
smtpd_helo_restrictions = permit_mynetworks, reject_invalid_helo_hostname, reject_non_fqdn_helo_hostname

# MAIL FROM
smtpd_sender_restrictions = permit_mynetworks, reject_non_fqdn_sender, reject_unknown_sender_domain

# RCPT TO (relay control -- mandatory)
smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination

# RCPT TO (anti-spam)
smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination, reject_rbl_client zen.spamhaus.org
```

**`reject_unauth_destination` must appear** in `smtpd_relay_restrictions` or early in `smtpd_recipient_restrictions` to prevent open relay.

### Common Restriction Actions

| Restriction | Effect |
|-------------|--------|
| `permit_mynetworks` | Allow if client IP in $mynetworks |
| `permit_sasl_authenticated` | Allow if SASL auth succeeded |
| `reject_unauth_destination` | Reject if not local or relay domain |
| `reject_unknown_client_hostname` | Reject if no valid FCrDNS |
| `reject_rbl_client zen.spamhaus.org` | Reject if client IP in DNSBL |
| `check_policy_service` | Delegate to external policy daemon |

---

## Lookup Table Types

| Type | Usage | Notes |
|------|-------|-------|
| `lmdb` | General key-value | Preferred on modern systems |
| `hash` | General key-value | Berkeley DB; legacy |
| `pcre` | Regex matching | Read-only, full file in memory |
| `regexp` | POSIX regex | Less powerful than pcre |
| `ldap` | LDAP directory | No reload needed after changes |
| `mysql` / `pgsql` | Database | No reload needed |
| `mongodb` | MongoDB | New in Postfix 3.9 |
| `static` | Fixed value | e.g., `static:5000` for uid maps |
| `socketmap` | Socket protocol | For MTA-STS resolvers |

---

## master.cf Service Definitions

Each line defines a service with 8 fields:

```
# service  type  private  unpriv  chroot  wakeup  maxproc  command
smtp       inet  n        -       y       -       -        smtpd
submission inet  n        -       y       -       -        smtpd
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
pickup     unix  n        90      n       60      1        pickup
cleanup    unix  n        -       y       -       0        cleanup
qmgr       unix  n        n       n       300     1        qmgr
```

**Column meanings:**
- `type`: `inet` (TCP), `unix` (UNIX socket), `pass` (passed from another daemon)
- `private`: `y` means only Postfix processes can access
- `unpriv`: `y` means runs as unprivileged user
- `chroot`: `y` means runs in chroot jail
- `maxproc`: max simultaneous processes (0 = `$default_process_limit`)

## Address Rewriting

### Canonical Maps

```ini
sender_canonical_maps = lmdb:/etc/postfix/sender_canonical
recipient_canonical_maps = lmdb:/etc/postfix/recipient_canonical
```

### Masquerading

Hide internal hostnames:
```ini
masquerade_domains = example.com
masquerade_exceptions = root, postmaster
```

### Generic Maps (Outbound)

```ini
smtp_generic_maps = lmdb:/etc/postfix/generic
```

```
root@internal.lab    admin@example.com
@internal.lab        noreply@example.com
```

### Header and Body Checks

```ini
header_checks = regexp:/etc/postfix/header_checks
body_checks = regexp:/etc/postfix/body_checks
```

Actions: `REJECT`, `HOLD`, `DISCARD`, `WARN`, `PREPEND`, `REPLACE`, `REDIRECT`, `FILTER`.
