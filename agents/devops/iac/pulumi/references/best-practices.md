# Pulumi Best Practices

## Project Organization

### Repository Structure

```
infrastructure/
├── Pulumi.yaml                  # Project definition
├── Pulumi.dev.yaml              # Dev stack config
├── Pulumi.staging.yaml          # Staging stack config
├── Pulumi.production.yaml       # Production stack config
├── index.ts                     # Entry point (TypeScript)
├── package.json
├── tsconfig.json
├── components/                  # Reusable ComponentResources
│   ├── vpc.ts
│   ├── eks-cluster.ts
│   └── rds-instance.ts
└── config/                      # Configuration helpers
    └── index.ts
```

### Multi-Project Layout

For large infrastructure, split into separate Pulumi projects:

```
infrastructure/
├── network/                     # VPC, subnets, DNS
│   ├── Pulumi.yaml
│   └── index.ts
├── data/                        # Databases, caches
│   ├── Pulumi.yaml
│   └── index.ts
├── compute/                     # EKS, EC2
│   ├── Pulumi.yaml
│   └── index.ts
└── shared/                      # Shared components (npm package)
    ├── package.json
    └── src/
        ├── vpc.ts
        └── rds.ts
```

Use `StackReference` for cross-stack references:

```typescript
const networkStack = new pulumi.StackReference("org/network/production");
const vpcId = networkStack.getOutput("vpcId");
```

## Component Design

### Good Component Properties

```typescript
// Inputs interface — clear, typed, documented
interface VpcArgs {
    cidrBlock: pulumi.Input<string>;
    availabilityZones: pulumi.Input<string[]>;
    enableNatGateway?: pulumi.Input<boolean>;  // Optional with default
    tags?: pulumi.Input<Record<string, string>>;
}

class Vpc extends pulumi.ComponentResource {
    // Outputs — expose what consumers need
    public readonly vpcId: pulumi.Output<string>;
    public readonly privateSubnetIds: pulumi.Output<string[]>;
    public readonly publicSubnetIds: pulumi.Output<string[]>;

    constructor(name: string, args: VpcArgs, opts?: pulumi.ComponentResourceOptions) {
        super("custom:networking:Vpc", name, args, opts);
        // Resources created with { parent: this }
        // registerOutputs at the end
    }
}
```

### Component Rules

1. **Always pass `{ parent: this }`** to child resources for proper URN hierarchy
2. **Call `registerOutputs`** at the end of the constructor
3. **Use Input types** for args to accept both raw values and Outputs
4. **Export Output types** for public properties
5. **Namespace the type** — `custom:category:Name` to avoid collisions

## Testing

### Unit Tests

```typescript
// __tests__/vpc.test.ts
import * as pulumi from "@pulumi/pulumi";

// Mock Pulumi runtime
pulumi.runtime.setMocks({
    newResource: (args) => ({
        id: `${args.name}-id`,
        state: args.inputs,
    }),
    call: (args) => ({}),
});

describe("VPC", () => {
    it("should create a VPC with the correct CIDR", async () => {
        const { Vpc } = await import("../components/vpc");
        const vpc = new Vpc("test", { cidrBlock: "10.0.0.0/16" });

        const cidr = await new Promise<string>((resolve) =>
            vpc.vpcId.apply(resolve)
        );
        expect(cidr).toBeDefined();
    });
});
```

### Integration Tests

```typescript
import { LocalWorkspace } from "@pulumi/pulumi/automation";

test("deploys and validates infrastructure", async () => {
    const stack = await LocalWorkspace.createOrSelectStack({
        stackName: "test",
        projectName: "my-project",
        program: async () => {
            // Inline program
            const bucket = new aws.s3.Bucket("test-bucket");
            return { bucketName: bucket.id };
        },
    });

    const upResult = await stack.up();
    expect(upResult.outputs.bucketName.value).toBeDefined();

    // Cleanup
    await stack.destroy();
});
```

## Secret Management

```bash
# Set a secret (encrypted in state and config)
pulumi config set --secret dbPassword MySecret123

# In code — secrets stay encrypted
const config = new pulumi.Config();
const dbPassword = config.requireSecret("dbPassword");
// dbPassword is Output<string> — marked as secret, won't appear in logs
```

### Secret Providers

| Provider | Command |
|---|---|
| Pulumi Cloud (default) | `pulumi stack init --secrets-provider default` |
| AWS KMS | `pulumi stack init --secrets-provider awskms://keyId` |
| Azure Key Vault | `pulumi stack init --secrets-provider azurekeyvault://vaultUrl/keyName` |
| GCP KMS | `pulumi stack init --secrets-provider gcpkms://projects/p/locations/l/keyRings/r/cryptoKeys/k` |
| Passphrase | `pulumi stack init --secrets-provider passphrase` |

## CI/CD Integration

```yaml
# GitHub Actions
- uses: pulumi/actions@v5
  with:
    command: up
    stack-name: production
  env:
    PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}
```

### Review Stacks (Preview in PRs)

```yaml
# On PR: preview changes
- uses: pulumi/actions@v5
  with:
    command: preview
    stack-name: production
    comment-on-pr: true    # Post plan output as PR comment
```

## Common Mistakes

1. **Treating Outputs as plain values** — `Output<string>` is not `string`. Use `.apply()` or `pulumi.interpolate`.
2. **Not using `{ parent: this }`** — Child resources without parent have flat URNs, breaking component encapsulation.
3. **Hardcoding secrets** — Always use `config.requireSecret()`, never hardcode in code.
4. **Too many resources per stack** — Large stacks are slow. Split by lifecycle and blast radius.
5. **Not pinning provider versions** — Lock provider versions in package.json/requirements.txt.
