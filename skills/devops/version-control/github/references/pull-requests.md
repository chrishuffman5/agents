# Pull Requests, Review & Branch Protection

## PR Workflow

```
draft ──▶ ready ──▶ review ⇄ changes requested ──▶ approved ──▶ checks green ──▶ merge ──▶ delete branch
```

- **Open early as draft** — gets CI running and gives visibility without pinging reviewers.
- **One concern per PR** — easier review, cleaner revert, clearer history.
- **Size:** aim < ~400 changed lines. Review quality and defect detection drop sharply on large PRs.
- **Description:** what changed + why, testing done, and `Closes #N` / `Fixes #N` to auto-close the issue on merge.

```bash
gh pr create --draft --base main --title "feat: add SAML SSO" --body "Closes #142"
gh pr ready                      # flip draft → ready
gh pr checks --watch             # follow required checks
gh pr review --approve
gh pr merge --squash --delete-branch --auto   # auto-merge once checks/approvals pass
```

## Review Etiquette

| Reviewer | Author |
|---|---|
| Review within ~1 business day to keep flow | Keep PRs small and self-explanatory |
| Distinguish blocking vs. nits (prefix `nit:`) | Respond to every thread; don't silently force-push over discussion |
| Approve when "good enough + correct," not "perfect" | Re-request review after substantive changes |
| Suggest with code suggestions where possible | Resolve threads you've addressed |

## CODEOWNERS

`.github/CODEOWNERS` (also valid in repo root or `docs/`). Auto-assigns reviewers; with "require code owner review" it becomes mandatory for matching paths. **Last matching pattern wins.**

```
# Default owner for everything
*                         @org/maintainers

# Path-scoped ownership
/services/payments/**     @org/payments-team
/infra/terraform/         @org/platform @alice
*.tf                      @org/cloud
/.github/                 @org/devops
/docs/                    @org/tech-writers

# A path with no owner (blank) — overrides a broader rule to require no specific owner
/sandbox/
```

Owners must have **write** access and be added as a team/user the repo can request.

## Branch Protection vs. Rulesets

GitHub has two mechanisms. **Prefer rulesets** for new setups — they're layerable, support multiple target branches by pattern, have explicit bypass lists, and can be evaluated in "evaluate" mode before enforcing.

| | Legacy Branch Protection | Rulesets |
|---|---|---|
| Scope | One rule per branch pattern | Multiple layered rulesets, org or repo level |
| Bypass | Implicit (admins) | Explicit, audited bypass actor list |
| Dry run | No | `enforcement: "evaluate"` |
| Tag protection | Separate feature | Same ruleset engine (`target: "tag"`) |

### Recommended rules for `main`

| Rule | Setting | Why |
|---|---|---|
| Require a pull request | ✓, ≥1 approval | No direct pushes |
| Dismiss stale approvals | ✓ | New commits invalidate prior approval |
| Require code owner review | ✓ | Domain experts gate their paths |
| Require conversation resolution | ✓ | No unresolved review threads merged |
| Require status checks | ✓ `build`, `test`, ... | CI must pass |
| Require branches up to date (strict) | ✓ | Test against latest `main` (use merge queue at scale) |
| Require linear history | ✓ | Clean, bisectable history (squash/rebase only) |
| Block force pushes | ✓ | History is immutable |
| Restrict deletions | ✓ | `main` can't be deleted |
| Require signed commits | optional | Provenance / compliance |

### Ruleset JSON (repo API)

```json
{
  "name": "protect-main",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    { "actor_type": "RepositoryRole", "actor_id": 5, "bypass_mode": "pull_request" }
  ],
  "conditions": { "ref_name": { "include": ["refs/heads/main"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    { "type": "required_signatures" },
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    },
    { "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "build" },
          { "context": "test" },
          { "context": "lint" }
        ]
      }
    }
  ]
}
```

```bash
gh api repos/:owner/:repo/rulesets --method POST --input ruleset.json
gh api repos/:owner/:repo/rulesets                 # list
```

Protect tags too, so release tags can't be deleted or moved:

```json
{ "name": "protect-release-tags", "target": "tag", "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" } ] }
```

## Merge Queue

At scale, "branch up to date (strict)" causes thrashing — each merge invalidates every other PR. A **merge queue** batches PRs, tests each against the projected result, and merges in order. Enable in the ruleset (`required_merge_queue`) and require it on `main`.

## Stacked PRs

For large work, stack dependent PRs so each stays small:

```
main ◀── PR1 (schema) ◀── PR2 (api) ◀── PR3 (ui)
```

Each PR targets the one below it; rebase the stack as lower PRs merge. Tools: `gh`, Graphite, `spr`. Keeps reviews tractable without one giant PR.

## Auto-Merge & Bots

- `gh pr merge --auto --squash` — merges automatically once required reviews + checks pass.
- **Dependabot / Renovate** — dependency PRs; combine with auto-merge for patch/minor after CI passes.
- Require the same status checks on bot PRs — don't exempt them.
