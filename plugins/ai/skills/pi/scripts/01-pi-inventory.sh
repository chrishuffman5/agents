#!/usr/bin/env sh
# pi harness inventory — READ ONLY.
#
# Reports which pi configuration files, resources, and trust state actually
# exist, and which provider credential variables are set (NAMES ONLY — this
# script never prints a value, never reads auth.json contents, and never
# invokes pi). Run it from the project directory you are diagnosing.
#
# Usage: sh 01-pi-inventory.sh
#
# Paths follow https://pi.dev/docs/latest/settings, /environment-variables,
# /extensions, /skills, /prompt-templates, /themes, /packages, /sessions,
# /usage and /security (fetched 2026-08-05).

set -u

AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
SESSION_DIR="${PI_CODING_AGENT_SESSION_DIR:-$AGENT_DIR/sessions}"

hdr()  { printf '\n== %s ==\n' "$1"; }
have() { if [ -e "$1" ]; then printf '  [x] %s\n' "$1"; else printf '  [ ] %s\n' "$1"; fi; }
count_dir() {
  # $1 = directory, $2 = glob pattern, $3 = label
  if [ -d "$1" ]; then
    n=$(find "$1" -maxdepth 1 -name "$2" 2>/dev/null | wc -l | tr -d ' ')
    printf '  [x] %s  (%s matching %s)\n' "$1" "$n" "$2"
  else
    printf '  [ ] %s\n' "$1"
  fi
}

hdr "pi binary"
if command -v pi >/dev/null 2>&1; then
  printf '  [x] pi on PATH: %s\n' "$(command -v pi)"
else
  printf '  [ ] pi not found on PATH\n'
fi
printf '  cwd: %s\n' "$(pwd)"

hdr "Global config ($AGENT_DIR)"
have "$AGENT_DIR/settings.json"
have "$AGENT_DIR/models.json"
have "$AGENT_DIR/trust.json"
have "$AGENT_DIR/AGENTS.md"
have "$AGENT_DIR/SYSTEM.md"
have "$AGENT_DIR/APPEND_SYSTEM.md"
if [ -e "$AGENT_DIR/auth.json" ]; then
  printf '  [x] %s  (present — contents NOT read)\n' "$AGENT_DIR/auth.json"
else
  printf '  [ ] %s\n' "$AGENT_DIR/auth.json"
fi

hdr "Global resources"
count_dir "$AGENT_DIR/extensions" '*' 'entries'
count_dir "$AGENT_DIR/skills" '*' 'entries'
count_dir "$AGENT_DIR/prompts" '*.md' '*.md (discovery is NON-recursive)'
count_dir "$AGENT_DIR/themes" '*.json' '*.json'
count_dir "$AGENT_DIR/git" '*' 'cloned packages'
count_dir "$HOME/.agents/skills" '*' 'entries'

hdr "Project config (.pi/ — loaded only if the project is trusted)"
have ".pi/settings.json"
have ".pi/SYSTEM.md"
have ".pi/APPEND_SYSTEM.md"
count_dir ".pi/extensions" '*' 'entries'
count_dir ".pi/skills" '*' 'entries'
count_dir ".pi/prompts" '*.md' '*.md (discovery is NON-recursive)'
count_dir ".pi/themes" '*.json' '*.json'
count_dir ".pi/git" '*' 'cloned packages'
count_dir ".agents/skills" '*' 'entries'

hdr "Project trust"
if [ -f "$AGENT_DIR/trust.json" ]; then
  printf '  trust.json exists. Checking for a reference to this path...\n'
  if grep -qF "$(pwd)" "$AGENT_DIR/trust.json" 2>/dev/null; then
    printf '  [x] cwd appears in trust.json\n'
  else
    printf '  [ ] cwd NOT found in trust.json — project-local .pi/ resources may be ignored.\n'
    printf '      Run /trust in pi, or pass -a/--approve for one invocation.\n'
  fi
else
  printf '  [ ] no trust.json — no project trust decisions saved yet.\n'
fi

hdr "Context file discovery (AGENTS.md / CLAUDE.md, cwd walking upward)"
d=$(pwd)
while :; do
  for f in AGENTS.override.md AGENTS.md CLAUDE.md; do
    [ -f "$d/$f" ] && printf '  [x] %s/%s\n' "$d" "$f"
  done
  [ "$d" = "/" ] && break
  parent=$(dirname "$d")
  [ "$parent" = "$d" ] && break
  d="$parent"
done
printf '  (note: AGENTS.override.md REPLACES the standard context files in its own directory)\n'

hdr "Sessions ($SESSION_DIR)"
if [ -d "$SESSION_DIR" ]; then
  dirs=$(find "$SESSION_DIR" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  files=$(find "$SESSION_DIR" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
  printf '  [x] %s  (%s project dirs, %s .jsonl session files)\n' "$SESSION_DIR" "$dirs" "$files"
else
  printf '  [ ] %s\n' "$SESSION_DIR"
fi

hdr "pi environment variables set (names only)"
for v in PI_CODING_AGENT_DIR PI_CODING_AGENT_SESSION_DIR PI_PACKAGE_DIR PI_OFFLINE \
         PI_SKIP_VERSION_CHECK PI_TELEMETRY PI_CACHE_RETENTION PI_SHARE_VIEWER_URL \
         PI_HARDWARE_CURSOR PI_CODING_AGENT VISUAL EDITOR HTTP_PROXY HTTPS_PROXY; do
  eval "val=\${$v:-}"
  [ -n "$val" ] && printf '  set: %s\n' "$v"
done

hdr "Provider credential variables (set/unset only — values never printed)"
for v in ANTHROPIC_API_KEY OPENAI_API_KEY AZURE_OPENAI_API_KEY DEEPSEEK_API_KEY \
         GEMINI_API_KEY AWS_BEARER_TOKEN_BEDROCK GROQ_API_KEY OPENROUTER_API_KEY XAI_API_KEY; do
  eval "val=\${$v:-}"
  if [ -n "$val" ]; then printf '  [x] %s\n' "$v"; else printf '  [ ] %s\n' "$v"; fi
done

hdr "If a resource is not loading, check in this order"
cat <<'EOF'
  1. Is the project trusted?  (trust.json / /trust / -a)
  2. Is the file in a discovered location, or listed in settings.json?
  3. Is a suppression flag in play?  --no-extensions --no-skills
     --no-prompt-templates --no-themes -nc/--no-context-files -na/--no-approve
  4. Is .pi/settings.json deep-merging over ~/.pi/agent/settings.json?
  5. Prompt templates only: is it in a SUBDIRECTORY of prompts/? Discovery is non-recursive.
EOF
printf '\n'

## Sources
# - https://pi.dev/docs/latest/settings
# - https://pi.dev/docs/latest/environment-variables
# - https://pi.dev/docs/latest/providers
# - https://pi.dev/docs/latest/extensions
# - https://pi.dev/docs/latest/skills
# - https://pi.dev/docs/latest/prompt-templates
# - https://pi.dev/docs/latest/themes
# - https://pi.dev/docs/latest/packages
# - https://pi.dev/docs/latest/sessions
# - https://pi.dev/docs/latest/usage
# - https://pi.dev/docs/latest/security
#
# Fetched: 2026-08-05
