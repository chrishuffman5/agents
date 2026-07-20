# Release Management: Versioning, Tags & GitHub Releases

## Semantic Versioning (SemVer 2.0.0)

```
MAJOR . MINOR . PATCH [-prerelease] [+build]
  2   .   4   .   1        -rc.1       +20260525
```

| Increment | When | Example |
|---|---|---|
| **MAJOR** | Backward-**incompatible** API change | `2.4.1 → 3.0.0` |
| **MINOR** | Backward-compatible new functionality | `2.4.1 → 2.5.0` |
| **PATCH** | Backward-compatible bug fix | `2.4.1 → 2.4.2` |
| **Pre-release** | Unstable preview; lower precedence than release | `3.0.0-rc.1`, `3.0.0-beta.2` |
| **Build metadata** | Ignored for precedence | `2.4.1+exp.sha.5114f85` |

Rules that matter: pre-release versions sort **before** their release (`1.0.0-rc.1 < 1.0.0`); `0.y.z` is "anything may change" (pre-1.0); once published, a version's contents are immutable — fix-forward with a new version.

**Apps vs. libraries:** strict SemVer is a *contract for consumers*, so it's essential for libraries/APIs. Internal apps often use SemVer loosely or switch to **CalVer** (`2026.05.0`) when "breaking change" has no meaning for an end-deployed product.

## Conventional Commits

A commit-message convention that lets tooling compute the next version and generate the changelog.

```
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

| Type | Bumps | Changelog section |
|---|---|---|
| `feat:` | MINOR | Features |
| `fix:` | PATCH | Bug Fixes |
| `feat!:` / `fix!:` / `BREAKING CHANGE:` footer | MAJOR | ⚠ Breaking Changes |
| `perf:` | PATCH | Performance |
| `docs:` `style:` `refactor:` `test:` `chore:` `ci:` `build:` | none | (usually omitted) |

```
feat(auth): add SAML SSO support

Adds /auth/saml endpoints and IdP metadata config.

Closes #142
BREAKING CHANGE: removes the deprecated /auth/legacy endpoint
```

Enforce with **commitlint** + a `commit-msg` hook (Husky), or check PR titles in CI when you squash-merge (the PR title becomes the commit).

## Tags

A tag names a commit. Use **annotated** tags for releases — they carry author, date, and message, and are what `git describe` and most release tooling expect.

```bash
# Annotated (correct for releases)
git tag -a v2.4.1 -m "Release 2.4.1"
git push origin v2.4.1
git push origin --tags          # push all tags (use deliberately)

# Lightweight (avoid for releases — just a moving pointer, no metadata)
git tag v2.4.1                   # ✗ don't use for releases

# Inspect
git describe --tags             # e.g. v2.4.1-3-g5114f85  (nearest tag + commits since)
git tag -l 'v2.4.*'             # list matching tags
```

**Immutability:** never move or delete a published tag. If a release is bad, ship `v2.4.2`. Protect `v*` tags with a ruleset (see `pull-requests.md`).

Tag the commit that actually landed on the release line — the squash/merge commit on `main`, or the tip of `release/x.y` — never a feature branch.

## GitHub Releases

A Release wraps a tag with rendered notes and downloadable assets.

```bash
# Auto-generate notes from merged PRs since the last tag
gh release create v2.4.1 --generate-notes

# With curated notes + build artifacts
gh release create v2.4.1 \
  --title "v2.4.1" \
  --notes-file CHANGELOG-2.4.1.md \
  ./dist/app-2.4.1.tar.gz ./dist/app-2.4.1.tar.gz.sha256

# Pre-release / draft
gh release create v3.0.0-rc.1 --prerelease --generate-notes
gh release create v2.5.0 --draft --generate-notes   # publish later from UI/API
```

Configure auto-notes with `.github/release.yml` to group PRs by label:

```yaml
changelog:
  categories:
    - title: ⚠ Breaking Changes
      labels: [breaking]
    - title: Features
      labels: [enhancement, feature]
    - title: Bug Fixes
      labels: [bug, fix]
    - title: Other
      labels: ["*"]
  exclude:
    labels: [skip-changelog, dependencies]
```

## Changelog

Keep a human-readable `CHANGELOG.md` following *Keep a Changelog* (Added / Changed / Deprecated / Removed / Fixed / Security). With Conventional Commits, generate it instead of hand-writing — the tools below do this.

## Release Automation

Don't bump versions or write changelogs by hand. Let the commit history drive it.

| Tool | Ecosystem | How it works |
|---|---|---|
| **release-please** (Google) | Language-agnostic; great with GitHub Actions | Maintains a "release PR" that bumps version + updates `CHANGELOG.md` from Conventional Commits; merging it tags + creates the Release |
| **semantic-release** | Node-centric (plugins for others) | On each push to a release branch, computes version, tags, publishes (npm), creates GitHub Release — fully automated, no release PR |
| **changesets** | JS monorepos | Contributors add intent files; a bot opens a versioning PR; supports independent per-package versions |
| **GoReleaser** | Go | Builds cross-platform binaries + archives, creates the GitHub Release with assets/checksums on tag push |

### Example: release-please via GitHub Actions

```yaml
# .github/workflows/release.yml
on:
  push:
    branches: [main]
permissions:
  contents: write
  pull-requests: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4
        with:
          release-type: node   # or simple, python, go, ...
```

The build/publish that *reacts* to the created tag/release lives in a separate workflow (`on: push: tags: ['v*.*.*']` or `on: release: types: [published]`) — see the `github-actions` skill.

## Supported-Version Strategy

If you maintain multiple versions, publish a support policy and back-port fixes:

| Approach | Meaning |
|---|---|
| **Latest only** | Only the newest minor gets fixes; users must upgrade |
| **N-1 / N-2** | Current + previous one or two minors get patches |
| **LTS lines** | Designated versions (e.g., `2.x`) supported for a fixed window |

Each supported line has its own `release/x.y` branch; fixes land on `main`, then cherry-pick/back-port and cut a new PATCH tag on each line (see `branching.md`).
