# Codex approvals and sandboxing

Read when deciding how much autonomy to grant a Codex run, when a command was blocked or unexpectedly allowed, or when hardening a shared machine. For isolation *architecture* — egress proxies, credential injection, gVisor/Firecracker, cross-vendor fleet design — use the `sandboxing` sibling skill, which carries `references/codex-sandbox.md`. All facts as of 2026-08-05.

## The two-control model

> Source: https://learn.chatgpt.com/docs/agent-approvals-security

**Sandbox mode determines what is technically possible. Approval policy determines when the agent must ask first.** Actions that stay inside sandbox boundaries proceed automatically under permissive approval policies.

Diagnose in that order. "Codex edited a file I didn't expect" is a sandbox question; "Codex kept interrupting me" is an approval question. Fixing the wrong one produces either a useless prompt storm or a silent widening of what the agent can reach.

## Sandbox modes

> Source: https://learn.chatgpt.com/docs/sandboxing

Set with `sandbox_mode` in `config.toml` or `--sandbox` on the CLI.

| Mode | Behavior |
|---|---|
| `read-only` | Inspect files; cannot edit files or run commands without approval |
| `workspace-write` | Default for local dev — read files, edit within the workspace, run routine local commands inside that boundary |
| `danger-full-access` (alias `--yolo`) | Removes all filesystem and network restrictions; "no sandbox, no approvals" |

Widen `workspace-write` deliberately rather than dropping to `danger-full-access`:

```toml
[sandbox_workspace_write]
writable_roots = ["/path/to/allow"]
network_access = false
```

`network_access` is the single most consequential key here. Leaving it `false` is what makes prompt injection from fetched content non-exfiltrating.

## OS enforcement

> Source: https://learn.chatgpt.com/docs/sandboxing

| Platform | Mechanism |
|---|---|
| macOS | Native Seatbelt framework — `sandbox-exec` with a profile matching the selected mode |
| Linux / WSL2 | `bubblewrap` (`bwrap`, user-namespace isolation). Codex uses the first `bwrap` on `PATH`, falling back to a bundled helper that requires unprivileged user-namespace support. Landlock is available as a compatibility fallback path; seccomp is also used |
| Windows | Native Windows sandbox implementation when running natively; WSL2 uses the Linux implementation |

Two operational consequences on Linux: a hardened distro with unprivileged user namespaces disabled breaks the bundled fallback, and a shadowed or unexpected `bwrap` earlier on `PATH` changes which implementation actually runs. Check both before concluding the sandbox is misbehaving.

`[windows].sandbox = "elevated"` exists as a Windows-specific config knob.

## Approval policies

> Source: https://learn.chatgpt.com/docs/agent-approvals-security

| Value | Behavior |
|---|---|
| `untrusted` | Only known-safe read operations run automatically; anything that can mutate state requires approval |
| `on-request` | Codex requires approval to edit outside the workspace or to access the network |
| `never` | Disables approval prompts entirely; autonomy is still governed by sandbox settings |

Granular form, for controlling the individual approval channels:

```toml
approval_policy = { granular = {
  sandbox_approval = true,
  rules = true,
  mcp_elicitations = true
} }
```

`mcp_elicitations = true` keeps a human in the loop when an MCP server asks the user for input — worth keeping on when third-party servers are configured, since that channel is attacker-reachable content.

## Mode combinations

> Source: https://learn.chatgpt.com/docs/agent-approvals-security

```toml
# Standard safe mode — the default recommendation for local dev
approval_policy = "on-request"
sandbox_mode = "workspace-write"
```

```toml
# Read-only investigation: exploring an unfamiliar or untrusted repo
approval_policy = "on-request"
sandbox_mode = "read-only"
```

```toml
# Network-enabled workspace work — only when dependency installs genuinely need it
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
```

For unattended CI, the safe shape is a restrictive sandbox plus `approval_policy = "never"` — there is no human to answer a prompt, so a policy that can block will hang the job rather than protect it. Let the sandbox, not the approval prompt, be the boundary.

`--dangerously-bypass-approvals-and-sandbox` / `--yolo` runs every command with no approvals and no sandboxing. It is only defensible inside an environment already hardened externally (a disposable container or VM with no ambient credentials and controlled egress).

## Testing a policy before you ship it

> Source: https://learn.chatgpt.com/docs/developer-commands?surface=cli

`codex sandbox` runs an arbitrary command inside the Codex-provided sandbox via permission profiles, with platform aliases `codex sandbox seatbelt` and `codex sandbox landlock` (also surfaced as `codex debug`). Use it to confirm a build or test command still works under the restrictions you intend to enforce, before rolling that mode out to a team or a CI job.

`/status` reports the active approval policy and writable roots for the running session; `/debug-config` shows which layer set them and whether a managed requirement is responsible.

## Network access beyond the local sandbox

> Source: https://learn.chatgpt.com/docs/sandboxing

Network is enforced through the sandbox layer and via `[sandbox_workspace_write].network_access`. In ChatGPT Work (cloud), separate "Work network access" controls let admins restrict commands to managed allowlists or enable public internet access; cloud and isolated runs execute in an environment where workspace policy determines available capabilities. Cloud agent-phase internet has its own three-layer control — see `cloud-and-environments.md`.

Admins can enforce allowed sandbox modes and approval policies fleet-wide via `requirements.toml` — see `enterprise.md`.

## Sources

- https://learn.chatgpt.com/docs/sandboxing
- https://learn.chatgpt.com/docs/agent-approvals-security
- https://learn.chatgpt.com/docs/developer-commands?surface=cli
- https://learn.chatgpt.com/docs/config-file/config-basic
- https://learn.chatgpt.com/docs/config-file/config-advanced

Fetched: 2026-08-05
