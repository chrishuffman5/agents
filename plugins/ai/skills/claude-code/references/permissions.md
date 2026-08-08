# Permissions and permission modes reference

Read when writing allow/ask/deny rules, choosing a permission mode for a workflow or CI job, explaining why an action was blocked or auto-approved, or configuring auto mode for an organization.

## Permission system

> Source: https://code.claude.com/docs/en/permissions.md

Tiered approval:

| Tool type | Example | Approval required | "Don't ask again" behavior |
|---|---|---|---|
| Read-only | File reads, Grep | No (within working dir + additional dirs) | N/A |
| Bash commands | Shell execution | Yes, except built-in read-only commands | Permanently per repository and command |
| File modification | Edit/write files | Yes | Until session end |

Rules live under `permissions` in `settings.json`: `permissions.allow`, `permissions.deny`, `permissions.ask`, `permissions.defaultMode`. Commit project-scope rules to share with the team; each developer layers personal rules in `.claude/settings.local.json`.

### Rule syntax

- `Bash(npm run lint)` — exact match
- `Bash(npm run test *)` — prefix match. The space before `*` matters: `Bash(git diff*)` also matches `git diff-index`
- `Read(~/.zshrc)`, `Read(./.env)`, `Read(./secrets/**)` — glob-style path rules
- `Edit(*.ts)` — file-type scoped
- `Agent(subagent-name)` — restrict which subagent types can be spawned
- `Skill(name)` exact / `Skill(name *)` prefix — skill invocation control
- `mcp__<server>__<tool>`, `mcp__<server>`, `mcp__*` — MCP patterns (also valid in subagent `tools`/`disallowedTools`)

`claude --allowedTools "Bash,Read,Edit"` and `--disallowedTools "Agent(Explore)"` apply the same syntax for one invocation. `/permissions` (alias `/allowed-tools`) opens the in-session rule editor and saves to the appropriate scope.

## Permission modes

> Source: https://code.claude.com/docs/en/permission-modes.md

| Mode | What runs without asking | Best for |
|---|---|---|
| `default` (label **Manual**; CLI alias `manual` since v2.1.200) | Reads only | Getting started, sensitive work |
| `acceptEdits` | Reads, file edits, common filesystem commands in working dir | Iterating on reviewed code |
| `plan` | Reads, plus classifier-approved commands when auto mode is available | Exploring before changing |
| `auto` | Everything, with background classifier safety checks | Long tasks, reducing prompt fatigue |
| `dontAsk` | Only pre-approved tools (auto-denies everything else) | Locked-down CI/scripts |
| `bypassPermissions` | Everything (explicit `ask` rules and the root/home `rm -rf` circuit breaker still prompt) | Isolated containers/VMs only |

Set with `claude --permission-mode <mode>` (`--dangerously-skip-permissions` equals `bypassPermissions`) or persist:

```json
{ "permissions": { "defaultMode": "acceptEdits" } }
```

`Shift+Tab` cycles `default → acceptEdits → plan`, plus `bypassPermissions`/`auto` if enabled, in that order. `dontAsk` never appears in the cycle — set it via flag or setting only.

### `acceptEdits`

Auto-approves file edits plus `mkdir`, `touch`, `rm`, `rmdir`, `mv`, `cp`, `sed` — including with safe env-var prefixes (`LANG=C`) or wrappers (`timeout`, `nice`, `nohup`) — scoped to the working directory plus `additionalDirectories`. With the PowerShell tool enabled it also auto-approves `Set-Content`, `Add-Content`, `Clear-Content`, `Remove-Item` in scope; a quoted argument containing an apostrophe still prompts.

### `plan`

Claude researches and proposes without editing. Enter via the `/plan` prefix or `Shift+Tab`. When auto mode is available and `useAutoModeDuringPlan` is on (default), the classifier reviews shell commands instead of prompting. Approving a plan offers **Yes, and use auto mode** / **Yes, manually approve edits** / **No, keep planning**. `Ctrl+G` opens the plan in your editor.

### `auto` (classifier-backed)

A separate classifier model (Sonnet 5 by default) reviews each risky action before it runs, replacing fixed rule prompts for most actions.

Requirements: a Team/Enterprise org (admins can disable with `permissions.disableAutoMode: "disable"`); model Opus 4.6+/Sonnet 4.6+/Fable 5 on the Anthropic API or Claude Platform on AWS, or Sonnet 5/Opus 4.7+/Fable 5 on Bedrock/Vertex/Foundry/gateway.

`defaultMode: "auto"` is **ignored** in `.claude/settings.json` and `.claude/settings.local.json` as of v2.1.142+ — it must be set in `~/.claude/settings.json` so a repository cannot grant itself auto mode.

**Blocked by default** (partial list): `curl | bash`; sending sensitive data externally; production deploys and migrations; mass cloud-storage deletion; granting IAM or repo permissions; `git reset --hard`, `git checkout -- .`, `git restore .`, `git clean -fd`, `git stash drop`/`clear`; force push; `git commit --amend` on non-session or already-pushed commits; `terraform`/`pulumi`/`cdk`/`terragrunt destroy`; writing to secret managers; merging unapproved PRs; disabling CI checks; toggling production feature flags; printing live credentials to the transcript; routing installs around internal package registries; `--insecure`-style safety-disarming flags; launching nested `--dangerously-skip-permissions`/`--no-sandbox` agent loops; deleting files in `/tmp` by wildcard, glob, or age rather than a named path; writing to Claude Code's own session transcripts (`.jsonl` under `~/.claude/projects/`).

**Allowed by default**: local file operations in the working directory; installing dependencies from lock files/manifests; reading `.env` and sending those credentials to the matching API; read-only HTTP; pushing to any branch of the current repo except deploy-named branches like `production`/`gh-pages` (judged on content); deleting jobs Claude created earlier in the session; agent-to-agent messages in multi-agent sessions.

Boundaries stated in conversation ("don't push", "wait for review") are treated as a hard block signal by the classifier but are **not** stored as rules and are lost on context compaction. Use a `permissions.deny` rule for a guarantee.

Fallback: 3 consecutive blocks or 20 total blocks pauses auto mode and reverts to prompting; thresholds are not configurable. `claude auto-mode defaults` prints the full rule lists as JSON. Administrators narrow trusted infrastructure with `autoMode.environment` in managed settings.

Subagents under auto mode get three classifier checks: the delegated task description at spawn, each subagent action during the run, and the full action history when the subagent finishes (a security warning is prepended to flagged results). Any `permissionMode` in subagent frontmatter is ignored while the parent is in auto mode.

### `dontAsk`

Auto-denies anything not in `permissions.allow`, not in the built-in read-only command set, and not approved by a `PreToolUse` hook. It denies `AskUserQuestion`, org-`ask` connector tools, and `requiresUserInteraction`-marked MCP tools even when allow rules match. It never waits for input, which is what makes it correct for CI.

```bash
claude --permission-mode dontAsk
```

### `bypassPermissions`

Disables permission prompts and safety checks entirely, including protected-path writes (that exemption requires v2.1.126+). Explicit `ask` rules and org-`ask` connector tools still prompt. `rm -rf /` and `rm -rf ~`, including command- and process-substitution variants, still prompt as a circuit breaker (v2.1.208+).

Enable with `permissions.defaultMode: "bypassPermissions"` or `--permission-mode bypassPermissions` / `--dangerously-skip-permissions` at launch; you cannot switch into it mid-session unless it was enabled at launch. First interactive use shows a one-time acceptance dialog. It refuses to start as root/sudo on Linux/macOS outside a recognized sandbox — run a dev container as a non-root user instead. Administrators block it with `permissions.disableBypassPermissionsMode: "disable"` in managed settings.

## Protected paths

Writes to protected paths are never auto-approved except in `bypassPermissions`. The safety check runs **before** rule evaluation, so a matching `permissions.allow` rule does not bypass it.

| Mode | Protected-path writes |
|---|---|
| `default`, `acceptEdits` | Prompted |
| `plan` | Prompted (allowed if bypass available; else classifier-routed if auto mode available) |
| `auto` | Routed to classifier |
| `dontAsk` | Denied |
| `bypassPermissions` | Allowed |

Protected directories: `.git`, `.config/git`, `.vscode`, `.idea`, `.husky`, `.cargo`, `.devcontainer`, `.yarn`, `.mvn`, `.claude` (except `.claude/worktrees`).

Protected files: `.gitconfig`, `.gitmodules`, shell rc files (`.bashrc`, `.zshrc`, …), `.npmrc`, `.yarnrc`, `.pnpmfile.cjs`, `bunfig.toml`, `.bazelrc`, `.pre-commit-config.yaml`, `lefthook.yml`, `gradle-wrapper.properties`, `.devcontainer.json`, `.mcp.json`, `.claude.json`, and similar.

## Sources

- https://code.claude.com/docs/en/permissions.md
- https://code.claude.com/docs/en/permission-modes.md

Fetched: 2026-08-05
