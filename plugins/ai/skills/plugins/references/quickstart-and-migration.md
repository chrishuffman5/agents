# Quickstart, standalone-vs-plugin, and migration

Read this when starting a plugin from nothing, deciding whether a `.claude/` directory is enough, migrating existing standalone config into a plugin, or looking for an existing official plugin instead of building one.

## Standalone `.claude/` vs a plugin
> Source: https://code.claude.com/docs/en/plugins

| Approach | Skill names | Best for |
|---|---|---|
| Standalone (`.claude/` directory) | `/hello` | Personal workflows, project-specific customizations, quick experiments |
| Plugin (self-contained directory, optionally with `.claude-plugin/plugin.json`) | `/plugin-name:hello` | Sharing with teammates, distributing to the community, versioned releases, reuse across projects |

Choose standalone when: customizing for a single project; the config is personal; you are experimenting before packaging; you want short unnamespaced skill names.

Choose a plugin when: sharing with a team or community; you need the same skills and agents across projects; you want version control and easy updates; you are distributing through a marketplace; and namespaced skills are acceptable (namespacing is what prevents cross-plugin conflicts).

## Minimal plugin end-to-end
> Source: https://code.claude.com/docs/en/plugins

```bash
mkdir my-first-plugin
mkdir my-first-plugin/.claude-plugin
```

`my-first-plugin/.claude-plugin/plugin.json`:

```json
{
  "name": "my-first-plugin",
  "description": "A greeting plugin to learn the basics",
  "version": "1.0.0",
  "author": { "name": "Your Name" }
}
```

| Field | Purpose |
|---|---|
| `name` | Unique identifier and skill namespace, e.g. `/my-first-plugin:hello` |
| `description` | Shown in the plugin manager |
| `version` | Optional. If set, updates come only on bump. If omitted (git-distributed), every commit is a new version |
| `author` | Optional attribution |

```bash
mkdir -p my-first-plugin/skills/hello
```

`my-first-plugin/skills/hello/SKILL.md`:

```markdown
---
description: Greet the user with a friendly message
disable-model-invocation: true
---

Greet the user warmly and ask how you can help them today.
```

Test it:

```bash
claude --plugin-dir ./my-first-plugin
```

```shell
/my-first-plugin:hello
```

`/help` → **Custom commands** lists it under the plugin namespace. Plugin skills are always namespaced to prevent name collisions; change the namespace by editing `name` in `plugin.json`.

Arguments via `$ARGUMENTS`:

```markdown
---
description: Greet the user with a personalized message
---

# Hello Skill

Greet the user named "$ARGUMENTS" warmly and ask how you can help them today.
```

`/reload-plugins` picks up the change. Note: the reload summary's skills count covers only `commands/` directories, so it can report `0 skills` even though a `skills/`-based skill reloaded correctly.

## Develop in your skills directory instead
> Source: https://code.claude.com/docs/en/plugins

```bash
claude plugin init my-tool
```

Creates `~/.claude/skills/my-tool/` with `.claude-plugin/plugin.json` and a starter `SKILL.md`. It loads automatically next session as `my-tool@skills-dir` — no marketplace and no install step — and appears in `/plugin` and `claude plugin list`.

## Add more component types
> Source: https://code.claude.com/docs/en/plugins

Add a `skills/` directory with `<name>/SKILL.md` folders and a clear frontmatter `description` so Claude knows when to invoke each. After installing a plugin, check the install summary — if it says `Run /reload-plugins to activate.`, run it.

**LSP**: for common languages (TypeScript, Python, Rust, …) install the prebuilt LSP plugins from the official marketplace rather than authoring your own; build a custom `.lsp.json` only for uncovered languages. Confirm a server starts via `/plugin` → **Errors** (e.g. `Executable not found in $PATH`); `claude --debug` explains why an entry was skipped.

**Monitors**: add `monitors/monitors.json`; Claude Code starts each one automatically when the plugin is active — no instruction to "start watching" is needed.

**Default settings**: a `settings.json` at the plugin root can set `agent` (activates a plugin agent as the main thread, with its system prompt, tool restrictions, and model) and `subagentStatusLine`. These take priority over `settings` declared in `plugin.json`; unknown keys are silently ignored.

## Migrate `.claude/` config into a plugin
> Source: https://code.claude.com/docs/en/plugins

```bash
mkdir -p my-plugin/.claude-plugin
```

```json
{
  "name": "my-plugin",
  "description": "Migrated from standalone configuration",
  "version": "1.0.0"
}
```

Copy the existing directories (some may not exist — `cp` prints "No such file or directory" and copies nothing, which is safe to ignore):

```bash
cp -r .claude/commands my-plugin/
cp -r .claude/agents my-plugin/
cp -r .claude/skills my-plugin/
```

Hooks keep the identical format, just relocated to `my-plugin/hooks/hooks.json`. The hook command receives JSON on stdin, so use `jq` to extract fields:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "jq -r '.tool_input.file_path' | xargs npm run lint:fix" }]
      }
    ]
  }
}
```

Test with `claude --plugin-dir ./my-plugin`.

### What changes

| Standalone (`.claude/`) | Plugin |
|---|---|
| Only available in one project | Shareable via marketplaces |
| Files in `.claude/commands/` | Files in `plugin-name/commands/` |
| Hooks in `settings.json` | Hooks in `hooks/hooks.json` |
| Must manually copy to share | Install with `/plugin install` |

After migrating, remove the originals from `.claude/` to avoid duplicates:

- **Agents**: project/user `.claude/agents/` definitions *override* same-named plugin agents, so the plugin version only takes effect once the originals are removed.
- **Skills**: plugin skills are namespaced (`/plugin-name:skill-name`), so the original `/skill-name` and the plugin copy both remain available — neither overrides the other.

## Official marketplace catalog (as of 2026-08-05)
> Source: https://code.claude.com/docs/en/discover-plugins

Registered automatically on first interactive launch as `claude-plugins-official`; browse via `/plugin` → **Discover** or claude.com/plugins. Install with `/plugin install <name>@claude-plugins-official`.

If install fails with `Marketplace "claude-plugins-official" not found`, run `/plugin marketplace add anthropics/claude-plugins-official` and retry. A plugin-not-found triggers an automatic catalog refresh and retry; with auto-update off, refresh manually via `/plugin marketplace update claude-plugins-official`.

Categories:

- **Code intelligence** — the LSP plugins (see `components.md`).
- **External integrations** (bundled MCP servers): source control `github`, `gitlab`; project management `atlassian`, `asana`, `linear`, `notion`; design `figma`; infrastructure `vercel`, `firebase`, `supabase`; communication `slack`; monitoring `sentry`.
- **Automatic security review**: `security-guidance` reviews each change for common vulnerabilities and has Claude fix findings in the same session.
- **Development workflows**: `commit-commands`, `pr-review-toolkit`, `agent-sdk-dev`, `plugin-dev`.
- **Output styles**: `explanatory-output-style`, `learning-output-style`.

The official marketplace is curated at Anthropic's sole discretion — there is no application process, and the submission forms feed the **community** marketplace instead.

## When `/plugin` is unavailable
> Source: https://code.claude.com/docs/en/discover-plugins

If Claude reports that `/plugin` is not available (some non-terminal environments), use the plugin browser in the Claude desktop app, or declare the plugin under `enabledPlugins` in `.claude/settings.json` for cloud sessions.

## Sources

- https://code.claude.com/docs/en/plugins
- https://code.claude.com/docs/en/discover-plugins

Fetched: 2026-08-05
