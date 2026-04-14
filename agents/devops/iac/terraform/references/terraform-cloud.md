# Terraform Cloud (HCP Terraform)

## Platform Overview

Terraform Cloud (rebranded to HCP Terraform in 2023) is HashiCorp's managed SaaS platform for collaborative Terraform workflows. It provides remote state management, remote execution, policy enforcement, and team collaboration on top of open-source Terraform.

### HCP Terraform vs Terraform Enterprise

| Aspect | HCP Terraform (Cloud) | Terraform Enterprise |
|---|---|---|
| **Deployment** | SaaS, hosted by HashiCorp | Self-hosted, your infrastructure |
| **Maintenance** | HashiCorp manages upgrades, scaling | Customer manages installation, upgrades |
| **Network** | Public internet (agents for private access) | Runs inside your network natively |
| **Pricing** | Per resource under management (RUM) | Annual license ($15k+/year) |
| **Air-gapped** | No | Yes |
| **Audit logging** | Standard+ tiers | Full audit logging |
| **Resource limits** | Tier-dependent | No resource limits |
| **Custom concurrency** | Tier-dependent | Configurable |

Both share the same core features: remote execution, VCS integration, Sentinel/OPA policies, private registry, teams, and SSO. Terraform Enterprise adds air-gapped support, custom concurrency limits, and the ability to run entirely within private networks.

### Pricing Tiers (as of 2025)

| Tier | Resources Under Management | Key Features |
|---|---|---|
| **Free** | Up to 500 | Remote state, VCS integration, community support |
| **Standard** | ~$0.47/RUM/month | Teams, SSO, Sentinel, run tasks, cost estimation |
| **Plus** | Custom pricing | Drift detection, continuous validation, ephemeral workspaces, audit logging |

## Architecture and Hierarchy

```
Organization
  ├── Projects                          # Logical grouping
  │     ├── Workspaces                  # Each = 1 state file + config + variables
  │     │     ├── Runs                  # Plan/apply executions
  │     │     ├── Variables             # Terraform + environment vars
  │     │     ├── State Versions        # Historical state snapshots
  │     │     └── Run Triggers          # Cross-workspace dependencies
  │     └── Stacks                      # Multi-workspace orchestration
  ├── Teams                             # Groups of users with permissions
  ├── Policies (Sentinel / OPA)         # Governance rules
  ├── Policy Sets                       # Collections of policies applied to workspaces
  ├── Variable Sets                     # Shared variables across workspaces/projects
  ├── Agent Pools                       # Self-hosted execution agents
  └── Private Registry                  # Internal modules + providers
```

### Organizations

An organization is the top-level container. All workspaces, teams, policies, and registry modules belong to one organization. SSO, API tokens, and billing are configured at the organization level.

### Projects

Projects group workspaces and stacks for access control and organization. Each project has its own permission set -- teams can be granted access to all workspaces within a project rather than managing per-workspace permissions.

Use projects to model boundaries that matter: business units, teams, environments, or application domains.

### Workspaces

A workspace in HCP Terraform is fundamentally different from a CLI workspace. Each workspace encapsulates:

- One Terraform configuration (root module)
- One state file with full version history
- Its own variables (Terraform and environment)
- Run history, logs, and plan outputs
- Access controls, VCS connection, and execution settings

## Workspace Configuration

### Workspace Types (Workflow Modes)

| Type | Source of Config | Trigger | Best For |
|---|---|---|---|
| **VCS-connected** | Linked repository + branch | Webhook on push/PR | GitOps teams, automated pipelines |
| **CLI-driven** | `terraform plan/apply` from local CLI | Manual CLI commands | Developers testing, CI/CD orchestrators |
| **API-driven** | Config uploaded via API | API call | Custom pipelines, complex automation |

**VCS-connected** is the most common. HCP Terraform registers webhooks automatically, triggers plans on push, and posts speculative plan results on pull requests.

**CLI-driven** uses the `cloud` block. Runs execute remotely in HCP Terraform but are initiated from the CLI. Logs stream to the local terminal.

**API-driven** is the most flexible -- upload a tarball of config via the API, then trigger a run. Requires more tooling but gives full control.

### Execution Modes

| Mode | Where Runs Execute | State Storage | Use Case |
|---|---|---|---|
| **Remote** | HCP Terraform workers | HCP Terraform | Default, no local dependencies needed |
| **Local** | Your machine | HCP Terraform | Debugging, local provider access |
| **Agent** | Self-hosted agent behind firewall | HCP Terraform | Private network resources |

Configure via UI: Workspace > Settings > General > Execution Mode.

### Cloud Block Configuration (Terraform 1.1+)

The `cloud` block replaces the legacy `remote` backend. It is the recommended way to connect the CLI to HCP Terraform.

```hcl
terraform {
  cloud {
    organization = "my-org"

    workspaces {
      name = "my-app-prod"
    }
  }
}
```

Tag-based workspace selection (multi-environment):

```hcl
terraform {
  cloud {
    organization = "my-org"

    workspaces {
      tags = ["app:payments", "region:us-east-1"]
    }
  }
}
```

When using tags, `terraform workspace select` or `terraform workspace list` filters workspaces by matching tags.

### CLI Authentication

```bash
# Interactive login -- opens browser, stores token in ~/.terraform.d/credentials.tfrc.json
terraform login

# Login to Terraform Enterprise
terraform login tfe.mycompany.com

# Verify authentication
terraform workspace list
```

Token can also be set via environment variable:

```bash
export TF_TOKEN_app_terraform_io="<your-token>"
# For TFE: export TF_TOKEN_tfe_mycompany_com="<your-token>"
```

### Legacy Remote Backend (pre-1.1)

```hcl
# Deprecated -- migrate to cloud block
terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "my-org"

    workspaces {
      name = "my-app-prod"
    }
  }
}
```

### Workspace Settings

| Setting | Description | UI Path |
|---|---|---|
| **Auto-apply** | Skip manual approval after plan | Settings > General > Apply Method |
| **Working directory** | Subdirectory containing `.tf` files | Settings > General > Terraform Working Directory |
| **Terraform version** | Pin to a specific version | Settings > General > Terraform Version |
| **Execution mode** | Remote, local, or agent | Settings > General > Execution Mode |
| **Auto-destroy** | Schedule infrastructure destruction | Settings > Destruction and Deletion |
| **Remote state sharing** | Which workspaces can read state | Settings > General > Remote State Sharing |

## Variables

### Variable Types

| Type | Purpose | Example |
|---|---|---|
| **Terraform variable** | Maps to `variable` blocks in config | `instance_type = "t3.micro"` |
| **Environment variable** | Set in shell before `terraform` runs | `AWS_REGION = "us-east-1"` |

Both types can be marked **sensitive** (write-only, encrypted at rest with Vault transit, never displayed in UI or logs).

### Variable Precedence

1. Workspace-specific variables (highest priority)
2. Workspace-scoped variable sets (alphabetical by set name breaks ties)
3. Project-scoped variable sets
4. Organization-scoped variable sets (lowest priority)

### Variable Sets

Variable sets are reusable groups of variables applied across multiple workspaces or projects. Common uses:

- Shared cloud credentials across all workspaces
- Environment-specific defaults (region, tags)
- Organization-wide standards

Configure via UI: Organization Settings > Variable Sets > Create Variable Set. Choose scope: all workspaces, specific projects, or specific workspaces.

### HCL Variable Values

For complex types (lists, maps), enable the HCL checkbox in the UI:

```hcl
# Variable value (HCL mode)
{
  web = { instance_type = "t3.micro", count = 2 }
  api = { instance_type = "t3.small", count = 3 }
}
```

## State Management

### How State Works in HCP Terraform

HCP Terraform manages state automatically -- encryption at rest, locking during runs, and version history are built in. No need to configure S3 buckets, DynamoDB tables, or GCS backends.

- **Locking**: Automatic during plan/apply. No concurrent operations on the same workspace.
- **Encryption**: All state encrypted at rest using Vault transit backend.
- **Versioning**: Every apply creates a new state version. Full history is retained.

### State Versions and Rollback

Navigate to: Workspace > States > select a version.

To roll back to a previous state:

1. Go to the workspace's States tab
2. Click the state version you want to restore
3. Click the Advanced toggle
4. Click "Roll back to this state version"

This duplicates the selected version and makes it the current state. The workspace must be locked during rollback, and you must have permission to create new state versions.

### Remote State Sharing

Control which workspaces can read this workspace's outputs:

- **Share with all workspaces** in the organization
- **Share with all workspaces in the same project**
- **Share with specific workspaces** (most restrictive, recommended)

Configure via: Settings > General > Remote State Sharing.

### Cross-Workspace Data Access

**Preferred -- `tfe_outputs` data source** (only exposes outputs):

```hcl
data "tfe_outputs" "network" {
  organization = "my-org"
  workspace    = "network-prod"
}

resource "aws_instance" "web" {
  subnet_id = data.tfe_outputs.network.values.subnet_id
}
```

**Alternative -- `terraform_remote_state`** (exposes entire state, tighter coupling):

```hcl
data "terraform_remote_state" "network" {
  backend = "remote"
  config = {
    organization = "my-org"
    workspaces = {
      name = "network-prod"
    }
  }
}
```

Use `tfe_outputs` whenever possible. It is more secure (only outputs, not full state) and works natively with HCP Terraform access controls.

## Run Workflow

### Run Lifecycle

```
Queue → Plan → Cost Estimation → Policy Check → Apply
  │         │          │              │            │
  │         │          │              │            └─ State updated
  │         │          │              └─ Sentinel/OPA evaluation
  │         │          └─ Monthly cost delta shown
  │         └─ Terraform plan executes
  └─ Run enters queue (one run at a time per workspace)
```

### Run Types

| Type | Purpose | Trigger |
|---|---|---|
| **Plan and apply** | Full run -- plan then apply | VCS push, CLI, API, UI |
| **Plan only** | Plan without apply option | UI (plan only), speculative |
| **Speculative plan** | Read-only plan on PR/MR, no apply | Pull request webhook |
| **Destroy plan** | Plan to destroy all resources | UI queue destroy, API |
| **Refresh-only** | Update state without config changes | UI, CLI (`-refresh-only`) |

### Run Triggers (Cross-Workspace Dependencies)

When workspace A's apply succeeds, automatically queue a plan in workspace B.

Configure via UI: Workspace B > Settings > Run Triggers > Add Source Workspace.

Example: Network workspace apply triggers Compute workspace plan, which triggers Application workspace plan.

```
network-prod (apply succeeds)
    └──triggers──> compute-prod (plan queued)
                       └──triggers──> app-prod (plan queued)
```

Each workspace can have up to 20 source workspaces.

## VCS Integration

### Supported Providers

| Provider | OAuth App | Webhooks | PR Plans |
|---|---|---|---|
| **GitHub** (github.com + GHE) | Yes | Push, PR | Yes |
| **GitLab** (gitlab.com + self-managed) | Yes | Push, MR | Yes |
| **Azure DevOps** (Services + Server) | Yes | Push, PR | Yes |
| **Bitbucket** (Cloud + Server) | Yes | Push, PR | Yes |

### How VCS Triggers Work

1. Connect VCS provider to HCP Terraform (Organization Settings > VCS Providers)
2. Create workspace linked to repo + branch
3. HCP Terraform registers a webhook on the repository
4. On push to tracked branch: full run queued (plan + apply)
5. On PR/MR targeting tracked branch: speculative plan, results posted as commit status/check

### Branch-Based Workspace Pattern

Map environments to branches with separate workspaces:

| Workspace | Branch | Auto-Apply |
|---|---|---|
| `app-dev` | `develop` | Yes |
| `app-staging` | `staging` | Yes |
| `app-prod` | `main` | No (manual approve) |

### Working Directory and Trigger Paths

For monorepos, configure which paths trigger runs:

- **Working directory**: Only `.tf` files in this subdirectory are used
- **Trigger paths**: Additional paths that trigger runs when changed (e.g., shared modules directory)

Configure via: Settings > Version Control > Terraform Working Directory and VCS Triggers.

### VCS Webhook Troubleshooting

**Workspace does not trigger on push:**

1. Verify webhook exists in VCS provider settings (GitHub: Settings > Webhooks)
2. Check webhook delivery logs for errors (HTTP 4xx/5xx responses)
3. Confirm branch matches workspace configuration
4. A workspace with zero previous runs will not accept VCS webhooks -- queue one run manually first
5. Verify trigger paths include the changed files

**Speculative plan not appearing on PR:**

1. Confirm VCS connection has correct OAuth scopes
2. Check that PR targets the workspace's tracked branch
3. Look for webhook delivery failures in VCS provider

## Policy as Code

### Sentinel

Sentinel is HashiCorp's policy-as-code framework, natively integrated with HCP Terraform. Policies evaluate between plan and apply.

**Enforcement Levels:**

| Level | Behavior |
|---|---|
| **Advisory** | Logged but never blocks a run |
| **Soft mandatory** | Blocks the run, but users with override permission can bypass |
| **Hard mandatory** | Blocks the run, no override possible |

**Example Sentinel policy** (require tags on all AWS instances):

```python
import "tfplan/v2" as tfplan

aws_instances = filter tfplan.resource_changes as _, rc {
  rc.type is "aws_instance" and
  rc.mode is "managed" and
  (rc.change.actions contains "create" or rc.change.actions contains "update")
}

main = rule {
  all aws_instances as _, instance {
    instance.change.after.tags contains "Environment" and
    instance.change.after.tags contains "Owner"
  }
}
```

**Policy sets** group policies and assign them to workspaces. Store policies in a VCS repo for version control.

### OPA (Open Policy Agent)

HCP Terraform also supports OPA/Rego policies as an alternative to Sentinel. OPA policies evaluate the JSON plan output.

Sentinel and OPA can run side by side in the same workspace.

### Policy Check Failure in Runs

When a policy check fails:

```
Sentinel Result: false
  → Policy "require-tags" (soft-mandatory): FAILED
    → Override available: an authorized user can override this policy
```

Users with "Manage Policy Overrides" permission can override soft-mandatory failures in the UI.

## Cost Estimation

HCP Terraform estimates monthly costs for resources in the plan (Standard tier and above).

**How it works:** After the plan phase, HCP Terraform maps planned resources to public cloud pricing (AWS, Azure, GCP). The estimate appears as a run phase showing hourly cost, monthly cost, and delta from current state.

**Limitations:**
- Only supports AWS, Azure, and GCP resources
- Uses public list pricing -- does not account for reserved instances, savings plans, or negotiated discounts
- Data transfer, API call costs, and usage-based pricing are not estimated
- Tends to underestimate actual costs

For more accurate estimates, integrate Infracost as a run task.

## Run Tasks

Run tasks integrate third-party tools at specific stages of the run lifecycle.

### Integration Points

| Stage | When | Example Use |
|---|---|---|
| **Pre-plan** | Before plan starts | Validate config files, check naming conventions |
| **Post-plan** | After plan, before policy check | Security scanning (Snyk, Wiz), cost analysis (Infracost) |
| **Pre-apply** | After approval, before apply | Final compliance gate, change management ticket |
| **Post-apply** | After apply completes | Notify systems, update CMDB |

### Enforcement Levels

| Level | Behavior |
|---|---|
| **Advisory** | Results shown but run continues regardless |
| **Mandatory** | Run blocked if task returns failure |

### Configuration

Run tasks use a webhook callback model:

1. Register a run task in HCP Terraform (URL + HMAC key)
2. Attach to workspace(s) with enforcement level and stage
3. HCP Terraform sends a POST with run details to your endpoint
4. Your service processes and responds with pass/fail/running

Configure via: Organization Settings > Run Tasks > Create Run Task, then attach to workspaces via Settings > Run Tasks.

The Terraform Registry lists available run task integrations at `registry.terraform.io/browse/run-tasks`.

## Teams and Permissions

### Permission Model

Permissions are granted exclusively through team membership.

**Organization-level permissions:**

| Permission | Scope |
|---|---|
| Manage Policies | Create/edit/delete Sentinel and OPA policies |
| Manage Policy Overrides | Override soft-mandatory policy failures |
| Manage Workspaces | Create/configure/delete any workspace |
| Manage VCS Settings | Add/edit VCS provider connections |
| Manage Private Registry | Publish/delete modules and providers |
| Manage Teams | Create teams, manage membership |

**Workspace-level permissions:**

| Level | Capabilities |
|---|---|
| **Read** | View workspace, runs, state |
| **Plan** | Queue plans (no apply) |
| **Write** | Queue plans and apply |
| **Admin** | Full control, delete workspace, manage settings |
| **Custom** | Fine-grained: lock/unlock, state versions, run tasks, variables |

### SSO and SAML

HCP Terraform supports SAML SSO (Standard tier and above):

- Supported IdPs: Okta, Azure AD (Entra ID), OneLogin, ADFS, any SAML 2.0 provider
- Team mapping: SAML assertions can include team membership attributes
- Auto-provisioning: Users added/removed from teams based on SAML assertion on each login
- Enforcement: SSO can be required for all organization members

Configure via: Organization Settings > SSO > Set up SSO.

When team management via SAML is enabled, HCP Terraform reads team names from the SAML response's `MemberOf` attribute (configurable) and automatically syncs team membership on login.

## Self-Hosted Agents

Agents enable HCP Terraform to provision resources in private networks without exposing those networks to the public internet.

### How Agents Work

```
HCP Terraform ←──HTTPS (outbound only)──→ Agent (your network)
                                              │
                                         Private APIs
                                         (vSphere, on-prem DB, etc.)
```

1. Agent polls HCP Terraform for jobs (all connections are outbound from agent)
2. When a run is assigned to the agent pool, the agent downloads the config and executes plan/apply
3. Results and state are sent back to HCP Terraform

**Network requirements:** Outbound HTTPS to `app.terraform.io` on port 443. No inbound firewall rules needed.

### Agent Pool Setup

```bash
# Run the agent as a Docker container
docker run -e TFC_AGENT_TOKEN=<token> \
           -e TFC_AGENT_NAME=agent-1 \
           hashicorp/tfc-agent:latest

# Or run the binary directly
./tfc-agent -token=<token> -name=agent-1
```

Agent token is created in: Organization Settings > Agents > Create Agent Pool > Generate Token.

### Agent Pool Assignment

Assign an agent pool to a workspace to route its runs to your private agents:

- UI: Workspace > Settings > General > Execution Mode > Agent > select pool
- TFE provider: `execution_mode = "agent"` + `agent_pool_id`

### Agent Troubleshooting

| Agent Status | Meaning | Action |
|---|---|---|
| **Idle** | Connected, waiting for jobs | Normal |
| **Busy** | Executing a run | Normal |
| **Unknown** | Lost communication | Check network, agent process |
| **Errored** | Unknown for 2+ hours, auto-transitioned | Restart agent, check logs |
| **Exited** | Agent shut down cleanly | Restart if needed |

Unknown agents count against your organization's agent allowance. Restart or remove them.

## Advanced Features

### Dynamic Provider Credentials

Eliminate static cloud credentials by using OIDC-based workload identity. HCP Terraform issues a short-lived JWT for each run, which is exchanged for temporary cloud credentials.

**How it works:**

1. Configure trust between cloud provider and HCP Terraform (OIDC identity provider)
2. Set workspace environment variables to enable dynamic credentials
3. Each run receives a unique JWT signed by HCP Terraform
4. Cloud provider validates JWT and returns short-lived credentials

**AWS configuration:**

```hcl
# In AWS: Create OIDC identity provider
# Issuer URL: https://app.terraform.io
# Audience: aws.workload.identity

# In AWS: Create IAM role with trust policy
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/app.terraform.io" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "app.terraform.io:aud": "aws.workload.identity"
      },
      "StringLike": {
        "app.terraform.io:sub": "organization:my-org:project:*:workspace:*:run_phase:*"
      }
    }
  }]
}
```

Set these workspace environment variables:

| Variable | Value |
|---|---|
| `TFC_AWS_PROVIDER_AUTH` | `true` |
| `TFC_AWS_RUN_ROLE_ARN` | `arn:aws:iam::ACCOUNT:role/tfc-role` |

**Azure configuration:** Set `TFC_AZURE_PROVIDER_AUTH = true`, `TFC_AZURE_RUN_CLIENT_ID`, `TFC_AZURE_RUN_TENANT_ID`.

**GCP configuration:** Set `TFC_GCP_PROVIDER_AUTH = true`, `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL`, `TFC_GCP_PROJECT_NUMBER`, `TFC_GCP_WORKLOAD_PROVIDER_NAME`.

### Drift Detection

HCP Terraform can automatically detect when real infrastructure diverges from the Terraform state (Plus tier).

- Runs a background refresh on a schedule (default: every 24 hours after last successful run)
- Compares refreshed state to configuration
- Displays "Drift detected" status on workspace
- Sends notifications (email, Slack, webhook)

Requirements: Terraform >= 0.15.4, remote or agent execution mode, last run must be successful.

### Continuous Validation

Goes beyond drift detection by evaluating `check` blocks and `postcondition` blocks on a schedule (requires Terraform >= 1.3.0).

```hcl
check "api_health" {
  data "http" "api" {
    url = "https://api.example.com/health"
  }

  assert {
    condition     = data.http.api.status_code == 200
    error_message = "API health check failed"
  }
}
```

When a check fails, the workspace shows a "Health: check failed" warning without blocking runs.

### Ephemeral Workspaces and Auto-Destroy

Configure workspaces to automatically destroy their infrastructure:

**Scheduled destruction:** Set a specific date/time for auto-destroy.
- UI: Workspace > Settings > Destruction and Deletion > Automatically destroy > Set up auto-destroy

**Inactivity-based destruction:** Destroy after N days of no state changes.

**TFE provider configuration:**

```hcl
resource "tfe_workspace" "dev" {
  name         = "my-app-dev"
  organization = "my-org"

  # Destroy after 7 days of inactivity
  auto_destroy_activity_duration = "7d"

  # Or destroy at a specific time
  # auto_destroy_at = "2026-05-01T00:00:00Z"
}
```

### No-Code Provisioning

Enables self-service infrastructure without writing Terraform. Platform teams publish modules to the private registry and mark them as "no-code ready." End users deploy via a web form.

**Workflow:**

1. Platform team publishes module to private registry
2. Enable module for no-code provisioning (Registry > Module > Enable no-code)
3. End user navigates to Registry > selects module > "Provision workspace"
4. Fills in required variables via form
5. HCP Terraform creates a workspace, sets variables, runs the module

Sentinel policies still apply. Credentials come from variable sets -- end users never see cloud keys.

### Private Registry

Publish internal modules and providers for organization-wide reuse.

**Module publishing:**

1. Connect a VCS repository following the naming convention `terraform-<PROVIDER>-<NAME>`
2. Create semantic version tags (e.g., `v1.0.0`)
3. HCP Terraform imports the module and tracks new tags as versions

**Using private modules:**

```hcl
module "vpc" {
  source  = "app.terraform.io/my-org/vpc/aws"
  version = "~> 2.0"
}
```

**Provider publishing:** Upload provider binaries via API (manual process, no auto-sync from VCS).

## API and Automation

### Authentication

Three token types for API access:

| Token Type | Scope | Create Via |
|---|---|---|
| **User token** | All orgs/workspaces the user can access | User Settings > Tokens |
| **Team token** | Workspaces the team can access | Organization > Teams > Team > API Token |
| **Organization token** | Org-level management (cannot trigger runs) | Organization Settings > API Tokens |

All API requests use bearer token authentication:

```bash
curl -H "Authorization: Bearer $TFC_TOKEN" \
     -H "Content-Type: application/vnd.api+json" \
     https://app.terraform.io/api/v2/...
```

### Common API Operations

**List workspaces:**

```bash
curl -s \
  -H "Authorization: Bearer $TFC_TOKEN" \
  https://app.terraform.io/api/v2/organizations/my-org/workspaces \
  | jq '.data[].attributes.name'
```

**Create a workspace:**

```bash
curl -s \
  -H "Authorization: Bearer $TFC_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "workspaces",
      "attributes": {
        "name": "my-new-workspace",
        "auto-apply": false,
        "terraform-version": "1.15.0",
        "execution-mode": "remote"
      }
    }
  }' \
  https://app.terraform.io/api/v2/organizations/my-org/workspaces
```

**Trigger a run:**

```bash
curl -s \
  -H "Authorization: Bearer $TFC_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "runs",
      "attributes": {
        "message": "Triggered via API"
      },
      "relationships": {
        "workspace": {
          "data": { "type": "workspaces", "id": "ws-abc123" }
        }
      }
    }
  }' \
  https://app.terraform.io/api/v2/runs
```

**Read current state outputs:**

```bash
curl -s \
  -H "Authorization: Bearer $TFC_TOKEN" \
  https://app.terraform.io/api/v2/workspaces/ws-abc123/current-state-version \
  | jq '.data.attributes'
```

**Lock a workspace:**

```bash
curl -s -X POST \
  -H "Authorization: Bearer $TFC_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{"reason": "Maintenance window"}' \
  https://app.terraform.io/api/v2/workspaces/ws-abc123/actions/lock
```

### TFE Provider (Workspace-as-Code)

Manage HCP Terraform itself with Terraform -- workspaces, variables, teams, and policies as code.

```hcl
terraform {
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.57"
    }
  }
}

provider "tfe" {
  # Token from TFE_TOKEN env var or terraform login
}

# Create a project
resource "tfe_project" "payments" {
  organization = "my-org"
  name         = "payments"
}

# Create a workspace
resource "tfe_workspace" "api_prod" {
  name              = "payments-api-prod"
  organization      = "my-org"
  project_id        = tfe_project.payments.id
  terraform_version = "~> 1.15.0"
  working_directory = "infrastructure/api"
  auto_apply        = false
  execution_mode    = "remote"

  vcs_repo {
    identifier     = "my-org/payments-api"
    branch         = "main"
    oauth_token_id = tfe_oauth_client.github.oauth_token_id
  }

  # Ephemeral workspace -- auto-destroy after 7 days of inactivity
  # auto_destroy_activity_duration = "7d"
}

# Workspace variables
resource "tfe_variable" "environment" {
  key          = "environment"
  value        = "production"
  category     = "terraform"          # "terraform" or "env"
  workspace_id = tfe_workspace.api_prod.id
  description  = "Deployment environment"
}

resource "tfe_variable" "aws_role" {
  key          = "TFC_AWS_PROVIDER_AUTH"
  value        = "true"
  category     = "env"
  workspace_id = tfe_workspace.api_prod.id
}

# Variable set for shared credentials
resource "tfe_variable_set" "aws_creds" {
  name         = "aws-credentials"
  organization = "my-org"
  description  = "Dynamic AWS credentials for all workspaces"
}

resource "tfe_project_variable_set" "aws_creds" {
  variable_set_id = tfe_variable_set.aws_creds.id
  project_id      = tfe_project.payments.id
}

# Team access
resource "tfe_team" "payments_devs" {
  name         = "payments-developers"
  organization = "my-org"
}

resource "tfe_team_access" "payments_devs" {
  access       = "write"
  team_id      = tfe_team.payments_devs.id
  workspace_id = tfe_workspace.api_prod.id
}

# Run trigger: network changes trigger API workspace
resource "tfe_run_trigger" "network_to_api" {
  workspace_id  = tfe_workspace.api_prod.id
  sourceable_id = tfe_workspace.network_prod.id
}
```

Authenticate the TFE provider:

```bash
export TFE_TOKEN="<team-or-user-token>"
terraform init
terraform plan
```

## Troubleshooting

### Run Failures

**State lock conflict:**

```
Error: Error locking state: Error acquiring the state lock
```

In HCP Terraform, state locking is automatic. If a run fails mid-apply, the lock may persist. Go to Workspace > Settings > Locking > Unlock or use the API:

```bash
curl -s -X POST \
  -H "Authorization: Bearer $TFC_TOKEN" \
  https://app.terraform.io/api/v2/workspaces/ws-abc123/actions/unlock
```

**Provider authentication failure:**

```
Error: error configuring Terraform AWS Provider: no valid credential sources found
```

Check workspace variables: ensure `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` are set as environment variables, or dynamic credentials environment variables (`TFC_AWS_PROVIDER_AUTH`, `TFC_AWS_RUN_ROLE_ARN`) are configured correctly.

**Workspace misconfiguration:**

```
Error: No configuration files found
```

Check working directory setting. For VCS-connected workspaces, ensure the working directory matches the subdirectory containing `.tf` files in the repository.

### VCS Webhook Issues

**Runs not triggering on push:**

1. Go to your VCS provider's webhook settings and check delivery logs
2. Verify the webhook URL points to `app.terraform.io`
3. Confirm the tracked branch matches the push target
4. Queue one manual run first -- workspaces with zero runs ignore webhooks
5. Check trigger paths if using a monorepo

**Speculative plans not posting to PRs:**

1. Verify OAuth token has sufficient permissions (GitHub: `repo` scope)
2. Check VCS provider connection status in Organization Settings > VCS Providers
3. Look for delivery failures in the VCS provider's webhook logs

### Agent Connectivity

**Agent shows "Unknown" or "Errored":**

1. Verify outbound HTTPS connectivity to `app.terraform.io:443`
2. Check agent process is running: `docker ps` or `ps aux | grep tfc-agent`
3. Inspect agent logs for authentication or network errors
4. Verify the agent token is valid and not expired
5. Check proxy/firewall settings if behind a corporate network

**Runs stuck in "Planning" with agent execution:**

1. Verify at least one agent in the pool is idle
2. Check agent pool assignment matches workspace configuration
3. Review agent logs for crash or OOM during plan

### Sentinel Policy Debugging

**Policy fails unexpectedly:**

1. Click the policy check in the run UI to see evaluation details
2. Use `sentinel test` locally with mock data from the failed run
3. Download mock data: Run > Policy Check > Download Sentinel Mocks
4. Check the policy's imports match the expected Terraform plan structure

```bash
# Test sentinel policy locally
sentinel test -run <policy_name>
```

### Performance Issues

**Large state files (>50MB):**

- Decompose into smaller workspaces
- Remove unnecessary resources from state (`terraform state rm`)
- Use `-target` sparingly for immediate relief

**Run queue backlog:**

- Only one run executes per workspace at a time
- Cancel stale queued runs via UI or API
- Avoid unnecessary VCS triggers with precise trigger paths
- Consider splitting high-churn workspaces

**Concurrent run limits:**

| Tier | Concurrent Runs |
|---|---|
| Free | 1 |
| Standard | 3 |
| Plus | Configurable |
| Enterprise | Configurable |
