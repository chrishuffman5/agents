# Hosting, versioning, and release lifecycle

Read this when publishing a marketplace, wiring private-repo credentials, choosing a versioning strategy, setting up release channels, or renaming/removing a plugin.

## Host and distribute
> Source: https://code.claude.com/docs/en/plugin-marketplaces

**GitHub (recommended)**: create a repo, add `.claude-plugin/marketplace.json`, users add it with `/plugin marketplace add owner/repo`. Benefits: version control, issues, team collaboration.

**Other git services** — any host works (GitLab, Bitbucket, self-hosted):

```shell
/plugin marketplace add https://gitlab.com/company/plugins.git
```

## Private repositories
> Source: https://code.claude.com/docs/en/plugin-marketplaces

Claude Code supports private-repo plugin sources. When distributed via Organization settings > Plugins, your git credentials are not involved. Otherwise:

**Commands you run** (`/plugin marketplace add`, `/plugin install`, `/plugin update`, `/plugin marketplace update`) use your existing git credential helpers — HTTPS via `gh auth login`, macOS Keychain, or `git-credential-store` behaves as in your terminal. SSH works if the host is in `known_hosts` and the key is in `ssh-agent`; interactive SSH prompts for fingerprint or passphrase are suppressed. GitHub `owner/repo` shorthand clones over **SSH by default**; set `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` for HTTPS.

**Background auto-updates** are the trap: the background refresh **disables git credential helpers** for its `git pull`, so it cannot authenticate to private repos over HTTPS even with a helper configured. SSH remotes with a key in `ssh-agent` still work. On pull failure Claude Code falls back to a full re-clone, which does use stored credentials but can time out on large repos.

Two settings for predictable behavior:

- `CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1` — keep the existing clone when a background pull fails instead of deleting and re-cloning; manual `/plugin marketplace update` still pulls with your credentials.
- Configure a git credential helper (e.g. `gh auth setup-git`) so the re-clone fallback can authenticate.

Setting `GITHUB_TOKEN` alone does **not** enable background auth — tokens work only through a configured credential helper (the `gh` CLI helper reads `GH_TOKEN`/`GITHUB_TOKEN`).

To make the background pull itself authenticate over HTTPS, configure a global git URL rewrite:

```bash
git config --global url."https://x-access-token:YOUR_TOKEN@github.com/acme-corp/plugins".insteadOf "https://github.com/acme-corp/plugins"
```

Scope the rewrite to the marketplace repo or org path — a host-only base rewrite applies to *every* fetch and push to that host, including your own repos.

| Provider | Rewritten URL form |
|---|---|
| GitHub | `https://x-access-token:YOUR_TOKEN@github.com/acme-corp/plugins` |
| GitLab | `https://oauth2:YOUR_TOKEN@gitlab.com/acme-corp/plugins` |
| Bitbucket | `https://x-token-auth:YOUR_TOKEN@bitbucket.org/acme-corp/plugins` |

The rewrite stores the token in plaintext in gitconfig — use a read-only token.

**CI/CD**: on GitHub Actions, export a token with read access to the marketplace repo as `GH_TOKEN` and run `gh auth setup-git` (the default workflow token only accesses its own repo). A global URL rewrite in the pipeline also authenticates the background pull directly.

## Require marketplaces for your team
> Source: https://code.claude.com/docs/en/plugin-marketplaces

`.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "company-tools": { "source": { "source": "github", "repo": "your-org/claude-plugins" } }
  },
  "enabledPlugins": {
    "code-formatter@company-tools": true,
    "deployment-tools@company-tools": true
  }
}
```

Team members are prompted to install these marketplaces and plugins when they trust the project folder.

A local `directory`/`file` source with a relative path resolves against the repo's **main checkout** — running from a git worktree still points at the main checkout, so all worktrees share the marketplace location. Marketplace state lives once per user in `~/.claude/plugins/known_marketplaces.json`, not per project.

## Pre-populate plugins for containers
> Source: https://code.claude.com/docs/en/plugin-marketplaces

Set `CLAUDE_CODE_PLUGIN_SEED_DIR` to a directory Claude Code reads at startup so marketplaces and plugins are already available with no runtime cloning. Layer multiple seeds separated by `:` (Unix) or `;` (Windows); the first seed containing a given marketplace or plugin cache wins.

```text
$CLAUDE_CODE_PLUGIN_SEED_DIR/
  known_marketplaces.json
  marketplaces/<name>/...
  cache/<marketplace>/<plugin>/<version>/...
```

Build it by running Claude Code once during image build, installing plugins, then copying `~/.claude/plugins` into the image — or install directly to the seed path:

```bash
CLAUDE_CODE_PLUGIN_CACHE_DIR=/opt/claude-seed claude plugin marketplace add your-org/plugins
CLAUDE_CODE_PLUGIN_CACHE_DIR=/opt/claude-seed claude plugin install my-tool@your-plugins
```

Then set `CLAUDE_CODE_PLUGIN_SEED_DIR=/opt/claude-seed` in the container runtime environment.

Behavior:

- **Read-only** — never written to; auto-updates are disabled for seed marketplaces.
- **Seed entries take precedence** and overwrite matching user-config entries on every startup. Use `/plugin disable` to opt out of a seed plugin rather than removing the marketplace.
- **Path resolution** probes `$CLAUDE_CODE_PLUGIN_SEED_DIR/marketplaces/<name>/` at runtime instead of trusting stored paths, so it works when mounted at a different path than it was built at.
- **Mutation blocked** — `/plugin marketplace remove`/`update` against a seed-managed marketplace fails with guidance to update the seed image.
- **Composes with settings** — `extraKnownMarketplaces`/`enabledPlugins` declaring a marketplace already in the seed uses the seed copy instead of cloning.

## Version resolution
> Source: https://code.claude.com/docs/en/plugin-marketplaces

Plugin versions are the **cache key** determining update availability: if the resolved version matches what is installed, `/plugin update` and auto-update skip it.

Resolution order, first that is set wins:

1. `version` in the plugin's `plugin.json`
2. `version` in the plugin's marketplace entry
3. Git commit SHA of the plugin's source (for `github`, `url`, `git-subdir`, and relative-path sources inside a git-hosted marketplace)
4. `unknown` — for `npm` sources or local directories not inside a git repo

| Approach | How | Update behavior | Best for |
|---|---|---|---|
| Explicit version | `"version": "2.1.0"` in `plugin.json` | Updates only on bump; pushing commits alone does nothing | Published plugins, stable release cycles |
| Commit-SHA version | Omit `version` everywhere | Updates on every new commit | Internal, actively developed plugins |

**Warning**: setting `version` in `plugin.json` pins the plugin — you must bump it every release. Avoid setting `version` in *both* `plugin.json` and the marketplace entry: `plugin.json` always wins silently, so a stale manifest version masks a version set in `marketplace.json`.

If using explicit versions, follow semver (`MAJOR.MINOR.PATCH`): MAJOR = breaking, MINOR = features, PATCH = fixes. Document changes in `CHANGELOG.md`.

## Release channels
> Source: https://code.claude.com/docs/en/plugin-marketplaces

Two marketplaces pointing at different refs or SHAs of the same repo, assigned to user groups via managed settings.

```json
{
  "name": "stable-tools",
  "plugins": [
    { "name": "code-formatter", "source": { "source": "github", "repo": "acme-corp/code-formatter", "ref": "stable" } }
  ]
}
```

```json
{
  "name": "latest-tools",
  "plugins": [
    { "name": "code-formatter", "source": { "source": "github", "repo": "acme-corp/code-formatter", "ref": "latest" } }
  ]
}
```

**Warning**: each channel must resolve to a *different* version. With explicit versions, `plugin.json` must declare a different `version` at each pinned ref; with versions omitted, distinct commit SHAs already distinguish the channels. Two refs resolving to the same version string are treated as identical and the update is skipped.

Assign via managed `extraKnownMarketplaces`:

```json
{
  "extraKnownMarketplaces": {
    "stable-tools": { "source": { "source": "github", "repo": "acme-corp/stable-tools" } }
  }
}
```

The early-access group receives `latest-tools` instead, keyed the same way.

## Rename or remove a plugin
> Source: https://code.claude.com/docs/en/plugin-marketplaces

A plugin's `name` is its stable identifier — referenced in `enabledPlugins`, `pluginConfigs`, and `/plugin install`. Changing it breaks every existing install. To relabel the UI without breaking installs, set `displayName` and keep `name` unchanged.

To actually change `name`, or to remove a plugin from `plugins`, add a top-level `renames` entry (automatic migration requires v2.1.193+):

```json
{
  "name": "acme-tools",
  "owner": { "name": "Acme" },
  "plugins": [ { "name": "code-formatter", "source": "./plugins/code-formatter" } ],
  "renames": { "formatter": "code-formatter", "legacy-linter": null }
}
```

Behavior when a user's settings reference the old name:

- **Points to a new name**: loads under the new name, shows a one-line notice (`Renamed to "code-formatter" in the "acme-tools" marketplace`), and rewrites the old key to the new key in user/project/local settings for both `enabledPlugins` and `pluginConfigs`. The notice appears once.
- **`null` entry**: drops the old key; the notice reports removal.
- **Remote source** (`github`, `npm`): Claude Code reports `plugin-cache-miss` after the rename — the user must run `/plugin install` once to fetch under the new name.

Treat `renames` as **append-only**: keep old entries even after users are presumed migrated. Chains are followed — to rename `code-formatter` → `formatter-pro` later, add a *second* entry rather than editing the first; a user still on the original `formatter` resolves through both hops.

`claude plugin validate .` rejects any `renames` chain that cycles or does not terminate at `null` or a name listed in `plugins`.

**Managed/policy settings are read-only** to Claude Code, so a plugin enabled there cannot be rewritten automatically; the rename notice recurs each session until an admin updates `enabledPlugins` in managed settings. The same applies to plugins enabled via other read-only sources such as `--add-dir`.

Earlier Claude Code versions ignore `renames` and report `plugin-not-found` for the old name.

## Validation and testing
> Source: https://code.claude.com/docs/en/plugin-marketplaces

```bash
claude plugin validate .
```

or inside Claude Code:

```shell
/plugin validate .
/plugin marketplace add ./path/to/marketplace
/plugin install test-plugin@marketplace-name
```

## Plugin suggestions
> Source: https://code.claude.com/docs/en/discover-plugins

When an administrator allowlists a marketplace via the `pluginSuggestionMarketplaces` managed setting, plugins marked relevant to the current working directory are pinned at the top of `/plugin` Discover with a "suggested for this directory" label, driven by each plugin entry's `relevance` field.

## Sources

- https://code.claude.com/docs/en/plugin-marketplaces
- https://code.claude.com/docs/en/plugins-reference
- https://code.claude.com/docs/en/discover-plugins

Fetched: 2026-08-05
