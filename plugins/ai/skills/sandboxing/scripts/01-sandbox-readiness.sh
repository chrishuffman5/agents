#!/usr/bin/env bash
# 01-sandbox-readiness.sh
#
# Read-only preflight for Claude Code's Bash sandbox and @anthropic-ai/sandbox-runtime.
# Reports platform support, required binaries, the Ubuntu 24.04+ AppArmor userns
# restriction, and which sandbox settings files exist. Makes no changes and no
# network requests.
#
# Usage: bash 01-sandbox-readiness.sh

set -uo pipefail

pass() { printf '  [ OK ]   %s\n' "$1"; }
warn() { printf '  [ WARN ] %s\n' "$1"; }
fail() { printf '  [ FAIL ] %s\n' "$1"; }
info() { printf '  [ INFO ] %s\n' "$1"; }

section() { printf '\n== %s ==\n' "$1"; }

# --- Platform -----------------------------------------------------------------
section "Platform"

UNAME=$(uname -s 2>/dev/null || echo unknown)
IS_WSL=0
if grep -qi microsoft /proc/version 2>/dev/null; then IS_WSL=1; fi

case "$UNAME" in
  Darwin)
    pass "macOS detected - sandbox uses built-in Seatbelt, no packages required"
    PLATFORM=macos
    ;;
  Linux)
    if [ "$IS_WSL" -eq 1 ]; then
      if [ -n "$(uname -r | grep -o 'WSL2' || true)" ] || [ -e /dev/kmsg ]; then
        pass "WSL2 detected - supported (bubblewrap path)"
      else
        warn "WSL detected but WSL2 could not be confirmed; WSL1 is NOT supported"
      fi
    else
      pass "Linux detected - sandbox uses bubblewrap"
    fi
    PLATFORM=linux
    ;;
  *)
    fail "Unsupported platform '$UNAME' - the Bash sandbox runs on macOS, Linux, and WSL2 only (native Windows is unsupported)"
    PLATFORM=other
    ;;
esac

# --- Required binaries --------------------------------------------------------
section "Required binaries"

check_bin() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 found at $(command -v "$1")"
  else
    printf '  [ %s ] %s\n' "$2" "$3"
  fi
}

if [ "$PLATFORM" = "linux" ]; then
  check_bin bwrap  FAIL "bubblewrap (bwrap) NOT found - install: apt-get install bubblewrap  |  dnf install bubblewrap"
  check_bin socat  FAIL "socat NOT found - required to relay sandbox traffic to the proxy: apt-get install socat"
  check_bin rg     WARN "ripgrep (rg) not found on PATH - bundled with the Claude Code native binary; required standalone for sandbox-runtime"
  check_bin iptables WARN "iptables not found - only needed if you run a container-side egress firewall"
  check_bin ipset  WARN "ipset not found - only needed for the init-firewall.sh allowlist pattern"
elif [ "$PLATFORM" = "macos" ]; then
  check_bin sandbox-exec WARN "sandbox-exec not found on PATH - expected at /usr/bin/sandbox-exec on supported macOS"
  check_bin rg     WARN "ripgrep (rg) not found - sandbox-runtime requires it on macOS: brew install ripgrep"
fi

check_bin node WARN "node not found - needed for npm-installed Claude Code and for @anthropic-ai/sandbox-runtime"
if command -v node >/dev/null 2>&1; then
  info "node version: $(node --version 2>/dev/null)  (Node 22.15+ needed for CLAUDE_CODE_CERT_STORE=system; Node 24+ for NODE_USE_ENV_PROXY)"
fi

# --- AppArmor unprivileged user namespaces (Ubuntu 24.04+) --------------------
if [ "$PLATFORM" = "linux" ]; then
  section "AppArmor unprivileged user namespaces"
  if command -v sysctl >/dev/null 2>&1; then
    APPARMOR_VAL=$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || echo "unset")
    case "$APPARMOR_VAL" in
      1)
        fail "kernel.apparmor_restrict_unprivileged_userns=1 - bubblewrap cannot create user namespaces."
        info "Fix: create /etc/apparmor.d/bwrap with a 'profile bwrap /usr/bin/bwrap flags=(unconfined) { userns, }' stanza, then: sudo systemctl reload apparmor"
        ;;
      0)      pass "kernel.apparmor_restrict_unprivileged_userns=0 - bubblewrap user namespaces permitted" ;;
      unset)  info "kernel.apparmor_restrict_unprivileged_userns not present - not an AppArmor-restricted kernel" ;;
      *)      warn "kernel.apparmor_restrict_unprivileged_userns=$APPARMOR_VAL - unexpected value, verify manually" ;;
    esac
  else
    warn "sysctl not available - could not check the AppArmor userns restriction"
  fi

  section "Nested-container check"
  if [ -f /.dockerenv ] || grep -qE '(docker|containerd|kubepods)' /proc/1/cgroup 2>/dev/null; then
    warn "Running inside a container - bubblewrap may fail to mount a fresh /proc."
    info "If it fails, sandbox.enableWeakerNestedSandbox=true bind-mounts the existing /proc. This considerably weakens the inner sandbox; only acceptable when the outer container already isolates."
  else
    pass "Not running inside a detected container"
  fi
fi

# --- sandbox-runtime ----------------------------------------------------------
section "@anthropic-ai/sandbox-runtime"

if command -v srt >/dev/null 2>&1; then
  pass "srt found at $(command -v srt)"
else
  info "srt not on PATH - install with: npm install -g @anthropic-ai/sandbox-runtime"
  info "On Linux it also supplies the seccomp filter that blocks AF_UNIX socket creation for the Bash sandbox."
fi

if [ -f "$HOME/.srt-settings.json" ]; then
  pass "~/.srt-settings.json exists"
else
  warn "~/.srt-settings.json missing - srt still STARTS without it (all network blocked, writes confined to built-in runtime paths). A clean start is NOT proof your settings loaded; pass --settings explicitly so a load failure fails closed."
fi

# --- Settings files -----------------------------------------------------------
section "Sandbox settings files present"

for f in \
  "/Library/Application Support/ClaudeCode/managed-settings.json" \
  "/etc/claude-code/managed-settings.json" \
  "$HOME/.claude/settings.json" \
  "./.claude/settings.json" \
  "./.claude/settings.local.json"
do
  if [ -f "$f" ]; then
    if command -v grep >/dev/null 2>&1 && grep -q '"sandbox"' "$f" 2>/dev/null; then
      pass "$f  (contains a \"sandbox\" block)"
    else
      info "$f  (present, no \"sandbox\" key found)"
    fi
  fi
done

# --- Credential exposure ------------------------------------------------------
section "Credential files readable by default"

info "The Bash sandbox has NO built-in credential deny list; default read policy covers the whole machine."
for f in "$HOME/.aws/credentials" "$HOME/.ssh" "$HOME/.config/gcloud/application_default_credentials.json" \
         "$HOME/.kube/config" "$HOME/.docker/config.json" "$HOME/.git-credentials" "$HOME/.npmrc"
do
  [ -e "$f" ] && warn "exists and is readable by sandboxed commands unless denied: $f"
done
info "Add each to sandbox.credentials.files with mode \"deny\" (Claude Code v2.1.187+) or to sandbox.filesystem.denyRead."

printf '\nDone. Nothing was modified.\n'

# ## Sources
# - https://code.claude.com/docs/en/sandboxing
# - https://github.com/anthropic-experimental/sandbox-runtime
# - https://code.claude.com/docs/en/network-config
# Fetched: 2026-08-05
