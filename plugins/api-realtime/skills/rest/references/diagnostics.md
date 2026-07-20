# REST Diagnostics

## CORS Errors

### "No 'Access-Control-Allow-Origin' header is present"

```
Access to fetch at 'https://api.example.com' from origin 'https://app.example.com' has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present.
```

**Diagnostic steps:**
1. Check server CORS middleware is configured and includes the requesting origin
2. Verify the OPTIONS preflight handler returns correct headers
3. Check if the request triggers preflight (custom headers, PUT/PATCH/DELETE, `Content-Type: application/json`)
4. Inspect the actual response headers with browser DevTools Network tab

**Fix:** Add CORS middleware. Ensure OPTIONS handler returns `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`.

### "Wildcard '*' when credentials mode is 'include'"

```
The value of the 'Access-Control-Allow-Origin' header must not be the wildcard '*' when the request's credentials mode is 'include'.
```

**Fix:** Set explicit origin (not `*`) when `Access-Control-Allow-Credentials: true`. Read the `Origin` header from the request and echo it back (after validating against an allowlist).

### "Request header field X is not allowed"

**Fix:** Add the custom header to `Access-Control-Allow-Headers` in the preflight response. Common missing headers: `Authorization`, `Content-Type`, `X-Request-ID`.

### Credentials Not Sent

Client must set `credentials: 'include'` in fetch options. Without it, cookies and Authorization headers are not sent cross-origin.

## Status Code Confusion

### 401 vs 403

| Code | Meaning | Action |
|---|---|---|
| 401 Unauthorized | Not authenticated -- no valid credentials | Add or fix `Authorization` header |
| 403 Forbidden | Authenticated but insufficient permissions | Different role or resource needed |

Common mistake: returning 403 when the user is not logged in. Use 401.

### 400 vs 422

| Code | Meaning | Example |
|---|---|---|
| 400 Bad Request | Malformed request syntax | Invalid JSON, missing required header |
| 422 Unprocessable Entity | Semantically invalid | Valid JSON but email field has wrong format |

Use 400 for syntactic errors, 422 for validation errors.

### 404 vs 410

| Code | Meaning | Use When |
|---|---|---|
| 404 Not Found | Resource does not exist | Unknown ID, wrong URL |
| 410 Gone | Resource permanently deleted | Known ID but intentionally removed |

410 tells clients to stop requesting this resource.

### 200 with Error Body

**Symptom:** API returns `200 OK` with `{"error": "Something failed"}`.

**Fix:** Always use appropriate HTTP status code. 200 means success. Errors use 4xx or 5xx.

## Content-Type Errors

### 415 Unsupported Media Type

**Cause:** Client sent wrong `Content-Type` or server does not accept the media type.

**Fix:** Set `Content-Type: application/json` on requests with body. Verify the API accepts the media type you are sending.

### 406 Not Acceptable

**Cause:** Server cannot produce a response matching the `Accept` header.

**Fix:** Check the `Accept` header value. Remove quality factors that exclude JSON. Most APIs return `application/json`.

### Request Body Not Parsed

**Symptom:** Server receives empty body or raw string instead of parsed JSON.

**Diagnostic steps:**
1. Verify `Content-Type: application/json` is set
2. Check middleware order -- body parser must run before route handler
3. Verify the body is valid JSON (use `jq . <<< "$BODY"` to validate)

## Pagination Edge Cases

### Empty Page

Return `{"data": [], "pagination": {...}}` -- never 404 for an empty page.

### Over-limit Page

Return empty data, not an error, unless you validate page number against total.

### Cursor Invalidation

Cursors can expire. Client should handle 400/422 with error code `CURSOR_EXPIRED` and restart from beginning.

### Offset Drift

On frequently-updated datasets, offset pagination can skip or duplicate items. If this matters, switch to cursor pagination.

## Gateway Troubleshooting

### Gateway Returning 502 Bad Gateway

**Diagnostic steps:**
1. Check upstream service health (is the backend running?)
2. Verify gateway-to-backend connectivity (DNS, network, port)
3. Check backend timeout vs gateway timeout (gateway may time out before backend responds)
4. Review gateway error logs for specific error details

### Gateway Returning 504 Gateway Timeout

**Diagnostic steps:**
1. Check backend response time (is the endpoint slow?)
2. Increase gateway timeout for long-running endpoints
3. Consider async pattern (202 Accepted + polling) instead of synchronous long requests
4. Check if connection pooling is exhausted between gateway and backend

### Rate Limiting Not Working

**Diagnostic steps:**
1. Verify rate limit policy is attached to the correct route/endpoint
2. Check if the policy uses local or distributed counting (local counts per instance, not globally)
3. Verify the identifier (API key, IP, user ID) is being extracted correctly
4. Check Redis/shared state connection if using distributed rate limiting
5. Review `X-RateLimit-*` response headers to confirm policy is active

### API Key Validation Failures

**Diagnostic steps:**
1. Check if the key is being sent in the correct header (`Authorization`, `X-API-Key`)
2. Verify the key format and prefix match expectations
3. Check key expiration and rotation status
4. Review gateway logs for the specific validation error

## Performance Issues

### High Latency

**Diagnostic framework:**

| Symptom | Likely Cause | Investigation |
|---|---|---|
| Slow first request, fast subsequent | TLS handshake + cold start | Enable HTTP keep-alive, check connection pooling |
| All requests slow | Backend processing time | Profile backend, check database queries |
| Intermittent slowness | Resource contention, GC pauses | Monitor CPU, memory, connection pool exhaustion |
| Slow for large payloads | Network bandwidth, serialization | Enable gzip compression, reduce payload size |

### TTFB (Time to First Byte) Analysis

```bash
curl -w "DNS: %{time_namelookup}s\nConnect: %{time_connect}s\nTLS: %{time_appconnect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" -o /dev/null -s https://api.example.com/health
```

### Debug Headers

Add `X-Request-ID` to every request. Server echoes it in response. Enables log correlation:
```http
X-Request-ID: req-abc-123-def-456
X-Correlation-ID: correlation-xyz-789
```

### Connection Reuse

Check if connections are being reused:
```bash
curl -v https://api.example.com/orders 2>&1 | grep -i "re-using"
```

If connections are not reused, check `Connection: keep-alive` header and server keep-alive timeout configuration.

## Authentication Debugging

### JWT Validation Failures

**Common causes:**

| Error | Cause | Fix |
|---|---|---|
| "Token expired" | `exp` claim in past | Refresh token before expiry |
| "Invalid signature" | Wrong signing key or algorithm | Verify key matches issuer, check `alg` header |
| "Invalid audience" | `aud` does not match API | Configure correct audience in token request |
| "Invalid issuer" | `iss` does not match config | Verify issuer URL matches identity provider |

**Decode JWT without verification (debugging only):**
```bash
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq .
```

### OAuth 2.0 Flow Failures

**Authorization Code flow errors:**
- `invalid_client` -- wrong client ID or secret
- `invalid_grant` -- authorization code expired or already used
- `redirect_uri_mismatch` -- redirect URI does not match registered value

### API Key Not Recognized

1. Check for trailing whitespace or newline characters in the key
2. Verify the key is for the correct environment (test vs production)
3. Check if the key has been revoked or rotated

## OpenAPI Validation

### Spectral Linting

```bash
npx @stoplight/spectral-cli lint openapi.yaml
```

Common Spectral errors:
- `operation-operationId` -- missing operationId on endpoint
- `oas3-schema` -- schema does not conform to OpenAPI 3.x
- `info-contact` -- missing contact information
- `operation-description` -- missing operation description

### Schema Validation

```bash
# Validate OpenAPI spec structure
npx swagger-cli validate openapi.yaml

# Generate code to verify completeness
npx openapi-generator-cli generate -i openapi.yaml -g typescript-fetch -o ./generated
```

## Common curl Diagnostics

```bash
# Full headers and response
curl -v https://api.example.com/orders

# Check OPTIONS preflight
curl -X OPTIONS -H "Origin: https://app.example.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type,Authorization" \
  -v https://api.example.com/orders

# Check rate limit headers
curl -s -D - https://api.example.com/orders | grep -i ratelimit

# Check cache headers
curl -s -D - https://api.example.com/products/42 | grep -iE "cache-control|etag|last-modified|vary"
```
