# Terraform Network Architecture Reference

## Terraform Core Concepts for Network

### Declarative Model

Terraform uses a declarative model: you define the desired end state in HCL (HashiCorp Configuration Language), and Terraform computes the changes needed to reach that state.

```
Desired State (HCL files) ←→ Current State (terraform.tfstate) → Plan (diff) → Apply (execute)
```

For network infrastructure, this means:
- Define tenants, VRFs, VLANs, policies in HCL
- Terraform reads current state from the state file (and optionally refreshes from the API)
- Plan shows exactly what will be created, modified, or destroyed
- Apply executes the plan against the target platform's API

### Provider Architecture

Terraform providers are plugins that translate HCL resources into API calls:

```
HCL Resource Definition
  → Terraform Core (plan/apply engine)
  → Provider Plugin (translates to API calls)
  → Network Platform API (ACI APIC, Meraki Dashboard, PAN-OS XML/REST API)
```

Each provider:
- Implements CRUD operations (Create, Read, Update, Delete) for each resource type
- Manages authentication to the platform API
- Handles API rate limiting and retries
- Maps HCL attributes to API parameters
- Reports resource state back to Terraform

### State File Internals

The state file (`terraform.tfstate`) is a JSON document that maps:
- Each Terraform resource to its real-world counterpart (API ID, DN, etc.)
- Current attribute values as last known by Terraform
- Dependencies between resources
- Provider configuration used to manage each resource

**State file for network is especially critical because:**
- Network resources cannot be "discovered" easily (unlike cloud VMs with tags)
- Losing state means losing Terraform's knowledge of what it manages
- Recreating resources (delete + create) causes outages for network infrastructure
- State contains sensitive data (provider credentials, API responses)

## Provider Deep Dives

### CiscoDevNet/aci Provider

**API**: APIC REST API (HTTPS)
**Authentication**: Username/password or certificate-based

**Resource Hierarchy** (mirrors ACI object model):
```
aci_tenant
  ├── aci_vrf
  ├── aci_bridge_domain
  │     └── aci_subnet
  ├── aci_application_profile
  │     └── aci_application_epg
  │           ├── aci_epg_to_contract (consumer/provider)
  │           └── aci_epg_to_domain
  ├── aci_contract
  │     └── aci_contract_subject
  │           └── aci_contract_subject_filter
  └── aci_filter
        └── aci_filter_entry
```

**Key patterns:**
- Use `depends_on` when implicit dependencies are not detected (rare with ACI provider)
- Use `for_each` with a map to create multiple EPGs from a data structure
- Use `data` sources to reference existing objects not managed by Terraform
- **aci_rest** resource for objects not covered by dedicated resources

**ACI-specific considerations:**
- APIC uses DN (Distinguished Name) paths: `uni/tn-PROD/BD-APP_BD`
- Resources reference parent objects via `*_dn` attributes
- Contracts and filters define inter-EPG communication policy
- Apply is not commit-based (changes take effect immediately on APIC)

### cisco-open/meraki Provider

**API**: Meraki Dashboard REST API (HTTPS, cloud-hosted)
**Authentication**: API key (header)

**Key resources:**
- `meraki_networks_vlans`: VLAN configuration per network
- `meraki_devices`: Device configuration (name, tags, address)
- `meraki_networks_switch_access_policies`: Switch port ACL policies
- `meraki_organizations_policy_objects`: Shared policy objects

**Meraki-specific considerations:**
- API rate limiting: Meraki API has strict rate limits (10 calls/second per org). Large applies may need pacing.
- Network ID is the primary scope: most resources require `network_id` parameter
- Meraki API is cloud-only: Terraform must have internet access to reach api.meraki.com
- Some configuration changes trigger device reboot (switch firmware, SSID security changes)

### paloaltonetworks/panos Provider

**API**: PAN-OS XML API (HTTPS)
**Authentication**: Username/password or API key

**Key resources:**
- `panos_address_object`: Address objects (IP, FQDN, range)
- `panos_address_group`: Address groups (static or dynamic)
- `panos_service_object`: Custom service definitions
- `panos_security_policy`: Security policy rules
- `panos_nat_rule_group`: NAT policy rules
- `panos_zone`: Security zones
- `panos_ethernet_interface`: Interface configuration

**PAN-OS-specific considerations:**
- **Commit model**: Terraform changes modify the candidate configuration. A commit is needed to activate changes. The provider can auto-commit or you can commit separately.
- **Rule ordering**: Security and NAT rules are ordered. Terraform manages ordering within a rule group. Use `position_keyword` and `position_reference` for placement.
- **Panorama vs local**: Provider supports both local firewall and Panorama management. Set `device_group` and `template` for Panorama-managed resources.
- **Config lock**: Provider can acquire config lock to prevent concurrent changes during apply.

### fortiosapi/fortios Provider

**API**: FortiOS REST API (HTTPS)
**Authentication**: API token or username/password

**Key resources:**
- `fortios_firewall_address`: Address objects
- `fortios_firewall_policy`: Firewall policies
- `fortios_system_interface`: Interface configuration
- `fortios_system_sdwan`: SD-WAN configuration
- `fortios_router_static`: Static routes
- `fortios_vpn_ipsec_phase1_interface`: IPsec VPN Phase 1
- `fortios_vpn_ipsec_phase2_interface`: IPsec VPN Phase 2

**FortiOS-specific considerations:**
- API token generation: `config system api-user` on FortiGate
- VDOM support: specify `vdomparam` to target specific VDOMs
- Policy ID management: FortiOS assigns sequential policy IDs; Terraform must manage ordering carefully
- Firmware version differences: some resources/attributes only available on specific FortiOS versions

### F5Networks/bigip Provider

**API**: iControl REST API (HTTPS)
**Authentication**: Username/password

**Key resources:**
- `bigip_ltm_node`: Backend server nodes
- `bigip_ltm_pool`: Server pools with load balancing
- `bigip_ltm_pool_attachment`: Pool member assignment
- `bigip_ltm_virtual_server`: Virtual server (VIP)
- `bigip_ltm_monitor`: Health monitors (HTTP, TCP, custom)
- `bigip_ltm_irule`: iRule assignment
- `bigip_ltm_profile_http`: HTTP profile configuration
- `bigip_ltm_persistence_profile_cookie`: Persistence profiles

**F5-specific considerations:**
- Partition scoping: resources are scoped to partitions (e.g., `/Common/`)
- Resource naming: full path required (e.g., `/Common/APP_POOL`)
- iRule management: complex iRules are better managed as template files
- HA sync: Terraform changes to active unit; sync to standby required separately

## State Management Best Practices

### Backend Configuration

**S3 + DynamoDB (AWS):**
```hcl
terraform {
  backend "s3" {
    bucket         = "network-terraform-state"
    key            = "env/production/aci.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

**Azure Blob:**
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatenetwork"
    container_name       = "tfstate"
    key                  = "production/aci.tfstate"
  }
}
```

**Terraform Cloud:**
```hcl
terraform {
  cloud {
    organization = "my-org"
    workspaces {
      name = "network-production-aci"
    }
  }
}
```

### State File Segmentation

Segment state files to limit blast radius:

| State File | Contents | Blast Radius |
|---|---|---|
| `production/aci.tfstate` | ACI tenant, VRF, BD, EPG | ACI fabric only |
| `production/panos.tfstate` | Firewall policies, objects | Firewall only |
| `production/meraki.tfstate` | Meraki VLANs, switch config | Meraki network only |
| `production/f5.tfstate` | Load balancer pools, VIPs | F5 only |

Cross-state references via `terraform_remote_state` data source:
```hcl
data "terraform_remote_state" "aci" {
  backend = "s3"
  config = {
    bucket = "network-terraform-state"
    key    = "production/aci.tfstate"
    region = "us-east-1"
  }
}

# Reference ACI outputs in F5 configuration
resource "bigip_ltm_node" "aci_node" {
  name    = "/Common/aci-web-server"
  address = data.terraform_remote_state.aci.outputs.web_server_ip
}
```

### Import Workflow

For existing network infrastructure not yet managed by Terraform:

```bash
# 1. Write the HCL resource definition
# 2. Import the existing resource into state
terraform import aci_tenant.existing uni/tn-EXISTING_TENANT

# 3. Run plan to verify Terraform's view matches reality
terraform plan

# 4. Adjust HCL until plan shows NO changes
# 5. Commit HCL to Git
```

**Import best practices:**
- Import one resource at a time
- Always plan after import to verify alignment
- Adjust HCL to match actual configuration exactly
- Do not import and modify in the same step

## CI/CD Pipeline Design

### Pipeline Stages

```
PR Created → terraform plan → Review plan output → Merge → terraform apply → Post-apply validation
```

### GitHub Actions Example
```yaml
name: Network Terraform
on:
  pull_request:
    paths: ['terraform/**']
  push:
    branches: [main]
    paths: ['terraform/**']

jobs:
  plan:
    runs-on: self-hosted
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init
      - run: terraform plan -no-color -out=tfplan
      - name: Comment plan on PR
        uses: actions/github-script@v7
        with:
          script: |
            // Post plan output as PR comment for review

  apply:
    runs-on: self-hosted
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init
      - run: terraform plan -out=tfplan
      - run: terraform apply tfplan
      - name: Validate
        run: |
          # Post-apply connectivity tests
          # Verify resources via API queries
```

### Drift Detection Pipeline
```yaml
# Run nightly to detect drift
name: Drift Detection
on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM daily

jobs:
  drift:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: terraform init
      - run: terraform plan -detailed-exitcode
      # Exit code 2 = changes detected (drift)
      - name: Alert on drift
        if: failure()
        run: |
          # Send Slack/Teams alert about detected drift
```
