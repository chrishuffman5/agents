# `codex exec`, headless runs, and CI

Read when scripting Codex, wiring it into a pipeline, parsing its output, or handling credentials in automation. All facts as of 2026-08-05.

## Invocation forms

> Source: https://learn.chatgpt.com/docs/non-interactive-mode

```bash
codex exec "task prompt"
codex exec --json "task prompt"
codex exec --ephemeral "task prompt"
codex exec --sandbox workspace-write "task prompt"
codex exec --output-schema ./schema.json -o ./output.json "task prompt"
```

`codex e` is the alias. Image attachments are supported with `-i`.

Stdin patterns:

```bash
# Instruction first, piped data as context
npm test 2>&1 | codex exec "summarize failures and propose fix"

# Stdin is the entire prompt
cat prompt.txt | codex exec -
```

The first form is the one that matters in CI: pipe the failing tool's output in and let the instruction stay in the workflow file, rather than templating a giant prompt.

## Flags

> Source: https://learn.chatgpt.com/docs/non-interactive-mode

| Flag | Effect |
|---|---|
| `--json` | JSONL event stream to stdout instead of formatted text |
| `--ephemeral` | Skip persisting session files to disk |
| `--sandbox <mode>` | `read-only` \| `workspace-write` \| `danger-full-access` |
| `--ignore-user-config` | Skip `$CODEX_HOME/config.toml` (auth settings preserved) |
| `--ignore-rules` | Skip user/project execpolicy `.rules` files |
| `--output-schema <path>` | Constrain the final response to a JSON schema |
| `-o` / `--output-last-message <path>` | Write the final message to a file |
| `--skip-git-repo-check` | Run outside a Git repository |
| `-m` / `--model <id>` | Override the model for this run |
| `--strict-config` | Unrecognized config keys become errors |

For reproducibility, combine `--ignore-user-config --ignore-rules --sandbox <mode>` and pass the model explicitly. Without those, a developer's personal `~/.codex/config.toml` silently changes what CI does — the most common source of "it works on my machine, differently".

`--ephemeral` is right for shared runners: session files on a persistent runner are a data-retention surface nobody audits.

## JSONL event stream

> Source: https://learn.chatgpt.com/docs/non-interactive-mode

With `--json`, each line is a single event object. Observed types:

```json
{"type":"thread.started","thread_id":"0199a213-81c0-7800-8aa1-bbab2a035a53"}
{"type":"item.completed","item":{"type":"agent_message","text":"..."}}
```

| Event | Carries |
|---|---|
| `thread.started` | `thread_id` — log this for correlating a CI run back to a Codex session |
| `turn.started` / `turn.completed` | Token usage on completion: `input_tokens`, `cached_input_tokens`, `output_tokens` |
| `item.*` | Commands, file changes, MCP calls, messages |

Parse `turn.completed` for cost telemetry; `cached_input_tokens` versus `input_tokens` is the cache-hit signal worth graphing when a pipeline's cost rises.

## Exit codes — undocumented

> Source: https://learn.chatgpt.com/docs/non-interactive-mode

The fetched documentation does **not** enumerate `codex exec` exit-code semantics. Do not tell a user that a specific non-zero code means a specific failure.

Branch on evidence you can actually read: the `--json` event stream, or the file written by `--output-last-message` / `--output-schema`. Where an exit code must gate a step, verify the actual behavior in the user's own CLI version first and treat it as locally observed, not documented.

## Authentication in automation

> Source: https://learn.chatgpt.com/docs/non-interactive-mode

Set `CODEX_API_KEY` **inline for a single invocation only**. Never export it as a persistent environment variable in a job that runs untrusted code — every build script, test, and transitive dependency in that job inherits it.

```bash
CODEX_API_KEY="$KEY" codex exec --sandbox read-only "review the diff"
```

Note the API-key path's product limitation (see `models-and-pricing.md`): it bills per token and does **not** include cloud features such as GitHub reviews and Slack integration.

Pair automation credentials with `[shell_environment_policy.filters]` exclusions in `config.toml` so the agent's own subprocesses cannot read unrelated cloud credentials — see `config-reference.md`.

## GitHub Actions

> Source: https://learn.chatgpt.com/docs/non-interactive-mode

`openai/codex-action@v1` is the preferred path for GitHub workflows specifically because it avoids exposing credentials to build scripts. It:

- installs the Codex CLI,
- starts the Responses API proxy when given an API key,
- runs `codex exec` under specified permissions.

Prefer it over a hand-rolled `npm install -g @openai/codex` step whenever the workflow needs a credential at all.

For PR-comment-driven reviews (`@codex review`) and automatic PR reviews, that is a Codex cloud + GitHub App integration, not this Action — see `ide-and-review.md` and `cloud-and-environments.md`.

## MCP servers in CI

> Source: https://learn.chatgpt.com/docs/extend/mcp?surface=cli

Set `required = true` on any `[mcp_servers.*]` entry a pipeline depends on. Otherwise a server that fails to initialize is skipped and `codex exec` continues, producing a confident answer built without the data it was supposed to use.

## Sources

- https://learn.chatgpt.com/docs/non-interactive-mode
- https://learn.chatgpt.com/docs/developer-commands?surface=cli
- https://learn.chatgpt.com/docs/extend/mcp?surface=cli
- https://learn.chatgpt.com/docs/config-file/config-basic
- https://learn.chatgpt.com/docs/pricing

Fetched: 2026-08-05
