# Claude Code 2.1.x — Sandbox Feature Version Gates

Read before promising a sandbox capability to a fleet on a pinned Claude Code version. All gates below are stated verbatim in the source docs as of 2026-08-05; anything not listed here has no documented minimum version.

## Version gate table

> Source: https://code.claude.com/docs/en/sandboxing

| Minimum version | Capability |
|---|---|
| v2.1.187+ | `sandbox.credentials` — credential file and env-var protection (`mode: "deny"`) |
| v2.1.191 | Approving a network prompt with Yes allows that host **for the rest of the session** (prior behavior did not persist the grant) |
| v2.1.199+ | `sandbox.credentials.envVars` with `mode: "mask"`; `sandbox.network.tlsTerminate` (experimental) |
| v2.1.210+ | Symlink targets resolving to a protected settings path are also write-denied |
| v2.1.212+ | A bare `Bash` or `Bash(*)` ask rule is skipped for sandboxed commands, **except in plan mode** where it still prompts |
| v2.1.216+ | `sandbox.filesystem.disabled` — network-only sandbox (macOS/Linux/WSL2 only) |
| v2.1.218+ | Classifier routing in auto mode for `rm`/`rmdir` targeting `/`, home, or critical paths |
| v2.1.219+ | `sandbox.network.strictAllowlist` — deny rather than prompt for non-allowlisted hosts |
| v2.1.221+ | `sandbox.credentials.files` with `mode: "mask"` (sentinel file contents; Linux/WSL2 only in effect — macOS degrades to deny) |

## Related non-Claude-Code version dependencies

> Source: https://code.claude.com/docs/en/network-config

- **Node 22.15+** — required for npm installs to read the OS certificate store via `CLAUDE_CODE_CERT_STORE` (needs a runtime with `tls.getCACertificates`). The native installer always has it.
- **Node 24+** — `NODE_USE_ENV_PROXY=1` makes Node's `fetch()` honor `HTTP_PROXY`/`HTTPS_PROXY`; below that, `fetch()` ignores proxy env vars entirely, so agent code using `fetch()` bypasses a proxy-based egress control unless traffic is intercepted transparently.
- **Pre-v2.1.116** — the native installer used `storage.googleapis.com`; newer versions use `downloads.claude.ai`. Allowlist both when supporting mixed fleets.

## Practical implications for rollout planning

- A fleet pinned below **v2.1.187** has **no credential protection at all** in the Bash sandbox, and the default read policy still allows `~/.aws/credentials` and `~/.ssh/`. Use `filesystem.denyRead` there, or move the whole process into a container.
- A fleet pinned below **v2.1.219** cannot hard-deny non-allowlisted hosts; it can only prompt. For unattended runs on those versions, enforce egress outside the process (container firewall or corporate proxy) rather than relying on `allowedDomains`.
- Credential masking is only safe from **v2.1.199** (env vars) / **v2.1.221** (files) *and* requires `tlsTerminate`, itself experimental from v2.1.199. Prefer `mode: "deny"` plus a credential-injecting proxy on any version where masking is unavailable or unproven.

## Sources

- https://code.claude.com/docs/en/sandboxing
- https://code.claude.com/docs/en/network-config

Fetched: 2026-08-05
