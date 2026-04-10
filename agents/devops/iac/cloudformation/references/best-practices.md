# CloudFormation Best Practices

## Template Design

### Use Parameters with Constraints

```yaml
Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, staging, production]
    ConstraintDescription: Must be dev, staging, or production
  InstanceType:
    Type: String
    Default: t3.micro
    AllowedPattern: '^[a-z][0-9]+[a-z]?\.[a-z0-9]+$'
  VpcCidr:
    Type: String
    Default: 10.0.0.0/16
    AllowedPattern: '^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$'
```

### Use Conditions for Environment Differences

```yaml
Conditions:
  IsProd: !Equals [!Ref Environment, production]
  IsNotProd: !Not [!Equals [!Ref Environment, production]]
  NeedNAT: !Or [!Condition IsProd, !Equals [!Ref Environment, staging]]

Resources:
  NATGateway:
    Type: AWS::EC2::NatGateway
    Condition: NeedNAT
    Properties: # ...
```

### Use Mappings for Lookup Tables

```yaml
Mappings:
  InstanceSizing:
    dev:
      InstanceType: t3.micro
      MinSize: 1
      MaxSize: 2
    production:
      InstanceType: t3.large
      MinSize: 3
      MaxSize: 10
```

## Stack Organization

### Cross-Stack References

```yaml
# Network stack — exports VPC ID
Outputs:
  VpcId:
    Value: !Ref Vpc
    Export:
      Name: !Sub '${AWS::StackName}-VpcId'

# App stack — imports VPC ID
Resources:
  Instance:
    Type: AWS::EC2::Instance
    Properties:
      SubnetId: !ImportValue network-stack-SubnetId
```

### Nested vs Cross-Stack

| Pattern | When | Trade-offs |
|---|---|---|
| **Nested stacks** | Tightly coupled resources, same lifecycle | Single deploy, parent controls children |
| **Cross-stack (Export/Import)** | Independent lifecycles, shared resources | Loose coupling, but exports can't be deleted while imported |

## Security

1. **Use `CAPABILITY_IAM`/`CAPABILITY_NAMED_IAM`** — Required when creating IAM resources. Never bypass.
2. **Stack policies** — Prevent accidental updates to critical resources:
   ```json
   {
     "Statement": [{
       "Effect": "Deny",
       "Action": "Update:Replace",
       "Principal": "*",
       "Resource": "LogicalResourceId/ProductionDB"
     }]
   }
   ```
3. **DeletionPolicy: Retain** — Always on databases, S3 buckets with data, encryption keys
4. **Service roles** — Use CloudFormation service roles to limit what the stack can create

## CI/CD Integration

```bash
# Validate template
aws cloudformation validate-template --template-body file://template.yaml

# Lint with cfn-lint
cfn-lint template.yaml

# Create change set in CI, review, execute
aws cloudformation create-change-set \
  --stack-name prod-app \
  --change-set-name "deploy-$(git rev-parse --short HEAD)" \
  --template-body file://template.yaml
```

## CDK vs Raw CloudFormation

| Aspect | CloudFormation (YAML) | AWS CDK |
|---|---|---|
| Language | YAML/JSON | TypeScript, Python, Go, Java, C# |
| Abstraction | Low (resource-level) | High (constructs, patterns) |
| Learning curve | Lower (YAML) | Higher (programming + CDK concepts) |
| Reuse | Nested stacks, modules | Constructs, libraries (npm, PyPI) |
| Output | Direct template | Synthesizes to CloudFormation |

Use CDK when you need loops, conditionals, or abstractions beyond what YAML offers. Use raw CloudFormation for simple stacks or when CDK overhead isn't justified.

## Common Mistakes

1. **No change sets** — Always preview changes with change sets before updating production stacks
2. **Missing DeletionPolicy** — Databases and stateful resources need `Retain` or `Snapshot`
3. **Circular dependencies** — `!Ref` creates implicit dependencies. Use `DependsOn` carefully.
4. **Hardcoded AMIs** — Use SSM Parameter Store public parameters: `resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`
5. **Giant monolithic stacks** — Split by lifecycle. Network, data, and compute should be separate stacks.
