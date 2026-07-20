# Microsoft Sentinel Best Practices Reference

## KQL Optimization

### Query Performance Hierarchy

From fastest to slowest:

1. **Time-filtered queries on native tables** -- `SecurityEvent | where TimeGenerated > ago(1h)` uses time partitioning
2. **Indexed string operators** -- `has`, `has_any`, `has_all`, `!has` are indexed; `contains`, `matches regex` are not
3. **Summarize with early filtering** -- Filter with `where` before `summarize` to reduce data volume
4. **Join with filtered tables** -- Apply `where` before `join`, not after
5. **Cross-workspace queries** -- Add network latency; minimize cross-workspace calls
6. **ASIM unifying parsers** -- Union of multiple parsers; slower than direct table queries

### KQL Anti-Patterns

**Anti-pattern 1: `contains` instead of `has`**
```kql
// Slow: substring scan (not indexed)
SecurityEvent | where CommandLine contains "powershell"

// Fast: word-boundary match (indexed)
SecurityEvent | where CommandLine has "powershell"
```

**Anti-pattern 2: Late filtering**
```kql
// Slow: joins before filtering
SecurityEvent
| join kind=inner (SigninLogs) on $left.TargetAccount == $right.UserPrincipalName
| where EventID == 4625

// Fast: filter before join
SecurityEvent
| where EventID == 4625
| join kind=inner (SigninLogs | where ResultType != "0") on $left.TargetAccount == $right.UserPrincipalName
```

**Anti-pattern 3: Unnecessary columns through pipeline**
```kql
// Slow: carries all columns
SecurityEvent | where EventID == 4688 | summarize count() by Account

// Fast: project early
SecurityEvent | where EventID == 4688 | project Account | summarize count() by Account
```

**Anti-pattern 4: Repeated subqueries**
```kql
// Slow: same subquery executed twice
let suspicious_ips = SigninLogs | where ResultType != "0" | distinct IPAddress;
SecurityEvent | where EventID == 4625 | where IpAddress in (suspicious_ips)
| union (
    CommonSecurityLog | where DeviceAction == "Deny" | where SourceIP in (suspicious_ips)
)

// Fast: materialize the subquery
let suspicious_ips = materialize(SigninLogs | where ResultType != "0" | distinct IPAddress);
SecurityEvent | where EventID == 4625 | where IpAddress in (suspicious_ips)
| union (
    CommonSecurityLog | where DeviceAction == "Deny" | where SourceIP in (suspicious_ips)
)
```

### KQL Patterns for Detection

**Pattern 1: Threshold-based detection**
```kql
let threshold = 10;
let timeframe = 1h;
SigninLogs
| where TimeGenerated > ago(timeframe)
| where ResultType != "0"
| summarize FailureCount = count() by UserPrincipalName, IPAddress, bin(TimeGenerated, 5m)
| where FailureCount > threshold
```

**Pattern 2: Rare event detection**
```kql
// Find processes that are rare in the environment
let known_processes = DeviceProcessEvents
| where TimeGenerated between (ago(30d) .. ago(1d))
| distinct FileName;
DeviceProcessEvents
| where TimeGenerated > ago(1d)
| where FileName !in (known_processes)
| summarize FirstSeen = min(TimeGenerated), Count = count() by FileName, DeviceName
```

**Pattern 3: Sequence detection (time-ordered)**
```kql
let login_failures = SigninLogs | where ResultType != "0" | project FailureTime = TimeGenerated, UserPrincipalName, IPAddress;
let login_success = SigninLogs | where ResultType == "0" | project SuccessTime = TimeGenerated, UserPrincipalName, IPAddress;
login_failures
| join kind=inner (login_success) on UserPrincipalName, IPAddress
| where SuccessTime between (FailureTime .. FailureTime + 10m)
| summarize FailuresBeforeSuccess = count() by UserPrincipalName, IPAddress, SuccessTime
| where FailuresBeforeSuccess > 5
```

**Pattern 4: Anomaly detection with baseline**
```kql
// Detect data exfiltration: user downloading significantly more than usual
let baseline = OfficeActivity
| where TimeGenerated between (ago(30d) .. ago(1d))
| where Operation == "FileDownloaded"
| summarize AvgDailyDownloads = count() / 30 by UserId;
OfficeActivity
| where TimeGenerated > ago(1d)
| where Operation == "FileDownloaded"
| summarize TodayDownloads = count() by UserId
| join kind=inner (baseline) on UserId
| where TodayDownloads > AvgDailyDownloads * 5
| extend AnomalyRatio = round(TodayDownloads / AvgDailyDownloads, 1)
```

## Analytics Rule Tuning

### Rule Configuration Best Practices

1. **Query frequency vs. lookup period:**
   - Frequency: how often the rule runs (e.g., every 5 minutes)
   - Lookup: how far back the query looks (e.g., 10 minutes)
   - **Always overlap:** lookup > frequency to prevent gaps. Typical: 2x frequency.

2. **Entity mapping:**
   - Always map Account, Host, IP entities when available
   - Entity mapping enables investigation graph, UEBA correlation, and incident grouping
   - Use entity identifiers (not display names) for accurate correlation

3. **Alert grouping:**
   - Group alerts into incidents by entity (e.g., same user, same host)
   - Set grouping window (e.g., 24 hours) to combine related alerts
   - Prevents incident sprawl for persistent threats

4. **Suppression:**
   - Suppress duplicate alerts for the same entity within a time window
   - Configured per-rule; use for noisy but necessary detections

### Tuning Workflow

```
1. Enable rule in test mode (create alerts, not incidents)
        |
2. Run for 1-2 weeks, collect alert data
        |
3. Analyze false positives:
   - Identify patterns (specific users, IPs, applications)
   - Create exclusion lists (Watchlists)
   - Adjust thresholds
        |
4. Update rule KQL with exceptions:
   | where UserPrincipalName !in (_GetWatchlist('TrustedAdmins'))
        |
5. Enable incident creation
        |
6. Review monthly for rule decay
```

### Watchlists for Exception Management

```kql
// Create a watchlist: Settings > Watchlists > New
// Name: TrustedAdmins
// Columns: UserPrincipalName, Justification, ExpiryDate

// Use in analytics rules:
let trusted_admins = _GetWatchlist('TrustedAdmins') | project UserPrincipalName;
SigninLogs
| where ResultType != "0"
| where UserPrincipalName !in (trusted_admins)
| summarize count() by UserPrincipalName, IPAddress
```

## UEBA Best Practices

### Configuration

1. **Enable UEBA** -- Settings > Entity behavior > Enable UEBA
2. **Select data sources** -- Azure AD sign-in logs, Windows Security events, Azure Activity logs
3. **Sync period** -- Initial sync takes 24-48 hours to build baselines
4. **Entity identifiers** -- Configure how Sentinel identifies entities across data sources

### Using UEBA in Detection

```kql
// Combine UEBA anomaly scores with analytics rules
let high_risk_users = BehaviorAnalytics
| where TimeGenerated > ago(7d)
| where InvestigationPriority > 5
| distinct UserPrincipalName;
SigninLogs
| where UserPrincipalName in (high_risk_users)
| where ResultType == "0"
| where RiskState == "none"  // Successful login not flagged by Entra ID
| project TimeGenerated, UserPrincipalName, IPAddress, AppDisplayName
```

## Cost Management

### Ingestion Cost Analysis

```kql
// Daily ingestion by table (last 30 days)
Usage
| where TimeGenerated > ago(30d)
| where IsBillable == true
| summarize GB = sum(Quantity) / 1000 by DataType, bin(TimeGenerated, 1d)
| summarize AvgDailyGB = avg(GB), TotalGB = sum(GB) by DataType
| sort by AvgDailyGB desc
```

```kql
// Identify candidates for basic logs tier
Usage
| where TimeGenerated > ago(30d)
| where IsBillable == true
| summarize DailyGB = sum(Quantity) / 1000 / 30 by DataType
| join kind=leftouter (
    union withsource=TableName *
    | where TimeGenerated > ago(30d)
    | summarize QueryCount = count() by TableName = column_ifexists("$table", "unknown")
) on $left.DataType == $right.TableName
| extend QueryPerGB = QueryCount / DailyGB
| where DailyGB > 1 and QueryPerGB < 10  // High volume, rarely queried
| sort by DailyGB desc
```

### Commitment Tier Selection

| Tier | Daily Commitment | Discount vs. Pay-As-You-Go |
|---|---|---|
| Pay-As-You-Go | None | Baseline |
| 100 GB/day | 100 GB | ~50% |
| 200 GB/day | 200 GB | ~52% |
| 300 GB/day | 300 GB | ~53% |
| 400 GB/day | 400 GB | ~54% |
| 500 GB/day | 500 GB | ~55% |
| 1,000 GB/day | 1,000 GB | ~58% |
| 2,000 GB/day | 2,000 GB | ~60% |
| 5,000 GB/day | 5,000 GB | ~63% |

**Selection rule:** Choose the tier closest to your consistent daily ingestion without overage. Overage is billed at pay-as-you-go rates.

### Data Collection Rule Optimization

Reduce ingestion at the source with DCR transforms:

```kql
// Example: Keep only security-relevant Windows events
source
| where EventID in (
    1, 3, 5, 7, 8, 10, 11, 12, 13, 15, 17, 22, 23, 25, 26,  // Sysmon
    4624, 4625, 4648, 4672, 4688, 4698, 4720, 4726, 4728, 4732,  // Security
    4756, 4768, 4769, 4776, 5140, 5145  // Security continued
)
```

## Content Hub Strategy

### Solution Selection

1. **Start with Microsoft-published solutions** -- Highest quality, regularly updated
2. **Evaluate community solutions** -- Check last update date, GitHub issues, review count
3. **Clone before customizing** -- Never edit content hub-installed rules directly (updates overwrite)
4. **Version control** -- Export customized rules to Git via Sentinel Repositories

### Content Hub Categories

| Category | Examples | Priority |
|---|---|---|
| **Identity** | Azure AD, Entra ID Protection | Critical -- enable first |
| **Endpoint** | Microsoft Defender for Endpoint, Sysmon | Critical |
| **Network** | Palo Alto, Fortinet, Cisco | High |
| **Cloud** | AWS, GCP, Azure Activity | High |
| **Threat Intelligence** | MISP, TI feeds | Medium |
| **Compliance** | SOC 2, PCI DSS workbooks | As needed |

## Operational Monitoring

### Sentinel Health Monitoring

```kql
// Data connector health
SentinelHealth
| where TimeGenerated > ago(24h)
| where SentinelResourceType == "Data connector"
| where Status != "Success"
| summarize count() by SentinelResourceName, Status, Description
| sort by count_ desc
```

```kql
// Analytics rule health
SentinelHealth
| where TimeGenerated > ago(24h)
| where SentinelResourceType == "Analytics rule"
| where Status != "Success"
| summarize FailureCount = count() by SentinelResourceName, Description
| sort by FailureCount desc
```

```kql
// Ingestion latency monitoring
union withsource=TableName *
| where TimeGenerated > ago(1h)
| extend IngestionLatency = ingestion_time() - TimeGenerated
| summarize 
    P50 = percentile(IngestionLatency, 50),
    P95 = percentile(IngestionLatency, 95),
    P99 = percentile(IngestionLatency, 99)
    by TableName, bin(TimeGenerated, 5m)
| where P95 > 5m
```
