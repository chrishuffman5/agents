#!/usr/bin/env bash
# Read-only GitHub Copilot configuration inventory for a repository.
#
# Reports which Copilot customization files exist, whether their required
# frontmatter is present, and whether copilot-setup-steps.yml carries the job
# name the cloud agent actually looks for. Makes no changes, starts no Copilot
# session, and performs no network calls.
#
# Usage: bash 01-copilot-inventory.sh [repo-root]   # defaults to $PWD

set -u

ROOT="${1:-$PWD}"
cd "$ROOT" 2>/dev/null || { echo "Cannot enter $ROOT"; exit 1; }

hr() { printf '\n== %s ==\n' "$1"; }
exists() { [ -e "$1" ] && echo "  present : $1" || echo "  absent  : $1"; }

echo "Copilot configuration inventory for: $ROOT"

hr "Copilot CLI"
if command -v copilot >/dev/null 2>&1; then
  copilot version 2>/dev/null || echo "  copilot present, version command failed"
  echo "  For resolved plugins/MCP/skills/instruction sources run: copilot plugins list --json"
else
  echo "  copilot not on PATH"
fi
command -v gh >/dev/null 2>&1 && gh --version 2>/dev/null | head -1 || echo "  gh not on PATH"

hr "Repository-wide instructions"
exists ".github/copilot-instructions.md"
if [ -f ".github/copilot-instructions.md" ]; then
  echo "  lines   : $(wc -l < .github/copilot-instructions.md)  (guidance: keep it to roughly two pages)"
fi

hr "Path-specific instructions (.github/instructions/**/*.instructions.md)"
found=0
while IFS= read -r f; do
  found=1
  if head -20 "$f" | grep -qE '^applyTo:'; then
    printf '  ok      : %s  (%s)\n' "$f" "$(head -20 "$f" | grep -E '^applyTo:' | head -1)"
  else
    printf '  PROBLEM : %s  -- missing required applyTo frontmatter\n' "$f"
  fi
done < <(find .github/instructions -type f -name '*.instructions.md' 2>/dev/null)
[ "$found" -eq 0 ] && echo "  none found"

hr "Agent instruction files (nearest-to-context wins)"
find . -type f -name 'AGENTS.md' -not -path './.git/*' 2>/dev/null | sed 's/^/  AGENTS.md : /' || true
exists "CLAUDE.md"
exists "GEMINI.md"

hr "Prompt files (.github/prompts/*.prompt.md)"
found=0
while IFS= read -r f; do
  found=1
  if head -10 "$f" | grep -qE '^description:'; then
    printf '  ok      : %s  -> invoke as /%s\n' "$f" "$(basename "$f" .prompt.md)"
  else
    printf '  note    : %s  -- no description frontmatter\n' "$f"
  fi
done < <(find .github/prompts -type f -name '*.prompt.md' 2>/dev/null)
[ "$found" -eq 0 ] && echo "  none found"

hr "Custom agents (.github/agents/*.agent.md)"
found=0
while IFS= read -r f; do
  found=1
  bytes=$(wc -c < "$f")
  if head -20 "$f" | grep -qE '^description:'; then
    printf '  ok      : %s  (%s bytes; body limit 30000 chars)\n' "$f" "$bytes"
  else
    printf '  PROBLEM : %s  -- description is required frontmatter\n' "$f"
  fi
  [ "$bytes" -gt 30000 ] && printf '  PROBLEM : %s  -- exceeds the 30000-character limit\n' "$f"
done < <(find .github/agents -type f -name '*.agent.md' 2>/dev/null)
[ "$found" -eq 0 ] && echo "  none found"

hr "Cloud agent environment (.github/workflows/copilot-setup-steps.yml)"
SETUP=".github/workflows/copilot-setup-steps.yml"
exists "$SETUP"
if [ -f "$SETUP" ]; then
  if grep -qE '^[[:space:]]+copilot-setup-steps:[[:space:]]*$' "$SETUP"; then
    echo "  ok      : job named 'copilot-setup-steps' found"
  else
    echo "  PROBLEM : no job named 'copilot-setup-steps' -- Copilot will silently ignore this file"
  fi
  grep -nE '^[[:space:]]+(runs-on|timeout-minutes):' "$SETUP" | sed 's/^/  /'
  grep -qiE 'windows' "$SETUP" && echo "  WARNING : Windows runner detected -- the integrated firewall is not compatible with Windows"
  grep -qiE 'self-hosted|arc-' "$SETUP" && echo "  WARNING : self-hosted runner detected -- the integrated firewall is not compatible; configure proxy env vars instead"
fi

hr "VS Code workspace Copilot settings"
exists ".vscode/settings.json"
if [ -f ".vscode/settings.json" ]; then
  grep -nE '"(chat\.|github\.copilot|inlineChat\.)' .vscode/settings.json | sed 's/^/  /' || echo "  no Copilot-related keys"
fi

printf '\nReminders: instruction precedence is personal > repository > organization.\n'
printf 'Custom agent precedence is repository > organization > enterprise.\n'
printf 'Cloud agent sessions are capped at 59 minutes and touch one repo, one branch, one PR.\n'

# Sources:
#   https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions
#   https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file
#   https://docs.github.com/en/copilot/reference/custom-agents-configuration
#   https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/customize-the-agent-environment
#   https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent
#   https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference
#   https://code.visualstudio.com/docs/copilot/reference/copilot-settings
# Fetched: 2026-08-05
