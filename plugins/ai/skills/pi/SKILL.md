---
name: pi
description: "pi (pi.dev) harness operations end-to-end — Earendil's minimal open-source coding agent: install/auth, the four modes (TUI, `-p`/`--mode json`, `--mode rpc`, embedded SDK), settings precedence and models.json, AGENTS.md/SYSTEM.md context, project trust, TypeScript extensions and packages, 15+ providers with mid-session switching, tree-structured sessions, compaction, and its deliberate exclusions (no MCP, sub-agents, plan mode, permission popups, to-dos, background bash) plus the extension-based alternatives. WHEN: \"pi\", \"pi.dev\", \"Earendil\", \"@earendil-works/pi-coding-agent\", \"pi --mode rpc\", \"pi --mode json\", \"~/.pi/agent\", \".pi/settings.json\", \"models.json\", \"AGENTS.override.md\", \"APPEND_SYSTEM.md\", \"pi.registerTool\", \"pi.registerProvider\", \"ExtensionAPI\", \"pi install npm:\", \"pi-package\", \"gondolin\", \"PI_CODING_AGENT_DIR\", \"keepRecentTokens\", \"thinkingLevelMap\", \"/tree\", \"/trust\". Do NOT use for: Claude Code (use `claude-code`); OpenAI Codex (use `codex`); GitHub Copilot (use `github-copilot`); Cursor (use `cursor`); building agents with the Claude Agent SDK, OpenAI Agents SDK, or Google ADK (use `claude-agent-sdk`, `openai-agents-sdk`, `google-adk`); comparing or choosing harnesses/SDKs/APIs (use `overview`); the MCP spec or writing MCP servers (use `mcp`); authoring SKILL.md content (use `agent-skills`); cross-vendor model choice (use `model-selection`); the Claude Messages API (use `claude-api`); isolation/egress architecture (use `sandboxing`); prompt injection and threat modeling (use `ai-security`); testing agents (use `evals`). Not Raspberry Pi hardware."
license: MIT
---

# pi (the harness)

Configure, extend, and operate `pi` — the minimal coding agent harness from Earendil (`@earendil-works/pi-coding-agent`). This skill covers install/auth, the four run modes, configuration precedence, context files, providers, TypeScript extensions, packages, sessions/compaction, and the security model.

Corpus fetched 2026-08-05 against `pi.dev/docs/latest` and the GitHub README. The docs are published under a `latest` path with **no per-release version pages** — there is no documented "this changed in pi X.Y" surface to check. The one versioned artifact is the session JSONL format (`"version": 3`), documented in `references/versions/session-format-v3.md`.

## The one thing to get right

pi is **minimal by design, and the design excludes several controls other harnesses treat as safety features**. It ships no sandbox, no permission prompts, no MCP client, and no sub-agents. Never describe pi to an enterprise reader as if those exist or as if an extension recreates them at equal strength. Read "Design exclusions" below before answering any question that assumes a Claude-Code-shaped or Copilot-shaped feature set.

## Answering rules

Always state which scope a change belongs in before editing config — global (`~/.pi/agent/settings.json`) or project (`.pi/settings.json`). Project wins, and objects **deep-merge** rather than replace, so a project file that sets one nested key inherits the rest from global.

Always check **project trust** first when project-local resources "aren't loading". `.pi/settings.json`, `.pi/extensions/`, `.pi/skills/`, `.pi/prompts/`, and `.pi/themes/` are only read for a trusted project. `/trust` saves the decision to `~/.pi/agent/trust.json`; `-a`/`--approve` and `-na`/`--no-approve` force it per invocation.

Never call project trust a security boundary. The docs are explicit: it prevents a repo from silently changing settings before you approve it, and "does not make untrusted code, untrusted prompts, or untrusted model output safe."

Never recommend running pi against untrusted code on a workstation. pi runs with the **same access level as the user who starts it** — anything that user can write is inside pi's trust boundary. Untrusted code goes in a container/VM (see "Containment"); architecture and egress control belong to the `sandboxing` sibling.

Always prefer an **extension** over a prose instruction when the user wants a guarantee (a confirmation prompt, a blocked command, a required check). The `tool_call` event can block a call before it executes; text in AGENTS.md cannot.

Always distinguish pi's own `SKILL.md` support (a real, documented feature) from MCP (absent). A user asking "how do I add tools to pi" usually needs `pi.registerTool()` or a CLI-tool-plus-README skill, not an MCP server.

## Install and authenticate

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent   # documented install
curl -fsSL https://pi.dev/install.sh | sh                          # alternative (README)
npm uninstall -g @earendil-works/pi-coding-agent                   # keeps ~/.pi/agent/
```

`--ignore-scripts` is the documented default install form — dependency lifecycle scripts are disabled for supply-chain safety. Keep it when scripting installs.

Auth, two paths:

- **Subscription login** — start `pi`, run `/login`, choose Claude Pro/Max, ChatGPT Plus/Pro, or GitHub Copilot. Credentials land in `~/.pi/agent/auth.json`.
- **API key env var** exported before launch, e.g. `ANTHROPIC_API_KEY`. `/login` can also store API-key credentials into the same `auth.json`.

Run `pi` from the project directory; `AGENTS.md` loads automatically with no flag.

## The four modes

| Mode | Invocation | Use for |
|---|---|---|
| Interactive TUI | `pi` | Normal development; slash commands, multi-line editing, file references, external editor |
| Print | `pi -p "…"` | One-shot answer to stdout, then exit |
| JSON stream | `pi --mode json "…"` | Scripting/CI — a session header line then a typed event stream |
| RPC | `pi --mode rpc` | Embedding pi behind another process over stdin/stdout JSONL |
| SDK | `import { createAgentSession } from "@earendil-works/pi-coding-agent"` | Embedding pi **in-process** in a TypeScript app |

JSON mode emits `{"type":"session","version":3,…}` first, then events: `agent_start`/`agent_end`, `turn_start`/`turn_end`, `message_start`/`message_update`/`message_end`, `tool_execution_start`/`_update`/`_end`, `queue_update`, `compaction_start`/`compaction_end`. **`message_update` is delta-only** — it omits the cumulative message and `assistantMessageEvent.partial` to keep stream size linear, so a consumer must accumulate deltas itself.

RPC mode is **strict JSONL with LF as the only record delimiter** (a trailing `\r` on input is stripped). Commands in on stdin, `{"type":"response",…}` plus async `{"type":"event_name",…}` out on stdout.

Read `references/modes-and-cli.md` for the complete CLI flag set, the RPC command/response shapes, and the SDK API surface.

## Configuration

Precedence: **project `.pi/settings.json` over global `~/.pi/agent/settings.json`**, deep-merged.

```json
{
  "defaultProvider": "anthropic",
  "defaultModel": "claude-sonnet-4-20250514",
  "defaultThinkingLevel": "medium",
  "theme": "dark",
  "compaction": { "enabled": true, "reserveTokens": 16384, "keepRecentTokens": 20000 },
  "retry": { "enabled": true, "maxRetries": 3, "baseDelayMs": 2000,
             "provider": { "timeoutMs": 3600000, "maxRetries": 0, "maxRetryDelayMs": 60000 } }
}
```

`/settings` edits common options interactively; anything else is a direct file edit.

Custom models live in a separate file, `~/.pi/agent/models.json`, keyed by provider with `baseUrl`, `api`, `apiKey`, `models`. Supported `api` values: `openai-completions` (most compatible), `openai-responses`, `anthropic-messages`, `google-generative-ai`. That is the hook for Ollama, LM Studio, vLLM, or any OpenAI-compatible endpoint.

Thinking levels are pi-wide: `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`. A model maps them via `thinkingLevelMap`; set a level to `null` to hide it in the UI when the model doesn't support it.

Environment variables split into three groups — injected into bash-tool commands (`PI_SESSION_ID`, `PI_SESSION_FILE`, `PI_PROVIDER`, `PI_MODEL`, `PI_REASONING_LEVEL`), read at startup (`PI_CODING_AGENT_DIR`, `PI_CODING_AGENT_SESSION_DIR`, `PI_PACKAGE_DIR`, `PI_OFFLINE`, `PI_SKIP_VERSION_CHECK`, `PI_TELEMETRY`, `PI_CACHE_RETENTION`, `PI_SHARE_VIEWER_URL`, `HTTP_PROXY`/`HTTPS_PROXY`, …), and the marker `PI_CODING_AGENT=true` that scripts can test to detect they are running under pi.

For locked-down or air-gapped installs, `PI_OFFLINE` disables startup network operations including update checks; `PI_SKIP_VERSION_CHECK` disables version-check requests alone.

Read `references/config-and-providers.md` for the full settings/env tables, the `models.json` structure, the provider list with per-provider API-key variables, and switching mechanics across TUI/CLI/RPC/SDK.

## Context files and the system prompt

`AGENTS.md` discovery order: `~/.pi/agent/AGENTS.md` (global) → parent directories walking up from cwd → current directory. `CLAUDE.md` is accepted in the same slots, so a repo written for another harness works unchanged.

`AGENTS.override.md` in a directory **replaces** the standard context file(s) from that same directory instead of appending — the tool for a subdirectory whose conventions contradict the repo root.

System prompt control:

| File / flag | Effect |
|---|---|
| `.pi/SYSTEM.md` (project) | **Replaces** the default system prompt |
| `~/.pi/agent/SYSTEM.md` (global) | Replaces, at global scope |
| `APPEND_SYSTEM.md` (either location) | Appends instead of replacing |
| `--system-prompt <text>` / `--append-system-prompt <text>` | Same two behaviors, one invocation |

Reach for `APPEND_SYSTEM.md` by default. A `SYSTEM.md` discards pi's default prompt wholesale, including whatever tool guidance it carries — only do that deliberately.

`--no-context-files` / `-nc` skips context files entirely for one run; useful when isolating whether AGENTS.md is causing a behavior.

## Providers and model switching

The providers doc enumerates 15+: Anthropic, OpenAI, Azure OpenAI, DeepSeek, NVIDIA NIM, Google Gemini, Amazon Bedrock, Mistral, Groq, Cerebras, Cloudflare (AI Gateway & Workers AI), xAI, OpenRouter, Hugging Face, Fireworks, Together AI, plus regional providers Qwen, Xiaomi, MiniMax, Kimi. The README's "40+" counts individual regional/local variants — cite the enumerated list, not the marketing number, when a user needs to know whether a specific provider is supported.

Switch mid-session with `/model`; authenticate another provider with `/login <provider>`; clear with `/logout`. Non-interactively: `--provider`, `--model` (pattern `provider/id:thinking`), `--thinking`, and `--models` for the Ctrl+P cycling set. RPC uses `{"type":"set_model","provider":…,"modelId":…}`; the SDK uses `session.setModel()` / `session.cycleModel()`.

Providers needing custom API shapes or OAuth register programmatically via `pi.registerProvider()` in an extension. Per the docs, `models.json` overrides compose **above** registered native providers.

For choosing *which* model to run, defer to the `model-selection` sibling — this skill covers the wiring, not the catalog.

## Extensions — the substitute for everything pi omits

Extensions are TypeScript modules auto-discovered from `~/.pi/agent/extensions/*.ts` (or `*/index.ts`) globally and `.pi/extensions/` project-locally (**trust required**), plus any paths in the `extensions` settings array. `-e/--extension <source>` loads one per invocation; `--no-extensions` disables the lot.

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    // fires before execution — this handler can block the call
  });
}
```

Event families: lifecycle (`project_trust`, `session_start`, `session_shutdown`, `resources_discover`, `session_info_changed`), agent (`before_agent_start`, `agent_start`/`agent_end`/`agent_settled`, `turn_*`, `message_*`), tool (`tool_call` — blocking, `tool_result` — can modify, `tool_execution_*`), input/model (`input`, `model_select`, `thinking_level_select`).

Registration API highlights: `pi.registerTool()`, `pi.registerCommand()`, `pi.registerShortcut()`, `pi.registerFlag()`, `pi.registerProvider()`, `pi.setActiveTools()`, `pi.sendMessage()`, `pi.appendEntry()`, `pi.exec()`.

Two patterns worth naming because they carry safety weight:

- **Approval gate** — `tool_call` blocking plus `ctx.ui.confirm` is the documented way to get a confirmation flow, since pi has none built in.
- **Branch-safe state** — store data in a tool result's `details` field so tree navigation and forking can reconstruct state; extension state that must not reach the LLM goes through `pi.appendEntry()` (a `CustomEntry`).

Read `references/extensions.md` before writing one — it carries the full event list, the `registerTool` definition shape, `ExtensionContext`/`ExtensionCommandContext` members, the TUI component contract, and the recommended patterns.

## Skills, prompt templates, themes, packages

pi loads **Agent Skills** — a directory with `SKILL.md` (frontmatter `name`, `description` required; `license`, `compatibility`, `metadata`, `allowed-tools`, `disable-model-invocation` optional), "everything else is freeform". Discovery: npm packages, git repos, `.pi/skills/` or `.agents/skills/` (project), `~/.pi/agent/skills/` or `~/.agents/skills/` (global), `--skill <path>` per run. For *writing* good skill content, use the `agent-skills` sibling.

Prompt templates are `*.md` in `~/.pi/agent/prompts/` or `.pi/prompts/`; filename becomes the command (`review.md` → `/review`), with `$1`/`$@`/`$ARGUMENTS`/`${1:-default}`/`${@:N:L}` expansion and an optional `argument-hint`. Discovery is **non-recursive** — subdirectory templates need explicit settings or package-manifest entries.

Themes are JSON in `themes/` dirs; `name` is required, unique, no slashes; `colors` must supply **51 required tokens** (plus optional `thinkingMax`, `scrollbarThumb`).

All four resource kinds ship as a **package**:

```bash
pi install npm:@scope/pkg@1.2.3     # versioned specs are pinned, skip auto-updates
pi install git:github.com/user/repo@v1
pi install ./relative/path
```

```json
{ "name": "my-package", "keywords": ["pi-package"],
  "pi": { "extensions": ["./extensions"], "skills": ["./skills"],
          "prompts": ["./prompts"], "themes": ["./themes"] } }
```

Omit the `pi` key and conventional directories are auto-discovered. In `settings.json`, a `packages` entry may be a bare source string or an object with per-category glob filters (`!pattern` excludes, `+`/`-` force, `[]` drops the whole category). Same package in global and project settings: **project wins, unless the project entry sets `"autoload": false`**, in which case global is used.

State the docs' own warning whenever you recommend a package: **"Packages execute with full system access; review source code before installing."** There is no sandboxing of package code.

Read `references/resources-and-packages.md` for the full frontmatter/discovery/filtering detail.

## Sessions, tree navigation, compaction

Sessions are one JSONL file per session under `~/.pi/agent/sessions/--<path>--/<timestamp>_<uuid>.jsonl`, structured as a **tree**: every entry has `id` and `parentId`, and the current position is the active leaf. Multiple branches live in one file.

- `/tree` — navigate history; selecting a **user** message moves the leaf to that message's parent and loads its text into the editor for editing/resubmission, while selecting a non-user entry moves the leaf there with an empty editor.
- `/fork` (or `--fork`) — new session file from an earlier user message; `/clone` — duplicate the active branch; `/resume` or `pi -r` — browse; `-c`/`--continue` — most recent; `--session <path|id>`; `--no-session` for ephemeral runs (and note `PI_SESSION_FILE` is then unset).
- `/export [file]` — HTML or JSONL. `/share` — uploads as a **private GitHub gist** with a shareable HTML link. Treat `/share` as an exfiltration path: a session transcript can contain source, secrets echoed by tools, and internal URLs. Confirm before suggesting it; `PI_SHARE_VIEWER_URL` only changes the viewer base URL, not where the gist goes.

Auto-compaction triggers when `contextTokens > contextWindow - reserveTokens` (defaults: `reserveTokens` 16384, `keepRecentTokens` 20000). It walks backward to the `keepRecentTokens` threshold, picks a cut point that must land on a user/assistant boundary (**never mid-tool-result**), summarizes from the previous compaction boundary to the cut, appends a `CompactionEntry`, and reloads with summary + kept messages. On repeated compactions the summarized span starts at the previous compaction's `firstKeptEntryId`, not at the compaction entry, so content survives multiple cycles.

`"compaction": {"enabled": false}` keeps manual `/compact [instructions]` while disabling the automatic pass.

Read `references/sessions-and-compaction.md` for the entry-type catalog and `references/versions/session-format-v3.md` when parsing `.jsonl` files programmatically.

## Design exclusions — answer these honestly

Per the GitHub README, pi favors aggressive extensibility over baked-in features so the harness doesn't dictate a workflow. Six exclusions are documented, each with an alternative:

| Excluded | Documented alternative | What to tell the reader |
|---|---|---|
| **MCP** | Build CLI tools with READMEs (as skills), or an extension that adds MCP support | No MCP client ships; an extension is third-party code you own and maintain. Protocol questions → `mcp` |
| **Sub-agents** | Separate pi instances under tmux, an extension, or a community package | No isolation between "agents" — separate processes share the same user account |
| **Plan mode** | Write plans to a file (PLAN.md), extension, or community package | There is no read-only mode enforced by the harness |
| **Permission popups** | Run in containers, or build a confirmation flow via an extension | The critical one — see below |
| **Built-in to-dos** | `TODO.md`, or an extension | Deliberate: avoids confusing the model with a redundant mechanism |
| **Background bash** | Use tmux for full observability of long-running processes | pi will not manage detached shells for you |

On permissions, quote the rationale rather than paraphrasing it: pi assumes the OS already governs file/process access through normal user permissions, and dialogs "would create a false sense of security without actual isolation." Similarly on sandboxing: "A partial in-process sandbox would be easy to misunderstand as a security boundary while still depending on the host shell, filesystem, package managers, credentials, and extension code."

That reasoning is coherent, and it also means **the containment decision is entirely the operator's**. An enterprise evaluating pi must supply isolation externally; there is no managed-policy file, no deny-list, and no admin-enforced setting documented anywhere in the corpus. Say that plainly rather than implying a config key exists.

## Containment

Three documented patterns, summarized here — isolation architecture, egress policy, and multi-tenant design belong to the `sandboxing` sibling:

- **Gondolin** (micro-VM extension shipped in `examples/extensions/`): mounts host cwd at `/workspace` and **overrides `read`, `write`, `edit`, `bash`, `grep`, `find`, `ls`**. Needs Node.js ≥ 23.6.0 and QEMU.
- **Plain Docker**: `node:24-bookworm-slim` + global pi install, bind-mount the project at `/workspace` and a named volume at `/root/.pi/agent`. Full Dockerfile in `references/security-and-exclusions.md`.
- **OpenShell**: policy-controlled sandbox via `openshell gateway add/select` and `openshell sandbox create --from pi -- pi`.

Tool-surface reduction is a real, cheap control even without a container: `--tools`/`-t` allowlists, `--exclude-tools`/`-xt` denies, `-nbt` drops built-ins, `-nt` drops all tools. Combine with `-na` on untrusted repos.

Threat modeling — prompt injection through repo content, tool output, or a package — is the `ai-security` sibling's job.

## Diagnosing "it isn't loading"

Work this order: is the project trusted (`~/.pi/agent/trust.json`, `/trust`, `-a`)? → is the resource in a discovered location or listed in settings? → is a `--no-*` flag suppressing it (`--no-extensions`, `--no-skills`, `--no-prompt-templates`, `--no-themes`, `-nc`)? → is a project setting deep-merging over the global one? → for templates, is it in a subdirectory (non-recursive discovery)?

`scripts/01-pi-inventory.sh` walks that checklist read-only.

## Documented gaps — do not fill these from memory

- No long-form design-philosophy page exists under `/docs/latest/`; the exclusion list comes from the GitHub README rendering.
- `models.json` has **no published field-by-field schema** (required vs optional, validation rules). The docs favor `pi.registerProvider()`. Say so instead of inventing fields.
- No dedicated non-JSON "print mode" page — treat `-p` as "print final response and exit".
- `/share` gist retention, expiry, and visibility options beyond "private" are undocumented.
- Platform-setup pages (Windows, Termux, tmux, shell aliases), `keybindings.json`, and the development guide were not fetched — treat as unverified here.

## Reference files

- `references/modes-and-cli.md` — full CLI flag reference, JSON event stream, RPC protocol, SDK API
- `references/config-and-providers.md` — settings precedence, `models.json`, env vars, provider list and keys
- `references/extensions.md` — extension events, API, tool definition, TUI components, packaging
- `references/resources-and-packages.md` — skills, prompt templates, themes, package manifest and install
- `references/sessions-and-compaction.md` — session tree, commands, sharing, compaction algorithm
- `references/security-and-exclusions.md` — permission model, containment patterns, exclusions and alternatives
- `references/versions/session-format-v3.md` — the `"version": 3` session JSONL entry schema

## Diagnostic script

- `scripts/01-pi-inventory.sh` — read-only inventory of pi config paths, discovered resources, trust state, session counts, and which provider API-key variables are set (names only, never values).

## Sources

- https://pi.dev
- https://pi.dev/docs/latest/quickstart
- https://pi.dev/docs/latest/usage
- https://pi.dev/docs/latest/json
- https://pi.dev/docs/latest/rpc
- https://pi.dev/docs/latest/sdk
- https://pi.dev/docs/latest/settings
- https://pi.dev/docs/latest/environment-variables
- https://pi.dev/docs/latest/models
- https://pi.dev/docs/latest/custom-provider
- https://pi.dev/docs/latest/providers
- https://pi.dev/docs/latest/extensions
- https://pi.dev/docs/latest/tui
- https://pi.dev/docs/latest/skills
- https://pi.dev/docs/latest/prompt-templates
- https://pi.dev/docs/latest/themes
- https://pi.dev/docs/latest/packages
- https://pi.dev/docs/latest/sessions
- https://pi.dev/docs/latest/session-format
- https://pi.dev/docs/latest/compaction
- https://pi.dev/docs/latest/security
- https://pi.dev/docs/latest/containerization
- https://github.com/earendil-works/pi/tree/main/packages/coding-agent

Fetched: 2026-08-05
