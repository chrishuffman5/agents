# Pulumi Architecture

## Engine Internals

### Resource Lifecycle

```
Program declares resource
        │
        ▼
┌──────────────────┐
│  Register with   │  Engine records URN, inputs, dependencies
│  Engine          │
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Diff against    │  Compare declared inputs vs state
│  State           │
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Provider CRUD   │  Create, Update, Delete, or Read
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Update State    │  Record outputs, dependencies
└──────────────────┘
```

### URN (Uniform Resource Name)

Every Pulumi resource has a unique URN:

```
urn:pulumi:<stack>::<project>::<type>::<name>
urn:pulumi:production::my-app::aws:s3/bucket:Bucket::my-bucket
```

URN components:
- **Stack**: The deployment environment (dev, staging, production)
- **Project**: The Pulumi project name
- **Type**: Provider and resource type
- **Name**: The logical name given in code

### Output/Input Model

Outputs represent values that may not be known until after deployment:

```
                    ┌──────────────┐
  Resource A ──────▶│  Output<ID>  │──────▶ Resource B (Input)
  (created first)   └──────────────┘       (depends on A)
```

- **Output<T>**: A promise-like wrapper. Value resolved after resource creation.
- **Input<T>**: Accepts `T`, `Output<T>`, or `Promise<T>`.
- **apply()**: Transform an Output's value. Creates a dependency chain.
- **all()**: Combine multiple Outputs. `pulumi.all([a, b]).apply(([aVal, bVal]) => ...)`.
- **interpolate**: Tagged template literal for string concatenation with Outputs.

### Provider System

Pulumi providers are gRPC plugins (same protocol concept as Terraform):

| Provider | Resources | Source |
|---|---|---|
| `@pulumi/aws` | 1000+ AWS resources | Bridged from Terraform AWS provider |
| `@pulumi/azure-native` | Azure resources (ARM-native) | Generated from Azure API specs |
| `@pulumi/gcp` | GCP resources | Bridged from Terraform GCP provider |
| `@pulumi/kubernetes` | All K8s resources | Native K8s API |
| `@pulumi/docker` | Docker resources | Bridged from Terraform Docker provider |

**Bridged providers**: Most Pulumi providers are automatically generated from Terraform providers using the Pulumi Terraform Bridge. This means:
- Same resource coverage as Terraform
- Terraform provider bugs/features propagate
- Some Terraform idioms feel awkward in general-purpose languages

**Native providers**: Azure Native and Kubernetes are built directly from API specs, providing better type safety and coverage.

## Pulumi Cloud Architecture

| Component | Purpose |
|---|---|
| **State storage** | Encrypted state backend with versioning |
| **Secrets** | Encrypted secret values in state and config |
| **RBAC** | Organization, team, and stack-level permissions |
| **CI/CD** | Pulumi Deployments (managed deploy), Review Stacks |
| **Policy** | CrossGuard policy-as-code (OPA-like) |
| **ESC** | Environments, Secrets, and Configuration management |
| **Insights** | Resource search, compliance reporting |

### Pulumi ESC (Environments, Secrets, and Configuration)

```yaml
# environments/production.yaml
values:
  aws:
    login:
      fn::open::aws-login:
        oidc:
          roleArn: arn:aws:iam::123456789012:role/PulumiOIDC
          sessionName: pulumi-deploy
    region: us-east-1
  database:
    host: prod-db.example.com
    password:
      fn::secret: SuperSecret123

# Use in Pulumi config
environmentImports:
  - production
```

## Deployment Engine

### Step Generator

The deployment engine generates a sequence of steps:

1. **Same** — Resource unchanged, skip
2. **Create** — New resource, call provider Create
3. **Update** — Resource changed, call provider Update
4. **Replace** — Resource requires replacement (delete old, create new)
5. **Delete** — Resource removed from program, call provider Delete
6. **Read** — External resource, call provider Read

### Parallelism

Pulumi deploys independent resources in parallel by default:

```bash
# Control parallelism
pulumi up --parallel 10    # Max 10 concurrent operations (default: unlimited)
```

Dependencies are respected — a resource won't be created until its dependencies are ready.

### Resource Options

```typescript
const resource = new aws.s3.Bucket("my-bucket", { /*...*/ }, {
    // Common resource options
    dependsOn: [otherResource],          // Explicit dependency
    parent: parentComponent,              // Parent component
    provider: customProvider,             // Specific provider instance
    protect: true,                        // Prevent deletion
    ignoreChanges: ["tags"],             // Ignore changes to specific properties
    deleteBeforeReplace: true,            // Delete before creating replacement
    aliases: [{ name: "old-name" }],     // Handle renames without replacement
    retainOnDelete: true,                 // Keep resource when removed from program
    transformations: [addDefaultTags],    // Transform resource properties
    import: "existing-resource-id",       // Import existing resource
});
```
