---
name: security-secrets-cyberark
description: "Expert agent for CyberArk PAM and Conjur. Covers Digital Vault, PVWA, CPM (auto-rotation), PSM (session recording), PTA (threat analytics), Privilege Cloud SaaS, Conjur for DevOps secrets, and Secrets Hub (sync to AWS SM/AKV). WHEN: \"CyberArk\", \"PAM\", \"privileged access\", \"PVWA\", \"CPM\", \"PSM\", \"Conjur\", \"Secrets Hub\", \"vault rotation\", \"session recording\", \"CyberArk machine identity\"."
license: MIT
metadata:
  version: "1.0.0"
---

# CyberArk PAM + Conjur Expert

You are a specialist in CyberArk Privileged Access Management (PAM) and the Conjur secrets management platform. You have deep knowledge of PAM architecture, privileged credential management, session recording, DevOps secrets patterns, and the Secrets Hub synchronization service.

> **Note**: CyberArk acquired Venafi in October 2024. Venafi products are now under the CyberArk Machine Identity Security portfolio. For Venafi/TLS Protect specifics, see `pki/venafi/SKILL.md`.

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **PAM/Vault setup** — Apply Digital Vault and PVWA guidance
   - **Credential rotation** — Apply CPM guidance
   - **Session management** — Apply PSM guidance
   - **Threat detection** — Apply PTA guidance
   - **DevOps/CI/CD secrets** — Conjur guidance
   - **Cloud secrets sync** — Secrets Hub guidance
   - **Architecture** — Load `references/architecture.md`

2. **Identify deployment model** — Self-hosted (on-premises or IaaS) vs. Privilege Cloud (SaaS).

3. **Clarify persona** — PAM admin, developer, auditor, or end user. The interface and permissions differ significantly.

## CyberArk PAM Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    CyberArk PAM Platform                     │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Digital     │  │ PVWA        │  │ CPM                 │ │
│  │ Vault       │◄─┤ (Web Portal)│  │ (Password Rotation) │ │
│  │ (Core Store)│  └─────────────┘  └─────────────────────┘ │
│  └──────┬──────┘                                            │
│         │         ┌─────────────┐  ┌─────────────────────┐ │
│         │         │ PSM         │  │ PTA                 │ │
│         └────────►│ (Session    │  │ (Threat Analytics)  │ │
│                   │  Proxy)     │  │                     │ │
│                   └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Digital Vault

The Digital Vault (formerly EPV — Enterprise Password Vault) is the core secure storage component:

- Hardened Windows Server with custom kernel-level security
- All data encrypted with AES-256 (server key + Master CD key)
- No direct database access — all operations via authenticated API
- Network-isolated: typically only CPM, PVWA, and PSM have inbound access
- Clustered for HA: Active-Active with shared storage (SAN/NAS)

### Vault Hierarchy

```
Vault
├── Safe (access-controlled container, like a folder)
│   ├── Account (a privileged credential record)
│   │   ├── Properties (username, address, platform, last rotation)
│   │   └── Password (encrypted at rest, never logged in plaintext)
│   └── File (arbitrary file stored securely)
└── Safe (another safe for another team/service)
```

**Safes** are the primary access control unit. Users/groups are assigned to safes with specific permissions: List Accounts, Retrieve Accounts, Add Accounts, Modify Accounts, Delete Accounts, Manage Safe, etc.

### Safe Administration

```powershell
# CyberArk REST API (PVWA API)
# Authenticate
$Token = Invoke-RestMethod -Method POST \
    -Uri "https://pvwa.example.com/PasswordVault/API/auth/CyberArk/Logon" \
    -Body (@{username="admin"; password="password"} | ConvertTo-Json) \
    -ContentType "application/json"

# Create a safe
Invoke-RestMethod -Method POST \
    -Uri "https://pvwa.example.com/PasswordVault/API/Safes" \
    -Headers @{Authorization=$Token} \
    -Body (@{
        SafeName = "APP-MYAPP-PROD"
        Description = "Production credentials for MyApp"
        ManagingCPM = "PasswordManager"
        NumberOfVersionsRetention = 5
    } | ConvertTo-Json) \
    -ContentType "application/json"

# Add a member to a safe
Invoke-RestMethod -Method POST \
    -Uri "https://pvwa.example.com/PasswordVault/API/Safes/APP-MYAPP-PROD/Members" \
    -Headers @{Authorization=$Token} \
    -Body (@{
        MemberName = "Domain\ServiceAccount"
        MemberType = "User"
        Permissions = @{
            ListAccounts = $true
            RetrieveAccounts = $true
            UseAccounts = $true
        }
    } | ConvertTo-Json -Depth 5)
```

## PVWA (PrivateArk Web Access)

The web interface for end-users and administrators:
- Password checkout and check-in (one-time use or timed)
- Session launch (via PSM integration — connects through PVWA/PSM to target)
- Policy management (platform policies, safe permissions)
- Reporting and audit
- REST API: `https://pvwa.example.com/PasswordVault/API/`

### Account Management via API

```python
import requests

class CyberArkClient:
    def __init__(self, pvwa_url, username, password):
        self.base_url = pvwa_url
        self.token = self._authenticate(username, password)
    
    def _authenticate(self, username, password):
        resp = requests.post(
            f"{self.base_url}/API/auth/CyberArk/Logon",
            json={"username": username, "password": password}
        )
        return resp.text.strip('"')
    
    def get_accounts(self, safe_name=None, search=None):
        params = {}
        if safe_name:
            params['safeName'] = safe_name
        if search:
            params['search'] = search
        return requests.get(
            f"{self.base_url}/API/Accounts",
            headers={"Authorization": self.token},
            params=params
        ).json()
    
    def get_password(self, account_id, reason="Automated retrieval"):
        return requests.post(
            f"{self.base_url}/API/Accounts/{account_id}/Password/Retrieve",
            headers={"Authorization": self.token},
            json={"reason": reason, "TicketingSystemName": "", "TicketId": ""}
        ).text.strip('"')
    
    def logoff(self):
        requests.post(
            f"{self.base_url}/API/auth/Logoff",
            headers={"Authorization": self.token}
        )
```

## CPM (Central Policy Manager)

The CPM is responsible for automatic credential rotation. It runs as a service and periodically:
1. Connects to the target system (using the current password)
2. Changes the password to a newly generated value
3. Updates the Vault with the new password
4. Verifies the new password works

### Platform Policies

CPM rotation is driven by platform policies that define:
- How to connect (protocol: WinRM, SSH, REST, ODBC, etc.)
- How to change the password (OS-level, DB-level, API-level)
- Rotation schedule (periodic days, immediate after use)
- Password complexity requirements
- Reconcile account (fallback account for rotation failures)

```
Built-in platforms:
  WinServerLocal — Local Windows accounts
  WinDomain — Active Directory domain accounts
  UnixSSH — Unix/Linux root or service accounts
  Oracle — Oracle DBA accounts
  MySQL — MySQL admin accounts
  MSSQLServer — SQL Server sa or service accounts
  AWS — IAM access keys
  AzureAD — Azure service principals
  ...and hundreds more
```

### Rotation Scheduling

```
Platform policy configuration:
  ImmediatelyAfterRetrieve: "No"    → Password valid until next scheduled rotation
  ImmediatelyAfterRetrieve: "Yes"   → Password changed after each retrieval (one-time use)
  
  RequirePasswordChangeEveryX: 30   → Rotate every 30 days
  MinimumValidityPeriod: 1          → Minimum 1 hour before re-rotation allowed
```

### Reconcile Accounts

If rotation fails (e.g., because the current password in the Vault is out-of-sync with the actual password), CPM uses a reconcile account:
- A privileged account that can reset passwords on the target
- For Windows: local admin or domain admin
- For Unix: root account
- For Oracle: SYSDBA account

Configure reconcile accounts on the platform policy or per-account.

## PSM (Privileged Session Manager)

PSM acts as a proxy/jump server for privileged sessions:
- Users never directly connect to target servers
- All sessions are recorded (video + keystroke logging)
- Sessions can be terminated in real-time by security team
- Supports: RDP, SSH, HTTP/HTTPS (web apps), database connections

### Session Flow

```
User (PVWA) → Request Session
PVWA → PSM: Launch connection request
PSM → Vault: Retrieve password (user never sees it)
PSM → Target Server: Connect with retrieved credentials
User ↔ PSM ↔ Target: All traffic proxied and recorded
Session recording stored in Vault
```

### PSM for SSH

```bash
# User connects to PSM (not to target)
ssh user@psm.example.com -p 22

# PSM prompts for target selection via PVWA
# OR user specifies target in SSH command:
ssh PVWA:domain\user#targetserver.example.com@psm.example.com

# User's SSH session is proxied; PSM records everything
```

### Session Monitoring

From PVWA: Live Sessions dashboard shows:
- Active sessions by user, target, duration
- Real-time terminate option
- Recorded sessions searchable by user, target, date, keywords (transcript search)

## PTA (Privileged Threat Analytics)

PTA monitors for anomalous privileged access patterns:
- Detects use of credentials outside of CyberArk (credentials used without going through PVWA/PSM)
- Identifies unmanaged privileged accounts (discovered but not in the Vault)
- Monitors for suspected credential theft patterns
- Integrates with SIEM (Syslog, QRadar, Splunk)

```
PTA detects:
  ✓ Privileged account used without a Vault request ticket
  ✓ Login from unusual IP/time for this account
  ✓ Multiple failed logins followed by success (password spraying)
  ✓ Accounts connecting to systems they've never accessed before
  ✓ Kerberoasting attempts
  ✓ Pass-the-hash / Pass-the-ticket indicators
```

## Conjur (DevOps Secrets)

Conjur is CyberArk's developer-friendly secrets platform, designed for machine and application secrets in CI/CD and cloud-native environments.

### Key Differences from PAM

| Dimension | CyberArk PAM | Conjur |
|---|---|---|
| Primary use case | Human privileged access | Machine/application secrets |
| Interface | Web UI + REST API | REST API + SDKs |
| Rotation | CPM-driven | Dynamic (DB plugin) or manual |
| Auth methods | LDAP, RADIUS, SAML | JWT, Kubernetes, AWS IAM, OIDC |
| Audit | Session recording + keystrokes | API audit log |
| Learning curve | Higher (admin-focused) | Lower (developer-focused) |

### Conjur Architecture

```
Conjur Server (Leader)
├── Policy Store (YAML policies defining resources and permissions)
├── Secret Store (encrypted secret values)
└── Audit Log

Conjur Follower (read-only replica for HA)
```

### Conjur Policy (YAML)

```yaml
# policy.yml — Define resources and permissions
- !policy
  id: myapp
  body:
    # Define variables (secrets)
    - !variable db/password
    - !variable api/key
    
    # Define a host (machine identity)
    - !host myapp-production
    
    # Define a group
    - !group apps
    
    # Add host to group
    - !grant
      role: !group apps
      member: !host myapp-production
    
    # Grant read access to variables
    - !permit
      role: !group apps
      privileges: [read, execute]
      resources:
        - !variable db/password
        - !variable api/key
```

```bash
# Load policy
conjur policy replace -b root -f policy.yml

# Create secret
conjur variable values add myapp/db/password "s3cr3t"

# Retrieve secret (from application)
conjur variable value myapp/db/password
```

### Conjur Kubernetes Integration

```yaml
# Kubernetes authenticator setup
# Namespace annotation for Conjur auth
# In pod spec:
spec:
  serviceAccountName: myapp-sa
  containers:
  - name: secretless-broker
    image: cyberark/secretless-broker:latest
    env:
    - name: CONJUR_ACCOUNT
      value: "myorg"
    - name: CONJUR_APPLIANCE_URL
      value: "https://conjur.example.com"
    volumeMounts:
    - name: conjur-access-token
      mountPath: /run/conjur
  - name: app
    image: myapp:latest
    # App connects to secretless-broker on localhost
    # Broker handles auth, never exposes credentials to app
```

### Secretless Broker

CyberArk's Secretless Broker intercepts application connections (DB, HTTP, etc.) and injects credentials transparently. Applications use no-auth or placeholder credentials; the broker fetches real credentials from Conjur.

## Secrets Hub

Secrets Hub synchronizes CyberArk PAM or Conjur secrets to cloud-native secret stores:
- Push secrets to AWS Secrets Manager
- Push secrets to Azure Key Vault
- Applications in AWS/Azure use their native secret managers without knowing about CyberArk
- CyberArk retains governance, audit, and rotation control

```
CyberArk Vault (source of truth)
  → Secrets Hub (sync engine)
    → AWS Secrets Manager (consumer in AWS)
    → Azure Key Vault (consumer in Azure)

Benefits:
  - Cloud apps use native SM APIs (no Conjur/PVWA SDK needed)
  - PAM team controls rotation and governance centrally
  - Audit trail in CyberArk, consumption in cloud
```

## Reference Files

- `references/architecture.md` — CyberArk PAM component internals: Vault encryption, DR Vault, CPM rotation mechanics, PSM proxy architecture, PTA detection models, Conjur Leader/Follower replication, Secrets Hub sync architecture.
