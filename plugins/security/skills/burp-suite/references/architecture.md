# Burp Suite Architecture Reference

Deep reference for Burp Suite internals: proxy engine, scanner architecture, Intruder mechanics, extension API, Enterprise server, Collaborator, and BCheck runtime.

---

## Proxy Engine

### MitM Architecture

Burp Proxy operates as a man-in-the-middle between browser and server:

```
Browser → [Burp Proxy Listener :8080] → [Burp Engine] → [Upstream Target]
                                              ↕
                                    [Intercept Queue]
                                    [HTTP History]
                                    [WebSocket History]
```

**TLS interception:**
1. Browser connects to Burp proxy (HTTP CONNECT or direct HTTPS)
2. Burp presents a dynamically generated certificate for the target hostname, signed by the Burp CA
3. Browser trusts this because the Burp CA is installed as a trusted root
4. Burp creates a second TLS connection to the actual server
5. Burp can now read and modify all traffic

**Certificate generation:**
Burp generates per-host certificates on demand, caching them for reuse. The certificate includes the exact Subject Alternative Names from the real server certificate, making it visually indistinguishable.

**Certificate pinning bypass:**
Mobile apps and some desktop apps implement certificate pinning — they reject any cert not matching an expected fingerprint. Bypass techniques:
- Android: Use Frida or Objection to hook SSL validation
- iOS: Use SSL Kill Switch 2 (requires jailbreak) or Objection
- For non-mobile: Generally not needed if Burp CA is trusted

### WebSocket Proxying

Burp intercepts WebSocket traffic by upgrading the HTTP/S connection:
- WebSocket Upgrade request appears in HTTP history
- Ongoing WebSocket messages appear in WebSocket history tab
- Messages can be intercepted and modified like HTTP requests

### HTTP/2 Support

Burp Suite handles HTTP/2:
- Proxies HTTP/2 traffic (browser ↔ Burp uses HTTP/2 if negotiated)
- Can downgrade to HTTP/1.1 for testing (configured in Proxy settings)
- HTTP/2 specific attacks: ALPN confusion, H2C smuggling

---

## Scanner Architecture

### Crawl Engine

The crawler builds a sitemap of the application:

**Traditional spider:**
- Parses HTML for links (`<a href>`, `<form action>`, JavaScript URLs)
- Submits forms with appropriate test data
- Follows redirects
- Respects robots.txt (configurable)

**JavaScript rendering:**
- Uses a headless Chromium engine for JavaScript-heavy SPAs
- Renders pages, executes JavaScript, discovers dynamically added links
- Detects framework routing (React Router, Vue Router, Angular) for SPA coverage

**Crawl scope:**
Crawl only follows URLs within the defined scope. Configure:
```
Target → Scope → Advanced scope control
Protocol: HTTPS
Host/IP: app.example.com (exact match or regex)
Port: ^443$
File: ^/app/.*$ (optional path regex)
```

**Session handling during crawl:**
Configure login macros for authenticated crawling:
```
Settings → Sessions → Session Handling Rules
Add rule: Run macro before each request (re-login if session expires)
```

### Audit Engine

The auditor tests discovered attack surface for vulnerabilities:

**Insertion point generation:**
For each crawled request, the auditor identifies insertion points:
- URL path segments
- Query parameters (GET)
- Body parameters (POST, JSON, XML)
- HTTP headers (User-Agent, Referer, custom headers)
- Cookie values
- Path parameters (`/api/users/{id}`)

**Issue detection pipeline:**
```
For each request:
  For each insertion point:
    For each applicable check:
      1. Generate test payloads
      2. Send modified requests
      3. Analyze responses
      4. Correlate response patterns with expected vulnerability indicators
      5. Apply confidence scoring (Certain/Firm/Tentative)
      6. Deduplicate similar issues
      7. Report with evidence
```

**Check types:**
- **Passive checks:** Analyze responses without modification (header analysis, information disclosure)
- **Active checks:** Send modified requests with payloads (injection testing)
- **DOM checks:** JavaScript engine analyzes client-side code for DOM XSS

**Confidence levels:**
- `Certain`: Issue is definitively present (e.g., error message contains SQL syntax error, Collaborator interaction received)
- `Firm`: Strong evidence but not 100% confirmed
- `Tentative`: Indicators present but could be coincidental

### Burp Collaborator

Collaborator is Burp's out-of-band interaction detection server.

**How it works:**
1. Burp generates unique subdomains: `xxxxxxxx.burpcollaborator.net`
2. Payloads include these subdomains (e.g., in SSRF payloads: `http://xxxxxxxx.burpcollaborator.net/`)
3. If the application makes a DNS or HTTP request to this domain, Collaborator records it
4. Burp polls Collaborator and reports the interaction as confirmation

**Use cases:**
- SSRF detection (server-side request to external URL)
- Blind SQL injection (DNS exfiltration via `load_file()`, xp_dirtree)
- Blind OS command injection (`ping xxxxxxxx.burpcollaborator.net`)
- XXE (out-of-band exfiltration via parameter entity)
- Log4Shell (JNDI lookup to Collaborator)

**Private Collaborator server:** Enterprise deployments use a self-hosted Collaborator server for air-gapped environments or privacy reasons. Configured in Enterprise settings.

---

## Intruder Mechanics

### Request Parsing

Intruder parses the request and allows marking payload positions with `§` delimiters:

```
POST /api/login HTTP/1.1
Host: app.example.com
Content-Type: application/json

{"username":"§admin§","password":"§password§"}
```

Positions can be in any part of the request: path, headers, body.

### Payload Processing

Each payload can be transformed before sending:
- **URL encoding:** Encode special characters
- **HTML encoding:** Encode for HTML context
- **Base64:** Encode/decode
- **Prefix/suffix:** Add strings around each payload
- **Match/replace:** Replace strings within payloads
- **Reverse:** Reverse the payload string
- **Case modification:** Upper/lower/capitalize

Chained processing allows multiple transformations in sequence.

### Grep Matching

Configure result columns based on response content:
- **Grep - Match:** Add column showing if response contains string (useful for error messages, success indicators)
- **Grep - Extract:** Extract value from response using start/end string markers (useful for CSRF tokens, IDs)
- **Grep - Payload Reflection:** Detect if payload appears in response (XSS indicator)

---

## Extension API (Montoya API)

Burp Suite's extension API (Montoya API, introduced in 2023, replacing the legacy API):

### Extension Entry Point

```java
// Java extension
public class MyExtension implements BurpExtension {
    @Override
    public void initialize(MontoyaApi api) {
        api.extension().setName("My Security Extension");
        
        // Register HTTP handler
        api.http().registerHttpHandler(new MyHttpHandler());
        
        // Register scan check
        api.scanner().registerScanCheck(new MyScanCheck());
        
        // Add context menu
        api.userInterface().registerContextMenuItemsProvider(new MyContextMenu());
        
        // Logging
        api.logging().logToOutput("Extension initialized");
    }
}
```

### HTTP Handler

```java
public class MyHttpHandler implements HttpHandler {
    @Override
    public RequestToBeSentAction handleHttpRequestToBeSent(HttpRequestToBeSent request) {
        // Modify request or add annotations
        if (request.path().contains("/api/")) {
            return RequestToBeSentAction.continueWith(
                request.withAddedHeader("X-Custom-Header", "test")
            );
        }
        return RequestToBeSentAction.continueWith(request);
    }
    
    @Override
    public ResponseReceivedAction handleHttpResponseReceived(HttpResponseReceived response) {
        // Analyze response
        if (response.statusCode() == 500) {
            response.annotations().setHighlightColor(HighlightColor.RED);
            response.annotations().setNotes("Server error");
        }
        return ResponseReceivedAction.continueWith(response);
    }
}
```

### Custom Scan Check

```java
public class MyScanCheck implements ScanCheck {
    @Override
    public List<AuditIssue> passiveAudit(HttpRequestResponse requestResponse) {
        // Passive check: analyze response without sending additional requests
        if (requestResponse.response().bodyToString().contains("DEBUG=true")) {
            return List.of(AuditIssue.auditIssue(
                "Debug mode enabled",
                "The response reveals debug=true which indicates...",
                "Disable debug mode in production",
                requestResponse.request().url(),
                AuditIssueSeverity.MEDIUM,
                AuditIssueConfidence.CERTAIN,
                null,
                null,
                AuditIssueSeverity.LOW,
                requestResponse
            ));
        }
        return List.of();
    }
    
    @Override
    public List<AuditIssue> activeAudit(HttpRequestResponse baseRequestResponse, AuditInsertionPoint insertionPoint) {
        // Active check: send test requests
        var testPayload = "<script>alert(1)</script>";
        var request = insertionPoint.buildHttpRequestWithPayload(
            ByteArray.byteArray(testPayload)
        );
        var response = api.http().sendRequest(request);
        
        if (response.response().bodyToString().contains(testPayload)) {
            return List.of(/* Report XSS */);
        }
        return List.of();
    }
    
    @Override
    public ConsolidationAction consolidateIssues(AuditIssue existing, AuditIssue check) {
        return existing.name().equals(check.name()) 
            ? ConsolidationAction.KEEP_EXISTING 
            : ConsolidationAction.KEEP_BOTH;
    }
}
```

---

## BCheck Runtime

BCheck scripts run in a sandboxed runtime within the Burp Scanner.

### Execution Model

```
Scanner finds insertion point
    ↓
BCheck runtime loads applicable checks
    ↓
For each BCheck:
    Execute given-when-then block
    Send defined requests
    Evaluate conditions
    Report issues if conditions met
```

### BCheck Language Reference

```
# Full BCheck structure
metadata:
    language: v1-beta
    name: "Check Name"
    description: "What this check does"
    author: "Author Name"
    tags: "tag1", "tag2"

# 'given' block: context for the check
# Options:
given host then              # Check applies per host
given path then              # Check applies per path/endpoint  
given request then           # Check applies per request
given any insertion point then  # Check applies per insertion point

# Variables from context:
# {base.request.url}        - Current URL
# {base.request.method}     - HTTP method
# {base.request.body}       - Request body
# {base.response.status}    - Response status code
# {base.response.body}      - Response body
# {latest.response.body}    - Most recent response body

    # Send HTTP requests
    send request called <name>:
        method: "GET"
        path: "/admin"
        headers:
            "X-Custom": "value"
        body: "payload"
    
    # Conditions
    if <name>.response.status_code is "200" then
        ...
    end if
    
    if <name>.response.body contains "error" then
        ...
    end if
    
    # Regex matching
    if <name>.response.body matches "(?i)password" then
        ...
    end if
    
    # Report findings
    report issue:
        severity: high          # info, low, medium, high, critical
        confidence: certain     # tentative, firm, certain
        detail: "Description of the finding"
        remediation: "How to fix it"
    
end
```

---

## Enterprise Server Architecture

### Component Topology

```
┌───────────────────────────────────────────────────────┐
│              Burp Enterprise Server                    │
│                                                        │
│  ┌──────────────┐  ┌─────────────┐  ┌──────────────┐ │
│  │   Web App    │  │  REST API   │  │  Scheduler   │ │
│  │   (UI)       │  │  Server     │  │  (cron jobs) │ │
│  └──────────────┘  └─────────────┘  └──────────────┘ │
│           │               │                │          │
│           └───────────────┴────────────────┘          │
│                           │                           │
│                    ┌──────────────┐                   │
│                    │  PostgreSQL  │                   │
│                    │  Database    │                   │
│                    └──────────────┘                   │
└───────────────────────────────────────────────────────┘
                           │ Scan tasks
                           ▼
┌───────────────────────────────────────────────────────┐
│              Scan Agents (Docker containers)           │
│                                                        │
│  Agent 1          Agent 2          Agent 3            │
│  [Burp Scanner]   [Burp Scanner]   [Burp Scanner]     │
│  Scan task A      Scan task B      Scan task C        │
└───────────────────────────────────────────────────────┘
```

### Scaling

- Each scan agent runs one scan at a time
- Add agents to run more concurrent scans
- Agents can run on separate hosts (Docker, Kubernetes)
- Agent registration is automatic via shared API token

### Storage

- **PostgreSQL:** Scan configurations, results, user management, audit logs
- **File system:** Scan artifacts, reports, large response bodies

### Authentication and Authorization

Enterprise supports:
- Local user accounts
- SAML 2.0 SSO (Okta, Azure AD, etc.)
- RBAC: Admin, Analyst, Read-only roles
- API tokens per user (for CI/CD integration)

### Audit Logging

All Enterprise actions are audited:
- Scan creation/modification/deletion
- Configuration changes
- User management
- API access

Audit log exportable to SIEM via syslog or JSON export.

---

## Burp Collaborator Server (Self-Hosted)

For environments that cannot reach the public `burpcollaborator.net`:

### Requirements
- Internet-accessible server (or accessible from target application)
- Domain with DNS delegation to Collaborator server
- TLS certificate for the domain

### Configuration

```
# collaborator.config (server-side)
{
  "serverDomain": "collaborator.yourdomain.com",
  "ssl": {
    "certificateFiles": [
      "keys/collaborator.crt",
      "keys/collaborator.key"
    ]
  },
  "eventCapture": {
    "http": { "ports": [80, 443] },
    "smtp": { "ports": [25, 587] },
    "dns": { "ports": [53] }
  },
  "polling": {
    "localAddress": "127.0.0.1",
    "localPort": 9090
  }
}
```

```bash
java -jar burpsuite_pro.jar --collaborator-server --collaborator-config collaborator.config
```

**Burp Pro client configuration:**
Settings → Project → Misc → Burp Collaborator server → Use a private Collaborator server
Server: `collaborator.yourdomain.com`
Polling location: `127.0.0.1:9090` (or wherever polling port is configured)
