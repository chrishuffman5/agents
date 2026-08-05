# Codex cloud, environments, and git worktrees

Read when delegating work to Codex cloud, configuring a cloud environment's dependencies or secrets, deciding on agent internet access, or running parallel chats over one repo. All facts as of 2026-08-05.

## Task delegation

> Source: https://learn.chatgpt.com/docs/cloud

Codex cloud runs coding tasks in parallel, isolated cloud environments so work continues unattended. The workflow:

1. **Task creation** — describe the desired result inside a chosen environment.
2. **Parallel execution** — give longer tasks dedicated environments; concurrent tasks do not interfere.
3. **Monitoring** — watch logs live, or let the task run fully in the background.
4. **Review & action** — inspect the summary and diff, request a follow-up, or open a pull request.

Delegation entry points: the ChatGPT web and desktop apps, the CLI (`codex cloud-tasks`), a **GitHub pull request**, a **Linear issue**, or a **Slack channel**.

The Linear and Slack integration pages were **not fetched into this corpus**. Their setup, permissions, and behavior are unverified here — send the user to the live `/codex/third-party/linear` and `/codex/third-party/slack` docs rather than describing them.

Best-fit cases named by the docs: background work that needs no live human loop, comparing multiple parallel attempts at one task, kicking off work from whatever platform you are already in, and using a remote machine for tasks too heavy for a laptop.

## Environment configuration

> Source: https://learn.chatgpt.com/docs/environments/cloud-environment

An environment controls what Codex installs and runs during a cloud chat: dependencies, tools (linters, formatters), and the environment variables the repository needs.

**Setup phase**

- **Setup script** — custom Bash commands run when the container is created. Runs **with internet access**, so dependency installation works even when the agent phase is offline.
- **Maintenance script** — optional; runs when a *cached* container is resumed, not on a fresh one.

**Runtime configuration**

| Item | Visibility |
|---|---|
| **Environment variables** | Available for the full chat — setup **and** agent phase |
| **Secrets** | Encrypted; available **only during the setup script**, stripped before the agent phase begins |

That distinction is the single most important thing to get right: anything the agent must never see — deploy keys, production credentials, signing secrets — goes in **Secrets**, consumed by the setup script. Anything in Environment variables is readable by the agent and therefore exfiltratable if internet access is on.

**Container image** — defaults to the `universal` image with pre-installed languages and tools; the reference Dockerfile is published at `github.com/openai/codex-universal`. Python, Node.js, and other runtime versions are pinnable per environment.

**Caching**

- Cached containers persist **up to 12 hours**.
- The cache invalidates automatically when the setup script, maintenance script, environment variables, or secrets change.
- Manual reset is available from the environment settings page.
- **Business/Enterprise workspaces share caches workspace-wide** — factor this in when one team's cached container state could reach another team's run.

## Agent internet access

> Source: https://learn.chatgpt.com/docs/cloud/internet-access

Default: Codex **blocks all internet access during the agent phase**. Setup scripts still have internet so dependencies install. Enable agent internet explicitly, per environment, only when the agent itself needs it.

Three layers of control:

1. **Toggle** — `Off` (blocks everything) or `On` (allows access under the restrictions below).
2. **Domain allowlist**
   - `None` — empty; every domain must be added manually.
   - `Common dependencies` — a preset of **89 domains** spanning package managers (npm, PyPI, Maven), version-control hosts (GitHub, GitLab), container registries (Docker, GHCR), and language-specific repos (Rust, Go, Ruby). The verbatim domain list is not published on the fetched page.
   - `All (unrestricted)` — permits every domain.
3. **HTTP method restrictions** — optionally limit outbound requests to `GET`, `HEAD`, and `OPTIONS`, blocking `POST`/`PUT`/`PATCH`/`DELETE` and other mutating verbs.

Risks the docs call out explicitly: prompt injection from untrusted web content, exfiltration of code or secrets, downloading malware or vulnerable dependencies, and license violations. Their worked example: an agent following hidden instructions embedded in a web page or GitHub issue could leak sensitive commit messages if internet access and method restrictions are too permissive.

Recommended path, from the docs: **start at `Common dependencies`, then iteratively restrict to only the domains the workflow actually needs.** Add the method restriction whenever the agent only needs to *fetch* — read-only verbs make the exfiltration path much narrower even if injection succeeds.

For egress-proxy architecture and allowlist design beyond these toggles, use the `sandboxing` sibling skill.

## Git worktrees

> Source: https://learn.chatgpt.com/docs/environments/git-worktrees

**ChatGPT desktop app only**, and the project must be a Git repository.

Worktrees let multiple Codex chats run in parallel on the *same* repo without interfering — each chat gets an independent working directory sharing the same `.git` metadata and history (standard `git worktree` mechanics). Uses: parallel chats on one project, scheduled background tasks on dedicated worktrees, and moving work between Local and Worktree via Handoff.

**Setup**: select "Worktree" in the new-chat composer → optionally configure a local environment for setup scripts → choose the starting branch → submit. Codex creates the worktree automatically.

**Configuration**

- Worktree root: Settings > Worktrees; default `$CODEX_HOME/worktrees`.
- `.worktreeinclude` copies git-ignored files (e.g. `.env`) into new worktrees — without it, a fresh worktree lacks the local config the project needs to run.
- **Codex-managed worktrees**: lightweight, disposable, tied to one chat.
- **Permanent worktrees**: long-lived, support multiple chats.

**Handoff** transfers a chat plus its code changes between Local and Worktree, performing the Git safety operations required because Git disallows checking out the same branch in two worktrees at once. Two typical flows: (a) stay on the worktree — verify, branch, commit, push, open a PR; (b) hand off to Local to inspect in your IDE, run dev servers, or validate in an established environment.

Key terms: **Local checkout** (your primary repo), **Worktree** (created from Local), **Detached HEAD** (the default worktree state, which avoids branch pollution across worktrees), **Handoff**.

**Limits**: ~15 Codex-managed worktrees retained by default, oldest auto-removed past the limit. Worktrees with pinned chats, active work, or permanent status are protected. Deleting one triggers a snapshot save so it can be restored from chat history.

## Sources

- https://learn.chatgpt.com/docs/cloud
- https://learn.chatgpt.com/docs/environments/cloud-environment
- https://learn.chatgpt.com/docs/cloud/internet-access
- https://learn.chatgpt.com/docs/environments/git-worktrees

Fetched: 2026-08-05
