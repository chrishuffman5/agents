# Dev Container Isolation and the init-firewall Egress Allowlist

Read this when building or reviewing a containerized agent development environment. All facts as of 2026-08-05.

## What a dev container isolates

> Source: https://code.claude.com/docs/en/devcontainer

A development container defines an identical, isolated environment every engineer runs. With Claude Code installed inside, commands Claude runs execute **inside the container**, while edits to project files appear on the host repo through the bind mount. Architecture: a Docker container (local or a cloud host such as GitHub Codespaces) plus an editor supporting the Dev Containers spec (VS Code, GitHub Codespaces, JetBrains, Cursor). Terminal, language servers, and build tools all run inside the container, not on the host. Editors without dev container support (plain Vim) are not part of this workflow.

**Warning to repeat to users**: while the dev container provides substantial protections, no system is completely immune. When executed with `--dangerously-skip-permissions`, dev containers do **not** prevent a malicious project from exfiltrating anything accessible inside the container, **including Claude Code credentials stored in `~/.claude`**. Use dev containers only with **trusted** repositories, and monitor Claude's activities. Avoid mounting host secrets such as `~/.ssh` or cloud credential files; prefer repository-scoped or short-lived tokens.

## Adding Claude Code

> Source: https://code.claude.com/docs/en/devcontainer

```json
// .devcontainer/devcontainer.json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/anthropics/devcontainer-features/claude-code:1.0": {}
  }
}
```

The `:1.0` tag pins the **feature's install script**, not the Claude Code release — the feature always installs the latest Claude Code, which then auto-updates itself inside the container by default. If the base image lacks Node.js and the build fails with `Failed to install Node.js and npm`, add `"ghcr.io/devcontainers/features/node:1": {}` above the Claude Code feature.

Rebuild via Command Palette → **Dev Containers: Rebuild Container**, then run `claude` in the container terminal to authenticate. For Bedrock/Vertex/Foundry, pass credentials via `containerEnv`, a Codespaces secret, or workload identity — **not** mounted host credential files.

## Persisting auth and settings across rebuilds

> Source: https://code.claude.com/docs/en/devcontainer

The container home directory is discarded on rebuild. Claude Code stores the auth token, settings, and session history under `~/.claude`, but the OAuth account, personal MCP servers, and per-project trust live in a **separate** file `~/.claude.json` — mounting a volume at `~/.claude` alone does not preserve sign-in. Mount a named volume **and** set `CLAUDE_CONFIG_DIR` to the same path:

```json
"mounts": [
  "source=claude-code-config,target=/home/node/.claude,type=volume"
],
"containerEnv": {
  "CLAUDE_CONFIG_DIR": "/home/node/.claude"
}
```

The reference config uses `source=claude-code-config-${devcontainerId}` to isolate state per project. In GitHub Codespaces `~/.claude` persists across stop/start but clears on rebuild — the same volume config applies. To carry auth across codespaces, store `ANTHROPIC_API_KEY` or a `claude setup-token` long-lived `CLAUDE_CODE_OAUTH_TOKEN` as a Codespaces secret (auto-exposed as an env var).

## Organization policy inside the container

> Source: https://code.claude.com/docs/en/devcontainer

Claude Code reads `/etc/claude-code/managed-settings.json` on Linux at **highest precedence**:

```dockerfile
RUN mkdir -p /etc/claude-code
COPY managed-settings.json /etc/claude-code/managed-settings.json
```

Caveat: the Dockerfile lives in the repo, so anyone with write access can alter or remove this step. For policy engineers cannot bypass, deliver via server-managed settings (Claude.ai admin console) or MDM.

```json
"containerEnv": {
  "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
  "DISABLE_AUTOUPDATER": "1"
}
```

`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` also disables the feature-flag evaluation Remote Control depends on. Because the Dev Container Feature always installs latest, pin a version for reproducible builds with `npm install -g @anthropic-ai/claude-code@X.Y.Z` in the Dockerfile plus `DISABLE_AUTOUPDATER`.

MCP servers: define at **project scope** in a `.mcp.json` at the repo root (checked in alongside the devcontainer config), install stdio-server binary dependencies in the Dockerfile, and add remote server domains to the network allowlist.

## Restricting network egress

> Source: https://code.claude.com/docs/en/devcontainer

The reference container ships `init-firewall.sh`, which blocks all outbound traffic except needed domains. Running a firewall inside a container needs extra Docker capabilities — the reference adds `NET_ADMIN` and `NET_RAW` via `runArgs`. **These capabilities and the firewall script are not required for Claude Code itself** and can be omitted if you rely on external network controls such as a corporate egress proxy.

### init-firewall.sh mechanics

> Source: https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh

Script safety: `set -euo pipefail` with `IFS=$'\n\t'` — strict word splitting, exits on any error, undefined var, or pipeline failure.

Default-deny policy first:

```bash
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
```

Foundational allow rules, before restrictions apply:

```bash
# DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
# SSH
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
# Localhost
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
# Docker host network
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT
```

Stateful connection tracking:

```bash
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```

Allowed destinations live in an `ipset` of type `hash:net`, which accepts both individual IPs and CIDR ranges:

```bash
ipset create allowed-domains hash:net
# ... populate with CIDRs/IPs ...
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited
```

`REJECT` rather than `DROP` for the catch-all so blocked connections give immediate diagnostic feedback instead of hanging until timeout.

**Sources populated into the ipset:**

- Dynamic: the GitHub API meta endpoint `https://api.github.com/meta` → `.web[]`, `.api[]`, `.git[]` CIDR lists, aggregated with `aggregate -q`.
- Static domains resolved and added by IP: `registry.npmjs.org`, `api.anthropic.com`, `sentry.io`, `statsig.anthropic.com`, `statsig.com`, `marketplace.visualstudio.com`, `vscode.blob.core.windows.net`, `update.code.visualstudio.com`.

Input validation before adding to the ipset, failing fast on malformed data:

```bash
if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
    exit 1
fi
```

Self-verification at the end — copy this pattern into any firewall you write:

```bash
# Should FAIL — confirms default-deny works
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed"
    exit 1
fi
# Should SUCCEED — confirms allowlist works
if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Unable to reach https://api.github.com"
    exit 1
fi
```

## Running without permission prompts

> Source: https://code.claude.com/docs/en/devcontainer

Because the container runs Claude Code as a **non-root user** and confines execution to the container, `--dangerously-skip-permissions` can be used for unattended operation — the CLI rejects the flag when launched as root, so `remoteUser` must be a non-root account. Skipping prompts removes the chance to review tool calls: Claude can still modify any file in the bind-mounted workspace (visible on the host) and reach anything the container's network policy allows. Pair it with the egress firewall. For fewer prompts without disabling safety checks, use **auto mode** (a classifier reviews actions). To block the flag org-wide, set `permissions.disableBypassPermissionsMode: "disable"` in managed settings.

## Reference container layout

> Source: https://code.claude.com/docs/en/devcontainer

The `anthropics/claude-code` repo ships a working example (not a maintained base image) combining CLI, firewall, persistent volumes, and a Zsh shell:

| File | Purpose |
|---|---|
| `.devcontainer/devcontainer.json` | Volume mounts, `runArgs` capabilities, VS Code extensions, `containerEnv` |
| `.devcontainer/Dockerfile` | Base image, dev tools, Claude Code install |
| `.devcontainer/init-firewall.sh` | Default-deny egress firewall |

To adopt: copy `.devcontainer/` into your own repo and adjust the Dockerfile, base image, and pinned version — or just add the Feature to an existing setup.

## devcontainer.json spec — security-relevant properties

> Source: https://containers.dev/implementors/json_reference/

| Property | Isolation relevance |
|---|---|
| `privileged` | Runs the container privileged — the spec explicitly warns this "has security implications particularly when running directly on Linux" |
| `capAdd` | Adds disabled Linux capabilities (e.g. `SYS_PTRACE`) — expands attack surface |
| `securityOpt` | Fine-grained security options (e.g. `seccomp=unconfined`) |
| `runArgs` | Raw Docker CLI arguments — used by the reference container to add `NET_ADMIN`/`NET_RAW` |
| `remoteUser` / `containerUser` | User for tool processes vs all container operations; `updateRemoteUserUID` (default true) syncs UID/GID on Linux |
| `mounts`, `workspaceMount`, `workspaceFolder` | Mount syntax (Docker `--mount` format) and project bind-mount location |
| `containerEnv` vs `remoteEnv` | Static/baked into image vs tool-and-subprocess scoped, updatable without rebuild |
| `hostRequirements` | Minimum `cpus`, `memory`, `storage`, `gpu` |

Lifecycle order relevant to firewall init: `initializeCommand` (host, pre-create) → `onCreateCommand` → `updateContentCommand` → `postCreateCommand` (user secrets available) → `postStartCommand` (every start) → `postAttachCommand`.

Variable interpolation: `${localEnv:VAR}`, `${containerEnv:VAR}` (remoteEnv only), `${localWorkspaceFolder}`, `${containerWorkspaceFolder}`, `${devcontainerId}` (stable unique container ID, used by the reference config to namespace the config volume per project).

## Sources

- https://code.claude.com/docs/en/devcontainer
- https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh
- https://containers.dev/implementors/json_reference/

Fetched: 2026-08-05
