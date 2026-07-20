# Postfix Best Practices

## TLS Configuration

### Server-Side TLS (Inbound)

Modern certificate configuration (Postfix 3.4+):

```ini
# main.cf -- TLS for inbound SMTP
smtpd_tls_chain_files =
    /etc/postfix/rsa.pem,
    /etc/postfix/ecdsa.pem
smtpd_tls_security_level = may          # opportunistic
smtpd_tls_loglevel = 1
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = medium
smtpd_tls_exclude_ciphers = aNULL, eNULL, EXPORT, RC4, DES, 3DES, MD5
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_mandatory_ciphers = high
smtpd_tls_auth_only = yes               # require TLS before SASL AUTH
```

**PEM file order for `smtpd_tls_chain_files`:** Private key, then leaf cert, then intermediates (bottom-up).

Legacy configuration (Postfix < 3.4):
```ini
smtpd_tls_cert_file = /etc/ssl/certs/mail.crt
smtpd_tls_key_file = /etc/ssl/private/mail.key
smtpd_tls_CAfile = /etc/ssl/certs/ca-bundle.crt
```

### Client-Side TLS (Outbound)

```ini
smtp_tls_security_level = may            # opportunistic
smtp_tls_loglevel = 1
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_ciphers = medium
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
```

### TLS Security Levels

| Level | Description |
|-------|-------------|
| `none` | TLS disabled |
| `may` | Opportunistic; try TLS, fall back to plaintext |
| `encrypt` | Mandatory encryption; reject if TLS unavailable |
| `dane` | DNSSEC + TLSA records required (client only) |
| `dane-only` | Like dane but never deliver without valid TLSA |
| `verify` | Verify certificate chain against trust anchors |
| `secure` | Verify + hostname check |
| `fingerprint` | Verify by certificate fingerprint |

### DANE

Built into Postfix. Requires DNSSEC-validating resolver:

```ini
smtp_dns_support_level = dnssec
smtp_tls_security_level = dane
smtp_host_lookup = dns
```

Verify TLSA: `posttls-finger -l secure -T 25 mail.example.com`

**TLSA key rollover:**
1. Publish new TLSA record alongside existing
2. Wait for DNS TTL (24-48h)
3. Deploy new certificate
4. Remove old TLSA after another TTL

### MTA-STS

Postfix does not natively support MTA-STS. Use external resolver:

```ini
# With postfix-tlspol
smtp_tls_policy_maps = socketmap:inet:127.0.0.1:8642:postfix
```

### TLSRPT (Postfix 3.10)

RFC 8460 support for TLS connection reporting:

```dns
_smtp._tls.example.com. IN TXT "v=TLSRPTv1; rua=mailto:tlsrpt@example.com"
```

### Submission Port (587)

```
# master.cf
submission inet n - y - - smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_sasl_type=dovecot
  -o smtpd_sasl_path=private/auth
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
```

---

## SASL Authentication

### Dovecot SASL (Recommended)

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

### SASL for Outbound Relay

```ini
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

## Anti-Spam Pipeline

### Postscreen

Pre-filters inbound connections, blocking spambots with a single process:

```ini
# main.cf
postscreen_access_list = permit_mynetworks, cidr:/etc/postfix/postscreen_access.cidr
postscreen_cache_map = lmdb:$data_directory/postscreen_cache
postscreen_greet_wait = 6s
postscreen_greet_action = drop
postscreen_dnsbl_threshold = 3
postscreen_dnsbl_sites =
    zen.spamhaus.org*3,
    bl.spamcop.net*2,
    b.barracudacentral.org*2
postscreen_dnsbl_action = enforce
postscreen_pipelining_enable = yes
postscreen_pipelining_action = drop
postscreen_non_smtp_command_enable = yes
postscreen_non_smtp_command_action = drop
```

In `master.cf` (replace default smtp with postscreen):
```
smtp      inet  n       -       y       -       1       postscreen
smtpd     pass  -       -       y       -       -       smtpd
dnsblog   unix  -       -       y       -       0       dnsblog
tlsproxy  unix  -       -       y       -       0       tlsproxy
```

### OpenDKIM

```bash
opendkim-genkey -s mail -d example.com -D /etc/opendkim/keys/example.com/
chmod 640 /etc/opendkim/keys/example.com/mail.private
chown opendkim:opendkim /etc/opendkim/keys/example.com/mail.private
```

`/etc/opendkim.conf`:
```
Mode                sv
Socket              inet:8891@127.0.0.1
Domain              example.com
KeyFile             /etc/opendkim/keys/example.com/mail.private
Selector            mail
InternalHosts       /etc/opendkim/trusted.hosts
```

DNS record:
```
mail._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=<base64-public-key>"
```

### OpenDMARC

```ini
# main.cf
smtpd_milters = inet:127.0.0.1:8891, inet:127.0.0.1:8893
```

DNS record:
```
_dmarc.example.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com; pct=100"
```

### Rspamd (Modern All-in-One)

Rspamd handles spam scoring, DKIM, DMARC, ARC, Bayes filtering, URL blocklists:

```ini
# main.cf
smtpd_milters = inet:127.0.0.1:11332
milter_default_action = accept
```

### Full Milter Pipeline

```ini
milter_default_action = accept
milter_protocol = 6
smtpd_milters =
    inet:127.0.0.1:8891,    # OpenDKIM
    inet:127.0.0.1:8893,    # OpenDMARC
    inet:127.0.0.1:11332    # Rspamd
non_smtpd_milters =
    inet:127.0.0.1:8891     # DKIM signing for local submissions
```

### Amavis + ClamAV + SpamAssassin

After-queue content filter:

```ini
# main.cf
content_filter = scan:[127.0.0.1]:10024
receive_override_options = no_address_mappings
```

```
# master.cf (re-injection)
127.0.0.1:10025 inet  n  -  n  -  -  smtpd
  -o content_filter=
  -o receive_override_options=no_header_body_checks
  -o smtpd_authorized_xforward_hosts=127.0.0.0/8
```

---

## Performance Tuning

### Rate Limiting (Anvil)

```ini
anvil_rate_time_unit = 60s
smtpd_client_connection_rate_limit = 10
smtpd_client_connection_count_limit = 10
smtpd_client_message_rate_limit = 100
smtpd_client_recipient_rate_limit = 200
```

Clients in `$mynetworks` are exempt by default.

### Delivery Concurrency

```ini
default_destination_concurrency_limit = 20
smtp_destination_concurrency_limit = 5
local_destination_concurrency_limit = 2
```

### Message Limits

```ini
message_size_limit = 52428800              # 50 MB
mailbox_size_limit = 1073741824            # 1 GB
smtpd_recipient_limit = 1000
```

### Queue Timing

```ini
queue_run_delay = 300s
minimal_backoff_time = 300s
maximal_backoff_time = 4000s
maximal_queue_lifetime = 5d
bounce_queue_lifetime = 5d
```

---

## Dovecot Integration

### LMTP Delivery

```ini
# main.cf
virtual_transport = lmtp:unix:private/dovecot-lmtp
```

Dovecot configuration:
```
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}
```

### Let's Encrypt Certificate Renewal

```bash
certbot certonly --standalone -d mail.example.com --pre-hook "systemctl stop postfix" --post-hook "systemctl start postfix"

# Or with webroot (no downtime):
certbot certonly --webroot -w /var/www/html -d mail.example.com --deploy-hook "postfix reload && systemctl reload dovecot"
```

Update `main.cf` to point to Let's Encrypt paths:
```ini
smtpd_tls_chain_files = /etc/letsencrypt/live/mail.example.com/privkey.pem, /etc/letsencrypt/live/mail.example.com/fullchain.pem
```

---

## Security Hardening Checklist

- [ ] `smtpd_relay_restrictions` includes `reject_unauth_destination` (prevents open relay)
- [ ] TLS 1.2+ only (`smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1`)
- [ ] `smtpd_tls_auth_only = yes` (SASL only over TLS)
- [ ] DKIM signing enabled (OpenDKIM or Rspamd)
- [ ] SPF published and validated (`check_policy_service` or Rspamd)
- [ ] DMARC published and enforced (`p=quarantine` or `p=reject`)
- [ ] Postscreen enabled for inbound port 25
- [ ] DNSBL checks active (`reject_rbl_client zen.spamhaus.org`)
- [ ] `sasl_passwd` file permissions 600 (no world-readable credentials)
- [ ] Message size limits set appropriately
- [ ] Queue lifetime configured (not infinite)
- [ ] Log rotation configured for mail.log
