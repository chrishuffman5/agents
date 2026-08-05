# Skills and plugins reference (harness mechanics)

Read when wiring skills or plugins into Claude Code — frontmatter fields the harness understands, invocation control, argument substitution, plugin manifests, and marketplace distribution. For *writing* good skill content (progressive disclosure, description craft), use the `agent-skills` sibling skill instead.

## Skills

> Source: https://code.claude.com/docs/en/skills.md

A skill is a `SKILL.md` file with YAML frontmatter plus markdown instructions. Claude loads it when relevant, or the user invokes `/skill-name`. It follows the open Agent Skills standard (`https://agentskills.io`); Claude Code extends it with invocation control, subagent execution (`context: fork`), and dynamic context injection.

Custom commands are merged into skills: `.claude/commands/deploy.md` and `.claude/skills/deploy/SKILL.md` both create `/deploy` and behave the same. Skills add a directory for supporting files, invocation-control frontmatter, and model auto-loading.

### Bundled skills

Prompt-based and available every session: `/doctor`, `/code-review`, `/batch`, `/debug`, `/loop`, `/claude-api`, and others. `disableBundledSkills` turns them all off except `/doctor`. `/verify` and `/code-review` run only when explicitly invoked and are not auto-triggerable by Claude as of v2.1.215+.

`/run`, `/verify`, and `/run-skill-generator` (v2.1.145+) work together to launch and verify apps against the real running app instead of falling back to tests. `/run-skill-generator` records a per-project recipe at `.claude/skills/run-<name>/`.

### Where skills live

| Location | Path | Applies to |
|---|---|---|
| Enterprise | managed settings | All org users |
| Personal | `~/.claude/skills/<name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<name>/SKILL.md` | This project |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | Where the plugin is enabled |

Name-clash precedence: enterprise > personal > project > bundled. Plugin skills are namespaced (`plugin-name:skill-name`) so they never conflict. `.claude/commands/` files also work, but a skill wins over a same-named command.

Nested `.claude/skills/` below the starting directory (e.g. a monorepo package) load lazily the first time Claude reads or edits a file in that subdirectory. On a clash with a root-level skill the nested one gets a directory-qualified name such as `apps/web:deploy`; typing the unqualified `/deploy` auto-includes an instruction to also invoke matching directory-qualified variants (v2.1.203+).

Edits to `SKILL.md` under a watched skills directory are picked up without restart; a brand-new top-level skills directory needs a restart. `--add-dir` / `/add-dir` load `.claude/skills/` from the added directory automatically — an exception to the rule that additional dirs grant file access only. The `permissions.additionalDirectories` setting does **not** load skills.

### Directory structure

```
my-skill/
├── SKILL.md           # required entrypoint
├── template.md
├── examples/sample.md
└── scripts/validate.sh
```

Keep `SKILL.md` under 500 lines and push detail into referenced supporting files.

### Frontmatter reference

Only `description` is recommended; every field is optional.

| Field | Description |
|---|---|
| `name` | Display name for personal/project skills (the command name still comes from the directory/file name). For plugin skills it sets the last command segment |
| `description` | What and when. Combined with `when_to_use` and truncated at 1,536 chars in the listing — put the key use case first |
| `when_to_use` | Extra trigger phrases appended to `description`; counts toward the 1,536 cap |
| `argument-hint` | Autocomplete hint, e.g. `[issue-number]` |
| `arguments` | Named positional args for `$name` substitution (space-separated string or YAML list) |
| `disable-model-invocation` | `true` = only the user can invoke (`/name`); prevents auto-load and preload into a subagent |
| `user-invocable` | `false` = hidden from the `/` menu; only Claude can invoke |
| `allowed-tools` | Tools pre-approved for the invoking turn only (cleared on the next message) |
| `disallowed-tools` | Tools removed from the pool while the skill is active (cleared on the next message) |
| `model` | Model override for the turn (not saved); accepts `/model` values or `inherit` |
| `effort` | Effort override for the turn |
| `context` | `fork` = run in a forked subagent context |
| `agent` | Which subagent type to use with `context: fork` (default `general-purpose`) |
| `background` | With `context: fork`: `false` waits for the result in the same turn (default `true`, requires v2.1.218+) |
| `hooks` | Hooks scoped to this skill's lifecycle |
| `paths` | Glob patterns limiting auto-activation to matching files (comma-string or YAML list) |
| `shell` | `bash` (default) or `powershell` for inline `` !`command` `` execution |
| `metadata` | Free-form YAML map, unused by Claude Code |
| `license` | Agent Skills spec field, unused by Claude Code |
| `compatibility` | Agent Skills spec field (≤500 chars), unused by Claude Code |

Boolean fields accept `yes/no/on/off/1/0` in any case as well as `true/false` (v2.1.218+).

**Outside Claude Code** (Agent Skills spec / claude.ai uploads) only `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools` are valid. Any other key fails hard: `Unexpected key(s) in SKILL.md frontmatter: argument-hint. Allowed properties are: allowed-tools, compatibility, description, license, metadata, name`.

### Invocation control matrix

| Frontmatter | You can invoke | Claude can invoke | Context loading |
|---|---|---|---|
| (default) | Yes | Yes | Description always in context; full skill loads on invoke |
| `disable-model-invocation: true` | Yes | No | Description NOT in context; loads only when you invoke |
| `user-invocable: false` | No | Yes | Description always in context; loads on invoke |

### String substitutions

| Variable | Value |
|---|---|
| `$ARGUMENTS` | All args as typed; if absent from the content, appended as `ARGUMENTS: <value>` |
| `$ARGUMENTS[N]` / `$N` | Nth arg (0-indexed), shell-style quoting for multi-word |
| `$name` | Named arg from the `arguments:` frontmatter list, mapped by position |
| `${CLAUDE_SESSION_ID}` | Current session ID |
| `${CLAUDE_EFFORT}` | `low` \| `medium` \| `high` \| `xhigh` \| `max` (ultracode reports as `xhigh`) |
| `${CLAUDE_SKILL_DIR}` | Directory containing this SKILL.md; also substitutes inside `allowed-tools` Bash rules (v2.1.129+) |
| `${CLAUDE_PROJECT_DIR}` | Project root; also substitutes inside `allowed-tools` (v2.1.196+) |

Escape a literal `$` before a digit, `ARGUMENTS`, or an arg name with a single backslash: `\$1.00`.

```yaml
---
name: render-chart
description: Render a chart from a CSV file
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/render.sh *)
---
Run `${CLAUDE_SKILL_DIR}/scripts/render.sh <csv-file>` to render the chart.
```

Stacking: `/write-tests /fix-issue 123` loads both skills and both receive `123` as `$ARGUMENTS` (up to 6 skills chained, v2.1.199+). Expansion stops at the first token that is not an inline user-invocable skill — a forked-subagent skill like `/code-review` ends the chain.

### Content lifecycle

Rendered content enters as a single message and persists for the session; it is not re-read on later turns. The `allowed-tools` grant clears each turn regardless. Re-invoking with identical rendered content adds only a short "already loaded" note. Auto-compaction re-attaches the most recent invocation of each skill (first 5,000 tokens each, sharing a 25,000-token budget across all skills) after summarization.

### Pre-approve tools for a skill

```yaml
---
name: commit
description: Stage and commit the current changes
disable-model-invocation: true
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status *)
---
```

The grant applies only to the invoking turn; project-scoped skills require workspace-trust acceptance first.

### Dynamic context injection

`` !`<command>` `` at line start (or after whitespace) runs a shell command **before** the skill content reaches Claude; the output replaces the placeholder as plain text and is not re-scanned for further placeholders. The multi-line form is a fenced ` ```! ` block.

```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---
## Pull request context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
## Your task
Summarize this pull request...
```

Disable entirely with `"disableSkillShellExecution": true`; each command is replaced with `[shell command execution disabled by policy]`. Bundled and managed skills are unaffected.

### Running a skill in a subagent

```yaml
context: fork
agent: Explore   # built-in Explore/Plan/general-purpose, or any custom subagent
```

The skill content becomes the subagent's task prompt with no access to conversation history. It runs in background by default; set `background: false` to wait inline. It always waits inline in `-p`/Agent SDK mode, with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, when an earlier invocation of the same skill is still running, or when fired by a scheduled task.

| Approach | System prompt | Task | Also loads |
|---|---|---|---|
| Skill with `context: fork` | From the agent type | SKILL.md content | CLAUDE.md (unless the agent is Explore/Plan) |
| Subagent with `skills:` field | The subagent's own body | Claude's delegation message | Preloaded skills + CLAUDE.md |

### Restricting Claude's skill access

```
Skill            # deny the whole Skill tool
Skill(commit)
Skill(review-pr *)
Skill(deploy *)  # deny
```

`user-invocable` controls menu visibility only, not Skill-tool access — use `disable-model-invocation: true` to block programmatic invocation.

```json
{ "skillOverrides": { "legacy-context": "name-only", "deploy": "off" } }
```

Values: `"on"` (name + description, in menu), `"name-only"`, `"user-invocable-only"` (hidden from Claude's list, in menu), `"off"` (hidden everywhere). The `/skills` menu writes this to `.claude/settings.local.json`. Plugin skills are unaffected — manage those via `/plugin`.

### Evaluating skills

The official `skill-creator` plugin (`/plugin install skill-creator@claude-plugins-official`) automates eval test cases in `evals/evals.json`, isolated subagent runs per case, pass/fail grading, with-skill vs without-skill benchmarking (pass rate, tokens, time), version A/B comparison, and description tuning against should-trigger / should-not-trigger hit rates.

## Plugin manifest and structure

> Source: https://code.claude.com/docs/en/plugins.md

A standalone `.claude/` config produces skill names like `/hello`; a plugin produces namespaced `/plugin-name:hello` and is sharable and versioned through a marketplace.

```json
{
  "name": "my-first-plugin",
  "description": "A greeting plugin to learn the basics",
  "version": "1.0.0",
  "author": { "name": "Your Name" }
}
```

`name` is the unique ID and skill namespace. `version` is optional — omitted on a git-distributed plugin, the commit SHA becomes the version, so every commit is a new version.

### Directory layout

Everything except the manifest lives at the plugin root, **not** inside `.claude-plugin/`.

| Directory/file | Purpose |
|---|---|
| `.claude-plugin/plugin.json` | Manifest (the only thing inside `.claude-plugin/`) |
| `skills/` | `<name>/SKILL.md` directories |
| `commands/` | Flat `.md` skill files (legacy; use `skills/` for new plugins) |
| `agents/` | Custom agent definitions |
| `hooks/hooks.json` | Event handlers |
| `.mcp.json` | MCP server configs |
| `.lsp.json` | LSP server configs |
| `monitors/monitors.json` | Background monitor configs |
| `bin/` | Executables added to the Bash tool's `PATH` while the plugin is enabled |
| `settings.json` | Default settings applied when enabled (currently only `agent` and `subagentStatusLine`) |

A single-skill plugin may put `SKILL.md` at the plugin root, with frontmatter `name` as the invocation name. Plugin root is the directory passed to `--plugin-dir` or containing `.claude-plugin/plugin.json` — never `~/.claude/`.

```json
{ "go": { "command": "gopls", "args": ["serve"], "extensionToLanguage": { ".go": "go" } } }
```

```json
[{ "name": "error-log", "command": "tail -F ./logs/error.log", "description": "Application error log" }]
```

Each monitor stdout line is delivered to Claude as a notification.

### Skills-directory plugins (no marketplace)

```bash
claude plugin init my-tool
```

Creates `~/.claude/skills/my-tool/` with a `.claude-plugin/plugin.json`; it loads next session as `my-tool@skills-dir` with no install step. Any skill folder containing a `.claude-plugin/plugin.json` becomes a plugin this way — inside a project's `.claude/skills/` it requires workspace-trust acceptance first.

### Testing and validation

```bash
claude --plugin-dir ./my-plugin              # local dev, also accepts .zip (v2.1.128+)
claude --plugin-dir ./p1 --plugin-dir ./p2
claude --plugin-url https://example.com/my-plugin.zip   # fetched at startup, session-only
claude plugin validate ./your-plugin [--strict]
```

`--plugin-dir` beats an installed marketplace plugin of the same name for that session, except for plugins force-enabled/disabled by managed settings. `/reload-plugins` picks up changes without restart, reloading plugins, skills, agents, hooks, and plugin MCP/LSP servers.

Community submission goes through `claude.ai/admin-settings/directory/submissions/plugins/new` (Team/Enterprise) or `platform.claude.com/plugins/submit` (individual). The official `claude-plugins-official` marketplace is auto-registered on first interactive launch and curated by Anthropic directly. In `claude-plugins-community`, approved plugins are pinned to a commit SHA with CI auto-bumping.

### Ship default settings

```json
{ "agent": "security-reviewer" }
```

The `agent` key activates a plugin's custom agent as the main-thread agent when the plugin is enabled, applying its system prompt, tools, and model.

## Plugin marketplaces

> Source: https://code.claude.com/docs/en/plugin-marketplaces.md

```json
{
  "name": "company-tools",
  "owner": { "name": "DevTools Team", "email": "devtools@example.com" },
  "plugins": [
    { "name": "code-formatter", "source": "./plugins/formatter", "description": "...", "version": "2.1.0", "author": {"name": "DevTools Team"} },
    { "name": "deployment-tools", "source": {"source": "github", "repo": "company/deploy-plugin"}, "description": "..." }
  ]
}
```

Required top-level keys: `name` (kebab-case, public-facing, one marketplace per name per user), `owner` (`name` required; `email`/`url` optional), `plugins`.

Reserved marketplace names, rejected for third parties and re-checked on every load (not just at add-time): `claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `claude-plugins-community`, `claude-community`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `anthropic-agent-skills`, `knowledge-work-plugins`, `life-sciences`, `claude-for-legal`, `claude-for-financial-services`, `financial-services-plugins`, `first-party-plugins`, `healthcare`, plus any name impersonating an official one.

Optional top-level: `$schema`, `description`, `version`, `metadata.pluginRoot` (base directory for relative sources), `allowCrossMarketplaceDependenciesOn`, `renames` (map of old name → new name or `null`; append-only history, requires v2.1.193+).

### Plugin entry fields

Required: `name`, `source`. Optional: `displayName`, `description`, `version`, `author`, `homepage`, `repository`, `license`, `keywords`, `metadata`, `category`, `tags`, `strict` (default `true`), `relevance`, `defaultEnabled` (default `true`). Component overrides: `skills`, `commands`, `agents`, `hooks`, `mcpServers`, `lspServers` (string or array of custom paths).

### Sources

| Source | Fields | Notes |
|---|---|---|
| Relative path (string) | `"./my-plugin"` | Must start with `./`, resolves against the marketplace root, no `../` |
| `github` | `repo`, `ref?`, `sha?` | `owner/repo` |
| `url` | `url`, `ref?`, `sha?` | Full git URL, `.git` suffix optional |
| `git-subdir` | `url`, `path`, `ref?`, `sha?` | Sparse clone of a monorepo subdirectory |
| `npm` | `package`, `version?`, `registry?` | Installed via `npm install` |

When both `ref` and `sha` are set, `sha` is the effective pin and keeps working even if the branch/tag is later deleted on most hosts.

The **marketplace source** (where `marketplace.json` lives — supports `ref`, not `sha`) is a different concept from a **plugin source** (where an individual listed plugin comes from — supports both).

### Strict mode

| `strict` | Behavior |
|---|---|
| `true` (default) | `plugin.json` is the authority; the marketplace entry may supplement with extra components |
| `false` | The marketplace entry is the entire definition; a `plugin.json` that also declares components is a conflict and fails to load |

### Version resolution

1. `version` in the plugin's `plugin.json`
2. `version` in the marketplace entry
3. The git commit SHA of the plugin source

Setting `version` **pins** the plugin — bump it every release or users get no update. Omit it for git-based sources to treat each commit as a new version. Never set `version` in both places: `plugin.json` wins silently.

### Release channels

Two marketplaces pointing at different refs of the same repo (`stable` / `latest`), assigned to different user groups via `extraKnownMarketplaces` in managed settings.

### Renaming or removing

```json
{
  "name": "acme-tools", "owner": {"name": "Acme"},
  "plugins": [{ "name": "code-formatter", "source": "./plugins/code-formatter" }],
  "renames": { "formatter": "code-formatter", "legacy-linter": null }
}
```

Auto-migration requires v2.1.193+; earlier versions show `plugin-not-found`.

### Hosting and team distribution

```bash
/plugin marketplace add owner/repo
/plugin marketplace add https://gitlab.com/team/plugins.git
/plugin marketplace add ./my-marketplace
```

```json
{
  "extraKnownMarketplaces": { "company-tools": { "source": { "source": "github", "repo": "your-org/claude-plugins" } } },
  "enabledPlugins": { "code-formatter@company-tools": true, "deployment-tools@company-tools": true }
}
```

Managed lockdown via `strictKnownMarketplaces`:

| Value | Behavior |
|---|---|
| undefined (default) | No restrictions |
| `[]` | Complete lockdown, blocks even the official marketplace |
| List of sources | Only exact-matching marketplaces allowed |

```json
{ "strictKnownMarketplaces": [{ "source": "hostPattern", "hostPattern": "^github\\.example\\.com$" }] }
```

`pathPattern` (regex on filesystem path) is also supported for local marketplaces.

### CLI subcommands

```bash
claude plugin marketplace add <source> [--scope user|project|local] [--sparse <paths...>]
claude plugin marketplace list [--json]
claude plugin marketplace remove <name> [--scope ...]
claude plugin marketplace update [name]
claude plugin validate <path> [--strict]
```

### Container/CI pre-population and private repos

```bash
CLAUDE_CODE_PLUGIN_SEED_DIR=/opt/claude-seed
CLAUDE_CODE_PLUGIN_CACHE_DIR=/opt/claude-seed claude plugin marketplace add your-org/plugins
```

The seed directory mirrors `~/.claude/plugins`, is read-only at runtime, and disables auto-updates for seeded marketplaces.

Manual commands (`marketplace add`, `install`, `update`) use your existing git credential helpers. Background auto-update disables credential helpers for `git pull` over HTTPS by default — SSH with `ssh-agent` still works. Set `CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1` to avoid failed re-clone attempts, or configure a global git URL rewrite embedding a token:

```bash
git config --global url."https://x-access-token:YOUR_TOKEN@github.com/acme-corp/plugins".insteadOf "https://github.com/acme-corp/plugins"
```

Clone/pull timeout defaults to 120s; override with `CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS`.

## Sources

- https://code.claude.com/docs/en/skills.md
- https://code.claude.com/docs/en/plugins.md
- https://code.claude.com/docs/en/plugin-marketplaces.md

Fetched: 2026-08-05
