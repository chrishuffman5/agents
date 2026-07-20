# Vault PKI Secret Engine

Full Certificate Authority built into Vault. Used for internal PKI, mTLS, and as an ACME CA.

```bash
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki

# Generate Root CA
vault write pki/root/generate/internal \
    common_name="My Root CA" \
    ttl=87600h

# Configure URLs
vault write pki/config/urls \
    issuing_certificates="https://vault.example.com/v1/pki/ca" \
    crl_distribution_points="https://vault.example.com/v1/pki/crl"

# Create Intermediate CA
vault secrets enable -path=pki_int pki
vault write pki_int/intermediate/generate/internal common_name="My Intermediate CA"
# Sign with root, then set signed cert
vault write pki/root/sign-intermediate csr=@pki_int.csr format=pem_bundle ttl=43800h
vault write pki_int/intermediate/set-signed certificate=@signed.pem

# Create a role for issuing certs
vault write pki_int/roles/my-service \
    allowed_domains="internal.example.com" \
    allow_subdomains=true \
    max_ttl=72h

# Issue a certificate
vault write pki_int/issue/my-service \
    common_name="api.internal.example.com" \
    ttl=24h
```
