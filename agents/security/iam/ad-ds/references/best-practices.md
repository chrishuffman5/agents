# AD DS Best Practices and Hardening

Operational guidance, security hardening, and best practices for Active Directory Domain Services.

---

## Tiered Administration Model

The tiered model prevents credential theft from propagating across control planes. It is the single most impactful AD hardening measure.

### Tier Definitions

| Tier | Controls | Assets | Admin Accounts |
|---|---|---|---|
| **Tier 0** | Forest and domain identity | Domain controllers, AD DS, AD CS, AD FS, Entra Connect, PKI, PAM | T0 admin accounts (separate from daily-use) |
| **Tier 1** | Servers and enterprise applications | Member servers, SQL, Exchange, SCCM, file servers | T1 admin accounts |
| **Tier 2** | Workstations and end-user devices | Desktops, laptops, printers, mobile devices | Helpdesk, T2 admin accounts |

### Tier Isolation Rules

1. **Tier 0 credentials NEVER touch Tier 1 or Tier 2 systems** -- No interactive logon, no RDP, no PSRemoting to member servers or workstations
2. **Tier 1 credentials NEVER touch Tier 2 systems** -- Server admins do not log into workstations
3. **Lower tiers NEVER have admin access to higher tiers** -- Workstation admins cannot manage servers or DCs
4. **Enforce via Authentication Policies and Silos** (2012 R2+) or GPO logon restrictions

### Implementation Steps

```powershell
# Create Authentication Policy (Tier 0 restriction)
New-ADAuthenticationPolicy -Name "Tier0-Policy" `
    -UserAllowedToAuthenticateFrom "O:SYG:SYD:(XA;OICI;CR;;;WD;(@USER.ad://ext/AuthenticationSilo == `"Tier0-Silo`"))" `
    -Enforce

# Create Authentication Silo
New-ADAuthenticationPolicySilo -Name "Tier0-Silo" `
    -UserAuthenticationPolicy "Tier0-Policy" `
    -ComputerAuthenticationPolicy "Tier0-Policy" `
    -ServiceAuthenticationPolicy "Tier0-Policy" `
    -Enforce

# Assign silo to Tier 0 accounts and DCs
Set-ADAccountAuthenticationPolicySilo -Identity "T0-Admin" -AuthenticationPolicySilo "Tier0-Silo"
Grant-ADAuthenticationPolicySiloAccess -Identity "Tier0-Silo" -Account "T0-Admin"
```

---

## Privileged Access Workstations (PAWs)

Dedicated workstations for Tier 0 administration:

### PAW Configuration

- **Clean OS installation** -- Not domain-joined (or in a separate hardened OU with strict GPO)
- **No internet access** -- Block all outbound except to DCs and management tools
- **No email or browsing** -- Separate machine for daily work
- **Application whitelisting** -- Windows Defender Application Control (WDAC) or AppLocker
- **Credential Guard** -- Enabled (virtualizes LSA)
- **Secure Boot + UEFI** -- Required for Credential Guard
- **BitLocker** -- Full disk encryption with TPM + PIN
- **USB restrictions** -- Block removable storage via GPO
- **Monitoring** -- Full audit logging, forwarded to SIEM

### Jump Server Alternative

If dedicated PAWs are not feasible, use hardened jump servers:
- Hardened Windows Server in Tier 0 OU
- RDP only from specific source IPs
- Restricted Admin mode or Remote Credential Guard for RDP
- No internet, no email, application whitelisting
- Session recording for audit

---

## LAPS (Local Administrator Password Solution)

### Windows LAPS (Built-in, Server 2019+ / Windows 10 21H2+)

```powershell
# Configure Windows LAPS via GPO or Intune
# Computer Configuration > Administrative Templates > System > LAPS

# Key settings:
# - Password complexity (uppercase, lowercase, digits, special)
# - Password length (14+ characters recommended, max 64)
# - Password age (30 days recommended)
# - Password storage: AD or Azure AD (Entra ID)
# - Encryption: enabled (requires 2016+ domain functional level)
# - Post-authentication actions: reset password + logoff

# Retrieve password
Get-LapsADPassword -Identity "WORKSTATION01" -AsPlainText

# View password expiration
Get-LapsADPassword -Identity "WORKSTATION01" | Select-Object Account, PasswordUpdateTime, ExpirationTimestamp
```

### Legacy Microsoft LAPS (Add-on)

- Schema extension required (`Update-AdmPwdADSchema`)
- GPO-based configuration
- Passwords stored in `ms-Mcs-AdmPwd` attribute (cleartext in AD, ACL-protected)
- No encryption (unlike Windows LAPS)
- Migrate to Windows LAPS when possible

---

## Group Managed Service Accounts (gMSA)

gMSAs provide automatic password management for service accounts:

```powershell
# Create KDS root key (one-time, forest-wide)
# Production (wait 10 hours for replication):
Add-KdsRootKey -EffectiveImmediately  # Actually waits 10 hours

# Lab only (immediate, skip replication wait):
Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))

# Create gMSA
New-ADServiceAccount -Name "gMSA-SQLSvc" `
    -DNSHostName "gMSA-SQLSvc.example.com" `
    -PrincipalsAllowedToRetrieveManagedPassword "SQLServers-Group" `
    -KerberosEncryptionType AES128,AES256

# Install on target server
Install-ADServiceAccount -Identity "gMSA-SQLSvc"

# Test
Test-ADServiceAccount -Identity "gMSA-SQLSvc"

# Use in service: set service account to "DOMAIN\gMSA-SQLSvc$" with blank password
```

**gMSA benefits:**
- 240-character random password, auto-rotated every 30 days
- No human knows the password (cannot be phished or guessed)
- Kerberoasting is impractical (password too complex)
- Works with SQL Server, IIS, scheduled tasks, Windows services

---

## GPO Security Baselines

### Microsoft Security Baselines

Apply Microsoft Security Compliance Toolkit baselines as a starting point:

**Key GPO settings for DCs:**

| Setting | Recommended Value | GPO Path |
|---|---|---|
| Minimum password length | 14+ characters | Computer > Windows Settings > Security > Account Policies |
| Account lockout threshold | 10 invalid attempts | Computer > Windows Settings > Security > Account Policies |
| Account lockout duration | 15 minutes | Computer > Windows Settings > Security > Account Policies |
| Audit policy | Success + Failure for all categories | Computer > Windows Settings > Security > Advanced Audit Policy |
| NTLM restriction | Audit first, then deny | Computer > Windows Settings > Security > Local Policies > Security Options |
| LDAP signing | Require signing | Computer > Windows Settings > Security > Local Policies > Security Options |
| LDAP channel binding | Always | Registry: `LdapEnforceChannelBinding = 2` |
| SMB signing | Required | Computer > Windows Settings > Security > Local Policies > Security Options |
| LAN Manager auth level | Send NTLMv2 only, refuse LM & NTLM | Computer > Windows Settings > Security > Local Policies > Security Options |

### Protected Users Group

Add ALL privileged accounts to the Protected Users group:

**Protections applied:**
- NTLM authentication is blocked
- DES and RC4 encryption types are not used
- Kerberos delegation (unconstrained and constrained) is blocked
- Kerberos TGT lifetime reduced to 4 hours (non-renewable)
- Credential caching is disabled (no offline logon)

**Requirements:** Domain functional level 2012 R2+, DCs running 2012 R2+

### Fine-Grained Password Policies

```powershell
# Create FGPP for admins (stricter than domain default)
New-ADFineGrainedPasswordPolicy -Name "Admin-Password-Policy" `
    -Precedence 10 `
    -MinPasswordLength 16 `
    -PasswordHistoryCount 24 `
    -ComplexityEnabled $true `
    -MaxPasswordAge "90.00:00:00" `
    -MinPasswordAge "1.00:00:00" `
    -LockoutThreshold 5 `
    -LockoutDuration "00:30:00" `
    -LockoutObservationWindow "00:30:00" `
    -ReversibleEncryptionEnabled $false

# Apply to admin group
Add-ADFineGrainedPasswordPolicySubject -Identity "Admin-Password-Policy" -Subjects "Domain Admins"
```

---

## Monitoring and Alerting

### Critical Events to Alert On

| Event | Alert Priority | Description |
|---|---|---|
| 4728/4732/4756 + Domain Admins | Critical | Member added to privileged group |
| 4780 | High | AdminSDHolder ACL propagated (unexpected = attack indicator) |
| 4720 + Privileged OU | Critical | Account created in admin OU |
| 4768 with RC4 encryption | Medium | Potential AS-REP roasting |
| 4769 with RC4 encryption | Medium | Potential Kerberoasting |
| 8222 (DS Access) | High | Shadow credentials (Key Trust) modification |
| Directory Service 1644 | Medium | Expensive LDAP query (performance issue or reconnaissance) |
| replication failure > 1 hour | High | Replication broken |
| FSMO role seizure | Critical | Unplanned role seizure |
| GPO modification | Medium | Track all GPO changes |

### Honeypot Accounts

Create decoy accounts to detect reconnaissance:
- Create accounts that look like service accounts or admin accounts
- Set obviously tempting names (e.g., `svc-backup-admin`, `sql-sa`)
- Monitor Event ID 4625 (failed logon) and 4624 (successful logon) for these accounts
- No legitimate use should ever access these accounts

---

## DC Placement and Sizing

### DC Placement Guidelines

| Scenario | Recommendation |
|---|---|
| Main office (>500 users) | 2+ writable DCs, both GC-enabled |
| Branch office (50-500 users, secure) | 1-2 writable DCs |
| Branch office (50-500 users, insecure) | 1-2 RODCs |
| Branch office (<50 users) | RODC or rely on WAN to hub DC |
| Cloud (Azure/AWS) | DC VMs in cloud for cloud workloads, or use Entra DS |
| DMZ | Never place a writable DC. RODC if required. Prefer LDAPS proxy. |

### DC Sizing

| Component | Recommendation |
|---|---|
| CPU | 4+ cores (8+ for large environments or AD CS co-located) |
| RAM | 8 GB minimum. 16+ GB recommended. ESE cache = RAM - 1 GB (auto-tuned) |
| Disk (NTDS.dit) | SSD strongly recommended. Separate volume from OS. |
| Disk (Logs) | Separate volume from NTDS.dit for write performance |
| Disk (SYSVOL) | Can share OS volume for small environments |
| Network | 1 Gbps minimum. Dual NIC for redundancy (not teaming on DCs) |

---

## Backup and Recovery Strategy

### Backup Requirements

- Backup System State on at least 2 DCs per domain
- Frequency: daily minimum
- Retention: at least 2 backup cycles within tombstone lifetime
- Test restore quarterly in isolated lab
- Document forest recovery procedure

### AD Recycle Bin

```powershell
# Enable AD Recycle Bin (irreversible, requires Forest Functional Level 2008 R2+)
Enable-ADOptionalFeature -Identity "Recycle Bin Feature" `
    -Scope ForestOrConfigurationSet `
    -Target "example.com"

# Recover deleted object
Get-ADObject -Filter {displayName -eq "John Doe" -and isDeleted -eq $true} `
    -IncludeDeletedObjects | Restore-ADObject

# Recover deleted OU and all children
Get-ADObject -Filter {isDeleted -eq $true -and lastKnownParent -eq "OU=Sales,DC=example,DC=com"} `
    -IncludeDeletedObjects | Restore-ADObject
```

**Deleted object lifetime:** Default 180 days (same as tombstone lifetime). After this, objects are permanently removed and cannot be recovered from the Recycle Bin.

---

## NTLM Reduction

NTLM is a legacy authentication protocol that should be minimized:

### NTLM Audit Phase

```powershell
# Enable NTLM auditing via GPO
# Computer Configuration > Windows Settings > Security > Local Policies > Security Options

# 1. "Network security: Restrict NTLM: Audit incoming NTLM traffic" = Enable auditing for all accounts
# 2. "Network security: Restrict NTLM: Audit NTLM authentication in this domain" = Enable all

# Monitor events:
# Event 8001 (Operational log) -- NTLM authentication in domain
# Event 8002 (Operational log) -- NTLM pass-through from server
# Event 8003 (Operational log) -- NTLM block would have occurred

# Identify NTLM-dependent applications from audit events, then remediate
```

### NTLM Reduction Steps

1. **Audit** -- Enable NTLM auditing, collect data for 30+ days
2. **Identify** -- List applications/services using NTLM
3. **Remediate** -- Fix applications (add SPNs, update configs for Kerberos)
4. **Exception** -- Add remaining NTLM-dependent systems to exception list
5. **Block** -- Enable NTLM blocking with exception list
6. **Monitor** -- Continue monitoring for new NTLM usage
