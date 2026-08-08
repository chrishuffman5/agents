# IDE surfaces, settings, models, and auto selection

Read when configuring Copilot inside an editor, when a chat/agent feature is missing in VS Code, or when choosing between Copilot's available models.

## VS Code chat surfaces

> Source: https://code.visualstudio.com/docs/copilot/chat/copilot-chat

| Surface | Purpose | Access |
|---|---|---|
| Agents Window | Agent-first orchestration across projects | "Open in Agents" in the title bar, or `code --agents` |
| Chat View | Code-focused sidebar assistance | Chat icon in the title bar, or `Ctrl+Alt+I` |
| Inline Chat | Quick in-place edits | `Ctrl+I` |
| Quick Chat | Lightweight top panel | `Ctrl+Shift+Alt+L` |

Additional shortcuts: `Ctrl+Alt+Up` / `Ctrl+Alt+Down` (previous/next prompt), `Ctrl+Alt+PageUp` / `Ctrl+Alt+PageDown` (previous/next code block).

**Context**: implicit context (VS Code auto-includes the active file, the selection, and the filename); `#`-mentions for `#file`, folders, `#codebase`, `#terminalSelection`, `#fetch`; image/vision attachments such as screenshots and mockups; HTML/CSS pulled from the integrated browser.

**Other behaviors**: `/` for slash commands and agent skills; `!` prefix to run shell commands directly in chat (**Agent Host sessions only**); message queuing, steering, and stop-and-send while a request is processing; `chat.notifyWindowOnResponseReceived` for OS notifications; `chat.verbose` to show timestamps.

> Gap: the classic **Ask / Edit / Agent** three-mode comparison with switching keybindings was not present on the fetched `chat-modes` page as of 2026-08-05 — that page now documents custom agents and handoffs. The four surfaces above are what current docs describe. Do not present an Ask/Edit/Agent table as current.

## Agent mode

> Source: https://code.visualstudio.com/docs/copilot/chat/chat-agent-mode

Agent mode lets AI agents in VS Code analyze code, make modifications, and summarize their actions inside chat sessions. Agents use the same `#`-mentions (file/symbol references, `#codebase`, `#terminalSelection`, `#fetch`), browser elements, and image/video attachments.

MCP servers or extensions can be connected to "give the agent access to external services, databases, or APIs." An **Approvals & Permissions** mechanism governs tool execution; the fetched page does not enumerate it — deeper detail lives in VS Code's "Build with Agents" / "Agent Host Architecture" docs, which were not fetched.

## Custom agents and handoffs

> Source: https://code.visualstudio.com/docs/copilot/chat/chat-modes

Custom agents (formerly "chat modes") adopt personas tailored to roles — security reviewer, planner, solution architect — each with its own behavior, available tools, and instructions.

- **Handoffs**: guided workflows transitioning between agents, e.g. a planning agent directly into an implementation agent, or into a code-review agent with relevant context carried over.
- **Files**: `.agent.md` at workspace level (`.github/agents`) or user-profile level (`~/.copilot/agents`). Field reference in `customization-files.md`.
- **Tool control**: restrict tools per agent — a planning agent given only read-only tools cannot make accidental changes.

## VS Code `settings.json` keys

> Source: https://code.visualstudio.com/docs/copilot/reference/copilot-settings

**Chat and agent core**

| Key | Default | Effect |
|---|---|---|
| `chat.agent.enabled` | `true` | Enable/disable agents (VS Code 1.99+) |
| `chat.disableAIFeatures` | — | Disable and hide built-in AI features (chat, inline suggestions) |
| `github.copilot.chat.localeOverride` | `"auto"` | Response language, e.g. `"en"`, `"fr"` |

**Model selection**

| Key | Default | Effect |
|---|---|---|
| `chat.utilityModel` | `"Default"` | Model for utility flows (titles, summaries) |
| `chat.utilitySmallModel` | `"Default"` | Model for fast tasks (commit messages, renames) |
| `inlineChat.defaultModel` | — | Default model for editor inline chat |

**Custom instructions and prompts**

| Key | Default | Effect |
|---|---|---|
| `chat.instructionsFilesLocations` | includes `.github/instructions` and `~/.claude/rules` | Directories searched for instruction files |
| `chat.promptFilesLocations` | `{ ".github/prompts": true }` | Locations for reusable prompt files |
| `chat.useAgentsMdFile` | `true` | Enable `AGENTS.md` as chat context |
| `chat.useClaudeMdFile` | `true` | Enable `CLAUDE.md` as custom instructions |

**MCP**

| Key | Default | Effect |
|---|---|---|
| `chat.mcp.access` | — | Manage which MCP servers may be used in VS Code |
| `chat.mcp.discovery.enabled` | `false` | Auto-discover MCP configs |
| `chat.mcp.autoStart` | `"newAndOutdated"` | Auto-start MCP servers on config changes |

**Agent customization**

| Key | Default | Effect |
|---|---|---|
| `chat.agentFilesLocations` | `{ ".github/agents": true }` | Where custom agents are found |
| `chat.agentSkillsLocations` | — | Search locations for agent skills across multiple directories |

Debug order for "my instructions/agent/prompt file isn't picked up": confirm the file is under a directory listed in the corresponding `*Locations` setting, then confirm the frontmatter is valid (`applyTo` for instruction files, `description` for agents), then check whether an org/enterprise policy disabled the feature.

## Cross-IDE feature availability

> Source: https://docs.github.com/en/copilot/reference/copilot-feature-matrix

GitHub's reference feature matrix is organized by **IDE platform** (VS Code, Visual Studio, JetBrains, Eclipse, Xcode, NeoVim) and IDE version history — **not** by subscription plan. GitHub recommends running the latest stable IDE and Copilot extension versions.

When a user asks "is feature X available in my IDE," the answer is a two-step lookup: the feature matrix for IDE support, and the plans page (see `admin-and-governance.md`) for plan gating. Neither page alone answers it.

> Gap: JetBrains-specific chat/edit/completion feature detail beyond cloud-agent integration was not fetched (jetbrains.com is outside the allowed source domains and no dedicated docs.github.com JetBrains features page was located). JetBrains cloud-agent behavior is documented in `cloud-agent.md`.

## Supported models

> Source: https://docs.github.com/en/copilot/reference/ai-models/supported-models

Catalog as of 2026-08-05, by provider:

- **OpenAI** — GPT-5 mini, GPT-5.3-Codex, GPT-5.4, GPT-5.4 mini, GPT-5.4 nano, GPT-5.5, GPT-5.6 Luna/Sol/Terra
- **Anthropic** — Claude Fable 5, Claude Haiku 4.5, Claude Opus 4.5–4.8, Claude Opus 5, Claude Sonnet 4.5–5
- **Google** — Gemini 3.1 Pro (preview), Gemini 3.5–3.6 Flash
- **Microsoft** — MAI-Code-1-Flash
- **Other** — Raptor mini (fine-tuned GPT-5 mini), Kimi K2.7 Code (Moonshot AI), Grok 4.5 (xAI)

Extended capabilities: select models support a **1 million token context window** — "available in Visual Studio Code and Copilot CLI only" — and **configurable reasoning levels**, which work across VS Code, the CLI, and the cloud agent.

Product availability: Copilot Chat supports most models (exceptions include GPT-5 mini and Raptor mini). Copilot CLI has broad support with some gaps (Raptor mini excluded). GitHub.com and IDE availability varies by model and plan tier. All default models pass through GitHub Copilot's content filters for harmful, offensive, or off-topic content.

Model IDs and pricing outside Copilot's catalog, and cross-vendor tier choice, belong to the `model-selection` sibling skill.

## Auto model selection

> Source: https://docs.github.com/en/copilot/concepts/models/auto-model-selection

Two systems combine: one monitors real-time system health and availability, one evaluates task complexity. Together they "route the task to the optimal model," making routing decisions "along natural cache boundaries to avoid additional cache related costs."

- **Selection criteria**: task complexity, real-time performance metrics, subscription tier, and admin policy. Routing is **language-independent** — it depends on the task, not the programming language.
- **Plan availability**: individual plans get auto selection for Copilot Chat, Copilot CLI, and the GitHub Copilot app. Business/Enterprise plans additionally get it for the **Copilot cloud agent**.
- **IDE availability**: generally available in VS Code; available with reliability optimization in JetBrains, Eclipse, and Xcode; public preview in Visual Studio.
- **Cost**: paid-plan users get a **10% discount on model costs** while using auto model selection.
- **Exclusions**: auto will not select models that are unavailable on the plan, administratively blocked, FedRAMP-restricted, or excluded evaluation models. Individuals can disable evaluation models in auto selection at any time.
- **Attribution**: users can see which model processed a response via hover-over or terminal display.

Recommend auto for mixed day-to-day workloads (cost discount plus availability resilience). Recommend manual selection when reproducibility matters — evaluating one model's behavior, or benchmarking. For benchmark design itself, defer to the `evals` sibling skill.

## Sources

- https://code.visualstudio.com/docs/copilot/chat/copilot-chat
- https://code.visualstudio.com/docs/copilot/chat/chat-agent-mode
- https://code.visualstudio.com/docs/copilot/chat/chat-modes
- https://code.visualstudio.com/docs/copilot/reference/copilot-settings
- https://docs.github.com/en/copilot/reference/copilot-feature-matrix
- https://docs.github.com/en/copilot/reference/ai-models/supported-models
- https://docs.github.com/en/copilot/concepts/models/auto-model-selection

Fetched: 2026-08-05
