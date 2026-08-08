#!/usr/bin/env bash
# Read-only OpenAI Codex harness inventory.
#
# Reports the CLI version, which config layers exist (system / user / profile /
# project), whether admin-managed policy is present, the AGENTS.md chain that
# would be discovered from the current directory, the .agents/skills directories
# on the discovery path, and the configured MCP servers.
#
# Makes no changes, writes no files, and starts no Codex session.
# Run it first when a Codex setting "isn't applying".
#
# Usage: bash 01-codex-inventory.sh [start-dir]

set -u

START_DIR="${1:-$PWD}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"

hr()     { printf '\n== %s ==\n' "$1"; }
exists() { [ -e "$1" ] && echo "  present : $1" || echo "  absent  : $1"; }

hr "CLI version"
if command -v codex >/dev/null 2>&1; then
  codex --version 2>/dev/null || echo "  codex present but --version failed"
else
  echo "  codex not on PATH"
fi

hr "Codex home"
echo "  CODEX_HOME = ${CODEX_HOME:-<unset, defaulting to ~/.codex>}"
exists "$CODEX_DIR"

hr "Config layers (lowest precedence first; CLI flags beat all of them)"
exists "/etc/codex/config.toml"
exists "$CODEX_DIR/config.toml"
echo "  -- profile files (~/.codex/<name>.config.toml, used with --profile) --"
found_profile=0
for f in "$CODEX_DIR"/*.config.toml; do
  [ -e "$f" ] || continue
  echo "  present : $f"
  found_profile=1
done
[ "$found_profile" -eq 0 ] && echo "  none found"

echo "  -- project configs from the start dir upward --"
d="$START_DIR"
while :; do
  [ -f "$d/.codex/config.toml" ] && echo "  present : $d/.codex/config.toml"
  [ -d "$d/.git" ] && { echo "  (git root: $d)"; break; }
  parent="$(dirname "$d")"
  [ "$parent" = "$d" ] && break
  d="$parent"
done
echo "  NOTE: project config is loaded only when the project is trusted."

hr "Admin-managed policy"
exists "/etc/codex/managed_config.toml"
exists "/etc/codex/requirements.toml"
exists "$CODEX_DIR/managed_config.toml"     # Windows location
exists "$CODEX_DIR/requirements.toml"
if command -v defaults >/dev/null 2>&1; then
  echo "  -- macOS MDM preference domain com.openai.codex --"
  for key in config_toml_base64 requirements_toml_base64; do
    if defaults read com.openai.codex "$key" >/dev/null 2>&1; then
      echo "  present : com.openai.codex/$key"
    else
      echo "  absent  : com.openai.codex/$key"
    fi
  done
fi

hr "AGENTS.md discovery chain"
echo "  -- global scope ($CODEX_DIR): override wins, first non-empty file only --"
exists "$CODEX_DIR/AGENTS.override.md"
exists "$CODEX_DIR/AGENTS.md"
echo "  -- project scope: git root down to start dir, one file per directory --"
# Collect the directory chain from the git root down to START_DIR.
chain=""
d="$START_DIR"
while :; do
  chain="$d
$chain"
  [ -d "$d/.git" ] && break
  parent="$(dirname "$d")"
  [ "$parent" = "$d" ] && break
  d="$parent"
done
printf '%s\n' "$chain" | while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  if [ -f "$dir/AGENTS.override.md" ]; then
    echo "  USED    : $dir/AGENTS.override.md  (override beats AGENTS.md here)"
  elif [ -f "$dir/AGENTS.md" ]; then
    echo "  USED    : $dir/AGENTS.md"
  fi
done
echo "  Files merge root-down; later (deeper) files override earlier guidance."
echo "  Default size cap is project_doc_max_bytes = 32 KiB per file."
echo "  Definitive check: codex debug prompt-input"

hr "Skill directories (.agents/skills on the discovery path)"
printf '%s\n' "$chain" | while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  [ -d "$dir/.agents/skills" ] && echo "  present : $dir/.agents/skills"
done
exists "$HOME/.agents/skills"
exists "/etc/codex/skills"
echo "  NOTE: the directory is .agents/skills, not .codex/skills."

hr "Configured MCP servers"
if command -v codex >/dev/null 2>&1; then
  codex mcp list 2>/dev/null || echo "  'codex mcp list' unavailable or failed"
else
  echo "  codex not on PATH"
fi

hr "Sandbox backend availability (local enforcement)"
case "$(uname -s 2>/dev/null || echo unknown)" in
  Darwin)
    command -v sandbox-exec >/dev/null 2>&1 \
      && echo "  present : sandbox-exec (macOS Seatbelt)" \
      || echo "  absent  : sandbox-exec — macOS sandboxing unavailable"
    ;;
  Linux)
    if command -v bwrap >/dev/null 2>&1; then
      echo "  present : $(command -v bwrap)  (first bwrap on PATH is the one Codex uses)"
    else
      echo "  absent  : bwrap on PATH — Codex falls back to a bundled helper that"
      echo "            requires unprivileged user namespaces"
    fi
    if [ -r /proc/sys/kernel/unprivileged_userns_clone ]; then
      echo "  unprivileged_userns_clone = $(cat /proc/sys/kernel/unprivileged_userns_clone)"
    fi
    ;;
  *)
    echo "  Windows/other: Codex uses its native Windows sandbox; WSL2 uses the Linux path."
    ;;
esac

hr "Next steps"
cat <<'EOF'
  In a Codex session:
    /status         active model, approval policy, writable roots, token usage
    /debug-config   config layers in precedence order + source of managed policy
  On the CLI:
    codex debug prompt-input    exact model-visible prompt input list
    codex --strict-config ...   make unrecognized config keys an error
EOF

# Sources:
#   https://learn.chatgpt.com/docs/config-file/config-basic
#   https://learn.chatgpt.com/docs/config-file/config-advanced
#   https://learn.chatgpt.com/docs/agent-configuration/agents-md
#   https://learn.chatgpt.com/docs/build-skills
#   https://learn.chatgpt.com/docs/extend/mcp?surface=cli
#   https://learn.chatgpt.com/docs/sandboxing
#   https://learn.chatgpt.com/docs/enterprise/managed-configuration
#   https://learn.chatgpt.com/docs/developer-commands?surface=cli
# Fetched: 2026-08-05
