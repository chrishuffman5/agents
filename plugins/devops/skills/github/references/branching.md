# Branching Strategies

The branching model is a contract between three things: how often you deploy, how many versions you support at once, and how confident your automated tests/flags are. Pick the lightest model those three allow.

## Trunk-Based Development

Everyone integrates into `main` ("trunk") at least daily. Branches live hours, not days.

```
main  ──●──●──●──●──●──●──●──▶   (always releasable, deployed continuously)
         \        \
          ●─●       ●            short branches, merged same day
```

- **Requires:** strong automated tests, fast CI, and **feature flags** to merge incomplete work safely.
- **Releases:** deploy `main` continuously, or cut a `release/x.y` branch at release time (release-from-trunk).
- **Strength:** minimal merge conflict, smallest batch size, highest deploy frequency.
- **Cost:** unforgiving without test coverage and flags — a broken `main` blocks everyone.

## GitHub Flow

The pragmatic middle ground and the right default for most deployed services.

```
main ──●─────●───────●──────●──▶   (deployable; deploy on merge)
        \     \       \
         feat  fix     feat        branch → PR → review → checks → merge → deploy
```

1. Branch off `main`.
2. Commit, open a PR (draft early for CI).
3. Review + required checks.
4. Merge to `main` → deploy.
5. Delete the branch.

- **No `develop` branch.** `main` is the single source of truth.
- Best for SaaS / web apps where "released" means "what's on `main`."
- Add **release branches** on top if you also need to support shipped versions.

## GitFlow

Heavyweight, version-oriented. Justified **only** when you support multiple released versions in the wild (libraries, desktop/mobile, on-prem).

```
main     ──●─────────────────●────────────●──▶   tagged releases only (v1.0, v1.1, v1.1.1)
            \               /  \          /
release      \         ●──●     \    ●──●         release/1.1  stabilization
              \       /          \  /
develop  ──●───●─●───●────●───●───●──●────●──▶    integration branch
              \                 /
hotfix         ●───────────────●                  hotfix/1.1.1 off main, merged back
```

| Branch | Cut from | Merges to | Purpose |
|---|---|---|---|
| `main` | — | — | Production; only release/hotfix merges land here; every merge is tagged |
| `develop` | `main` | — | Ongoing integration of features |
| `feature/*` | `develop` | `develop` | One feature |
| `release/x.y` | `develop` | `main` **and** `develop` | Stabilize a release; only bug fixes, no new features |
| `hotfix/x.y.z` | `main` | `main` **and** `develop` | Emergency production fix |

The dual-merge rule (release/hotfix → both `main` and `develop`) is what keeps fixes from being lost — and it's also why GitFlow is overkill for continuous deployment.

## Release Branches on Trunk (hybrid)

Keep trunk/GitHub Flow simplicity day-to-day; cut a stabilization branch only when shipping a version.

```
main ──●──●──●──●──●──●──●──▶
              \
release/2.4    ●──●──●            cut at feature-freeze; fixes cherry-picked from main
                     │
                     tag v2.4.0
```

- New work always targets `main`.
- Fixes for a release land on `main` first, then **cherry-pick** to `release/2.4`:
  ```bash
  git checkout release/2.4
  git cherry-pick <sha-from-main>
  git push origin release/2.4
  ```
- Avoids GitFlow's `develop` while still supporting versioned lines.

## Backporting

When a fix must reach an older supported version:

```bash
git checkout release/2.3
git cherry-pick -x <sha>     # -x records the original commit hash in the message
# resolve conflicts, then
git push origin release/2.3
git tag -a v2.3.5 -m "Release 2.3.5"
git push origin v2.3.5
```

Label PRs (`backport/2.3`) or use a backport bot to automate cherry-picks across maintained branches.

## Monorepo vs Polyrepo

| | Monorepo | Polyrepo |
|---|---|---|
| **Branching** | One model across all packages; path filters scope CI | Independent model per repo |
| **Versioning** | Often independent per-package (changesets) or single global version | Per-repo SemVer |
| **Tags** | Prefixed tags: `web-v1.2.0`, `api-v3.1.0` | Plain `v1.2.0` |
| **Trade-off** | Atomic cross-package changes, heavier CI/tooling | Simple isolation, harder cross-cutting changes |

## Choosing — Quick Heuristic

- Deploy many times a day, good tests, feature flags → **trunk-based**.
- Deploy on merge, single live version, small/mid team → **GitHub Flow**.
- Ship discrete versions you must patch after release → **GitHub Flow + release branches**.
- Multiple concurrently supported versions, scheduled releases, formal QA → **GitFlow** (accept the overhead).
