# Egress Control, Container Hardening, and Secrets for Agents

Read this for any network-policy, container-hardening, or credential-handling question about agent deployments. All facts as of 2026-08-05.

## Threat model and principles

> Source: https://code.claude.com/docs/en/agent-sdk/secure-deployment

Agents can take unintended actions from **prompt injection** (instructions embedded in processed content) or model error. Defense in depth remains good practice even though Claude models are designed to resist injection — if an agent processes a malicious file instructing it to send customer data externally, network controls block that request regardless of what the model decided.

Three principles for hardened deployments:

- **Security boundaries** — separate components by trust level. For high-security deployments keep sensitive resources (credentials) *outside* the boundary containing the agent; e.g. a proxy outside the agent's environment injects API keys so the agent never sees the credential.
- **Least privilege**:

| Resource | Restriction options |
|---|---|
| Filesystem | Mount only needed directories, prefer read-only |
| Network | Restrict to specific endpoints via proxy |
| Credentials | Inject via proxy rather than exposing directly |
| System capabilities | Drop Linux capabilities in containers |

- **Defense in depth** — layer container isolation + network restrictions + filesystem controls + request validation at a proxy.

Relevant built-in Claude Code features: the permissions system (allow/block/prompt per tool/command, org-wide policy) with commands parsed into an AST matched against rules before execution — note the doc's own caveat, "This is a permission gate, not a sandbox; it does not infer whether a command is dangerous from its target path or effects" (a small set of constructs such as `eval` always require approval regardless of allow rules); WebFetch result summarization, which reduces prompt-injection risk from raw web content; and sandbox mode.

## Isolation technology tradeoffs

> Source: https://code.claude.com/docs/en/agent-sdk/secure-deployment

| Technology | Isolation strength | Performance overhead | Complexity |
|---|---|---|---|
| Sandbox runtime | Good (secure defaults) | Very low | Low |
| Containers (Docker) | Setup dependent | Low | Medium |
| gVisor | Excellent (with correct setup) | Medium/high | Medium |
| VMs (Firecracker, QEMU) | Excellent (with correct setup) | High | Medium/high |

In every configuration Claude Code (or the Agent SDK app) runs **inside** the isolation boundary — the controls restrict what the agent can access from within it.

### Sandbox runtime

No Docker config, images, or networking required; proxy and filesystem restrictions are built in and you supply a settings file of allowed domains and paths. Two explicitly called-out considerations:

1. **Same-host kernel** — sandboxed processes share the host kernel unlike VMs; a kernel vulnerability could theoretically enable escape. Use gVisor or a separate VM if you need kernel-level isolation.
2. **No TLS inspection** — the proxy allowlists by client-supplied hostname only; code inside can potentially use domain fronting to reach hosts outside the allowlist. Use a TLS-terminating proxy if your threat model requires stronger guarantees. Separately, if the agent has permissive credentials for an allowed domain, ensure it cannot use that domain to trigger other requests or exfiltrate data.

Per the doc: "For many single-developer and CI/CD use cases, sandbox-runtime raises the bar significantly with minimal setup."

### Containers

Isolation via Linux namespaces — own filesystem, process tree, and network stack view, with a shared host kernel. Hardened example:

```bash
docker run \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --security-opt seccomp=/path/to/seccomp-profile.json \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  --tmpfs /home/agent:rw,noexec,nosuid,size=500m \
  --network none \
  --memory 2g \
  --cpus 2 \
  --pids-limit 100 \
  --user 1000:1000 \
  -v /path/to/code:/workspace:ro \
  -v /var/run/proxy.sock:/var/run/proxy.sock:ro \
  agent-image
```

| Option | Purpose |
|---|---|
| `--cap-drop ALL` | Removes capabilities like `NET_ADMIN`/`SYS_ADMIN` that enable privilege escalation |
| `--security-opt no-new-privileges` | Prevents gaining privileges via setuid binaries |
| `--security-opt seccomp=...` | Restricts syscalls; Docker's default blocks ~44, custom profiles can block more |
| `--read-only` | Immutable root filesystem — the agent cannot persist changes |
| `--tmpfs /tmp:...` | Writable temp dir cleared on container stop |
| `--network none` | Removes all network interfaces — only path out is the mounted Unix socket |
| `--memory 2g` | Caps memory to prevent resource exhaustion |
| `--pids-limit 100` | Caps process count to prevent fork bombs |
| `--user 1000:1000` | Non-root |
| `-v code:/workspace:ro` | Read-only code mount — **avoid mounting `~/.ssh`, `~/.aws`, `~/.config`** |
| `-v proxy.sock:...` | Unix socket to a proxy running **outside** the container |

**Unix socket architecture**: with `--network none` the container has zero network interfaces, so the only path outward is the mounted Unix socket to a host-side proxy enforcing domain allowlists, injecting credentials, and logging traffic — the same architecture sandbox-runtime uses. Per the doc: "Even if the agent is compromised via prompt injection, it cannot exfiltrate data to arbitrary servers. It can only communicate through the proxy."

Additional hardening: `--userns-remap` (maps container root to an unprivileged host user; needs daemon config, limits container-escape damage) and `--ipc private` (isolates IPC to prevent cross-container attacks).

### gVisor

Standard containers share the host kernel, so a syscall from inside goes straight to it and a kernel vulnerability can enable escape. gVisor intercepts syscalls in **userspace** via its own compatibility layer before they reach the host kernel; malicious code must first exploit gVisor's userspace implementation and has limited access to the real kernel.

```json
// /etc/docker/daemon.json
{ "runtimes": { "runsc": { "path": "/usr/local/bin/runsc" } } }
```

```bash
docker run --runtime=runsc agent-image
```

| Workload | Overhead |
|---|---|
| CPU-bound computation | ~0% (no syscall interception) |
| Simple syscalls | ~2x slower |
| File I/O intensive | Up to 10–200x slower for heavy open/close patterns |

"For multi-tenant environments or when processing untrusted content, the additional isolation is often worth the overhead."

### Virtual machines

Hardware-level isolation via CPU virtualization extensions; each VM has its own kernel, so a guest kernel vulnerability does not directly compromise the host. Explicitly noted: VMs "aren't automatically 'more secure'" than gVisor — VM security depends heavily on the hypervisor and device emulation code.

**Firecracker**: lightweight microVM isolation, booting VMs in under **125 ms** with less than **5 MiB** memory overhead by stripping unnecessary device emulation. Pattern: the agent VM has **no external network interface** and communicates only via `vsock`, with all traffic routed through vsock to a host-side proxy that enforces allowlists and injects credentials before forwarding.

### Cloud deployments

1. Run agent containers in a private subnet with **no internet gateway**.
2. Cloud firewall rules (AWS Security Groups, GCP VPC firewall) block all egress except to your proxy.
3. Run a proxy (e.g. Envoy with its `credential_injector` filter) that validates requests, enforces domain allowlists, injects credentials, and forwards to external APIs.
4. Assign minimal IAM permissions to the agent's service account; route sensitive access through the proxy where possible.
5. Log all traffic at the proxy for audit.

## Credential management — the proxy pattern

> Source: https://code.claude.com/docs/en/agent-sdk/secure-deployment

A proxy **outside the agent's security boundary** injects credentials into outgoing requests: the agent sends requests without credentials, the proxy adds them and forwards. Benefits — the agent never sees actual credentials; the proxy enforces an endpoint allowlist; every request is logged for audit; credentials live in one secure location rather than distributed to every agent instance.

### Pointing Claude Code at a proxy

**Option 1 — `ANTHROPIC_BASE_URL`** (simple, sampling API only):

```bash
export ANTHROPIC_BASE_URL="http://localhost:8080"
```

The proxy receives plaintext HTTP, can inspect and modify (inject credentials), and forwards to the real API.

**Option 2 — `HTTP_PROXY` / `HTTPS_PROXY`** (system-wide):

```bash
export HTTP_PROXY="http://localhost:8080"
export HTTPS_PROXY="http://localhost:8080"
```

Routes all HTTP traffic through the proxy; for HTTPS the proxy creates an encrypted CONNECT tunnel and **cannot see or modify contents without TLS interception**.

Named implementations: Envoy Proxy (`credential_injector` filter), mitmproxy (TLS-terminating), Squid (caching + ACLs), LiteLLM (LLM gateway with credential injection and rate limiting).

### Credentials for non-Claude-API services (git, databases, internal APIs)

**Custom tool / MCP server pattern** — an MCP server or custom tool routes requests to a service running **outside** the agent's boundary; the agent calls the tool and the authenticated request happens outside (e.g. a git MCP server forwards commands to a host-side git proxy that adds auth). No TLS interception needed and credentials never reach the agent.

**Traffic forwarding (TLS-terminating proxy)** — for arbitrary HTTPS services where traffic is encrypted end-to-end even through `HTTP_PROXY`, you need a proxy that decrypts, inspects/modifies, then re-encrypts. Requires: (1) the proxy runs outside the agent's container, (2) the proxy's CA cert is installed in the agent's trust store, (3) `HTTP_PROXY`/`HTTPS_PROXY` route through it. Handles any HTTP-based service without custom tools, at the cost of cert-management complexity.

Caveat: not all tools respect `HTTP_PROXY`/`HTTPS_PROXY`. `curl`, `pip`, `npm`, and `git` do; **Node.js `fetch()` ignores them by default** (Node 24+: set `NODE_USE_ENV_PROXY=1`). For comprehensive coverage use proxychains or configure iptables to redirect outbound traffic to a transparent proxy — "A transparent proxy intercepts traffic at the network level so the client doesn't need explicit configuration."

## Filesystem configuration

> Source: https://code.claude.com/docs/en/agent-sdk/secure-deployment

Read-only code mount: `docker run -v /path/to/code:/workspace:ro agent-image`.

Even **read-only** access can expose credentials. Exclude or sanitize before mounting:

| File | Risk |
|---|---|
| `.env`, `.env.local` | API keys, DB passwords, secrets |
| `~/.git-credentials` | Git passwords/tokens in plaintext |
| `~/.aws/credentials` | AWS access keys |
| `~/.config/gcloud/application_default_credentials.json` | Google Cloud ADC tokens |
| `~/.azure/` | Azure CLI credentials |
| `~/.docker/config.json` | Docker registry auth tokens |
| `~/.kube/config` | Kubernetes cluster credentials |
| `.npmrc`, `.pypirc` | Package registry tokens |
| `*-service-account.json` | GCP service account keys |
| `*.pem`, `*.key` | Private keys |

Writable locations — `tmpfs` mounts for ephemeral workspaces, cleared on container stop:

```bash
docker run \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  --tmpfs /workspace:rw,noexec,size=500m \
  agent-image
```

For reviewable changes, an overlay filesystem lets the agent write to a separate layer you inspect, apply, or discard before touching underlying files. For persistent output, mount a dedicated volume kept separate from sensitive directories.

## Claude Code egress domain allowlist

> Source: https://code.claude.com/docs/en/network-config

Allowlist these in proxy/firewall rules, especially in containerized or restricted networks:

| URL | Required for |
|---|---|
| `api.anthropic.com` | Claude API requests including WebFetch domain-safety check, feature-flag fetches, telemetry logging |
| `claude.ai` | claude.ai account authentication |
| `claude.com` | Sign-in browser redirect target; pre-approved WebFetch doc lookups |
| `platform.claude.com` | Anthropic Console auth; OAuth token exchange/refresh/revocation for claude.ai accounts too |
| `mcp-proxy.anthropic.com` | MCP connectors from claude.ai (default-on; disable via `ENABLE_CLAUDEAI_MCP_SERVERS=false` or `disableClaudeAiConnectors`) |
| `downloads.claude.ai` | Plugin downloads; native installer/auto-updater |
| `storage.googleapis.com` | Install counts/plugin metadata for `/plugin`; artifact upload fallback; native installer pre-v2.1.116 |
| `bridge.claudeusercontent.com` | Claude in Chrome extension WebSocket bridge |
| `raw.githubusercontent.com` | Changelog feed for `/release-notes` |
| `http-intake.logs.us5.datadoghq.com` | Operational telemetry (direct Anthropic API only, never Bedrock/Vertex/Foundry) — optional |
| `browser-intake-us5-datadoghq.com` | Operational error reports — optional |
| `formulae.brew.sh` | Update checks for Homebrew installs only |
| `code.claude.com` | Doc lookups by the built-in claude-code-guide agent; blocking only affects doc lookups |

npm/bun installs additionally need `registry.npmjs.org` unless the org mirrors it. The two Datadog hosts are optional telemetry — `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` disables both (also `DISABLE_TELEMETRY`/`DO_NOT_TRACK` and `DISABLE_ERROR_REPORTING` respectively). Sessions on Bedrock/Vertex/Foundry route model traffic and auth to the provider instead of `api.anthropic.com`/`claude.ai`/`platform.claude.com`, but WebFetch's domain-safety check still calls `api.anthropic.com` unless `skipWebFetchPreflight: true`.

### Proxy environment variables

```bash
export HTTPS_PROXY=https://proxy.example.com:8080
export HTTP_PROXY=http://proxy.example.com:8080
export NO_PROXY="localhost 192.168.1.1 example.com .example.com"   # space-separated
export NO_PROXY="localhost,192.168.1.1,example.com,.example.com"   # or comma-separated
export NO_PROXY="*"                                                 # bypass everything
```

Lowercase variants work; Claude Code uses the first set variable in the order `https_proxy`, `HTTPS_PROXY`, `http_proxy`, `HTTP_PROXY`. **SOCKS proxies are not supported.** Basic auth is embedded in the URL (`http://username:password@proxy.example.com:8080`) — avoid hardcoding it in scripts. For NTLM/Kerberos, use an LLM Gateway service that supports it.

### CA and mTLS for enterprise egress proxies

`CLAUDE_CODE_CERT_STORE` (comma-separated `bundled` and/or `system`, default `bundled,system`) — reading the OS store needs a runtime with `tls.getCACertificates` (the native installer always has it; npm installs need Node 22.15+). `NODE_EXTRA_CA_CERTS=/path/to/ca-cert.pem` trusts a custom CA directly.

```bash
export CLAUDE_CODE_CLIENT_CERT=/path/to/client-cert.pem
export CLAUDE_CODE_CLIENT_KEY=/path/to/client-key.pem
export CLAUDE_CODE_CLIENT_KEY_PASSPHRASE="your-passphrase"   # optional
```

Certs are re-read at startup and whenever settings change during a session, so rotate by replacing the files at the same path. In Claude Code on the web these variables plus `NODE_TLS_REJECT_UNAUTHORIZED` and `CLAUDE_CODE_OAUTH_SCOPES` are **ignored** when set via a settings-file `env` block — the hosting environment manages the connection.

Verify with `claude --debug` (log at `~/.claude/debug/<session-id>.txt`, or `--debug-file <path>`), which prints lines such as `CA certs: Appended extra certificates from NODE_EXTRA_CA_CERTS (...)` and `mTLS: Loaded client certificate from CLAUDE_CODE_CLIENT_CERT`; or run `/status` interactively for the **Proxy**, **mTLS client cert/key**, and **Additional CA cert(s)** rows.

## Choosing an environment and enforcing it org-wide

> Source: https://code.claude.com/docs/en/sandbox-environments

| Goal | Start with |
|---|---|
| Reduce permission prompts during everyday local work | Sandboxed Bash tool via `/sandbox` |
| Unattended work with `--dangerously-skip-permissions` or auto mode | Preconfigured dev container, any container/VM, or the sandbox runtime |
| Isolate MCP servers and hooks too, without Docker | Sandbox runtime |
| Work on an untrusted repository | A dedicated VM, or Claude Code on the web |
| Standardize a sandboxed environment across a team | Preconfigured dev container, committed to the repo |
| Use Claude Code from a device with no local setup | Claude Code on the web |
| Work on a native Windows host | A container/VM, or the Bash sandbox inside WSL2 |

Warning from the doc: sandbox isolation reduces breach impact but does not eliminate risk. Any approach allowing network egress can still leak data the agent can read; any approach mounting the project directory writable can still modify that code. Isolation also does not change what is sent to the model — prompts and files Claude reads still go to the Anthropic API (or configured provider) with or without a sandbox.

**Permission-mode interaction**: with `--dangerously-skip-permissions` you are only prompted for explicit ask rules, org-flagged connector tools, MCP tools marked `requiresUserInteraction`, and removals targeting `/` or home — so **the isolation boundary is what protects your system**. Claude Code refuses to start with the flag as root on Linux/macOS. **Auto mode** replaces the prompt with a classifier that blocks escalation, unrecognized-infrastructure targeting, and hostile-content-driven actions; that classifier is a per-action control, not an isolation boundary. The sandboxed Bash tool alone is **not sufficient for fully unattended runs** in either mode; layering it inside a container/VM is valid defense in depth.

**Custom containers**: any Docker/OCI image with your own network policies, mounted volumes, and seccomp profiles — the most common path for orgs with existing container infra or CI runners, and managed sandbox/remote-execution services can host it. The same checklist applies regardless of who hosts it: review what is mounted writable, what credentials are reachable inside, and what the egress policy allows. Unprivileged containers running the inner Bash sandbox need `enableWeakerNestedSandbox`.

**Claude Code on the web**: each session runs in an isolated, Anthropic-managed VM. A network proxy enforces a default allowlist, and a separate proxy holds your GitHub token **outside** the sandbox while issuing scoped credentials for repo access inside it. Requires a Claude subscription; web-launched sessions need a connected GitHub account, while CLI launch with `--cloud` can bundle/upload the local repo without GitHub.

**Enforcement across an organization:**

| Approach | Enforcement mechanism |
|---|---|
| Built-in Bash sandbox | The only approach Claude Code enforces itself — deliver `sandbox` keys via managed settings (MDM file or Claude.ai server-managed settings) |
| Dev containers | Committing the example standardizes the environment but is a **convention, not an enforcement boundary** — use device management / software allowlisting to prevent running outside it |
| Custom containers and VMs | Distribute Claude Code only through the approved image; block installs outside it with device management / software allowlisting |

## Sources

- https://code.claude.com/docs/en/agent-sdk/secure-deployment
- https://code.claude.com/docs/en/network-config
- https://code.claude.com/docs/en/sandbox-environments

Fetched: 2026-08-05
