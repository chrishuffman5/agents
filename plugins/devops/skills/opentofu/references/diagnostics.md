# OpenTofu Diagnostics

## Provider Compatibility Issues

### Provider Not Found in Registry

```
Error: Failed to query available provider packages
Could not retrieve the list of available versions for provider hashicorp/xxx
```

**Cause**: Provider not yet mirrored in the OpenTofu Registry.

**Resolution:**
1. Check OpenTofu Registry: `https://registry.opentofu.org/`
2. Configure Terraform Registry as fallback:
   ```hcl
   provider_installation {
     direct {}
   }
   ```
3. Use a filesystem or network mirror for air-gapped environments

### Provider GPG Signature Mismatch

```
Error: Failed to install provider: the provider registry returned a
provider signed by an unknown GPG key
```

**Resolution:**
- OpenTofu may use different signing keys than Terraform Registry
- Run `tofu init` with `-upgrade` to refresh provider cache
- Check provider source configuration in `required_providers`

## State Encryption Issues

### Decryption Failed

```
Error: Failed to decrypt state: cipher: message authentication failed
```

**Cause**: Wrong encryption key or corrupted state.

**Resolution:**
1. Verify the key provider configuration matches what was used to encrypt
2. Check environment variables for KMS credentials
3. For PBKDF2: verify the passphrase is correct
4. If using key rotation: ensure the fallback method has the old key

### Enabling Encryption on Existing State

```bash
# Add encryption configuration to your .tf files, then:
tofu init -migrate-state

# This re-reads the unencrypted state and writes it encrypted
# Verify with:
tofu plan    # Should show no changes
```

### Lost Encryption Key

If the encryption key is lost and no backup exists:
- **State is unrecoverable** from the encrypted file
- **Resources still exist** in the cloud — they're not destroyed
- Recovery: Create new `.tf` files and `tofu import` each resource
- **Prevention**: Always back up KMS keys, store PBKDF2 passphrases in a secret manager

## Migration Issues

### State Format Mismatch

```
Error: Unsupported state file format
```

**Cause**: State was written by a newer Terraform version with format changes.

**Resolution:**
- Check state version: `tofu state pull | jq .version`
- OpenTofu supports state format version 4 (same as Terraform 1.x)
- If state was modified by a much newer Terraform, it may be incompatible

### Backend Configuration Differences

```
Error: Variables not allowed in backend configuration
```

**Note**: This error occurs in **Terraform**, not OpenTofu. If you're migrating configs that use OpenTofu's early variable evaluation back to Terraform, you'll need to refactor backend configuration to use `-backend-config` flags.

## Common Debugging

```bash
# Enable verbose logging
export TF_LOG=DEBUG
export TF_LOG_PATH=tofu-debug.log

# Validate configuration
tofu validate

# Check provider versions
tofu providers

# Inspect state
tofu state list
tofu state show <resource>
tofu state pull > state.json

# Compare plan
tofu plan -out=plan.tfplan
tofu show -json plan.tfplan | jq '.resource_changes[]'
```

## Terraform vs OpenTofu Behavior Differences

When troubleshooting, check if the behavior difference is due to:

1. **Feature divergence**: The feature was implemented differently in OpenTofu
2. **Registry difference**: Provider version available differs between registries
3. **Version mismatch**: Using an OpenTofu version that doesn't include the feature yet
4. **Bug**: Check OpenTofu GitHub issues for known issues

```bash
# Check OpenTofu version
tofu version

# Compare with Terraform
terraform version
```
