# Codex enterprise controls

Read when rolling Codex out across an organization, when enforcing policy that users cannot override, or when a user reports that a setting "reverted by itself". All facts as of 2026-08-05.

## Two independent layers

Codex administration has two layers that both apply, and confusing them is the usual source of "I set it and it didn't take":

- **Workspace RBAC** decides *who can reach which surface at all*.
- **Config-file policy** (`requirements.toml` / `managed_config.toml`) decides *what settings are allowed once someone is on a surface*.

A user permitted by RBAC to use Codex cloud is still bound by whatever `requirements.toml` constraints apply to that cloud environment. Neither layer substitutes for the other.

## Control boundaries (RBAC)

> Source: https://learn.chatgpt.com/docs/enterprise/roles-and-workspace-permissions

The docs describe administration as a **boundary map**, not a table of roles: "Administration spans six control boundaries," and access granted at one boundary does **not** automatically grant access at another. The operative rule, verbatim: **"A request must pass every boundary that applies to it."**

| # | Boundary | Governs |
|---|---|---|
| 1 | ChatGPT workspace | Membership and built-in administration roles |
| 2 | Local clients | Runtime behavior in the desktop app, CLI, and IDE extension |
| 3 | Codex cloud | Hosted-workflow eligibility |
| 4 | Platform API | Organization and project access |
| 5 | Plugins | Plugin availability and connector access |
| 6 | Connected systems | Source-system data access — what a connected GitHub/Slack/Linear integration can see |

Practical consequence to state when troubleshooting: a user who can open Codex but cannot reach a repository is failing boundary 6, not boundary 1. Granting a broader workspace role will not fix it.

**Named roles are not in the fetched corpus.** Concrete role names, seat types, and per-role capability matrices are deferred to Help Center articles ("Manage members, seat types, roles, and access", "Configure role-based access control (RBAC)"), which were not fetched. Do not assert that a role literally named "Codex Admin" exists. The admin-setup page's own guidance is only: "Keep built-in administration roles limited to the people who administer the workspace."

## Admin rollout areas

> Source: https://learn.chatgpt.com/docs/enterprise/admin-setup

The rollout guide organizes Codex administration into eight areas — useful as a rollout checklist:

1. **Workspace access** — membership, seats, roles.
2. **Local runtime policy** — desktop app, CLI, IDE extension.
3. **Codex cloud** — hosted environments, repositories.
4. **Platform API access** — organization/project boundaries.
5. **Plugins and connectors**.
6. **Connected system permissions**.
7. **Governance and observability** — analytics, audit.
8. **Verification and maintenance**.

Pages linked from this guide but **not fetched into this corpus**: `/codex/enterprise/groups-and-provisioning` (SSO/SCIM), `/codex/enterprise/apps-and-connectors`, `/codex/enterprise/workspace-analytics`, `/codex/enterprise/compliance-api`, `/codex/enterprise/skills`, `/codex/enterprise/governance`. Treat SSO/SCIM provisioning, analytics, and the compliance API as unverified here.

## Managed configuration files

> Source: https://learn.chatgpt.com/docs/enterprise/managed-configuration

| File | Force | Conflict behavior |
|---|---|---|
| `requirements.toml` | Non-overrideable constraints on security-sensitive settings | The local client falls back to a compatible value **and notifies the user** |
| `managed_config.toml` | Starting values applied at client launch | Users may change them mid-session; defaults reapply on next startup. **Not enforced** |

That reapply-on-restart behavior is exactly the "it reverted by itself" report — a managed default, not a bug.

File locations:

| Platform | Path |
|---|---|
| Linux / macOS | `/etc/codex/managed_config.toml` |
| Windows | `~/.codex/managed_config.toml` |
| macOS MDM | Preference domain `com.openai.codex`, keys `config_toml_base64` and `requirements_toml_base64` |

## What `requirements.toml` can enforce

> Source: https://learn.chatgpt.com/docs/enterprise/managed-configuration

- Approval policy
- Sandbox mode
- Permission profiles
- Web search
- MCP servers
- Plugin marketplace sources
- Feature flags — browser use, computer use, plugins, hooks
- Network access allow/deny domain lists
- Filesystem deny-read patterns
- Appshots and device remote-control toggles
- `allow_managed_hooks_only = true` — restricts user/project hook configs to managed hooks only. **Supported only in `requirements.toml`**, per `docs/config.md`.

```toml
# requirements.toml
allowed_approval_policies = ["on-request"]
allowed_sandbox_modes = ["read-only", "workspace-write"]
allow_appshots = false

[rules]
prefix_rules = [
  { pattern = [{ any_of = ["bash", "sh"] }],
    decision = "prompt",
    justification = "Require approval for shell" }
]

[mcp_servers.docs]
identity = { command = "codex-mcp" }
```

```toml
# managed_config.toml
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = false
```

`justification` on a prefix rule is worth filling in properly — it is what the user sees when the prompt fires, and it is the difference between a policy people follow and one they route around.

`filesystem deny-read patterns` plus `[shell_environment_policy.filters]` in `config.toml` (see `config-reference.md`) are the pair that keeps credentials away from the agent: one blocks reading credential files, the other blocks inheriting credential environment variables.

## Verifying a rollout

> Source: https://learn.chatgpt.com/docs/enterprise/managed-configuration

On a target machine, in-session:

- `/status` — the *effective* model, approval policy, and writable roots.
- `/debug-config` — every config layer in precedence order **plus the source of managed policy requirements**. This is the one command that proves policy reached the client.

Add `--strict-config` while validating so an unrecognized key in a rolled-out file errors instead of silently falling back to a default.

Note that a client-side policy file is not a hard security boundary on a machine where the user has administrative rights and can edit `/etc/codex/` or swap the binary. Deliver policy via MDM (the `com.openai.codex` preference domain on macOS) and pair it with RBAC-side restrictions when the control has to actually hold.

## Sources

- https://learn.chatgpt.com/docs/enterprise/managed-configuration
- https://learn.chatgpt.com/docs/enterprise/admin-setup
- https://learn.chatgpt.com/docs/enterprise/roles-and-workspace-permissions
- https://github.com/openai/codex/blob/main/docs/config.md
- https://learn.chatgpt.com/docs/config-file/config-basic

Fetched: 2026-08-05
