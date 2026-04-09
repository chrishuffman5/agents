# CyberArk PAM + Conjur — Architecture Internals

Deep reference covering Digital Vault encryption, DR Vault, CPM rotation mechanics, PSM proxy internals, PTA detection, Conjur Leader/Follower replication, and Secrets Hub sync architecture.

---

## Digital Vault Internals

### Encryption Architecture

The Digital Vault uses a layered encryption model:

```
Data at rest in Vault storage:
  └── Encrypted with: Server Key
        └── Server Key encrypted with: Operator Key (Master CD Key)
              └── Operator Key stored on encrypted media (CD/USB)
              └── Recovery Key (backup of Operator Key, stored separately)
```

**Server key**: Derived from the Vault master password + entropy. Never stored on disk in plaintext.

**Operator Key (Master CD)**: An external physical media (historically a CD, now typically USB) containing the key needed to start the Vault service. Without it, the Vault cannot decrypt the server key and remains offline.

**Data encryption**: Every password stored in the Vault is individually encrypted with AES-256 before being written to storage. The encryption key is derived from the Safe key + account-specific salt.

### Vault File System

The Vault uses a proprietary file system (not NTFS):
- Custom kernel driver intercepts file I/O
- Prevents unauthorized access even with local admin rights
- All files encrypted with Vault-internal keys
- No direct database — flat file store with internal indexing

### Vault HA Architecture

```
Primary Vault (Active)
  ├── Accept read/write operations
  ├── Replicate to DR Vault asynchronously (or synchronously)
  └── Shared storage: SAN/NAS for metadata

DR Vault (Passive)
  ├── Receive replication from Primary
  ├── Standby — not accepting connections during normal operation
  └── Promote to Primary on failover (manual or with cluster manager)
```

**Failover**: CyberArk uses Windows Server Failover Clustering (WSFC) for automated failover. A cluster resource (VIP/DNS) floats between nodes. On failover:
1. Cluster detects Primary Vault failure
2. DR Vault is promoted to Primary (service starts)
3. Cluster resource moves to new Primary
4. CPM, PVWA, PSM reconnect automatically

---

## CPM Rotation Mechanics

### Rotation Workflow

```
CPM Service (Windows)
  1. Reads pending rotation queue from Vault
  2. For each account due for rotation:
     a. Retrieves current password from Vault
     b. Connects to target using platform-specific plugin
     c. Generates new password (per complexity policy)
     d. Issues "change password" command on target
     e. Updates password in Vault
     f. Verifies new password by connecting with it
     g. Marks rotation as Success or Failure

  On failure:
     → Attempts reconcile using reconcile account
     → If reconcile succeeds: new password set, Vault updated
     → If reconcile fails: marks account as "needs reconcile", alerts
```

### Platform Plugins

CPM uses platform-specific plugins (DLLs/executables) for each target type:
- **WinServerLocal**: WMI / Net User command
- **WinDomain**: LDAP SetPassword / kpasswd
- **UnixSSH**: SSH + `passwd` command
- **Oracle**: SQL `ALTER USER` statement
- **MySQL/MSSQL**: SQL `ALTER USER`/`sp_password`
- **AWS**: IAM API (CreateAccessKey + DeleteAccessKey)
- **Azure**: Graph API (reset SP password/certificate)
- **REST**: Custom HTTP plugin framework

### Reconcile Account Logic

```
Primary account (e.g., app_db_user) → rotation fails
  ↓
CPM checks: is there a reconcile account configured?
  Yes: use reconcile account (e.g., dba_admin) to:
       1. Reset app_db_user password
       2. Update Vault with new password
       3. Verify new password
  No: Mark account for manual intervention + alert
```

Reconcile accounts are stored in the same Vault. They require their own rotation policy (to avoid the reconcile account itself becoming out-of-sync).

---

## PSM Proxy Architecture

### Connection Flow

```
User Browser/Client
  │
  │ HTTPS (PVWA) or RDP/SSH direct to PSM
  ▼
PVWA Web Server
  │ Authenticated session, session token
  ▼
PSM Server (Windows)
  │ PSMConnect domain account (service account for PSM)
  │ PSM requests credential from Vault
  ▼
Digital Vault
  │ Returns credential (PSM has Retrieve permission on safe)
  ▼
PSM Server
  │ Launches target application (mstsc.exe, PuTTY, browser, etc.)
  │ Injects credentials via keyboard hook or RDP mechanism
  ▼
Target Server
  │ Session appears as PSM service account, not the end-user
  │ All activity recorded at PSM level
  ▼
Recording stored in Vault (encrypted .tmp → .arec files)
```

### Session Recording Storage

Session recordings are stored in the Vault as files associated with the account and session:
- Format: CyberArk proprietary `.arec` format (can be converted to video)
- Encrypted with the Safe key (same as other Vault objects)
- Searchable: PSM indexes keystrokes for text search across recordings
- Retention: configurable per safe; old recordings can be archived

### PSM Hardening

PSM servers are hardened beyond standard Windows:
- Restricted service accounts (PSMConnect, PSMAdminConnect)
- AppLocker policies (only approved applications can run)
- No direct internet access
- Local admin access limited to CyberArk administrators
- All PSM admin actions audited

---

## PTA Detection Models

### Network-Based Detection

PTA analyzes network traffic (SPAN/TAP or integration with AD) to detect:
- **Unmanaged accounts**: Privileged account usage (admin/root/Domain Admins) not originating from CyberArk PSM
- **Golden Ticket**: Kerberos TGT with abnormal attributes (long lifetime, non-DC origin)
- **Overpass-the-Hash**: NTLM auth from account that should use Kerberos
- **Lateral movement**: Sequential logon attempts across multiple systems

### SIEM Integration

PTA events are forwarded to SIEM via syslog (CEF format):
```
CEF:0|CyberArk|PTA|...
Unmanaged privileged access detected:
  Account: DOMAIN\svc-myapp
  Source IP: 10.1.1.50
  Target: db-server-01
  Time: 2025-01-01T12:00:00Z
  Risk Score: 85
```

PTA provides risk scores (0-100) and feeds into PVWA to:
- Automatically increase session monitoring intensity
- Trigger additional MFA requirements
- Alert PAM team for immediate review

---

## Conjur Leader/Follower Architecture

### Replication Model

```
Conjur Leader (single write node)
  ├── Accept all API writes (policy changes, secret updates)
  ├── PostgreSQL backend (encrypted)
  └── Replicate to Followers asynchronously

Conjur Followers (read-only replicas)
  ├── Accept all API reads (secret retrieval, auth)
  ├── Sync from Leader via standby certificate rotation
  └── Continue serving reads if Leader is temporarily unavailable

Conjur Standbys (hot standby for Leader)
  ├── Full replica, ready for Leader promotion
  └── Synchronous replication from Leader
```

**Load distribution**: Applications should target Followers for secret reads (high frequency, read-only). Leader handles policy changes and secret writes only.

### Authentication Flow (Kubernetes)

```
Pod starts with Kubernetes Service Account Token
  ↓
Conjur Kubernetes Authenticator validates:
  1. Service account token is valid (call to K8s API)
  2. Service account name matches Conjur policy
  3. Namespace matches Conjur policy
  4. Pod UID is valid
  ↓
Conjur issues short-lived API token (8-minute TTL)
  ↓
Sidecar/Secretless-Broker uses API token to retrieve secrets
  ↓
Secrets delivered to application (environment, file, or in-memory)
```

---

## Secrets Hub Architecture

### Sync Model

```
CyberArk Vault / Conjur (source of truth)
  │
  │ Secrets Hub monitors for changes
  ▼
Secrets Hub Service (cloud-hosted or self-hosted)
  │ Transforms secret format if needed
  ▼
Target Store (AWS SM / Azure KV)
  │ Creates/updates secret with matching value
  ▼
Application reads from native cloud secret store
```

### Sync Policies

Secrets Hub uses sync policies to define:
- Source (Vault safe + account filter, or Conjur variable)
- Target (AWS SM path, Azure KV name)
- Transformation (rename, prefix/suffix)
- Trigger (on Vault rotation, scheduled, manual)

```
CyberArk Safe: APP-MYAPP-PROD
  Account: Oracle-db.prod.myapp (password: secret123)
  
Secrets Hub sync policy:
  Source: Safe=APP-MYAPP-PROD, Account=Oracle-db.prod.myapp
  Target: AWS SM: prod/myapp/oracle-password
  
AWS Secrets Manager:
  prod/myapp/oracle-password = { "password": "secret123", "username": "app_user" }
```

### Rotation Propagation

1. CPM rotates password in CyberArk Vault
2. Secrets Hub detects version change (event-driven via Vault notification or polling)
3. Secrets Hub pushes new value to AWS SM / Azure KV
4. Applications reading from AWS SM get updated value on next retrieval
5. Application-level graceful rotation (AWSPREVIOUS retained in SM for brief overlap)
