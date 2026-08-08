#!/usr/bin/env bash
# 02-egress-allowlist-check.sh
#
# Read-only egress verification. Run INSIDE the sandbox, container, or VM to prove
# the network policy actually applies: every host Claude Code requires should be
# reachable, and a control host outside the allowlist should be blocked.
#
# It only issues HTTPS connection attempts (no request bodies, no writes, no config
# changes). An allowlist that silently failed to apply looks identical to one that
# worked - this is how you tell them apart, mirroring the self-verification step in
# Anthropic's reference init-firewall.sh.
#
# Usage:
#   bash 02-egress-allowlist-check.sh                 # required + optional hosts
#   bash 02-egress-allowlist-check.sh --required-only # skip optional/telemetry hosts

set -uo pipefail

TIMEOUT=5
REQUIRED_ONLY=0
[ "${1:-}" = "--required-only" ] && REQUIRED_ONLY=1

probe() { # probe <host> <label>
  local host="$1" label="$2"
  if curl -sS --connect-timeout "$TIMEOUT" --max-time $((TIMEOUT * 2)) -o /dev/null "https://$host" 2>/dev/null; then
    printf '  REACHABLE  %-42s %s\n' "$host" "$label"
    return 0
  else
    printf '  BLOCKED    %-42s %s\n' "$host" "$label"
    return 1
  fi
}

printf '\n== Control: this host MUST be blocked by a default-deny policy ==\n'
if probe "example.com" "control host - reachable means egress is NOT restricted"; then
  printf '\n  !! example.com is reachable. Either no egress policy is in effect, or your\n'
  printf '     allowlist is far broader than intended. Fix before trusting this environment.\n'
fi

printf '\n== Required for Claude Code (direct Anthropic API) ==\n'
probe "api.anthropic.com"        "API requests, WebFetch safety preflight, feature flags"
probe "claude.ai"                "claude.ai account authentication"
probe "claude.com"               "sign-in redirect target, pre-approved doc lookups"
probe "platform.claude.com"      "Console auth; OAuth token exchange/refresh/revocation"

printf '\n== Commonly required (enable only what your workflow needs) ==\n'
probe "registry.npmjs.org"       "npm/bun installs (skip if the org mirrors npm)"
probe "downloads.claude.ai"      "plugin downloads; native installer/auto-updater"
probe "storage.googleapis.com"   "plugin metadata; native installer pre-v2.1.116"
probe "mcp-proxy.anthropic.com"  "claude.ai MCP connectors (disable via ENABLE_CLAUDEAI_MCP_SERVERS=false)"
probe "raw.githubusercontent.com" "changelog feed for /release-notes"
probe "code.claude.com"          "claude-code-guide doc lookups only"
probe "bridge.claudeusercontent.com" "Claude in Chrome extension WebSocket bridge"

if [ "$REQUIRED_ONLY" -eq 0 ]; then
  printf '\n== Optional telemetry (safe to leave BLOCKED) ==\n'
  probe "http-intake.logs.us5.datadoghq.com" "operational telemetry - DISABLE_TELEMETRY / DO_NOT_TRACK"
  probe "browser-intake-us5-datadoghq.com"   "error reports - DISABLE_ERROR_REPORTING"
  probe "formulae.brew.sh"                   "update checks for Homebrew installs only"
fi

printf '\n== Notes ==\n'
printf '  * Bedrock/Vertex/Foundry sessions route model traffic and auth to the provider\n'
printf "    instead, but WebFetch's domain-safety check still calls api.anthropic.com\n"
printf '    unless skipWebFetchPreflight: true.\n'
printf '  * Reachability proves the allowlist permits the host. It does NOT prove\n'
printf '    confidentiality: a proxy that does not terminate TLS allowlists by\n'
printf '    client-supplied hostname only, so domain fronting can bypass it.\n'
printf '  * curl honors HTTP_PROXY/HTTPS_PROXY; Node fetch() does not by default\n'
printf '    (Node 24+: NODE_USE_ENV_PROXY=1). Results here may not match your app.\n\n'

# ## Sources
# - https://code.claude.com/docs/en/network-config
# - https://code.claude.com/docs/en/sandboxing
# - https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh
# Fetched: 2026-08-05
