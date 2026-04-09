# Veeam Security Hardening and Best Practices

## Immutable Backup Configuration

### Hardened Linux Repository: Step-by-Step

**1. Prepare the Linux server:**
```bash
# Install minimal OS (Ubuntu 22.04 LTS recommended)
# No GUI, no unnecessary services

# Create dedicated filesystem for backups (XFS with reflink)
mkfs.xfs -b size=4096 -m reflink=1 /dev/sdb
mkdir -p /backup
echo "/dev/sdb /backup xfs defaults,noatime 0 0" >> /etc/fstab
mount /backup

# Set permissions (Veeam will configure the service account)
chmod 777 /backup
```

**2. Add to Veeam:**
- `Backup Infrastructure > Backup Repositories > Add Repository`
- Type: Linux (standalone server)
- Add the Linux server credentials (temporary; SSH will not be needed after deployment)
- Path: `/backup`
- Enable: `Make recent backups immutable for [30] days`
- Advanced: `Use per-machine backup files`

**3. Post-deployment hardening:**
```bash
# After Veeam deploys the transport component, restrict SSH
# Option A: Disable SSH entirely (if no other management need)
systemctl stop sshd
systemctl disable sshd

# Option B: Restrict SSH to management IPs only
# /etc/ssh/sshd_config:
AllowUsers admin@10.0.0.0/24
PasswordAuthentication no
PubkeyAuthentication yes
```

**4. Verify immutability is working:**
```bash
# Check that backup files have immutable bit set
lsattr /backup/
# Output should show: ----i----------- for .vbk/.vib files after backup completes
```

### Object Storage Immutability

**AWS S3 Compliance Mode (recommended for ransomware protection):**

1. Create S3 bucket with Object Lock enabled (must be done at bucket creation time)
2. Set default retention: Compliance mode, retention = backup retention period
3. Do NOT grant `s3:BypassGovernanceRetention` to any user
4. IAM policy for Veeam service account (minimum required permissions):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObjectVersion",
        "s3:GetObjectRetention",
        "s3:PutObjectRetention",
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:GetBucketObjectLockConfiguration"
      ],
      "Resource": [
        "arn:aws:s3:::veeam-backups-bucket",
        "arn:aws:s3:::veeam-backups-bucket/*"
      ]
    }
  ]
}
```
5. Note: Do NOT grant `s3:DeleteObject` on the bucket policy if you want compliance-mode protection (Veeam will use versioned deletes; actual data cannot be deleted before retention expiry)

**Azure Blob Immutability:**
1. Create storage account with "Immutable blob storage" enabled
2. Create container, add time-based retention policy
3. Lock the policy (once locked, cannot shorten retention period)
4. Add to Veeam as Azure Blob repository with immutability setting

---

## 4-Eyes Authorization Setup and Governance

### Configuration

`Veeam Backup & Replication Console > Menu (hamburger) > Configuration > Security`

1. Enable `4-eyes authorization` toggle
2. Configure approver accounts:
   - At minimum 2 distinct Active Directory accounts
   - Approvers should NOT be the same person who initiates operations
   - Consider: primary backup admin cannot be an approver; approval requires a manager account

### Protected Operations Scope

| Operation | Risk Without 4-Eyes |
|---|---|
| Delete backup job | Removes backup coverage; hides evidence |
| Disable backup job | Silently stops protection |
| Delete restore point / backup file | Destroys recovery option |
| Shorten retention period | Reduces available recovery points |
| Remove repository | Destroys all stored backups |

### Approval Workflow

When a protected operation is initiated:
1. Initiating admin sees "Operation pending approval" message
2. Pending operations list appears in `Home > Last 24 Hours > Pending Operations`
3. Approver logs in, reviews the operation details
4. Approver clicks Approve or Deny
5. Veeam logs: initiator identity, operation type, timestamp, approver identity, approval decision

**Monitoring:** Configure Veeam ONE alarm on pending 4-eyes operations. Alert if an operation waits > 1 hour without approval (may indicate the initiator is trying to perform unauthorized operation off-hours).

---

## Encryption Configuration

### Repository-Level Encryption

For repositories that do not have hardware/storage-level encryption:

`Backup Job > Storage > Advanced > Encryption > Enable backup file encryption`

- Set a strong password (store in enterprise password manager, NOT on the backup server itself)
- Veeam uses AES-256 for backup file encryption
- Password hint: Do NOT use a hint that reveals the password
- Key storage: Veeam stores an encrypted version of the key; if the VBR server is lost, you need both the VBR config backup AND the encryption password to restore

### External KMS Integration (v12+)

Veeam v12+ supports KMIP for external key management:

1. Deploy KMIP server (HashiCorp Vault Enterprise, Thales, Entrust, etc.)
2. `Menu > Configuration > Encryption > External Key Management`
3. Add KMIP server connection
4. Enable KMIP for encryption keys

**Key rotation with KMIP:**
- Key rotation can be triggered manually or by policy
- Veeam re-encrypts data encryption keys with the new master key
- Backup data is NOT re-encrypted (data keys are re-wrapped)

### Network Encryption

All Veeam data transport is encrypted by default in v12+:

- VBR to proxy: TLS
- Proxy to repository: TLS
- Additional: Enable `Encrypt backup traffic` in job settings for additional application-layer encryption

---

## Secure Restore Best Practices

### AV Engine Configuration

For Secure Restore to be effective, the AV engine on the helper VM must:
1. Have current definitions (update at least daily)
2. Be configured for full scan, not quick/partial scan
3. Log scan results to a location accessible to Veeam

**Recommended configuration:**
- Dedicate a Windows Server VM as the Secure Restore helper
- Install AV engine with real-time protection enabled
- Configure AV update schedule: hourly or at minimum daily
- Ensure the VM has internet access (or internal AV update server) for definition updates

### Limitations and Mitigations

| Limitation | Mitigation |
|---|---|
| AV only detects known threats | Supplement with threat hunting (consider Rubrik for advanced IOC/YARA scanning) |
| Signature freshness lag | Update definitions immediately before critical restores |
| Scan time adds to RTO | Pre-scan backups proactively using SureBackup + AV (not just at restore time) |
| Encrypted malware evades signature scanning | Use behavior-based AV; Rubrik Threat Hunting provides additional capability |

### Scanning Before Restore (Proactive)

Configure Veeam ONE or SureBackup to scan backups proactively (not just at restore time):
- Create a SureBackup job that includes Secure Restore-style scanning
- Schedule daily or weekly
- Alert on any threats found

---

## SureBackup Best Practices

### Virtual Lab Configuration

**Isolated network setup:**
- Create a dedicated internal virtual switch for the lab (no uplink to physical network)
- Configure IP masquerading: Veeam replaces the VM IP in the lab with a mapped IP (prevents conflicts)
- Optional proxy appliance: Allows lab VMs to access internet/AD for more realistic testing

**Resource allocation:**
- SureBackup uses production backup files (no data copy); the overhead is: booting VMs, running tests
- Allocate: CPU = 2x highest concurrent test VMs; RAM = sum of test VM max memory
- Storage: Test VMs write to a redo log (not the backup file); size the redo log appropriately

### Application Group Configuration

Start-up order for typical enterprise environment:
1. Domain Controller(s) -- all other VMs depend on AD
2. DNS server (if separate from DC)
3. DHCP server (if needed by test VMs)
4. File servers / dependency services
5. Application VMs under test

Set startup order with delays:
```
VM: dc01 > Wait 2 minutes > Heartbeat test passes > Continue
VM: dc02 > Wait 1 minute > Heartbeat test passes > Continue
VM: appserver01 > Wait 5 minutes > Application test (HTTP 200 on port 443) > Pass
```

### Test Frequency Recommendations

| Tier | System Type | SureBackup Frequency |
|---|---|---|
| Tier 0 | Critical (payment, ERP) | Daily |
| Tier 1 | Business-critical | Weekly |
| Tier 2 | Important | Monthly |
| Tier 3 | Non-critical | Quarterly |

### Interpreting SureBackup Results

| Result | Meaning | Action |
|---|---|---|
| Success | All tests passed | No action required; log for audit |
| Warning | Some tests passed; some timed out | Investigate specific test failures; may indicate application issue |
| Failure | VM did not boot OR core test failed | Escalate: backup may not be recoverable; investigate immediately |

**Common failure causes:**
- VM fails heartbeat: Kernel panic on boot, driver issue, corrupted filesystem
- VM fails ping: Network configuration in virtual lab, firewall blocking ICMP
- Application test fails: Application requires external dependency not in virtual lab (e.g., AD for authentication)

---

## Ransomware Resilience Architecture

### Recommended Veeam Reference Architecture

**Tier 1: Primary backup (local)**
- Backup repository: Hardened Linux repository (immutable, 30-day retention)
- Proxies: 2+ for redundancy and load distribution
- Location: Production datacenter, isolated VLAN

**Tier 2: Backup copy (offsite, immutable)**
- Repository: S3 Object Lock (compliance mode) or Azure immutable blob
- Backup copy job: Every 4 hours for Tier 0, daily for Tier 1+
- Credentials: Dedicated cloud IAM account; credentials NOT stored in production AD

**Tier 3: Archive (long-term)**
- SOBR archive tier: AWS S3 Glacier or Azure Archive
- Retention: 12 months (GFS policy)

**Verification:**
- SureBackup: Daily for Tier 0, weekly for Tier 1
- Secure Restore: Enabled for all restore operations

### Network Segmentation for Backup Infrastructure

```
Production Network (192.168.1.0/24)
     |
     | [Firewall rules: allow only backup traffic outbound]
     |
Backup Network (10.10.0.0/24)
  ├── Veeam Backup Server (10.10.0.10)
  ├── Backup Proxy 1 (10.10.0.11)
  ├── Backup Proxy 2 (10.10.0.12)
  └── Hardened Linux Repo (10.10.0.20)
     |
     | [Firewall: allow only HTTPS outbound to S3 endpoint]
     |
Internet / Cloud Storage (S3 bucket in separate AWS account)
```

**Firewall rules (backup network):**
- Inbound from production: Allow ports 902 (VADP), 445 (SMB for agent), 135/dynamic (RPC for agent)
- Outbound from backup network: Allow 443 to S3/Azure endpoints only
- No inbound from internet
- No direct production ↔ cloud path (all data flows through backup server/proxy)

### Credential Isolation

| Credential | Storage | Access |
|---|---|---|
| Veeam service account (ESXi/Hyper-V access) | VBR credential store | Read-only to vSphere/Hyper-V |
| Hardened repo service account | Linux local account | Local only; no AD; no SSH after deploy |
| S3/Azure credentials | VBR credential store | Write to S3; no Delete in compliance mode |
| Veeam console admin accounts | AD with MFA | 4-eyes for destructive operations |
| VBR database credentials | Local (PostgreSQL peer auth) | Local only |

---

## VBR Configuration Backup

The VBR configuration backup is critical -- it contains all job definitions, credentials, and settings. Without it, recovery requires manual reconfiguration.

### Configuration

`Menu > Configuration Backup`

Settings:
- **Destination**: External location (NOT the same server or backup repository that VBR manages)
- **Encryption**: Always enable (backup contains encrypted credentials)
- **Schedule**: Daily minimum
- **Restore points**: Keep at least 10

**Storage recommendations:**
- Dedicated SMB share on a server not managed by this VBR instance
- Or: Object storage bucket (separate from backup data bucket)
- Or: Second VBR instance (peer backup of configuration files)

### What Configuration Backup Contains

- All backup jobs (schedule, retention, source/destination)
- All backup repositories and credential associations
- All backup proxy assignments
- License file
- All stored credentials (encrypted with VBR master key)
- SureBackup virtual labs and jobs
- Backup copy jobs
- Tape jobs (if applicable)

### Recovery from Configuration Backup

If VBR server is lost:
1. Install fresh VBR on new server (same version)
2. `Menu > Configuration Backup > Restore`
3. Provide path to .bco file and encryption password
4. All jobs, credentials, and settings are restored

---

## Capacity Planning

### Repository Sizing

**Formula:**
```
Repository size = Daily change rate × Retention days × Compression ratio + Full backup size × Number of full backups
```

Typical values:
- Daily change rate: 3-5% of total source data
- Compression ratio: 1.5-2x (dedupe + compression combined: 2-5x depending on data type)
- Full backup: source_data_size / compression_ratio

**Example:**
- Source: 10 TB VMware environment
- Daily change rate: 5% = 500 GB/day
- Retention: 30 days
- Compression ratio: 2x (divide raw by 2)
- Monthly full backup (1 full per month)

```
Incrementals = 500 GB/day × 30 days / 2 = 7.5 TB
Monthly full = 10 TB / 2 = 5 TB
Total = ~12.5 TB
Overhead (metadata, temp files): +20% = ~15 TB
```

### Proxy Sizing

- 1 physical CPU core (or vCPU) per concurrent backup task
- 2 GB RAM per concurrent task
- Network: Each task uses ~50-200 Mbps (depending on source data rate and compression)
- Start with 2 CPUs / 4 GB RAM for a small environment; scale as concurrent tasks increase

**Concurrent tasks guideline:**
- Recommended: 1 concurrent task per 2 VMs in a maintenance window
- Example: 20 VMs in a 2-hour window → 10 concurrent tasks → 10 vCPUs, 20 GB RAM on proxy

### Performance Tier vs. Capacity Tier Ratio

As a rule of thumb:
- Performance tier (local disk): Last 7-14 days of backups for fast restore
- Capacity tier (object storage): 14+ days for ransomware dwell coverage + long-term retention
- Archive tier: Monthly/annual GFS points for compliance
