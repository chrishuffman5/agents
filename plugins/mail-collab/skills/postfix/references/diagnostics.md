# Postfix Diagnostics

## Queue Issues

### Queue Building Up

```bash
# Check queue size
mailq | tail -1
# Output: "-- 1234 Kbytes in 567 Requests."

# Check which destinations are backed up
postqueue -p | awk '/^[A-F0-9]/{print $NF}' | sort | uniq -c | sort -rn | head

# Check for specific queue issues
postqueue -p | grep "^[A-F0-9]" | awk '{print $5}' | sort | uniq -c | sort -rn
```

### Common Queue Error Messages

| Error in Queue | Meaning | Fix |
|---|---|---|
| `Connection timed out` | Cannot reach destination server | Check DNS resolution, firewall rules, destination server health |
| `Connection refused` | Destination port 25 closed | Check destination server is running, firewall allows SMTP |
| `Host or domain name not found` | DNS resolution failure | Check DNS resolver, verify MX/A records exist |
| `mail for example.com loops back to myself` | MX points to this server but domain is not in `mydestination` | Add domain to `mydestination` or `virtual_mailbox_domains`, or fix MX |
| `Relay access denied` | Missing `reject_unauth_destination` or domain not in relay_domains | Check relay restrictions and domain configuration |
| `Helo command rejected` | HELO/EHLO restrictions blocking sender | Review `smtpd_helo_restrictions` |
| `Sender address rejected` | Sender restrictions blocking | Review `smtpd_sender_restrictions` |
| `Insufficient system resources` | Back pressure from disk/memory | Check disk space, memory, queue size |

### Flushing Stuck Mail

```bash
# Retry all deferred messages
postqueue -f

# Retry messages for a specific domain
postqueue -s example.com

# Delete all deferred messages (lost permanently)
postsuper -d ALL deferred

# Requeue messages (re-process through cleanup)
postsuper -r ALL
```

### Mail Loops

**Error:** `mail for example.com loops back to myself`

**Causes:**
1. MX record points to this server, but the domain is not in `mydestination` or `virtual_mailbox_domains`
2. Transport map routes to this server
3. Relay host routes back to this server

**Fix:**
```bash
# Check if domain is configured
postconf mydestination virtual_mailbox_domains relay_domains

# If this server should accept for the domain:
postconf -e 'mydestination = $myhostname, localhost, example.com'
# OR
postconf -e 'virtual_mailbox_domains = example.com'

# If this server should NOT accept:
# Fix MX record in DNS to point to the correct server
```

---

## TLS Issues

### TLS Handshake Failures

```bash
# Test inbound TLS
openssl s_client -connect mail.example.com:25 -starttls smtp

# Test with specific TLS version
openssl s_client -connect mail.example.com:25 -starttls smtp -tls1_2

# Check certificate details
openssl s_client -connect mail.example.com:25 -starttls smtp 2>/dev/null | openssl x509 -noout -subject -dates -issuer

# Test outbound TLS to a destination
posttls-finger -l secure mail.example.com
```

### Common TLS Errors

| Log Entry | Meaning | Fix |
|---|---|---|
| `SSL_accept error from unknown` | Client TLS handshake failed | Check certificate validity, protocol/cipher match |
| `certificate verification failed for` | Outbound cert verification failure | Check CA bundle: `smtp_tls_CAfile` |
| `Untrusted TLS connection established` | TLS works but cert not trusted | Normal for opportunistic; add CA for `verify`/`secure` level |
| `Cannot start TLS: handshake failure` | TLS negotiation failed | Check protocols/ciphers, cert chain completeness |
| `TLS library problem` | OpenSSL error | Update OpenSSL, check cert file permissions |

### Certificate Issues

```bash
# Verify certificate chain
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /etc/postfix/cert.pem

# Check PEM file order (for smtpd_tls_chain_files)
openssl x509 -in /etc/postfix/rsa.pem -noout -subject
# Should show: private key first, then leaf cert, then intermediates

# Check certificate expiry
openssl x509 -in /etc/postfix/cert.pem -noout -enddate

# Verify DANE TLSA records
posttls-finger -l secure -T 25 mail.example.com
```

---

## Relay and Authentication Issues

### Open Relay Test

```bash
# Test from external host (not in mynetworks)
telnet mail.example.com 25
EHLO test.example.com
MAIL FROM:<test@evil.com>
RCPT TO:<victim@gmail.com>
# Should get: 554 5.7.1 <victim@gmail.com>: Relay access denied
```

If relay is permitted, check:
```bash
postconf smtpd_relay_restrictions smtpd_recipient_restrictions mynetworks
# Ensure reject_unauth_destination is present
```

### SASL Authentication Failures

**Log entry:** `warning: SASL authentication failure: no mechanism available`

**Fixes:**
```bash
# Check SASL configuration
postconf smtpd_sasl_type smtpd_sasl_path smtpd_sasl_auth_enable

# If using Dovecot SASL, verify socket exists:
ls -la /var/spool/postfix/private/auth

# If socket missing, check Dovecot auth listener config:
# /etc/dovecot/conf.d/10-master.conf
# service auth { unix_listener /var/spool/postfix/private/auth { ... } }

# Restart Dovecot to recreate socket
systemctl restart dovecot
```

**Log entry:** `warning: unknown smtpd_sasl_type: dovecot`

**Fix:** Install Dovecot and its auth components. Postfix must be compiled with Dovecot SASL support.

### Outbound Relay Failures

**Log entry:** `SASL authentication failed; server smtp.provider.com said: 535 Authentication failed`

```bash
# Verify credentials file
postmap -q "[smtp.provider.com]:587" /etc/postfix/sasl_passwd

# Test connection manually
openssl s_client -connect smtp.provider.com:587 -starttls smtp
# Then test AUTH manually with base64-encoded credentials
```

---

## Milter Issues

### Milter Unavailable

**Log entry:** `milter-reject: connect from unknown: 451 4.7.1 Service unavailable - try again later`

**Cause:** Milter daemon not running or socket not accessible.

```bash
# Check milter is running
systemctl status opendkim
systemctl status opendmarc
systemctl status rspamd

# Check socket connectivity
nc -z 127.0.0.1 8891 && echo "OpenDKIM OK" || echo "OpenDKIM DOWN"
nc -z 127.0.0.1 8893 && echo "OpenDMARC OK" || echo "OpenDMARC DOWN"
nc -z 127.0.0.1 11332 && echo "Rspamd OK" || echo "Rspamd DOWN"

# If milter is down and you need mail to flow:
# Set milter_default_action = accept (temporary workaround)
postconf -e 'milter_default_action = accept'
postfix reload
```

### DKIM Signing Not Working

1. Check OpenDKIM is running: `systemctl status opendkim`
2. Check socket: `postconf smtpd_milters non_smtpd_milters`
3. Check key permissions: `ls -la /etc/opendkim/keys/example.com/mail.private`
4. Check OpenDKIM config: `opendkim -t -x /etc/opendkim.conf`
5. Test DKIM signing: Send test email, check headers for `DKIM-Signature`
6. Verify DNS record: `dig +short TXT mail._domainkey.example.com`

### Rspamd Issues

```bash
# Check Rspamd status
rspamadm control stat

# Test a message against Rspamd
rspamc < /tmp/test-message.eml

# Check Rspamd logs
journalctl -u rspamd -f
```

---

## Delivery Failures

### Local Delivery Failures

| Error | Cause | Fix |
|---|---|---|
| `mail system not listed as domain destination` | Domain not in `mydestination` | Add to `mydestination` or use virtual |
| `alias loops for user@example.com` | Circular alias definition | Check `/etc/postfix/aliases` for loops |
| `cannot update mailbox /var/mail/user` | Permissions or disk full | Fix permissions (`chown`, `chmod`), free disk space |
| `mailbox full` | User quota exceeded | Increase `mailbox_size_limit` or clean mailbox |

### LMTP Delivery Failures

**Error:** `status=deferred (connect to dovecot.internal[private/dovecot-lmtp]: Connection refused)`

```bash
# Check Dovecot LMTP is running
systemctl status dovecot
doveadm service status lmtp

# Check socket
ls -la /var/spool/postfix/private/dovecot-lmtp

# If using TCP:
nc -z dovecot.internal 24 && echo "LMTP OK" || echo "LMTP DOWN"
```

---

## Log Analysis

### Key Log Locations

- Debian/Ubuntu: `/var/log/mail.log`, `/var/log/mail.err`
- RHEL/CentOS: `/var/log/maillog`
- Systemd journal: `journalctl -u postfix -f`

### Log Analysis Tools

```bash
# Summary report (install pflogsumm)
pflogsumm /var/log/mail.log

# Find rejected messages
grep "NOQUEUE: reject" /var/log/mail.log | tail -20

# Find deferred messages
grep "status=deferred" /var/log/mail.log | tail -20

# Find bounced messages
grep "status=bounced" /var/log/mail.log | tail -20

# Trace a specific message ID
grep "ABC123DEF" /var/log/mail.log

# Count messages per status
grep "status=" /var/log/mail.log | grep -oP 'status=\w+' | sort | uniq -c | sort -rn
```

### Common Log Patterns

```
# Successful delivery
postfix/smtp[1234]: ABC123: to=<user@example.com>, relay=mail.example.com[1.2.3.4]:25, delay=1.5, status=sent (250 2.0.0 Ok: queued)

# Deferred delivery
postfix/smtp[1234]: ABC123: to=<user@example.com>, relay=none, delay=3600, status=deferred (connect to mail.example.com[1.2.3.4]:25: Connection timed out)

# Rejected at RCPT TO
postfix/smtpd[1234]: NOQUEUE: reject: RCPT from unknown[5.6.7.8]: 554 5.7.1 <victim@gmail.com>: Relay access denied

# Milter rejection
postfix/smtpd[1234]: NOQUEUE: milter-reject: END-OF-MESSAGE from client[5.6.7.8]: 550 5.7.1 Blocked by DMARC policy
```

---

## Postscreen Issues

### Legitimate Clients Blocked

**Symptom:** Clients disconnected after pregreet test or DNSBL check.

```bash
# Check postscreen cache
postmap -s lmdb:$data_directory/postscreen_cache

# Allowlist a legitimate sender
# /etc/postfix/postscreen_access.cidr
1.2.3.0/24    permit
```

**Tuning:**
- Increase `postscreen_greet_wait` if fast legitimate servers are caught
- Adjust `postscreen_dnsbl_threshold` if too many false positives
- Use `enforce` instead of `drop` for DNSBL action (temp-fail instead of disconnect)

### Postscreen vs. Postfix Proxy Protocol

If using HAProxy or load balancer in front of Postfix, postscreen needs PROXY protocol support or the load balancer must pass through TCP directly.

---

## Performance Issues

### High Load / Slow Delivery

```bash
# Check process count
ps aux | grep postfix | wc -l

# Check active queue size
find /var/spool/postfix/active -type f | wc -l

# Check deferred queue size
find /var/spool/postfix/deferred -type f | wc -l

# Check disk I/O
iostat -x 1 5

# Check if queue is stuck on specific destination
postqueue -p | awk '/^[A-F0-9]/{print $NF}' | sort | uniq -c | sort -rn | head
```

**Common fixes:**
- Increase `default_process_limit` if all process slots are full
- Increase `default_destination_concurrency_limit` for high-volume destinations
- Check DNS resolver performance (slow DNS = slow delivery)
- Verify disk I/O is not bottlenecked (SSD recommended for queue directory)
