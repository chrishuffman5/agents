---
name: update-plugin
description: "Guides updating the installed Domain Expert plugin to the latest version. Refreshes the marketplace, updates the plugin, verifies the new version, and handles manual/git installs. WHEN: \"update the plugin\", \"update domain-expert\", \"upgrade the plugin\", \"is there a new version\", \"keep the plugin up to date\", \"refresh the plugin\", \"new plugin version\", \"plugin out of date\", \"latest version of domain-expert\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Update the Domain Expert Plugin

You help the user pull the latest version of the **domain-expert** plugin into their environment. The right procedure depends on how it was installed. Detect the install method first, run the update, then confirm the version changed and remind the user to restart.

> Plugin updates take effect on the **next** Claude Code session. The currently running session keeps the version it started with.

## How to Approach

1. **Detect the install method** (see below) — marketplace install is the common case.
2. **Check the current version** so you can confirm the update actually changed something.
3. **Run the update** for that method.
4. **Verify** the new version and tell the user to restart Claude Code.

## Detect the Install Method

Check `installed_plugins.json` — its presence and the plugin's `installPath` tell you how it was installed:

```bash
# macOS / Linux
cat ~/.claude/plugins/installed_plugins.json
```
```powershell
# Windows (PowerShell)
Get-Content "$env:USERPROFILE\.claude\plugins\installed_plugins.json"
```

| What you find | Install method | Use section |
|---|---|---|
| An entry like `"domain-expert@<marketplace>"` with a versioned `installPath` under `plugins/cache/` | **Marketplace plugin** (Claude Code) | A — Marketplace |
| A plain `git clone` under `.claude/plugins/…` (no `installed_plugins.json` entry) | **Manual git install** | B — Manual git |
| Installed via Copilot / Codex / Gemini | **Other host CLI** | C — Other hosts |

The marketplace name is whatever the marketplace was registered as (commonly `domain-expert`); the full plugin id is `domain-expert@<marketplace>`. Read it from `installed_plugins.json` rather than assuming.

## A — Marketplace Plugin (Claude Code)

This is a two-step flow: refresh the marketplace catalog from GitHub, then update the installed plugin. Both are non-interactive.

### Check current version
```bash
claude plugin list
```
Note the version shown for `domain-expert`.

### Update
```bash
# 1. Refresh the marketplace so it learns about the newest release
claude plugin marketplace update domain-expert

# 2. Update the plugin (use the marketplace name from installed_plugins.json)
claude plugin update domain-expert@domain-expert --scope user
```

Use the scope the plugin is installed at (`user`, `project`, `local`, or `managed`) — `installed_plugins.json` records it under `scope`. A successful run prints e.g. `updated from 0.7.5 to 0.7.6 … Restart to apply changes.`

> In-session alternative: run the slash commands `/plugin marketplace update domain-expert` then `/plugin update domain-expert`, or open the interactive `/plugin` menu.

### Verify
```bash
claude plugin list          # version should now show the latest
```
A fresh `plugins/cache/domain-expert/domain-expert/<new-version>/` folder confirms the update; the old version folder is pruned once it is no longer in use. **Restart Claude Code** to load the new version.

## B — Manual Git Install

If the plugin was cloned directly (e.g., `.claude/plugins/domain-expert/`), update it with git:

```bash
cd ~/.claude/plugins/domain-expert      # adjust to the actual clone path
git fetch origin
git checkout main
git pull --ff-only origin main
```

To pin to a specific released version instead of tracking `main`:
```bash
git fetch --tags
git checkout v0.7.6                      # the desired release tag
```

Restart Claude Code. No `installed_plugins.json` changes are needed for a manual clone.

## C — Other Hosts

| Host | Update command |
|---|---|
| **GitHub Copilot CLI** | `copilot plugin update chrishuffman5/domain-expert` (or reinstall: `copilot plugin install chrishuffman5/domain-expert`) |
| **OpenAI Codex CLI** | `cd ~/.codex/skills/domain-expert && git pull --ff-only`, then restart Codex |
| **Gemini CLI** | `gemini extensions update domain-expert` (or `gemini extensions link` against an updated local clone) |

## Verifying the Live Version

After restarting, confirm the running plugin matches the latest release:

- **Installed (any host):** read `version` in `<install-path>/.claude-plugin/plugin.json`.
- **Latest published:** check the repo's releases — `gh release view --repo chrishuffman5/domain-expert` or https://github.com/chrishuffman5/domain-expert/releases.

If the two match, the user is up to date.

## Troubleshooting

| Symptom | Cause / Fix |
|---|---|
| `claude plugin update` reports "already up to date" but you expect a newer version | The marketplace catalog is stale — run `claude plugin marketplace update domain-expert` first, then retry. |
| New skills/agents don't show up after updating | The session hasn't restarted. Plugin changes apply on the next Claude Code launch. |
| Update succeeds but the old version folder lingers in `plugins/cache/` | It's still `.in_use` by the running session; it is cleaned up after restart. Safe to ignore. |
| `marketplace update` fails to reach GitHub | Network/proxy issue, or the marketplace was registered from a local path — re-add with `claude plugin marketplace add chrishuffman5/domain-expert`. |
| Wrong marketplace name in the update command | Read the exact `domain-expert@<marketplace>` id from `installed_plugins.json`. |
