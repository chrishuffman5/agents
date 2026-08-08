# Choosing the implementation layer

Read this when the question is "should we build on the CLI, an SDK, or the raw API?" — including cross-vendor comparisons.

## Anthropic's four-way product split

> Source: https://code.claude.com/docs/en/agent-sdk/overview

Working definition used by Anthropic: "An agent is an application that completes a task by planning its own steps and calling tools that read files, run commands, or edit code."

| If you're… | Use | Why |
|---|---|---|
| Building an agent without implementing the tool loop yourself | **Agent SDK** | A library that runs the agent loop in your own process (Python/TypeScript) |
| Doing interactive development or one-off terminal tasks | **Claude Code CLI** | The terminal interface, built for daily interactive use |
| Calling the API directly and implementing the tool loop yourself | **Client SDK** | Direct Anthropic API access; you implement the tool loop |
| Running long-running/async agents without managing your own sandbox/session infra | **Managed Agents** | Hosted REST API — Anthropic runs the agent and the sandbox |

The **Claude Agent SDK** (renamed from "Claude Code SDK") is explicitly "Claude Code as a library": the same agent loop, tool set, and context management that power the harness, embedded in your own process. It is available in **Python and TypeScript only** — to drive the same loop from another language, run the CLI as a subprocess with `-p --output-format json`.

Everything that makes the harness powerful is exposed through the SDK:

| Capability | What it does |
|---|---|
| Built-in tools | Read/write/edit files, run commands, search the web |
| Hooks | Run custom code at agent-lifecycle key points |
| Subagents | Spawn specialized agents for focused subtasks |
| MCP | Connect external tools/data via Model Context Protocol |
| Permissions | Control which tools auto-run vs. need approval |
| Sessions | Maintain context across exchanges; resume or fork later |
| Skills, commands, memory | Load automatically from `.claude/` and `~/.claude/`, same as Claude Code |
| Plugins | Package skills/agents/hooks/MCP servers, load by local path |

**Licensing and branding constraints** for products built on the SDK: use is governed by Anthropic's Commercial Terms of Service. "Claude Code" or "Claude Code Agent" branding is **not permitted** on a third-party product; "Claude Agent" or "{YourAgentName} Powered by Claude" is allowed. Unless previously approved, third-party developers may **not** offer claude.ai login or its rate limits inside a product built on the Agent SDK — API-key auth is required.

## OpenAI's two-way split

> Source: https://developers.openai.com/api/docs/guides/agents

| Aspect | Responses API | Agents SDK |
|---|---|---|
| Control | You manage the loop and branching yourself | SDK manages the agent-loop lifecycle |
| Complexity | Single or fully custom workflows | Bounded conversational/transactional workflows |
| Orchestration | Manual routing | Built-in handoffs and delegation |
| Best for | Custom, model-powered features you fully control | Defined tools with recurring interaction patterns |

An **agent**, per this guide, is an application that "plans, calls tools, collaborates across specialists, and keeps enough state to complete multi-step work."

The five composable primitives underneath both options — useful as a checklist when auditing any agent design, regardless of vendor:

1. **Models & Providers**
2. **Tools** — platform tools, function calling, local MCP connections, agent-as-tool nesting
3. **Knowledge / Memory & State** — SDK sessions, resumable run state
4. **Guardrails** — input, output, and tool guardrails plus resumable human-approval flows for risky operations
5. **Orchestration** — handoffs or agents-as-tools

Codex is OpenAI's coding-agent product line built on this stack, available across CLI, IDE extension, web/cloud, and desktop, all sharing one underlying agent loop.

## Synthesis: the three-tier shape

> Source: https://code.claude.com/docs/en/agent-sdk/overview
> Source: https://developers.openai.com/api/docs/guides/agents

Both vendors converge on the same three tiers, plus Anthropic's hosted fourth:

1. **Interactive harness / CLI** (Claude Code, Codex CLI) — a human driving day-to-day work from a terminal/IDE; opinionated batteries-included agent loop, filesystem-based config (memory, skills/subagents, hooks, MCP), no code to write.
2. **Agent SDK** (Claude Agent SDK, OpenAI Agents SDK) — the same agent-loop machinery inside your own application/service, for headless, at-scale, or embedded use; Python/TypeScript.
3. **Raw model API** (Anthropic Client SDK / Messages API, OpenAI Responses API used directly) — full manual control of every model call and tool-execution step, for interactions that don't fit the SDK's agent-loop assumptions.
4. **Managed Agents** (Anthropic) — Agent SDK capabilities without operating your own sandbox/session infrastructure; Anthropic hosts the agent and the sandbox behind a REST API.

## Executing local commands from the raw API layer

> Source: https://developers.openai.com/api/docs/guides/tools-local-shell

If you build at the raw-API layer and need local execution, you own the request/execute/return loop: the model emits a `local_shell_call` action (`command`, `working_directory`, `env`, `timeout_ms`, `call_id`), your code executes it locally, and you return `local_shell_call_output` — repeating until the model stops requesting actions. This tool is documented as available only through the Responses API (not Chat Completions), historically paired with `codex-mini-latest`; OpenAI's docs mark it superseded by a newer `shell` tool paired with GPT-5.1 for new implementations.

The docs warn explicitly that "running arbitrary shell commands can be dangerous" and that production use requires sandboxing, resource limits, command filtering, and logging before deployment. This is precisely the work a harness does for you, and the strongest practical argument for not dropping to the raw API without cause.

## Sources

- https://code.claude.com/docs/en/agent-sdk/overview
- https://developers.openai.com/api/docs/guides/agents
- https://developers.openai.com/api/docs/guides/tools-local-shell

Fetched: 2026-08-05
