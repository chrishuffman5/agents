# Headless, CI, and enterprise deployment reference

Read when scripting `claude -p`, wiring GitHub Actions, deploying on Bedrock or Google Cloud's Agent Platform, containerizing Claude Code, or looking up a built-in slash command.

## Headless / non-interactive mode

> Source: https://code.claude.com/docs/en/headless.md

```bash
claude -p "Find and fix the bug in auth.py" --allowedTools "Read,Edit,Bash"
```

Exit code 0 means success and non-zero means failure, so scripts can branch on it. An invalid flag errors to stderr before the run starts.

### `--bare` mode

Recommended for scripted and SDK calls; it is expected to become the `-p` default. It skips auto-discovery of hooks, skills, plugins, MCP servers, auto memory, and CLAUDE.md, giving the same result on every machine. It never reads OAuth credentials or the keychain — set `ANTHROPIC_API_KEY` explicitly, or use `apiKeyHelper` inside `--settings` JSON. Bedrock/Vertex/Foundry still read their own provider credentials. It has access to Bash plus file read/edit tools only, so context must be passed explicitly:

| To load | Use |
|---|---|
| System prompt additions | `--append-system-prompt`, `--append-system-prompt-file` |
| Settings | `--settings <file-or-json>` |
| MCP servers | `--mcp-config <file-or-json>` |
| Custom agents | `--agents <json>` |
| A plugin | `--plugin-dir <path>`, `--plugin-url <url>` |

```bash
claude --bare -p "Summarize README.md" --allowedTools "Read"
```

### Process lifecycle

A background Bash task started during `claude -p` (e.g. a dev server) is terminated about 5 seconds after the final result plus stdin close (v2.1.163+ fixed never-exiting processes). Background subagents and workflows are exempt from that grace period because their results are part of the final output, but they are capped at a 10-minute wait by default (`CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS`, `0` = unlimited). SIGTERM aborts the in-progress turn, kills the Bash process tree, runs `SessionEnd` hooks, and exits 143.

### Flags and patterns

```bash
# stdin piping (10MB cap as of v2.1.128)
cat build-error.txt | claude -p 'concisely explain the root cause' > output.txt

# structured JSON output
claude -p "Summarize this project" --output-format json
claude -p "Extract function names" --output-format json --json-schema '{"type":"object","properties":{"functions":{"type":"array","items":{"type":"string"}}},"required":["functions"]}'

# streaming
claude -p "Explain recursion" --output-format stream-json --verbose --include-partial-messages

# auto-approve tools / permission mode baseline
claude -p "Run the test suite and fix any failures" --allowedTools "Bash,Read,Edit"
claude -p "Apply the lint fixes" --permission-mode acceptEdits

# commits with scoped Bash rules
claude -p "Look at my staged changes and create an appropriate commit" \
  --allowedTools "Bash(git diff *),Bash(git log *),Bash(git status *),Bash(git commit *)"

# system prompt customization
gh pr diff "$1" | claude -p --append-system-prompt "You are a security engineer. Review for vulnerabilities." --output-format json

# continue / resume
claude -p "Review this codebase for performance issues"
claude -p "Now focus on the database queries" --continue
session_id=$(claude -p "Start a review" --output-format json | jq -r '.session_id')
claude -p "Continue that review" --resume "$session_id"
```

`--output-format`: `text` (default), `json` (result, `session_id`, metadata including `total_cost_usd` and a per-model cost breakdown), `stream-json` (newline-delimited events).

### CI-relevant stream events

- `system/init` — first event; reports model, tools, MCP servers, and plugins loaded. `plugins` / `plugin_errors` arrays let CI fail when a plugin fails to load; `mcp_servers` / `mcp_server_errors` (v2.1.219+) let CI fail when an `--mcp-config` entry is invalid.
- `system/api_retry` — a retryable API error before the retry, with `attempt`, `max_retries`, `retry_delay_ms`, `error_status`, `error`.
- `system/plugin_install` — emitted when `CLAUDE_CODE_SYNC_PLUGIN_INSTALL` is set.

## GitHub Actions

> Source: https://code.claude.com/docs/en/github-actions.md

Quick setup: run `/install-github-app` in a Claude Code session as a repo admin. It installs the Claude GitHub App (needs Contents / Issues / Pull requests read+write) and walks through workflow and secret setup.

```yaml
name: Claude Code
on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
jobs:
  claude:
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          # Responds to @claude mentions in comments
```

### v1.0 breaking changes from the beta

| Old beta input | New v1.0 input |
|---|---|
| `mode` | Removed — auto-detected |
| `direct_prompt` | `prompt` |
| `custom_instructions` | `claude_args: --append-system-prompt` |
| `max_turns` | `claude_args: --max-turns` |
| `model` | `claude_args: --model` |
| `allowed_tools` | `claude_args: --allowedTools` |
| `claude_env` | `settings` JSON format |

### Action parameters

`prompt` (plain text, or a skill invocation like `/plugin-name:skill-name`), `claude_args` (raw CLI passthrough, e.g. `--max-turns 5 --model claude-sonnet-5 --mcp-config /path/to/config.json`), `plugin_marketplaces`, `plugins`, `anthropic_api_key` (required for the direct API), `github_token`, `trigger_phrase` (default `@claude`), `use_bedrock`, `use_vertex`.

```yaml
- uses: anthropics/claude-code-action@v1
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    plugin_marketplaces: "https://github.com/anthropics/claude-code.git"
    plugins: "code-review@claude-code-plugins"
    prompt: "/code-review:code-review ${{ github.repository }}/pull/${{ github.event.pull_request.number }}"
```

### Amazon Bedrock via Actions

Requires a GitHub OIDC identity provider in AWS, an IAM role trusting `token.actions.githubusercontent.com` (audience `sts.amazonaws.com`) with `AmazonBedrockFullAccess` or a scoped equivalent, and a custom or official GitHub App. Secrets: `AWS_ROLE_TO_ASSUME`, `APP_ID`, `APP_PRIVATE_KEY`.

```yaml
permissions:
  contents: write
  pull-requests: write
  issues: write
  id-token: write
steps:
  - uses: actions/checkout@v4
  - uses: actions/create-github-app-token@v2
    id: app-token
    with: { app-id: ${{ secrets.APP_ID }}, private-key: ${{ secrets.APP_PRIVATE_KEY }} }
  - uses: aws-actions/configure-aws-credentials@v4
    with: { role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}, aws-region: us-west-2 }
  - uses: anthropics/claude-code-action@v1
    with:
      github_token: ${{ steps.app-token.outputs.token }}
      use_bedrock: "true"
      claude_args: '--model us.anthropic.claude-sonnet-4-6 --max-turns 10'
```

### Google Cloud's Agent Platform via Actions

Requires Workload Identity Federation (no downloadable service-account keys): enable the IAM Credentials, STS, and Vertex AI APIs; create a WIF pool plus GitHub OIDC provider; grant a service account `Vertex AI User`. Secrets: `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT`, `APP_ID`, `APP_PRIVATE_KEY`.

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/create-github-app-token@v2
    id: app-token
    with: { app-id: ${{ secrets.APP_ID }}, private-key: ${{ secrets.APP_PRIVATE_KEY }} }
  - uses: google-github-actions/auth@v2
    id: auth
    with: { workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}, service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }} }
  - uses: anthropics/claude-code-action@v1
    with:
      github_token: ${{ steps.app-token.outputs.token }}
      use_vertex: "true"
      claude_args: '--model claude-sonnet-4-5@20250929 --max-turns 10'
    env:
      ANTHROPIC_VERTEX_PROJECT_ID: ${{ steps.auth.outputs.project_id }}
      CLOUD_ML_REGION: us-east5
      VERTEX_REGION_CLAUDE_4_5_SONNET: us-east5
```

## Amazon Bedrock

> Source: https://code.claude.com/docs/en/amazon-bedrock.md

Interactive setup: `claude` → **3rd-party platform** → **Amazon Bedrock**, or `/setup-bedrock` at any time (writes to `~/.claude/settings.json`).

```bash
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1                              # optional; else AWS_DEFAULT_REGION, profile region, then us-east-1
export ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION=us-west-2   # optional, small/fast model region only
```

Credentials: `aws configure`, `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN`, an SSO profile (`aws sso login --profile=X; export AWS_PROFILE=X`), `aws login`, or a Bedrock API key via `AWS_BEARER_TOKEN_BEDROCK`.

`/logout` is unavailable on Bedrock (AWS-credential auth), and the WebSearch tool is unavailable.

### Pin model versions (required for multi-user deployments)

```bash
export ANTHROPIC_DEFAULT_OPUS_MODEL='us.anthropic.claude-opus-4-8'
export ANTHROPIC_DEFAULT_SONNET_MODEL='us.anthropic.claude-sonnet-4-6'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='us.anthropic.claude-haiku-4-5-20251001-v1:0'
```

Cross-region inference profile IDs use the `us.` prefix (`us-gov.` in GovCloud). Without pinning, the `opus`/`sonnet` aliases resolve to Claude Code's built-in Bedrock defaults — as of 2026-08-05, primary `us.anthropic.claude-opus-5` and small/fast `us.anthropic.claude-sonnet-4-5-20250929-v1:0` — which may not be enabled in your account. Claude Code falls back automatically, but the choice is not persisted.

### IAM policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "AllowModelAndInferenceProfileAccess", "Effect": "Allow",
      "Action": ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream", "bedrock:ListInferenceProfiles", "bedrock:GetInferenceProfile"],
      "Resource": ["arn:aws:bedrock:*:*:inference-profile/*", "arn:aws:bedrock:*:*:application-inference-profile/*", "arn:aws:bedrock:*:*:foundation-model/*"] },
    { "Sid": "AllowMarketplaceSubscription", "Effect": "Allow",
      "Action": ["aws-marketplace:ViewSubscriptions", "aws-marketplace:Subscribe"], "Resource": "*",
      "Condition": { "StringEquals": { "aws:CalledViaLast": "bedrock.amazonaws.com" } } }
  ]
}
```

### Other Bedrock features

- 1M-token context: Sonnet 5 always runs with it; other models need `[1m]` appended to the model ID.
- Service tiers: `ANTHROPIC_BEDROCK_SERVICE_TIER=default|flex|priority`.
- Guardrails: `ANTHROPIC_CUSTOM_HEADERS="X-Amzn-Bedrock-GuardrailIdentifier: id\nX-Amzn-Bedrock-GuardrailVersion: 1"` in settings `env`.
- **Mantle endpoint** (native Anthropic API shape rather than the Invoke API): `CLAUDE_CODE_USE_MANTLE=1` with model IDs like `anthropic.claude-sonnet-5` / `anthropic.claude-haiku-4-5`. It can run alongside standard Bedrock (`CLAUDE_CODE_USE_BEDROCK=1` + `CLAUDE_CODE_USE_MANTLE=1`); `CLAUDE_CODE_SKIP_MANTLE_AUTH=1` supports gateway-injected credentials.
- Standard Bedrock uses the Invoke API (`InvokeModelWithResponseStream`), not the Converse API.

## Google Cloud's Agent Platform (Vertex AI)

> Source: https://code.claude.com/docs/en/google-vertex-ai.md

Interactive setup: `claude` → **3rd-party platform** → **Google Vertex AI**, or `/setup-vertex` (writes to `~/.claude/settings.json`).

```bash
gcloud config set project YOUR-PROJECT-ID
gcloud services enable aiplatform.googleapis.com
# request Claude model access in the Model Garden console and wait for approval

export CLAUDE_CODE_USE_VERTEX=1
export CLOUD_ML_REGION=global   # or a multi-region ("eu"/"us"), or a specific region such as us-east5
export ANTHROPIC_VERTEX_PROJECT_ID=YOUR-PROJECT-ID
```

Credentials via standard GCP ADC (`gcloud auth application-default login`), a service account key (`GOOGLE_APPLICATION_CREDENTIALS`), or X.509-based Workload Identity Federation (v2.1.121+).

```bash
export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-8'
export ANTHROPIC_DEFAULT_SONNET_MODEL='claude-sonnet-5'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='claude-haiku-4-5@20251001'
export VERTEX_REGION_CLAUDE_HAIKU_4_5=us-east5
export VERTEX_REGION_CLAUDE_4_6_SONNET=europe-west1
```

Built-in defaults as of 2026-08-05: primary `claude-opus-5`, small/fast `claude-sonnet-4-5@20250929`. IAM: `roles/aiplatform.user` includes `aiplatform.endpoints.predict`, required for model invocation and token counting.

`/logout` is unavailable on Vertex. 1M-token context: Sonnet 5 always on, others via the `[1m]` suffix. Tool search is enabled by default on Claude 4.5+ generations; older models load MCP tools upfront regardless of `ENABLE_TOOL_SEARCH`.

## Dev containers

> Source: https://code.claude.com/docs/en/devcontainer.md

```json
// .devcontainer/devcontainer.json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": { "ghcr.io/anthropics/devcontainer-features/claude-code:1.0": {} }
}
```

Rebuild via VS Code Command Palette → **Dev Containers: Rebuild Container**. The feature installs Node.js itself if missing; add `"ghcr.io/devcontainers/features/node:1": {}` if that install fails.

### Persist auth and settings across rebuilds

```json
"mounts": ["source=claude-code-config,target=/home/node/.claude,type=volume"],
"containerEnv": { "CLAUDE_CONFIG_DIR": "/home/node/.claude" }
```

`~/.claude.json` (OAuth account, MCP servers, per-project trust) is separate from the `~/.claude` directory — you must set `CLAUDE_CONFIG_DIR` so it lands inside the mounted volume too. Use `${devcontainerId}` in the volume source to isolate per project.

### Enforce org policy in the image

```dockerfile
RUN mkdir -p /etc/claude-code
COPY managed-settings.json /etc/claude-code/managed-settings.json
```

This has the highest precedence in the settings hierarchy but is bypassable by anyone with repo write access, since the Dockerfile is checked in. For unbypassable policy use server-managed settings or MDM.

```json
"containerEnv": { "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1", "DISABLE_AUTOUPDATER": "1" }
```

`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` also disables Remote Control's feature-flag evaluation.

The reference `init-firewall.sh` script blocks all outbound traffic except required domains and needs `NET_ADMIN`/`NET_RAW` capabilities via `runArgs` — optional hardening, not required by Claude Code itself.

`claude --dangerously-skip-permissions` is rejected when launched as root/sudo (the check is skipped inside a recognized sandbox) — set `remoteUser` to a non-root account. The reference container is the `.devcontainer/` in the `anthropics/claude-code` repo, combining the CLI, firewall, persistent volumes, and a Zsh shell.

## Sandboxing (feature summary)

> Source: https://code.claude.com/docs/en/sandboxing.md

Deep sandbox architecture and enterprise egress control belong to the `sandboxing` sibling skill; this is the harness-level summary.

Platform support: macOS uses built-in Seatbelt with nothing to install; Linux and WSL2 need `bubblewrap` and `socat` (optional seccomp filter via `npm install -g @anthropic-ai/sandbox-runtime`); native Windows is not supported, use WSL2.

```json
{ "sandbox": { "enabled": true } }
```

`/sandbox` opens a panel with **Mode** (auto-allow vs regular permissions), **Overrides** (`allowUnsandboxedCommands`), **Config** (resolved settings), and a **Dependencies** tab when a package is missing. `sandbox.failIfUnavailable: true` turns missing dependencies or an unsupported platform into a hard failure instead of a silent unsandboxed fallback.

Default filesystem: writes limited to cwd plus the session temp dir (`$TMPDIR` is redirected for sandboxed commands); reads cover the whole filesystem except denied directories — which still includes `~/.aws/credentials` and `~/.ssh/` unless blocked via `sandbox.credentials`. Network is proxy-enforced with no domains pre-allowed; the first use of a new domain prompts and the approval sticks for the session (v2.1.191+). `strictAllowlist: true` denies instead of prompting. `sandbox.filesystem.disabled` and `mask`-mode credentials are honored only from user/managed/`--settings` sources, never project scope.

## Built-in slash commands

> Source: https://code.claude.com/docs/en/commands.md

Commands are recognized only at the start of a message; up to 6 skills chain per message (v2.1.199+). `/status`, `/tasks`, and `/usage` run immediately without interrupting responses.

- **Project & session setup**: `/init`, `/memory`, `/cd <path>`, `/add-dir <path>`, `/mcp [reconnect <server>|enable|disable]`
- **Model & performance**: `/model [model]`, `/effort [level|auto]`, `/advisor [model|off]`, `/fast [on|off]`, `/autocompact [auto|<tokens>]` (v2.1.221+)
- **Context & conversation**: `/context [all]`, `/compact [instructions]`, `/clear [name]`, `/resume`, `/branch [name]`, `/fork [prompt]`, `/btw [question]`
- **Code review & analysis**: `/code-review [level] [--fix] [--comment] [target]` (levels low/medium/high/xhigh/max/ultra), `/diff`, `/review`, `/security-review`
- **Workflow & execution**: `/plan`, `/batch <instruction>`, `/tasks`, `/goal [condition|clear]`, `/loop [interval] [prompt]`
- **Parallel/agents**: `/background [prompt]` (alias `/bg`), `/agents` (reminder only, v2.1.198+), `/subtask`
- **Settings & config**: `/config [key=value ...]` (alias `/settings`), `/color`, `/keybindings`, `/permissions` (alias `/allowed-tools`)
- **Debugging**: `/debug [description]`, `/doctor` (alias `/checkup`), `/rewind`, `/heapdump`
- **Research**: `/deep-research <question>`, `/insights`
- **Migration/audit**: `/claude-api [migrate|managed-agents-onboard|prompt-audit]`, `/fewer-permission-prompts`
- **Utilities**: `/copy [N]`, `/export [filename]`, `/ide`, `/hooks`, `/install-github-app`, `/install-slack-app`, `/autofix-pr [prompt]`
- **Remote**: `/desktop` (alias `/app`, macOS and x64 Windows only), `/remote-control`, `/teleport`, `/mobile` (aliases `/ios`, `/android`)
- **Account/help**: `/login`, `/logout`, `/usage` (alias `/cost`), `/status`, `/help`, `/exit` (alias `/quit`), `/feedback [report]`, `/bug [report]` (alias `/share`), `/upgrade` (hidden on Enterprise), `/passes`

Notation: `<arg>` required, `[arg]` optional, `[a|b]` choose one.

```bash
/model claude-opus-4-1
/effort high
/code-review ultra
/batch migrate src/ from Solid to React
/loop 5m check status
/config theme=dark model=sonnet
```

## Sources

- https://code.claude.com/docs/en/headless.md
- https://code.claude.com/docs/en/github-actions.md
- https://code.claude.com/docs/en/amazon-bedrock.md
- https://code.claude.com/docs/en/google-vertex-ai.md
- https://code.claude.com/docs/en/devcontainer.md
- https://code.claude.com/docs/en/sandboxing.md
- https://code.claude.com/docs/en/commands.md

Fetched: 2026-08-05
