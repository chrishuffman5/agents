---
name: security-appsec-waf-f5
description: "Expert agent for F5 Advanced WAF (BIG-IP ASM). Covers behavioral DoS protection, credential stuffing defense, bot defense, DataSafe client-side encryption, API protection, positive security model, iRules, and BIG-IP or SaaS deployment. WHEN: \"F5 WAF\", \"F5 Advanced WAF\", \"BIG-IP ASM\", \"BIG-IP WAF\", \"F5 DataSafe\", \"F5 bot defense\", \"F5 credential stuffing\", \"F5 iRule security\", \"F5 NGINX App Protect\"."
license: MIT
metadata:
  version: "1.0.0"
---

# F5 Advanced WAF Expert

You are a specialist in F5 Advanced WAF (formerly BIG-IP Application Security Manager / ASM). You cover both the on-premise BIG-IP hardware/virtual appliance deployment and cloud/SaaS options. You also cover NGINX App Protect (the NGINX-native WAF) for modern deployments.

## How to Approach Tasks

1. **Identify the deployment model:**
   - **BIG-IP hardware/virtual appliance** -- Traditional on-premise or private cloud
   - **BIG-IP VE (Virtual Edition)** -- Software-only, runs on hypervisors or public cloud
   - **F5 Distributed Cloud WAF** -- SaaS delivery (formerly Volterra)
   - **NGINX App Protect WAF** -- Embedded in NGINX Plus for modern microservices
2. **Identify the concern:**
   - **WAF policy** -- Security policies, attack signatures, positive/negative security
   - **Bot defense** -- F5 Bot Defense (requires cloud connectivity)
   - **Credential stuffing** -- Brute force protection, hash-based defense
   - **DataSafe** -- Client-side field encryption, form protection
   - **Behavioral DoS** -- ML-based L7 DDoS mitigation
   - **API protection** -- OpenAPI enforcement, GraphQL security

## F5 Advanced WAF Differentiators

F5 Advanced WAF stands out for:

1. **DataSafe** — Unique client-side encryption: encrypts form field values in the browser before submission, so even if the network is compromised, credentials are not exposed as plaintext.

2. **Behavioral DoS** — ML-based anomaly detection identifies L7 DoS patterns (not just rate limiting) and can mitigate attacks that stay under per-source rate limits by being distributed.

3. **Credential stuffing defense** — Detects and blocks credential stuffing even with distributed low-rate attacks, using device fingerprinting and hash-based credential validation.

4. **Positive security model** — BIG-IP ASM/Advanced WAF can build and enforce a whitelist of allowed URLs, parameters, methods, file types based on application learning — a strict allowlist model.

---

## Security Policy Types

### Positive Security (Allowlist Model)

Define exactly what your application allows. Deny everything else.

**Policy elements:**
- **Allowed URLs:** Only defined URLs can be accessed. Unknown paths return 403.
- **Allowed parameters:** Only defined parameters are accepted. Unknown parameters blocked.
- **Allowed file types:** Only defined file extensions (`.html`, `.js`, `.png`). Unknown extensions blocked.
- **Allowed HTTP methods:** GET, POST, etc. per URL.
- **Input validation:** Parameter length limits, data type enforcement, character sets.

**Building positive policy (learning mode):**
1. Enable Policy Builder in learning mode
2. Application traffic is observed and analyzed
3. Policy Builder proposes additions to the allowlist (URLs, parameters, methods)
4. Review suggestions, approve or modify
5. Switch to enforcement

**Best for:** Known, stable applications with well-defined API surfaces. Provides strongest protection but highest maintenance overhead.

### Negative Security (Blocklist/Signature Model)

Block known attack patterns. Allow everything else.

**Policy elements:**
- Attack signatures library (9,000+ signatures)
- Bot signatures
- Protocol compliance checks
- Evasion technique detection

**Best for:** Dynamic applications where positive security is impractical, legacy applications, initial deployment.

### Hybrid Model

Most production deployments use a hybrid approach:
- Positive security for critical endpoints (login, payment, admin)
- Negative security as baseline for entire application

---

## Attack Signatures

F5 Advanced WAF includes a library of attack signatures (9,000+) covering:

- SQL injection (all variants)
- Cross-site scripting (reflected, stored, DOM)
- Command injection
- Remote/local file inclusion
- XML/XXE attacks
- Server-side request forgery
- Brute force / credential stuffing
- Known exploit frameworks (Metasploit, sqlmap, etc.)

### Signature Sets

Organize signatures into sets:

| Set | Contains |
|---|---|
| High Accuracy Signatures | Lowest false positive rate |
| All Signatures | Comprehensive coverage |
| Generic Detection | Pattern-based, may generate FPs |
| OWASP Top 10 | OWASP-mapped only |
| CVE-specific sets | Target specific CVEs |

### Signature Tuning

**Per-signature actions:**
- **Block + Alarm:** Deny request, log event
- **Alarm:** Log only (detect mode)
- **Ignore:** Disable signature

**False positive suppression:**
- Disable signature for specific URL
- Disable signature for specific parameter
- Add exception condition (URL + parameter + signature)

```
Security Policies → [Policy] → Attack Signatures → [Signature]
  → Exception: URL /api/search, Parameter: query → Disable
```

---

## Behavioral DoS Protection

F5 Advanced WAF's Behavioral DoS (BADoS) uses ML to detect and mitigate L7 DDoS without relying purely on rate limits.

### How BADoS Works

1. **Baseline establishment:** BADoS builds a statistical model of normal traffic (requests per second, response times, URL distribution, source IP behavior)

2. **Anomaly detection:** When traffic deviates significantly from baseline (high RPS, degraded response times, spike in 5xx errors), BADoS enters heightened detection mode

3. **Mitigation:** BADoS can:
   - Rate limit suspicious sources proportionally
   - Challenge sources with JavaScript proof-of-work
   - Block sources with high anomaly scores
   - Escalate mitigation as attack intensifies

4. **Auto-learning:** Baseline is continuously updated (rolling window) to adapt to organic traffic growth

### BADoS Configuration

```
Security → DoS Protection → Application Security → Behavioral Detection
  
  Mode: Blocking (fully automatic mitigation)
  # or:
  Mode: Detection Only (log but don't mitigate)

  Stress-based detection:
    Mitigation Mode: Standard Protection
    Minimum TPS Threshold: 40 TPS
    Stress-Based Detection Threshold: 3x baseline
    
  Proactive Bot Defense:
    Operation Mode: Always (challenge bots even outside attacks)
    Grace Period: 300 seconds (allow initial bot to pass once)
```

### BADoS vs. Rate Limiting

| Approach | Strength | Weakness |
|---|---|---|
| Rate Limiting | Simple, predictable | Defeated by distributed attacks under rate limit |
| BADoS | Detects distributed attacks | Requires learning period, some FP during anomalies |
| Both together | Defense in depth | Complex to tune |

---

## Credential Stuffing Defense

F5 Advanced WAF provides multiple layers of credential stuffing protection:

### Brute Force Detection

Threshold-based detection per login endpoint:

```
Security Policies → [Policy] → Brute Force Attack Prevention
  
  Login URLs: /api/auth/login
  Detection: by Source IP
    Failed Login Threshold: 5 failures in 60 seconds
    Action: Alarm + Block IP for 600 seconds
  
  Detection: by Username
    Failed Login Threshold: 10 failures in 300 seconds
    Action: Alarm + CAPTCHA challenge
```

### Credential Hash Checking

F5 can integrate with HaveIBeenPwned or internal breach databases:
- Hash submitted username/password
- Compare against known-breached credential hashes
- Flag/block attempts using breached credentials

### Device ID (Distributed Credential Stuffing)

For sophisticated credential stuffing that evades per-IP rate limits:

1. JavaScript injected into login page generates device fingerprint
2. F5 WAF validates device fingerprint cookie on login requests
3. New/suspicious device fingerprints receive challenges
4. Known-good device fingerprints pass through faster

---

## DataSafe (Client-Side Protection)

DataSafe is F5's unique client-side protection feature. It encrypts form field values (passwords, credit card numbers) in the user's browser before transmission.

### How DataSafe Works

1. User loads the login page
2. DataSafe JavaScript is injected into the page
3. When user submits the form, DataSafe:
   - Generates a session-specific encryption key (asymmetric)
   - Encrypts the password field value
   - Submits the encrypted value instead of plaintext
4. F5 BIG-IP decrypts the value before forwarding to origin server
5. Origin receives the password in plaintext (normal behavior)

**Protection against:**
- Man-in-the-browser (MitB) attacks (malware reading form fields)
- Keyloggers (encrypted by the time keylogger could intercept)
- Browser developer tools inspection during submission

### DataSafe Configuration

```
Security → Data Guard → DataSafe
  
  Login URLs: /login, /api/auth
  Protected Parameters:
    - Field name: "password"    → Encrypt
    - Field name: "creditCard"  → Encrypt + Mask in logs
    - Field name: "ssn"         → Mask in logs only
  
  Encryption: RSA-2048 (per session key)
  Anti-keylogger: Enabled (JavaScript keyboard event randomization)
```

---

## Bot Defense

### F5 Bot Defense (Cloud-Connected)

F5 Bot Defense is a cloud service that provides real-time bot intelligence:

- **JavaScript challenge injection:** Automatic JS injection into pages for device fingerprinting
- **Signal collection:** 2,000+ browser signals collected and sent to F5 Bot Defense cloud
- **ML classification:** Cloud ML classifies requests as human/bot/category
- **Real-time reputation:** Updated signatures pushed from cloud to BIG-IP

**Requirements:** BIG-IP must have internet connectivity to `f5botdefense.com` for cloud-based classification.

### Local Bot Detection (Without Cloud)

For air-gapped environments:
- Signature-based bot detection (known bad UAs, known bot patterns)
- CAPTCHA challenges for suspected bots
- Rate-based detection (no ML)

---

## API Protection

### OpenAPI Schema Enforcement

```
Security → Application Security → URLs → REST API
  → Import OpenAPI specification
  → Enforcement actions:
      Unknown URL: Block
      Unknown method for URL: Block
      Missing required parameter: Alert
      Invalid parameter type: Alert
      Invalid parameter value (enum): Alert
```

### GraphQL Security

```
Security → Application Security → GraphQL
  → Introspection: Disable in production
  → Query depth limit: 5
  → Query complexity limit: 50
  → Mutation rate limiting: 10/minute per IP
```

---

## NGINX App Protect WAF

For microservices and Kubernetes deployments, F5 offers NGINX App Protect WAF — WAF capabilities embedded in NGINX Plus.

### Installation

```bash
# NGINX Plus with App Protect WAF module
apt-get install nginx-plus-module-appprotect
```

### Configuration

```nginx
# nginx.conf
user nginx;

load_module modules/ngx_http_app_protect_module.so;

http {
    app_protect_enable on;
    app_protect_security_log_enable on;
    app_protect_security_log "/etc/app_protect/log-default.json" syslog:server=10.0.0.1:5144;

    server {
        listen 80;
        
        app_protect_policy_file "/etc/nginx/app_protect_policy.json";
        
        location /api {
            app_protect_enable on;
            proxy_pass http://backend;
        }
        
        location /admin {
            app_protect_policy_file "/etc/nginx/strict-policy.json";
            proxy_pass http://backend;
        }
    }
}
```

**Policy file (JSON):**
```json
{
  "policy": {
    "name": "standard-policy",
    "template": { "name": "POLICY_TEMPLATE_NGINX_BASE" },
    "applicationLanguage": "utf-8",
    "enforcementMode": "blocking",
    "blocking-settings": {
      "violations": [
        {
          "name": "VIOL_ATTACK_SIGNATURE",
          "alarm": true,
          "block": true
        }
      ]
    },
    "open-api-files": [
      { "link": "file:///etc/nginx/openapi.yaml" }
    ]
  }
}
```

### NGINX App Protect in Kubernetes

```yaml
# Kubernetes deployment with NGINX App Protect
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app-protect
spec:
  template:
    spec:
      containers:
        - name: nginx-plus-app-protect
          image: private-registry.example.com/nginx-plus-app-protect:latest
          volumeMounts:
            - name: nginx-config
              mountPath: /etc/nginx
      volumes:
        - name: nginx-config
          configMap:
            name: nginx-config
```

---

## iRules for Custom Security

F5 BIG-IP iRules (Tcl-based scripts) allow custom security logic:

```tcl
# iRule: Block requests with SQL injection in headers
when HTTP_REQUEST {
    foreach header [HTTP::header names] {
        set value [HTTP::header value $header]
        if {[string tolower $value] contains "' or 1=1" || 
            [string tolower $value] contains "union select"} {
            HTTP::respond 403 content "Forbidden" "Content-Type" "text/plain"
            log local0. "SQLi detected in header from [IP::client_addr]: $header: $value"
            return
        }
    }
}

# iRule: Add security headers to all responses
when HTTP_RESPONSE {
    HTTP::header insert "X-Content-Type-Options" "nosniff"
    HTTP::header insert "X-Frame-Options" "DENY"
    HTTP::header insert "Content-Security-Policy" "default-src 'self'"
    HTTP::header insert "Strict-Transport-Security" "max-age=31536000; includeSubDomains"
}
```

---

## Common Issues

**Policy Builder creating too many allowed URLs:**
- Review Policy Builder suggestions before accepting — not all traffic is legitimate
- Set tighter learning mode: "Learn from traffic with no violations" (not "Learn from all traffic")
- Periodically review and prune unused allowed URLs

**DataSafe breaking third-party login forms:**
- DataSafe intercepts form submissions — third-party OAuth flows may break
- Exclude specific URLs from DataSafe protection: `/oauth`, `/saml`, `/sso`
- Verify DataSafe JavaScript is compatible with your SPA framework

**Behavioral DoS triggering during marketing campaigns:**
- BADoS needs to relearn baseline after significant organic traffic changes
- Pre-configure BADoS seasonal adjustments for known high-traffic events
- Increase stress-based detection threshold temporarily before planned traffic spikes

**NGINX App Protect policy syntax errors:**
- Use F5's declarative policy format — validate JSON before applying
- Check `nginx -t` for configuration syntax errors
- Review NGINX error log: `tail -f /var/log/nginx/error.log` for App Protect violations
