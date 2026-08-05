#!/usr/bin/env bash
# probe-mcp-http-endpoint.sh — read-only reachability + OAuth-discovery probe for a
# remote MCP (Streamable HTTP) endpoint.
#
# Makes only GET/HEAD/OPTIONS requests plus metadata fetches. It never POSTs a
# JSON-RPC request, never initializes a session, and never calls a tool.
#
# Usage:  ./probe-mcp-http-endpoint.sh https://mcp.example.com/mcp
#
# Behavior derived from:
#   https://modelcontextprotocol.io/specification/2025-11-25/basic/transports
#   https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization
#   https://code.claude.com/docs/en/mcp   (curl -I triage)

set -u

URL="${1:-}"
if [ -z "$URL" ]; then
  echo "usage: $0 <mcp-endpoint-url>" >&2
  exit 2
fi

case "$URL" in
  https://*) ;;
  http://localhost*|http://127.0.0.1*|http://\[::1\]*) echo "note: loopback http is dev-only" >&2 ;;
  *) echo "refusing non-https, non-loopback URL (spec requires https for remote servers)" >&2; exit 2 ;;
esac

CURL="curl -sS --max-time 15 -o /dev/null"

hr() { printf '%s\n' "------------------------------------------------------------"; }

hr
echo "1. Reachability"
hr
STATUS=$($CURL -w '%{http_code}' -I "$URL" 2>/dev/null || echo "000")
echo "HEAD $URL -> HTTP $STATUS"
case "$STATUS" in
  404|405) echo "   OK: many MCP endpoints answer POST only. Not a failure." ;;
  401|403) echo "   Authorization required — continuing to OAuth discovery." ;;
  000)     echo "   No response: network, DNS, or wrong URL." ;;
  2*)      echo "   Endpoint responded." ;;
  *)       echo "   Unexpected status; inspect manually." ;;
esac

hr
echo "2. WWW-Authenticate challenge (RFC 9728 discovery)"
hr
HEADERS=$(curl -sS --max-time 15 -D - -o /dev/null \
  -H 'Accept: application/json, text/event-stream' "$URL" 2>/dev/null || true)
CHALLENGE=$(printf '%s' "$HEADERS" | tr -d '\r' | grep -i '^www-authenticate:' || true)

RES_META=""
if [ -n "$CHALLENGE" ]; then
  echo "$CHALLENGE"
  RES_META=$(printf '%s' "$CHALLENGE" | sed -n 's/.*resource_metadata="\([^"]*\)".*/\1/p')
  SCOPES=$(printf '%s' "$CHALLENGE" | sed -n 's/.*scope="\([^"]*\)".*/\1/p')
  [ -n "$SCOPES" ] && echo "   required scopes (authoritative for this request): $SCOPES"
else
  echo "no WWW-Authenticate header; falling back to well-known probing"
fi

hr
echo "3. Protected Resource Metadata"
hr
ORIGIN=$(printf '%s' "$URL" | sed -E 's#^(https?://[^/]+).*#\1#')
PATH_PART=$(printf '%s' "$URL" | sed -E 's#^https?://[^/]+##; s#^/##')

CANDIDATES=""
[ -n "$RES_META" ] && CANDIDATES="$RES_META"
[ -n "$PATH_PART" ] && CANDIDATES="$CANDIDATES $ORIGIN/.well-known/oauth-protected-resource/$PATH_PART"
CANDIDATES="$CANDIDATES $ORIGIN/.well-known/oauth-protected-resource"

PRM=""
for c in $CANDIDATES; do
  code=$(curl -sS --max-time 15 -o /tmp/mcp-prm.$$ -w '%{http_code}' "$c" 2>/dev/null || echo 000)
  echo "GET $c -> HTTP $code"
  if [ "$code" = "200" ]; then PRM=$(cat /tmp/mcp-prm.$$); break; fi
done
rm -f /tmp/mcp-prm.$$

if [ -z "$PRM" ]; then
  echo "no protected resource metadata found (server may be unauthenticated)"
  exit 0
fi
printf '%s\n' "$PRM"

hr
echo "4. Authorization server metadata"
hr
AS=$(printf '%s' "$PRM" | tr ',{}[]' '\n\n\n\n\n' | sed -n 's/.*"authorization_servers"[^"]*"\([^"]*\)".*/\1/p' | head -1)
if [ -z "$AS" ]; then
  AS=$(printf '%s' "$PRM" | grep -o 'https://[^"]*' | head -1)
fi
if [ -z "$AS" ]; then
  echo "could not extract authorization_servers; inspect the metadata above manually"
  exit 0
fi
echo "authorization server: $AS"

AS_ORIGIN=$(printf '%s' "$AS" | sed -E 's#^(https?://[^/]+).*#\1#')
AS_PATH=$(printf '%s' "$AS" | sed -E 's#^https?://[^/]+##; s#^/##; s#/$##')

if [ -n "$AS_PATH" ]; then
  PROBES="$AS_ORIGIN/.well-known/oauth-authorization-server/$AS_PATH
$AS_ORIGIN/.well-known/openid-configuration/$AS_PATH
$AS_ORIGIN/$AS_PATH/.well-known/openid-configuration"
else
  PROBES="$AS_ORIGIN/.well-known/oauth-authorization-server
$AS_ORIGIN/.well-known/openid-configuration"
fi

printf '%s\n' "$PROBES" | while IFS= read -r p; do
  [ -z "$p" ] && continue
  code=$(curl -sS --max-time 15 -o /tmp/mcp-as.$$ -w '%{http_code}' "$p" 2>/dev/null || echo 000)
  echo "GET $p -> HTTP $code"
  if [ "$code" = "200" ]; then
    grep -o '"code_challenge_methods_supported":[^]]*]' /tmp/mcp-as.$$ || \
      echo "   WARNING: code_challenge_methods_supported absent — spec says clients MUST refuse to proceed"
    grep -o '"client_id_metadata_document_supported":[a-z]*' /tmp/mcp-as.$$ || true
    grep -o '"registration_endpoint":"[^"]*"' /tmp/mcp-as.$$ || true
    rm -f /tmp/mcp-as.$$
    break
  fi
  rm -f /tmp/mcp-as.$$
done

hr
echo "Done. No state-changing requests were made."
