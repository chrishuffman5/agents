---
name: update-plugin
description: "Refreshes the domain-expert marketplace catalog and updates installed Domain Expert plugins (domain-expert-core plus any per-domain plugin such as database, security, devops, os) to their latest versions. Also handles migrating off the old pre-marketplace monolithic \"domain-expert\" install and finding domain plugins the user doesn't have installed yet. Use when: \"update the plugin\", \"update domain-expert\", \"upgrade domain-expert-core\", \"is there a new version\", \"keep plugins up to date\", \"refresh the marketplace\", \"new plugin version\", \"plugin out of date\", \"what domain plugins do I have installed\", \"why did my domain-expert plugin disappear\". Do NOT use for a first-time marketplace setup with no prior install (`claude plugin marketplace add chrishuffman5/domain-expert`) — only for refreshing or updating what's already installed."
license: MIT
---

# Update the Domain Expert Marketplace and Plugins

`domain-expert` is a **marketplace**, not a single plugin. It ships one plugin per IT domain (`database`, `os`, `networking`, `security`, `devops`, `containers`, `cloud-platforms`, and 11 more) plus `domain-expert-core`, which holds the six cross-domain task agents (architecture-consultant, troubleshooting-agent, migration-expert, iac-consultant, data-expert, security-expert) and this skill. A user typically has several of these plugins installed at once, not just one.

> Plugin updates take effect on the **next** Claude Code session. The currently running session keeps the version it started with.

## How to Approach

1. **Detect install state** — is this a marketplace install (current model, or the pre-split legacy monolithic plugin), a manual git clone, or another host CLI?
2. **Refresh the marketplace catalog** so it knows about the newest releases.
3. **Update the plugin(s) the user asked about** — or list what's installed and update each if they mean "everything."
4. **Verify** the new version(s) and tell the user to restart Claude Code.

## Detect the Install Method

Check `installed_plugins.json` — its entries and their `installPath` tell you how things are installed:

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
| One or more entries like `"database@domain-expert"`, `"domain-expert-core@domain-expert"` with a versioned `installPath` under `plugins/cache/` | **Marketplace install (current)** | A — Marketplace |
| A single entry `"domain-expert@domain-expert"` and nothing else from this marketplace | **Legacy monolithic install (pre-split)** | A2 — Migrating off the legacy plugin |
| A plain `git clone` under `.claude/plugins/…` (no `installed_plugins.json` entry) | **Manual git install** | B — Manual git |
| Installed via Copilot / Codex / Gemini | **Other host CLI** | C — Other hosts |

Read the exact plugin id (`<plugin>@domain-expert`) and `scope` (`user`, `project`, `local`, `managed`) from the file rather than assuming — do not guess.

## A — Marketplace Plugins (Claude Code)

Refreshing and updating are always two separate steps: the refresh pulls the newest catalog from GitHub, the update applies it to an installed plugin.

### Refresh
```bash
claude plugin marketplace update domain-expert
```

### See what's installed
```bash
claude plugin list
```
Look for the `@domain-expert` suffix to see which of the 19 plugins (18 domains + `domain-expert-core`) the user has, and their current versions.

### Update
```bash
# One plugin
claude plugin update domain-expert-core@domain-expert --scope user

# Repeat per plugin the user has installed, e.g.:
claude plugin update database@domain-expert --scope user
claude plugin update security@domain-expert --scope user
```
Use the `scope` recorded for that plugin in `installed_plugins.json`. A successful run prints e.g. `updated from 1.0.0 to 1.1.0 … Restart to apply changes.` If the user wants "everything updated," loop this over every `@domain-expert` entry from `claude plugin list`.

> In-session alternative: `/plugin marketplace update domain-expert` then `/plugin update <name>` per plugin, or the interactive `/plugin` menu.

### Verify
```bash
claude plugin list          # versions should now show the latest
```
A fresh `plugins/cache/<plugin>/<new-version>/` folder confirms the update; old version folders are pruned once no longer in use. **Restart Claude Code** to load the new versions.

## A2 — Migrating Off the Legacy Monolithic Plugin

Before the marketplace split, everything shipped as one plugin named `domain-expert` (skills for all 18 domains, all task agents, this skill). If `installed_plugins.json` still shows only `"domain-expert@domain-expert"`, the user is on that old layout.

The marketplace declares a rename: `domain-expert` → `domain-expert-core`. Running the normal refresh + update flow (`claude plugin marketplace update domain-expert`, then `claude plugin update domain-expert@domain-expert --scope user`) picks up that rename and moves the user onto `domain-expert-core`.

**This is not a like-for-like swap** — `domain-expert-core` only carries the six cross-domain task agents and this skill. The 18 domains' skills and their `<domain>-specialist` agents (database, os, security, etc.) are no longer bundled; each is now its own plugin the user must install separately:

```bash
# Repeat for each domain the user actually uses
claude plugin install database@domain-expert --scope user
claude plugin install security@domain-expert --scope user
claude plugin install devops@domain-expert --scope user
```
Or in-session: `/plugin install <domain>@domain-expert`, or browse the full list of 18 domains via the `/plugin` menu.

If the rename does not resolve automatically (check `claude plugin list` after the update — you should see `domain-expert-core`, not `domain-expert`), fall back to a clean swap:
```bash
claude plugin uninstall domain-expert@domain-expert --scope user
claude plugin install domain-expert-core@domain-expert --scope user
```
Then install the domain plugins the user needs as shown above.

## B — Manual Git Install

If the plugin was cloned directly (e.g., `.claude/plugins/domain-expert/`), update it with git — note this only gives the user the repo's current contents (all plugin directories under `plugins/`), not the marketplace's per-plugin versioning:

```bash
cd ~/.claude/plugins/domain-expert      # adjust to the actual clone path
git fetch origin
git checkout main
git pull --ff-only origin main
```

To pin to a specific released version instead of tracking `main`:
```bash
git fetch --tags
git checkout v1.0.0                      # the desired release tag
```

Restart Claude Code. No `installed_plugins.json` changes are needed for a manual clone. Recommend switching to a real marketplace install (`claude plugin marketplace add chrishuffman5/domain-expert`) so individual plugins version independently.

## C — Other Hosts

| Host | Update command |
|---|---|
| **GitHub Copilot CLI** | `copilot plugin update chrishuffman5/domain-expert` (or reinstall: `copilot plugin install chrishuffman5/domain-expert`) |
| **OpenAI Codex CLI** | `cd ~/.codex/skills/domain-expert && git pull --ff-only`, then restart Codex |
| **Gemini CLI** | `gemini extensions update domain-expert` (or `gemini extensions link` against an updated local clone) |

These hosts do not understand the marketplace's per-plugin split; they track the whole repo.

## Verifying the Live Version

After restarting, confirm the running plugin(s) match the latest release:

- **Installed (any host):** read `version` in `<install-path>/.claude-plugin/plugin.json` for the specific plugin (e.g. `plugins/cache/database/<version>/.claude-plugin/plugin.json`).
- **Latest published:** check the repo's releases — `gh release view --repo chrishuffman5/domain-expert` or https://github.com/chrishuffman5/domain-expert/releases.

If the two match for every plugin the user cares about, they are up to date.

## Troubleshooting

| Symptom | Cause / Fix |
|---|---|
| `claude plugin update` reports "already up to date" but a newer version should exist | The marketplace catalog is stale — run `claude plugin marketplace update domain-expert` first, then retry. |
| New skills/agents don't show up after updating | The session hasn't restarted. Plugin changes apply on the next Claude Code launch. |
| Update succeeds but the old version folder lingers in `plugins/cache/` | It's still `.in_use` by the running session; cleaned up after restart. Safe to ignore. |
| `marketplace update` fails to reach GitHub | Network/proxy issue, or the marketplace was registered from a local path — re-add with `claude plugin marketplace add chrishuffman5/domain-expert`. |
| Wrong plugin id in the update command | Read the exact `<plugin>@domain-expert` id from `installed_plugins.json` — don't assume `domain-expert@domain-expert` still exists post-split. |
| User asks for a domain-specialist agent or skill that's missing | They likely have `domain-expert-core` but not that domain's plugin — install it with `/plugin install <domain>@domain-expert`. |
| `installed_plugins.json` still shows `domain-expert@domain-expert` after an update | The rename didn't resolve — do the manual uninstall/install swap described in A2. |
