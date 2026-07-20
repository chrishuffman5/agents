# CloudFormation Diagnostics

## Stack Creation Failures

### ROLLBACK_COMPLETE

**Diagnosis:**
```bash
# See which resource failed
aws cloudformation describe-stack-events \
  --stack-name my-app \
  --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].[LogicalResourceId,ResourceStatusReason]" \
  --output table
```

**Common causes:**
- IAM permissions insufficient
- Resource limit reached (VPCs, EIPs, etc.)
- Invalid parameter values
- AMI not available in region
- Security group rule conflicts

### ROLLBACK_FAILED

The stack failed to create AND failed to roll back. Manual intervention required.

```bash
# Continue rollback, skipping problematic resources
aws cloudformation continue-update-rollback \
  --stack-name my-app \
  --resources-to-skip LogicalResourceId1 LogicalResourceId2

# Or delete the stack entirely
aws cloudformation delete-stack --stack-name my-app
```

### DELETE_FAILED

```bash
# Find resources that couldn't be deleted
aws cloudformation describe-stack-events \
  --stack-name my-app \
  --query "StackEvents[?ResourceStatus=='DELETE_FAILED']"

# Force delete, retaining problem resources
aws cloudformation delete-stack \
  --stack-name my-app \
  --retain-resources LogicalResourceId1
```

**Common causes:**
- S3 bucket not empty (must empty before deletion)
- Security group in use by another resource
- ENI attached to a running instance
- Export value imported by another stack

## Update Failures

### Replacement Surprises

Some property changes cause resource **replacement** (destroy + recreate):

```bash
# Preview with change set to catch replacements
aws cloudformation create-change-set \
  --stack-name my-app \
  --change-set-name preview \
  --template-body file://template.yaml

aws cloudformation describe-change-set \
  --stack-name my-app \
  --change-set-name preview \
  --query "Changes[?ResourceChange.Replacement=='True']"
```

**High-risk replacement triggers:**
- Changing `AWS::EC2::Instance` AMI or subnet
- Changing `AWS::RDS::DBInstance` engine or storage type
- Changing `AWS::Lambda::Function` runtime
- Changing any resource's `AWS::CloudFormation::Stack` TemplateURL

### Circular Dependencies

```
Circular dependency between resources: [ResourceA, ResourceB]
```

**Resolution:**
1. Identify the cycle in `!Ref` / `!GetAtt` chains
2. Break the cycle by:
   - Using `DependsOn` instead of `!Ref` where possible
   - Splitting into separate stacks with `!ImportValue`
   - Using `AWS::EC2::SecurityGroupIngress` as a separate resource instead of inline rules

## Drift Detection

```bash
# Detect drift
aws cloudformation detect-stack-drift --stack-name my-app

# Check status
aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id <detection-id>

# See drifted resources
aws cloudformation describe-stack-resource-drifts \
  --stack-name my-app \
  --stack-resource-drift-status-filters MODIFIED DELETED
```

**Drift remediation:**
1. **Accept drift**: Update template to match current state
2. **Revert drift**: Update stack to enforce template state
3. **Import**: For resources created outside CloudFormation, use resource import

## Template Validation

```bash
# AWS validation (checks syntax and resource types)
aws cloudformation validate-template --template-body file://template.yaml

# cfn-lint (catches more issues — type errors, invalid refs, best practices)
pip install cfn-lint
cfn-lint template.yaml

# cfn-nag (security-focused checks)
cfn_nag_scan --input-path template.yaml

# TaskCat (integration testing across regions)
taskcat test run
```

## Debugging Tips

```bash
# Stream stack events in real-time
aws cloudformation describe-stack-events \
  --stack-name my-app \
  --query "StackEvents[?Timestamp>'2026-04-01']" \
  --output table

# Check resource status
aws cloudformation describe-stack-resource \
  --stack-name my-app \
  --logical-resource-id WebServer

# List all exports (for ImportValue debugging)
aws cloudformation list-exports

# List all imports of a specific export
aws cloudformation list-imports --export-name my-export-name
```
