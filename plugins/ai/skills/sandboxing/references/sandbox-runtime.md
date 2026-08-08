# Sandbox Runtime (`srt`) — Mechanics and Configuration

`@anthropic-ai/sandbox-runtime` applies OS-level filesystem and network isolation to an entire process without a container. Read this when isolating MCP servers and hooks (not just Bash), or when Docker is unavailable. All facts as of 2026-08-05.

## What it is

> Source: https://github.com/anthropic-experimental/sandbox-runtime
> Source: https://www.anthropic.com/engineering/claude-code-sandboxing

Apache-2.0 OS-level sandboxing tool and library for enforcing filesystem and network restrictions on arbitrary processes without requiring a container. Used to secure AI agents, MCP servers, and arbitrary commands. Status: **beta research preview** — open-sourced for ecosystem adoption; the configuration format may still change.

Design philosophy is **secure-by-default**: processes start with minimal access and you explicitly grant what is needed.

Motivation per Anthropic's engineering blog: sandboxing was built primarily to cut permission-prompt fatigue — "sandboxing safely reduces permission prompts by 84%" in internal Anthropic usage — because constant approval clicking is itself a security risk once users stop reading prompts. Anthropic states that effective sandboxing requires **both** filesystem and network isolation: filesystem isolation stops a prompt-injected agent modifying sensitive system files; network isolation stops it leaking data or downloading malware.

## Install and CLI

> Source: https://github.com/anthropic-experimental/sandbox-runtime

```bash
npm install -g @anthropic-ai/sandbox-runtime
```

| Platform | Dependencies |
|---|---|
| Linux | `bubblewrap`, `socat`, `ripgrep` |
| macOS | `ripgrep` (Homebrew); uses built-in Seatbelt |
| Windows | None (bundled `srt-win.exe`); one-time elevated `windows-install` |

```bash
srt "curl example.com"
srt --settings /path/to/srt-settings.json npm install
srt --debug <command>
```

Default config location `~/.srt-settings.json`, overridable with `--settings`.

### Wrapping the whole Claude Code process

> Source: https://code.claude.com/docs/en/sandbox-environments

```bash
npx @anthropic-ai/sandbox-runtime claude
```

By default the runtime **denies all network access** and confines writes to a small set of built-in runtime paths, so it must be configured *before* first launch.

Minimum recommended `allowWrite`: the project directory, `~/.claude` and `~/.claude.json` (Claude Code config), and `/tmp` (runtime files).

Minimum recommended `allowedDomains`: `api.anthropic.com` (or your provider's endpoint — WebFetch's domain-safety preflight calls it by default unless `skipWebFetchPreflight: true`), plus `claude.ai` and `platform.claude.com` for OAuth sign-in and token refresh. API-key-only runs can drop the latter two.

On Linux/WSL2 write grants apply only to paths that **already exist** — create Claude Code's config before first launch:

```bash
mkdir -p ~/.claude && echo '{}' > ~/.claude.json
```

## Configuration schema

> Source: https://github.com/anthropic-experimental/sandbox-runtime

### Network — allow-only (everything denied unless explicitly allowed)

```json
{
  "network": {
    "allowedDomains": ["github.com", "*.npmjs.org"],
    "deniedDomains": ["malicious.com"],
    "deniedDomainReasons": { "github.com:22": "SSH pushes blocked; use https://" },
    "allowLocalBinding": false,
    "allowUnixSockets": ["/var/run/docker.sock"],
    "tlsTerminate": {
      "excludeDomains": ["internal-mtls.example.net"],
      "extraCaCertPaths": ["/etc/custom-roots.pem"]
    }
  }
}
```

Domains support wildcards (`*.example.com`) and optional port suffixes (`api.example.com:443`).

### Filesystem — dual patterns

Reads are **deny-then-allow** (allowed by default); writes are **allow-only** (denied by default):

```json
{
  "filesystem": {
    "denyRead": ["~/.ssh"],
    "allowRead": ["."],
    "allowWrite": [".", "/tmp"],
    "denyWrite": [".env", "secrets/"]
  }
}
```

Path syntax: macOS supports git-style globs (`*.ts`, `src/**/*.json`, `[abc]` ranges); **Linux supports literal paths only**; all platforms support `~` expansion plus absolute and relative paths.

### Other settings

```json
{
  "ignoreViolations": { "*": ["/usr/bin"], "git push": ["/usr/bin/nc"] },
  "enableWeakerNestedSandbox": false,
  "enableWeakerNetworkIsolation": false,
  "allowAppleEvents": false,
  "mandatoryDenySearchDepth": 3,
  "windows": { "proxyPortRange": [60080, 60089], "sublayerGuid": "..." }
}
```

### Mandatory deny paths

Always write-blocked regardless of config: shell configs (`.bashrc`, `.zshrc`), git configs (`.gitconfig`, `.git/hooks/`), IDE dirs (`.vscode/`, `.idea/`), Claude configs (`.claude/commands/`).

> Source: https://code.claude.com/docs/en/sandbox-environments

The runtime also blocks high-risk writes with **no configuration needed**:

- `denyWrite` always takes precedence over `allowWrite`.
- At project root: denies `.git/hooks`, `.git/config` (unless `filesystem.allowGitConfig: true`), `.mcp.json`, `.claude/commands`, `.claude/agents`, and shell startup files.
- **macOS** checks denies per-write, so nested files and repos created mid-session are covered.
- **Linux/WSL2** builds the deny list **once at launch** — reliably covers the project root, best-effort shallow scan for nested copies existing at launch, and does **not** cover things created later (`git init`, `git clone`, scaffolding).
- Without a valid `~/.srt-settings.json` the runtime still starts, blocks all network, and confines writes to built-in runtime paths (`/tmp/claude`, `~/.npm/_logs`, `~/.claude/debug`) — **a clean start is not proof your settings loaded**. With `--settings` passed explicitly, a load failure refuses to start (fails closed).

## Platform mechanisms

> Source: https://github.com/anthropic-experimental/sandbox-runtime
> Source: https://www.anthropic.com/engineering/claude-code-sandboxing

### macOS — Seatbelt profiles + localhost proxy

`sandbox-exec` runs commands under a dynamically generated Seatbelt profile. Filesystem: the profile specifies allowed read/write paths via glob patterns. Network: the profile restricts communication to specific **localhost ports** where the proxy servers listen; all other network access is blocked. Violations are monitored in real time by tapping the macOS system sandbox violation log store.

### Linux — bubblewrap + Unix domain sockets + seccomp

`bubblewrap` creates isolated PID, network, and mount namespaces. Filesystem uses bind mounts with read-only/read-write flags, with glob-pattern matching done via `ripgrep` scanning. Network: the **network namespace is removed from the bubblewrap container entirely**, so all traffic must traverse Unix domain socket proxies bridged by `socat`. A static seccomp BPF filter (x64/arm64) blocks `AF_UNIX` socket creation at the syscall level, applied in two stages using a nested PID namespace for isolation. Violation monitoring is manual, via `strace` — there is no automatic log store like macOS. Requires `kernel.apparmor_restrict_unprivileged_userns=0` on Ubuntu 24.04+.

### Windows (alpha) — WFP filter + dedicated sandbox account

Runs under a dedicated `srt-sandbox` local user account with a DPAPI-encrypted password. Network isolation uses a machine-wide **WFP `ALE_AUTH_CONNECT` filter** that blocks every outbound connect from the sandbox SID except loopback to the configured proxy port range (default `60080–60089`). Proxy env vars (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`) point tools at the proxies, but **the WFP filter, not the env vars, is the enforced boundary** — a process that unsets them is still fenced. Filesystem isolation is additive, inheriting NTFS ACEs on configured paths (ALLOW for `allowRead`/`allowWrite`, DENY for denies). Setup is a one-time elevated `windows-install`, idempotent (re-running rotates the sandbox account password).

## Proxy / egress design

> Source: https://github.com/anthropic-experimental/sandbox-runtime

Two proxy servers run **on the host, outside the sandbox**: an **HTTP proxy** that intercepts HTTP/HTTPS and validates against `allowedDomains`/`deniedDomains`, and a **SOCKS5 proxy** for other TCP (SSH, database connections).

| Platform | Routing to the proxies |
|---|---|
| Linux | Unix domain sockets (network namespace removed; sockets bind-mounted into the sandbox) |
| macOS | Localhost ports (Seatbelt profile restricts to those ports) |
| Windows | Loopback + WFP filter (proxies bind inside the configured port range) |

**TLS termination** (`network.tlsTerminate`): HTTPS CONNECTs are terminated in-process for inspection via `filterRequest`; a MITM CA signs intercepted certs while real upstream certs stay verifiable. `excludeDomains` bypasses termination for mTLS and cert-pinning clients.

**Permission prompt flow**: sandboxed process attempts restricted access → OS-level block returns `EPERM` → violation logged (platform-specific) → the embedding app (e.g. Claude Code) triggers a user permission prompt → user grants or denies; sandbox continues or terminates.

## Documented limitations

> Source: https://github.com/anthropic-experimental/sandbox-runtime

- **Network** — verbatim: "The network filtering system operates by restricting the domains that processes are allowed to connect to. It does not otherwise inspect the traffic passing through the proxy and users are responsible for ensuring they only allow trusted domains in their policy." Domain fronting may bypass filtering; broad allowlists such as `github.com` enable exfiltration to any repo on that host.
- **Filesystem** — overly broad write grants (`$PATH` dirs, shell configs) enable privilege escalation; on Linux mandatory-deny paths only block files existing at launch.
- **Unix sockets** (macOS/Linux) — `allowUnixSockets` can grant powerful system-service access; `/var/run/docker.sock` is effective host access.
- **Linux** — `enableWeakerNestedSandbox` weakens security for Docker compatibility; needs `kernel.apparmor_restrict_unprivileged_userns=0` on Ubuntu 24.04+; proxy bypass is possible via programs that ignore `HTTP_PROXY`.
- **macOS** — `enableWeakerNetworkIsolation` re-enables `com.apple.trustd.agent` for Go TLS verification, opening a data-exfiltration vector. `allowAppleEvents` enables `(allow appleevent-send)` and `(allow lsopen)`, removing code-execution isolation because launched apps run outside the sandbox.
- **Windows** — cert revocation checks (CRL/OCSP) are blocked by the WFP filter (workaround: `git -c http.schannelCheckRevoke=false`); per-user tool installs are unreachable, so prefer machine-wide installs; per-exec `filesystem.allowRead`/`allowWrite` overrides are unsupported; the proxy auth token is visible in the runner's command line to local principals with process-query access.

## Library usage (JS/TS)

> Source: https://github.com/anthropic-experimental/sandbox-runtime

```javascript
import { SandboxManager } from '@anthropic-ai/sandbox-runtime'

const config = {
  network: { allowedDomains: ['example.com'] },
  filesystem: { allowWrite: ['.'], denyWrite: ['.env'] }
}

await SandboxManager.initialize(config)
const wrapped = await SandboxManager.wrapWithSandbox('curl https://example.com')
// Execute wrapped command
await SandboxManager.reset()
```

Key exports: `SandboxManager`, `SandboxViolationStore`, and TypeScript config-schema type definitions.

## Versus the built-in Bash sandbox

> Source: https://code.claude.com/docs/en/sandbox-environments

| Approach | What is isolated | Requires Docker |
|---|---|---|
| Sandboxed Bash tool (built into Claude Code) | Bash commands + child processes only | No |
| Sandbox runtime | The **whole** Claude Code process — file tools, MCP servers, hooks | No |

The sandboxed Bash tool leaves built-in file tools, MCP servers, and hooks running unconstrained on the host. Sandbox-runtime puts the entire process inside one OS boundary, which is why Anthropic recommends it (or a dev container, custom container, or VM) for any deployment using `--dangerously-skip-permissions` or fully unattended runs.

## Sources

- https://github.com/anthropic-experimental/sandbox-runtime
- https://www.anthropic.com/engineering/claude-code-sandboxing
- https://code.claude.com/docs/en/sandbox-environments

Fetched: 2026-08-05
