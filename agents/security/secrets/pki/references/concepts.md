# PKI & Certificate Management — Core Concepts

Deep reference for PKI fundamentals, X.509 certificate structure, certificate chains, CRL/OCSP, Certificate Transparency logs, and the ACME protocol.

> **Note**: For the foundational concepts including envelope encryption, HSMs, and secret rotation, see `../references/concepts.md`. This file focuses specifically on PKI and certificates.

---

## X.509 Certificate Deep Dive

### Certificate Structure (ASN.1 / DER)

An X.509 v3 certificate (RFC 5280) is a DER-encoded ASN.1 structure:

```
Certificate  ::=  SEQUENCE {
  tbsCertificate      TBSCertificate,    -- "To Be Signed"
  signatureAlgorithm  AlgorithmIdentifier,
  signatureValue      BIT STRING
}

TBSCertificate ::= SEQUENCE {
  version          [0] INTEGER { v3(2) },
  serialNumber     CertificateSerialNumber,
  signature        AlgorithmIdentifier,   -- must match outer signatureAlgorithm
  issuer           Name,
  validity         Validity { notBefore, notAfter },
  subject          Name,
  subjectPublicKeyInfo SubjectPublicKeyInfo,
  extensions       [3] SEQUENCE OF Extension
}
```

### Critical Extensions

**Subject Alternative Name (SAN)** — OID 2.5.29.17

Required for all modern TLS certificates. The `commonName` (CN) in the Subject is deprecated for hostname matching (RFC 2818, enforced by browsers since ~2017).

```
DNS:example.com
DNS:www.example.com
DNS:*.example.com    # wildcard — covers one level only
IP:192.168.1.1
email:user@example.com
URI:https://example.com
```

**Basic Constraints** — OID 2.5.29.19, CRITICAL for CAs

```
CA: TRUE, pathLenConstraint: 0   → Can sign leaf certs only (no sub-CAs)
CA: TRUE, pathLenConstraint: 1   → Can sign one level of sub-CA
CA: TRUE                          → No path length constraint
CA: FALSE                         → Leaf (end-entity) certificate
```

**Key Usage** — OID 2.5.29.15, CRITICAL

Bit string defining allowed operations:
```
digitalSignature   → TLS handshake, ECDH key agreement (TLS 1.3)
nonRepudiation     → Legal signatures
keyEncipherment    → RSA key exchange (TLS 1.2)
dataEncipherment   → Rarely used
keyAgreement       → ECDH/DH
keyCertSign        → Sign certificates (CA only)
cRLSign            → Sign CRLs (CA only)
encipherOnly       → Combined with keyAgreement
decipherOnly       → Combined with keyAgreement
```

For TLS server: `digitalSignature` + `keyEncipherment` (RSA) or `digitalSignature` (ECDSA).

**Extended Key Usage (EKU)** — OID 2.5.29.37

| OID | Name | Use |
|---|---|---|
| 1.3.6.1.5.5.7.3.1 | serverAuth | TLS server certificate |
| 1.3.6.1.5.5.7.3.2 | clientAuth | TLS client certificate (mTLS) |
| 1.3.6.1.5.5.7.3.3 | codeSigning | Code signing |
| 1.3.6.1.5.5.7.3.4 | emailProtection | S/MIME |
| 1.3.6.1.5.5.7.3.8 | timeStamping | RFC 3161 timestamp tokens |
| 1.3.6.2.1.4.1.311.10.3.3 | (Microsoft) | EFS |

**Authority Key Identifier (AKI)** — OID 2.5.29.35

Identifies the CA key that signed this certificate. Used for chain building when multiple CA certificates exist.

**Subject Key Identifier (SKI)** — OID 2.5.29.14

Hash of the subject's public key. Used in AKI of certificates signed by this cert.

**CRL Distribution Points** — OID 2.5.29.31

HTTP URLs where the CRL can be downloaded:
```
URI:http://crl.example.com/intermediate.crl
```

**Authority Information Access (AIA)** — OID 1.3.6.1.5.5.7.1.1

Two sub-types:
- `OCSP` — URL of OCSP responder
- `caIssuers` — URL where the issuing CA certificate can be downloaded

**Certificate Policies** — OID 2.5.29.32

Policy OIDs indicating compliance with a Certificate Practice Statement (CPS). The `2.23.140.1.2.1` (DV), `2.23.140.1.2.2` (OV), `2.23.140.1.2.3` (EV) policy OIDs are used by CAs to indicate validation level.

**Must Staple** — OID 1.3.6.1.5.5.7.1.24

Signals that the server MUST provide a stapled OCSP response. Clients should reject the certificate if no staple is present during TLS handshake.

---

## Certificate Chain Validation

A client validating a TLS certificate:

1. **Build a chain** from the leaf certificate to a trusted root
2. **Verify each signature** in the chain
3. **Check validity period** (notBefore, notAfter) for each cert
4. **Check revocation** for each cert (CRL or OCSP, unless OCSP stapling)
5. **Verify hostname** matches Subject Alternative Name
6. **Check EKU** includes `serverAuth`
7. **Check Basic Constraints** — intermediate certs must have `CA: TRUE`
8. **Verify path length** constraints are not exceeded

### Chain Building

Clients use the AKI extension to find the issuing CA certificate. The issuer's SKI should match the subject's AKI.

**Common chain issues**:
- **Missing intermediate**: Server must serve the full chain (leaf + all intermediates, not root)
- **Wrong order**: Chain should be leaf → intermediate → (optionally) root
- **Cross-signed intermediates**: Some CAs cross-sign intermediates with multiple roots for backward compatibility (Let's Encrypt R3 is cross-signed)
- **Expired intermediate**: Intermediate expiry affects all leaf certs it issued

---

## Certificate Revocation

### CRL (Certificate Revocation List) — RFC 5280

A signed, time-stamped list of revoked certificate serial numbers published by the CA.

**CRL structure**:
```
CertificateList  ::=  SEQUENCE {
  tbsCertList          TBSCertList,
  signatureAlgorithm   AlgorithmIdentifier,
  signatureValue       BIT STRING
}

TBSCertList ::= SEQUENCE {
  version                 INTEGER OPTIONAL { v2(1) },
  signature               AlgorithmIdentifier,
  issuer                  Name,
  thisUpdate              Time,
  nextUpdate              Time OPTIONAL,
  revokedCertificates     SEQUENCE OF SEQUENCE {
    userCertificate         CertificateSerialNumber,
    revocationDate          Time,
    crlEntryExtensions      Extensions OPTIONAL
  } OPTIONAL,
  crlExtensions       [0] CRITICAL Extensions OPTIONAL
}
```

**CRL problems**:
- CRLs can be large (MBs for large CAs)
- Published periodically (typically 24h or 7 days) — not real-time
- Clients often fail open if CRL URL is unreachable (soft-fail)
- Delta CRLs reduce download size but add complexity

### OCSP (Online Certificate Status Protocol) — RFC 6960

HTTP-based protocol for real-time certificate status queries:

```
Client → OCSP Responder:
  Request: issuerNameHash, issuerKeyHash, serialNumber

OCSP Responder → Client:
  Response: { good | revoked | unknown }
  + Signature by OCSP signing cert
  + thisUpdate, nextUpdate
```

**OCSP response status values**:
- `good`: Certificate is not revoked (does not mean it was validly issued)
- `revoked`: Certificate is revoked (with revocation time and reason code)
- `unknown`: Responder doesn't know about this certificate

**OCSP problems**:
- Privacy: CA learns which certificates you're validating
- Availability: Clients depend on OCSP responder uptime
- Performance: Extra round-trip per TLS handshake
- Soft-fail behavior: Most clients fail open if OCSP is unreachable

### OCSP Stapling — RFC 6066 / RFC 6961

The TLS server pre-fetches its own OCSP response and includes it in the TLS handshake as a "Certificate Status" extension.

**Benefits**:
- Eliminates client privacy concern (no client-to-CA connection)
- No extra RTT for client
- OCSP responder availability less critical (server caches response)

**Limitations**:
- OCSP staple has a validity period (typically 24h-7d); server must refresh
- An attacker who has the cert and private key could suppress the staple
- `must-staple` extension prevents staple stripping (client rejects if no staple)

**nginx configuration**:
```nginx
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/ssl/chain.pem;
resolver 8.8.8.8 8.8.4.4 valid=300s;
```

**Apache configuration**:
```apache
SSLUseStapling on
SSLStaplingCache "shmcb:logs/ssl_stapling(32768)"
```

### Revocation Reasons (X.509 Reason Codes)

| Code | Reason | Description |
|---|---|---|
| 0 | unspecified | Generic revocation |
| 1 | keyCompromise | Private key compromised |
| 2 | cACompromise | CA key compromised |
| 3 | affiliationChanged | Subject name changed |
| 4 | superseded | Certificate replaced |
| 5 | cessationOfOperation | Service discontinued |
| 6 | certificateHold | Temporary suspension |
| 9 | privilegeWithdrawn | Authorization revoked |
| 10 | aACompromise | Attribute authority compromised |

---

## Certificate Transparency (CT)

### Overview

CT (RFC 6962) is a system of append-only, publicly auditable logs that record all certificates issued by publicly-trusted CAs. Browsers require CT proof before trusting certificates.

### How CT Works

1. CA submits certificate (pre-certificate or final) to CT log(s)
2. CT log returns a Signed Certificate Timestamp (SCT)
3. CA embeds SCT in the certificate, or serves via TLS extension, or OCSP response
4. Browser verifies SCT signature from a trusted CT log
5. Anyone can monitor CT logs for unauthorized issuance for their domain

### SCT Delivery Methods

| Method | Pros | Cons |
|---|---|---|
| Embedded in certificate | Always present, no server config | CA must submit before issuance |
| TLS extension | Server controls, no cert change | Requires server config |
| OCSP staple | Combined with OCSP staple | OCSP must support it |

### CT Log Monitoring

Monitor CT logs for your domain at:
- `https://crt.sh/?q=example.com` — Query all logs
- `https://censys.io/` — Certificate search
- Facebook CT Monitor (discontinued; use crt.sh)

Alert on:
- New certificates for your domain not in your certificate inventory
- Certificates with unexpected SANs
- Certificates from unexpected CAs (correlate with your CAA records)

---

## ACME Protocol Deep Dive (RFC 8555)

### Protocol Objects

**Account**: A registered ACME client, identified by a key pair (RSA or ECDSA). The account key signs all requests.

**Order**: A request for a certificate for a set of identifiers (DNS names or IP addresses).

**Authorization**: Proof that the ACME client controls a specific identifier. One authorization per DNS name per order.

**Challenge**: A method of proving domain control. The client must complete one challenge per authorization.

**CSR**: Certificate Signing Request submitted after completing authorizations. Contains the public key for the new certificate.

### JWS-Based Protocol

All ACME requests are JSON Web Signature (JWS) objects:
```json
{
  "protected": "<base64url encoded header>",
  "payload": "<base64url encoded payload>",
  "signature": "<base64url encoded signature>"
}
```

Header contains:
- `alg`: Signing algorithm (RS256, ES256, etc.)
- `nonce`: Anti-replay nonce from ACME server
- `url`: URL being requested (prevents replay to different URL)
- `jwk` (first request) or `kid` (subsequent requests)

### Challenge Types — Technical Detail

**HTTP-01**:
```
Token: RANDOM_TOKEN_VALUE
Key Authorization: RANDOM_TOKEN_VALUE.BASE64URL(SHA256(accountKey_JWK))

Provisioned at:
  http://example.com/.well-known/acme-challenge/RANDOM_TOKEN_VALUE
  Content: KEY_AUTHORIZATION
  Content-Type: text/plain (or application/octet-stream)
```

Requirements: Port 80 accessible, no redirects to HTTPS before token is verified.

**DNS-01**:
```
Token: RANDOM_TOKEN_VALUE
DNS Record:
  Name:  _acme-challenge.example.com.
  Type:  TXT
  Value: BASE64URL(SHA256(KEY_AUTHORIZATION))
```

Required for wildcard certificates. DNS propagation delay must be handled (client waits for DNS propagation before notifying ACME server to validate).

**TLS-ALPN-01**:
```
Protocol: acme-tls/1 (ALPN extension in ClientHello)
Certificate served:
  Subject: example.com (SAN)
  acmeValidation-v1 extension (OID 1.3.6.1.5.5.7.1.31):
    SHA256(KEY_AUTHORIZATION) as ASN.1 octet string
```

### Rate Limits (Let's Encrypt Production)

| Limit | Value | Notes |
|---|---|---|
| Certificates per Registered Domain | 50 / week | Sliding 7-day window |
| Duplicate Certificates | 5 / week | Same set of SANs |
| Failed Validations | 5 / hour / account / hostname | |
| New Orders | 300 / 3 hours / account | |
| Pending Authorizations | 300 / account | |
| New Accounts per IP | 10 / 3 hours | |
| Accounts per IP range (/48) | 500 / 3 hours | |

Staging environment: 10x higher limits, uses untrusted root.

### Certificate Profiles (Let's Encrypt 2025+)

Let's Encrypt added ACME certificate profiles for selecting certificate characteristics:
- `tlsserver`: Default 90-day TLS server certificate
- `tlsserver6day`: 6-day short-lived TLS server certificate (launched March 2025)

```bash
# Request 6-day certificate with certbot
certbot certonly --preferred-chain "ISRG Root X1" \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --cert-name example.com \
    -d example.com
# Currently: negotiate profile via ACME profile extension (RFC draft)
```

---

## Key Algorithms

### RSA

- **Sizes**: 2048 (minimum), 3072 (recommended new), 4096 (high security)
- **Signature schemes**: PKCS#1 v1.5 (RSA-PKCS1) and PSS (RSA-PSS)
- **Pros**: Universal compatibility
- **Cons**: Large key/signature size, slower than ECC
- **SHA-1 forbidden**: All signatures must use SHA-2 (SHA-256 minimum)

### ECDSA

- **Curves**: P-256 (most compatible), P-384 (higher security), P-521 (very high security)
- **Pros**: Smaller keys, faster operations, equivalent security to RSA at much shorter length
- **Cons**: Not supported by some legacy systems
- **ECDSA P-256** ≈ RSA-3072 security level; use for most TLS certificates

### Ed25519

- **Use**: SSH certificates, code signing, JWT signing
- **Not** supported for TLS server certificates in X.509 by most browsers yet
- Faster than ECDSA P-256, simpler implementation (immune to timing attacks)

### Key Length Recommendations (2025+)

| Algorithm | Minimum | Recommended | Notes |
|---|---|---|---|
| RSA | 2048 | 3072 | 4096 for long-lived certs (5+ years) |
| ECDSA | P-256 | P-256 or P-384 | P-256 has widest compatibility |
| Ed25519 | — | Use where supported | Not yet in X.509 for TLS broadly |
| DSA | Deprecated | Do not use | Vulnerable, removed from TLS 1.3 |
