# Plugin dependencies

Read this when a plugin needs another plugin present, when building a team bundle plugin, or when resolving a `dependency-*` / `range-conflict` / `no-matching-tag` error.

## Why constrain versions
> Source: https://code.claude.com/docs/en/plugin-dependencies

Without a version constraint a dependency tracks the latest available version, so an upstream release can silently change what your plugin depends on. Worked example from the docs: a platform team ships `secrets-vault` (an MCP wrapper); the deploy team's `deploy-kit` calls it and is tested against v2.1.0. With no constraint, the next `secrets-vault` release — say it renames an MCP tool — breaks every `deploy-kit` install on auto-update. With `~2.1.0`, engineers stay on the highest matching `2.1.x` patch until the deploy team widens the constraint in a new `deploy-kit` release.

When you install a plugin declaring dependencies, Claude Code resolves and installs them automatically and lists what was added at the end of install output. If a dependency later goes missing, `/reload-plugins` and background auto-update reinstall it — provided its marketplace is already configured. Re-running `claude plugin install` on the dependent, or adding a marketplace with `claude plugin marketplace add`, also resolves outstanding missing dependencies. Dependencies from an unconfigured marketplace are left unresolved.

## Declare a dependency
> Source: https://code.claude.com/docs/en/plugin-dependencies

```json
{
  "name": "deploy-kit",
  "version": "3.1.0",
  "dependencies": [
    "audit-logger",
    { "name": "secrets-vault", "version": "~2.1.0" }
  ]
}
```

A bare string is a plugin name at any version the marketplace provides. The object form:

| Field | Type | Description |
|---|---|---|
| `name` | string | Required. Resolves within the same marketplace as the declaring plugin |
| `version` | string | Semver range — `~2.1.0`, `^2.0`, `>=1.4`, `=2.1.0`. Fetches the highest tagged version satisfying the range |
| `marketplace` | string | A different marketplace to resolve `name` in; blocked unless allowlisted |

`version` accepts any Node `semver` expression (caret, tilde, hyphen, comparator ranges). Pre-release versions (`2.0.0-beta.1`) are excluded unless the range opts in with a pre-release suffix such as `^2.0.0-0`.

## Bundle plugins for a team
> Source: https://code.claude.com/docs/en/plugin-dependencies

A manifest can consist of only `name` plus `dependencies` — a bundle plugin:

```json
{
  "name": "backend-standard",
  "version": "1.0.0",
  "description": "Standard plugin set for backend engineers",
  "dependencies": [
    "secrets-vault",
    "deploy-kit",
    { "name": "db-migrate", "version": "^3.0" },
    "oncall-runbook"
  ]
}
```

Installing `backend-standard` resolves all four. To add a tool later, publish a new `backend-standard` version with the extra dependency — since auto-update defaults off for non-Anthropic marketplaces, engineers pick it up by enabling auto-update for the marketplace or running `claude plugin update backend-standard` then `/reload-plugins`. Roll out org-wide by adding the bundle to `enabledPlugins` in managed settings.

## Cross-marketplace dependencies
> Source: https://code.claude.com/docs/en/plugin-dependencies

By default Claude Code refuses to auto-install a dependency from a *different* marketplace than the declaring plugin. The **root marketplace** — the one hosting the plugin the user installs — must allowlist the target via `allowCrossMarketplaceDependenciesOn`. Trust does not chain through intermediate marketplaces.

```json
{
  "name": "acme-tools",
  "owner": { "name": "Acme" },
  "allowCrossMarketplaceDependenciesOn": ["acme-shared"],
  "plugins": [
    {
      "name": "deploy-kit",
      "source": "./deploy-kit",
      "dependencies": [ { "name": "audit-logger", "marketplace": "acme-shared" } ]
    }
  ]
}
```

If the field is missing or does not include the target, install fails with a `cross-marketplace` error naming the field to set. Users can manually install the dependency first to satisfy the constraint without changing the allowlist.

## Tag plugin releases for version resolution
> Source: https://code.claude.com/docs/en/plugin-dependencies

Version constraints resolve against **git tags** on the marketplace repository, convention `{plugin-name}--v{version}` where `{version}` matches that commit's `plugin.json` `version`.

```bash
claude plugin tag --push
```

Before tagging it validates plugin contents, checks that `plugin.json` and the marketplace entry agree on version, requires a clean working tree under the plugin directory, and refuses if the tag exists.

- `--push` pushes to `origin` (needs a configured remote); `--remote` targets another.
- If the push fails the tag is still created locally and the command exits with an error.
- With `--push`, success prints `Created tag secrets-vault--v2.1.0` then `Pushed to origin`. Without it, the command prints the `git push` to run.
- `--dry-run` prints what would be tagged.

Manual equivalent: `git tag secrets-vault--v2.1.0` (you keep `plugin.json` and the marketplace entry in sync yourself).

The `{plugin-name}--` prefix is a prefix match on the full plugin name, so hyphenated names work and one repo can host multiple independently versioned plugins.

When resolving `{ "name": "secrets-vault", "version": "~2.1.0" }`, Claude Code lists the marketplace's tags, filters to `secrets-vault--v*`, and fetches the highest match. With no matching tag the dependent plugin is **disabled** with an error listing available versions.

A local-folder marketplace resolves tags the same way if the folder is a git repo (requires v2.1.196+). Two exceptions install from current folder contents instead: earlier versions do not read tags from local-folder marketplaces (a constrained dependency loads only if that copy satisfies the range), and a non-git local folder has no tags regardless of version.

The resolved tag's semver is recorded separately from `plugin.json`'s `version`, so constraint checks use the fetched tag even if `plugin.json` at that commit is stale. Cache directory names for tag-resolved installs include a 12-character commit-SHA suffix, so force-moving a tag to a different commit produces a fresh cache directory instead of reusing stale content.

**npm marketplace sources**: tag-based resolution does not apply (git-backed sources only). The constraint is still checked at load time — a mismatched installed version disables the dependent plugin with `dependency-version-unsatisfied`.

## How multiple constraints combine
> Source: https://code.claude.com/docs/en/plugin-dependencies

Claude Code intersects ranges across all installed plugins constraining the same dependency and resolves to the highest version satisfying all of them.

| Plugin A requires | Plugin B requires | Result |
|---|---|---|
| `^2.0` | `>=2.1` | One install at the highest `2.x` tag ≥ 2.1.0; both plugins load |
| `~2.1` | `~3.0` | Install of plugin B fails with `range-conflict`; plugin A and the dependency stay as they were |
| `=2.1.0` | none | Dependency stays at `2.1.0`; auto-update skips newer versions while plugin A is installed |

Auto-update fetches a constrained dependency at the highest tag satisfying every installed plugin's range, not necessarily the marketplace's absolute latest. If no tag satisfies all ranges, auto-update skips it and lists the skip in `/plugin` **Errors**, naming the constraining plugin.

Uninstalling the last plugin constraining a dependency releases the hold — it resumes tracking its plain marketplace entry on the next update.

## Enable and disable with dependencies
> Source: https://code.claude.com/docs/en/plugin-dependencies

Enabling a plugin also enables its dependencies recursively at the same scope (requires v2.1.143+; earlier versions enable only the named plugin and surface `dependency-unsatisfied` on the next load).

| Condition | Result |
|---|---|
| A dependency is not installed | Enable fails and prints the `claude plugin install` command for each missing dependency |
| A dependency is blocked by org policy | Enable fails, naming the blocked dependency |
| A dependency is `false` at a scope with higher precedence than the target scope | Enable fails — enable the dependency at that scope, or use `--scope` to write there |
| All dependencies installed and allowed | Enable succeeds; writes `true` for the plugin and each not-already-enabled dependency at the target scope |

This holds even when a dependency's own manifest sets `defaultEnabled: false` — Claude Code writes an explicit `true`. The same applies at install time.

Disabling a plugin is **refused** while another enabled plugin depends on it; the error names the dependents and a chained command:

```text
secrets-vault is still required by deploy-kit. Disable that plugin first, or
disable everything together: claude plugin disable deploy-kit@acme-tools && claude plugin disable secrets-vault@acme-tools
```

## Prune orphaned auto-installed dependencies
> Source: https://code.claude.com/docs/en/plugin-dependencies

```bash
claude plugin prune            # requires v2.1.121+
claude plugin uninstall deploy-kit --prune
```

Lists auto-installed dependencies no longer required by any installed plugin and removes them after confirmation. `Nothing to prune` is the expected output on a fresh install, not an error. `--scope project`/`--scope local` targets a different scope (default `user`); `--dry-run` lists without removing; `-y` skips confirmation, and when stdin/stdout is not a TTY prune lists orphans and exits without removing unless `-y` is passed. Plugins you installed yourself are never pruned — only ones auto-installed via another plugin's `dependencies`.

## Dependency error catalog
> Source: https://code.claude.com/docs/en/plugin-dependencies

Errors appear as descriptive messages (not literal codes) in `claude plugin list` and `/plugin`; the affected plugin is **disabled** until resolved. Check programmatically with `claude plugin list --json` — problem plugins include an `errors` field, clean plugins omit it.

| Error | Meaning | Resolution |
|---|---|---|
| `dependency-unsatisfied` | Declared dependency not installed, or installed but disabled | Run the `claude plugin install` command shown; if the dependency's marketplace is not configured, `claude plugin marketplace add` it; if disabled, enable it |
| `range-conflict` | Version requirements cannot be combined (no version satisfies all ranges, invalid semver syntax, or ranges too complex to intersect) | Uninstall or update one of the conflicting plugins, fix an invalid `version` string, simplify long `\|\|` chains, or ask upstream to widen its constraint |
| `dependency-version-unsatisfied` | Installed dependency's version is outside this plugin's declared range | `claude plugin install <dependency>@<marketplace>` to re-resolve against all current constraints |
| `no-matching-tag` | Dependency's repo has no `{name}--v*` tag satisfying the range | Confirm upstream tags releases per convention, or relax your range |

## Sources

- https://code.claude.com/docs/en/plugin-dependencies

Fetched: 2026-08-05
