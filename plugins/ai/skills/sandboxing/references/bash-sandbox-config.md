# Claude Code Bash Sandbox — Full Configuration Reference

Read this before writing any `sandbox.*` settings block. All facts as of 2026-08-05.

## Platform support and prerequisites

> Source: https://code.claude.com/docs/en/sandboxing

Supported on **macOS, Linux, and WSL2**. Native Windows is not supported; WSL1 is not supported (bubblewrap requires WSL2 kernel features).

| Platform | Mechanism | Install |
|---|---|---|
| macOS | Built-in Seatbelt | Nothing to install |
| Linux / WSL2 | bubblewrap (`bwrap`) + `socat` | `apt-get install bubblewrap socat` / `dnf install bubblewrap socat` |
| Linux / WSL2 (optional) | seccomp filter blocking Unix domain sockets | `npm install -g @anthropic-ai/sandbox-runtime` |

`ripgrep` ships with the native binary.

**Ubuntu 24.04+**: the default AppArmor policy blocks bubblewrap's user-namespace creation. Check `sysctl kernel.apparmor_restrict_unprivileged_userns`; if it returns `1`, create `/etc/apparmor.d/bwrap`:

```
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
  include if exists <local/bwrap>
}
```

then `sudo systemctl reload apparmor`.

**WSL2 caveat**: sandboxed commands cannot launch Windows binaries (`cmd.exe`, `powershell.exe`, `/mnt/c/...`) — WSL hands those to the Windows host over a Unix socket the sandbox blocks. Add them to `excludedCommands`.

## Modes and the `/sandbox` command

> Source: https://code.claude.com/docs/en/sandboxing

`/sandbox` opens a panel with **Mode**, **Overrides** (`allowUnsandboxedCommands`), **Config** (resolved settings), plus a **Dependencies** tab on Linux when a package is missing. Selecting a mode writes to `.claude/settings.local.json` (project-local). For all projects, set `sandbox.enabled: true` in `~/.claude/settings.json`; for org-wide, use managed settings.

- **Auto-allow mode** — sandboxable commands run auto-approved. Non-sandboxable commands (e.g. needing a non-allowed host) fall back to the regular permission flow. Still enforced in auto-allow: explicit deny rules; `rm`/`rmdir` against `/`, home, or critical paths still prompts (classifier routing in auto mode requires v2.1.218+); content-scoped ask rules such as `Bash(git push *)` still prompt. A bare `Bash` or `Bash(*)` ask rule is skipped for sandboxed commands, except in plan mode where it still prompts (v2.1.212+).
- **Regular permissions mode** — every Bash command goes through the normal permission flow even when sandboxed.

Both modes enforce identical filesystem/network restrictions; only the approval flow differs.

If the sandbox cannot start (missing deps, unsupported platform), Claude Code warns and runs **unsandboxed** by default. `sandbox.failIfUnavailable: true` makes that a hard failure — required for any deployment treating the sandbox as a security gate.

**Escape hatch**: on a sandbox-caused failure Claude may retry with the `dangerouslyDisableSandbox` parameter; the retry runs unsandboxed through the regular permission flow. Force a prompt every time with an ask rule `Bash(dangerouslyDisableSandbox:true)`. Disable entirely with `"allowUnsandboxedCommands": false` (shown as **Strict sandbox mode**) — then the parameter is ignored and commands must run sandboxed or appear in `excludedCommands`.

Session temp dir: Claude Code sets `$TMPDIR` to the session temp dir for sandboxed commands (different from the shell's own `$TMPDIR` for unsandboxed commands) and it is writable by default alongside the working directory.

## Filesystem isolation

> Source: https://code.claude.com/docs/en/sandboxing

Defaults:

- **Write**: current working directory + subdirectories, plus session `$TMPDIR`.
- **Read**: the entire computer except denied dirs — **`~/.aws/credentials` and `~/.ssh/` are readable by default**.
- **Blocked**: modifying anything outside CWD/temp without explicit permission, including `~/.bashrc` and `/bin/`.

```json
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["~/.kube", "/tmp/build"],
      "denyRead": ["~/"],
      "allowRead": ["."]
    }
  }
}
```

Filesystem arrays defined in multiple settings scopes are **merged**, not replaced.

Path prefixes (these differ from Read/Edit permission-rule syntax, which uses `//path` for absolute):

| Prefix | Meaning | Example |
|---|---|---|
| `/` | Absolute from root | `/tmp/build` |
| `~/` | Relative to home | `~/.kube` → `$HOME/.kube` |
| `./` or none | Project root (project settings) or `~/.claude` (user settings) | `./output` |

Precedence: most-specific path wins. `denyRead: ["~/"]` + `allowRead: ["~/projects"]` → only `~/projects` readable. `allowRead: ["~/"]` + `denyRead: ["~/.env"]` → `~/.env` still blocked.

**Git worktrees**: linked-worktree sessions also get write access to the main repo's shared `.git` dir (so `git commit` works), but `.git/hooks/` and `.git/config` inside it stay denied.

**Protected settings files** (auto-denied for writes unless filesystem isolation is disabled): `settings.json` at every scope plus the managed settings dir; `.mcp.json` at project root and at any `--add-dir` root; symlink targets resolving to a protected path (resolved as of v2.1.210+).

### Disabling filesystem isolation (network-only sandbox)

`sandbox.filesystem.disabled: true` keeps network isolation while dropping filesystem isolation. Requires v2.1.216+, macOS/Linux/WSL2 only.

```json
{
  "sandbox": {
    "enabled": true,
    "filesystem": { "disabled": true },
    "network": { "allowedDomains": ["github.com", "*.npmjs.org"] }
  }
}
```

Honored only from user settings, managed settings, or the `--settings` CLI flag — project settings (`.claude/settings.json`, `.claude/settings.local.json`) cannot set it. If managed settings configure `sandbox.filesystem` at all, or any `sandbox.credentials.files` entry uses `"mode": "deny"`, only managed settings can set the key thereafter. If `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` is set, the key is ignored from every source and filesystem isolation stays on.

Warn before recommending it: with filesystem isolation off and auto-allowed commands, a sandboxed command can write shell startup files, `$PATH` executables, or `~/.claude/settings.json` and widen its own access on the next run.

## Credential protection (`sandbox.credentials`)

> Source: https://code.claude.com/docs/en/sandboxing

Requires v2.1.187+. There is **no built-in credential deny list** — only what you list is restricted, and it applies to sandboxed Bash commands only.

```json
{
  "sandbox": {
    "enabled": true,
    "credentials": {
      "files": [
        { "path": "~/.aws/credentials", "mode": "deny" },
        { "path": "~/.ssh", "mode": "deny" }
      ],
      "envVars": [
        { "name": "GITHUB_TOKEN", "mode": "deny" },
        { "name": "NPM_TOKEN", "mode": "deny" }
      ]
    }
  }
}
```

`mode: "deny"` blocks file paths for reads (equivalent to `filesystem.denyRead`) and unsets env vars before each sandboxed command. File protection is part of the filesystem layer and does not apply when filesystem isolation is disabled; env-var protection still applies.

`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` strips Anthropic/cloud credentials from **all** subprocesses regardless of sandboxing.

### Masking (`mode: "mask"`)

Env vars require v2.1.199+; files require v2.1.221+. The sandboxed command sees a per-session **sentinel** placeholder and the sandbox proxy substitutes the real value on outbound requests to `injectHosts`. **Requires `network.tlsTerminate`** — the proxy must terminate TLS to substitute inside request contents. Without it masking fails safely: the sentinel reaches the server unchanged, auth fails, and Claude Code warns at startup.

```json
{
  "sandbox": {
    "enabled": true,
    "network": {
      "tlsTerminate": {},
      "allowedDomains": ["*.github.com", "registry.npmjs.org"]
    },
    "credentials": {
      "envVars": [
        { "name": "GH_TOKEN", "mode": "mask", "injectHosts": ["api.github.com"] },
        { "name": "NPM_TOKEN", "mode": "mask" }
      ]
    }
  }
}
```

- **AWS SigV4**: mask `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` **together**. The proxy detects SigV4 from the sentinel access key and re-signs after substitution; masking the secret alone breaks signing.
- Honored only from user settings, managed settings, or `--settings`. Never from a repo's `.claude/settings.json` / `.claude/settings.local.json`.
- If the same variable is `deny` in any scope, `deny` wins.

**Masked credential files are platform-dependent**: on Linux/WSL2 the sandboxed command reads a sentinel copy and the proxy substitutes on egress; on **macOS the file cannot be read at all** — same effect as `deny`, no sentinel, no substitution.

```json
{
  "sandbox": {
    "credentials": {
      "files": [{
        "path": "~/.config/gh/hosts.yml",
        "mode": "mask",
        "extract": "oauth_token:\\s*(\\S+)",
        "injectHosts": ["api.github.com"]
      }]
    }
  }
}
```

`extract` is a regex applied across the whole file; only capture group 1 of each match is replaced with the sentinel, so YAML/JSON structure stays parseable. Required for structured files (`.netrc`, JSON, YAML) — without it the entire file becomes one sentinel, which is fine only for bare-secret files. `onExtractNoMatch`: `warn` (default, unmasked read allowed), `deny` (file unreadable), `error` (stops sandbox setup). `maskDuplicates` (default false) also replaces verbatim copies of the captured value elsewhere in the file — reserve for long, high-entropy secrets. Masking falls back to `deny` for a directory path, a glob pattern, a file over 8 MiB, or a non-UTF-8 file.

## Network isolation

> Source: https://code.claude.com/docs/en/sandboxing

Traffic routes through a **proxy running outside the sandbox**. No domains are pre-allowed; first use of a new domain prompts. As of v2.1.191 choosing Yes allows the host for the rest of the session. `WebFetch` allow rules also pre-allow domains for the sandbox.

| Key | Effect |
|---|---|
| `allowedDomains` | Pre-allowed hosts; wildcards supported |
| `strictAllowlist: true` | Denies rather than prompts for hosts outside the allowlist (v2.1.219+). User/managed/`--settings` only; no effect from repo settings. In-process tools like WebFetch still follow their own permission rules |
| `allowManagedDomainsOnly` | Managed settings only — non-allowed domains blocked automatically; only managed-settings `allowedDomains` / `WebFetch(domain:...)` honored |
| `tlsTerminate` | Experimental (v2.1.199+); proxy terminates TLS itself. Required for credential masking |
| `httpProxyPort` / `socksProxyPort` | Point the sandbox at your own proxy |

```json
{ "sandbox": { "network": { "httpProxyPort": 8080, "socksProxyPort": 8081 } } }
```

By default the built-in proxy does **not** terminate or inspect TLS — it enforces the allowlist purely from the client-supplied hostname, so domain fronting can bypass it and broad grants such as `github.com` become exfiltration paths.

## Relationship to permissions

> Source: https://code.claude.com/docs/en/sandboxing

Permission rules gate every tool (Bash, Read, Edit, WebFetch, MCP) pre-execution from the command string plus classifier judgment in auto mode. Sandboxing is **OS-level enforcement on the running process**, applies only to Bash and its children, and holds regardless of model intent. `/sandbox` is not a permission mode.

`--dangerously-skip-permissions` is blocked when running as root/sudo on Linux/macOS unless inside a recognized sandbox — use the dev container (non-root) for autonomous container runs.

## Enterprise / managed settings

> Source: https://code.claude.com/docs/en/sandboxing

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "allowUnsandboxedCommands": false
  }
}
```

- Boolean keys (`enabled`, `failIfUnavailable`) — managed value wins, developer overrides ignored.
- Array keys (`excludedCommands`, `allowRead`, `allowedDomains`) — **merged** across scopes, so developers can widen them. Lock with `allowManagedReadPathsOnly: true` (read paths) and `allowManagedDomainsOnly` (network domains). `excludedCommands` has **no** managed-only lockdown — keep that list narrow.
- Add `sandbox.credentials` entries for `~/.aws`, `~/.ssh`, and secret env vars; the default read policy still allows them.
- The sandbox does not run on native Windows — scope managed config to macOS/Linux, or require WSL2/containers for Windows fleets.

## Troubleshooting

> Source: https://code.claude.com/docs/en/sandboxing

| Symptom | Cause / fix |
|---|---|
| Host-not-allowed error | Approve the prompt to add the host to the session allowlist, or pre-allow it |
| `jest` hangs | `watchman` is incompatible — run `jest --no-watchman` |
| Go CLIs (`gh`, `gcloud`, `terraform`) fail TLS verification on macOS | Add to `excludedCommands`, or set `enableWeakerNetworkIsolation: true` when using `httpProxyPort` with a MITM proxy + custom CA |
| `open`/`osascript`/browser auth fails with `-600` on macOS | Apple Events blocked by default. `allowAppleEvents: true` (user/managed/CLI settings only) lifts it but **removes code-execution isolation** |
| `docker` commands fail | Docker is incompatible with the sandbox — add `docker *` to `excludedCommands` |
| bubblewrap fails inside an unprivileged container | Cannot mount a fresh `/proc`. `enableWeakerNestedSandbox: true` bind-mounts the container's existing `/proc` — considerably weaker; only when the outer container already isolates |
| Unix domain sockets not blocked on Linux | Missing seccomp filter — `npm install -g @anthropic-ai/sandbox-runtime` |

## Documented limitations

> Source: https://code.claude.com/docs/en/sandboxing

Security: no TLS inspection by default (domain fronting, broad-domain exfiltration); `allowUnixSockets` misconfiguration can grant powerful system access (`/var/run/docker.sock` = full host access); overly broad `allowWrite` on `$PATH` dirs or shell configs enables privilege escalation; `enableWeakerNestedSandbox` and `allowAppleEvents` both weaken the boundary materially.

Scope — the sandbox isolates **Bash subprocesses only**:

- Built-in Read/Edit/Write use the permission system directly, not the sandbox.
- Computer use runs on the actual desktop, gated only by per-app permission prompts.
- Sandboxed Bash commands inherit the parent process environment (including credentials) by default.
- Subagents run in the same process as the parent session and share its sandbox config.

Performance overhead is minimal; some filesystem operations are slightly slower.

## Sources

- https://code.claude.com/docs/en/sandboxing

Fetched: 2026-08-05
