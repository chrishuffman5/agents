# Ansible Automation Platform (AAP) — Platform Management

## Platform Architecture (AAP 2.5+)

### Component Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Platform Gateway                           │
│         Unified UI / SSO / Centralized Authentication           │
├──────────────────┬──────────────────┬───────────────────────────┤
│  Automation      │  Private         │  EDA Controller           │
│  Controller      │  Automation Hub  │  (Event-Driven Ansible)   │
│  (formerly Tower)│                  │                           │
├──────────────────┴──────────────────┴───────────────────────────┤
│                     Automation Mesh (Receptor)                  │
│           Control Nodes ←→ Hop Nodes ←→ Execution Nodes        │
├─────────────────────────────────────────────────────────────────┤
│                     PostgreSQL Database                         │
└─────────────────────────────────────────────────────────────────┘
```

| Component | Purpose |
|---|---|
| **Platform Gateway** | Unified entry point — consolidates Controller, Hub, and EDA UIs. Handles SSO, authentication (SAML, LDAP, OIDC), and centralized user management |
| **Automation Controller** | Job execution, scheduling, RBAC, workflows, REST API. Formerly Ansible Tower |
| **Private Automation Hub** | On-premise repository for collections, execution environments, and container images. Built-in Pulp container registry |
| **EDA Controller** | Event-driven automation — rulebook activations, event sources, integration with Controller job templates |
| **Automation Mesh (Receptor)** | Peer-to-peer overlay network connecting control, hop, and execution nodes. Replaces legacy isolated nodes |
| **PostgreSQL** | Stores job history, credentials, inventories, RBAC data, activity stream |

### Controller vs AWX (Open Source)

| Feature | AWX (Open Source) | Automation Controller (AAP) |
|---|---|---|
| License | Apache 2.0 | Red Hat subscription |
| Support | Community only | Red Hat SLA, 24/7 support |
| Upgrades | No supported migration path between versions | Tested, supported upgrade procedures |
| Authentication | Basic SSO | SAML, OIDC, LDAP, RADIUS, MFA |
| Certification | None | FIPS 140-2, SOC 2, FedRAMP |
| Automation Hub | No Private Hub | Private Automation Hub included |
| EDA | Separate install | Integrated EDA Controller |
| Content | Community collections only | Certified + Validated content |
| Scalability | Limited clustering | Full mesh networking, container groups |

**Rule of thumb:** AWX is suitable for dev/lab environments and upstream contributions. Automation Controller (AAP) is required for production, compliance, and enterprise-scale automation.

### Installation Topologies (AAP 2.5)

AAP 2.5 introduced **containerized installation** using Podman, deprecating the RPM-based installer.

| Topology | Description |
|---|---|
| **Growth** | Single server — Controller + Hub + EDA + PostgreSQL on one host |
| **Enterprise** | Multi-server — Separate hosts for Controller, Hub, EDA, DB. Supports HA |
| **Operator (OpenShift)** | Kubernetes-native — Operator-managed on Red Hat OpenShift |

```bash
# Containerized installer (AAP 2.5+)
# Download and extract the installer bundle
tar xf ansible-automation-platform-containerized-setup-bundle-2.5-1.tar.gz
cd ansible-automation-platform-containerized-setup-bundle-2.5-1/

# Edit the inventory file
vi inventory

# Run the installer
sudo ./setup.sh
```

---

## Automation Mesh (Receptor)

### Node Types

| Node Type | Role | Runs Jobs? | Runs Services? |
|---|---|---|---|
| **Control** | Runs controller services only (web, dispatcher). Does NOT run jobs | No | Yes |
| **Hybrid** | Default. Runs controller services AND executes jobs | Yes | Yes |
| **Execution** | Runs playbooks only. No controller services | Yes | No |
| **Hop** | Relays traffic between nodes. Does not run jobs or services | No | No |

### Mesh Topology Example

```
                  ┌──────────────┐
                  │  Control /   │  DC1 (Primary Data Center)
                  │  Hybrid Node │
                  └──────┬───────┘
                         │ :27199
              ┌──────────┴──────────┐
              │                     │
       ┌──────▼──────┐      ┌──────▼──────┐
       │  Execution  │      │  Hop Node   │  DMZ / Branch Office
       │  Node (DC1) │      │  (Relay)    │
       └─────────────┘      └──────┬──────┘
                                   │ :27199
                            ┌──────▼──────┐
                            │  Execution  │  Remote Site
                            │  Node (DC2) │
                            └─────────────┘
```

**All mesh communication uses port 27199/TCP (TLS-encrypted).** This is the only port required between mesh nodes.

### Receptor Configuration

```yaml
# /etc/receptor/receptor.conf (execution node)
---
- node:
    id: exec1.dc2.example.com
- log-level: info
- tcp-peer:
    address: hop1.example.com:27199
    tls: tlsclient
- control-service:
    service: control
    filename: /var/run/receptor/receptor.sock
- work-command:
    worktype: ansible-runner
    command: ansible-runner
    params: worker
    allowruntimeparams: true
```

### Mesh Diagnostic Commands

```bash
# Check receptor service status
sudo systemctl status receptor

# View receptor mesh status (on any mesh node)
receptorctl --socket /var/run/receptor/receptor.sock status

# View mesh topology from controller
awx-manage list_instances

# Ping a specific node through the mesh
receptorctl --socket /var/run/receptor/receptor.sock ping exec1.dc2.example.com

# View receptor connections and routes
receptorctl --socket /var/run/receptor/receptor.sock status --json

# Check receptor logs
journalctl -u receptor -f

# On the controller, check receptor status
receptorctl --socket /var/run/awx-receptor/receptor.sock status
```

---

## Execution Environments (EEs)

Execution environments are container images that package ansible-core, Python dependencies, collections, and system libraries into a portable, reproducible runtime.

### Why EEs?

- Replace Python virtualenvs (deprecated in AAP 2.x)
- Consistent runtime across dev laptops, CI/CD, and Controller
- Isolated dependencies — no conflicts between different automation projects
- Versioned and distributable via container registries

### Default EEs

| Image | Contents |
|---|---|
| `ee-minimal-rhel9` | ansible-core + ansible.builtin only |
| `ee-supported-rhel9` | ansible-core + Red Hat certified collections |
| `ee-29-rhel9` | ansible-core 2.16 + supported collections (AAP 2.5) |

### Building Custom EEs with ansible-builder

```yaml
# execution-environment.yml (v3 schema)
---
version: 3

images:
  base_image:
    name: registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest

dependencies:
  galaxy:
    collections:
      - name: amazon.aws
        version: ">=7.0.0"
      - name: community.general
      - name: ansible.windows
      - name: cisco.ios
  python:
    - boto3>=1.28.0
    - botocore>=1.31.0
    - pywinrm>=0.4.3
    - jmespath
  system:
    - openssh-clients [platform:redhat]
    - sshpass [platform:redhat]

additional_build_steps:
  prepend_final:
    - RUN whoami
    - RUN pip3 install --upgrade pip
  append_final:
    - RUN ansible-galaxy collection list
```

```bash
# Install ansible-builder
pip install ansible-builder

# Build the EE image
ansible-builder build \
  --tag my-custom-ee:1.0 \
  --container-runtime podman \
  --file execution-environment.yml \
  --verbosity 3

# Verify the built image
podman run --rm my-custom-ee:1.0 ansible --version
podman run --rm my-custom-ee:1.0 ansible-galaxy collection list

# Push to Private Automation Hub
podman login hub.example.com
podman tag my-custom-ee:1.0 hub.example.com/my-custom-ee:1.0
podman push hub.example.com/my-custom-ee:1.0

# Run a playbook with a specific EE locally
ansible-navigator run site.yml --eei my-custom-ee:1.0 --mode stdout
```

### Troubleshooting EE Builds

| Error | Cause | Fix |
|---|---|---|
| `ERROR: Could not find a version that satisfies the requirement` | Python package not available for platform | Check package availability on RHEL 9. Use `--build-arg` for custom pip index |
| `ERROR: Collection 'x.y' not found` | Galaxy server unreachable or collection not published | Configure `ansible.cfg` with correct galaxy server URL. Check `--galaxy-keyring` |
| `COPY failed: file not found` | Missing dependency files | Ensure `requirements.txt`, `requirements.yml`, `bindep.txt` exist at paths specified |
| Image too large (>2GB) | Too many collections or system packages | Use multi-stage builds. Only include collections you actually need |

---

## Organizations, Teams, Users & RBAC

### Permission Model

```
Organization (top-level tenant)
  ├── Teams (groups of users)
  │     ├── User A (admin role)
  │     ├── User B (execute role)
  │     └── User C (read role)
  ├── Projects
  ├── Inventories
  ├── Credentials
  ├── Job Templates
  └── Workflow Templates
```

### Built-in Roles

| Role | Scope | Permissions |
|---|---|---|
| **System Administrator** | Global | Full access to everything |
| **System Auditor** | Global | Read-only access to everything |
| **Admin** | Per-object | Full control of the specific object |
| **Execute** | Job/Workflow Template | Launch jobs, view results |
| **Use** | Credential/Inventory/Project | Attach to job templates (cannot view secrets) |
| **Update** | Project/Inventory | Trigger SCM sync or inventory refresh |
| **Read** | Per-object | View configuration and results |

### RBAC via API

```bash
# Grant a team "Execute" role on a job template
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id": 5, "type": "role"}' \
  https://controller.example.com/api/v2/teams/3/roles/
```

### Authentication Sources

Configure via **Platform Gateway > Settings > Authentication** (AAP 2.5+):

| Method | Configuration Key |
|---|---|
| LDAP | `AUTH_LDAP_SERVER_URI`, `AUTH_LDAP_BIND_DN`, `AUTH_LDAP_USER_SEARCH` |
| SAML | IdP metadata URL, SP Entity ID, certificate/key pairs |
| OIDC | Client ID, Client Secret, OIDC provider URL |
| RADIUS | RADIUS server, port, shared secret |
| Local | Built-in database authentication (default) |

---

## Projects

Projects represent a collection of playbooks sourced from version control.

### SCM Configuration

| Setting | Description |
|---|---|
| **SCM Type** | Git (most common), Subversion, Red Hat Insights, Archive |
| **SCM URL** | Repository URL (`https://` or `git@`) |
| **SCM Branch/Tag/Commit** | Pin to a specific branch, tag, or commit hash |
| **SCM Credential** | SSH key or token for private repos |
| **Update on Launch** | Pull latest before each job run (adds latency) |
| **Clean** | Delete local modifications before update |
| **Delete** | Delete entire local copy and re-clone on update |
| **Cache Timeout** | Seconds to cache project between syncs (0 = always update) |

**UI Path:** Automation Controller > Projects > Add

```bash
# Trigger project sync via API
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  https://controller.example.com/api/v2/projects/7/update/

# Check project sync status
curl -k -H "Authorization: Bearer $TOKEN" \
  https://controller.example.com/api/v2/projects/7/
```

---

## Inventories

### Inventory Types

| Type | Description |
|---|---|
| **Static** | Manually defined hosts and groups in the Controller UI or via API |
| **Dynamic (Source-based)** | Syncs from external sources — AWS, Azure, GCP, VMware, ServiceNow, RHEV, Satellite |
| **Constructed** | Combines multiple input inventories with custom grouping logic (Jinja2-based). Replaces deprecated Smart Inventories |
| **Smart** (Deprecated) | Host filter using search syntax. Migrate to constructed inventories |

### Dynamic Inventory Sources

| Source | Plugin | Credential Type |
|---|---|---|
| AWS EC2 | `amazon.aws.aws_ec2` | Amazon Web Services |
| Azure RM | `azure.azcollection.azure_rm` | Microsoft Azure RM |
| GCP | `google.cloud.gcp_compute` | Google Compute Engine |
| VMware vCenter | `community.vmware.vmware_vm_inventory` | VMware vCenter |
| ServiceNow | `servicenow.servicenow.now` | ServiceNow (custom) |
| Red Hat Satellite | `theforeman.foreman.foreman` | Red Hat Satellite 6 |
| OpenStack | `openstack.cloud.openstack` | OpenStack |

**Note:** ServiceNow inventory sources must use the `*.servicenow.yml` filename pattern.

### Constructed Inventory Example

```yaml
# Source vars for a constructed inventory combining AWS + VMware
plugin: constructed
strict: false
groups:
  # Create groups based on AWS tags
  webservers: "'web' in tags.get('Role', '')"
  databases: "'db' in tags.get('Role', '')"
  # Group by environment
  production: "tags.get('Environment') == 'prod'"
  staging: "tags.get('Environment') == 'staging'"
compose:
  # Set ansible_host from private IP
  ansible_host: private_ip_address | default(ansible_host)
```

**UI Path:** Automation Controller > Inventories > Add > Add constructed inventory

---

## Credentials

### Built-in Credential Types

| Type | Used For | Key Fields |
|---|---|---|
| **Machine** | SSH/WinRM to managed hosts | Username, password, SSH key, privilege escalation |
| **SCM** | Git/SVN repository access | Username, password/token, SSH key |
| **Vault** | Ansible Vault decryption | Vault password, Vault ID |
| **Amazon Web Services** | AWS API calls | Access key, Secret key, STS token |
| **Microsoft Azure RM** | Azure API calls | Subscription ID, Client ID, Secret, Tenant |
| **Google Compute Engine** | GCP API calls | Service account JSON key |
| **VMware vCenter** | vSphere API calls | Host, Username, Password |
| **Network** | Network device CLI/API | Username, password, authorize password |
| **Container Registry** | Pull EE images | Registry URL, username, password |
| **Red Hat Ansible Automation Platform** | Controller-to-Controller API | Host, Username, Password/Token |

### Custom Credential Types

Define custom credentials with an Input Configuration (what fields to collect) and an Injector Configuration (how to expose them at runtime).

```yaml
# Input Configuration (what the user fills in)
fields:
  - id: api_token
    type: string
    label: API Token
    secret: true
  - id: api_url
    type: string
    label: API URL
required:
  - api_token
  - api_url

# Injector Configuration (how values reach the playbook)
env:
  MY_API_TOKEN: '{{ api_token }}'
  MY_API_URL: '{{ api_url }}'
extra_vars:
  my_api_token: '{{ api_token }}'
  my_api_url: '{{ api_url }}'
```

### External Credential Lookups

External credential plugins retrieve secrets at runtime from external vaults. Configure via **Automation Controller > Credentials > (select credential) > (click key icon on field)**.

| External System | Plugin | Lookup Metadata |
|---|---|---|
| **CyberArk CCP** | CyberArk Central Credential Provider Lookup | AppID, Safe, Object, Query |
| **CyberArk Conjur** | CyberArk Conjur Secrets Manager Lookup | Account, Variable path |
| **HashiCorp Vault** | HashiCorp Vault Secret Lookup | Server URL, Role ID, Secret ID, Path, API version (v1/v2) |
| **Azure Key Vault** | Microsoft Azure Key Vault | Vault URL, Client, Secret, Tenant, Secret Name/Version |
| **AWS Secrets Manager** | AWS Secrets Manager Lookup | Region, Secret Name |
| **Thycotic** | Thycotic Secret Server | Server URL, Secret ID, Field |

```bash
# Create a HashiCorp Vault credential lookup source
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "HashiCorp Vault Lookup",
    "credential_type": 21,
    "inputs": {
      "url": "https://vault.example.com:8200",
      "token": "s.xxxxxxxxxxxx",
      "api_version": "v2"
    }
  }' \
  https://controller.example.com/api/v2/credentials/
```

---

## Job Templates

### Key Settings

| Setting | Description |
|---|---|
| **Job Type** | Run (execute) or Check (dry run / `--check`) |
| **Inventory** | Target hosts. Can be overridden with Prompt on Launch |
| **Project** | Source of playbooks |
| **Playbook** | Specific playbook file from the project |
| **Execution Environment** | Container image for runtime |
| **Credentials** | One or more credentials (machine, cloud, vault, etc.) |
| **Instance Group** | Where to run (default, specific instance group, container group) |
| **Forks** | Parallel host connections (default: controller-level setting) |
| **Limit** | Restrict to specific hosts/groups (host pattern) |
| **Job Tags / Skip Tags** | Run or skip specific tagged tasks |
| **Verbosity** | 0 (Normal) through 5 (WinRM Debug) |
| **Extra Variables** | YAML/JSON vars passed as `--extra-vars` |
| **Job Slicing** | Split inventory into N slices, run in parallel |
| **Timeout** | Maximum job runtime in seconds (0 = no limit) |
| **Survey** | User-facing form for runtime variables (see below) |

### Survey Variables

Surveys present a form to users launching a job, enforcing input validation.

```json
{
  "name": "Deploy Application",
  "description": "Deploy the application to the target environment",
  "spec": [
    {
      "question_name": "Target Environment",
      "variable": "target_env",
      "type": "multiplechoice",
      "choices": ["dev", "staging", "production"],
      "required": true,
      "default": "dev"
    },
    {
      "question_name": "Application Version",
      "variable": "app_version",
      "type": "text",
      "required": true,
      "min": 5,
      "max": 20
    },
    {
      "question_name": "Enable Debug",
      "variable": "debug_mode",
      "type": "multiplechoice",
      "choices": ["yes", "no"],
      "default": "no"
    }
  ]
}
```

### Launching Jobs via API

```bash
# Launch a job template with extra variables
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "limit": "webservers",
    "extra_vars": {"app_version": "2.1.0", "target_env": "production"},
    "credentials": [5, 12]
  }' \
  https://controller.example.com/api/v2/job_templates/14/launch/

# Response includes job ID
# {"job": 4832, "id": 4832, "type": "job", ...}

# Poll job status
curl -k -H "Authorization: Bearer $TOKEN" \
  https://controller.example.com/api/v2/jobs/4832/

# Get job stdout
curl -k -H "Authorization: Bearer $TOKEN" \
  https://controller.example.com/api/v2/jobs/4832/stdout/?format=txt
```

---

## Workflow Job Templates

Workflows chain multiple job templates, project syncs, inventory syncs, and approval gates into a directed graph.

### Workflow Node Types

| Node Type | Purpose |
|---|---|
| **Job Template** | Run a playbook |
| **Workflow Job Template** | Nest a sub-workflow |
| **Project Sync** | Update a project from SCM |
| **Inventory Sync** | Refresh a dynamic inventory source |
| **Approval** | Pause and wait for human approval (with optional timeout) |

### Convergence Modes

| Mode | Behavior |
|---|---|
| **Any** (default) | Node runs when ANY parent completes with the expected status |
| **All** | Node runs only when ALL parents complete with the expected status |

### Edge Types

Each workflow node connects to the next via one of three edge types:

- **On Success** (green) — next node runs if this one succeeds
- **On Failure** (red) — next node runs if this one fails
- **Always** (blue) — next node runs regardless of outcome

### Workflow Example

```
[Sync Inventory] ──success──► [Deploy App] ──success──► [Approval: Prod Sign-off]
                                    │                          │
                                    │failure                   │approved
                                    ▼                          ▼
                              [Rollback App]             [Promote to Prod]
                                    │                          │
                                    │always                    │failure
                                    ▼                          ▼
                              [Notify Slack]             [Notify PagerDuty]
```

**UI Path:** Automation Controller > Templates > Add > Add workflow template > Visualizer

### Workflow API Example

```bash
# Launch a workflow
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"extra_vars": {"release": "v2.1.0"}}' \
  https://controller.example.com/api/v2/workflow_job_templates/8/launch/

# Approve a pending approval node
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  https://controller.example.com/api/v2/workflow_approvals/42/approve/

# Deny a pending approval
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  https://controller.example.com/api/v2/workflow_approvals/42/deny/
```

---

## Schedules

Schedules attach to job templates, workflow templates, project syncs, and inventory syncs.

### RRULE Syntax

AAP uses RFC 5545 RRULE format for recurring schedules.

```
# Every day at 2:00 AM UTC
DTSTART:20240101T020000Z RRULE:FREQ=DAILY;INTERVAL=1

# Every Monday and Wednesday at 6:00 PM Eastern
DTSTART:20240101T230000Z RRULE:FREQ=WEEKLY;BYDAY=MO,WE;INTERVAL=1

# First day of every month at midnight
DTSTART:20240101T050000Z RRULE:FREQ=MONTHLY;BYMONTHDAY=1;INTERVAL=1

# Every 4 hours
DTSTART:20240101T000000Z RRULE:FREQ=HOURLY;INTERVAL=4

# Weekdays only at 8 AM
DTSTART:20240101T130000Z RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;INTERVAL=1
```

**Important:** DTSTART uses UTC. Adjust for your timezone. The UI handles timezone conversion automatically.

```bash
# Create a schedule via API
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Nightly Patching",
    "unified_job_template": 14,
    "rrule": "DTSTART:20240101T060000Z RRULE:FREQ=DAILY;INTERVAL=1",
    "enabled": true
  }' \
  https://controller.example.com/api/v2/schedules/
```

---

## Notification Templates

| Type | Configuration |
|---|---|
| **Slack** | Token, destination channel(s), custom icon/username |
| **Email** | SMTP host, port, sender, recipients, TLS |
| **Webhook** | URL, HTTP method (POST/PUT), headers, body template |
| **PagerDuty** | API token, service key, subdomain |
| **Grafana** | URL, API key, dashboard ID |
| **IRC** | Server, port, channel, nick, SSL |
| **Mattermost** | URL, channel, username, icon, SSL |
| **Rocket.Chat** | URL, channel, username, icon |
| **Twilio** | Account SID, Auth Token, from/to numbers |

Notifications can trigger on: **Start**, **Success**, **Failure**, and **Approval** (workflow only).

**UI Path:** Automation Controller > Notifications > Add

---

## Private Automation Hub

### Content Types

| Content | Description |
|---|---|
| **Certified Collections** | Red Hat and partner-certified, fully supported content. Synced from `console.redhat.com` |
| **Validated Collections** | Community-tested but not Red Hat-supported. Synced from `console.redhat.com` |
| **Custom Collections** | Internally developed collections published by your team |
| **Execution Environments** | Container images served from the built-in Pulp container registry |

### Syncing Content from console.redhat.com

```bash
# Configure ansible.cfg to use Private Automation Hub
[galaxy]
server_list = automation_hub, galaxy

[galaxy_server.automation_hub]
url=https://hub.example.com/api/galaxy/content/published/
token=<your-hub-token>

[galaxy_server.galaxy]
url=https://galaxy.ansible.com/
```

### Publishing Custom Collections

```bash
# Build and publish a collection
cd my_namespace/my_collection/
ansible-galaxy collection build
ansible-galaxy collection publish \
  my_namespace-my_collection-1.0.0.tar.gz \
  --server https://hub.example.com/api/galaxy/content/inbound-custom/ \
  --token $HUB_TOKEN
```

### Container Registry for EEs

```bash
# Tag and push an EE to Private Automation Hub
podman login hub.example.com
podman tag my-custom-ee:1.0 hub.example.com/my-custom-ee:1.0
podman push hub.example.com/my-custom-ee:1.0

# Configure Controller to pull EEs from Hub
# UI: Automation Controller > Execution Environments > Add
#   Image: hub.example.com/my-custom-ee:1.0
#   Credential: (select Container Registry credential for Hub)
```

---

## Event-Driven Ansible (EDA)

### Architecture

```
Event Source ──► EDA Controller ──► Decision Engine (Drools) ──► Action
(Webhook,        (Rulebook         (Evaluates conditions)       (Run Job Template,
 Kafka,           Activation)                                    Run Playbook,
 Alertmanager)                                                   Debug, Set Fact)
```

### Rulebook Structure

```yaml
---
- name: Respond to webhook events
  hosts: all
  sources:
    - ansible.eda.webhook:
        host: 0.0.0.0
        port: 5000
  rules:
    - name: Restart service on alert
      condition: event.payload.status == "critical"
      action:
        run_job_template:
          name: "Restart Application"
          organization: "Default"
          job_args:
            extra_vars:
              target_host: "{{ event.payload.host }}"

    - name: Log informational events
      condition: event.payload.status == "info"
      action:
        debug:
          msg: "Informational event received: {{ event.payload.message }}"
```

### Event Source Plugins

| Plugin | Source | Use Case |
|---|---|---|
| `ansible.eda.webhook` | HTTP POST webhooks | GitHub, ServiceNow, custom apps |
| `ansible.eda.kafka` | Apache Kafka topics | Streaming event platforms |
| `ansible.eda.alertmanager` | Prometheus Alertmanager | Infrastructure monitoring alerts |
| `ansible.eda.url_check` | HTTP endpoint polling | Health check monitoring |
| `ansible.eda.file_watch` | Local file changes | Config drift detection |
| `ansible.eda.range` | Generate sequential events | Testing and development |
| `ansible.eda.aws_sqs_queue` | AWS SQS messages | Cloud event processing |

### Decision Environments (DEs)

Decision environments are container images for EDA rulebook activations (analogous to EEs for playbooks).

```yaml
# decision-environment.yml
---
version: 3
images:
  base_image:
    name: registry.redhat.io/ansible-automation-platform-25/de-supported-rhel9:latest
dependencies:
  galaxy:
    collections:
      - ansible.eda
      - ansible.eda_contrib
  python:
    - aiokafka
    - aiohttp
  system: []
```

### EDA in the UI

**UI Path:** EDA Controller > Rulebook Activations > Add

Key fields: Rulebook, Decision Environment, Project (Git repo containing rulebooks), Credentials, Restart Policy (Always, Never, On Failure), Log Level.

---

## Instance Groups & Container Groups

### Instance Groups

Instance groups partition execution nodes for job isolation and capacity management.

| Setting | Description |
|---|---|
| **Policy Instance Minimum** | Minimum nodes that must be in this group |
| **Policy Instance Percentage** | Percentage of total nodes to assign |
| **Max Concurrent Jobs** | Limit parallel jobs on this group |
| **Max Forks** | Limit total forks across the group |

**UI Path:** Automation Controller > Instance Groups > Add

### Container Groups (Kubernetes/OpenShift)

Container groups run each job as an ephemeral Kubernetes pod — clean environment per job, auto-scaling, no persistent execution nodes.

```yaml
# Custom pod_spec for a container group
apiVersion: v1
kind: Pod
metadata:
  namespace: ansible-automation
spec:
  serviceAccountName: ansible-ee
  containers:
    - name: worker
      image: hub.example.com/my-custom-ee:1.0
      resources:
        requests:
          cpu: 500m
          memory: 1Gi
        limits:
          cpu: 2000m
          memory: 4Gi
      env:
        - name: HTTP_PROXY
          value: "http://proxy.example.com:3128"
```

**Key consideration:** Container groups do NOT use the standard capacity algorithm. You must set `max_forks` on the container group to prevent oversubscription of Kubernetes nodes.

---

## REST API Usage

### Authentication

```bash
# Create a Personal Access Token (PAT)
curl -k -X POST \
  -H "Content-Type: application/json" \
  -u admin:password \
  -d '{"description": "CI/CD Token", "scope": "write"}' \
  https://controller.example.com/api/v2/tokens/

# Use the token for subsequent requests
export TOKEN="your-token-value"

curl -k -H "Authorization: Bearer $TOKEN" \
  https://controller.example.com/api/v2/me/
```

### Pagination

```bash
# API returns paginated results (default page_size: 25)
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://controller.example.com/api/v2/jobs/?page_size=100&page=2"

# Response includes navigation links:
# "next": "/api/v2/jobs/?page=3&page_size=100"
# "previous": "/api/v2/jobs/?page=1&page_size=100"
```

### awx CLI

```bash
# Install awx CLI
pip install awxkit

# Configure credentials
export CONTROLLER_HOST=https://controller.example.com
export CONTROLLER_USERNAME=admin
export CONTROLLER_PASSWORD=secret
# OR use token auth:
export CONTROLLER_OAUTH_TOKEN=your-token

# Common operations
awx job_templates list --all
awx job_templates launch 14 --extra_vars '{"env": "prod"}'
awx jobs get 4832
awx jobs stdout 4832
awx projects update 7
awx inventories list --all
awx credentials list --all

# Export/import configuration (as code)
awx export --all > aap-config.json
awx import < aap-config.json
```

### Common API Endpoints

| Endpoint | Description |
|---|---|
| `/api/v2/ping/` | Health check (no auth required) |
| `/api/v2/me/` | Current user info |
| `/api/v2/job_templates/` | List/create job templates |
| `/api/v2/job_templates/{id}/launch/` | Launch a job |
| `/api/v2/workflow_job_templates/{id}/launch/` | Launch a workflow |
| `/api/v2/jobs/{id}/` | Job details |
| `/api/v2/jobs/{id}/stdout/` | Job output |
| `/api/v2/inventories/` | List/create inventories |
| `/api/v2/projects/{id}/update/` | Trigger project sync |
| `/api/v2/schedules/` | List/create schedules |
| `/api/v2/workflow_approvals/{id}/approve/` | Approve a workflow approval |
| `/api/v2/workflow_approvals/{id}/deny/` | Deny a workflow approval |
| `/api/v2/config/` | Controller configuration |
| `/api/v2/activity_stream/` | Audit trail |

---

## Logging and Auditing

### Activity Stream

Every change in the Controller is recorded in the activity stream — user actions, object changes, job launches, credential modifications.

**UI Path:** Automation Controller > Activity Stream

```bash
# Query activity stream via API
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://controller.example.com/api/v2/activity_stream/?order_by=-timestamp&page_size=50"
```

### External Logging Integration

Configure via **Automation Controller > Settings > Logging** (or API `/api/v2/settings/logging/`).

| Setting | Description |
|---|---|
| `LOG_AGGREGATOR_HOST` | URL of the external logging service |
| `LOG_AGGREGATOR_PORT` | Port (e.g., 8088 for Splunk HEC) |
| `LOG_AGGREGATOR_TYPE` | `splunk`, `loggly`, `logstash`, `other` |
| `LOG_AGGREGATOR_USERNAME` | Username (if required) |
| `LOG_AGGREGATOR_PASSWORD` | Password/token (Splunk HEC token) |
| `LOG_AGGREGATOR_PROTOCOL` | `https` (recommended), `tcp`, `udp` |
| `LOG_AGGREGATOR_ENABLED` | `true` / `false` |
| `LOG_AGGREGATOR_INDIVIDUAL_FACTS` | Send facts as individual log entries |

### Logger Categories

| Logger | Data Sent |
|---|---|
| `job_events` | Ansible callback data — task results, play summaries |
| `activity_stream` | All object changes (CRUD operations) |
| `system_tracking` | Ansible setup module fact data |
| `awx.analytics.job_lifecycle` | Job state transitions (pending → running → successful) |

### Splunk Integration Example

```bash
# Configure Splunk HEC logging via API
curl -k -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "LOG_AGGREGATOR_HOST": "https://splunk.example.com:8088/services/collector/event",
    "LOG_AGGREGATOR_PORT": 8088,
    "LOG_AGGREGATOR_TYPE": "splunk",
    "LOG_AGGREGATOR_PASSWORD": "your-hec-token",
    "LOG_AGGREGATOR_PROTOCOL": "https",
    "LOG_AGGREGATOR_ENABLED": true
  }' \
  https://controller.example.com/api/v2/settings/logging/
```

---

## Performance Tuning

### Job-Level Tuning

| Setting | Effect | Recommendation |
|---|---|---|
| **Forks** | Parallel host connections per job | Match to EE/node resources. 50-100 for beefy nodes |
| **Job Slicing** | Split inventory across N parallel job runs | Use for large inventories (500+ hosts). Each slice runs on a separate node |
| **Fact Caching** | Store gathered facts for reuse | Enable for environments with frequent runs against same hosts |
| **Verbosity** | Log level (0-5) | Keep at 0 or 1 in production. Higher levels generate large stdout |

### Controller-Level Tuning

```bash
# Key settings (awx-manage shell_plus or Settings > Jobs)
AWX_TASK_ENV:
  ANSIBLE_FORKS: 50
  ANSIBLE_TIMEOUT: 30

# Database connection pooling
DATABASES.default.CONN_MAX_AGE: 0   # Or set to connection reuse time in seconds

# Job event processing
AWX_CLEANUP_PATHS: true              # Clean temp files after jobs
SCHEDULE_MAX_JOBS: 10                # Max simultaneous scheduled jobs

# Fact caching in Controller
# UI: Settings > Jobs > Per-Host Ansible Fact Cache Timeout (seconds)
```

### Database Optimization

```bash
# PostgreSQL maintenance (run periodically)
sudo -u postgres psql -d awx

-- Check table sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC LIMIT 10;

-- Vacuum and analyze (run during maintenance window)
VACUUM ANALYZE;

-- Check for long-running queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;
```

### awx-manage Maintenance Commands

```bash
# Run as the awx user
sudo -u awx awx-manage

# Clean up old job data (keep last 120 days)
awx-manage cleanup_jobs --days 120

# Purge old stdout files buffered to disk
awx-manage cleanup_jobs --dry-run  # Preview first

# View all instances and capacity
awx-manage list_instances

# Gather analytics data on demand
awx-manage gather_analytics

# Check database integrity
awx-manage check_db

# Remove orphaned data
awx-manage cleanup_deleted

# Regenerate secret key (dangerous — breaks existing encrypted data)
# awx-manage regenerate_secret_key  # DO NOT run unless you know what you're doing
```

---

## Backup and Restore

### RPM-Based Installation (AAP 2.4 and earlier)

```bash
# Navigate to the installer directory
cd /path/to/ansible-automation-platform-setup-bundle-2.4-*/

# Backup (creates timestamped backup file)
sudo ./setup.sh -b

# Restore from backup
sudo ./setup.sh -r
```

### Containerized Installation (AAP 2.5+)

```bash
# Backup using the installer
cd /path/to/ansible-automation-platform-containerized-setup-bundle-2.5-*/
sudo ./setup.sh -b

# Restore
sudo ./setup.sh -r
```

### Operator-Based (OpenShift)

```yaml
# Create a backup CR
apiVersion: automationcontroller.ansible.com/v1beta1
kind: AutomationControllerBackup
metadata:
  name: controller-backup-2024-01-15
  namespace: ansible-automation-platform
spec:
  deployment_name: controller

# Restore from backup CR
apiVersion: automationcontroller.ansible.com/v1beta1
kind: AutomationControllerRestore
metadata:
  name: controller-restore
  namespace: ansible-automation-platform
spec:
  deployment_name: controller
  backup_name: controller-backup-2024-01-15
```

### Critical Notes

- **Version match required:** The target AAP version must match the backup version exactly, including PostgreSQL version
- **Test restores regularly:** Validate backups by restoring to a non-production environment
- **Disk space:** Ensure sufficient space for the backup — large job history tables can produce multi-GB backups
- **PVC cleanup (OpenShift):** When removing a controller instance, PVCs are NOT auto-deleted. Manually clean old PVCs before restoring to the same namespace

---

## Upgrading AAP

### RPM to Containerized (2.4 → 2.5)

This is a **migration**, not an in-place upgrade:

1. Back up the existing 2.4 installation (`./setup.sh -b`)
2. Provision new host(s) for 2.5 containerized install
3. Install AAP 2.5 on new hosts
4. Restore backup to the new environment (`./setup.sh -r`)
5. Validate — check jobs, inventories, credentials, schedules
6. Update DNS / load balancers to point to new hosts

### Operator-Based Upgrade (OpenShift)

1. Update the AAP operator subscription channel (e.g., `stable-2.4` → `stable-2.5`)
2. Operator automatically handles the rolling upgrade
3. Monitor the upgrade via OpenShift console or `oc get pods -n ansible-automation-platform -w`
4. Validate post-upgrade: check CRDs, verify controller/hub/eda pods are running

```bash
# Check current operator version
oc get csv -n ansible-automation-platform

# Update subscription channel
oc patch subscription aap-operator -n ansible-automation-platform \
  --type merge -p '{"spec":{"channel":"stable-2.5"}}'

# Monitor upgrade
oc get pods -n ansible-automation-platform -w
```

---

## Troubleshooting

### Job Failures

| Error | Cause | Resolution |
|---|---|---|
| `ERROR! couldn't resolve module/action 'x.y.z'` | Collection missing from EE | Build custom EE with the required collection |
| `denied: requested access to the resource is denied, unauthorized` | EE in Private Hub requires authentication | Attach Container Registry credential to the EE in Controller |
| Job stuck in **Pending** | No capacity, all nodes busy, receptor offline | Check `awx-manage list_instances` for node health and capacity |
| `ansible-playbook: Timeout (12s) waiting for privilege escalation prompt` | `become` password wrong or sudoers misconfigured | Verify machine credential become password. Check `!requiretty` in sudoers |
| `ERROR! the playbook: site.yml could not be found` | Project sync failed or playbook path wrong | Verify project sync succeeded. Check playbook filename matches exactly |
| `Job terminated due to timeout` | Timeout value too low | Increase timeout on the job template (default: 0 = unlimited) |
| `No hosts matched` | Limit pattern or inventory filter returns no hosts | Check inventory, verify host patterns, ensure dynamic source synced |

### Receptor Mesh Issues

```bash
# Node not appearing in mesh
# 1. Check receptor is running on the execution/hop node
sudo systemctl status receptor

# 2. Verify receptor config
cat /etc/receptor/receptor.conf

# 3. Check firewall — port 27199/TCP must be open
firewall-cmd --list-ports
firewall-cmd --add-port=27199/tcp --permanent
firewall-cmd --reload

# 4. Check TLS certificates
# Receptor uses mutual TLS. Certificates must be valid and signed by the same CA

# 5. View receptor connections
receptorctl --socket /var/run/receptor/receptor.sock status

# 6. Test connectivity from controller
receptorctl --socket /var/run/awx-receptor/receptor.sock ping <node-name>

# Common receptor errors in journalctl:
# "certificate verify failed" — TLS cert mismatch or expired
# "connection refused" — receptor not running or firewall blocking 27199
# "no route to node" — mesh topology broken, hop node down
```

### EE Build Failures

```bash
# ansible-builder common errors

# Missing system dependency
# Error: "Package 'xxx' has no installation candidate"
# Fix: Add to bindep.txt or system section of EE definition

# Python dependency conflict
# Error: "ERROR: Cannot install X because these package versions have conflicting dependencies"
# Fix: Pin compatible versions in requirements.txt. Use pip-compile for resolution

# Base image pull failure
# Error: "Error: error creating build container: ... denied: ... requires authentication"
# Fix: podman login registry.redhat.io (requires Red Hat subscription credentials)

# Debug a failed build
ansible-builder build --tag debug-ee:latest --verbosity 3 2>&1 | tee build.log
```

### Database Performance

```bash
# Symptoms: slow UI, job launches delayed, API timeouts

# Check PostgreSQL connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"

# Check table bloat (main_jobevent is usually the largest)
sudo -u postgres psql -d awx -c "
  SELECT schemaname, tablename,
         pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
  FROM pg_tables
  WHERE schemaname = 'public'
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
  LIMIT 10;"

# Clean up old job events (main_jobevent table grows fastest)
awx-manage cleanup_jobs --days 90

# PostgreSQL configuration tuning (postgresql.conf)
shared_buffers = 4GB              # 25% of total RAM
effective_cache_size = 12GB       # 75% of total RAM
work_mem = 64MB                   # Per-sort/hash operation
maintenance_work_mem = 1GB        # For VACUUM, CREATE INDEX
max_connections = 400             # Match controller connection pool

# After config changes
sudo systemctl restart postgresql
```

### License and Subscription

```bash
# Check current license status
curl -k -H "Authorization: Bearer $TOKEN" \
  https://controller.example.com/api/v2/config/ | jq '.license_info'

# Upload a new license/subscription manifest
# UI: Automation Controller > Settings > License
# Or download manifest from access.redhat.com > Subscriptions > Subscription Allocations

# Common license errors:
# "License has expired" — renew subscription at access.redhat.com
# "License count exceeded" — too many managed hosts. Purchase additional capacity
# "Subscription not found" — manifest not uploaded or corrupted. Re-download from portal

# Host count check
curl -k -H "Authorization: Bearer $TOKEN" \
  https://controller.example.com/api/v2/config/ | jq '.license_info.current_instances'
```

### Network and Connectivity

```bash
# Container subnet conflict (common with Podman in AAP 2.5)
# Symptom: "No route to host" errors
# Fix: Change the default container subnet
# /etc/containers/containers.conf:
# [network]
# default_subnet = "10.99.0.0/16"   # Avoid conflicting with internal networks

# Verify Controller API is reachable
curl -k https://controller.example.com/api/v2/ping/
# Expected: {"ha": true, "version": "4.5.x", "active_node": "controller1"}
```

---

## Quick Reference: CLI Tools

| Tool | Purpose | Install |
|---|---|---|
| `awx` | CLI for Automation Controller API | `pip install awxkit` |
| `ansible-builder` | Build custom Execution Environments | `pip install ansible-builder` |
| `ansible-navigator` | Run playbooks with EEs locally | `pip install ansible-navigator` |
| `receptorctl` | Receptor mesh diagnostics | Installed with receptor |
| `awx-manage` | Controller administration utility | Installed on controller nodes |
| `ansible-galaxy` | Collection and role management | Included with ansible-core |
