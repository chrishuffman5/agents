# Secrets Management — Core Concepts

Deep reference for secrets management fundamentals, rotation patterns, envelope encryption, HSMs, PKI concepts, X.509 certificates, and the ACME protocol.

---

## Secret Rotation Patterns

### Why Rotation Matters

Rotation limits the window of exposure if a credential is compromised. A secret rotated every 24 hours can only be exploited for up to 24 hours even if stolen immediately after rotation.

### Rotation Strategies

**Manual rotation** — Human-driven, error-prone, infrequent. Acceptable only for low-risk, low-count secrets with SLA.

**Scheduled rotation** — Automated on a calendar (e.g., every 30 days). Better, but still creates windows. Most secrets managers support this natively.

**Event-driven rotation** — Rotated on trigger: detected breach, employee departure, anomalous access. Requires integration with SIEM/threat detection.

**Dynamic secrets (best)** — Secret is generated fresh for each requester, valid for a short TTL. No rotation needed because secrets are effectively single-use. Vault database engine is the canonical example.

### Zero-Downtime Rotation

Applications must tolerate credential rotation without restarting. Patterns:

**Versioned secrets (AWSCURRENT / AWSPREVIOUS)**:
1. New secret generated and stored as `AWSPENDING`
2. Target system updated to accept new credential
3. `AWSPENDING` promoted to `AWSCURRENT`, old value becomes `AWSPREVIOUS`
4. Grace period: both old and new accepted
5. Old credential revoked after grace period

**Blue-green credential rotation**:
- Maintain two valid credentials at all times
- Rotate by retiring the older and issuing a new "other slot"
- No application restart required

**Connection pool re-validation**:
- Applications must handle auth failures by re-fetching credentials
- Use circuit breaker + retry with backoff on DB auth failure
- Health check endpoints should detect stale credentials

### Rotation for Specific Secret Types

| Secret Type | Recommended TTL | Rotation Mechanism |
|---|---|---|
| Database passwords | 24h (dynamic) or 30d | Vault DB engine / AWS SM Lambda |
| API keys | 90d (static) | Custom Lambda or Vault agent |
| TLS certificates | 90d (ACME) or 6d (Let's Encrypt new) | cert-manager / ACME renewal |
| SSH host keys | Annual or on compromise | Manual + automation |
| JWT signing keys | 7-30d | JWKS endpoint rotation |
| Cloud IAM credentials | Avoid static — use roles | STS / Managed Identity |

---

## Envelope Encryption — Deep Dive

### The Problem

You cannot store encryption keys alongside the data they protect. And you cannot re-encrypt terabytes of data every time a key rotates.

### The Pattern

```
                 ┌─────────────────────────────────────┐
                 │           Key Management Service      │
                 │  ┌─────────────────────────────────┐ │
                 │  │  Key Encryption Key (KEK / CMK)  │ │
                 │  │  Lives in HSM — never exported   │ │
                 │  └─────────────────────────────────┘ │
                 └─────────────────────────────────────┘
                          │ Encrypt/Decrypt DEK
                          ▼
┌──────────────────────────────────────────────────────┐
│  Application / Storage Layer                          │
│                                                       │
│  Plaintext ──encrypt──► Ciphertext                   │
│                │                                      │
│                └──with DEK (Data Encryption Key)      │
│                                                       │
│  DEK ──encrypt with KEK──► Encrypted DEK             │
│  Store: { Ciphertext + Encrypted DEK } together      │
└──────────────────────────────────────────────────────┘
```

### Key Rotation Without Re-Encryption

When the KEK is rotated:
1. Fetch the encrypted DEK for each data item
2. Decrypt the DEK using the old KEK
3. Re-encrypt the DEK using the new KEK
4. Store the new encrypted DEK

The actual ciphertext is never touched. Only the small DEK ciphertext is re-encrypted. This makes key rotation O(number of unique data objects), not O(data size).

### AWS KMS Implementation

```
GenerateDataKey(KeyId=CMK_ARN) →
  { Plaintext: DEK_bytes, CiphertextBlob: encrypted_DEK }

Use Plaintext DEK to encrypt data with AES-256-GCM
Immediately zero/discard Plaintext DEK from memory
Store CiphertextBlob alongside ciphertext

To decrypt:
  Decrypt(CiphertextBlob) → Plaintext DEK
  Use DEK to decrypt ciphertext
```

### Vault Transit Engine Implementation

The Transit engine provides encryption-as-a-service. Applications never see the key:
- `transit/encrypt/my-key` — Submit plaintext, receive ciphertext
- `transit/decrypt/my-key` — Submit ciphertext, receive plaintext
- Key rotation generates new key version; old versions retained for decryption
- `rewrap` endpoint re-encrypts ciphertexts with latest key version (batch supported)

---

## Hardware Security Modules (HSMs)

### What an HSM Provides

1. **Key protection** — Private keys generated inside HSM, never exported in plaintext
2. **Cryptographic operations** — Signing, encryption, decryption performed inside hardware
3. **Tamper evidence / resistance** — Physical attack destroys keys
4. **Audit** — All operations logged with operator identity

### FIPS 140-3 Levels

| Level | Requirement |
|---|---|
| Level 1 | Correct cryptographic algorithms, no physical requirements |
| Level 2 | Tamper-evident (seals/coatings), role-based authentication |
| Level 3 | Tamper-resistant (zeroizes on attack), identity-based auth, physical security |
| Level 4 | Complete envelope protection, detects environmental attacks |

Cloud services typically provide Level 3:
- AWS CloudHSM: FIPS 140-3 Level 3
- Azure Managed HSM: FIPS 140-3 Level 3
- Azure Key Vault Premium (multi-tenant HSM): FIPS 140-3 Level 3
- GCP Cloud HSM: FIPS 140-3 Level 3

### HSM vs. Software Key Store

| Concern | HSM | Software (e.g., Vault Shamir) |
|---|---|---|
| Key extraction | Physically impossible | Possible if host is compromised |
| Performance | Hardware-accelerated crypto | CPU-bound |
| Cost | Significant (CloudHSM ~$1.45/hr) | Low |
| Compliance | PCI-DSS, FedRAMP High | Generally insufficient for HSM-mandated controls |
| Operational complexity | High (quorum management, backup) | Lower |

### When HSM Is Required

- Payment card data (PCI-DSS Requirement 3.5)
- FedRAMP High or DoD IL4+ workloads
- eIDAS qualified signatures
- Code signing for critical infrastructure
- Any control requiring "hardware-based key storage"

---

## PKI Fundamentals

### Certificate Hierarchy

```
Root CA (offline, air-gapped)
  └── Intermediate CA (online, signs end-entity certs)
        └── Intermediate CA (optional additional tier)
              ├── TLS Server Certificate
              ├── TLS Client Certificate
              ├── Code Signing Certificate
              └── Email/S/MIME Certificate
```

**Root CA**: Self-signed, the ultimate trust anchor. Should be kept offline (air-gapped) to protect the root private key. Intermediate CAs are signed by the root; if an intermediate is compromised, the root can revoke it without rebuilding trust.

**Intermediate CA**: Online, issues end-entity certificates. If compromised, can be revoked by the root.

**End-Entity (Leaf) Certificate**: Issued to a specific subject (server, user, device). Cannot sign other certificates (`CA:FALSE` in Basic Constraints).

### Trust Stores

Operating systems and browsers ship with a set of trusted Root CA certificates. Certificates issued by any CA in this set (or their intermediates) are trusted automatically.

| Platform | Trust Store Location |
|---|---|
| Linux | `/etc/ssl/certs/`, `/etc/pki/tls/certs/` |
| macOS | System Keychain |
| Windows | Cert Store (certmgr.msc) |
| Java | `$JAVA_HOME/lib/security/cacerts` |
| Firefox | Bundled NSS store (ignores OS) |
| Chrome/Safari | OS trust store |

---

## X.509 Certificate Structure

### Key Fields

```
Certificate:
  Version: 3
  Serial Number: 0x...  (unique per CA)
  Signature Algorithm: sha256WithRSAEncryption

  Issuer:   CN=Example Intermediate CA, O=Example Corp, C=US
  Validity:
    Not Before: 2025-01-01 00:00:00 UTC
    Not After:  2025-04-01 00:00:00 UTC  (90-day cert)
  Subject:  CN=api.example.com, O=Example Corp

  Subject Public Key Info:
    Algorithm: rsaEncryption (or id-ecPublicKey)
    Public Key: ...

  Extensions (v3):
    Subject Alternative Name (SAN): DNS:api.example.com, DNS:*.api.example.com
    Basic Constraints: CA:FALSE
    Key Usage: Digital Signature, Key Encipherment
    Extended Key Usage: TLS Web Server Authentication
    Subject Key Identifier: ...
    Authority Key Identifier: ...
    CRL Distribution Points: http://crl.example.com/intermediate.crl
    Authority Information Access:
      OCSP: http://ocsp.example.com
      CA Issuers: http://certs.example.com/intermediate.crt
```

### Critical Extensions

**Subject Alternative Name (SAN)**: The authoritative field for hostnames and IPs (not CN, which is deprecated for host matching). Must include all DNS names and IP addresses the certificate will be used for.

**Basic Constraints**: `CA:TRUE` (+ optionally `pathLen` constraint) for CA certs; `CA:FALSE` for end-entity. Critical extension.

**Key Usage**: Restricts how the key can be used:
- `digitalSignature` — TLS handshakes, code signing
- `keyEncipherment` — RSA key exchange (TLS 1.2 RSA)
- `keyCertSign` — Can sign other certificates (CA only)
- `cRLSign` — Can sign CRLs

**Extended Key Usage (EKU)**:
- `serverAuth` (1.3.6.1.5.5.7.3.1) — TLS server
- `clientAuth` (1.3.6.1.5.5.7.3.2) — Mutual TLS client
- `codeSigning` (1.3.6.1.5.5.7.3.3) — Code signing
- `emailProtection` (1.3.6.1.5.5.7.3.4) — S/MIME

### Certificate Encoding Formats

| Format | Extension | Description |
|---|---|---|
| PEM | `.pem`, `.crt`, `.cer`, `.key` | Base64 DER with `-----BEGIN...-----` header |
| DER | `.der`, `.cer` | Binary encoding, used in Java and Windows APIs |
| PKCS#12 | `.p12`, `.pfx` | Container for cert + private key, password-protected |
| PKCS#7 | `.p7b`, `.p7c` | Certificate chain without private key |
| JKS | `.jks` | Java KeyStore, Java-specific |

---

## Certificate Revocation

### CRL (Certificate Revocation List)

A signed, periodic list of revoked serial numbers published by the CA. Clients must download and cache. Problems:
- Can grow very large
- Published on a schedule (not real-time)
- Clients often fail open when CRL is unavailable

### OCSP (Online Certificate Status Protocol)

Real-time protocol: client sends serial number, OCSP responder returns `good`, `revoked`, or `unknown`. Problems:
- Privacy (CA learns which certificates are being validated)
- Availability dependency (OCSP responder must be up)
- Performance (extra round-trip per TLS handshake)

### OCSP Stapling

Server fetches its own OCSP response and staples it to the TLS handshake. Addresses privacy and performance issues. The stapled response is signed by the OCSP responder, so it cannot be forged. Certificate must have `must-staple` extension to prevent stripping.

### CAA (Certification Authority Authorization) DNS Record

DNS record that specifies which CAs are authorized to issue certificates for a domain:
```
example.com. CAA 0 issue "letsencrypt.org"
example.com. CAA 0 issuewild ";"        ; prohibit wildcard
example.com. CAA 0 iodef "mailto:security@example.com"
```
CAs must check CAA before issuance (required by CA/Browser Forum). Does not prevent issuance by rogue CAs, but creates accountability.

---

## Certificate Transparency (CT) Logs

All publicly-trusted CAs are required (per Chrome and Apple policies) to submit every issued certificate to at least two Certificate Transparency logs. Certificates not in CT logs are rejected by modern browsers.

CT logs are append-only, cryptographically verifiable logs using a Merkle tree structure. They enable:
- Detection of misissued certificates for your domain
- Monitoring: tools like `crt.sh`, Facebook CT Monitor, Cloudflare CT Monitor
- Post-breach forensics

Monitoring CT logs for your domain is an essential security practice. Subscribe to alerts via:
- `https://crt.sh/?q=example.com` — Search issued certificates
- Certificate Transparency Policy API
- Commercial CLM tools (Venafi, DigiCert TLM)

---

## ACME Protocol

### Overview

ACME (Automatic Certificate Management Environment, RFC 8555) is the protocol used by Let's Encrypt and implemented by most modern CAs. It automates the entire certificate lifecycle: domain validation, issuance, renewal, and revocation.

### ACME Flow

```
1. Account Registration
   Client → Server: POST /acme/new-account
   Server → Client: Account URL + ACME account key

2. Order Creation
   Client → Server: POST /acme/new-order { identifiers: [dns:example.com] }
   Server → Client: Order URL, list of Authorization URLs, Finalize URL

3. Authorization / Challenge
   Client: GET each Authorization URL
   Server: List of challenges (HTTP-01, DNS-01, TLS-ALPN-01)
   Client: Provision challenge response (file, DNS record, or TLS cert)
   Client → Server: POST challenge URL to indicate ready
   Server: Validates challenge

4. Certificate Finalization
   Client: Generate private key + CSR
   Client → Server: POST finalize URL with CSR
   Server → Client: Certificate URL when ready

5. Certificate Download
   Client: GET certificate URL
   Server → Client: Certificate chain (PEM)

6. Renewal
   Repeat from step 2 before expiry (typically at 2/3 of lifetime)
```

### ACME Challenge Types

**HTTP-01**: Provision a file at `http://example.com/.well-known/acme-challenge/{token}`. Easiest for single servers with port 80 access. Cannot be used for wildcard certificates.

**DNS-01**: Create a `_acme-challenge.example.com` TXT record with the key authorization. Required for wildcard certificates. Works when HTTP is not accessible. Requires DNS API access for automation.

**TLS-ALPN-01**: Provision a special TLS certificate served on port 443 with ACME protocol negotiation. Alternative to HTTP-01 when only port 443 is accessible.

### ACME Certificate Lifetimes

| CA | Standard Lifetime | Short-Lived Option |
|---|---|---|
| Let's Encrypt | 90 days (current) | 6 days (launched March 2025) |
| Let's Encrypt | 45 days opt-in | (May 2026) |
| ZeroSSL | 90 days | — |
| Google Trust Services | 90 days | — |
| Smallstep | Configurable (default 24h) | Minutes |

Short-lived certificates (6-day Let's Encrypt) eliminate the need for revocation — by the time a compromise is detected, the certificate has likely already expired. This is the direction the industry is moving.

### Rate Limits (Let's Encrypt)

| Limit | Value |
|---|---|
| Certificates per Registered Domain | 50/week |
| Duplicate Certificates | 5/week |
| Failed Validations | 5/hour per account per hostname |
| Accounts per IP | 10/3 hours |
| Pending Authorizations | 300 |

Staging environment (`acme-staging-v02.api.letsencrypt.org`) has higher limits for testing.

---

## PKI Design Patterns

### Internal PKI for Zero-Trust

For internal services (mTLS, service-to-service auth):
- Use Vault PKI engine or smallstep CA
- Issue short-lived certificates (hours to days), not 1-year
- No revocation infrastructure needed if TTL is short
- SPIFFE/SPIRE for workload identity using X.509 SVIDs

### Certificate Pinning (and why not to use it)

Pinning hard-codes the expected certificate or public key. Breaks on legitimate rotation. Almost universally considered an anti-pattern for general applications. Acceptable only for:
- Mobile apps where you control both client and server
- High-security internal tooling with controlled deployment

### Wildcard vs. SAN Certificates

**Wildcard** (`*.example.com`): Covers one level of subdomains. Cannot cover root domain or deeper subdomains (`sub.sub.example.com`). Shares one private key across all subdomains — compromise of one service exposes all.

**Multi-SAN**: Lists each hostname explicitly. Better security isolation. Preferred for production workloads. cert-manager makes these trivial in Kubernetes.
