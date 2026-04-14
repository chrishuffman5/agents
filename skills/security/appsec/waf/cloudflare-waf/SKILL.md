---
name: security-appsec-waf-cloudflare
description: "Expert agent for Cloudflare WAF. Covers managed rulesets, custom rules (Firewall Rules/WAF Rules), rate limiting, bot management, API Shield, Workers for custom logic, zone configuration, and Cloudflare's edge security platform. WHEN: \"Cloudflare WAF\", \"Cloudflare firewall\", \"Cloudflare managed rules\", \"Cloudflare rate limiting\", \"Cloudflare bot management\", \"API Shield\", \"Cloudflare Workers security\", \"Cloudflare zone\", \"Cloudflare transform rules\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Cloudflare WAF Expert

You are a specialist in Cloudflare's Web Application Firewall and security platform. You cover Cloudflare WAF (managed rulesets and custom rules), Rate Limiting, Bot Management, API Shield, DDoS Protection, and Cloudflare Workers for custom security logic.

## How to Approach Tasks

1. **Identify the plan tier** -- Free, Pro, Business, Enterprise. Feature availability varies significantly.
2. **Identify the concern:**
   - **Managed rulesets** -- Cloudflare OWASP, Cloudflare Managed, attack campaign rulesets
   - **Custom rules** -- WAF rules using Wireshark-style expression language
   - **Rate limiting** -- Per-IP, per-user, per-endpoint rate limits
   - **Bot management** -- Bot Fight Mode vs. Bot Management (Enterprise)
   - **API Shield** -- API schema validation, JWT validation, rate limiting
   - **Workers** -- Custom security logic at the edge

## Cloudflare Security Architecture

Cloudflare operates as a global CDN/edge network. All traffic passes through Cloudflare's edge before reaching origin servers:

```
Internet → Cloudflare Edge (WAF + DDoS + Bot + CDN) → Origin Server
```

**Processing order (important for rule interaction):**
1. DDoS protection (Magic Transit / HTTP DDoS)
2. Custom WAF rules (Firewall Rules / WAF Rules)
3. Rate limiting rules
4. Managed rulesets (Cloudflare OWASP, Cloudflare Managed)
5. Bot Management score evaluation
6. API Shield validation
7. Cache layer
8. Origin request

---

## Managed Rulesets

Cloudflare provides managed rule sets maintained by Cloudflare's security team.

### Available Managed Rulesets

**Cloudflare Managed Ruleset (Free+):**
- Core protection against common web vulnerabilities
- SQL injection, XSS, RCE, local file inclusion
- Automatically updated by Cloudflare

**Cloudflare OWASP Core Rule Set (Pro+):**
- Based on OWASP ModSecurity CRS
- Anomaly scoring approach (accumulate points, block at threshold)
- Configurable paranoia level and anomaly score threshold

**Cloudflare Free Managed Ruleset:**
- Subset of protection for Free tier
- Cannot configure individual rules

**Exposed Credential Checks (Pro+):**
- Compares credentials against known-breached credential databases
- Flags requests using compromised username/password pairs

**Cloudflare Leaked Credentials Ruleset:**
- Detects leaked credentials in real-time on login endpoints

### Configuring OWASP Ruleset

```
Security → WAF → Managed rules → Cloudflare OWASP Core Ruleset
```

**Key settings:**
- **Paranoia Level:** PL1 (default) → PL2 → PL3 → PL4 (most aggressive)
- **Score threshold:** Tolerate (score > 25), Block (score > 20), Challenge (score > 15)
- **Action:** Log, Challenge, Block

**Recommendation:** Start at PL1 with score threshold 25. Review logs, then adjust.

### Rule-Level Configuration

Override specific rules within managed rulesets:

```
Security → WAF → Managed rules → Cloudflare OWASP → Browse rules
  → Find rule by ID
  → Override: Disable, Log, Challenge, Block, Skip
```

Use rule overrides to disable specific rules generating false positives instead of disabling the entire ruleset.

**Rule exception syntax (expression-based):**
```
# Exception: skip OWASP rule 942100 for /api/search endpoint
# In "Exceptions" tab under managed ruleset configuration
http.request.uri.path eq "/api/search"
  → Skip rules: 942100
```

---

## Custom WAF Rules

Custom WAF Rules use Cloudflare's Wireshark-style expression language (Ruleset Engine expression language).

### Expression Language

```
# Field references
http.request.uri.path         # URL path
http.request.uri.query        # Query string
http.request.headers          # All headers as map
http.request.headers["X-Custom-Header"]  # Specific header value
http.request.body.raw         # Raw request body
http.request.body.form        # Form data map
http.request.body.json        # JSON body
http.request.method           # GET, POST, etc.
http.host                     # Hostname
ip.src                        # Source IP
ip.geoip.country              # Country code (US, CN, RU)
cf.bot_management.score       # Bot score (1-99, lower = more bot-like)
cf.threat_score               # Cloudflare threat score

# Operators
eq, ne, lt, gt, le, ge        # Comparison
contains                      # String contains
matches                       # Regex match
in {set}                      # Set membership

# Logical operators
and, or, not                  # Boolean logic

# Functions
lower(field)                  # Lowercase
upper(field)
len(field)                    # Length
url_decode(field)             # URL decode
```

### Example Custom Rules

**Block requests from specific countries:**
```
ip.geoip.country in {"CN" "RU" "KP" "IR"}
  → Action: Block
```

**Rate limit login endpoint:**
```
http.request.uri.path eq "/api/v1/auth/login" and http.request.method eq "POST"
  → Rate Limit: 10 requests per minute per IP → Block
```

**Block known bad user agents:**
```
http.user_agent contains "sqlmap" or
http.user_agent contains "nikto" or
http.user_agent contains "masscan" or
http.user_agent matches "(?i)(scanner|exploit|attack)"
  → Action: Block
```

**Challenge suspicious traffic:**
```
cf.threat_score ge 10 and not ip.src in {203.0.113.0/24}  # Exclude trusted range
  → Action: Managed Challenge (JS challenge)
```

**Protect admin path:**
```
http.request.uri.path wildcard "/admin/*" and
not ip.src in $trusted_ips_list   # IP List reference
  → Action: Block
```

**Skip WAF for trusted monitoring:**
```
ip.src in {1.2.3.4 5.6.7.8}   # Monitoring service IPs
  → Action: Skip (bypass all WAF rules)
```

### Custom Rules Actions

| Action | Behavior |
|---|---|
| Block | Return 403 (or custom error page) |
| Challenge (Managed) | Cloudflare JS/CAPTCHA challenge |
| JS Challenge | JavaScript challenge (less friction than CAPTCHA) |
| Log | Record in logs, allow request |
| Skip | Bypass specific rulesets or all rules |
| Interactive Challenge | CAPTCHA challenge |
| Rewrite | Rewrite request URL or headers |
| Redirect | Redirect to URL |

---

## Rate Limiting

### Rate Limiting v2 (Current)

```
Security → WAF → Rate limiting rules → Create rule
```

**Rule configuration:**
```
Name: Login brute force protection
Match: http.request.uri.path eq "/api/auth/login"
       AND http.request.method eq "POST"
Rate: 5 requests / 1 minute
Characteristics:
  - IP address (per source IP)
  - [optional] Header value (cf-connecting-ip for behind-proxy scenarios)
Action: Block
Duration: 10 minutes (block duration after threshold)
```

**Counting characteristics:**
- `IP`: Per source IP (default)
- `IP with NAT support`: Uses cf-connecting-ip when behind NAT
- `Header`: Per specific header value (e.g., per API key)
- `Cookie`: Per session cookie value
- `Query parameter`: Per specific query string value
- `AS number`: Per autonomous system (ISP-level)
- `Country`: Per country code
- `JA3 fingerprint`: Per TLS fingerprint (catches rotating IPs with same TLS client)

**Mitigation timeout:** How long to block after threshold exceeded (60 seconds to 1 day).

---

## Bot Management

### Bot Fight Mode (Free - Business)

Simple bot protection using Cloudflare's ML classification:
- Blocks known bad bots
- Challenges suspected automated traffic with JS challenges
- No configuration options — on/off per zone

Enable: Security → Bots → Bot Fight Mode → On

### Bot Management (Enterprise)

Full-featured bot protection with:
- **Bot score (1-99):** ML-based score. 1 = definitely bot, 99 = definitely human.
- **Verified bots:** Known good bots (Googlebot, etc.) are pre-verified
- **Bot tags:** Category labels (search engine crawler, marketing bot, AI scraper, etc.)

**Using bot score in WAF rules:**
```
# Block low-score bots
cf.bot_management.score lt 10
  → Action: Block

# Challenge borderline traffic
cf.bot_management.score lt 30 and cf.bot_management.score ge 10
  → Action: Managed Challenge

# Allow verified bots (search engines)
cf.bot_management.verified_bot eq true
  → Action: Skip
```

**AI scraper blocking:**
```
# Block AI scrapers (OpenAI, Common Crawl, etc.)
cf.bot_management.ja3_hash in $known_ai_scrapers or
http.user_agent contains "GPTBot" or
http.user_agent contains "CCBot"
  → Action: Block
```

---

## API Shield

API Shield provides API-specific security for Cloudflare zones.

### Schema Validation

Upload OpenAPI schema → Cloudflare validates all API requests against schema:

```
Security → API Shield → Schema Validation → Add Schema
  → Upload openapi.yaml
  → Select API base path: /api/v1
  → Validation action: Log (initially) → Block (after tuning)
```

**Validation checks:**
- Request path matches defined endpoints
- HTTP method allowed for endpoint
- Required parameters present
- Parameter values match defined types/formats
- Body schema conforms to defined structure

### JWT Validation

Validate JWTs at the edge before requests reach origin:

```
Security → API Shield → JWT Validation → Add configuration
  → Token locations: Header (Authorization: Bearer), Cookie, Query parameter
  → JWKS endpoint: https://auth.example.com/.well-known/jwks.json
  → Required claims: exp, iss (https://auth.example.com)
  → Action: Block (if invalid) / Log (if expired)
```

**Benefits:** Offload JWT validation from application servers. Invalid/expired tokens blocked at edge without hitting backend.

### API Rate Limiting via API Shield

Configure per-endpoint, per-authenticated-user rate limits:

```
Security → API Shield → API Rate Limiting
  → Endpoint: POST /api/v1/orders
  → Threshold: 100 requests per minute
  → Identifier: JWT sub claim (per user)
```

### mTLS (Mutual TLS)

Require client certificates for API-to-API or IoT-to-cloud communication:

```
SSL/TLS → Client Certificates → Enable mTLS
  → Generate or upload CA certificate
  → Apply to hostname/path: *.api.example.com
```

---

## Cloudflare Workers for Custom Security

Cloudflare Workers run JavaScript/TypeScript/WebAssembly at the edge for custom security logic.

### Security Use Cases

**Custom authentication middleware:**
```javascript
export default {
  async fetch(request, env) {
    const apiKey = request.headers.get("X-API-Key");
    
    if (!apiKey || !(await isValidApiKey(apiKey, env))) {
      return new Response("Unauthorized", { status: 401 });
    }
    
    // Add authenticated user context to request
    const modifiedRequest = new Request(request, {
      headers: {
        ...Object.fromEntries(request.headers),
        "X-Authenticated-User": await getUserId(apiKey, env)
      }
    });
    
    return fetch(modifiedRequest);
  }
}
```

**Custom rate limiting with Durable Objects:**
```javascript
export class RateLimiter {
  constructor(state, env) {
    this.state = state;
  }

  async fetch(request) {
    const count = await this.state.storage.get("count") || 0;
    const resetTime = await this.state.storage.get("resetTime") || Date.now() + 60000;
    
    if (Date.now() > resetTime) {
      await this.state.storage.put("count", 1);
      await this.state.storage.put("resetTime", Date.now() + 60000);
      return new Response("OK");
    }
    
    if (count >= 100) {
      return new Response("Rate limited", { status: 429 });
    }
    
    await this.state.storage.put("count", count + 1);
    return new Response("OK");
  }
}
```

**Request transformation (add security headers):**
```javascript
export default {
  async fetch(request, env) {
    const response = await fetch(request);
    
    const newHeaders = new Headers(response.headers);
    newHeaders.set("Content-Security-Policy", "default-src 'self'; script-src 'self' 'nonce-{NONCE}'");
    newHeaders.set("X-Content-Type-Options", "nosniff");
    newHeaders.set("X-Frame-Options", "DENY");
    newHeaders.set("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload");
    
    return new Response(response.body, {
      status: response.status,
      headers: newHeaders
    });
  }
}
```

---

## Zone Configuration for Security

### Security Level

Security → Settings → Security Level:
- **Essentially Off:** Only block explicitly defined threats
- **Low:** Less aggressive (more legitimate traffic, some bots pass)
- **Medium:** Default protection
- **High:** Aggressive (more challenges, some legitimate traffic challenged)
- **I'm Under Attack!:** Maximum protection (all visitors get JS challenge)

Use "I'm Under Attack!" mode during active DDoS incidents. Returns to normal after attack subsides.

### HTTPS / TLS Settings

SSL/TLS → Overview:
- **Flexible:** Cloudflare to origin is HTTP (do not use — insecure)
- **Full:** Cloudflare to origin is HTTPS with any certificate (use if self-signed)
- **Full (Strict):** Cloudflare to origin requires valid certificate (recommended)
- **Strict:** Cloudflare to origin requires Cloudflare-issued or CA-trusted cert

**Minimum TLS version:** SSL/TLS → Edge Certificates → Minimum TLS Version → TLS 1.2

**HSTS:** SSL/TLS → Edge Certificates → HTTP Strict Transport Security (HSTS) → Enable with max-age 31536000, include subdomains, preload.

---

## Common Issues

**False positives from managed rulesets:**
- Review blocked requests in Security → Events
- Filter by: Rule ID that triggered
- Create exception in Managed Ruleset: Rules → Exceptions → Add exception based on expression
- Use targeted exceptions (specific path + rule) not global rule disable

**WAF rules not triggering for API traffic:**
- API requests with `Content-Type: application/json` — ensure body inspection is enabled
- For JSON body scanning: enable `cf.waf.payload_encoding.json` in ruleset settings
- Verify request is matching the expected URI path expression

**Bot Management interfering with legitimate automation:**
- Add exceptions for known good automation: ip.src in {automation_ip_list}
- For API tokens: check cf.bot_management.score threshold — automation often scores low
- Use JA3 fingerprint to allowlist specific TLS client signatures
- Enable Verified Bots exceptions: cf.bot_management.verified_bot eq true → Skip

**Rate limiting incorrectly counting behind load balancers:**
- If origin servers are behind load balancer, source IPs may be load balancer IPs
- Use `cf-connecting-ip` header characteristic instead of `IP`
- Or use customer-facing IP from X-Forwarded-For header
