#!/usr/bin/env bash
# Purpose:        Audit Postfix TLS posture and relay restrictions - deliverability and open-relay safety in one pass
# Applies to:     Postfix 3.8+ (postconf is read-only; run on the mail host)
# Read-only:      yes
# Inputs:         none
# Interpretation: smtpd_relay_restrictions MUST end effectively in reject_unauth_destination - without it you risk an
#                 OPEN RELAY (spammers relay through you, your IP gets blocklisted, all mail fails). smtp_tls_security_level
#                 = 'may' is opportunistic (fine for outbound to the world); 'dane' or 'encrypt' for partners requiring
#                 it. Inbound: smtpd_tls_security_level should be at least 'may'. 3.10 adds TLSRPT - if configured,
#                 you get TLS failure reports. Missing DKIM/DMARC milters = deliverability problems (those live in
#                 the milter chain, checked here).
# Next step:      Fix any relay restriction gap immediately (open relay is critical); enforce TLS to partners that require it

set -euo pipefail

echo "== Relay restrictions (must reject unauth destinations)"
postconf smtpd_relay_restrictions smtpd_recipient_restrictions

echo
echo "== TLS posture"
postconf smtp_tls_security_level smtpd_tls_security_level smtp_tls_CAfile smtpd_tls_cert_file

echo
echo "== Milters (DKIM/DMARC signing/verification chain)"
postconf smtpd_milters non_smtpd_milters milter_default_action

echo
echo "== SASL auth (inbound submission)"
postconf smtpd_sasl_auth_enable smtpd_sasl_type
