# Pulumi Diagnostics

## Common Errors

### Output Resolution Errors

```
Error: Calling [toString] on an [Output<T>] is not supported.
To get the value of an Output<T> as an Output<string>, use `pulumi.interpolate`
```

**Cause**: Trying to use an `Output<T>` as a plain value.

**Resolution:**
```typescript
// BAD
const url = `https://${bucket.id}.s3.amazonaws.com`;

// GOOD
const url = pulumi.interpolate`https://${bucket.id}.s3.amazonaws.com`;

// Or use .apply()
const url = bucket.id.apply(id => `https://${id}.s3.amazonaws.com`);
```

### Provider Authentication

```
Error: error configuring AWS provider: no valid credential sources found
```

**Resolution:**
- Set AWS credentials via environment variables or AWS profiles
- Configure OIDC for CI/CD (Pulumi Cloud supports OIDC natively)
- Use Pulumi ESC for centralized credential management

### State Conflict

```
Error: the current deployment has N resource(s) with pending operations
```

**Cause**: Previous `pulumi up` was interrupted, leaving pending operations.

**Resolution:**
```bash
# Export state, remove pending operations, import
pulumi stack export > state.json
# Edit state.json: remove "pending_operations" array
pulumi stack import < state.json

# Then refresh to reconcile
pulumi refresh
```

### Resource Already Exists

```
Error: creating resource: already exists
```

**Resolution:**
```bash
# Import the existing resource
pulumi import aws:s3/bucket:Bucket my-bucket existing-bucket-name

# Or in code
const bucket = new aws.s3.Bucket("my-bucket", { /*...*/ }, {
    import: "existing-bucket-name",
});
```

## Debugging

### Verbose Logging

```bash
# Increase verbosity (1-9)
pulumi up -v=5

# Debug specific components
PULUMI_DEBUG_GRPC=true pulumi up
```

### Stack Inspection

```bash
# View stack state
pulumi stack export | jq '.deployment.resources | length'

# List resources
pulumi stack --show-urns

# Show outputs
pulumi stack output --json
```

### Refresh to Detect Drift

```bash
# Compare state against actual cloud resources
pulumi refresh

# Preview what refresh would change
pulumi refresh --preview-only
```

## Migration from Terraform

```bash
# Convert Terraform state to Pulumi
pulumi import --from terraform ./terraform.tfstate

# Generate Pulumi code from Terraform HCL
pulumi convert --from terraform --language typescript

# Import individual resources
pulumi import aws:s3/bucket:Bucket my-bucket my-existing-bucket
```
