# Tenable Architecture Reference

## Nessus Scanner Architecture

### Scanner Components

```
Tenable.io (Cloud Management)
        |
        | HTTPS/443 (outbound from scanner)
        |
+-------+----------+
|  Nessus Scanner  |
|                  |
|  nessusd daemon  |  <-- Core scanning engine
|  Plugin Store    |  <-- /opt/nessus/lib/nessus/plugins
|  Results Store   |  <-- /opt/nessus/var/nessus/
|  Web UI (8834)   |  <-- Local management interface
+------------------+
        |
        | Scan traffic (various protocols)
        |
   [Target hosts]
```

**Key processes:**
- `nessusd` -- Main Nessus daemon, handles scanning and plugin execution
- Nessus web server -- HTTPS UI on port 8834
- Plugin updates -- Fetched from plugins.nessus.org every 24 hours

**Storage paths:**
- Plugins: `/opt/nessus/lib/nessus/plugins/` (Linux) or `C:\ProgramData\Tenable\Nessus\nessus\plugins\` (Windows)
- Reports: `/opt/nessus/var/nessus/` 
- Config: `/opt/nessus/etc/nessus/`
- Logs: `/opt/nessus/var/nessus/logs/`

### Scanner Types in Tenable Ecosystem

| Scanner Type | Deployment | Use Case |
|---|---|---|
| **Nessus Scanner** (standalone) | VM, physical, cloud | Primary network scanner |
| **Nessus Manager** (deprecated) | On-premises | Was multi-user management; replaced by SC |
| **Tenable Security Center Scanner** | Linked to TSC | Managed scanner for enterprise on-prem |
| **Nessus Agent** | Endpoint agent | Remote/cloud endpoints, no network scan |
| **Cloud Scanners** (Tenable.io) | Tenable-hosted | External/DMZ scanning from Tenable cloud |
| **Container Security Scanner** | CI/CD pipeline | Docker/OCI image scanning |

### Linked Scanner Architecture (Tenable.io)

```
Tenable.io Cloud Platform
    |
    |-- Tenable-managed cloud scanners (US-East, US-West, EU, APAC)
    |-- Linked scanners (customer-deployed, report to Tenable.io)
         |-- On-prem Nessus scanners
         |-- Cloud VM scanners (EC2, Azure VM, GCP)
         |-- Agent-linked groups
```

**Linked scanner connectivity:**
- Scanner initiates outbound connection to Tenable.io (cloud.tenable.com:443)
- No inbound ports required on scanner
- Scan jobs pushed from Tenable.io, results uploaded back
- Scanner behind firewall/NAT is fully supported

### Tenable Security Center Architecture (On-Premises)

```
+------------------------------+
|  Tenable Security Center     |
|  (Management Server)         |
|  - Apache Tomcat web UI      |
|  - PostgreSQL database       |
|  - Feed management           |
|  - Report engine             |
+----------+-------------------+
           |
   +-------+-------+
   |               |
+--+------+   +----+----+
| Nessus  |   | Nessus  |
| Scanner |   | Scanner |
| Site A  |   | Site B  |
+---------+   +---------+
           |
    +------+------+
    | Nessus      |
    | Agents      |
    | (thousands) |
    +-------------+
```

**TSC components:**
- Web application: Port 443 (HTTPS)
- Scanner communication: Port 8834 (HTTPS, to/from scanners)
- Database: PostgreSQL (embedded)
- Feed updates: Pulled from Tenable update servers

**TSC repositories:** 
- Data containers that hold scan results
- Separate repositories for different asset groups, BUs, or compliance scopes
- Repository types: IPv4, IPv6, Agent, Universal

## Nessus Agent Architecture

### Agent Components

```
Endpoint (Windows/Linux/macOS)
+------------------------+
| Nessus Agent Service   |
| - nessusagent daemon   |
| - Local plugin store   |
| - Local results store  |
| - Scan executor        |
+----------+-------------+
           |
           | HTTPS/443 (outbound)
           |
+----------+-------------+
| Tenable.io or TSC       |
| - Agent management      |
| - Policy distribution   |
| - Results collection    |
+------------------------+
```

**Agent scan execution:**
- Scan triggered by policy schedule or on-demand from management platform
- Agent runs plugins locally against the host it's installed on
- Results uploaded to management platform on completion
- No network traffic to other hosts -- purely local assessment

**Agent linking:**
- Agents link using a linking key (generated in Tenable.io/TSC)
- Link command: `nessuscli agent link --key=KEY --host=cloud.tenable.com --port=443`
- Agent identified by UUID and hostname

**Plugin distribution to agents:**
- Differential plugin updates pushed from management platform
- Agent downloads only changed/new plugins (not full plugin set)
- Updates occur on agent's schedule (default: check-in every 24h)

## Plugin Families Reference

| Plugin Family | Description | Example Plugins |
|---|---|---|
| **Windows** | Windows OS vulnerabilities | MS patch detection, Windows services |
| **Windows: Microsoft Bulletins** | Microsoft Security Bulletins | CVE detection for Windows patches |
| **Red Hat Local Security Checks** | RHEL/CentOS/Fedora | yum/rpm package CVE detection |
| **Ubuntu Local Security Notices** | Ubuntu/Debian | apt package CVE detection |
| **Amazon Linux** | Amazon Linux 1/2/2023 | AWS-specific Linux packages |
| **Web Servers** | Web server vulnerabilities | Apache, Nginx, IIS, Tomcat |
| **Databases** | Database vulnerabilities | MSSQL, Oracle, MySQL, PostgreSQL, MongoDB |
| **Firewalls** | Network device vulns | Cisco IOS, Juniper, Palo Alto, Fortinet |
| **Network Infrastructure** | Routers, switches | Network device plugins |
| **VMware** | VMware products | ESXi, vCenter, VMware Workstation |
| **Policy Compliance** | Compliance audit plugins | CIS, DISA STIG, PCI, custom .audit |
| **Port Scanners** | Network discovery | TCP SYN, UDP, service detection |
| **Service Detection** | Service fingerprinting | Banner grabs, protocol identification |
| **DNS** | DNS vulnerabilities | Zone transfer, cache poisoning |
| **SMTP** | Email server vulns | Sendmail, Postfix, Exchange |
| **SSL/TLS** | Certificate and crypto | Expired certs, weak ciphers, Heartbleed |
| **Web Application Abuses** | Web app vulns | XSS, SQLi, CSRF (requires WAS module) |
| **Backdoors** | Malware and backdoors | Known trojan ports, backdoor services |
| **Gain a shell remotely** | RCE vulnerabilities | Remote code execution plugins |
| **Misc.** | Miscellaneous | Fingerprinting, informational |

**Safe vs. unsafe plugins:**
- Safe plugins: Do not cause denial of service or data modification
- Unsafe plugins: Can crash services, modify data, or trigger DoS
- Default: "Safe checks" enabled -- unsafe plugins disabled
- Enable unsafe plugins only in isolated test environments

## Plugin Update Mechanism

**Update frequency:** Tenable releases plugin updates multiple times daily.

**Update process:**
1. `nessusd` checks for updates at configured intervals
2. Downloads plugin diff packages from `plugins.nessus.org`
3. Updates compiled plugin cache
4. New plugins available immediately for new scans
5. Live Results applies new plugins to existing scan data retroactively (Tenable.io)

**Feed types:**
- **Nessus Professional Feed** -- Full plugin library, 200K+ plugins
- **Nessus Home Feed** -- Deprecated; was limited free version
- **Nessus Manager Feed** -- Full library, enterprise management features

**Offline/air-gapped updates:**
- Download plugin packages from Tenable Support Portal
- Install via: `nessuscli update /path/to/all-2.0.tar.gz`
- Tenable Security Center supports offline plugin bundles

## Cloud Scanning Architecture (Tenable.io)

### Cloud Scanner Regions

Tenable-hosted cloud scanners for external/DMZ scanning:

| Region | Scanner Names |
|---|---|
| US East | US East 1, 2, 3 |
| US West | US West 1, 2 |
| EU | EU Central, EU West |
| Asia Pacific | AP Southeast, AP Northeast |
| Canada | CA Central |

**When to use cloud scanners:**
- External attack surface scanning (scan from internet perspective)
- DMZ/public-facing asset scanning
- Eliminates need to deploy a scanner in the DMZ

**When to use linked scanners:**
- Internal network scanning (private RFC1918 ranges)
- Air-gapped or segmented networks
- High scan volume (dedicated scanner capacity)

### Tenable.io Data Flow

```
Asset Discovery / Scan Trigger
    |
    v
Scan Job Created in Tenable.io
    |
    v
Job Dispatched to Scanner (cloud or linked)
    |
    v
Scanner Executes Plugins Against Targets
    |
    v
Raw Results Uploaded to Tenable.io
    |
    v
Results Processed: Dedup, VPR scoring, ACR calculation
    |
    v
Findings Available in Workbench / API
    |
    v
Live Results Updates (daily, for assets with credential scan history)
```

## Tenable One Architecture

Tenable One is the exposure management layer above all Tenable products.

**Data sources unified in Tenable One:**
- Tenable VM (Nessus/Tenable.io vulnerability findings)
- Tenable Web App Scanning (DAST results)
- Tenable Identity Exposure (Active Directory risk data)
- Tenable ASM (external attack surface discoveries)
- Tenable OT Security (operational technology assets)
- Tenable Cloud Security (cloud asset posture data)
- Third-party connectors (CrowdStrike, ServiceNow, etc.)

**Exposure Graph:**
- Graph database mapping relationships between assets, vulnerabilities, identities, configurations
- Attack path analysis traverses graph to find chained risk paths
- "What is the blast radius if this asset is compromised?"

**Lumin Exposure View:**
- Business context layer: assign assets to business units, tag by criticality
- AES (Asset Exposure Score): ACR × aggregated VPR scores
- Benchmark: Compare AES vs. industry peer group
- Trend tracking: Is exposure increasing or decreasing over time?
