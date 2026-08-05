#!/usr/bin/env bash
# Read-only Claude Code harness inventory.
# Reports CLI version, which settings sources exist at each scope, configured MCP
# servers, and installed plugin marketplaces. Makes no changes and starts no session.
#
# Usage: bash 01-harness-inventory.sh

set -u

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

hr() { printf '\n== %s ==\n' "$1"; }
exists() { [ -e "$1" ] && echo "  present : $1" || echo "  absent  : $1"; }

hr "CLI version"
command -v claude >/dev/null 2>&1 && claude --version || echo "  claude not on PATH"

hr "Config directory"
echo "  CLAUDE_CONFIG_DIR = ${CLAUDE_CONFIG_DIR:-<unset, defaulting to ~/.claude>}"
exists "$CONFIG_DIR"

hr "Settings files by scope (highest precedence first)"
# Managed (endpoint-delivered) — platform-specific paths.
exists "/etc/claude-code/managed-settings.json"
exists "/Library/Application Support/ClaudeCode/managed-settings.json"
exists "/c/Program Files/ClaudeCode/managed-settings.json"
# Local > Project > User.
exists "./.claude/settings.local.json"
exists "./.claude/settings.json"
exists "$CONFIG_DIR/settings.json"

hr "Memory / instruction files"
exists "./CLAUDE.md"
exists "./.claude/CLAUDE.md"
exists "./CLAUDE.local.md"
exists "$CONFIG_DIR/CLAUDE.md"
exists "./.claude/rules"

hr "Project-scoped component directories"
exists "./.claude/agents"
exists "./.claude/skills"
exists "./.claude/commands"
exists "./.mcp.json"

hr "Configured MCP servers"
claude mcp list 2>&1 || echo "  (claude mcp list unavailable)"

hr "Installed plugin marketplaces"
claude plugin marketplace list 2>&1 || echo "  (claude plugin marketplace list unavailable)"

hr "Relevant environment variables"
for v in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN \
         CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY \
         ANTHROPIC_BASE_URL HTTPS_PROXY NODE_EXTRA_CA_CERTS \
         CLAUDE_CODE_ENABLE_TELEMETRY DISABLE_AUTOUPDATER; do
  if [ -n "${!v:-}" ]; then
    case "$v" in
      *KEY|*TOKEN) echo "  $v = <set, value redacted>" ;;
      *)           echo "  $v = ${!v}" ;;
    esac
  fi
done

printf '\nRun /status, /doctor, /hooks, /permissions and /mcp inside a session for the resolved view.\n'

# Sources:
#   https://code.claude.com/docs/en/settings.md
#   https://code.claude.com/docs/en/memory.md
#   https://code.claude.com/docs/en/mcp.md
#   https://code.claude.com/docs/en/plugin-marketplaces.md
#   https://code.claude.com/docs/en/authentication.md
# Fetched: 2026-08-05
