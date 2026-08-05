#!/usr/bin/env bash
# 01-harness-inventory.sh — read-only inventory of installed agent harnesses and their config surface.
#
# Reports, for Claude Code / OpenAI Codex CLI / Google Gemini CLI: whether the binary is on PATH,
# its version, and which instruction / config / MCP files exist for the current user and project.
# Run from the repository root you care about. Read-only: no file is created or modified.
#
# Config and instruction-file locations are taken from the official docs listed under "Sources" below.
#
# Usage: bash scripts/01-harness-inventory.sh

set -u

say()  { printf '%s\n' "$*"; }
head2() { printf '\n== %s ==\n' "$*"; }

check_bin() {
  # $1 = binary, $2 = version flag
  if command -v "$1" >/dev/null 2>&1; then
    printf '  binary   : %s (%s)\n' "$(command -v "$1")" "$("$1" "$2" 2>/dev/null | head -n 1)"
  else
    printf '  binary   : not on PATH\n'
  fi
}

check_file() {
  # $1 = label, $2 = path
  if [ -e "$2" ]; then
    printf '  %-9s: PRESENT  %s\n' "$1" "$2"
  else
    printf '  %-9s: -        %s\n' "$1" "$2"
  fi
}

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
say "Agent harness inventory"
say "project root: ${PROJECT_ROOT}"
say "user home   : ${HOME}"

head2 "Claude Code"
check_bin claude --version
check_file memory   "${PROJECT_ROOT}/CLAUDE.md"
check_file memory   "${HOME}/.claude/CLAUDE.md"
check_file settings "${PROJECT_ROOT}/.claude/settings.json"
check_file settings "${PROJECT_ROOT}/.claude/settings.local.json"
check_file settings "${HOME}/.claude/settings.json"
check_file mcp      "${PROJECT_ROOT}/.mcp.json"
check_file skills   "${PROJECT_ROOT}/.claude/skills"
check_file agents   "${PROJECT_ROOT}/.claude/agents"

head2 "OpenAI Codex CLI"
check_bin codex --version
check_file memory   "${PROJECT_ROOT}/AGENTS.md"
check_file memory   "${PROJECT_ROOT}/AGENTS.override.md"
check_file memory   "${HOME}/.codex/AGENTS.md"
check_file config   "${PROJECT_ROOT}/.codex/config.toml"
check_file config   "${HOME}/.codex/config.toml"
check_file config   "/etc/codex/config.toml"
check_file managed  "/etc/codex/managed_config.toml"
check_file managed  "/etc/codex/requirements.toml"

head2 "Google Gemini CLI"
check_bin gemini --version
check_file memory   "${PROJECT_ROOT}/GEMINI.md"
check_file memory   "${HOME}/.gemini/GEMINI.md"
check_file settings "${PROJECT_ROOT}/.gemini/settings.json"
check_file settings "${HOME}/.gemini/settings.json"
check_file managed  "/etc/gemini-cli/settings.json"
check_file managed  "/Library/Application Support/GeminiCli/settings.json"

head2 "Notes"
say "  MCP servers are declared in .mcp.json (Claude Code), config.toml [mcp_servers.*] (Codex),"
say "  and settings.json mcpServers (Gemini). Inspect them with: claude mcp list / codex mcp list / /tools."
say "  Codex resolved config: run '/status' or '/debug-config' inside a session."

# Sources:
#   https://code.claude.com/docs/en/mcp.md
#   https://code.claude.com/docs/en/skills.md
#   https://code.claude.com/docs/en/sub-agents.md
#   https://code.claude.com/docs/en/hooks.md
#   https://learn.chatgpt.com/docs/config-file/config-basic
#   https://learn.chatgpt.com/docs/agent-configuration/agents-md
#   https://learn.chatgpt.com/docs/enterprise/managed-configuration
#   https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/settings.md
#   https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/gemini-md.md
#   https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/enterprise.md
# Fetched: 2026-08-05
