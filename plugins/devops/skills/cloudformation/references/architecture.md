# CloudFormation Architecture

## Stack Lifecycle

```
create-stack
    │
    ▼
┌──────────────┐
│  CREATE_IN_  │  Provisioning resources in dependency order
│  PROGRESS    │
└──────┬───────┘
       │
   Success?
   ┌───┴───┐
   Yes     No
   │       │
   ▼       ▼
┌──────┐ ┌──────────────┐
│CREATE│ │ROLLBACK_IN_  │  Undo all created resources
│_COMP │ │PROGRESS      │
│LETE  │ └──────┬───────┘
└──────┘        │
         ┌──────▼───────┐
         │ROLLBACK_     │
         │COMPLETE      │
         └──────────────┘
```

### Stack States

| State | Meaning |
|---|---|
| `CREATE_COMPLETE` | Stack created successfully |
| `CREATE_FAILED` | Creation failed (no rollback yet) |
| `ROLLBACK_COMPLETE` | Creation failed, rollback succeeded |
| `ROLLBACK_FAILED` | Rollback also failed (manual intervention needed) |
| `UPDATE_COMPLETE` | Update succeeded |
| `UPDATE_ROLLBACK_COMPLETE` | Update failed, rolled back |
| `DELETE_COMPLETE` | Stack deleted |
| `DELETE_FAILED` | Deletion failed (retained resources) |

## Change Set Mechanics

Change sets provide a safe preview of stack modifications:

```
Template Changes
      │
      ▼
┌──────────────┐
│ Create       │  CloudFormation computes diff
│ Change Set   │
└──────┬───────┘
       │
┌──────▼───────┐
│ Review       │  See what will be added/modified/removed
│ Changes      │
└──────┬───────┘
       │
   Approve?
   ┌───┴───┐
   Yes     No
   │       │
   ▼       ▼
Execute  Delete
Change   Change
Set      Set
```

### Change Types

| Action | Meaning | Risk |
|---|---|---|
| `Add` | New resource created | Low |
| `Modify` | Resource updated in place | Medium — check replacement |
| `Remove` | Resource deleted | High — data loss possible |
| `Modify (Replacement)` | Resource destroyed and recreated | High — new physical ID |

## StackSets Architecture

```
┌─────────────────────────┐
│    Management Account   │
│    (StackSet admin)     │
│                         │
│  ┌───────────────────┐  │
│  │    StackSet       │  │
│  │  (template +      │  │
│  │   parameters)     │  │
│  └────────┬──────────┘  │
└───────────┼─────────────┘
            │
    ┌───────┼───────┐
    │       │       │
    ▼       ▼       ▼
┌──────┐ ┌──────┐ ┌──────┐
│Acct A│ │Acct B│ │Acct C│
│Stack │ │Stack │ │Stack │
│Inst. │ │Inst. │ │Inst. │
└──────┘ └──────┘ └──────┘
```

### Permission Models

| Model | How | Use Case |
|---|---|---|
| **Self-managed** | Admin/execution IAM roles in each account | Specific accounts, full control |
| **Service-managed** | AWS Organizations integration | Automatic deployment to OUs, auto-deploy to new accounts |

## CloudFormation Registry

The registry tracks resource types:

- **AWS resources** (`AWS::EC2::Instance`, `AWS::S3::Bucket`) — native support
- **Third-party resources** (`MongoDB::Atlas::Cluster`) — registered via CloudFormation Registry
- **Custom resources** (`Custom::MyResource`) — backed by Lambda or SNS
- **Modules** — reusable template fragments registered as resource types

## Transforms and Macros

### AWS::Serverless Transform (SAM)

```yaml
Transform: AWS::Serverless-2016-10-31

Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      Runtime: python3.12
      Handler: app.handler
      Events:
        Api:
          Type: Api
          Properties:
            Path: /hello
            Method: get
```

SAM transforms expand `AWS::Serverless::*` resources into standard CloudFormation resources.

### Custom Macros

Macros process template fragments before CloudFormation creates resources:

```yaml
Transform:
  - MyCustomMacro

Resources:
  # MyCustomMacro can add, modify, or remove resources
```
