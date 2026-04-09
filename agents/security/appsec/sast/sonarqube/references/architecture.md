# SonarQube Architecture Reference

Deep reference for SonarQube internals: analysis pipeline, Compute Engine, quality gate evaluation, quality profiles, SonarCloud architecture, and the Clean Code taxonomy implementation.

---

## SonarQube Server Architecture

### Components

```
┌─────────────────────────────────────────────────────────┐
│                    SonarQube Server                      │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │  Web Server  │  │   Compute    │  │ Elasticsearch │ │
│  │  (HTTP API,  │  │   Engine     │  │   (Search,    │ │
│  │   UI, REST)  │  │  (Analysis   │  │   indexing)   │ │
│  │              │  │   reports)   │  │               │ │
│  └──────────────┘  └──────────────┘  └───────────────┘ │
│           │                │                │           │
│           └────────────────┴────────────────┘           │
│                            │                             │
│                     ┌──────────────┐                    │
│                     │   Database   │                    │
│                     │  (PostgreSQL)│                    │
│                     └──────────────┘                    │
└─────────────────────────────────────────────────────────┘
                            ↑
               SonarScanner (external, CI/CD)
```

### Web Server

- Serves the SonarQube UI (React SPA)
- Exposes the REST API (`/api/*`)
- Handles authentication and authorization
- Queues analysis reports to the Compute Engine via internal message queue
- Manages webhooks (notifies CI/CD of quality gate status)

**Key REST API endpoints:**
```
GET  /api/qualitygates/project_status?projectKey=...    # QG result
GET  /api/measures/component?component=...&metricKeys=...# Metrics
POST /api/issues/search                                  # Issue list
GET  /api/hotspots/search?projectKey=...                 # Hotspots
POST /api/issues/do_transition (confirm, reopen, etc.)   # Transitions
```

### Compute Engine

The Compute Engine processes analysis reports submitted by SonarScanner.

**Processing pipeline:**
1. SonarScanner submits a report (ZIP file) to the server via HTTP
2. Compute Engine picks up the task from the internal queue
3. Report is unpacked and processed:
   - Issues parsed and matched to source files
   - Coverage metrics computed
   - Duplication detection run (hash-based for cross-file)
   - Issue tracking: new issues vs. existing issues vs. resolved issues
4. Quality gate conditions evaluated against computed metrics
5. Results written to database and search index
6. Webhook fired with quality gate status

**Issue tracking (persistence between scans):**
SonarQube uses a heuristic algorithm to match issues across scans:
- Primary: exact match on file + rule + line + hash of surrounding lines
- Secondary: match on file + rule + hash only (line moved)
- Tertiary: match on file + rule only (large refactor)

This allows "Won't Fix" and "False Positive" markings to persist even when code moves.

### Elasticsearch

Used for fast search across issues, measures, and components. Not a primary data store — it is a search index over the PostgreSQL data.

In Data Center Edition, Elasticsearch runs as a cluster for high availability.

**Important:** Elasticsearch indices can be rebuilt from the database if corrupted (sonar-app-upgrade or manual reindex API call). Never use the Elasticsearch instance directly — always go through the SonarQube API.

### Database (PostgreSQL)

SonarQube requires PostgreSQL (10+ as of 2026.x versions). Oracle and MSSQL support was deprecated and removed.

**Key tables:**
- `projects` — Project and branch registry
- `issues` — All issues with status, severity, assignee, resolution
- `project_measures` — Metric snapshots per analysis
- `rules` — Active rules per quality profile
- `quality_gates` — Gate definitions and conditions
- `components` — File tree structure per analysis

---

## Analysis Pipeline (SonarScanner)

### What SonarScanner Does

SonarScanner is not a server component — it runs in CI/CD or developer workstations.

```
Source Code
    │
    ▼
┌────────────────────────────┐
│      SonarScanner          │
│                            │
│  1. Index source files     │
│  2. Apply sensors per lang │
│  3. Run analyzers:         │
│     - AST parsing          │
│     - Rule execution       │
│     - Taint analysis       │
│     - CPD (duplication)    │
│  4. Collect external data: │
│     - Coverage reports     │
│     - Test reports         │
│     - External issues      │
│  5. Build report ZIP       │
│  6. Upload to server       │
└────────────────────────────┘
    │
    ▼
Server (Compute Engine processes asynchronously)
```

### Language Sensors

Each language has one or more "sensors" that handle analysis:

- **Java:** Uses custom bytecode analysis engine. Requires compiled `.class` files (`sonar.java.binaries`). Without binaries, analysis is severely degraded.
- **JavaScript/TypeScript:** Uses a JavaScript analysis engine (V8-based). Runs Node.js internally.
- **Python:** AST-based analysis.
- **C/C++:** Requires compilation database (`compile_commands.json`) for accurate analysis.
- **C#/.NET:** Uses Roslyn analyzers. The .NET SonarScanner integrates with the build process.

### Taint Analysis Engine

For Enterprise Edition, taint analysis runs as part of the sensor phase:

1. **Source identification:** Framework-specific annotations and method signatures mark data sources (e.g., `@RequestParam`, `HttpServletRequest.getParameter()`)
2. **Propagation rules:** Taint flows through assignments, method calls (interprocedurally), string operations
3. **Sanitizer recognition:** Known sanitization methods break the taint chain. Custom sanitizers can be registered via Quality Profile rule parameters.
4. **Sink matching:** When tainted data reaches a dangerous sink, a Vulnerability is raised
5. **Cross-file analysis:** Full inter-procedural analysis across the entire project (not just within files)

---

## Quality Gate Evaluation Pipeline

### When Gates are Evaluated

Quality gates are evaluated by the Compute Engine after each analysis. The evaluation result is:
- Stored in the database
- Sent via webhook to CI/CD (if configured)
- Visible in the UI

### Gate Conditions and Metrics

Gates operate on **metrics** computed from the analysis. Key metrics:

| Metric Key | Description |
|---|---|
| `new_vulnerabilities` | Count of new Security Vulnerabilities |
| `new_bugs` | Count of new Reliability Bugs |
| `new_code_smells` | Count of new Maintainability Code Smells |
| `new_security_hotspots_reviewed` | % of new hotspots reviewed |
| `new_coverage` | Coverage % on new code |
| `new_duplicated_lines_density` | Duplication % on new code |
| `security_rating` | Overall security rating (A-E) |
| `reliability_rating` | Overall reliability rating (A-E) |
| `sqale_rating` | Overall maintainability rating (A-E) |

**Rating scale:**
- A: 0 issues
- B: At least 1 minor issue
- C: At least 1 major issue
- D: At least 1 critical issue
- E: At least 1 blocker issue

### Webhook Payload

When CI sets `sonar.qualitygate.wait=true`, the scanner polls the server until the Compute Engine task completes, then returns exit code 0 (pass) or 1 (fail) based on gate status.

Webhook JSON structure (for async notification):
```json
{
  "serverUrl": "https://sonarqube.example.com",
  "taskId": "AXxyz...",
  "status": "SUCCESS",
  "analysedAt": "2026-04-08T10:30:00+0000",
  "project": {
    "key": "my-project",
    "name": "My Project",
    "url": "https://sonarqube.example.com/dashboard?id=my-project"
  },
  "qualityGate": {
    "name": "Sonar way",
    "status": "ERROR",
    "conditions": [
      {
        "metric": "new_vulnerabilities",
        "operator": "GREATER_THAN",
        "errorThreshold": "0",
        "actualValue": "2",
        "status": "ERROR"
      }
    ]
  }
}
```

---

## Quality Profile Implementation

### Rule Storage

Rules are stored in the database with:
- Rule key (e.g., `java:S3649`)
- Default severity
- Parameters (key-value pairs)
- Tags (security standards: `owasp-a3`, `cwe-89`, etc.)
- Type (BUG, VULNERABILITY, CODE_SMELL, SECURITY_HOTSPOT)
- Status (READY, DEPRECATED, REMOVED)

### Profile Inheritance

```
Built-in: "Sonar way" (read-only, auto-updated)
    │
    └── Custom: "My Organization Java" (inherits, can override)
            │
            └── Custom: "My Team Java" (inherits, can override)
```

Changes to parent profiles propagate to children unless explicitly overridden.

### Custom Rules

Two mechanisms for custom rules:

**1. External rules (preferred for CI/CD):**
Use Semgrep or other analyzers to generate issues in the SonarQube "generic issue" format:
```json
{
  "issues": [{
    "engineId": "CustomAnalyzer",
    "ruleId": "NO_HARDCODED_CREDS",
    "severity": "CRITICAL",
    "type": "VULNERABILITY",
    "primaryLocation": {
      "message": "Do not hardcode credentials",
      "filePath": "src/main/java/Config.java",
      "textRange": {"startLine": 42, "endLine": 42}
    }
  }]
}
```
Import via: `sonar.externalIssuesReportPaths=issues.json`

**2. Custom rules via plugin API:**
Write a Java plugin implementing `RulesDefinition` and `JavaFileScanner`. Deploy as `.jar` to `$SONARQUBE_HOME/extensions/plugins/`. Requires server restart.

---

## SonarCloud Architecture

SonarCloud is a multi-tenant SaaS deployment of SonarQube hosted on AWS.

**Key architectural differences from self-managed:**

| Aspect | SonarQube Self-Managed | SonarCloud |
|---|---|---|
| Infrastructure | Customer managed | Sonar managed (AWS) |
| Updates | Customer controlled | Automatic (always latest) |
| ALM integration | Manual configuration | Native app installation |
| Org model | Projects under server | Organizations (mirrors VCS org) |
| Storage | Customer database | Sonar-managed, per-org |
| Elasticsearch | Customer managed | Sonar-managed cluster |
| Branch analysis | Developer Edition+ | Included |
| PR decoration | Developer Edition+ | Included |
| Pricing | License per instance | Per LOC analyzed (private) |

**SonarCloud organization model:**
- Organization → Projects → Branches
- Organization binds to GitHub/GitLab/Bitbucket/Azure DevOps org
- Members inherit from VCS org membership
- Admin permissions managed via SonarCloud org admin

**Automatic analysis (GitHub only):**
SonarCloud can analyze GitHub repositories without any CI/CD configuration using "Automatic Analysis." This uses GitHub Actions internally and covers Java, JavaScript, TypeScript, Python, C#, PHP, Ruby, Go, Kotlin, Scala, CSS, HTML.

Limitations of automatic analysis:
- Cannot configure custom scanner properties
- Coverage reports cannot be imported
- Use "CI-based analysis" to import coverage

---

## LTA (Long-Term Active) Release Model

As of 2024+, SonarQube moved from LTS (Long-Term Support) to LTA (Long-Term Active):

- **LTA release:** Maintained for 18 months with bug fixes and security patches. Recommended for organizations that cannot update frequently.
- **Current release (latest):** Latest features and fixes. Updated quarterly. Active development.
- **2026.x:** Current version series (major.minor.patch).

**Migration between versions:**
1. Back up database
2. Stop SonarQube
3. Replace `$SONARQUBE_HOME` with new version (keep `data/`, `conf/`, `logs/` directories)
4. Update `conf/sonar.properties` if needed
5. Start — Compute Engine auto-migrates DB schema
6. Verify all plugins are compatible (check plugin changelog)

**Plugin compatibility:** Each SonarQube version has a range of compatible plugin API versions. When upgrading, check each installed plugin for compatibility.

---

## Performance Tuning

### JVM Settings

```properties
# conf/sonar.properties
sonar.web.javaOpts=-Xmx2g -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.ce.javaOpts=-Xmx4g -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.search.javaOpts=-Xmx2g -Xms2g -XX:+HeapDumpOnOutOfMemoryError
```

Compute Engine memory depends on project size. For large Java projects (>1M LOC), increase CE heap to 6-8GB.

### Database Connection Pool

```properties
sonar.jdbc.maxActive=60     # Default 60; increase for high concurrency
sonar.jdbc.minIdle=10
```

### Elasticsearch Performance

For large instances (>100 projects, >10M lines):
- Mount Elasticsearch data on fast SSD storage
- Ensure `vm.max_map_count=524288` on Linux host
- In Data Center Edition, use dedicated Elasticsearch nodes

### Analysis Parallelism

Multiple projects can be analyzed simultaneously. The Compute Engine processes tasks one at a time per project (to maintain ordering) but handles different projects in parallel:

```properties
sonar.ce.workerCount=4  # Number of parallel CE workers (Enterprise+)
```
