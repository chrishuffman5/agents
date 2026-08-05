#!/usr/bin/env bash
# Read-only Cursor configuration inventory.
# Reports which Cursor config files exist at enterprise / project / user scope,
# lists .cursor/rules entries (flagging .md files that Cursor will ignore), and
# shows relevant environment variables. Makes no changes and starts no agent.
#
# Usage: bash 01-cursor-config-inventory.sh   (run from the project root)

set -u

USER_DIR="$HOME/.cursor"
PROJ_DIR="./.cursor"

hr() { printf '\n== %s ==\n' "$1"; }
exists() { [ -e "$1" ] && echo "  present : $1" || echo "  absent  : $1"; }

hr "CLI presence"
command -v cursor-agent >/dev/null 2>&1 && echo "  cursor-agent on PATH: $(command -v cursor-agent)" \
  || echo "  cursor-agent not on PATH"
command -v agent >/dev/null 2>&1 && echo "  agent on PATH: $(command -v agent)" \
  || echo "  agent not on PATH"

hr "Hooks by scope (precedence: Enterprise > Team > Project > User)"
# Team hooks are dashboard-delivered and have no local path to check.
exists "/Library/Application Support/Cursor/hooks.json"      # enterprise, macOS
exists "/etc/cursor/hooks.json"                              # enterprise, Linux
exists "/c/ProgramData/Cursor/hooks.json"                    # enterprise, Windows (Git Bash view)
exists "$PROJ_DIR/hooks.json"
exists "$USER_DIR/hooks.json"
echo "  note: team hooks sync from the dashboard every ~30 min and are not on disk here"

hr "MCP server config"
exists "$PROJ_DIR/mcp.json"
exists "$USER_DIR/mcp.json"

hr "Run-mode permissions (project and user are merged; team settings override local)"
exists "$PROJ_DIR/permissions.json"
exists "$USER_DIR/permissions.json"
# sandbox.json holds custom network-allowlist domains; its canonical path is not
# stated in the docs, so both plausible scopes are probed here.
exists "$PROJ_DIR/sandbox.json"
exists "$USER_DIR/sandbox.json"

hr "Cloud agent environment"
exists "$PROJ_DIR/environment.json"

hr "Instruction files"
exists "./AGENTS.md"
exists "./CLAUDE.md"
exists "./BUGBOT.md"
exists "./.cursorignore"

hr "Project rules (.cursor/rules) — only .mdc files are loaded"
if [ -d "$PROJ_DIR/rules" ]; then
  find "$PROJ_DIR/rules" -type f \( -name '*.mdc' -o -name '*.md' \) 2>/dev/null | sort | while read -r f; do
    case "$f" in
      *.mdc) echo "  rule    : $f" ;;
      *.md)  echo "  IGNORED : $f  (Cursor only loads .mdc in .cursor/rules)" ;;
    esac
  done
  [ -z "$(find "$PROJ_DIR/rules" -type f 2>/dev/null)" ] && echo "  (directory is empty)"
else
  echo "  absent  : $PROJ_DIR/rules"
fi

hr "Nested AGENTS.md (deeper files take precedence over parents)"
find . -name 'AGENTS.md' -not -path './node_modules/*' -not -path './.git/*' 2>/dev/null \
  | sort | sed 's/^/  /' || true

hr "Worktrees created by the CLI"
exists "$USER_DIR/worktrees"

hr "Relevant environment variables"
for v in CURSOR_API_KEY CURSOR_AGENT CURSOR_SANDBOX CURSOR_ORIG_UID CURSOR_ORIG_GID \
         CURSOR_PROJECT_DIR CURSOR_VERSION CURSOR_USER_EMAIL CURSOR_CODE_REMOTE \
         CURSOR_AWS_ASSUME_IAM_ROLE_ARN HTTPS_PROXY; do
  if [ -n "${!v:-}" ]; then
    case "$v" in
      *KEY|*TOKEN|*SECRET) echo "  $v = <set, value redacted>" ;;
      *)                   echo "  $v = ${!v}" ;;
    esac
  fi
done

printf '\nIn-app checks: Customize > Hooks tab, Output panel (Cmd+Shift+U) > MCP Logs.\n'

# Sources:
#   https://cursor.com/docs/hooks.md
#   https://cursor.com/docs/mcp.md
#   https://cursor.com/docs/agent/security/run-modes.md
#   https://cursor.com/docs/context/rules
#   https://cursor.com/docs/cloud-agent/setup.md
#   https://cursor.com/docs/cli/using.md
#   https://cursor.com/docs/cli/headless.md
#   https://cursor.com/docs/agent/tools/terminal.md
# Fetched: 2026-08-05
