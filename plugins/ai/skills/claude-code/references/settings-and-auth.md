# Settings and authentication reference

Read when configuring `settings.json` at any scope, debugging "my setting isn't applying", wiring an LLM gateway/proxy, or rolling out server-managed settings for a Teams/Enterprise org.

## Authentication

> Source: https://code.claude.com/docs/en/authentication.md

### Login methods

- **Claude Pro/Max subscription** — log in with a claude.ai account.
- **Claude for Teams/Enterprise** — log in with the claude.ai account an admin invited.
- **Claude Console** — API-based billing. Admin invites with the **Claude Code** role (can create Claude Code API keys only) or **Developer** role (any API key).
- **Cloud providers** — Amazon Bedrock, Google Cloud's Agent Platform, Microsoft Foundry. Set env vars before running `claude`, or pick **3rd-party platform** at the login prompt for a setup wizard.
- **Cloud gateway** — self-hosted Claude apps gateway; sign in through corporate SSO via `/login`.

`/logout` logs out and resets first-launch setup state.

### Credential storage

| Platform | Location |
|---|---|
| macOS | encrypted macOS Keychain |
| Linux | `~/.claude/.credentials.json`, mode `0600` |
| Windows | `%USERPROFILE%\.claude\.credentials.json` |

`CLAUDE_CONFIG_DIR` overrides the location on Linux/Windows.

`apiKeyHelper` is a shell script that prints an API key; it is re-invoked after 5 minutes or on HTTP 401 by default. Override the interval with `CLAUDE_CODE_API_KEY_HELPER_TTL_MS`.

### Precedence (highest to lowest)

1. Cloud provider credentials — when `CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX`, or `CLAUDE_CODE_USE_FOUNDRY` is set
2. `ANTHROPIC_AUTH_TOKEN` — sent as `Authorization: Bearer` (LLM gateway/proxy)
3. `ANTHROPIC_API_KEY` — sent as `X-Api-Key`; prompts once for approval interactively, always used in `-p` mode
4. `apiKeyHelper` script output — dynamic/rotating credentials
5. `CLAUDE_CODE_OAUTH_TOKEN` — long-lived token from `claude setup-token`
6. Subscription OAuth credentials from `/login`

A signed-in Claude apps gateway session sits outside this list and outranks Bedrock/Vertex/Foundry provider selection when present.

### Long-lived CI token

```bash
claude setup-token
# opens browser auth flow, prints the token (it is not saved anywhere)
export CLAUDE_CODE_OAUTH_TOKEN=your-token
```

Requires Pro/Max/Team/Enterprise. Can make model requests only — no Remote Control sessions, no claude.ai connector fetching. `--bare` mode does **not** read it; use `ANTHROPIC_API_KEY` or `apiKeyHelper` there.

### Restrict login to one organization

```json
{ "forceLoginMethod": "...", "forceLoginOrgUUID": "org-uuid-here" }
```

Managed settings only. Exits at startup if the active credential belongs to a different org. Enforcement varies by login path: terminal / VS Code / Agent SDK enforce both keys as of v2.1.212+; `claude setup-token` and `/install-github-app` enforce only `forceLoginMethod`; gateway sign-in is selected by `forceLoginMethod: "gateway"` and does not check `forceLoginOrgUUID`.

It also blocks `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` / `apiKeyHelper` sessions, because org membership cannot be verified for env credentials. Cloud-provider sessions (Bedrock and friends) are **not** blocked — restrict those with cloud IAM.

## Settings file locations and precedence

> Source: https://code.claude.com/docs/en/settings.md

Priority order (as of 2026-08-05):

1. **Managed** (highest) — server-managed, MDM/OS-level, or file-based policies
2. **Command line arguments** — temporary session overrides
3. **Local** — `.claude/settings.local.json` (gitignored)
4. **Project** — `.claude/settings.json` (committed)
5. **User** (lowest) — `~/.claude/settings.json`

| Scope | Location | Applies to | Shared? |
|---|---|---|---|
| User | `~/.claude/settings.json` | You, all projects | No |
| Project | `.claude/settings.json` | All collaborators | Yes (git) |
| Local | `.claude/settings.local.json` | You, this repo | No (gitignored) |
| Managed | Server/MDM/`managed-settings.json` | Org members | Yes (IT deployed) |

On Windows `~/.claude/` resolves to `%USERPROFILE%\.claude`.

Managed settings file paths:

- Linux/WSL: `/etc/claude-code/managed-settings.json`
- macOS: `/Library/Application Support/ClaudeCode/managed-settings.json`
- Windows: `C:\Program Files\ClaudeCode\managed-settings.json`
- Drop-in directory variant: `managed-settings.d/*.json`

Precedence rules: higher-priority values override lower ones, **except** that permission rules merge across scopes rather than overriding, and arrays generally concatenate and de-duplicate. Managed settings cannot be overridden, with documented exceptions (e.g. `forceRemoteSettingsRefresh` can be set from any admin-controlled managed source).

### Example settings.json

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "model": "claude-opus-4-1",
  "fallbackModel": ["claude-sonnet-5", "claude-haiku-4-5"],
  "alwaysThinkingEnabled": true,
  "effortLevel": "xhigh",
  "autoMemoryEnabled": true,
  "autoMemoryDirectory": "~/my-memory-dir",
  "autoCompactEnabled": true,
  "autoCompactWindow": 500000,
  "editorMode": "vim",
  "permissions": {
    "allow": ["Bash(npm run lint)", "Bash(npm run test *)", "Read(~/.zshrc)"],
    "deny": ["Bash(curl *)", "Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)"]
  },
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
    "NODE_ENV": "production"
  },
  "companyAnnouncements": ["Welcome to Acme Corp!", "New security policy in effect"],
  "attribution": { "commit": "🤖 Generated with Claude Code", "pr": "Claude Code" },
  "allowedMcpServers": [{ "serverName": "github" }, { "serverName": "memory" }],
  "deniedMcpServers": [{ "serverName": "filesystem" }],
  "claudeMd": "Always run make lint before committing.",
  "claudeMdExcludes": ["**/vendor/**/CLAUDE.md"],
  "cleanupPeriodDays": 30,
  "autoUpdatesChannel": "stable"
}
```

### Settings key catalog by area

**Model & performance**: `model`, `fallbackModel`, `advisorModel`, `availableModels`, `enforceAvailableModels`, `alwaysThinkingEnabled`, `effortLevel`, `fastMode`, `modelOverrides` (model ID → provider-specific ARN, used for Bedrock inference profiles).

**Memory & context**: `autoMemoryEnabled`, `autoMemoryDirectory`, `autoCompactEnabled`, `autoCompactWindow`, `claudeMd`, `claudeMdExcludes`.

**Permissions & security**: `permissions.allow` / `.deny` / `.ask` / `.defaultMode`, `disableAutoMode`, `allowManagedPermissionRulesOnly`, `disableBypassPermissionsMode`.

**Tools & features**: `disableArtifact`, `enableArtifact`, `disableAgentView`, `disableBundledSkills`, `disableWorkflows`, `disableRemoteControl`, `channelsEnabled`, `disableSkillShellExecution`, `skillOverrides`.

**MCP servers**: `allowedMcpServers`, `deniedMcpServers`, `allowManagedMcpServersOnly`, `disableClaudeAiConnectors`, `disabledMcpjsonServers`, `enabledMcpjsonServers`, `enableAllProjectMcpServers`.

**Hooks & automation**: `disableAllHooks`, `allowManagedHooksOnly`, `allowedHttpHookUrls`, `hooks`.

**UI & display**: `editorMode`, `tui`, `outputStyle`, `autoScrollEnabled`, `spinnerTipsEnabled`, `awaySummaryEnabled`, `axScreenReader`, `emojiCompletionEnabled`, `showClearContextOnPlanAccept`.

**Environment & shell**: `env`, `defaultShell`, `awsCredentialExport`, `apiKeyHelper`, `awsAuthRefresh`, `gcpAuthRefresh`, `otelHeadersHelper`.

**Organization/management**: `companyAnnouncements`, `attribution.commit` / `.pr`, `cleanupPeriodDays`, `autoUpdatesChannel`, `forceLoginOrgUUID`, `forceLoginMethod`.

**Plugin/marketplace**: `extraKnownMarketplaces`, `enabledPlugins`, `pluginConfigs`, `strictKnownMarketplaces`, `blockedMarketplaces`, `disableSideloadFlags`, `pluginSuggestionMarketplaces`.

**Sandbox**: `sandbox.enabled`, `sandbox.failIfUnavailable`, `sandbox.filesystem.*`, `sandbox.network.*`, `sandbox.credentials.*`.

### Managed-only extras

Read only from managed settings:

```json
{
  "forceLoginOrgUUID": "org-uuid-here",
  "allowAllClaudeAiMcps": true,
  "blockedMarketplaces": [{ "source": "github", "repo": "untrusted/plugins" }],
  "strictKnownMarketplaces": true,
  "allowedChannelPlugins": [{ "marketplace": "claude-plugins-official", "plugin": "telegram" }],
  "allowedHttpHookUrls": ["https://hooks.example.com/*"],
  "disableSideloadFlags": true,
  "disableBrowserExternalNavigation": true,
  "browserExternalPageTools": "disabled",
  "disableMobileSimulatorTools": true,
  "forceRemoteSettingsRefresh": true
}
```

### Environment-variable overrides

```bash
CLAUDE_CODE_MODEL=claude-opus-4-1
CLAUDE_CODE_EFFORT_LEVEL=xhigh
CLAUDE_CODE_AUTO_COMPACT_WINDOW=500000
CLAUDE_CODE_DISABLE_AUTO_MEMORY=0
CLAUDE_CODE_DISABLE_ARTIFACT=0
CLAUDE_CODE_DISABLE_AGENT_VIEW=0
CLAUDE_CODE_DISABLE_WORKFLOWS=0
CLAUDE_CODE_DISABLE_BUNDLED_SKILLS=0
CLAUDE_CODE_DISABLE_REMOTE_CONTROL=0
CLAUDE_AX_SCREEN_READER=false
DISABLE_AUTOUPDATER=0
CLAUDE_CODE_API_KEY_HELPER_TTL_MS=3600000
CLAUDE_CODE_USE_POWERSHELL_TOOL=1
DISABLE_AUTO_COMPACT=0
```

### When settings take effect

- **Immediate (live reload)**: `permissions`, `hooks`, `apiKeyHelper`, `env`, most other keys (surfaced via the `ConfigChange` hook).
- **On restart only**: `model` (use `/model` mid-session instead) and `outputStyle` (part of the system prompt).

### Verification commands

```bash
/status            # lists all active settings sources
/config            # interactive settings interface
/config key=value  # change a single setting (v2.1.181+)
/doctor            # debug configuration issues
```

Claude Code auto-creates timestamped config backups. `.claude/settings.local.json` is auto-added to the global gitignore.

## Server-managed settings (Teams/Enterprise)

> Source: https://code.claude.com/docs/en/server-managed-settings.md

Organization Owners configure Claude Code centrally at **Admin Settings > Claude Code > Managed settings** (`claude.ai/admin-settings/claude-code`) with no MDM required. Clients fetch these settings when authenticated via org OAuth login or a directly configured API key.

Requirements: Claude for Teams or Enterprise plan, Owner or Primary Owner role, network access to `api.anthropic.com`.

### Server-managed vs. endpoint-managed

| Approach | Best for | Security model |
|---|---|---|
| Server-managed | No MDM, or unmanaged devices | Delivered from Anthropic's servers at auth time |
| Endpoint-managed | Orgs with MDM | MDM profiles, registry policies, or `managed-settings.json` files |

Endpoint-managed settings do not reach cloud sessions (Claude Code on the web) — configure server-managed as well for those.

### Example payloads

Enforce a deny list, disable bypass mode, restrict to managed permission rules only:

```json
{
  "permissions": {
    "deny": ["Bash(curl *)", "Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)"],
    "disableBypassPermissionsMode": "disable"
  },
  "allowManagedPermissionRulesOnly": true
}
```

Run an audit script after every edit, org-wide:

```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "/usr/local/bin/audit-edit.sh" }] }
    ]
  }
}
```

Describe the trusted environment to the auto-mode classifier:

```json
{
  "autoMode": {
    "environment": [
      "Source control: github.example.com/acme-corp and all repos under it",
      "Trusted cloud buckets: s3://acme-build-artifacts, gs://acme-ml-datasets",
      "Trusted internal domains: *.corp.example.com"
    ]
  }
}
```

Hooks and shell-executing / custom-`env` settings trigger a **security approval dialog** in the user's next interactive session before being applied. A non-interactive run (`claude -p`, Agent SDK) that hits a payload needing approval applies it for that run only, without recording approval.

### Precedence within the managed tier

Server- and endpoint-managed both occupy the highest tier; no non-managed level overrides them. A configured `policyHelper` preempts every other managed source. Otherwise Claude Code uses the **first source that delivers a non-empty configuration** — server-managed checked first, then endpoint-managed. They do not merge: if server-managed delivers any keys, endpoint-managed is ignored entirely.

### Fetch and caching

- Fetches at startup, polls hourly during active sessions.
- First launch with no cache: async fetch; on failure the session continues unmanaged (a brief unenforced window).
- Subsequent launches: cached settings apply immediately except withheld `env` categories; fresh settings fetched in background; cache survives network failures.
- As of v2.1.198, three categories of cached `env` values are **withheld** until the server confirms the payload for the session, so a cached value cannot intercept the confirming fetch:
  - Proxy/TLS: `HTTPS_PROXY`, `NODE_EXTRA_CA_CERTS`, `CLAUDE_CODE_CLIENT_CERT`, `CLAUDE_CODE_CLIENT_KEY`
  - API routing/provider selection: `ANTHROPIC_BASE_URL`, `CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX`, provider endpoint URLs such as `ANTHROPIC_BEDROCK_BASE_URL`
  - Auth credentials: `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`
- All other cached `env` keys apply at startup as before.
- Updates apply without restart **except** OTel configuration, which requires a full restart.

### Fail-closed startup

```json
{ "forceRemoteSettingsRefresh": true }
```

Blocks CLI startup until remote settings are freshly fetched and exits if the fetch fails (`claude auth` subcommands exempt since v2.1.139). Self-perpetuating once delivered. Sends `Cache-Control: no-cache`.

### Availability and limits

Requires a direct connection to `api.anthropic.com` plus org OAuth login or a directly configured API key. **Not available** with Amazon Bedrock, Google Cloud's Agent Platform, Microsoft Foundry, Claude Platform on AWS, or a custom `ANTHROPIC_BASE_URL`/LLM gateway — exporting any `CLAUDE_CODE_USE_*` var or a non-default `ANTHROPIC_BASE_URL` skips the fetch entirely for that session. For those providers, a self-hosted Claude apps gateway can deliver equivalent managed settings.

Current limitations: settings apply uniformly to all org users (no per-group configuration); `managed-mcp.json` cannot be distributed this way (use `allowedMcpServers`/`deniedMcpServers` instead); `policyHelper` and `wslInheritsWindowsSettings` are OS-level only and require MDM or a system `managed-settings.json`. Only Primary Owner and Owner roles can manage server-managed settings.

### Security posture

Server-managed settings are a **client-side control, not a security boundary**. On an unmanaged device a user without admin/sudo can bypass them by running a modified binary, an older CLI version, or authenticating to a different org. Use `ConfigChange` hooks to detect, log, or block unauthorized runtime configuration changes. For a hard boundary, deploy endpoint-managed settings on MDM-enrolled devices.

## Sources

- https://code.claude.com/docs/en/authentication.md
- https://code.claude.com/docs/en/settings.md
- https://code.claude.com/docs/en/server-managed-settings.md

Fetched: 2026-08-05
