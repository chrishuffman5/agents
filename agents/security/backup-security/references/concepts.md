# Backup Security Fundamentals

## The 3-2-1-1-0 Rule

### Evolution from 3-2-1

The original 3-2-1 rule (Peter Krogh, 2009) predates modern ransomware. The extensions address current threat landscape:

- **3-2-1**: Three copies, two media types, one offsite — addresses hardware failure, site disaster
- **3-2-1-1**: Adds one immutable/air-gapped copy — addresses ransomware, insider threats, compromised credentials
- **3-2-1-1-0**: Adds zero errors in verified restores — addresses "backup exists but doesn't restore"

### Practical Implementation

A compliant 3-2-1-1-0 implementation might look like:

| Copy | Location | Media | Immutable? |
|---|---|---|---|
| Production data | Primary datacenter | SAN/NAS | No (live data) |
| Backup copy 1 | Backup server | Backup repository (disk) | Optional |
| Backup copy 2 | Offsite/cloud | Object storage (S3/Azure) | Yes — Object Lock |
| Immutable/air-gapped copy | Cyber vault / tape | Isolated storage | Yes — hard immutability |

The offsite copy and immutable copy CAN be the same copy if the offsite copy is immutable (e.g., S3 Object Lock compliance mode). This satisfies both the "1 offsite" and "1 immutable" requirements with one copy.

### Retention Strategy

Retention must account for ransomware dwell time. Industry average dwell time: 2-6 weeks before detonation.

**Minimum recommended retention:**
- Daily backups: 30+ days (covers 6-week dwell + margin)
- Weekly backups: 13 weeks (quarterly coverage)
- Monthly backups: 12 months
- Annual backups: 7 years (regulatory compliance tier)

Grandfather-Father-Son (GFS) rotation is the standard implementation for meeting these tiers.

---

## Immutable Backups

### What Immutability Means

True immutability means the backup data cannot be modified or deleted by any means — including by the backup administrator, storage administrator, or root/Administrator OS user — for the defined retention period. After the retention period, the system automatically expires the data.

This is distinct from:
- **Access control protection**: A highly privileged attacker (or ransomware with admin credentials) can bypass access controls
- **Encryption**: Encrypted backups can still be deleted; encryption protects confidentiality, not availability

### Immutability Mechanisms

**Hardware-enforced (strongest):**
- WORM tape (LTO with WORM media): Physical write-once; no software can erase
- Self-encrypting WORM drives: Firmware-level protection
- Immutable object storage with compliance mode (S3, Azure): Cloud provider guarantees retention at infrastructure level

**Software-enforced with OS hardening:**
- Linux `chattr +i` flag: Files marked immutable at ext4/xfs filesystem level; root cannot delete without removing the flag first
- Veeam Hardened Linux Repository: Combines `chattr +i` with restricted SSH access, single-use credentials, and no persistent remote access
- Rubrik immutable filesystem: Custom filesystem (not POSIX) that rejects modification/deletion via any interface

**Object storage WORM:**

| Mode | Who Can Override | Suitable For |
|---|---|---|
| Governance | Privileged IAM user with bypass permission | Test environments, flexible retention |
| Compliance | No one (including AWS root) | Regulatory compliance, ransomware protection |
| Legal Hold | No one until hold is removed | Litigation/investigation |

Always use compliance mode for ransomware protection. Governance mode provides false security if attacker compromises cloud credentials.

### Key Management for Immutable Backups

Encryption + immutability is the correct combination: immutability ensures data cannot be deleted; encryption ensures data cannot be read if media is stolen.

**Critical rule**: Do not store encryption keys in the same location as the backup data. If ransomware can reach your backup repository, it may be able to reach your key store if they're co-located.

Best practice:
- External KMS (HashiCorp Vault, AWS KMS, Azure Key Vault, Thales CipherTrust)
- Separate access controls for KMS vs. backup repository
- Key rotation: rotate annually or after suspected compromise
- Key escrow: store recovery keys offline (printed, in a safe) for disaster scenarios

---

## Air-Gapped Backups

### Physical Air Gap

**Definition**: Physical media completely disconnected from all networks and stored in a different location.

**Implementation:**
- LTO tape rotated offsite (Iron Mountain, in-house offsite facility)
- Removable disk (RDX, USB drives) — less common for enterprise
- "Sneakernet" virtual tape library (VTL) exports to physical tape

**Advantages**: True isolation; ransomware cannot traverse a physical gap.

**Disadvantages**: Manual process; recovery time is limited by physical retrieval; rotation policies require disciplined execution.

**Best practices:**
- Label tapes with retention dates; use locked storage
- Test restore from tape quarterly
- Track tape inventory; missing tapes are a data breach risk
- Consider encryption on all tapes (AES-256; key stored separately from tapes)

### Logical Air Gap (Cyber Vault)

**Definition**: An automated, software-defined isolation mechanism where backup data is stored in an environment with no persistent network connection to production infrastructure.

**Key differentiator from simple offsite cloud storage**: A logical air gap requires that the production environment cannot initiate connections to the vault — only a scheduled, time-limited connection window exists, controlled by the vault side.

**Implementation patterns:**

1. **SaaS-managed vault** (Cohesity FortKnox, Commvault Metallic):
   - Cohesity or Commvault-managed cloud infrastructure
   - Data replicated via controlled egress
   - Production cannot access vault directly; vendor manages isolation

2. **Cloud-native vault** (S3 + Object Lock + VPC isolation):
   - Dedicated AWS account or Azure subscription for backup
   - No persistent IAM credentials in production that can write to vault
   - Time-limited, MFA-protected access for backup windows

3. **On-premises isolated network** (air-gap VLAN):
   - Backup infrastructure on isolated VLAN
   - Firewall rules: production can push backups during windows; no persistent access
   - No production credentials stored in backup network

### Air Gap Assessment Checklist

- [ ] No persistent network path from production to backup/vault at rest
- [ ] Backup jobs use dedicated credentials not shared with production
- [ ] Credentials for backup infrastructure not stored in production identity systems (AD, etc.) that could be compromised
- [ ] Management plane for backup infrastructure is separate from production management
- [ ] Immutability on all air-gapped copies (air gap prevents deletion but immutability is defense-in-depth)
- [ ] Alert on any unexpected connection to air-gapped infrastructure

---

## Ransomware Recovery Workflow

### Pre-Incident: What to Have Ready

Before an incident occurs, establish:

1. **Recovery runbook**: Documented, tested procedure for ransomware recovery
2. **Communication plan**: Who to notify, in what order (legal, executives, regulators, customers)
3. **Isolation playbook**: How to network-isolate affected systems rapidly
4. **Clean build images**: Known-good OS and application images stored in air-gapped location
5. **Backup inventory**: Know where your backups are, how old they go, and what they contain
6. **Recovery team**: Identify who is responsible for each recovery step; establish out-of-band communication (ransomware may compromise email)

### Incident Response Steps

**Phase 1: Containment (Hours 0-2)**

1. Activate IR team and out-of-band communication
2. Isolate infected systems (network isolation, NOT shutdown if possible)
3. Preserve forensic evidence (memory dumps, logs)
4. Identify patient zero and infection vector
5. Determine scope: which systems are affected?
6. Engage legal counsel for regulatory notification obligations

**Phase 2: Assessment (Hours 2-24)**

7. Identify infection timeline (when did dwell begin vs. when did encryption trigger?)
8. Check backup platform anomaly detection for early warning signals
9. Identify the last known-clean restore point (before infection, not just before encryption)
10. Inventory recovery resources: restore capacity, clean infrastructure, bandwidth

**Phase 3: Recovery Planning (Hours 24-48)**

11. Prioritize systems for recovery (business criticality, dependencies)
12. Select restore points for each system
13. Scan restore points for malware before restoring
14. Provision isolated recovery environment
15. Establish success criteria for each system recovery

**Phase 4: Recovery Execution**

16. Restore systems in dependency order (infrastructure first, then applications)
17. Apply patches and harden each system before reconnecting
18. Verify application functionality at each layer
19. Monitor restored systems intensively for re-infection indicators

**Phase 5: Post-Incident**

20. Document root cause and timeline
21. Patch the initial access vector
22. Review and improve backup strategy based on gaps discovered
23. Conduct tabletop exercises to test updated runbook

### Identifying Clean Restore Points

This is the hardest part of ransomware recovery. Key factors:

- **Dwell time**: Ransomware typically waits 14-45 days after initial access before encrypting. Your "day of encryption" restore point likely still contains malware.
- **Lateral movement artifacts**: Even restoring a clean server may re-infect it if the Active Directory is compromised.
- **Backup anomaly detection**: Modern backup platforms detect file entropy changes and deletion spikes that indicate ransomware activity.

**Restore point selection process:**
1. Get the exact encryption timestamp from the infected system (event logs, file timestamps)
2. Use anomaly detection reports to identify suspicious activity before encryption (unusual file changes, deletions, entropy spikes)
3. Select a restore point from before the earliest suspicious activity, not just before encryption
4. If the Active Directory is suspected of compromise, restore AD from before the infection or rebuild

---

## RTO and RPO Frameworks

### Definitions

**Recovery Point Objective (RPO)**: The maximum amount of data loss, expressed in time, that is acceptable in a disaster scenario.
- RPO = 4 hours means: in the worst case, you might lose the last 4 hours of data changes
- RPO drives backup FREQUENCY: backup every ≤ RPO interval

**Recovery Time Objective (RTO)**: The maximum acceptable duration from disaster declaration to restored service.
- RTO = 2 hours means: service must be restored within 2 hours of declaring a disaster
- RTO drives recovery TECHNOLOGY: faster RTO requires more sophisticated (expensive) recovery methods

**Recovery Time Actual (RTA)**: What your recovery actually takes. Must be measured through testing.

**Recovery Time Test Objective (RTTO)**: The time budget for running a recovery test. If RTTO > RTO, you cannot test your recovery realistically.

### Technology Selection by RTO/RPO

| RPO | RTO | Recommended Technology |
|---|---|---|
| < 1 minute | < 15 minutes | Synchronous replication + instant failover |
| < 15 minutes | < 1 hour | Async replication + instant recovery (Veeam Instant Recovery, Rubrik Live Mount) |
| < 4 hours | < 4 hours | Disk backup with instant recovery from local repository |
| < 24 hours | < 8 hours | Daily disk backup + staged recovery |
| < 1 week | < 24 hours | Remote backup with WAN recovery |
| Days-weeks | Days | Tape/archive (disaster recovery only) |

### RPO/RTO by Data Tier

Define tiers based on business criticality:

| Tier | Description | Typical RPO | Typical RTO |
|---|---|---|---|
| Tier 0 | Mission-critical (payment systems, core ERP) | 0-15 min | 15-60 min |
| Tier 1 | Business-critical (email, CRM, HR) | 1-4 hours | 2-8 hours |
| Tier 2 | Important but not time-sensitive (reporting, dev) | 4-24 hours | 24-48 hours |
| Tier 3 | Non-critical (archives, test environments) | 24-48 hours | 72+ hours |

---

## Backup Encryption

### Encryption Architecture

**Data at rest:**
- Encrypt backup data stored on disk and tape
- Standard: AES-256 (approved by NIST FIPS 140-2/140-3)
- Key size: 256-bit minimum; 128-bit is technically secure but 256-bit is the current standard for sensitive data
- Hardware acceleration (AES-NI instructions) eliminates most CPU overhead

**Data in transit:**
- Encrypt all backup data streams with TLS 1.2 minimum (TLS 1.3 preferred)
- Validate certificates; do not accept self-signed certs without explicit pinning policy
- Consider encrypting at the backup application layer in addition to TLS for defense-in-depth

**Deduplication interaction:**
- Encryption before deduplication: better security; significantly reduces deduplication ratios
- Deduplication before encryption: better storage efficiency; consider data sensitivity
- Most enterprise backup products deduplicate then encrypt at the repository level

### Key Management

**Backup encryption key failure modes:**
1. **Key lost**: Backup data is permanently inaccessible (equivalent to deletion)
2. **Key compromised**: Backup data confidentiality is lost (historical data at risk)
3. **Key accessible from compromised system**: Ransomware can decrypt and re-encrypt or exfiltrate backups

**Key management best practices:**
- Use a dedicated, external KMS (not embedded in the backup server)
- Implement master key + data key hierarchy (key encryption keys separate from data keys)
- Key escrow: Store recovery keys offline, in physical secure storage (fireproof safe, bank vault)
- Key rotation: Annual rotation minimum; rotate immediately if compromise suspected
- Key access audit: Log and alert on all key access events
- Separation of duties: Backup admins ≠ key admins

**Platform-specific implementation:**
- Veeam: Software-based encryption with configurable password; recommend external KMS integration
- Rubrik: Built-in encryption; key management through Security Cloud
- Cohesity: DataLock + AES-256 at rest; external KMS support (KMIP)
- Commvault: MediaAgent-level encryption; KMIP-compatible KMS support

---

## Secure Restore Testing

### Why Testing Is Mandatory

NIST SP 800-34 and ISO 22301 both require periodic testing of backup and recovery procedures. Without testing:
- You don't know if backups are actually restoring successfully
- You don't know your actual RTA vs. your target RTO
- You can't comply with many regulatory frameworks (SOC 2, PCI-DSS, HIPAA)

### Testing Levels

**Level 1: Checksum validation (every backup)**
- Automated verification that backup data was written without errors
- Detects: write errors, storage corruption
- Does NOT detect: application-level inconsistency, encryption key issues

**Level 2: Mount/instant recovery test (weekly)**
- Mount the backup and verify it is readable
- Veeam: SureBackup or manual Instant Recovery to isolated lab
- Rubrik: Live Mount
- Cohesity: Instant mass restore to test network
- Detects: filesystem corruption, media failure, repository inaccessibility

**Level 3: Application-level test (monthly)**
- Restore and bring up application services; verify functionality
- Test database consistency checks, application startup, basic CRUD operations
- Detects: application-level corruption, dependency issues, configuration drift

**Level 4: Full DR test (quarterly to annually)**
- Full recovery simulation: restore all systems in dependency order, verify service within RTO
- Use cleanroom/isolated environment to avoid impacting production
- Measure actual RTA against RTO target; document and remediate gaps

### Cleanroom / Isolated Recovery Environment

A dedicated environment for recovery testing (and real incident recovery):

**Requirements:**
- Network-isolated from production (prevent re-infection during testing)
- Sufficient compute/storage for target workloads
- Access to backup data (local copy or secured remote access)
- DNS/AD configuration mirroring production (to test without modifying production)

**Implementation options:**
- On-premises VMware/Hyper-V isolated cluster
- Veeam Virtual Lab (isolated network bubble, auto-configures networking)
- Rubrik Orchestrated Recovery (define recovery plan, execute in cloud or on-prem)
- Commvault Cleanroom Recovery (automated provision in cloud for isolated testing)
- AWS/Azure isolated VPC/VNet for cloud-based cleanroom

### Recovery Verification Checklist

For each recovered system:
- [ ] System boots successfully
- [ ] OS is patched and no malware indicators present
- [ ] Application services start without errors
- [ ] Database consistency checks pass (DBCC CHECKDB, etc.)
- [ ] Application-level smoke tests pass (login, query, transaction)
- [ ] Data completeness check: verify expected record counts or file checksums
- [ ] Encryption keys are accessible and data decrypts successfully
- [ ] Recovery time measured and compared to RTO target
- [ ] Recovery documented in test report
